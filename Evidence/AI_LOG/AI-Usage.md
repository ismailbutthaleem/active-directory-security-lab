AI Usage Log (AI_LOG)

Record any AI/tool usage:

date/time

tool used

what it generated

what you changed afterwards

Week 1–2 Infrastructure, baseline readiness

Tool used: ChatGPT

AI provided theoretical explanations of:

Desired State Configuration (DSC) architecture
MOF compilation process
the role of the Local Configuration Manager (LCM)
how configuration data files (AllNodes.psd1) separate logic from data
basic structure for a DSC configuration file

AI also suggested an execution plan to start the deployment by calculating the days available for the student and the submission deadline, helping structure the order in which the infrastructure should be built.

AI helped debug grammar/spelling issues for commands used to install required packages/modules and recommended basic verification commands.

What AI generated (examples):

$PSVersionTable
Get-Module -ListAvailable
Get-DscLocalConfigurationManager

What the student changed afterwards / validated:

The student used AI explanations to understand what should be checked, then validated the environment manually and made final decisions based on the outputs.

Student then verified:

DSC modules were correctly installed
configuration data matched the environment
the configuration compiled successfully into MOF files
the baseline system configuration applied correctly before domain promotion

Example commands used by the student:

Get-Module -ListAvailable | Where-Object Name -match "ActiveDirectory|GroupPolicy|Pester|DesiredStateConfiguration"
Get-DscLocalConfigurationManager
.\Run_BuildMain.ps1
Get-ChildItem .\DSC\Outputs\StudentBaseline -Filter *.mof

Several steps were tested multiple times before continuing to the next stage of the deployment.

AI helped with commands to perform checks, however interpretation and final decision was made by the student.

Week 3–4 — Domain Controller Promotion and Active Directory Automation

Tool used: ChatGPT

AI helped investigate and explain the following concepts:

DNS adapter priority issues affecting domain join
WinRM transport issues when attempting DSC push to a client
PowerShell 7 vs Windows PowerShell 5.1 module compatibility
Kerberos authentication dependencies during Ubuntu integration

AI also helped explain the student configuration design, specifically that the deployment is data-driven (AllNodes.psd1) and the DSC configuration iterates through lists (OUs, users, groups, memberships).

The student then validated AI generation was correct and adequate to the environment and the brief requirements.

Example modification — user enablement handled in AllNodes.psd1 (not hardcoded)

During development, user creation through DSC initially caused a password/complexity-related failure during convergence.

AI suggested checking password complexity and changing how accounts were enabled during creation. The student analysed the error output and concluded that the correct fix in this data-driven design was to adjust the Users array in DSC\Data\AllNodes.psd1 and handle enablement in phases.

What AI generated (idea):
“Create accounts disabled first, set passwords, then enable and rerun.”

What the student changed afterwards (actual implementation in AllNodes.psd1):

Original values (enabled at creation):

Users = @(
    @{ UserName = 'adam.khan'      ; Path = 'OU=Users,OU=UserAccessPlane'      ; Enabled = $true ; MemberOf = @('GG-Finance-Staff') },
    @{ UserName = 'katy.smith'     ; Path = 'OU=Users,OU=UserAccessPlane'      ; Enabled = $true ; MemberOf = @('GG-HR-Staff') },
    @{ UserName = 'ismail.admin'   ; Path = 'OU=AdminUsers,OU=ManagementPlane' ; Enabled = $true ; MemberOf = @('GG-IT-Admins') },
    @{ UserName = 'paul.evans'     ; Path = 'OU=AdminUsers,OU=ManagementPlane' ; Enabled = $true ; MemberOf = @('GG-Server-Admins') },
    @{ UserName = 'raul.alejandro' ; Path = 'OU=AdminUsers,OU=ControlPlane'    ; Enabled = $true ; MemberOf = @('GG-Domain-Admins') }
)

Student changed to disabled for first convergence run:

