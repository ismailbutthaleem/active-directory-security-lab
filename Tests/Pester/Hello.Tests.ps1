# Tests\Pester\Hello.Tests.ps1
# This is a simple test file for Pester, a testing framework for PowerShell.
# 
# STUDENT NOTE: This demonstrates the minimal structure for a test file.
# Even if you don't use $RepoRoot or $EvidenceDir, you should still accept
# them in the param() block so your tests work with the test harness.

Describe "Hello World Test" {

    BeforeAll {
        # REQUIRED: Accept injected parameters from the test harness
        # Even if you don't use them, include this so the harness can inject them
        param($RepoRoot, $EvidenceDir)

        # Fallback: If not injected by harness, calculate from test file location
        if (-not $RepoRoot) {
            $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        }
        if (-not $EvidenceDir) {
            $EvidenceDir = (Resolve-Path (Join-Path $RepoRoot 'Evidence/Pester')).Path
        }

        # You can use $RepoRoot to load config files if needed:
        # $config = Import-PowerShellDataFile (Join-Path $RepoRoot 'DSC\Data\AllNodes.psd1')
    }

    It "2 + 2 should equal 4" {
        (2 + 2) | Should -Be 4 -Because @"
This is a smoke test to verify Pester is working correctly.
If this fails, something is seriously wrong with your PowerShell installation!

HINT: If you see this error, try:
  1. Close PowerShell
  2. Restart PowerShell as Administrator
  3. Run: Install-Module Pester -Force -SkipPublisherCheck
  4. Re-run tests
"@
    }

}
