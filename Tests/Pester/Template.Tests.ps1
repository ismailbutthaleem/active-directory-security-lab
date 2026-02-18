# Tests\Pester\Template.Tests.ps1
# COM5411 - Student Test Template
#
# INSTRUCTIONS FOR STUDENTS:
#   1. Copy this template to create your own test file (e.g., MyFeature.Tests.ps1)
#   2. Your test filename MUST end with .Tests.ps1 (Pester convention)
#   3. Run tests using: .\Tests\Pester\Invoke-Validation.ps1
#
# WHAT YOU GET AUTOMATICALLY:
#   - $RepoRoot: The absolute path to your repository root
#   - $EvidenceDir: Where to save any test evidence (Evidence\Pester folder)
#
# PESTER v5 BASICS:
#   - Describe: Groups related tests together (think of it as a test suite)
#   - Context: Optional sub-grouping within a Describe block
#   - It: A single test case (should test one specific thing)
#   - Should: Assertion commands (-Be, -BeTrue, -Match, etc.)
#
# WHEN DO YOU NEED BeforeDiscovery vs BeforeAll?
#   - BeforeDiscovery: Use when you need to generate tests dynamically (foreach loops)
#   - BeforeAll: Use for setup code that runs before tests execute
#   - Most student tests only need BeforeAll

# ==============================================================================
# PATTERN 1: Simple Tests (No Dynamic Generation)
# ==============================================================================
# Use this pattern if you just have a fixed list of tests to run.

Describe "My Feature Tests" {

    BeforeAll {
        # REQUIRED: Accept parameters from the test harness
        param($RepoRoot, $EvidenceDir)

        # Good practice: Set strict mode and error handling
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        # IMPORTANT: Fallback logic for when parameters aren't injected
        # This allows running tests directly OR through the harness
        if (-not $RepoRoot) {
            $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        }
        if (-not $EvidenceDir) {
            $EvidenceDir = (Resolve-Path (Join-Path $RepoRoot 'Evidence/Pester')).Path
        }

        # EXAMPLE: Load configuration from your repo
        # $config = Import-PowerShellDataFile (Join-Path $RepoRoot 'DSC\Data\AllNodes.psd1')
        # $node = $config.AllNodes | Where-Object NodeName -eq 'localhost'

        # EXAMPLE: Set up test data in script scope (available to all tests)
        # $script:ExpectedValue = $node.SomeSetting
    }

    It "Example test: PowerShell version is 7+" {
        $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7 -Because @"
This lab requires PowerShell 7 or higher!
  Your version: $($PSVersionTable.PSVersion.ToString())

HINT: Download PowerShell 7 from:
  https://aka.ms/powershell
Or use Windows Package Manager:
  winget install Microsoft.PowerShell
"@
    }

    It "Example test: Repo root exists" {
        Test-Path $RepoRoot | Should -BeTrue -Because @"
Repository root directory not found!
  Expected path: $RepoRoot

HINT: Are you running this test from the correct location?
The test harness should inject the correct path automatically.
"@
    }

    It "Example test: Can load AllNodes.psd1" {
        $configPath = Join-Path $RepoRoot 'DSC\Data\AllNodes.psd1'
        Test-Path $configPath | Should -BeTrue -Because @"
AllNodes.psd1 configuration file not found!
  Expected: $configPath

HINT: Check that you have the correct folder structure:
  DSC/Data/AllNodes.psd1
"@
        
        $config = Import-PowerShellDataFile $configPath
        $config | Should -Not -BeNullOrEmpty -Because @"
AllNodes.psd1 exists but couldn't be loaded!

HINT: Check for syntax errors in AllNodes.psd1
  - Missing commas between properties?
  - Unclosed braces or brackets?
  - Invalid PowerShell syntax?
"@
        $config.AllNodes | Should -Not -BeNullOrEmpty -Because @"
AllNodes.psd1 loaded but doesn't contain 'AllNodes' property!

HINT: Your AllNodes.psd1 should have this structure:
  @{
      AllNodes = @(
          @{
              NodeName = 'localhost'
              ...
          }
      )
  }
"@
    }
}

# ==============================================================================
# PATTERN 2: Dynamic Test Generation
# ==============================================================================
# Use this pattern when you want to generate tests from data (e.g., test each file
# in a folder, or test each required module).

