# This Pester test suite verifies the existence of the
# Organizational Units (OUs) defined in the governance structure.
#
# It uses Get-ADOrganizationalUnit to query each OU
# and asserts that it exists with the expected name.
#
# The test fails if any OU is missing or incorrectly named,
# providing clear feedback about misconfiguration. 

Describe 'Student OU Governance Structure' {

    Describe 'Student OU Governance Structure' {

    $DomainDN = 'DC=bolton,DC=corp'

    It 'ControlPlane OU should exist' {
        (Get-ADOrganizationalUnit -Identity "OU=ControlPlane,$DomainDN" -ErrorAction Stop).Name |
            Should -Be 'ControlPlane'
    }

    It 'ManagementPlane OU should exist' {
        (Get-ADOrganizationalUnit -Identity "OU=ManagementPlane,$DomainDN" -ErrorAction Stop).Name |
            Should -Be 'ManagementPlane'
    }

    It 'UserAccessPlane OU should exist' {
        (Get-ADOrganizationalUnit -Identity "OU=UserAccessPlane,$DomainDN" -ErrorAction Stop).Name |
            Should -Be 'UserAccessPlane'
    }

    It 'Users OU should exist under UserAccessPlane' {
        (Get-ADOrganizationalUnit -Identity "OU=Users,OU=UserAccessPlane,$DomainDN" -ErrorAction Stop).Name |
            Should -Be 'Users'
    }

    It 'Computers OU should exist under UserAccessPlane' {
        (Get-ADOrganizationalUnit -Identity "OU=Computers,OU=UserAccessPlane,$DomainDN" -ErrorAction Stop).Name |
            Should -Be 'Computers'
    }
}