@{
    AllNodes = @(
        @{
            # NodeName is used to match the node in the configuration to the node in the configuration data
            NodeName     = 'localhost'
            Role         = 'DC'

            # ComputerName and TimeZone are required for domain join and time sync
            ComputerName  = 'SERVER25-DC-01'
            TimeZone      = 'GMT Standard Time'
            EnsureW32Time = $true # Ensure Windows Time service is running for domain join and time sync

            # Network configuration for internal network
            InterfaceAlias_Internal = 'Ethernet 2'
            IPv4Address_Internal    = '192.168.56.107'
            PrefixLength_Internal   = 24
            DnsServers_Internal     = @('127.0.0.1') # Point to itself for DNS resolution

            # Network configuration for NAT network
            InterfaceAlias_NAT          = 'Ethernet'
            Expect_NAT_Dhcp             = $true
            DisableDnsRegistrationOnNat = $true

            # Installation of Active Directory Domain Services and RSAT-ADDS for domain controller configuration
            InstallADDSRole = $true
            InstallRSATADDS = $true

            # Security Setttings
            PsDscAllowPlainTextPassword = $true
            PsDscAllowDomainUser        = $true

            # Domain configuration for Active Directory
            DomainName       = 'bolton.corp'
            DomainNetBIOSName = 'BOLTON'
            DomainDN         = 'DC=bolton,DC=corp'
            ForestMode       = 'WinThreshold'
            DomainMode       = 'WinThreshold'

            # OUs List
            OUList = @(
                @{ Name = 'ControlPlane'    ; Path = $null },
                @{ Name = 'ManagementPlane' ; Path = $null },
                @{ Name = 'UserAccessPlane' ; Path = $null },

                @{ Name = 'Users'     ; Path = 'OU=UserAccessPlane' },
                @{ Name = 'Groups'    ; Path = 'OU=UserAccessPlane' },
                @{ Name = 'Computers' ; Path = 'OU=UserAccessPlane' },

                @{ Name = 'AdminUsers' ; Path = 'OU=ManagementPlane' },
                @{ Name = 'Groups'     ; Path = 'OU=ManagementPlane' },

                @{ Name = 'Groups'     ; Path = 'OU=ControlPlane' },
                @{ Name = 'AdminUsers' ; Path = 'OU=ControlPlane' }
            )

            # Security Groups List
            Groups = @(
                @{ GroupName = 'GG-HR-Staff'       ; Path = 'OU=Groups,OU=UserAccessPlane' ; Scope = 'Global' ; Category = 'Security' },
                @{ GroupName = 'GG-Finance-Staff'  ; Path = 'OU=Groups,OU=UserAccessPlane' ; Scope = 'Global' ; Category = 'Security' },
                @{ GroupName = 'GG-IT-Admins'      ; Path = 'OU=Groups,OU=ManagementPlane' ; Scope = 'Global' ; Category = 'Security' },
                @{ GroupName = 'GG-Server-Admins'  ; Path = 'OU=Groups,OU=ManagementPlane' ; Scope = 'Global' ; Category = 'Security' },
                @{ GroupName = 'GG-Domain-Admins'  ; Path = 'OU=Groups,OU=ControlPlane'    ; Scope = 'Global' ; Category = 'Security' }
            )

            # Users List (Password must be configured in AD)
            Users = @(
                @{ UserName = 'adam.khan'       ; Path = 'OU=Users,OU=UserAccessPlane'       ; Enabled = $true ; MemberOf = @('GG-Finance-Staff') },
                @{ UserName = 'katy.smith'      ; Path = 'OU=Users,OU=UserAccessPlane'       ; Enabled = $true ; MemberOf = @('GG-HR-Staff') },
                @{ UserName = 'ismail.admin'    ; Path = 'OU=AdminUsers,OU=ManagementPlane'  ; Enabled = $true ; MemberOf = @('GG-IT-Admins') },
                @{ UserName = 'paul.evans'      ; Path = 'OU=AdminUsers,OU=ManagementPlane'  ; Enabled = $true ; MemberOf = @('GG-Server-Admins') },
                @{ UserName = 'raul.alejandro'  ; Path = 'OU=AdminUsers,OU=ControlPlane'     ; Enabled = $true ; MemberOf = @('GG-Domain-Admins') }
            )

            # SafeModeAdministratorPassword is required for domain join and Active Directory installation
            Features = @{
                Add = @('AD-Domain-Services', 'DNS')
            }

            Baseline = @{
                PowerPlan = 'High Performance'
            }
        }
    )
}