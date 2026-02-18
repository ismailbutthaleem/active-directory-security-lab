BeforeDiscovery {
  param($RepoRoot, $EvidenceDir)

  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  # Fallback: If not injected by harness, calculate from test file location
  if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
  }

  # Load intent for discovery phase (needed for -Skip: expressions)
  $cfg = Import-PowerShellDataFile (Join-Path $RepoRoot 'DSC\Data\AllNodes.psd1')
  $node = $cfg.AllNodes | Where-Object NodeName -eq 'localhost' | Select-Object -First 1

  # Provide hints if required properties are missing
  $requiredProps = @(
    'InterfaceAlias_Internal', 'InterfaceAlias_NAT',
    'IPv4Address_Internal', 'PrefixLength_Internal',
    'DnsServers_Internal', 'Expect_NAT_Dhcp',
    'DisableDnsRegistrationOnNat', 'InstallADDSRole', 'InstallRSATADDS'
  )
  
  $missingProps = $requiredProps | Where-Object { -not $node.ContainsKey($_) }
  if ($missingProps) {
    Write-Warning @"
HINT: Missing network configuration properties in AllNodes.psd1!
Add these properties to the localhost node:

  InterfaceAlias_Internal = 'Ethernet'           # Internal network adapter name
  InterfaceAlias_NAT = 'Ethernet 2'              # NAT/External adapter name
  IPv4Address_Internal = '192.168.99.10'         # Static IP for internal NIC
  PrefixLength_Internal = 24                     # Subnet mask (CIDR)
  DnsServers_Internal = @('127.0.0.1')          # DNS points to self (loopback)
  Expect_NAT_Dhcp = `$true                        # NAT adapter gets DHCP
  DisableDnsRegistrationOnNat = `$true           # Don't register NAT IP in DNS
  InstallADDSRole = `$true                        # Install AD DS role
  InstallRSATADDS = `$true                        # Install RSAT tools

Missing: $($missingProps -join ', ')
"@
  }

  $script:ExpectNatDhcp = if ($node.ContainsKey('Expect_NAT_Dhcp')) { [bool]$node.Expect_NAT_Dhcp } else { $false }
  $script:DisableNatReg = if ($node.ContainsKey('DisableDnsRegistrationOnNat')) { [bool]$node.DisableDnsRegistrationOnNat } else { $false }
  $script:NeedADDS = if ($node.ContainsKey('InstallADDSRole')) { [bool]$node.InstallADDSRole } else { $false }
  $script:NeedRSAT = if ($node.ContainsKey('InstallRSATADDS')) { [bool]$node.InstallRSATADDS } else { $false }
}

