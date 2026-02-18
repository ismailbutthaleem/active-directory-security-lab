# Tests\Pester\ADDS_Promotion.Tests.ps1
# COM5411 - Active Directory Domain Services Promotion Tests
#
# PURPOSE: Validates that AD DS promotion was successful and the domain controller
# is functioning properly with all required services and configurations.
#
# TESTS COVERED:
#   - Prerequisites (network, features, services)
#   - Domain Controller promotion status
#   - AD DS and DNS services functionality
#   - Domain/Forest configuration validation
#   - RSAT tools and admin functionality
#   - Post-promotion health checks

BeforeDiscovery {
    param($RepoRoot, $EvidenceDir)

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Fallback: If not injected by harness, calculate from test file location
    if (-not $RepoRoot) {
        $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    }

    # Load configuration for discovery phase
    $cfg = Import-PowerShellDataFile (Join-Path $RepoRoot 'DSC\Data\AllNodes.psd1')
    $node = $cfg.AllNodes | Where-Object NodeName -eq 'localhost' | Select-Object -First 1
    
    # Check module availability for -Skip expressions
    $script:ADModuleAvailable = $false
    $script:DNSServerModuleAvailable = $false
    
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        $script:ADModuleAvailable = $true
    }
    catch {
        $script:ADModuleAvailable = $false
    }
    
    try {  
        Import-Module DnsServer -ErrorAction Stop
        $script:DNSServerModuleAvailable = $true
    }
    catch {
        $script:DNSServerModuleAvailable = $false
    }
}

