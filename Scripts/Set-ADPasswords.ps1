# Create secure password once
$SecurePass = ConvertTo-SecureString "Bolton!1" -AsPlainText -Force

# adam.khan
Set-ADAccountPassword -Identity "adam.khan" -Reset -NewPassword $SecurePass
Set-ADUser -Identity "adam.khan" -ChangePasswordAtLogon $false
Enable-ADAccount -Identity "adam.khan"

# katy.smith
Set-ADAccountPassword -Identity "katy.smith" -Reset -NewPassword $SecurePass
Set-ADUser -Identity "katy.smith" -ChangePasswordAtLogon $false
Enable-ADAccount -Identity "katy.smith"

# ismail.admin
Set-ADAccountPassword -Identity "ismail.admin" -Reset -NewPassword $SecurePass
Set-ADUser -Identity "ismail.admin" -ChangePasswordAtLogon $false
Enable-ADAccount -Identity "ismail.admin"

# paul.evans
Set-ADAccountPassword -Identity "paul.evans" -Reset -NewPassword $SecurePass
Set-ADUser -Identity "paul.evans" -ChangePasswordAtLogon $false
Enable-ADAccount -Identity "paul.evans"

# raul.alejandro
Set-ADAccountPassword -Identity "raul.alejandro" -Reset -NewPassword $SecurePass
Enable-ADAccount -Identity "raul.alejandro"

# Verification
Get-ADUser adam.khan,katy.smith,ismail.admin,paul.evans,raul.alejandro `
-Properties Enabled,PasswordLastSet |
Select SamAccountName, Enabled, PasswordLastSet