Describe "Dynamic Test Example" {

    BeforeDiscovery {
        # REQUIRED: Accept parameters from the test harness
        param($RepoRoot, $EvidenceDir)

        # IMPORTANT: Fallback logic for when parameters aren't injected
        if (-not $RepoRoot) {
            $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        }

        # Generate list of items to test (runs during discovery phase)
        # This example creates tests for each required PowerShell module
        $script:RequiredModules = @(
            'Pester'
            'ActiveDirectoryDsc'
            'ComputerManagementDsc'
        )
    }

    BeforeAll {
        # REQUIRED: Accept parameters from the test harness
        param($RepoRoot, $EvidenceDir)

        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        # IMPORTANT: Fallback logic for when parameters aren't injected
        if (-not $RepoRoot) {
            $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        }
        if (-not $EvidenceDir) {
            $EvidenceDir = (Resolve-Path (Join-Path $RepoRoot 'Evidence/Pester')).Path
        }

        # Any setup that runs before tests execute
    }

    # This creates one test for EACH module in $RequiredModules
    It "Module '<_>' should be installed" -ForEach $RequiredModules {
        # $_ represents the current module name in the loop
        Get-Module -ListAvailable -Name $_ | Should -Not -BeNullOrEmpty -Because @"
PowerShell module '$_' is not installed!

HINT: Install it using:
  Install-Module -Name $_ -Force -SkipPublisherCheck

Or if you need a specific version:
  Install-Module -Name $_ -RequiredVersion x.x.x -Force

Check what's installed:
  Get-Module -ListAvailable -Name $_
"@
    }
}

# ==============================================================================
# COMMON PATTERNS AND TIPS
# ==============================================================================

Describe "Common Testing Patterns" {

    BeforeAll {
        param($RepoRoot, $EvidenceDir)
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        # IMPORTANT: Fallback logic
        if (-not $RepoRoot) {
            $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        }
        if (-not $EvidenceDir) {
            $EvidenceDir = (Resolve-Path (Join-Path $RepoRoot 'Evidence/Pester')).Path
        }
    }

    Context "File and Directory Tests" {
        
        It "Tests a file exists" {
            $testFile = Join-Path $RepoRoot 'README.md'
            Test-Path $testFile | Should -BeTrue -Because @"
File doesn't exist: $testFile

HINT: Verify your repository structure is correct.
"@
        }

        It "Tests a directory exists" {
            $testDir = Join-Path $RepoRoot 'Tests\Pester'
            Test-Path $testDir -PathType Container | Should -BeTrue -Because @"
Directory doesn't exist: $testDir

HINT: Check your folder structure matches the expected layout.
"@
        }
    }

    Context "Service and Process Tests" {
        
        It "Tests a Windows service status" {
            $service = Get-Service -Name 'W32Time' -ErrorAction SilentlyContinue
            $service | Should -Not -BeNullOrEmpty -Because @"
Windows Time service (W32Time) not found!

HINT: This is a built-in Windows service. If it's missing, your OS installation may be corrupt.
"@
            $service.Status | Should -Be 'Running' -Because @"
Windows Time service is not running!
  Current status: $($service.Status)

HINT: Start it with:
  Start-Service W32Time
Or set it to auto-start:
  Set-Service W32Time -StartupType Automatic
"@
        }
    }

    Context "Network Tests" {
        
        It "Tests network adapter exists" {
            $adapter = Get-NetAdapter -Name 'Ethernet*' -ErrorAction SilentlyContinue
            $adapter | Should -Not -BeNullOrEmpty -Because @"
No network adapter matching 'Ethernet*' found!

HINT: Check available adapters with:
  Get-NetAdapter
Then adjust your test to match the actual adapter name.
"@
        }
    }

    Context "String and Value Tests" {
        
        It "Tests exact string match" {
            $actual = 'Hello'
            $actual | Should -Be 'Hello' -Because @"
String doesn't match!
  Expected: 'Hello'
  Actual:   '$actual'

HINT: -Be does exact comparison (case-sensitive on Linux/Mac).
Use -Match for pattern matching or -Like for wildcards.
"@
        }

        It "Tests string contains pattern" {
            $actual = 'Hello World'
            $actual | Should -Match 'World' -Because @"
String doesn't contain expected pattern!
  Pattern: 'World'
  String:  '$actual'

HINT: -Match uses regex. For literal strings with special chars, escape them.
"@
        }

        It "Tests numeric comparison" {
            $value = 42
            $value | Should -BeGreaterThan 40 -Because @"
Value is not greater than 40!
  Expected: > 40
  Actual:   $value
"@
            $value | Should -BeLessThan 50 -Because @"
Value is not less than 50!
  Expected: < 50
  Actual:   $value
"@
        }
    }
}

# ==============================================================================
# COMMON SHOULD ASSERTIONS
# ==============================================================================
# -Be                  : Exact equality (like -eq)
# -BeTrue / -BeFalse   : Boolean tests
# -BeNullOrEmpty       : Tests for null or empty
# -Match               : Regex pattern matching
# -Contain             : Array/collection contains item
# -BeGreaterThan       : Numeric comparison
# -BeLessThan          : Numeric comparison
# -Exist               : File/path exists (alternative to Test-Path)
# -Throw               : Tests that code throws an exception
#
# You can also negate with -Not:
#   Should -Not -Be 'value'
#   Should -Not -BeNullOrEmpty
