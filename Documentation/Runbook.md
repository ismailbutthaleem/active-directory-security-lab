Runbook (Student)

Keep a dated log of:

what was changed

what was executed (commands)

where evidence is stored (paths)

Runbook – Development Log (Student)

This document records how the environment was actually built, what issues were encountered, how they were resolved, and where evidence was stored.

This is not the final professional system documentation.
It reflects the development process and troubleshooting journey.

1. Initial Environment Preparation

The project started with setting up the Windows Server VM and preparing the networking correctly before attempting any domain promotion.

The internal adapter was configured with a static IP address. The NAT adapter was left for internet access but later configured not to register in DNS to avoid duplicate or incorrect records.

Early on, module installation became the first obstacle.

2. Module Installation Issues

Installing required DSC modules using the normal method did not work immediately.

Running:

Install-Module ActiveDirectoryDsc

either failed or did not behave as expected.

Issues encountered included:

PowerShellGet not behaving correctly

NuGet provider prompts

Repository trust issues

Modules installing but not being recognised

To resolve this:

TLS 1.2 was enforced

PowerShellGet was updated

Modules were installed using -Scope CurrentUser

In some cases -Force or -AllowClobber was required

Modules were verified using:

Get-Module -ListAvailable

It became clear that simply installing a module does not mean it is available in every shell context.

Evidence stored in:

.\Evidence\Screenshots\
.\Evidence\Transcripts\
3. PowerShell 7 vs Windows PowerShell Confusion

Another issue occurred when running AD-related commands.

Inside PowerShell 7 (pwsh), commands such as:

Get-ADUser

were not recognised.

However, running the same command inside Windows PowerShell 5.1 (powershell.exe) worked immediately.

This happened because:

The ActiveDirectory module is built for Windows PowerShell

It is not fully native to PowerShell 7

Compatibility loading is required

The solution was to perform AD management tasks inside Windows PowerShell 5.1.

This clarified the difference between the shells and prevented further confusion during validation.

4. PATH and Shell Recognition Issues

At one stage, pwsh itself was not recognised after installation.

Although PowerShell 7 had been installed, it was not available in PATH.

This caused commands to fail until the system PATH variable was corrected and verified.

Shell context became important throughout development, especially when running DSC and AD cmdlets.

5. Pre-Promotion Troubleshooting Phase

Before domain promotion successfully completed, several environment issues needed to be resolved.

5.1 Network Adapter Confusion

There was confusion between:

Host-only adapter (internal)

NAT adapter (internet)

Which adapter DNS should point to

Why 127.0.0.1 appeared in some outputs

Key clarifications:

The internal adapter must use a static IP

The Domain Controller must point to itself for DNS

NAT adapter should not register in DNS

DNS was validated using:

dcdiag /test:dns

After adjusting adapter settings, name resolution stabilised.

5.2 AD DS Role vs Promotion

There was initial confusion between:

Installing AD DS role

Promoting the server to a Domain Controller

Checking:

Get-WindowsFeature AD-Domain-Services

showed the role was installed, but that does not mean the server is a DC.

Promotion is triggered during the DSC configuration stage.

This distinction became clearer after reviewing the sequence of events during BuildMain.

6. First Successful Domain Promotion

Running:

.\BuildMain.ps1
Start-DscConfiguration -Path .\DSC\Outputs -Wait -Verbose -Force

initiated the full configuration.

During promotion, the server rebooted automatically as expected.

However, post-reboot, another issue appeared.

7. Network Profile Conflict After Promotion

After promotion, the network profile changed to DomainAuthenticated.

DSC was still attempting to enforce a Private profile.

Running:

Get-NetConnectionProfile

confirmed that the profile could not be changed manually.

This caused the DSC configuration to fail.

Resolution involved adjusting the network configuration logic so it would not attempt to change the profile after promotion.

After modification, the configuration completed successfully.

8. AD Cmdlet Not Recognised During Build

While running BuildMain, errors appeared suggesting that AD commands such as Get-ADUser were not recognised.

This was traced back to shell usage.

