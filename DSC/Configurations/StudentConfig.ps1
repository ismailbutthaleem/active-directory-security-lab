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

        # -----------------------------
        # Baseline network readiness
        # -----------------------------

        # Ensure a deterministic static IPv4 is applied to the intended interface
        IPAddress StaticIPv4
        {
            IPAddress      = $node.Network.IPAddress
            InterfaceAlias = $node.Network.InterfaceAlias
            AddressFamily  = $node.Network.AddressFamily  
            SubnetMask  = $node.Network.PrefixLength    
        }

        # Bind DNS client to the same interface (critical for AD readiness later)
        DnsServerAddress DnsClientServers
        {
            Address        = $node.Network.DnsServers      # e.g. @('192.168.56.10')
            InterfaceAlias = $node.Network.InterfaceAlias
            AddressFamily  = $node.Network.AddressFamily
            DependsOn      = '[IPAddress]StaticIPv4'
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