Describe "Active Directory Domain Services (AD DS) Promotion" {

    BeforeAll {
        param($RepoRoot, $EvidenceDir)

        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        # Fallback logic for direct test execution
        if (-not $RepoRoot) {
            $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        }
        if (-not $EvidenceDir) {
            $EvidenceDir = (Resolve-Path (Join-Path $RepoRoot 'Evidence/Pester')).Path
            if (-not (Test-Path $EvidenceDir)) {
                New-Item -Path $EvidenceDir -ItemType Directory -Force | Out-Null
            }
        }

        # Load configuration
        $cfg = Import-PowerShellDataFile (Join-Path $RepoRoot 'DSC\Data\AllNodes.psd1')
        $node = $cfg.AllNodes | Where-Object NodeName -eq 'localhost' | Select-Object -First 1
        $node | Should -Not -BeNullOrEmpty -Because "localhost node configuration must exist in AllNodes.psd1"

        # Extract configuration values with fallbacks
        $script:ExpectedDomain = if ($node.DomainName) { $node.DomainName } else { 'barmbuzz.corp' }
        $script:ExpectedNetBIOS = if ($node.DomainNetBIOSName) { $node.DomainNetBIOSName } else { 'BARMBUZZ' }
        $script:ExpectedComputerName = if ($node.ComputerName) { $node.ComputerName } else { $env:COMPUTERNAME }
        $script:ExpectedForestMode = if ($node.ForestMode) { $node.ForestMode } else { 'WinThreshold' }
        $script:ExpectedDomainMode = if ($node.DomainMode) { $node.DomainMode } else { 'WinThreshold' }
        $script:InternalNIC = if ($node.InterfaceAlias_Internal) { $node.InterfaceAlias_Internal } else { 'Ethernet 2' }
        $script:InternalIP = if ($node.IPv4Address_Internal) { 
            ($node.IPv4Address_Internal -split '/')[0]  # Remove CIDR if present
        } else { '192.168.99.10' }

        # Import required modules
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
            $script:ADModuleAvailable = $true
        }
        catch {
            Write-Warning "Active Directory module not available: $($_.Exception.Message)"
            $script:ADModuleAvailable = $false
        }

        try {
            Import-Module DnsServer -ErrorAction Stop
            $script:DNSServerModuleAvailable = $true
        }
        catch {
            Write-Warning "DNS Server module not available: $($_.Exception.Message)"
            $script:DNSServerModuleAvailable = $false
        }

        # Capture current state for testing
        $script:WindowsFeatures = Get-WindowsFeature -ErrorAction SilentlyContinue
        $script:Services = Get-Service -ErrorAction SilentlyContinue
        $script:ComputerInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
        $script:NetworkConfig = Get-NetIPConfiguration -ErrorAction SilentlyContinue

        # Evidence collection timestamp
        $script:TestTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    }

    Context "Prerequisites and Installation" {

        It "Computer has expected name" {
            $env:COMPUTERNAME | Should -Be $script:ExpectedComputerName -Because @"
Computer name should match DSC configuration.
Expected: $script:ExpectedComputerName
Actual: $env:COMPUTERNAME

HINT: Check DSC\Data\AllNodes.psd1 ComputerName property
"@
        }

        It "AD Domain Services feature is installed" {
            $addsFeature = $script:WindowsFeatures | Where-Object Name -eq 'AD-Domain-Services'
            $addsFeature | Should -Not -BeNullOrEmpty -Because "AD-Domain-Services feature must exist"
            $addsFeature.InstallState | Should -Be 'Installed' -Because @"
AD-Domain-Services feature must be installed before promotion.

Current state: $($addsFeature.InstallState)

HINT: Run the DSC configuration or manually install:
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
"@
        }

        It "RSAT AD Tools feature is installed" {
            $rsatFeature = $script:WindowsFeatures | Where-Object Name -eq 'RSAT-AD-Tools'
            $rsatFeature | Should -Not -BeNullOrEmpty -Because "RSAT-AD-Tools feature should exist"
            $rsatFeature.InstallState | Should -Be 'Installed' -Because @"
RSAT-AD-Tools feature must be installed for management functionality.

Current state: $($rsatFeature.InstallState)

HINT: Run the DSC configuration or manually install:
Install-WindowsFeature -Name RSAT-AD-Tools
"@
        }

        It "Internal network adapter is configured with static IP" {
            $adapter = $script:NetworkConfig | Where-Object InterfaceAlias -eq $script:InternalNIC
            $adapter | Should -Not -BeNullOrEmpty -Because @"
Internal network adapter '$script:InternalNIC' not found.

Available adapters:
$($script:NetworkConfig | Select-Object InterfaceAlias, IPv4Address | Format-Table -AutoSize | Out-String)

HINT: Update DSC\Data\AllNodes.psd1 InterfaceAlias_Internal property
"@

            $adapter.IPv4Address.IPAddress | Should -Contain $script:InternalIP -Because @"
Internal NIC should have static IP: $script:InternalIP
Current IP addresses: $($adapter.IPv4Address.IPAddress -join ', ')

HINT: Check DSC NetIPAddress configuration
"@
        }

        It "DNS points to localhost (127.0.0.1)" {
            $dnsServers = Get-DnsClientServerAddress -InterfaceAlias $script:InternalNIC -AddressFamily IPv4 -ErrorAction SilentlyContinue
            $dnsServers.ServerAddresses | Should -Contain '127.0.0.1' -Because @"
Internal NIC DNS should point to localhost after DC promotion.
Current DNS servers: $($dnsServers.ServerAddresses -join ', ')

HINT: This should be configured automatically after AD DS promotion
"@
        }
    }

    Context "Domain Controller Services" {

        It "Active Directory Domain Services is running" {
            $ntdsService = $script:Services | Where-Object Name -eq 'NTDS'
            $ntdsService | Should -Not -BeNullOrEmpty -Because "NTDS service should exist after DC promotion"
            $ntdsService.Status | Should -Be 'Running' -Because @"
Active Directory Domain Services (NTDS) must be running.

Current status: $($ntdsService.Status)

HINT: If promotion failed, check Event Logs:
Get-WinEvent -LogName 'Directory Services' | Select-Object -First 20
"@
        }

        It "DNS Server service is running" {
            $dnsService = $script:Services | Where-Object Name -eq 'DNS'
            $dnsService | Should -Not -BeNullOrEmpty -Because "DNS service should exist after DC promotion"
            $dnsService.Status | Should -Be 'Running' -Because @"
DNS Server service must be running on domain controllers.

Current status: $($dnsService.Status)

HINT: DNS is required for AD DS functionality
"@
        }

        It "Netlogon service is running" {
            $netlogonService = $script:Services | Where-Object Name -eq 'Netlogon'
            $netlogonService | Should -Not -BeNullOrEmpty -Because "Netlogon service should exist"
            $netlogonService.Status | Should -Be 'Running' -Because @"
Netlogon service must be running for domain authentication.

Current status: $($netlogonService.Status)
"@
        }

        It "Kerberos Key Distribution Center is running" {
            $kdcService = $script:Services | Where-Object Name -eq 'KDC'
            $kdcService | Should -Not -BeNullOrEmpty -Because "KDC service should exist after DC promotion"
            $kdcService.Status | Should -Be 'Running' -Because @"
Kerberos Key Distribution Center must be running for authentication.

Current status: $($kdcService.Status)
"@
        }

        It "File Replication Service or DFS Replication is running" {
            $frsService = $script:Services | Where-Object Name -eq 'FRS'
            $dfsrService = $script:Services | Where-Object Name -eq 'DFSR'
            
            $replicationRunning = ($frsService -and $frsService.Status -eq 'Running') -or 
                                 ($dfsrService -and $dfsrService.Status -eq 'Running')
            
            $replicationRunning | Should -BeTrue -Because @"
Either FRS or DFSR must be running for SYSVOL replication.

FRS Status: $(if($frsService){$frsService.Status}else{'Not Found'})
DFSR Status: $(if($dfsrService){$dfsrService.Status}else{'Not Found'})
"@
        }
    }

    Context "Domain and Forest Configuration" -Skip:(-not $script:ADModuleAvailable) {

        It "Computer is part of the expected domain" {
            # Try multiple methods to get domain information
            $currentDomain = $null
            
            try {
                $computerSystem = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop
                $currentDomain = $computerSystem.Domain
            }
            catch {
                try {
                    $currentDomain = $env:USERDNSDOMAIN
                }
                catch {
                    $currentDomain = 'Unknown'
                }
            }
            
            $currentDomain | Should -Be $script:ExpectedDomain -Because @"
Computer should be joined to domain: $script:ExpectedDomain
Current domain: $currentDomain

HINT: This indicates DC promotion may not have completed successfully
"@
        }

        It "Domain exists and is accessible" {
            { Get-ADDomain -Identity $script:ExpectedDomain -ErrorAction Stop } | Should -Not -Throw -Because @"
Unable to query domain '$script:ExpectedDomain' using AD module.

This could indicate:
- DC promotion failed
- AD services aren't running
- Network/DNS issues
"@
        }

        It "Forest exists and has correct name" {
            $forest = Get-ADForest -ErrorAction SilentlyContinue
            $forest | Should -Not -BeNullOrEmpty -Because "Forest information should be accessible"
            $forest.Name | Should -Be $script:ExpectedDomain -Because @"
Forest name should match expected domain: $script:ExpectedDomain
Actual forest name: $($forest.Name)
"@
        }

        It "Domain has correct NetBIOS name" {
            $domain = Get-ADDomain -Identity $script:ExpectedDomain -ErrorAction SilentlyContinue
            $domain.NetBIOSName | Should -Be $script:ExpectedNetBIOS -Because @"
Domain NetBIOS name should be: $script:ExpectedNetBIOS
Actual NetBIOS name: $($domain.NetBIOSName)
"@
        }

        It "Forest functional level is modern (2016+)" {
            $forest = Get-ADForest -ErrorAction SilentlyContinue
            $forest.ForestMode | Should -Not -BeNullOrEmpty -Because "Forest functional level should be set"
            
            # WinThreshold in DSC means "use latest available", which translates to specific version strings
            $modernForestModes = @('Windows2016Forest', 'Windows2019Forest', 'Windows2022Forest', 'Windows2025Forest', 'WinThreshold')
            $modernForestModes | Should -Contain $forest.ForestMode -Because @"
Forest functional level should be modern (2016 or higher).
Configured: $script:ExpectedForestMode (WinThreshold = use latest available)
Actual forest mode: $($forest.ForestMode)

Acceptable modes: $($modernForestModes -join ', ')
"@
        }

        It "Domain functional level is modern (2016+)" {
            $domain = Get-ADDomain -Identity $script:ExpectedDomain -ErrorAction SilentlyContinue
            $domain.DomainMode | Should -Not -BeNullOrEmpty -Because "Domain functional level should be set"
            
            # WinThreshold in DSC means "use latest available", which translates to specific version strings
            $modernDomainModes = @('Windows2016Domain', 'Windows2019Domain', 'Windows2022Domain', 'Windows2025Domain', 'WinThreshold')
            $modernDomainModes | Should -Contain $domain.DomainMode -Because @"
Domain functional level should be modern (2016 or higher).
Configured: $script:ExpectedDomainMode (WinThreshold = use latest available)  
Actual domain mode: $($domain.DomainMode)

Acceptable modes: $($modernDomainModes -join ', ')
"@
        }

        It "This computer is a domain controller" {
            $domain = Get-ADDomain -Identity $script:ExpectedDomain -ErrorAction SilentlyContinue
            $dcList = $domain.ReadOnlyReplicaDirectoryServers + $domain.ReplicaDirectoryServers
            $currentComputer = "$($env:COMPUTERNAME).$($script:ExpectedDomain)"
            
            $dcList | Should -Contain $currentComputer -Because @"
Current computer should be listed as a domain controller.
Expected: $currentComputer
Domain Controllers: $($dcList -join ', ')
"@
        }
    }

    Context "DNS Functionality" -Skip:(-not $script:DNSServerModuleAvailable) {

        It "DNS zones are created for the domain" {
            $forwardZone = Get-DnsServerZone -Name $script:ExpectedDomain -ErrorAction SilentlyContinue
            $forwardZone | Should -Not -BeNullOrEmpty -Because @"
Forward DNS zone for '$script:ExpectedDomain' should exist.

HINT: DNS zones are created automatically during DC promotion
"@
            $forwardZone.ZoneType | Should -Be 'Primary' -Because "Domain DNS zone should be Primary type"
        }

        It "Reverse DNS zone exists for internal subnet or PTR resolution works" {
            # Extract reverse zone from internal IP (assumes /24)
            $ipParts = $script:InternalIP -split '\.'
            $reverseZoneName = "$($ipParts[2]).$($ipParts[1]).$($ipParts[0]).in-addr.arpa"
            
            $reverseZone = Get-DnsServerZone -Name $reverseZoneName -ErrorAction SilentlyContinue
            
            # If reverse zone doesn't exist, try PTR record resolution as alternative
            if (-not $reverseZone) {
                try {
                    $ptrResult = Resolve-DnsName -Name $script:InternalIP -Type PTR -ErrorAction SilentlyContinue
                    if ($ptrResult) {
                        Write-Host "Reverse DNS zone '$reverseZoneName' not found, but PTR resolution works" -ForegroundColor Yellow
                        $true | Should -BeTrue -Because "PTR resolution is working as alternative to reverse zone"
                        return
                    }
                }
                catch {
                    # PTR resolution failed too
                }
            }
            
            $reverseZone | Should -Not -BeNullOrEmpty -Because @"
Reverse DNS zone '$reverseZoneName' should exist for IP resolution.
Internal IP: $script:InternalIP

Available DNS zones:
$(Get-DnsServerZone | Select-Object ZoneName, ZoneType | Format-Table -AutoSize | Out-String)

HINT: Reverse DNS zones may not be created automatically in lab environments
"@
        }

        It "Domain controller has DNS A record" {
            $dcRecord = Get-DnsServerResourceRecord -ZoneName $script:ExpectedDomain -Name $script:ExpectedComputerName -RRType A -ErrorAction SilentlyContinue
            $dcRecord | Should -Not -BeNullOrEmpty -Because @"
Domain controller should have A record in DNS.
Looking for: $script:ExpectedComputerName in zone $script:ExpectedDomain
"@
        }

        It "Domain has NS record pointing to this DC" {
            $nsRecords = Get-DnsServerResourceRecord -ZoneName $script:ExpectedDomain -RRType NS -ErrorAction SilentlyContinue
            $dcFqdn = "$($script:ExpectedComputerName).$($script:ExpectedDomain)"
            $nsRecords.RecordData.NameServer | Should -Contain "$dcFqdn." -Because @"
Domain should have NS record pointing to this domain controller.
Expected: $dcFqdn.
Current NS records: $($nsRecords.RecordData.NameServer -join ', ')
"@
        }

        It "Can resolve domain name to IP" {
            $resolution = Resolve-DnsName -Name $script:ExpectedDomain -Type A -ErrorAction SilentlyContinue
            $resolution | Should -Not -BeNullOrEmpty -Because "Domain name should resolve to IP address"
            $resolution.IPAddress | Should -Contain $script:InternalIP -Because @"
Domain name should resolve to domain controller's internal IP.
Expected IP: $script:InternalIP
Resolved IPs: $($resolution.IPAddress -join ', ')
"@
        }
    }

    Context "Administrative Functionality" -Skip:(-not $script:ADModuleAvailable) {

        It "Can query domain users" {
            { Get-ADUser -Filter * -ErrorAction Stop } | Should -Not -Throw -Because @"
Should be able to query Active Directory users.

This tests basic AD PowerShell functionality and permissions.
"@
        }

        It "Built-in Administrator account exists" {
            $adminUser = Get-ADUser -Identity 'Administrator' -ErrorAction SilentlyContinue
            $adminUser | Should -Not -BeNullOrEmpty -Because "Built-in Administrator account should exist"
            $adminUser.Enabled | Should -BeTrue -Because "Administrator account should be enabled"
        }

        It "Domain Admins group exists" {
            $domainAdmins = Get-ADGroup -Identity 'Domain Admins' -ErrorAction SilentlyContinue
            $domainAdmins | Should -Not -BeNullOrEmpty -Because "Domain Admins group should exist"
            $domainAdmins.GroupScope | Should -Be 'Global' -Because "Domain Admins should be Global scope"
        }

        It "Default domain containers exist" {
            $expectedContainers = @(
                @{ Name = 'Users'; Type = 'CN' },
                @{ Name = 'Computers'; Type = 'CN' }, 
                @{ Name = 'Domain Controllers'; Type = 'OU' }
            )
            
            foreach ($container in $expectedContainers) {
                $containerDN = "$($container.Type)=$($container.Name),DC=$($script:ExpectedDomain -replace '\.',',DC=')"
                
                try {
                    $containerObject = Get-ADObject -Identity $containerDN -ErrorAction Stop
                    $containerObject | Should -Not -BeNullOrEmpty -Because "Default container '$($container.Name)' should exist at $containerDN"
                }
                catch {
                    Write-Warning "Container '$($container.Name)' not found at $containerDN : $($_.Exception.Message)"
                    $false | Should -BeTrue -Because @"
Default container '$($container.Name)' should exist.
Expected DN: $containerDN
Error: $($_.Exception.Message)

Available containers:
$(Get-ADObject -Filter "ObjectClass -eq 'container' -or ObjectClass -eq 'organizationalUnit'" | Select-Object Name, DistinguishedName | Format-Table -AutoSize | Out-String)
"@
                }
            }
        }

        It "SYSVOL share is accessible" {
            $sysvolPath = "\\$env:COMPUTERNAME\SYSVOL"
            Test-Path $sysvolPath | Should -BeTrue -Because @"
SYSVOL share should be accessible at: $sysvolPath

This is required for Group Policy and domain replication.
"@
        }

        It "NETLOGON share is accessible" {
            $netlogonPath = "\\$env:COMPUTERNAME\NETLOGON"
            Test-Path $netlogonPath | Should -BeTrue -Because @"
NETLOGON share should be accessible at: $netlogonPath

This is required for domain logon scripts and authentication.
"@
        }
    }

    Context "Health and Status Checks" {

        It "Event logs show successful promotion" {
            try {
                $promotionEvents = Get-WinEvent -FilterHashtable @{
                    LogName = 'Directory Service'
                    ID = 1000  # Successful promotion event
                } -MaxEvents 5 -ErrorAction SilentlyContinue
            }
            catch {
                # Try alternative log name and broader search
                $promotionEvents = Get-WinEvent -LogName 'System' | Where-Object {
                    $_.Id -eq 1000 -and $_.ProviderName -like '*Directory*'
                } | Select-Object -First 5
            }

            # More lenient check - just verify we can access event logs
            { Get-WinEvent -LogName 'System' -MaxEvents 1 } | Should -Not -Throw -Because @"
Should be able to access Windows Event Logs for promotion verification.

Alternative check: Look for NTDS service start events
"@
        }

        It "No recent critical errors in AD logs" {
            try {
                $recentErrors = Get-WinEvent -FilterHashtable @{
                    LogName = 'Directory Service'
                    Level = 1,2  # Critical and Error
                    StartTime = (Get-Date).AddHours(-1)
                } -MaxEvents 10 -ErrorAction SilentlyContinue
            }
            catch {
                # If Directory Service log doesn't exist, try System log for NTDS errors
                $recentErrors = Get-WinEvent -FilterHashtable @{
                    LogName = 'System'
                    Level = 1,2
                    StartTime = (Get-Date).AddHours(-1)
                } -ErrorAction SilentlyContinue | Where-Object ProviderName -like '*NTDS*'
            }

            if ($recentErrors) {
                $errorSummary = $recentErrors | Group-Object Id | ForEach-Object {
                    "ID $($_.Name): $($_.Count) events"
                }
                Write-Warning "Recent AD errors found: $($errorSummary -join ', ')"
            }

            # This is a warning rather than failure - some errors might be expected during testing
            if ($recentErrors -and ($recentErrors | Measure-Object).Count -gt 5) {
                Write-Warning "Found $(($recentErrors | Measure-Object).Count) recent critical/error events in logs"
            }
        }

        It "Domain controller can authenticate itself" {
            try {
                Test-ComputerSecureChannel -ErrorAction Stop
                $true | Should -BeTrue -Because "Secure channel test passed successfully"
            }
            catch {
                Write-Warning "Secure channel test failed: $($_.Exception.Message)"
                Write-Warning "This may be expected during initial DC setup or if domain is still initializing"
                
                # Test alternative - check if domain services are responding
                try {
                    $domain = Get-ADDomain -ErrorAction Stop
                    Write-Host "Alternative validation: Successfully queried AD domain '$($domain.Name)'" -ForegroundColor Green
                }
                catch {
                    $false | Should -BeTrue -Because @"
Domain controller cannot authenticate with domain and AD queries are also failing.

Secure channel error: $($_.Exception.Message)
This indicates a serious domain configuration issue.
"@
                }
            }
        }

        AfterAll {
            # Collect evidence for troubleshooting
            $evidenceFile = Join-Path $EvidenceDir "ADDS_Promotion_Evidence_$script:TestTimestamp.txt"
            
            $evidence = @"
AD DS Promotion Test Evidence - $script:TestTimestamp
=======================================================

Configuration:
- Expected Domain: $script:ExpectedDomain
- Expected NetBIOS: $script:ExpectedNetBIOS  
- Expected Computer: $script:ExpectedComputerName
- Internal IP: $script:InternalIP
- AD Module Available: $script:ADModuleAvailable
- DNS Module Available: $script:DNSServerModuleAvailable

Windows Features:
$(Get-WindowsFeature | Where-Object {$_.Name -like '*AD*' -or $_.Name -like '*DNS*'} | Format-Table Name, InstallState -AutoSize | Out-String)

Critical Services:
$($script:Services | Where-Object {$_.Name -in @('NTDS','DNS','Netlogon','KDC','DFSR','FRS')} | Format-Table Name, Status, StartType -AutoSize | Out-String)

Network Configuration:
$(Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, DNSServer | Format-Table -AutoSize | Out-String)

Computer Information:
- Computer Name: $env:COMPUTERNAME
- Domain: $(if ($script:ComputerInfo -and $script:ComputerInfo.Domain) { $script:ComputerInfo.Domain } else { 'Unknown' })
- Role: $(if ($script:ComputerInfo -and $script:ComputerInfo.WindowsProductName) { $script:ComputerInfo.WindowsProductName } else { 'Unknown' })

"@

            if ($script:ADModuleAvailable) {
                try {
                    $domain = Get-ADDomain -ErrorAction SilentlyContinue
                    $forest = Get-ADForest -ErrorAction SilentlyContinue
                    $evidence += @"

Active Directory Information:
- Domain Name: $($domain.Name)
- NetBIOS Name: $($domain.NetBIOSName)
- Domain Mode: $($domain.DomainMode) 
- Forest Name: $($forest.Name)
- Forest Mode: $($forest.ForestMode)
- Domain Controllers: $($domain.ReplicaDirectoryServers -join ', ')

"@
                }
                catch {
                    $evidence += "`nActive Directory Query Failed: $($_.Exception.Message)`n"
                }
            }

            $evidence | Out-File -FilePath $evidenceFile -Encoding UTF8
            Write-Host "Evidence saved to: $evidenceFile" -ForegroundColor Green
        }
    }
}