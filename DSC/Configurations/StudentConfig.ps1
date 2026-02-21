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
        # Pull this node's data from ConfigurationData
        $node = $ConfigurationData.AllNodes | Where-Object NodeName -eq $Node.NodeName

        # Local network map (from ConfigurationData)
        $Network = $node.Network

        # -----------------------------
        # Proof-of-life
        # -----------------------------
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

        # -----------------------------
        # Baseline identity controls
        # -----------------------------
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

        # -----------------------------
        # Feature readiness (baseline)
        # -----------------------------
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

        # -----------------------------
        # Baseline network readiness
        # -----------------------------
        IPAddress StaticIPv4
        {
            AddressFamily       = $Network.AddressFamily
            InterfaceAlias      = $Network.InterfaceAlias
            IPAddress           = @("$($Network.IPAddress)/$($Network.PrefixLength)")
            KeepExistingAddress = $false
        }

        # IMPORTANT: match tutor test expectation for Internal NIC DNS
        # Uses AllNodes keys: DnsServers_Internal + InterfaceAlias_Internal
        DnsServerAddress InternalDNS
        {
            AddressFamily  = 'IPv4'
            InterfaceAlias = $node.InterfaceAlias_Internal
            Address        = $node.DnsServers_Internal   # e.g. @('127.0.0.1')
            DependsOn      = '[IPAddress]StaticIPv4'
        }

        # NEW: Disable DNS registration on NAT NIC (dual-NIC DC best practice)
        DnsClient DisableNatRegistration
        {
            InterfaceAlias                 = $node.InterfaceAlias_NAT
            RegisterThisConnectionsAddress = $false
        }

        # -----------------------------
        # Optional extra features from data
        # -----------------------------
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