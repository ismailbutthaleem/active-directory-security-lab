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
        $Network = $node.Network

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

        Script DisableNatDnsRegistration
        {
            GetScript = {
                @{ Result = (Get-DnsClient -InterfaceAlias $using:node.InterfaceAlias_NAT).RegisterThisConnectionsAddress }
            }
            TestScript = {
                (Get-DnsClient -InterfaceAlias $using:node.InterfaceAlias_NAT).RegisterThisConnectionsAddress -eq $false
            }
            SetScript = {
                Set-DnsClient -InterfaceAlias $using:node.InterfaceAlias_NAT -RegisterThisConnectionsAddress $false
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