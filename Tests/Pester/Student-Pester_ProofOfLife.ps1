# This Pester test suite verifies the existence of the
# Organizational Units (OUs) defined in the governance structure.
#
# It uses Get-ADOrganizationalUnit to query each OU
# and asserts that it exists with the expected name.
#
# The test fails if any OU is missing or incorrectly named,
# providing clear feedback about misconfiguration.

# Uses Get-ADOrganizationalUnit to assert correct creation and location.
# Fails if any OU is missing or incorrectly placed.

Describe 'Student OU Governance Structure' {

    BeforeAll {
        Import-Module ActiveDirectory -ErrorAction Stop
        $script:DomainDN = (Get-ADDomain -ErrorAction Stop).DistinguishedName.Trim()
    }

    It 'ControlPlane OU should exist' {
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=ControlPlane)" -SearchBase $script:DomainDN -ErrorAction Stop).DistinguishedName |
            Should -Be "OU=ControlPlane,$($script:DomainDN)"
    }

    It 'ManagementPlane OU should exist' {
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=ManagementPlane)" -SearchBase $script:DomainDN -ErrorAction Stop).DistinguishedName |
            Should -Be "OU=ManagementPlane,$($script:DomainDN)"
    }

    It 'UserAccessPlane OU should exist' {
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=UserAccessPlane)" -SearchBase $script:DomainDN -ErrorAction Stop).DistinguishedName |
            Should -Be "OU=UserAccessPlane,$($script:DomainDN)"
    }

    It 'Users OU should exist under UserAccessPlane' {
        $base = "OU=UserAccessPlane,$($script:DomainDN)"
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=Users)" -SearchBase $base -ErrorAction Stop).DistinguishedName |
            Should -Be "OU=Users,OU=UserAccessPlane,$($script:DomainDN)"
    }

    It 'Computers OU should exist under UserAccessPlane' {
        $base = "OU=UserAccessPlane,$($script:DomainDN)"
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=Computers)" -SearchBase $base -ErrorAction Stop).DistinguishedName |
            Should -Be "OU=Computers,OU=UserAccessPlane,$($script:DomainDN)"
    }

    It 'Groups OU should exist under UserAccessPlane' {
        $base = "OU=UserAccessPlane,$($script:DomainDN)"
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=Groups)" -SearchBase $base -ErrorAction Stop).DistinguishedName |
            Should -Be "OU=Groups,OU=UserAccessPlane,$($script:DomainDN)"
    }

    It 'AdminUsers OU should exist under ManagementPlane' {
        $base = "OU=ManagementPlane,$($script:DomainDN)"
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=AdminUsers)" -SearchBase $base -ErrorAction Stop).DistinguishedName |
            Should -Be "OU=AdminUsers,OU=ManagementPlane,$($script:DomainDN)"
    }
    It 'Groups OU should exist under ManagementPlane' {
        $base = "OU=ManagementPlane,$($script:DomainDN)"
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=Groups)" -SearchBase $base -ErrorAction Stop).DistinguishedName |
            Should -Be "OU=Groups,OU=ManagementPlane,$($script:DomainDN)"
    }
}