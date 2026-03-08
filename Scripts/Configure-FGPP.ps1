# Configure-FGPP.ps1
# Creates and assigns Fine-Grained Password Policy for privileged accounts

$PolicyName = "BB-DomainAdmins-PasswordPolicy"
$TargetGroup = "GG-Domain-Admins"

New-ADFineGrainedPasswordPolicy `
-Name $PolicyName `
-Precedence 1 `
-MinPasswordLength 15 `
-PasswordHistoryCount 24 `
-ComplexityEnabled $true `
-MaxPasswordAge (New-TimeSpan -Days 30)

Add-ADFineGrainedPasswordPolicySubject `
-Identity $PolicyName `
-Subjects $TargetGroup