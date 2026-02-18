# ========================================================================
# STUDENT DEMO NOTE: How the Test Harness Injects Configuration
# ========================================================================
# The Invoke-Validation.ps1 harness passes data via New-PesterContainer.
# The param() block below receives $RepoRoot and $EvidenceDir from the
# harness. This is the Pester v5 pattern for parameterized test blocks.
#
# KEY PATTERN: This test demonstrates the "declared intent" pattern:
#   1. Load AllNodes.psd1 (WHAT WE WANT)
#   2. Capture actual system state (WHAT WE HAVE)
#   3. Compare them using Should assertions
# ========================================================================

Describe "Server Baseline Validation" {

    BeforeAll {
        # REQUIRED: Accept injected parameters from the test harness
        param($RepoRoot, $EvidenceDir)

        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        # Fallback: If not injected by harness, calculate from test file location
        if (-not $RepoRoot) {
            $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        }
        if (-not $EvidenceDir) {
            $EvidenceDir = (Resolve-Path (Join-Path $RepoRoot 'Evidence/Pester')).Path
        }
 
        $configPath = Join-Path -Path $RepoRoot -ChildPath 'DSC\Data\AllNodes.psd1'
        $configData = Import-PowerShellDataFile $configPath
        $node = $configData.AllNodes | Where-Object NodeName -eq 'localhost'
 
        # Check if required properties exist, provide hints if missing
        if (-not $node.ContainsKey('ComputerName')) {
            Write-Warning "HINT: Add 'ComputerName' property to AllNodes.psd1 localhost node (e.g., ComputerName = 'DC01')"
        }
        if (-not $node.ContainsKey('TimeZone')) {
            Write-Warning "HINT: Add 'TimeZone' property to AllNodes.psd1 localhost node (e.g., TimeZone = 'GMT Standard Time')"
        }

        $script:ExpectedName = $node.ComputerName
        $script:ExpectedTZ   = $node.TimeZone
 
        $script:ActualName = $env:COMPUTERNAME
        $script:ActualTZ   = (Get-TimeZone).Id
        $script:W32Time    = Get-Service W32Time
    }
 
    It "Hostname matches declared intent in AllNodes" {
        $script:ActualName | Should -Be $script:ExpectedName -Because @"
The computer name should match your configuration.
  Expected (from AllNodes.psd1): '$($script:ExpectedName)'
  Actual (from system):          '$($script:ActualName)'

HINT: To fix this, use the ComputerManagementDsc module's Computer resource in your StudentConfig.ps1:
  Computer SetName {
    Name = `$Node.ComputerName
  }
"@
    }
 
    It "Timezone matches declared intent in AllNodes" {
        $script:ActualTZ | Should -Be $script:ExpectedTZ -Because @"
The timezone should match your configuration.
  Expected (from AllNodes.psd1): '$($script:ExpectedTZ)'
  Actual (from system):          '$($script:ActualTZ)'

HINT: To fix this, use the ComputerManagementDsc module's TimeZone resource in your StudentConfig.ps1:
  TimeZone SetTimeZone {
    IsSingleInstance = 'Yes'
    TimeZone = `$Node.TimeZone
  }

Common UK timezones:
  - 'GMT Standard Time' (London, no DST)
  - 'UTC' (Coordinated Universal Time)
"@
    }
 
    It "Windows Time service is running" {
        $script:W32Time.Status | Should -Be 'Running' -Because @"
The Windows Time (W32Time) service must be running for time synchronization.
  Current status: $($script:W32Time.Status)

HINT: To fix this, use the Service resource in your StudentConfig.ps1:
  Service W32Time {
    Name = 'W32Time'
    State = 'Running'
    StartupType = 'Automatic'
  }
"@
    }
}

