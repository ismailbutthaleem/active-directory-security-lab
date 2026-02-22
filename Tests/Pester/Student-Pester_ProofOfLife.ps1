# This Pester test suite verifies the existence of the
# Organizational Units (OUs) defined in the governance structure.
#
# It uses Get-ADOrganizationalUnit to query each OU
# and asserts that it exists with the expected name.
#
# The test fails if any OU is missing or incorrectly named,
# providing clear feedback about misconfiguration.
 
Describe 'Student OU Governance Structure' {

    $DomainDN = (Get-ADDomain).DistinguishedName

    It 'ControlPlane OU should exist' {
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=ControlPlane)" -SearchBase $DomainDN -ErrorAction Stop).DistinguishedName |
            Should -Match "OU=ControlPlane,$DomainDN"
    }

    It 'ManagementPlane OU should exist' {
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=ManagementPlane)" -SearchBase $DomainDN -ErrorAction Stop).DistinguishedName |
            Should -Match "OU=ManagementPlane,$DomainDN"
    }

    It 'UserAccessPlane OU should exist' {
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=UserAccessPlane)" -SearchBase $DomainDN -ErrorAction Stop).DistinguishedName |
            Should -Match "OU=UserAccessPlane,$DomainDN"
    }

    It 'Users OU should exist under UserAccessPlane' {
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=Users)" -SearchBase "OU=UserAccessPlane,$DomainDN" -ErrorAction Stop).DistinguishedName |
            Should -Match "OU=Users,OU=UserAccessPlane,$DomainDN"
    }

    It 'Computers OU should exist under UserAccessPlane' {
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=Computers)" -SearchBase "OU=UserAccessPlane,$DomainDN" -ErrorAction Stop).DistinguishedName |
            Should -Match "OU=Computers,OU=UserAccessPlane,$DomainDN"
    }
}