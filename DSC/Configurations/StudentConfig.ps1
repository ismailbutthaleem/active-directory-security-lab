<#
STUDENT TASK:
- Define Configuration StudentBaseline
- Use ConfigurationData (AllNodes.psd1)
- DO NOT hardcode passwords here.
#>

Configuration StudentBaseline
{
    param(
        [Parameter(Mandatory)]
        [hashtable]$ConfigurationData
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc
    #Import-DscResource -ModuleName ActivedirectoryDSC

    Node $AllNodes.NodeName
    {
        # Pull the node object so every resource reads from the Data Plane
        $node = $ConfigurationData.AllNodes | Where-Object NodeName -eq $Node.NodeName

        # Proof-of-life folder + file (keep)
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

        # Baseline control 1: Computer identity
        Computer SetComputerName
        {
            Name = $node.ComputerName
        }

        # Baseline control 2: Time zone
        TimeZone SetTimeZone
        {
            IsSingleInstance = 'Yes'
            TimeZone         = $node.TimeZone
        }
    }
}