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

        # --- Added: local Network map from ConfigurationData (no other behaviour change) ---
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
            Name   = 'RSAT-ADDS'
            Ensure = 'Present'
            DependsOn = '[WindowsFeature]ADDS'
        }
        # -----------------------------
        # Baseline network readiness
        # -----------------------------

        # Ensure a deterministic static IPv4 is applied to the intended interface
        IPAddress StaticIPv4
        {
            AddressFamily       = $Network.AddressFamily
            InterfaceAlias      = $Network.InterfaceAlias
            IPAddress           = @("$($Network.IPAddress)/$($Network.PrefixLength)")
            KeepExistingAddress = $false
        }

        # Bind DNS client to the same interface (critical for AD readiness later)
        DnsServerAddress DnsClientServers
        {
            Address        = $Network.DnsServers      # e.g. @('192.168.56.10')
            InterfaceAlias = $Network.InterfaceAlias
            AddressFamily  = $Network.AddressFamily
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