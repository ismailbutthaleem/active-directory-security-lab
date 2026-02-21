<#
STUDENT TASK:
- Define Configuration StudentBaseline
- Use ConfigurationData (AllNodes.psd1)
- DO NOT hardcode passwords here.
#>

Configuration StudentBaseline
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName NetworkingDsc

    Node $AllNodes.NodeName
    {
        $node = $ConfigurationData.AllNodes | Where-Object NodeName -eq $Node.NodeName

        $Network = @{
            InterfaceAlias = $node.InterfaceAlias_Internal
            AddressFamily  = 'IPv4'
            IPAddress      = $node.IPv4Address_Internal
            PrefixLength   = $node.PrefixLength_Internal
            DnsServers     = $node.DnsServers_Internal
        }

        File TestFolder
        {
            DestinationPath = 'C:\TEST'
            Type            = 'Directory'
            Ensure          = 'Present'
        }

        File TestFile
        {
            DestinationPath = 'C:\TEST\test.txt'
            Type            = 'File'
            Ensure          = 'Present'
            Contents        = 'Proof-of-life: DSC created this file.'
            DependsOn       = '[File]TestFolder'
        }

        Computer SetComputerName
        {
            Name = $node.ComputerName
        }

        TimeZone SetTimeZone
        {
            IsSingleInstance = 'Yes'
            TimeZone         = $node.TimeZone
        }

        Service WindowsTime
        {
            Name        = 'W32Time'
            State       = 'Running'
            StartupType = 'Automatic'
            DependsOn   = '[TimeZone]SetTimeZone'
        }

        WindowsFeature ADDS
        {
            Name   = 'AD-Domain-Services'
            Ensure = 'Present'
        }

        WindowsFeature RSATADDS
        {
            Name      = 'RSAT-ADDS'
            Ensure    = 'Present'
            DependsOn = '[WindowsFeature]ADDS'
        }

        IPAddress StaticIPv4
        {
            AddressFamily       = $Network.AddressFamily
            InterfaceAlias      = $Network.InterfaceAlias
            IPAddress           = @("$($Network.IPAddress)/$($Network.PrefixLength)")
            KeepExistingAddress = $false
        }

        DnsServerAddress InternalDNS
        {
            AddressFamily  = 'IPv4'
            InterfaceAlias = $node.InterfaceAlias_Internal
            Address        = $node.DnsServers_Internal
            DependsOn      = '[IPAddress]StaticIPv4'
        }

        # --- FIX: capture NAT interface alias once for Script resource scoping ---
        $NatAlias = $node.InterfaceAlias_NAT

        Script DisableNatDnsRegistration
        {
            GetScript = {
                @{ Result = (Get-DnsClient -InterfaceAlias $using:NatAlias).RegisterThisConnectionsAddress }
            }
            TestScript = {
                (Get-DnsClient -InterfaceAlias $using:NatAlias).RegisterThisConnectionsAddress -eq $false
            }
            SetScript = {
                Set-DnsClient -InterfaceAlias $using:NatAlias -RegisterThisConnectionsAddress $false
            }
            DependsOn = '[DnsServerAddress]InternalDNS'
        }

        foreach ($featureName in $node.Features.Add)
        {
            WindowsFeature "Feature_$featureName"
            {
                Name   = $featureName
                Ensure = 'Present'
            }
        }
    }
}