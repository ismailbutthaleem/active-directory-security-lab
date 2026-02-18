# Tests\Pester\Test-ProofOfLife.Tests.ps1
# Post-build proof-of-life: validates the baseline DSC created files
# Run after orchestration. Expected to fail before first successful build.

$ErrorActionPreference = 'Stop'

Describe "Proof-of-Life (DSC created files)" {

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

        # You can use $RepoRoot or $EvidenceDir here if needed
        # For now, this test just checks hardcoded paths
    }

    It "C:\\TEST directory exists" {
        Test-Path 'C:\\TEST' | Should -BeTrue -Because @"
C:\TEST directory doesn't exist - DSC hasn't created it yet!

HINT: Add a File resource to your StudentConfig.ps1:
  File CreateTestDirectory {
    DestinationPath = 'C:\TEST'
    Type = 'Directory'
    Ensure = 'Present'
  }

Then run: .\Run_BuildMain.ps1
"@
    }

    It "C:\\TEST\\test.txt exists" {
        Test-Path 'C:\\TEST\\test.txt' | Should -BeTrue -Because @"
C:\TEST\test.txt doesn't exist - DSC hasn't created it yet!

HINT: Add a File resource to your StudentConfig.ps1:
  File CreateTestFile {
    DestinationPath = 'C:\TEST\test.txt'
    Type = 'File'
    Ensure = 'Present'
    Contents = 'Proof-of-life: DSC created this file.'
    DependsOn = '[File]CreateTestDirectory'
  }

Then run: .\Run_BuildMain.ps1
"@
    }

    It "test.txt has expected contents" {
        if (-not (Test-Path 'C:\\TEST\\test.txt')) { 
            Set-ItResult -Failed -Because @"
File doesn't exist - create it first using the File resource (see previous test).
"@
            return 
        }
        $content = Get-Content 'C:\\TEST\\test.txt' -ErrorAction Stop -Raw
        $content | Should -Be 'Proof-of-life: DSC created this file.' -Because @"
File contents don't match!
  Expected: 'Proof-of-life: DSC created this file.'
  Actual:   '$content'

HINT: Check the Contents property in your File resource.
"@
    }
}
