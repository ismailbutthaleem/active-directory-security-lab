# Tests\Pester\Invoke-Validation.ps1
# COM5411 Generic Pester Test Handler (Deterministic repo root + data injection)
#
# STUDENT NOTE: This is the test harness - YOU DON'T NEED TO EDIT THIS FILE!
# This script automatically:
#   - Discovers all *.Tests.ps1 files in Tests\Pester\
#   - Injects $RepoRoot and $EvidenceDir into your test files
#   - Runs tests and saves results to Evidence\Pester\
#
# USAGE (from repo root):
#   .\Tests\Pester\Invoke-Validation.ps1                    # Run ALL tests
#   .\Tests\Pester\Invoke-Validation.ps1 Preflight*.Tests.ps1  # Run specific test
#   .\Tests\Pester\Invoke-Validation.ps1 -Output Normal     # Less verbose output
#   .\Tests\Pester\Invoke-Validation.ps1 -NoResultFile      # Don't save XML evidence
#
# WHAT YOU GET FOR FREE:
#   - $RepoRoot automatically calculated and injected into your tests
#   - $EvidenceDir path provided (where to save test evidence)
#   - XML results auto-saved for Git commits (Evidence\Pester\PesterResults_*.xml)

[CmdletBinding()]
param(
  # STUDENT NOTE: You can pass specific test files or folders to run
  # If omitted, ALL *.Tests.ps1 files in Tests\Pester will run
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
  [string[]]$Paths,

  # STUDENT NOTE: Controls how much detail Pester shows
  # 'Detailed' shows each test result (recommended for learning)
  # 'Normal' shows summary only (faster for CI/CD)
  [ValidateSet('None','Normal','Detailed','Diagnostic')]
  [string]$Output = 'Detailed',

  # STUDENT NOTE: By default, results are saved to Evidence\Pester for Git commits
  # Use -NoResultFile during development if you don't want XML clutter
  [switch]$NoResultFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-TestTargets {
  # STUDENT NOTE: This function finds all test files based on what you pass in
  # It handles:
  #   - No arguments: finds ALL *.Tests.ps1 files
  #   - Specific files: validates they exist and end with .Tests.ps1
  #   - Folders: recursively finds all *.Tests.ps1 inside them
  #   - Relative paths: converts them to absolute paths under Tests\Pester
  param(
    [string[]]$InputPaths,       # What the user asked to run
    [string]$TestsRoot,          # Tests\Pester folder
    [string]$RunnerFullPath      # This script's path (to exclude it from results)
  )

  $testsRootFull = (Resolve-Path -Path $TestsRoot).Path.TrimEnd('\') + '\'

  # CASE 1: No paths specified - run EVERYTHING (except this runner script)
  if (-not $InputPaths -or $InputPaths.Count -eq 0) {
    $all = Get-ChildItem -Path $TestsRoot -Recurse -File -Filter '*.Tests.ps1' |
      Where-Object { $_.FullName -ne $RunnerFullPath } |
      Select-Object -ExpandProperty FullName
    return @($all)
  }

  # CASE 2: User specified files/folders - validate and collect them
  $targets = New-Object System.Collections.Generic.List[string]

  foreach ($p in $InputPaths) {
    $resolved = $null

    # Try to resolve the path (could be absolute or relative)
    try {
      $resolved = Resolve-Path -Path $p -ErrorAction Stop
    } catch {
      # If it failed and it's not rooted, try relative to Tests\Pester
      if (-not [System.IO.Path]::IsPathRooted($p)) {
        $candidate = Join-Path -Path $TestsRoot -ChildPath $p
        $resolved = Resolve-Path -Path $candidate -ErrorAction SilentlyContinue
      }
      if (-not $resolved) {
        throw "Test paths must be valid file or folder paths (absolute or relative to Tests\Pester). Not found: $p"
      }
    }

    foreach ($item in $resolved) {
      $full = $item.Path
      $fullNormalized = (Resolve-Path -Path $full).Path

      # SECURITY CHECK: Don't allow tests outside Tests\Pester folder
      if (-not $fullNormalized.StartsWith($testsRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Test paths must be under $TestsRoot. Not allowed: $full"
      }

      # If it's a FILE, validate it ends with .Tests.ps1 (Pester convention)
      if (Test-Path -Path $full -PathType Leaf) {
        if ($full -notmatch '\.Tests\.ps1$') {
          throw "Test file must end with .Tests.ps1: $full"
        }
        $targets.Add($full)
        continue
      }

      # If it's a FOLDER, find all *.Tests.ps1 files inside it recursively
      if (Test-Path -Path $full -PathType Container) {
        $found = Get-ChildItem -Path $full -Recurse -File -Filter '*.Tests.ps1' |
          Select-Object -ExpandProperty FullName
        foreach ($f in $found) { $targets.Add($f) }
        continue
      }

      throw "Path is neither file nor folder: $full"
    }
  }

  if ($targets.Count -eq 0) {
    throw "No *.Tests.ps1 files found for the provided paths."
  }

  # De-duplicate while preserving order (in case user specified overlapping paths)
  $seen = @{}
  $deduped = foreach ($t in $targets) {
    if (-not $seen.ContainsKey($t)) { $seen[$t] = $true; $t }
  }

  return @($deduped)
}

# ============================================================================
# MAIN SCRIPT EXECUTION
# ============================================================================

# STUDENT NOTE: Calculate repo root deterministically
# This script is at: <RepoRoot>\Tests\Pester\Invoke-Validation.ps1
# So repo root is: $PSScriptRoot\..\..\
# No more walking up the tree looking for Run_BuildMain.ps1!
$repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path

$testsRoot = $PSScriptRoot
$runnerFullPath = (Resolve-Path -Path (Join-Path $PSScriptRoot 'Invoke-Validation.ps1')).Path

# Find all test files based on user input (or default to ALL tests)
[array]$testFiles = Resolve-TestTargets -InputPaths $Paths -TestsRoot $testsRoot -RunnerFullPath $runnerFullPath

Write-Host "Pester runner:"
Write-Host "  Repo root:  $repoRoot"
Write-Host "  Test count: $($testFiles.Count)"
Write-Host "  Output:     $Output"

# STUDENT NOTE: Evidence folder - where test results (XML) get saved for Git commits
$evidenceDir = Join-Path -Path $repoRoot -ChildPath 'Evidence\Pester'
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null

$timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$resultPath = Join-Path -Path $evidenceDir -ChildPath "PesterResults_$timestamp.xml"

# STUDENT NOTE: This is the MAGIC part!
# New-PesterContainer creates a "container" for each test file with injected data
# Your test files receive $RepoRoot and $EvidenceDir via param() in BeforeAll/BeforeDiscovery
# This means you NEVER need to calculate repo paths yourself!
$containers = foreach ($tf in $testFiles) {
  $data = @{
    RepoRoot    = [string]$repoRoot      # Injected into your tests
    EvidenceDir = [string]$evidenceDir   # Injected into your tests
  }
  New-PesterContainer -Path $tf -Data $data
}

# Build Pester configuration (Pester v5 uses configuration objects)
$cfg = New-PesterConfiguration
$cfg.Run.Container   = $containers  # Run our containers (with injected data)
$cfg.Output.Verbosity = $Output     # How much detail to show
$cfg.Run.Exit         = $true       # Exit with non-zero code on failures (for CI/CD)

# STUDENT NOTE: By default, save XML results for evidence submission
# Use -NoResultFile during development if you don't want XML files piling up
if (-not $NoResultFile) {
  $cfg.TestResult.Enabled      = $true
  $cfg.TestResult.OutputPath   = $resultPath
  $cfg.TestResult.OutputFormat = 'NUnitXml'  # Industry-standard format
  Write-Host "  Results:    $resultPath"
} else {
  Write-Host "  Results:    disabled"
}

# Run Pester with the configuration
Invoke-Pester -Configuration $cfg