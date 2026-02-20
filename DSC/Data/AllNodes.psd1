@{
    AllNodes = @(
        @{
            NodeName     = 'localhost'
            Role         = 'RootDC'

            ComputerName = 'SERVER25-DC-01'
            TimeZone     = 'GMT Standard Time'

            Network = @{
                InterfaceAlias = 'Ethernet 2'
                AddressFamily  = 'IPv4'
                IPAddress      = '192.168.56.107'
                SubnetMask     = '255.255.255.0'
                DnsServers     = @('192.168.56.107')
            }

            Features = @{
                Add = @('AD-Domain-Services','DNS')
            }

            Baseline = @{
                PowerPlan = 'High Performance'
            }
        }
    )
}
