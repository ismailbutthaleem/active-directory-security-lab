# Configure-GPOs.ps1
# Creates and links security GPOs for the BarmBuzz AD environment

$DomainDN     = (Get-ADDomain).DistinguishedName
$UsersOU      = "OU=Users,OU=UserAccessPlane,$DomainDN"
$ComputersOU  = "OU=Computers,OU=UserAccessPlane,$DomainDN"

$GpoUser      = "BBZ-User-Hardening-Reduce-AttackSurface"
$GpoComputer  = "BBZ-Computer-Baseline-Firewall-SMBv1"

Write-Host "Domain DN: $DomainDN"
Write-Host "Users OU: $UsersOU"
Write-Host "Computers OU: $ComputersOU"

# ---------------- USER GPO ----------------
Write-Host "Creating and linking user hardening GPO..."
New-GPO -Name $GpoUser -ErrorAction SilentlyContinue | Out-Null
New-GPLink -Name $GpoUser -Target $UsersOU -LinkEnabled Yes -ErrorAction SilentlyContinue | Out-Null

# Disable CMD
Set-GPRegistryValue -Name $GpoUser `
  -Key "HKCU\Software\Policies\Microsoft\Windows\System" `
  -ValueName "DisableCMD" -Type DWord -Value 2

# Block Control Panel + Settings
Set-GPRegistryValue -Name $GpoUser `
  -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
  -ValueName "NoControlPanel" -Type DWord -Value 1

# ---------------- COMPUTER GPO ----------------
Write-Host "Creating and linking computer baseline GPO..."
New-GPO -Name $GpoComputer -ErrorAction SilentlyContinue | Out-Null
New-GPLink -Name $GpoComputer -Target $ComputersOU -LinkEnabled Yes -ErrorAction SilentlyContinue | Out-Null

# Enable Windows Firewall for Domain profile
Set-GPRegistryValue -Name $GpoComputer `
  -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\DomainProfile" `
  -ValueName "EnableFirewall" -Type DWord -Value 1

# Disable SMBv1
Set-GPRegistryValue -Name $GpoComputer `
  -Key "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" `
  -ValueName "SMB1" -Type DWord -Value 0

Write-Host "GPO configuration complete."