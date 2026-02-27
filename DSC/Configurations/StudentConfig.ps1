<#
STUDENT TASK:
- Define Configuration StudentBaseline
- Use ConfigurationData (AllNodes.psd1)
- DO NOT hardcode passwords here.
#>

Configuration StudentBaseline {

    param(

        [Parameter(Mandatory = $true)]
        [PSCredential]
        $DomainAdminCredential,

        [Parameter(Mandatory = $true)]
        [PSCredential]
        $DsrmCredential
    )
    ## Note: The DomainAdminCredential and DsrmCredential parameters are defined as mandatory to ensure that the configuration cannot be applied without providing these credentials. This is important for security and functionality, as these credentials are required for domain join and Active Directory installation. By using parameters, we avoid hardcoding sensitive information in the configuration script, allowing for secure and flexible deployment.
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName NetworkingDsc
    Import-DscResource -ModuleName ActiveDirectoryDsc

    Node $AllNodes.NodeName {

        $node = $ConfigurationData.AllNodes | Where-Object { $_.NodeName -eq $Node.NodeName }

        ## Note: The $node variable is used to access the properties defined in the configuration data for the current node. This allows us to use the values specified in AllNodes.psd1, such as ComputerName, TimeZone, network settings, and domain configuration, without hardcoding them in the configuration script. This approach promotes reusability and maintainability of the configuration, as changes can be made in the configuration data file without modifying the script itself.
        $Network = @{
            InterfaceAlias = $node.InterfaceAlias_Internal
            AddressFamily  = 'IPv4'
            IPAddress      = $node.IPv4Address_Internal
            PrefixLength   = $node.PrefixLength_Internal
            DnsServers     = $node.DnsServers_Internal
        }


        File TestFolder {
            DestinationPath = 'C:\TEST'
            Type            = 'Directory'
            Ensure          = 'Present'
        }

        File TestFile {
            DestinationPath = 'C:\TEST\test.txt'
            Type            = 'File'
            Ensure          = 'Present'
            Contents        = 'Proof-of-life: DSC created this file.'
            DependsOn       = '[File]TestFolder'
        }

        Computer SetComputerName {
            Name = $node.ComputerName
        }

        TimeZone SetTimeZone {
            IsSingleInstance = 'Yes'
            TimeZone         = $node.TimeZone
        }

        Service WindowsTime {
            Name        = 'W32Time'
            State       = 'Running'
            StartupType = 'Automatic'
            DependsOn   = '[TimeZone]SetTimeZone'
        }

        WindowsFeature ADDS {
            Name   = 'AD-Domain-Services'
            Ensure = 'Present'
        }

        WindowsFeature RSATADDS {
            Name      = 'RSAT-ADDS'
            Ensure    = 'Present'
            DependsOn = '[WindowsFeature]ADDS'
        }

        IPAddress StaticIPv4 {
            AddressFamily       = $Network.AddressFamily
            InterfaceAlias      = $Network.InterfaceAlias
            IPAddress           = @("$($Network.IPAddress)/$($Network.PrefixLength)")
            KeepExistingAddress = $false
            DependsOn           = '[Computer]SetComputerName'
        }

        DnsServerAddress InternalDNS {
            AddressFamily  = 'IPv4'
            InterfaceAlias = $node.InterfaceAlias_Internal
            Address        = $node.DnsServers_Internal
            DependsOn      = '[IPAddress]StaticIPv4'
        }

        DnsConnectionSuffix DisableNatDnsRegistration {
            InterfaceAlias                 = $node.InterfaceAlias_NAT
            ConnectionSpecificSuffix       = 'nat'
            RegisterThisConnectionsAddress = $false
            DependsOn                      = '[DnsServerAddress]InternalDNS'
        }

        ADDomain CreateForest {
            DomainName                    = $Node.DomainName
            DomainNetBIOSName             = $Node.DomainNetBIOSName
            Credential                    = $DomainAdminCredential
            SafemodeAdministratorPassword = $DsrmCredential
            ForestMode                    = $Node.ForestMode
            DomainMode                    = $Node.DomainMode
            DependsOn                     = '[WindowsFeature]RSATADDS'
        }

        if ($node.Role -eq 'DC') {

            # OU Loop to enforce values described in AllNodes.psd1
            # ---------- OUs (Data-driven) ----------
            foreach ($ou in $node.OUList) {

                $ouPath = if ([string]::IsNullOrWhiteSpace($ou.Path)) {
                    $Node.DomainDN
                }
                else {
                    "$($ou.Path),$($Node.DomainDN)"
                }

                ADOrganizationalUnit "OU_$($ou.Name)_$([Math]::Abs(($ouPath).GetHashCode()))" {
                    Name                            = $ou.Name
                    Path                            = $ouPath
                    Ensure                          = 'Present'
                    ProtectedFromAccidentalDeletion = $true
                    DependsOn                       = '[ADDomain]CreateForest'
                }
            }

            # ---------- Groups (Data-driven) ----------
            foreach ($g in $node.Groups) {

                $safeGrp = ($g.GroupName -replace '[^a-zA-Z0-9]', '_')

                # Build members list from Users[] where MemberOf contains this group
                $membersForGroup = @(
                    foreach ($u in $node.Users) {
                        if ($u.MemberOf -and ($u.MemberOf -contains $g.GroupName)) {
                            $u.UserName
                        }
                    }
                )

                ADGroup "Group_$safeGrp" {
                    GroupName        = $g.GroupName
                    GroupScope       = $g.Scope
                    Category         = $g.Category
                    Path             = "$($g.Path),$($Node.DomainDN)"
                    Ensure           = 'Present'

                    # Enforce membership via ADGroup resource (compatible across module versions)
                    MembersToInclude = $membersForGroup

                    DependsOn        = '[ADDomain]CreateForest'
                }
            }

            # ---------- Users (Data-driven) ----------
            foreach ($u in $node.Users) {

                $safeUser = ($u.UserName -replace '[^a-zA-Z0-9]', '_')

                ADUser "User_$safeUser" {
                    DomainName = $Node.DomainName
                    UserName   = $u.UserName
                    Path       = "$($u.Path),$($Node.DomainDN)"
                    Ensure     = 'Present'
                    Enabled    = [bool]$u.Enabled
                    DependsOn  = '[ADDomain]CreateForest'
                }
            }
        }
    }
}