Describe "Pre-DC Readiness (Dual NIC) - localhost" {

  BeforeAll {
    param($RepoRoot, $EvidenceDir)

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Fallback: If not injected by harness, calculate from test file location
    if (-not $RepoRoot) {
      $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    }

    # Load intent
    $cfg = Import-PowerShellDataFile (Join-Path $RepoRoot 'DSC\Data\AllNodes.psd1')
    $node = $cfg.AllNodes | Where-Object NodeName -eq 'localhost' | Select-Object -First 1
    $node | Should -Not -BeNullOrEmpty

    # Scope
    $node.Role | Should -Be 'DC'

    foreach ($k in @(
      'InterfaceAlias_Internal','InterfaceAlias_NAT',
      'IPv4Address_Internal','PrefixLength_Internal',
      'DnsServers_Internal',
      'Expect_NAT_Dhcp',
      'DisableDnsRegistrationOnNat',
      'InstallADDSRole','InstallRSATADDS'
    )) {
      ($node.ContainsKey($k) -and -not [string]::IsNullOrWhiteSpace([string]$node[$k])) |
        Should -BeTrue -Because "AllNodes must provide $k for pre-DC dual-NIC readiness"
    }

    $script:IfInt   = [string]$node.InterfaceAlias_Internal
    $script:IfNat   = [string]$node.InterfaceAlias_NAT

    $script:IPv4Int = [string]$node.IPv4Address_Internal
    $script:PrefInt = [int]$node.PrefixLength_Internal
    $script:DnsInt  = @($node.DnsServers_Internal)

    $script:ExpectNatDhcp = [bool]$node.Expect_NAT_Dhcp
    $script:DisableNatReg = [bool]$node.DisableDnsRegistrationOnNat

    $script:NeedADDS = [bool]$node.InstallADDSRole
    $script:NeedRSAT = [bool]$node.InstallRSATADDS

    # Capture actual state
    $script:AdapterInt = Get-NetAdapter -Name $script:IfInt -ErrorAction SilentlyContinue
    $script:AdapterNat = Get-NetAdapter -Name $script:IfNat -ErrorAction SilentlyContinue

    $script:IPInt  = Get-NetIPConfiguration -InterfaceAlias $script:IfInt -ErrorAction SilentlyContinue
    $script:IPNat  = Get-NetIPConfiguration -InterfaceAlias $script:IfNat -ErrorAction SilentlyContinue

    $dnsInt = Get-DnsClientServerAddress -InterfaceAlias $script:IfInt -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $dnsNat = Get-DnsClientServerAddress -InterfaceAlias $script:IfNat -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $script:DnsIntActual = if ($dnsInt) { $dnsInt.ServerAddresses } else { @() }
    $script:DnsNatActual = if ($dnsNat) { $dnsNat.ServerAddresses } else { @() }

    $script:DnsClientInt = Get-DnsClient -InterfaceAlias $script:IfInt -ErrorAction SilentlyContinue
    $script:DnsClientNat = Get-DnsClient -InterfaceAlias $script:IfNat -ErrorAction SilentlyContinue

    # Feature state
    Import-Module ServerManager -ErrorAction Stop
    $script:FeatADDS = Get-WindowsFeature -Name AD-Domain-Services
    $script:FeatRSAT = Get-WindowsFeature -Name RSAT-ADDS
  }

  It "Internal and NAT adapters exist" {
    $script:AdapterInt | Should -Not -BeNullOrEmpty -Because @"
Internal network adapter '$($script:IfInt)' not found!

HINT: Check your network adapter names with: Get-NetAdapter
Then update AllNodes.psd1:
  InterfaceAlias_Internal = 'YourActualAdapterName'

Or rename your adapter to match: Rename-NetAdapter -Name 'CurrentName' -NewName '$($script:IfInt)'
"@
    $script:AdapterNat | Should -Not -BeNullOrEmpty -Because @"
NAT/External network adapter '$($script:IfNat)' not found!

HINT: Check your network adapter names with: Get-NetAdapter
Then update AllNodes.psd1:
  InterfaceAlias_NAT = 'YourActualAdapterName'

For Hyper-V VMs, you typically need two network adapters:
  - Internal: Static IP for AD/DNS
  - NAT/External: DHCP for internet access
"@
  }

  It "Internal NIC has static IPv4 (Manual prefix origin)" {
    $script:IPInt.IPv4Address | Should -Not -BeNullOrEmpty -Because @"
Internal NIC '$($script:IfInt)' has no IPv4 address!

HINT: Configure static IP using NetIPAddress resource in StudentConfig.ps1:
  NetIPAddress InternalIP {
    InterfaceAlias = `$Node.InterfaceAlias_Internal
    IPAddress = `$Node.IPv4Address_Internal
    PrefixLength = `$Node.PrefixLength_Internal
    AddressFamily = 'IPv4'
  }
"@
    ($script:IPInt.IPv4Address | Select-Object -First 1).PrefixOrigin | Should -Be 'Manual' -Because @"
Internal NIC has DHCP instead of static IP!
  Current: $(($script:IPInt.IPv4Address | Select-Object -First 1).PrefixOrigin)
  Required: Manual (static)

HINT: Use NetIPAddress resource (see above). DHCP is not suitable for a Domain Controller.
"@
  }

  It "Internal NIC IPv4 address matches AllNodes" {
    ($script:IPInt.IPv4Address | Select-Object -First 1).IPv4Address | Should -Be $script:IPv4Int -Because @"
Internal NIC IP doesn't match configuration!
  Expected (from AllNodes.psd1): $($script:IPv4Int)
  Actual (from system):          $(($script:IPInt.IPv4Address | Select-Object -First 1).IPv4Address)

HINT: Update your NetIPAddress resource or fix the value in AllNodes.psd1
"@
  }

  It "Internal NIC prefix length matches AllNodes" {
    ($script:IPInt.IPv4Address | Select-Object -First 1).PrefixLength | Should -Be $script:PrefInt -Because @"
Internal NIC subnet mask doesn't match configuration!
  Expected (from AllNodes.psd1): /$($script:PrefInt)
  Actual (from system):          /$(($script:IPInt.IPv4Address | Select-Object -First 1).PrefixLength)

Common values: /24 = 255.255.255.0, /16 = 255.255.0.0
"@
  }

  It "Internal NIC has NO default gateway (single-gateway rule)" {
    $script:IPInt.IPv4DefaultGateway | Should -BeNullOrEmpty -Because @"
Internal NIC should NOT have a default gateway (dual-NIC routing rule)!

WHY: Only ONE NIC should have a gateway to avoid routing conflicts.
The NAT/External NIC handles internet routing.

HINT: Remove default gateway from internal adapter:
  Remove-NetRoute -InterfaceAlias '$($script:IfInt)' -DestinationPrefix '0.0.0.0/0' -Confirm:`$false

Or ensure your NetIPAddress resource doesn't set DefaultGateway for internal NIC.
"@
  }

  It "NAT NIC has a default gateway" {
    $script:IPNat.IPv4DefaultGateway | Should -Not -BeNullOrEmpty -Because @"
NAT/External NIC '$($script:IfNat)' has no default gateway!

HINT: If using DHCP, this should come automatically.
If static, add DefaultGateway to your NetIPAddress resource for this NIC.

Check current routing: Get-NetRoute -InterfaceAlias '$($script:IfNat)'
"@
  }

  It "Internal NIC DNS servers match AllNodes (order-insensitive)" {
    $expected = @($script:DnsInt) | Sort-Object
    $actual   = @($script:DnsIntActual) | Sort-Object
    $diff = Compare-Object -ReferenceObject $expected -DifferenceObject $actual
    $diff | Should -BeNullOrEmpty -Because @"
Internal NIC DNS servers don't match configuration!
  Expected (from AllNodes.psd1): $($script:DnsInt -join ', ')
  Actual (from system):          $($script:DnsIntActual -join ', ')

HINT: For a DC, DNS should point to itself (127.0.0.1 or its own IP).
Use DnsServerAddress resource in StudentConfig.ps1:
  DnsServerAddress InternalDNS {
    InterfaceAlias = `$Node.InterfaceAlias_Internal
    AddressFamily = 'IPv4'
    Address = `$Node.DnsServers_Internal
  }
"@
  }

  It "NAT NIC does not register in DNS when DisableDnsRegistrationOnNat is true" -Skip:(-not $script:DisableNatReg) {
    $script:DnsClientNat.RegisterThisConnectionsAddress | Should -BeFalse -Because @"
NAT NIC should not register its IP in DNS (best practice for dual-NIC DCs)!

WHY: External/NAT IPs shouldn't be in AD DNS records.

HINT: Use DnsClient resource in StudentConfig.ps1:
  DnsClient DisableNatRegistration {
    InterfaceAlias = `$Node.InterfaceAlias_NAT
    RegisterThisConnectionsAddress = `$false
  }
"@
  }

  It "Internal NIC registers in DNS" {
    $script:DnsClientInt.RegisterThisConnectionsAddress | Should -BeTrue -Because @"
Internal NIC should register its IP in DNS!

HINT: Use DnsClient resource in StudentConfig.ps1:
  DnsClient EnableInternalRegistration {
    InterfaceAlias = `$Node.InterfaceAlias_Internal
    RegisterThisConnectionsAddress = `$true
  }
"@
  }

  It "NAT NIC is DHCP (when Expect_NAT_Dhcp is true)" -Skip:(-not $script:ExpectNatDhcp) {
    $script:IPNat.IPv4Address | Should -Not -BeNullOrEmpty -Because @"
NAT NIC has no IP address!

If using DHCP, ensure the adapter is connected and DHCP is working.
Check: Get-NetIPConfiguration -InterfaceAlias '$($script:IfNat)'
"@
    ($script:IPNat.IPv4Address | Select-Object -First 1).PrefixOrigin | Should -Be 'Dhcp' -Because @"
NAT NIC should use DHCP but has static IP!
  Current: $(($script:IPNat.IPv4Address | Select-Object -First 1).PrefixOrigin)

HINT: For Hyper-V labs, NAT adapter typically uses DHCP from the host.
Don't configure NetIPAddress for the NAT adapter - leave it as DHCP.
"@
  }

  It "AD-Domain-Services is installed when requested" -Skip:(-not $script:NeedADDS) {
    $script:FeatADDS.Installed | Should -BeTrue -Because @"
Active Directory Domain Services role is not installed!

HINT: Use WindowsFeature resource in StudentConfig.ps1:
  WindowsFeature ADDS {
    Name = 'AD-Domain-Services'
    Ensure = 'Present'
  }

NOTE: This test only runs on Windows Server (will skip on client OS).
"@
  }

  It "RSAT-ADDS is installed when requested" -Skip:(-not $script:NeedRSAT) {
    $script:FeatRSAT.Installed | Should -BeTrue -Because @"
RSAT Active Directory tools are not installed!

HINT: Use WindowsFeature resource in StudentConfig.ps1:
  WindowsFeature RSAT-ADDS {
    Name = 'RSAT-ADDS'
    Ensure = 'Present'
  }

These tools provide AD cmdlets (Get-ADUser, etc.) needed for management.
"@
  }
}