The commands were being executed in PowerShell 7 instead of Windows PowerShell 5.1.

Switching to Windows PowerShell resolved the issue.

Module availability was confirmed using:

Get-Module -ListAvailable ActiveDirectory

9. User Account Enablement and Password Complexity Issue

During domain promotion and early validation, an issue occurred where DSC reported that the password did not meet complexity requirements.

The error appeared during the user provisioning stage while running:

.\BuildMain.ps1

The configuration would fail with a message indicating that the supplied password did not satisfy domain password policy requirements.

Initially, the assumption was that password policy settings inside Active Directory were preventing user creation. Attempts were made to review and adjust password-related settings within AD.

However, the issue was not caused by domain password policy.

After reviewing the configuration file, it was identified that the line:

Enabled = $true

was missing from the user resource definition in the DSC configuration.

This meant:

The user object was being created

But not explicitly enabled in the configuration

Leading to inconsistent state during validation

After correcting the configuration and ensuring Enabled = $true was included for the user resource, DSC completed successfully and domain promotion finalised correctly.

Post-Promotion Validation Issue

After successful promotion and configuration completion, validation was performed using:

Get-ADUser -Identity <Username> -Properties Enabled

The result returned:

Enabled : False

Even though the desired state specified the account should be enabled.

Attempting to enable the user manually using:

Enable-ADAccount -Identity <Username>

resulted in an error stating that the account required a password before it could be enabled.

This clarified that:

An AD user cannot be enabled without a valid password

DSC desired state alone does not override AD security requirements

Password must be set before enabling the account

The issue was resolved by setting a compliant password:

Set-ADAccountPassword -Identity <Username> -Reset -NewPassword (ConvertTo-SecureString "Bolton!1" -AsPlainText -Force)
Enable-ADAccount -Identity <Username>

After this, validation using:

Get-ADUser -Identity <Username> -Properties Enabled

returned:

Enabled : True
Security Consideration

Hardcoding passwords directly inside the DSC configuration file was avoided.

Instead, passwords were set within the Active Directory environment after promotion.

This approach:

Avoided storing plaintext credentials in configuration

Reduced exposure of sensitive data

Aligned more closely with security best practices

This issue highlighted the interaction between:

Domain password complexity rules

Account state (Enabled vs Disabled)

DSC desired configuration

Active Directory enforcement behaviour

10. Custom Pester GPO Link Failure

During execution of the custom student Pester suite, an assertion failure reported that a GPO was not linked to the expected OU.

The test was checking:

GPO existence

Correct OU scope

Link status

Investigation involved checking:

Get-GPInheritance -Target "OU=UserAccessPlane,DC=bolton,DC=corp"

It was confirmed that the GPO was either linked at the wrong level or not linked directly.

The link was corrected to the appropriate OU and verified as Enabled.

After correction, Pester was re-run and passed successfully.

This reinforced the importance of validating scope, not just existence.

11. GPG Commit Signing Issue

When configuring Git commit signing, the original GPG key was unusable because the passphrase had not been saved securely.

This prevented signed commits from functioning.

A new GPG key was generated and configured with:

git config --global user.signingkey <keyID>
git config --global commit.gpgsign true

This was important for:

Validating commit authorship

Following industry best practice

Supporting provenance requirements

After configuration, signed commits worked correctly.

12. Idempotence Verification

After stabilising the build, the configuration was re-run:

Start-DscConfiguration -Path .\DSC\Outputs -Wait -Verbose

No duplicate OUs, users, or groups were created.

Pester validation confirmed the system remained compliant with the defined baseline.

This confirmed that the configuration converges correctly.

13. Evidence Storage

Throughout development, evidence was stored under:

.\Evidence\Pester\
.\Evidence\Transcripts\
.\Evidence\HealthChecks\
.\DSC\Outputs\
.\Evidence\Screenshots\

Both tutor and student Pester suites passed in the final stable state.

Final State

Domain bolton.corp deployed

OU governance model applied

Security groups provisioned

Users created

Baseline GPOs linked correctly

