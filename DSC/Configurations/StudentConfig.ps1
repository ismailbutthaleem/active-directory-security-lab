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

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName NetworkingDsc
    Import-DscResource -ModuleName ActiveDirectoryDsc
    Import-DscResource -ModuleName ComputerManagementDsc

    Node $AllNodes.NodeName {

        $node = $ConfigurationData.AllNodes | Where-Object { $_.NodeName -eq $Node.NodeName }

        # ---------- Common Resources (All Nodes) ----------

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

        # ================= DC CONFIGURATION =================

        if ($node.Role -eq 'DC') {

            $Network = @{
                InterfaceAlias = $node.InterfaceAlias_Internal
                AddressFamily  = 'IPv4'
                IPAddress      = $node.IPv4Address_Internal
                PrefixLength   = $node.PrefixLength_Internal
                DnsServers     = $node.DnsServers_Internal
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

            # ---------- OUs ----------
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

            # ---------- Users ----------
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

            # ---------- Groups ----------
            foreach ($g in $node.Groups) {

                $safeGrp = ($g.GroupName -replace '[^a-zA-Z0-9]', '_')

                $membersForGroup = @(
                    foreach ($u in $node.Users) {
                        if ($u.MemberOf -and ($u.MemberOf -contains $g.GroupName)) {
                            $u.UserName
                        }
                    }
                )

                $depends = @('[ADDomain]CreateForest')
                foreach ($member in $membersForGroup) {
                    $safeMember = ($member -replace '[^a-zA-Z0-9]', '_')
                    $depends += "[ADUser]User_$safeMember"
                }

                ADGroup "Group_$safeGrp" {
                    GroupName        = $g.GroupName
                    GroupScope       = $g.Scope
                    Category         = $g.Category
                    Path             = "$($g.Path),$($Node.DomainDN)"
                    Ensure           = 'Present'
                    DependsOn        = $depends
                    MembersToInclude = $membersForGroup
                }
            }
        }

        # ================= CLIENT CONFIGURATION =================

        if ($node.Role -eq 'Client') {

            LocalConfigurationManager {
                RebootNodeIfNeeded = $true
            }

            Script JoinDomain {

                GetScript = {
                    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
                    @{
                        PartOfDomain = [bool]$cs.PartOfDomain
                        Domain       = $cs.Domain
                    }
                }

                TestScript = {
                    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
                    return ($cs.PartOfDomain -eq $true -and $cs.Domain -ieq $using:node.DomainName)
                }

                SetScript = {
                    Add-Computer -DomainName $using:node.DomainName `
                        -Credential $using:DomainAdminCredential `
                        -OUPath $using:node.DomainJoinOU `
                        -Force -ErrorAction Stop

                    Restart-Computer -Force
                }
            }
        }
    }
}