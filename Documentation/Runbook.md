Runbook (Student)

Keep a dated log of:

what was changed

what was executed (commands)

where evidence is stored (paths)

1. Purpose

This runbook documents the build, validation and operational process of the Enterprise Active Directory Domain Services (AD DS) environment deployed using PowerShell Desired State Configuration (DSC).

The environment is designed to:

Automate the full AD build via DSC

Enforce a structured OU governance model

Provision security groups and users

Apply baseline GPO hardening

Validate configuration deterministically using Pester

The configuration can be recompiled and applied at any time to return the system to its defined baseline state.

2. Environment Overview
Component	Description
Operating System	Windows Server
Configuration Tool	PowerShell DSC
Validation Framework	Pester 5
Domain	bolton.corp
Domain Controller Role	Single DC deployment
Network Model	Static internal IP, NAT adapter not registered in DNS

The Domain Controller uses a static internal IP.
The NAT adapter is configured not to register in DNS to prevent incorrect name resolution entries.

3. Build Procedure
3.1 Prerequisites

Windows Server installed

Administrative privileges available

Repository cloned locally

Required DSC modules installed (ActiveDirectoryDsc, NetworkingDsc, ComputerManagementDsc)

Execution policy configured to allow script execution

3.2 Compile Configuration
.\BuildMain.ps1

Compiling the configuration reads data variables from AllNodes.psd1.

In this design:

AllNodes.psd1 defines environment values (IP address, DNS, domain name, node role, etc.)

StudentConfig.ps1 contains the configuration logic

StudentBaseline enforces the desired state using the values defined in AllNodes

In practical terms:

AllNodes defines the configuration values.
StudentConfig enforces those values through DSC resources.

Compilation produces MOF output in:

.\DSC\Outputs\
3.3 Apply Configuration
Start-DscConfiguration -Path .\DSC\Outputs -Wait -Verbose -Force

Running the configuration applies:

Computer renaming

Static IP configuration

DNS configuration

AD DS feature installation

Forest creation

OU creation

Security group provisioning

User provisioning

GPO linking

3.4 Reboot Behaviour

During domain promotion, the system reboots automatically.

If baseline configuration is applied but promotion does not complete during orchestrator execution, a manual restart finalises the promotion process.

4. Validation Procedure

After promotion and baseline enforcement, the system must be validated.

4.1 Tutor Validation Suite
Invoke-Validation

This executes the full tutor Pester suite from the repository to confirm compliance with required baseline standards.

Expected result:

All tests pass

No failed assertions

4.2 Student Pester Suite
Invoke-Pester -Path .\Tests\Pester\Student-Pester_ProofOfLife.ps1 -Output Detailed

Expected result:

Passed: 21
Failed: 0

Validation confirms:

OU governance structure is correct

Security groups are correctly placed

Users are provisioned in correct OUs

GPOs exist and are linked correctly

DNS configuration meets DC best practice

4.3 Evidence Capture

Validation output is captured using:

Start-Transcript -Path .\Evidence\Pester\Pester-Detailed.txt -Force
Invoke-Pester -Path .\Tests\Pester\Student-Pester_ProofOfLife.ps1 -Output Detailed
Stop-Transcript

Evidence is stored under:

.\Evidence\Pester\

.\Evidence\Transcripts\

.\DSC\Outputs\

5. Design Decisions
5.1 OU Governance Model

The directory structure follows a three-plane model:

ControlPlane – Core infrastructure

ManagementPlane – Administrative objects

UserAccessPlane – End-user objects

This separation:

Reduces risk of misconfiguration

Allows clear GPO scoping

Supports administrative delegation

Separates privileged accounts from standard users

5.2 Group Strategy

Global Security Groups are used:

GG-HR-Staff

GG-Finance-Staff

GG-IT-Admins

GG-Server-Admins

Global groups support:

Role-based access control

Alignment with AGDLP model

Scalable future delegation

Access should be assigned to groups, not directly to users.

5.3 GPO Strategy

Two baseline GPOs are implemented:

Computer baseline (Firewall configuration and SMBv1 disabled)

User baseline (Attack surface reduction settings)

GPO links are:

Enabled

Not enforced

Enforcement was avoided to prevent unnecessary precedence override and to maintain layered policy control.

5.4 DNS Configuration

The internal NIC on the Domain Controller is configured to:

127.0.0.1

This ensures:

Local AD-integrated DNS resolution

No dependency on external resolvers

Compliance with Domain Controller best practice

This configuration is validated through Pester testing.

5.5 Idempotence

The DSC configuration is idempotent.

Re-running:

Start-DscConfiguration -Path .\DSC\Outputs -Wait -Verbose

does not recreate objects or introduce duplication if the system state already matches the defined baseline.

Pester validation confirms:

No duplicate objects

No mislinked GPOs

No OU placement errors

6. Weekly Execution Log
Week 1–2: Environment Preparation

Focus areas:

Windows Server installation

RSAT and required DSC module installation

Network configuration

Repository setup

Module verification

Commands executed included:

Install-Module ActiveDirectoryDsc
Install-Module NetworkingDsc
Install-Module ComputerManagementDsc

Evidence stored in:

.\Evidence\Screenshots\

.\Evidence\Transcripts\

Week 3: DSC Configuration & Domain Promotion

Focus areas:

Development of StudentConfig.ps1

Structuring of AllNodes.psd1

MOF compilation

Baseline application

Domain Controller promotion

DNS correction to 127.0.0.1

Initial Pester validation

Commands executed:

.\BuildMain.ps1
Start-DscConfiguration -Path .\DSC\Outputs -Wait -Verbose -Force
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 127.0.0.1
Invoke-Validation

Evidence stored in:

.\DSC\Outputs\

.\Evidence\Pester\

.\Evidence\Transcripts\

Week 4: AD Baseline Stabilisation & Final Validation

Focus areas:

Final OU governance confirmation

Group placement validation

GPO link verification

Full tutor and student Pester validation

Final evidence capture

Commands executed:

Invoke-Validation
Invoke-Pester -Path .\Tests\Pester\Student-Pester_ProofOfLife.ps1 -Output Detailed

Final state:

All tutor tests passed

All student tests passed

AD baseline compliant

Evidence stored in:

.\Evidence\Pester\Pester-Detailed.txt

.\Evidence\Pester\Pester-Results.xm