DNS stabilised

Custom and tutor Pester suites passing

Configuration re-run safe

14. Windows Client Integration

Got it — I’ll continue exactly in your tone: technical, development-log style, not polished like an essay, and not AI sounding. I’ll only finish section 14 and close the runbook, keeping the same structure you used.

14. Windows Client Integration

After the Domain Controller was stable, a Windows client was integrated into the domain through DSC.

The Windows 10 client DNS was redirected so that the primary DNS server pointed to the Domain Controller. This is required because domain join relies on SRV record discovery, which only exists on the internal AD DNS server.

The client node was already defined in the configuration data file under:

DSC\Data\AllNodes.psd1

The node role was defined as:

Role = 'Client'

The DSC configuration logic inside StudentConfig.ps1 contains a separate block that handles client nodes.

This block performs:

Domain join

Placement of the computer object inside the correct OU

Creation of a proof-of-life file to demonstrate that the client applied its own configuration.

During the build process the configuration compiled a separate MOF file for the Windows client.

This file was generated inside:

DSC\Outputs\StudentBaseline\

File generated:

Windows10.mof

This confirms that DSC compiled a separate configuration for the client node.

The intended process was for the Domain Controller to push this configuration to the client automatically through WinRM.

However, the push transport did not complete successfully.

This was most likely caused by:

WinRM configuration on the client

Firewall restrictions

Transport configuration limitations between the machines

Because of this, the configuration was applied manually on the client.

The MOF file was copied to the Windows client machine using a shared folder between the VMs.

On the Windows client, the configuration was applied locally using:

Start-DscConfiguration -Path C:\Temp -Wait -Verbose -Force

This allowed the Local Configuration Manager (LCM) on the client to read and apply the desired state.

After execution, the client successfully joined the bolton.corp domain.

Validation steps included checking:

whoami

which returned:

BOLTON\<username>

confirming the machine was operating within the domain context.

Group Policy application was also verified using:

gpresult /r

and

gpresult /h gpresult.html

These confirmed that the baseline GPOs applied correctly once the client was placed inside the correct OU.

Evidence stored in:

Evidence\Transcripts\client-session_windows10.txt
Evidence\AD\gpresult_adam.kahan_windowsclient.txt
Evidence\AD\gpresult.html

A proof-of-life file created by DSC on the client was also verified.

This file confirms that the client node applied its own configuration.

Evidence stored in:

Evidence\HealthChecks\03-DSC-Applied.txt

This stage demonstrated that DSC can manage multiple nodes using a single configuration, where each node receives its own compiled MOF file.

15. Final Validation and System State

After the infrastructure build and client integration were completed, the system was validated using the Pester testing framework.

The tutor validation suite was executed first to confirm that the required environment state matched the assignment specification.

Command executed:

Invoke-Validation

All tutor tests passed successfully.

Additional student tests were also executed to validate specific design decisions implemented in the environment.

These tests verified:

OU placement

RBAC group structure

User creation through data-driven configuration

Delegation behaviour

Command executed:

Invoke-Pester

Both the tutor and student Pester suites returned successful results.

Evidence stored in:

Evidence\Pester\
16. Final Environment Summary

The final system state after completion of the build was:

Active Directory forest bolton.corp successfully deployed.

Single Domain Controller operational.

OU governance model implemented:

ControlPlane

ManagementPlane

UserAccessPlane

Security groups provisioned for RBAC:

GG-HR-Staff

GG-Finance-Staff

GG-IT-Admins

GG-Server-Admins

GG-Domain-Admins

Users created and placed in the correct OU scopes.

Delegation implemented and validated using RBAC groups.

Fine Grained Password Policy applied to privileged group.

Baseline security GPOs implemented and linked to the appropriate OUs.

Windows client successfully joined to the domain.

Group Policy enforcement validated using gpresult.

DNS resolution stabilised through correct NIC configuration.

Both tutor and student Pester suites passing.

DSC configuration verified as idempotent through multiple re-runs.

All evidence captured and stored inside the repository under the Evidence directory