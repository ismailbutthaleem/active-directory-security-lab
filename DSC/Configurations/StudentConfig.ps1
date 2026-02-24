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
            DomainName                   = $Node.DomainName
            DomainNetBIOSName             = $Node.DomainNetBIOSName
            Credential                    = $DomainAdminCredential
            SafemodeAdministratorPassword = $DsrmCredential
            ForestMode                    = $Node.ForestMode
            DomainMode                    = $Node.DomainMode
            DependsOn                     = '[WindowsFeature]RSATADDS'
        }

        if ($node.Role -eq 'DC') {

            # ---------- OUs ----------

            ADOrganizationalUnit 'OU_ControlPlane' {
                Name  = 'ControlPlane'
                Path  = $Node.DomainDN
                Ensure = 'Present'
                ProtectedFromAccidentalDeletion = $true
                DependsOn = '[ADDomain]CreateForest'
            }

            ADOrganizationalUnit 'OU_ManagementPlane' {
                Name  = 'ManagementPlane'
                Path  = $Node.DomainDN
                Ensure = 'Present'
                ProtectedFromAccidentalDeletion = $true
                DependsOn = '[ADDomain]CreateForest'
            }

            ADOrganizationalUnit 'OU_UserAccessPlane' {
                Name  = 'UserAccessPlane'
                Path  = $Node.DomainDN
                Ensure = 'Present'
                ProtectedFromAccidentalDeletion = $true
                DependsOn = '[ADDomain]CreateForest'
            }

            ADOrganizationalUnit 'OU_UserAccessPlane_Users' {
                Name  = 'Users'
                Path  = "OU=UserAccessPlane,$($Node.DomainDN)"
                Ensure = 'Present'
                ProtectedFromAccidentalDeletion = $true
            }

            ADOrganizationalUnit 'OU_UserAccessPlane_Groups' {
                Name  = 'Groups'
                Path  = "OU=UserAccessPlane,$($Node.DomainDN)"
                Ensure = 'Present'
                ProtectedFromAccidentalDeletion = $true
            }

            ADOrganizationalUnit 'OU_UserAccessPlane_Computers' {
                Name  = 'Computers'
                Path  = "OU=UserAccessPlane,$($Node.DomainDN)"
                Ensure = 'Present'
                ProtectedFromAccidentalDeletion = $true
            }

            ADOrganizationalUnit 'OU_ManagementPlane_AdminUsers' {
                Name  = 'AdminUsers'
                Path  = "OU=ManagementPlane,$($Node.DomainDN)"
                Ensure = 'Present'
                ProtectedFromAccidentalDeletion = $true
            }

            ADOrganizationalUnit 'OU_ManagementPlane_Groups' {
                Name  = 'Groups'
                Path  = "OU=ManagementPlane,$($Node.DomainDN)"
                Ensure = 'Present'
                ProtectedFromAccidentalDeletion = $true
            }

            # ---------- Groups ----------

            ADGroup 'GG_HR_Staff' {
                GroupName  = 'GG-HR-Staff'
                GroupScope = 'Global'
                Category   = 'Security'
                Path       = "OU=Groups,OU=UserAccessPlane,$($Node.DomainDN)"
                Ensure     = 'Present'
            }

            ADGroup 'GG_Finance_Staff' {
                GroupName  = 'GG-Finance-Staff'
                GroupScope = 'Global'
                Category   = 'Security'
                Path       = "OU=Groups,OU=UserAccessPlane,$($Node.DomainDN)"
                Ensure     = 'Present'
            }

            ADGroup 'GG_IT_Admins' {
                GroupName  = 'GG-IT-Admins'
                GroupScope = 'Global'
                Category   = 'Security'
                Path       = "OU=Groups,OU=ManagementPlane,$($Node.DomainDN)"
                Ensure     = 'Present'
            }

            ADGroup 'GG_Server_Admins' {
                GroupName  = 'GG-Server-Admins'
                GroupScope = 'Global'
                Category   = 'Security'
                Path       = "OU=Groups,OU=ManagementPlane,$($Node.DomainDN)"
                Ensure     = 'Present'
            }

            # ---------- Users (No Password – created disabled) ----------
                        # ---------- Users (Created via DSC, disabled to avoid password policy / no hardcoded secrets) ----------

            ADUser 'User_Adam_Khan' {
                DomainName  = $Node.DomainName
                UserName    = 'adam.khan'
                Path        = "OU=Users,OU=UserAccessPlane,$($Node.DomainDN)"
                Ensure      = 'Present'
                Enabled     = $false
            }

            ADUser 'User_Katy_Smith' {
                DomainName  = $Node.DomainName
                UserName    = 'katy.smith'
                Path        = "OU=Users,OU=UserAccessPlane,$($Node.DomainDN)"
                Ensure      = 'Present'
                Enabled     = $false
            }

            ADUser 'User_Ismail_Admin' {
                DomainName  = $Node.DomainName
                UserName    = 'ismail.admin'
                Path        = "OU=AdminUsers,OU=ManagementPlane,$($Node.DomainDN)"
                Ensure      = 'Present'
                Enabled     = $false
            }

            ADUser 'User_Paul_Evans' {
                DomainName  = $Node.DomainName
                UserName    = 'paul.evans'
                Path        = "OU=AdminUsers,OU=ManagementPlane,$($Node.DomainDN)"
                Ensure      = 'Present'
                Enabled     = $false
            }


        }

    }

}