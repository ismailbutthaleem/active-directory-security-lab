<#
STUDENT TASK:
- Define Configuration StudentBaseline
- Use ConfigurationData (AllNodes.psd1)
- DO NOT hardcode passwords here.
#>

Configuration StudentBaseline {

    param(

        # The username in the credential should be just 'Administrator'
        [Parameter(Mandatory = $true)]
        [PSCredential]
        $DomainAdminCredential,

        # Can be same as DomainAdminCredential, or different for extra security
        [Parameter(Mandatory = $true)]
        [PSCredential]
        $DsrmCredential
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName NetworkingDsc
    Import-DscResource -ModuleName ActiveDirectoryDsc

    Node $AllNodes.NodeName {

        $node = $ConfigurationData.AllNodes | Where-Object { $_.NodeName -eq $Node.NodeName }

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

            ADOrganizationalUnit 'OU_ControlPlane' {
                Name                            = 'ControlPlane'
                Path                            = $Node.DomainDN
                Ensure                          = 'Present'
                ProtectedFromAccidentalDeletion = $true
                DependsOn                       = '[ADDomain]CreateForest'
            }

            ADOrganizationalUnit 'OU_ManagementPlane' {
                Name                            = 'ManagementPlane'
                Path                            = $Node.DomainDN
                Ensure                          = 'Present'
                ProtectedFromAccidentalDeletion = $true
                DependsOn                       = '[ADDomain]CreateForest'
            }

            ADOrganizationalUnit 'OU_UserAccessPlane' {
                Name                            = 'UserAccessPlane'
                Path                            = $Node.DomainDN
                Ensure                          = 'Present'
                ProtectedFromAccidentalDeletion = $true
                DependsOn                       = '[ADDomain]CreateForest'
            }

            ADOrganizationalUnit 'OU_UserAccessPlane_Users' {
                Name                            = 'Users'
                Path                            = "OU=UserAccessPlane,$($Node.DomainDN)"
                Ensure                          = 'Present'
                ProtectedFromAccidentalDeletion = $true
                DependsOn                       = '[ADOrganizationalUnit]OU_UserAccessPlane'
            }

            ADOrganizationalUnit 'OU_UserAccessPlane_Groups' {
                Name                            = 'Groups'
                Path                            = 'OU=UserAccessPlane,DC=bolton,DC=corp'
                Ensure                          = 'Present'
                ProtectedFromAccidentalDeletion = $true
                DependsOn                       = '[ADOrganizationalUnit]OU_UserAccessPlane'
            }

            ADOrganizationalUnit 'OU_ManagementPlane_AdminUsers' {
                Name                            = 'AdminUsers'
                Path                            = 'OU=ManagementPlane,DC=bolton,DC=corp'
                Ensure                          = 'Present'
                ProtectedFromAccidentalDeletion = $true
                DependsOn                       = '[ADOrganizationalUnit]OU_ManagementPlane'
            }

            ADOrganizationalUnit 'OU_ManagementPlane_Groups' {
                Name                            = 'Groups'
                Path                            = 'OU=ManagementPlane,DC=bolton,DC=corp'
                Ensure                          = 'Present'
                ProtectedFromAccidentalDeletion = $true
                DependsOn                       = '[ADOrganizationalUnit]OU_ManagementPlane'
            }

            ADGroup 'GG_HR_Staff' {
                GroupName  = 'GG-HR-Staff'
                GroupScope = 'Global'
                Category   = 'Security'
                Path       = 'OU=Groups,OU=UserAccessPlane,DC=bolton,DC=corp'
                Ensure     = 'Present'
                DependsOn  = '[ADOrganizationalUnit]OU_UserAccessPlane_Groups'
            }

            ADGroup 'GG_Finance_Staff' {
                GroupName  = 'GG-Finance-Staff'
                GroupScope = 'Global'
                Category   = 'Security'
                Path       = 'OU=Groups,OU=UserAccessPlane,DC=bolton,DC=corp'
                Ensure     = 'Present'
                DependsOn  = '[ADOrganizationalUnit]OU_UserAccessPlane_Groups'
            }

            ADGroup 'GG_IT_Admins' {
                GroupName  = 'GG-IT-Admins'
                GroupScope = 'Global'
                Category   = 'Security'
                Path       = 'OU=Groups,OU=ManagementPlane,DC=bolton,DC=corp'
                Ensure     = 'Present'
                DependsOn  = '[ADOrganizationalUnit]OU_ManagementPlane_Groups'
            }

            ADGroup 'GG_Server_Admins' {
                GroupName  = 'GG-Server-Admins'
                GroupScope = 'Global'
                Category   = 'Security'
                Path       = 'OU=Groups,OU=ManagementPlane,DC=bolton,DC=corp'
                Ensure     = 'Present'
                DependsOn  = '[ADOrganizationalUnit]OU_ManagementPlane_Groups'
            }

            ADUser 'User_Adam_Khan' {
                DomainName  = $Node.DomainName
                UserName    = 'adam.khan'
                GivenName   = 'Adam'
                Surname     = 'Khan'
                DisplayName = 'Adam Khan'
                Path        = 'OU=Users,OU=UserAccessPlane,DC=bolton,DC=corp'
                Enabled     = $true
                Ensure      = 'Present'
                Password    = $DomainAdminCredential
            }

            ADUser 'User_Katy_Smith' {
                DomainName  = $Node.DomainName
                UserName    = 'katy.smith'
                GivenName   = 'Katy'
                Surname     = 'Smith'
                DisplayName = 'Katy Smith'
                Path        = 'OU=Users,OU=UserAccessPlane,DC=bolton,DC=corp'
                Enabled     = $true
                Ensure      = 'Present'
                Password    = $DomainAdminCredential
            }

            ADUser 'User_Ismail_Admin' {
                DomainName  = $Node.DomainName
                UserName    = 'ismail.admin'
                GivenName   = 'Ismail'
                Surname     = 'Admin'
                DisplayName = 'Ismail Admin'
                Path        = 'OU=AdminUsers,OU=ManagementPlane,DC=bolton,DC=corp'
                Enabled     = $true
                Ensure      = 'Present'
                Password    = $DomainAdminCredential
            }

            ADUser 'User_Paul_Evans' {
                DomainName  = $Node.DomainName
                UserName    = 'paul.evans'
                GivenName   = 'Paul'
                Surname     = 'Evans'
                DisplayName = 'Paul Evans'
                Path        = 'OU=AdminUsers,OU=ManagementPlane,DC=bolton,DC=corp'
                Enabled     = $true
                Ensure      = 'Present'
                Password    = $DomainAdminCredential
            }

            ADGroupMember 'Adam_HR_Membership' {
                GroupName        = 'GG-HR-Staff'
                MembersToInclude = @('adam.khan')
                Ensure           = 'Present'
                DependsOn        = '[ADUser]User_Adam_Khan'
            }

            ADGroupMember 'Katy_Finance_Membership' {
                GroupName        = 'GG-Finance-Staff'
                MembersToInclude = @('katy.smith')
                Ensure           = 'Present'
                DependsOn        = '[ADUser]User_Katy_Smith'
            }

            ADGroupMember 'Ismail_ServerAdmin_Membership' {
                GroupName        = 'GG-Server-Admins'
                MembersToInclude = @('ismail.admin')
                Ensure           = 'Present'
                DependsOn        = '[ADUser]User_Ismail_Admin'
            }

            ADGroupMember 'Paul_Helpdesk_Membership' {
                GroupName        = 'GG-IT-Admins'
                MembersToInclude = @('paul.evans')
                Ensure           = 'Present'
                DependsOn        = '[ADUser]User_Paul_Evans'
            }

        }

    }

}