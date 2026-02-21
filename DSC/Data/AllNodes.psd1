@{
    AllNodes = @(
        @{
            NodeName     = 'localhost'
            Role         = 'DC'

            ComputerName = 'SERVER25-DC-01'
            TimeZone     = 'GMT Standard Time'
            EnsureW32Time = $true # Ensure Windows Time service is running for domain join and time sync

            InterfaceAlias_Internal = 'Ethernet 2'
            IPv4Address_Internal    = '192.168.56.107'
            PrefixLength_Internal   = 24
            DnsServers_Internal     = @('127.0.0.1')

            InterfaceAlias_NAT      = 'Ethernet'
            Expect_NAT_Dhcp         = $true
            DisableDnsRegistrationOnNat = $true

            InstallADDSRole  = $true
            InstallRSATADDS  = $true

            DomainName = 'bolton.corp'
            DomainNetBIOSName = 'BOLTON'
            ForestMode        = 'WinThreshold'
            DomainMode        = 'WinThreshold'

            Features = @{
                Add = @('AD-Domain-Services','DNS')
            }

            Baseline = @{
                PowerPlan = 'High Performance'
            }
        }
    )
}