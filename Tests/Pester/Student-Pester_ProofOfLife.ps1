# Student Pester test suite
# Validates:
# - OU governance structure exists in correct locations
# - Security groups exist in correct OUs
# - DSC-created users exist in correct OUs and are ENABLED
# - Security-relevant GPOs exist and are linked to the correct OUs (enabled links)
#   (checks both direct links and inherited links to avoid false negatives)

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

        # Cache GPO existence early (these should throw if names are wrong)
        $script:ComputerGpo = Get-GPO -Name $script:ComputerGpoName -ErrorAction Stop
        $script:UserGpo     = Get-GPO -Name $script:UserGpoName     -ErrorAction Stop

        function Assert-UserInOuAndEnabled {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)][string]$Identity,
                [Parameter(Mandatory)][string]$ExpectedOuDn
            )

            $u = Get-ADUser -Identity $Identity -Properties Enabled, DistinguishedName -ErrorAction Stop

            # Validate OU placement (avoid brittle "CN=..." equality)
            $escapedOu = [regex]::Escape(",$ExpectedOuDn")
            $u.DistinguishedName | Should -Match "$escapedOu$"

            $u.Enabled | Should -BeTrue
        }

        function Resolve-GpoLinkByDisplayName {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)][string]$TargetDn,
                [Parameter(Mandatory)][string]$GpoDisplayName
            )

            $inherit = Get-GPInheritance -Target $TargetDn -ErrorAction Stop
            $links   = @($inherit.GpoLinks + $inherit.InheritedGpoLinks) | Where-Object { $_ }

            # Regex for GUIDs with/without braces
            $guidRegex = '\{?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}?'

            foreach ($l in $links) {

                # 1) Try to find any GUID-looking value in ANY property value
                $candidateStrings = @()

                foreach ($p in $l.PSObject.Properties) {
                    if ($null -eq $p.Value) { continue }

                    # Flatten scalars / arrays into strings safely
                    if ($p.Value -is [System.Collections.IEnumerable] -and -not ($p.Value -is [string])) {
                        foreach ($item in $p.Value) {
                            if ($null -ne $item) { $candidateStrings += [string]$item }
                        }
                    } else {
                        $candidateStrings += [string]$p.Value
                    }
                }

                # Also add a full string dump as a last resort (covers nested objects)
                $candidateStrings += ($l | Out-String)

                $match = $candidateStrings |
                    Select-String -Pattern $guidRegex -AllMatches |
                    ForEach-Object { $_.Matches } |
                    Select-Object -First 1

                if (-not $match) { continue }

                $guidText = $match.Value.Trim('{}')

                # 2) Resolve GUID back to a GPO and compare DisplayName
                try {
                    $gpo = Get-GPO -Guid $guidText -ErrorAction Stop
                    if ($gpo.DisplayName -eq $GpoDisplayName) {
                        # Return the original link object (so we can check Enabled/Enforced)
                        return $l
                    }
                } catch {
                    continue
                }
            }

            return $null
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
            Assert-UserInOuAndEnabled -Identity 'adam.khan' -ExpectedOuDn $script:UsersOU
        }

        It 'katy.smith should exist in UserAccessPlane\Users and be enabled' {
            Assert-UserInOuAndEnabled -Identity 'katy.smith' -ExpectedOuDn $script:UsersOU
        }

        It 'ismail.admin should exist in ManagementPlane\AdminUsers and be enabled' {
            Assert-UserInOuAndEnabled -Identity 'ismail.admin' -ExpectedOuDn $script:AdminUsersOU
        }

        It 'paul.evans should exist in ManagementPlane\AdminUsers and be enabled' {
            Assert-UserInOuAndEnabled -Identity 'paul.evans' -ExpectedOuDn $script:AdminUsersOU
        }
    }

    # ---------- GPOs ----------
    Describe 'Student GPO Security Baseline' {

        It 'Computer baseline GPO should exist' {
            $script:ComputerGpo.DisplayName | Should -Be $script:ComputerGpoName
        }

        It 'User hardening GPO should exist' {
            $script:UserGpo.DisplayName | Should -Be $script:UserGpoName
        }

        It 'Computer baseline GPO should be linked to UserAccessPlane\Computers OU (enabled link)' {
            $link = Resolve-GpoLinkByDisplayName -TargetDn $script:ComputersOU -GpoDisplayName $script:ComputerGpoName
            $link | Should -Not -BeNullOrEmpty
            $link.Enabled | Should -BeTrue
        }

        It 'User hardening GPO should be linked to UserAccessPlane\Users OU (enabled link)' {
            $link = Resolve-GpoLinkByDisplayName -TargetDn $script:UsersOU -GpoDisplayName $script:UserGpoName
            $link | Should -Not -BeNullOrEmpty
            $link.Enabled | Should -BeTrue
        }

        It 'GPO links should not be enforced (best practice for scoped OUs)' {
            $compLink = Resolve-GpoLinkByDisplayName -TargetDn $script:ComputersOU -GpoDisplayName $script:ComputerGpoName
            $compLink | Should -Not -BeNullOrEmpty
            $compLink.Enforced | Should -BeFalse

            $userLink = Resolve-GpoLinkByDisplayName -TargetDn $script:UsersOU -GpoDisplayName $script:UserGpoName
            $userLink | Should -Not -BeNullOrEmpty
            $userLink.Enforced | Should -BeFalse
        }
    }
}