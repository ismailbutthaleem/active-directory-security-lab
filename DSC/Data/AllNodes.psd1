@{
    AllNodes = @(
        @{
            # NodeName is used to match the node in the configuration to the node in the configuration data
            NodeName     = 'localhost'
            Role         = 'DC'

            # ComputerName and TimeZone are required for domain join and time sync
            ComputerName = 'SERVER25-DC-01'
            TimeZone     = 'GMT Standard Time'
            EnsureW32Time = $true # Ensure Windows Time service is running for domain join and time sync

            # Network configuration for internal network
            InterfaceAlias_Internal = 'Ethernet 2'
            IPv4Address_Internal    = '192.168.56.107'
            PrefixLength_Internal   = 24
            DnsServers_Internal     = @('127.0.0.1')

            # Network configuration for NAT network
            InterfaceAlias_NAT      = 'Ethernet'
            Expect_NAT_Dhcp         = $true
            DisableDnsRegistrationOnNat = $true

            # Installation of Active Directory Domain Services and RSAT-ADDS for domain controller configuration
            InstallADDSRole  = $true
            InstallRSATADDS  = $true

            #Security Setttings
            PsDscAllowPlainTextPassword = $true
            PsDscAllowDomainUser        = $true

            # Domain configuration for Active Directory
            DomainName = 'bolton.corp'
            DomainNetBIOSName = 'BOLTON'
            DomainDN = 'DC=bolton,DC=corp'
            ForestMode        = 'WinThreshold'
            DomainMode        = 'WinThreshold'
            # SafeModeAdministratorPassword is required for domain join and Active Directory installation
            Features = @{
                Add = @('AD-Domain-Services','DNS')
            }

            Baseline = @{
                PowerPlan = 'High Performance'
            }
        }
    )
}