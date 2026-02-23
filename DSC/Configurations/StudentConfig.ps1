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

        # FIXED: Where-Object must use a script block
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

        # Use ComputerName resource to set the computer name as specified in the configuration data for domain join and proper identification in Active Directory
        Computer SetComputerName {
            Name = $node.ComputerName
        }

        # Set the time zone as specified in the configuration data for domain join and time synchronization, and ensure Windows Time service is running for proper time sync in Active Directory
        TimeZone SetTimeZone {
            IsSingleInstance = 'Yes'
            TimeZone         = $node.TimeZone
        }

        # Ensure Windows Time service is running and set to automatic startup for domain join and time synchronization in Active Directory
        Service WindowsTime {
            Name        = 'W32Time'
            State       = 'Running'
            StartupType = 'Automatic'
            DependsOn   = '[TimeZone]SetTimeZone'
        }

        # Install Active Directory Domain Services and RSAT-ADDS features for domain controller configuration as specified in the configuration data
        WindowsFeature ADDS {
            Name   = 'AD-Domain-Services'
            Ensure = 'Present'
        }

        WindowsFeature RSATADDS {
            Name      = 'RSAT-ADDS'
            Ensure    = 'Present'
            DependsOn = '[WindowsFeature]ADDS'
        }

        # Network configuration for internal network interface using IPAddress and DnsServerAddress resources, with dependency to ensure proper order of configuration application for domain join and Active Directory functionality
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

        ### Network Settings – External NIC
        ### Network Settings – External NIC

        # Disable DNS registration on the NAT network interface to prevent conflicts with the internal DNS configuration for Active Directory, with dependency to ensure it is applied after the internal DNS server address is configured
        DnsConnectionSuffix DisableNatDnsRegistration {
            InterfaceAlias                 = $node.InterfaceAlias_NAT
            ConnectionSpecificSuffix       = 'nat'
            RegisterThisConnectionsAddress = $false
            DependsOn                      = '[DnsServerAddress]InternalDNS'
        }

        ### PROMOTE TO DOMAIN CONTROLLER - Create new forest and domain
        ADDomain CreateForest {

            # DomainName: The fully-qualified domain name (FQDN)
            # This becomes both the AD domain name and the DNS zone
            DomainName = $Node.DomainName

            # Domain NetBIOS Name: Legacy short name (15 chars max, no dots)
            DomainNetBIOSName = $Node.DomainNetBIOSName

            # Credential: Account to use for the operation
            # For creating a NEW forest, this is the local Administrator
            # For joining an existing domain, this would be a domain account
            # After promotion, this account becomes the first Domain Admin
            Credential = $DomainAdminCredential

            # This is your emergency recovery password
            SafemodeAdministratorPassword = $DsrmCredential

            # ForestMode: Determines available AD features
            # Higher levels enable more features but limit DC compatibility
            ForestMode = $Node.ForestMode

            # DomainMode: Same as ForestMode for a new single-domain forest
            DomainMode = $Node.DomainMode

            # DependsOn: Wait for all prerequisites
            # Specifically, RSAT must be installed for the AD PowerShell module
            DependsOn = '[WindowsFeature]RSATADDS'
        }

        foreach ($featureName in $node.Features.Add) {
            WindowsFeature "Feature_$featureName" {
                Name   = $featureName
                Ensure = 'Present'
            }
        }

        # ===============================
        # OU STRUCTURE (Root DC only)
        # ===============================

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

            ADOrganizationalUnit 'OU_UserAccessPlane_Computers' {
                Name                            = 'Computers'
                Path                            = "OU=UserAccessPlane,$($Node.DomainDN)"
                Ensure                          = 'Present'
                ProtectedFromAccidentalDeletion = $true
                DependsOn                       = '[ADOrganizationalUnit]OU_UserAccessPlane'
            }

            # OU under UserAccessPlane
            ADOrganizationalUnit 'OU_UserAccessPlane_Groups' {
                Name                            = 'Groups'
                Path                            = 'OU=UserAccessPlane,DC=bolton,DC=corp'
                ProtectedFromAccidentalDeletion = $true
                Ensure                          = 'Present'
                DependsOn                       = '[ADOrganizationalUnit]OU_UserAccessPlane'
            }

            # OU under ManagementPlane for admin users
            ADOrganizationalUnit 'OU_ManagementPlane_AdminUsers' {
                Name                            = 'AdminUsers'
                Path                            = 'OU=ManagementPlane,DC=bolton,DC=corp'
                ProtectedFromAccidentalDeletion = $true
                Ensure                          = 'Present'
                DependsOn                       = '[ADOrganizationalUnit]OU_ManagementPlane'
            }

            # OU under ManagementPlane for groups
            ADOrganizationalUnit 'OU_ManagementPlane_Groups' {
                Name                            = 'Groups'
                Path                            = 'OU=ManagementPlane,DC=bolton,DC=corp'
                ProtectedFromAccidentalDeletion = $true
                Ensure                          = 'Present'
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

            # =========================
            # Tier 2 Users (UserAccessPlane)
            # =========================

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

            # =========================
            # Tier 1 Users (ManagementPlane)
            # =========================

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

            # =========================
            # RBAC Membership
            # =========================

            ADGroupMember 'Adam_HR_Membership' {
                GroupName        = 'GG-HR-Staff'
                MembersToInclude = @('adam.khan')
                Ensure           = 'Present'
                DependsOn        = '[ADUser]User_Adam_Khan','[ADGroup]GG_HR_Staff'
            }

            ADGroupMember 'Katy_Finance_Membership' {
                GroupName        = 'GG-Finance-Staff'
                MembersToInclude = @('katy.smith')
                Ensure           = 'Present'
                DependsOn        = '[ADUser]User_Katy_Smith','[ADGroup]GG_Finance_Staff'
            }

            ADGroupMember 'Ismail_ServerAdmin_Membership' {
                GroupName        = 'GG-Server-Admins'
                MembersToInclude = @('ismail.admin')
                Ensure           = 'Present'
                DependsOn        = '[ADUser]User_Ismail_Admin','[ADGroup]GG_Server_Admins'
            }

            ADGroupMember 'Paul_Helpdesk_Membership' {
                GroupName        = 'GG-IT-Admins'
                MembersToInclude = @('paul.evans')
                Ensure           = 'Present'
                DependsOn        = '[ADUser]User_Paul_Evans','[ADGroup]GG_IT_Admins'
            }

        }
    }
}