Users = @(
    @{ UserName = 'adam.khan'      ; Path = 'OU=Users,OU=UserAccessPlane'      ; Enabled = $false ; MemberOf = @('GG-Finance-Staff') },
    @{ UserName = 'katy.smith'     ; Path = 'OU=Users,OU=UserAccessPlane'      ; Enabled = $false ; MemberOf = @('GG-HR-Staff') },
    @{ UserName = 'ismail.admin'   ; Path = 'OU=AdminUsers,OU=ManagementPlane' ; Enabled = $false ; MemberOf = @('GG-IT-Admins') },
    @{ UserName = 'paul.evans'     ; Path = 'OU=AdminUsers,OU=ManagementPlane' ; Enabled = $false ; MemberOf = @('GG-Server-Admins') },
    @{ UserName = 'raul.alejandro' ; Path = 'OU=AdminUsers,OU=ControlPlane'    ; Enabled = $false ; MemberOf = @('GG-Domain-Admins') }
)

The student then set passwords directly in AD (manual admin action) and later switched the entries back to:

Enabled = $true

and reran the build for convergence.

This kept the design consistent with the student’s data-driven approach and avoided changing password policy settings just to make the build “pass”.

Example validation commands

AI suggested verification commands for domain/forest and OU structure. The student ran the commands and interpreted the results.

Commands used:

Get-ADDomain
Get-ADForest
Get-ADOrganizationalUnit -Filter * | Select Name, DistinguishedName
dcdiag /v

The student captured outputs as evidence files and referenced them in the README.

Week 5 — Client Integration, Validation and Documentation

Tool used: ChatGPT

AI tools were used to structure the README according to the assignment rubric, ensure each rubric point was met, and assist with locating evidence files quickly (transcripts, Pester output, gpresult reports, health-check outputs).

AI also assisted with explaining why certain choices were “enterprise-correct” vs lab trade-offs (for example WinRM push limitations, MOF credential trade-offs, DNS adapter priority and time sync).

Example modification — Windows client join credential in MOF

A repeated failure occurred when joining the Windows client to the domain. The issue was that the MOF embedded the username as Administrator rather than a domain-qualified account, causing join failures and stale computer account password issues.

AI suggested checking the MOF for the username line and adjusting the orchestrator to build a domain-qualified credential for the client join.

What AI generated (idea):
“Client MOF should contain NetBIOS\Administrator not just Administrator.”

What the student changed afterwards (actual implementation):

The student updated Run_BuildMain.ps1 so the client join credential was built using the NetBIOS name from configuration data:

$ClientJoinCredential = New-Object System.Management.Automation.PSCredential(
    ("{0}\Administrator" -f $dcNode.DomainNetBIOSName),
    $AdminPassword
)

The student then verified the MOF contained the correct username by capturing the UserName = line to evidence:

Select-String -Path .\DSC\Outputs\StudentBaseline\Windows10.mof -Pattern 'UserName\s*=\s*'

The student manually copied the client MOF to the Windows client (shared folder) and applied it locally:

Start-DscConfiguration -Path C:\Temp -Wait -Verbose -Force

Then the student verified the domain join and GPO application using:

systeminfo | findstr /B /C:"Domain"
gpresult /r
gpresult /h C:\gpresult.html

Evidence outputs were then stored in the repository evidence structure and referenced in the README.

Academic Integrity Statement

AI tools were used only as a support mechanism for explanation, debugging guidance and documentation assistance.

AI occasionally provided command examples, debugging ideas and suggestions for DSC structure. The student did not blindly copy AI output. Any suggested step was first explained, reviewed and validated by the student before being executed.

All infrastructure deployment, configuration, troubleshooting, validation and testing was performed directly by the student inside the virtual lab environment. Every command executed was first reviewed and understood before being applied.

The resulting infrastructure, automation scripts, configuration logic, test results and documentation therefore represent the student’s own work, decisions and technical understanding.