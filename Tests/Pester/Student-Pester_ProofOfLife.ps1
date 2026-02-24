# Student Pester test suite
# Validates:
# - OU governance structure exists in correct locations
# - Security groups exist in correct OUs
# - DSC-created users exist in correct OUs and are ENABLED (per StudentConfig change)
# - Security-relevant GPOs exist and are linked to the correct OUs (enabled links)

Describe 'Student OU Governance Structure' {

    BeforeAll {
        Import-Module ActiveDirectory -ErrorAction Stop
        Import-Module GroupPolicy     -ErrorAction Stop

        $script:DomainDN = (Get-ADDomain -ErrorAction Stop).DistinguishedName.Trim()

        $script:UserAccessPlaneDN = "OU=UserAccessPlane,$($script:DomainDN)"
        $script:UsersOU           = "OU=Users,OU=UserAccessPlane,$($script:DomainDN)"
        $script:ComputersOU       = "OU=Computers,OU=UserAccessPlane,$($script:DomainDN)"
        $script:UAPGroupsOU       = "OU=Groups,OU=UserAccessPlane,$($script:DomainDN)"

        $script:ManagementPlaneDN = "OU=ManagementPlane,$($script:DomainDN)"
        $script:AdminUsersOU      = "OU=AdminUsers,OU=ManagementPlane,$($script:DomainDN)"
        $script:MgmtGroupsOU      = "OU=Groups,OU=ManagementPlane,$($script:DomainDN)"

        # --- Set these to your exact GPO DisplayNames ---
        $script:ComputerGpoName = 'BBZ-Computer-Baseline-Firewall-SMBv1'
        $script:UserGpoName     = 'BBZ-User-Hardening-Reduce-AttackSurface'
    }

    # ---------- OUs ----------
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
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=Users)" -SearchBase $script:UserAccessPlaneDN -ErrorAction Stop).DistinguishedName |
            Should -Be $script:UsersOU
    }

    It 'Computers OU should exist under UserAccessPlane' {
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=Computers)" -SearchBase $script:UserAccessPlaneDN -ErrorAction Stop).DistinguishedName |
            Should -Be $script:ComputersOU
    }

    It 'Groups OU should exist under UserAccessPlane' {
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=Groups)" -SearchBase $script:UserAccessPlaneDN -ErrorAction Stop).DistinguishedName |
            Should -Be $script:UAPGroupsOU
    }

    It 'AdminUsers OU should exist under ManagementPlane' {
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=AdminUsers)" -SearchBase $script:ManagementPlaneDN -ErrorAction Stop).DistinguishedName |
            Should -Be $script:AdminUsersOU
    }

    It 'Groups OU should exist under ManagementPlane' {
        (Get-ADOrganizationalUnit -LDAPFilter "(ou=Groups)" -SearchBase $script:ManagementPlaneDN -ErrorAction Stop).DistinguishedName |
            Should -Be $script:MgmtGroupsOU
    }

    # ---------- Groups ----------
    It 'GG-HR-Staff should exist under UserAccessPlane\Groups' {
        (Get-ADGroup -LDAPFilter "(cn=GG-HR-Staff)" -SearchBase $script:UAPGroupsOU -ErrorAction Stop).DistinguishedName |
            Should -Be "CN=GG-HR-Staff,$($script:UAPGroupsOU)"
    }

    It 'GG-Finance-Staff should exist under UserAccessPlane\Groups' {
        (Get-ADGroup -LDAPFilter "(cn=GG-Finance-Staff)" -SearchBase $script:UAPGroupsOU -ErrorAction Stop).DistinguishedName |
            Should -Be "CN=GG-Finance-Staff,$($script:UAPGroupsOU)"
    }

    It 'GG-IT-Admins should exist under ManagementPlane\Groups' {
        (Get-ADGroup -LDAPFilter "(cn=GG-IT-Admins)" -SearchBase $script:MgmtGroupsOU -ErrorAction Stop).DistinguishedName |
            Should -Be "CN=GG-IT-Admins,$($script:MgmtGroupsOU)"
    }

    It 'GG-Server-Admins should exist under ManagementPlane\Groups' {
        (Get-ADGroup -LDAPFilter "(cn=GG-Server-Admins)" -SearchBase $script:MgmtGroupsOU -ErrorAction Stop).DistinguishedName |
            Should -Be "CN=GG-Server-Admins,$($script:MgmtGroupsOU)"
    }

    # ---------- Users ----------
    Describe 'User Provisioning via DSC' {

        It 'adam.khan should exist in UserAccessPlane\Users and be enabled' {
            $u = Get-ADUser -Identity 'adam.khan' -Properties Enabled, DistinguishedName
            $u.DistinguishedName | Should -Be "CN=adam.khan,$($script:UsersOU)"
            $u.Enabled | Should -BeTrue
        }

        It 'katy.smith should exist in UserAccessPlane\Users and be enabled' {
            $u = Get-ADUser -Identity 'katy.smith' -Properties Enabled, DistinguishedName
            $u.DistinguishedName | Should -Be "CN=katy.smith,$($script:UsersOU)"
            $u.Enabled | Should -BeTrue
        }

        It 'ismail.admin should exist in ManagementPlane\AdminUsers and be enabled' {
            $u = Get-ADUser -Identity 'ismail.admin' -Properties Enabled, DistinguishedName
            $u.DistinguishedName | Should -Be "CN=ismail.admin,$($script:AdminUsersOU)"
            $u.Enabled | Should -BeTrue
        }

        It 'paul.evans should exist in ManagementPlane\AdminUsers and be enabled' {
            $u = Get-ADUser -Identity 'paul.evans' -Properties Enabled, DistinguishedName
            $u.DistinguishedName | Should -Be "CN=paul.evans,$($script:AdminUsersOU)"
            $u.Enabled | Should -BeTrue
        }
    }

    # ---------- GPOs ----------
    Describe 'Student GPO Security Baseline' {

        It 'Computer baseline GPO should exist' {
            (Get-GPO -Name $script:ComputerGpoName -ErrorAction Stop).DisplayName |
                Should -Be $script:ComputerGpoName
        }

        It 'User hardening GPO should exist' {
            (Get-GPO -Name $script:UserGpoName -ErrorAction Stop).DisplayName |
                Should -Be $script:UserGpoName
        }

        It 'Computer baseline GPO should be linked to UserAccessPlane\Computers OU (enabled link)' {
            $links = (Get-GPInheritance -Target $script:ComputersOU -ErrorAction Stop).GpoLinks

            $link = $links | Where-Object { $_.DisplayName -eq $script:ComputerGpoName } | Select-Object -First 1
            $link | Should -Not -BeNullOrEmpty
            $link.Enabled | Should -BeTrue
        }

        It 'User hardening GPO should be linked to UserAccessPlane\Users OU (enabled link)' {
            $links = (Get-GPInheritance -Target $script:UsersOU -ErrorAction Stop).GpoLinks

            $link = $links | Where-Object { $_.DisplayName -eq $script:UserGpoName } | Select-Object -First 1
            $link | Should -Not -BeNullOrEmpty
            $link.Enabled | Should -BeTrue
        }

        It 'GPO links should not be enforced (best practice for scoped OUs)' {
            $compLinks = (Get-GPInheritance -Target $script:ComputersOU -ErrorAction Stop).GpoLinks
            $userLinks = (Get-GPInheritance -Target $script:UsersOU -ErrorAction Stop).GpoLinks

            ($compLinks | Where-Object DisplayName -eq $script:ComputerGpoName | Select-Object -First 1).Enforced | Should -BeFalse
            ($userLinks | Where-Object DisplayName -eq $script:UserGpoName     | Select-Object -First 1).Enforced | Should -BeFalse
        }
    }
}