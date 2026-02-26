# Student Pester test suite
# Validates:
# - OU governance structure exists in correct locations
# - Security groups exist in correct OUs
# - DSC-created users exist in correct OUs and are ENABLED
# - Security-relevant GPOs exist and are linked to the correct OUs (enabled links)
#   (checks both direct links and inherited links to avoid false negatives)
# Checks correct membership of users in security groups to validate DSC provisioning and RBAC design
# FIX:
# - GroupPolicy loads via WinPSCompatSession -> deserialized objects
# - Therefore we normalize GUID strings before comparing GpoId to GPO.Id

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

        function Normalize-GuidString {
            param([Parameter(Mandatory)][object]$Value)
            $s = [string]$Value
            $s = $s.Trim()
            $s = $s.TrimStart('{').TrimEnd('}')
            return $s.ToLowerInvariant()
        }

        function Find-GpoLink {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)][string]$TargetDn,
                [Parameter(Mandatory)][string]$GpoDisplayName
            )

            $gpo = Get-GPO -Name $GpoDisplayName -ErrorAction Stop
            $gpoGuid = Normalize-GuidString $gpo.Id

            $inherit = Get-GPInheritance -Target $TargetDn -ErrorAction Stop
            $links   = @($inherit.GpoLinks + $inherit.InheritedGpoLinks)

            $match = $links | Where-Object {
                $linkGuid = Normalize-GuidString $_.GpoId
                $linkGuid -eq $gpoGuid
            } | Select-Object -First 1

            return $match
        }
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
            $u = Get-ADUser -Identity 'adam.khan' -Properties Enabled, DistinguishedName -ErrorAction Stop
            $u.DistinguishedName | Should -Match ([regex]::Escape(",$($script:UsersOU)") + '$')
            $u.Enabled | Should -BeTrue
        }

        It 'katy.smith should exist in UserAccessPlane\Users and be enabled' {
            $u = Get-ADUser -Identity 'katy.smith' -Properties Enabled, DistinguishedName -ErrorAction Stop
            $u.DistinguishedName | Should -Match ([regex]::Escape(",$($script:UsersOU)") + '$')
            $u.Enabled | Should -BeTrue
        }

        It 'ismail.admin should exist in ManagementPlane\AdminUsers and be enabled' {
            $u = Get-ADUser -Identity 'ismail.admin' -Properties Enabled, DistinguishedName -ErrorAction Stop
            $u.DistinguishedName | Should -Match ([regex]::Escape(",$($script:AdminUsersOU)") + '$')
            $u.Enabled | Should -BeTrue
        }

        It 'paul.evans should exist in ManagementPlane\AdminUsers and be enabled' {
            $u = Get-ADUser -Identity 'paul.evans' -Properties Enabled, DistinguishedName -ErrorAction Stop
            $u.DistinguishedName | Should -Match ([regex]::Escape(",$($script:AdminUsersOU)") + '$')
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
            $link = Find-GpoLink -TargetDn $script:ComputersOU -GpoDisplayName $script:ComputerGpoName
            $link | Should -Not -BeNullOrEmpty
            $link.Enabled | Should -BeTrue
        }

        It 'User hardening GPO should be linked to UserAccessPlane\Users OU (enabled link)' {
            $link = Find-GpoLink -TargetDn $script:UsersOU -GpoDisplayName $script:UserGpoName
            $link | Should -Not -BeNullOrEmpty
            $link.Enabled | Should -BeTrue
        }

        It 'GPO links should not be enforced (best practice for scoped OUs)' {
            $compLink = Find-GpoLink -TargetDn $script:ComputersOU -GpoDisplayName $script:ComputerGpoName
            $compLink | Should -Not -BeNullOrEmpty
            $compLink.Enforced | Should -BeFalse

            $userLink = Find-GpoLink -TargetDn $script:UsersOU -GpoDisplayName $script:UserGpoName
            $userLink | Should -Not -BeNullOrEmpty
            $userLink.Enforced | Should -BeFalse
        }
    }

    # ---------- Memberships ----------
    Describe 'RBAC Group Memberships' {

        It 'katy.smith should be a member of GG-HR-Staff' {
            $m = Get-ADGroupMember -Identity 'GG-HR-Staff' -Recursive | Where-Object { $_.SamAccountName -eq 'katy.smith' }
            $m | Should -Not -BeNullOrEmpty
        }

        It 'adam.khan should be a member of GG-Finance-Staff' {
            $m = Get-ADGroupMember -Identity 'GG-Finance-Staff' -Recursive | Where-Object { $_.SamAccountName -eq 'adam.khan' }
            $m | Should -Not -BeNullOrEmpty
        }

        It 'ismail.admin should be a member of GG-IT-Admins' {
            $m = Get-ADGroupMember -Identity 'GG-IT-Admins' -Recursive | Where-Object { $_.SamAccountName -eq 'ismail.admin' }
            $m | Should -Not -BeNullOrEmpty
        }

        It 'paul.evans should be a member of GG-Server-Admins' {
            $m = Get-ADGroupMember -Identity 'GG-Server-Admins' -Recursive | Where-Object { $_.SamAccountName -eq 'paul.evans' }
            $m | Should -Not -BeNullOrEmpty
        }
    }
}