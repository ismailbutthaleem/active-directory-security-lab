Github Repository Link:
https://github.com/ismailbutthaleem/COM5411-BarmBuzz

1. Solution Overview

This solution implements an automated Active Directory forest deployment using Infrastructure as Code (IaC) principles. The environment uses Windows Server 2025 as the Domain Controller and Windows 11 as the development machine.
Deployment is fully declarative and driven by DSC v3. According to Microsoft (2025), DSC is a declarative framework engine which allows the user to describe the desired state for the target system, for this to automatically enforce and apply the desired state described.

The current implementation is based on a single-domain forest model, aligned with the business requirements described in the BarmBuzz scenario.

Forest Root Domain: bolton.corp

Domain: bolton.corp

The Domain Controller is built entirely through DSC v3. Core Active Directory objects such as OUs, users and groups are provisioned automatically by the configuration after the baseline infrastructure has been prepared.

Operating systems involved in the solution:

Windows Server 2025 (Domain Controller)

Windows 11 (Dev Machine)

Windows 11 (Client)

Ubuntu (Client)

The build is designed to be:

Reproducible from clean virtual machines

Idempotent (safe to re-run without unintended changes)

Validated using Pester tests

Extendable to support a future Derby child domain

2. Architectural Scope and Boundaries

Domain Model

The current architecture implements:

Forest: bolton.corp

Root Domain: bolton.corp

Single Domain Controller

Single domain security boundary

This is intentionally a single-domain baseline. The OU and group design is modular so it can be extended later to a multi-domain forest if needed (for example, adding derby.bolton.corp as a child domain), without rewriting the whole governance model.

Boundary Justification

A single-domain model was selected to:

Reduce operational complexity

Simplify replication and DNS configuration

Focus on identity, policy enforcement, and automation quality

Within this architecture:

The domain is the primary security boundary.

Organisational Units (OUs) are used for delegation and Group Policy scoping.

Subnets represent network segmentation but do not define Active Directory security boundaries.

This is important because the governance model is implemented through OU placement, RBAC groups and scoped delegation, not by treating OUs as security borders.

2.3 OU Scope and Structure

The OU structure follows a role-based governance model aligned with least privilege.

The OUs are divided into logical tiers:

Control Plane – Contains high-privilege administrative groups and accounts. These are isolated from lower tiers and should not be used to log into lower-tier systems.

Management Plane – Contains delegated administrative groups and infrastructure-related objects. Includes administrators and role-based personnel.

User Access Plane – Contains standard user accounts, role-based security groups, and client computers.

Example high-level structure:

bolton.corp
│
├── OU=ControlPlane
├── OU=ManagementPlane
├── OU=UserAccessPlane

The purpose of this structure is to:

Implement least privilege through tiering and OU separation

Separate high-risk administrative accounts from standard users

Support targeted Group Policy application

Enable controlled delegation at the OU scope

OUs are used for management structure and policy targeting, not as security boundaries.

2.4 Delegation Model

Delegation is implemented using role-based security groups rather than assigning permissions directly to individual users, as suggested by Microsoft (2025).

For example:

The GG-IT-Admins security group exists within the Management Plane. Members of this group are delegated limited administrative control over the UserAccessPlane OU.

This delegation allows:

Resetting user passwords

Unlocking user accounts

Reading user object properties

GG-IT-Admins does not receive Domain Admin privileges.

Delegation is applied at the OU scope rather than at the domain root. This prevents excessive privilege inheritance and ensures administrative permissions remain restricted to their intended boundary.

This model supports operational efficiency while maintaining least privilege enforcement.

2.5 RBAC Intent

Role-Based Access Control (RBAC) is implemented through:

Security groups representing job roles or functions

Group-based permission assignment

Separation between administrative and standard accounts

According to Microsoft (2025), AD Role-Based Access Control is when permissions are granted to security groups rather than individual users. This allows tasks that require administrative privileges to be delegated in a structured and controlled approach instead of granting single users specific permissions.

This structure supports controlled policy enforcement by tracking access through group membership rather than individual user permissions.

2.6 Default Container Hygiene

The default Active Directory containers:

CN=Users
CN=Computers

are not used for governance. These are containers rather than organisational units. Objects are expected to be moved into the correct OUs to keep policy and delegation predictable.

This ensures:

Predictable Group Policy application

Delegation control at the correct scope

Consistent automation behaviour

Reduced administrative ambiguity

Leaving objects in default containers would bypass the governance model and weaken policy targeting consistency.

2.7 Security Boundary Clarification

Microsoft (2025) states that it is important to explicitly state:

An OU is not a security boundary.

A domain is a security boundary.

AD allows administrative delegation and policy scoping through OUs; however, the main security boundary is the domain or forest itself, where authentication and trust occur.

Cross-domain access:

Users from one domain are authorised to another domain by default because of the existing trust relationship within a forest. However, they cannot access resources unless explicitly configured to do so by the domain administrators.

This demonstrates the forest trust relationship without breaking the principle that each domain maintains its own security boundary.

3. Automation Strategy
3.1 Overview

This solution implements an idempotent and reproducible environment that can be replicated through automation.

The infrastructure design approach is Infrastructure as Code. This allows the system to be configured declaratively through DSC, and version controlled through Git, improving scalability and consistency (Berkouwer, 2022).
The deployment is idempotent, meaning that applying the configuration multiple times would produce the same result without causing unwanted changes, and DSC resources would not duplicate (Microsoft, 2025).

Manual configuration increases the risk of configuration drift and inconsistent environments. DSC reduces this risk by enforcing the desired configuration state defined for the system.

The orchestrator executes the configuration in a layered order so dependencies are respected:

Baseline infrastructure state (server + prerequisites)

Networking and DNS configuration

AD DS role installation

Domain Controller promotion

Post-promotion directory objects (OUs, users, groups)

GPO creation, linking and enforcement

Client onboarding (Windows + Ubuntu evidence)

If the machine has already been promoted to a Domain Controller, DSC detects that the state already matches the desired configuration and skips that step. This supports safe reruns and convergence.

When the configuration is compiled, MOF artefacts are generated. These MOF files describe the target state for each node.

The Local Configuration Manager (LCM) reads the MOF file and enforces the defined state on the system.

MOF files are treated as generated artifacts that can be checked after a compile.

3.2 Data Driven Configuration Model

The data file is also used when objects are repetitive, likely to expand, or expected to change properties over time, as it is easy to manipulate with a data-driven approach, allowing easier scalability.

Instead of hardcoding these objects directly inside the configuration logic, they are defined inside:

DSC\Data\AllNodes.psd1

This keeps the configuration structure clean and avoids rewriting logic when objects change.

The data file acts as a definition layer.

It contains values such as:

OUs

Users

Security groups

Attributes and relationships

Credentials are not stored in plain text.

Objects are defined inside arrays.

For example:

OUList defines all required OUs.

Users defines user account objects.

Groups defines security groups.

MemberOf inside Users defines RBAC relationships.

The configuration file iterates through these lists and applies the required DSC resources.

This means the same logic works regardless of scale.

If additional users or groups are added to the data file, the configuration does not need to change.

This design improves:

Scalability

Maintainability

Configuration consistency

4. Repository Structure

The repository is structured to clearly separate configuration logic, validation tests and generated evidence artifacts.

The layout allows another engineer to extract the ZIP file and understand how the environment is deployed from the root directory.

4.1 Entry Point

The primary entry point for compiling the configuration is:

.\Run_BuildMain.ps1

This script compiles the DSC configuration and generates MOF output files.

Validation can then be executed using:

Invoke-Validation

or directly:

Invoke-Pester -Path .\Tests\Pester\

4.2 DSC Configuration Location

DSC configuration files are located under:

.\DSC\

Subdirectories include:

.\DSC\Configurations\StudentConfig.ps1
.\DSC\Data\AllNodes.psd1
.\DSC\Outputs\

StudentConfig.ps1 contains the DSC configuration logic.

AllNodes.psd1 contains environment specific data values.

Outputs contains compiled MOF files generated during build.

This separation ensures configuration logic and data definitions remain independent.

4.3 Pester Test Location

All Pester tests are located under:

.\Tests\Pester\

This includes:

Tutor provided validation tests

Student validation tests

These tests validate domain state, OU structure, RBAC group membership and policy linking.

4.4 Evidence and Transcripts

Execution evidence is stored under:

.\Evidence\

Subfolders include:

Pester

Transcripts

Screenshots

GPOBackups

This keeps generated artifacts separate from configuration logic.

5. Execution Order (Runbook)
5.1 Pre-Conditions

Before running the build the configuration data file must contain correct environment values such as:

Computer name
Internal NIC alias
IPv4 address
DNS server
Domain name
Node role

Required DSC modules must also be installed.

Credentials are provided during execution and are not stored in configuration files.

The only files to edit are:

AllNodes.psd1 (Logic File)
StudentConfig.ps1 (Configuration Logic)

This build is data-driven. All values stored in AllNodes.psd1 must match the environment values used in the StudentConfig.ps1 to ensure correct compilation.

VMs should ideally be started from a clean snapshot before running the build to avoid configuration drift or conflicts from previous runs.

NIC layout assumptions:

The Domain Controller has two adapters:

Host-only / internal adapter used for the Active Directory network.

NAT adapter used only for internet connectivity and module downloads.

The internal adapter must have a static IPv4 configured and use the Domain Controller as the DNS server. NAT registration from DNS should be disabled.

Time must also be synchronised between machines as Kerberos authentication requires clocks to be within the allowed time drift.

The build must be executed from an Administrator PowerShell shell.

5.2 Compile the Configuration

Compilation is triggered using:

.\Run_BuildMain.ps1

This step:

Loads configuration data
Compiles StudentBaseline
Generates MOF files inside:

.\DSC\Outputs\

What should change:

A compiled MOF file should appear inside the Outputs directory.

How to prove it:

Check the directory:

dir .\DSC\Outputs\

Expected result:

A localhost.mof file should be present for the Domain Controller.

5.3 Apply the Configuration

The configuration is applied automatically for the Domain Controller. The build generates a MOF file which the Local Configuration Manager (LCM) reads and applies to enforce the desired state.

During this stage the system will perform the following actions:

Operating system configuration
Network configuration
DNS configuration
AD DS role installation
Domain Controller promotion

The Domain Controller promotion stage will trigger a reboot as part of the forest creation process. In the case it does not, restart the machine manually, this might be needed twice for AD DS update on the machine.

If an error saying the domain is not available apppears, do:

1- Login with the local admin account
2- Start-Service Netlogon
3- Get-Service Netlogon

Expected outcome:

Running

Then restart the system again.

After reboot, the configuration can be executed again to continue convergence if needed.

For clients the configuration might be automatically pushed during the build run. If the push transport fails, the MOF file generated for the client on the Domain Controller can be copied manually to the client machine using a shared folder.

The file location will be:

DSC\Outputs\StudentBaseline\Windows10.mof

This file contains the desired configuration for the client machine, including the instructions required to join the bolton.corp domain. The separate MOF demonstrates that DSC can manage multiple nodes independently while using the same configuration logic.

Once copied, run on the client:

Start-DscConfiguration -Path C:\Temp -Wait -Verbose -Force

This allows the LCM on the client to read and apply the configuration locally.

Evidence of correct windows onboarding:
Evidence\Transcripts\client-session_windows10.txt
Evidence\AD\gpresult_adam.kahan_windowsclient.txt

5.4 Validate the Baseline

Validation is performed using Pester tests.

Run the tutor validation suite:

Invoke-Validation

This runs all Pester tests that assess both pre-promotion and post-promotion configuration states.

Alternatively run Pester directly:

Invoke-Pester

or run a specific Pester test file.

Tests confirm:

OU structure
Group membership
RBAC relationships
Policy linking
Domain state

Expected outcome:

All tests should pass. A failing test indicates either a configuration drift, missing object, incorrect OU path, or module dependency issue.

Summary (Simple Runbook After all conditions above have been met)

Clone the repository

git clone <repo-url>

Open an Administrator PowerShell session on the Domain Controller VM.

Navigate to the repository root.

cd COM5411-BarmBuzz

Run the orchestrator.

.\Run_BuildMain.ps1

Validate the environment.

Invoke-Validation

Expected outcome:
The Domain Controller is promoted, OUs and RBAC objects are created, policies are applied and validation tests pass.

6. Idempotence and Re-Run Behaviour

Idempotence means the build can be executed multiple times without creating duplicate objects or breaking the environment.

DSC compares the desired configuration against the actual machine state.

If the object already exists and matches the configuration, DSC skips it.

If the object does not exist, DSC creates it.

If configuration drift occurs, DSC enforces the desired state.

This behaviour ensures the environment remains consistent even if changes occur outside the configuration.

7. Validation and Testing Model

After the system is built, validation is performed using Pester tests.

Pester tests verify that the desired configuration state has been applied correctly.

Examples of validation checks include:

OU structure
User and group existence
RBAC relationships
GPO linking
DNS configuration

The validation suite provides clear pass or fail outputs.

Failed tests highlight the expected value and the actual value, making troubleshooting easier.

8. Health Checks
8.1 ControlPlane OU

Risk:

Most valuable OU in the infrastructure as it holds domain control operations.

Control:

Only privileged administrative accounts reside in this OU.

Justification:

Separating privileged accounts reduces lateral movement and limits attack surface.

Verification:

Evidence\HealthChecks\ou_listing.txt

8.2 ManagementPlane OU

Risk:

Administrative accounts require elevated privileges which increases potential exposure.

Control:

Delegated permissions are assigned to role based security groups.

Justification:

Permissions are scoped to specific OUs rather than domain root.

Verification:

Evidence\AD\RBAC_Reset_Test.txt

8.3 UserAccessPlane OU

Risk:

User endpoints represent the largest attack surface.

Control:

Hardening policies are applied to user accounts and computers inside this OU.

Justification:

Separating standard users prevents policy conflicts with privileged accounts.

Evidence:

Evidence\Transcripts\client-session_windows10.txt
Evidence\AD\ubuntu_join.txt

8.4 BBZ-User-Hardening-Reduce-AttackSurface

Risk:

Users may misuse system tools such as Command Prompt or Control Panel.

Control:

Access to these tools is restricted through Group Policy.

Justification:

This reduces attack surface while preserving administrative functionality.

Verification:

gpresult /r

Evidence:

Evidence\HealthChecks\gpresult_user.txt
Evidence\Screenshots\Capture_cmd_deactivated.PNG

8.5 BBZ-Computer-Baseline-Firewall-SMB

Risk:

Weak firewall configuration and legacy protocols increase attack surface.

Control:

Firewall rules are enforced and SMBv1 is disabled.

Justification:

Policies target client systems without affecting administrative infrastructure.

Verification:

Evidence\HealthChecks\gpresult_computer.txt

8.6 Fine Grained Password Policy

A fine-grained password policy was implemented targeting the security group GG-Domain-Admins, which resides inside the ControlPlane OU.

Risk:

Non-complex or easy to crack passwords suppose a potential threat inside the ControlPlane, as users inside it have privileged rights that can modify or change the domain. If a password was to be retrieved by a threat actor, they could potentially modify or break the system.

Control:

A stronger password policy must be enforced for domain admin users. This includes increased password complexity and length requirements, as well as forcing administrator accounts to update their passwords after a shorter period of time.

Justification:

Passwords that are longer and more complex are harder to crack or guess. Forcing a password update after a certain period of time acts as a delaying method that, when implemented continuously, ensures credentials remain up to date and reduces the chances of attackers successfully planning a strategy to compromise them.

FGPP should be applied to groups whose compromise would represent a major security risk, such as loss of domain control. These passwords are intentionally more complex and therefore harder to remember, and they also require periodic updates. Applying the same strict policy to normal users, such as a finance user inside the UserAccessPlane, would negatively affect usability and operational efficiency for everyday tasks.

Verification:
Evidence\AD\fgpp_policy.txt

8.7 GPO Implementation Approach

GPOs were not applied via DSC intentionally. According to Morris (2016), in production environments policy governance is usually handled separately through different operational layers. GPOs are enforced in the AD environment itself using an imperative approach; however DSC is still the primary control plane for the infrastructure layer of the environment, including:

DC Deployment

- Networking Configurations
- Users
- Security Groups 
- OU Implementation
- Windows Client Domain Join

This logical separation allows administrators to easily implement policies throughout the environment using the AD GUI or PowerShell cmdlets, or scripts that run on the Domain Controller. This therefore increases operational manageability and troubleshooting capability, as argued by Morris (2016).

Although the GPOs of this environment are not declarative and automated via DSC, they can be reused and implemented easily on a clean Domain Controller with the following scripts:

Scripts\Configure-GPOs.ps1
Scripts\Configure-FGPP.ps1

Then run:

gpupdate /force

Validate with:

Invoke-Pester Tests\Pester\Student-Pester_ProofOfLife.Tests.ps1

Outcome:

The GPOs should exist and be linked correctly.

This maintains DSC as the declarative infrastructure layer while allowing policies to be managed by the native Group Policy subsystem inside the DC.

9. Security Considerations
9.1 Credentials Hardening

Credential management should not be handled directly by DSC in the deployment of any production environment. This decision aligns with best security practices, as sensitive data such as passwords should never be stored in plain text within configuration files. Instead, PSCredential objects are used to pass password values during Active Directory setup, but these credentials are not hardcoded anywhere. However, due to the requirements for this lab, no MOF encryption was used, which caused the client MOF files to include the username and password for domain join in plain text.

MOF files are generated artifacts that should not contain or expose any credentials in a production environment. If exposed, these could allow a threat actor to modify, disrupt, or compromise the system.

In a production environment, certificate-based MOF encryption and integration with a secure vault (e.g., Azure Key Vault) would be implemented for enhanced security, ensuring credentials are protected at all times.

The Local Configuration Manager (LCM) reads the MOF files and enforces the defined configuration locally. No external sources or credential management systems are used to read or deploy the desired configuration in this lab environment.

9.2 Users Activation

User passwords are configured directly in the Active Directory environment after promotion.

In the AllNodes.psd1 file the user objects are created by DSC with the value:

Enabled = $false

This means the accounts are created in Active Directory but remain disabled until a valid password is configured. Passwords are intentionally not stored inside the DSC configuration.

After the orchestrator has completed and the Domain Controller has been promoted, run the following script on the Domain Controller to configure the user passwords and enable the accounts.

Script location:

Scripts\Set-ADPasswords.ps1

This script sets the passwords for each user and then enables the account after the password has been applied.

To avoid conflicts with DSC after the script has been run, set the AllNodes.ps1 users value:

enabled=$false

to:

enabled=$true

This approach allows DSC to provision the user objects while keeping credential configuration outside of the DSC configuration logic.

Considerations for production-level security:

9.3 DNS Security and Network Exposure

For the deployment of this environment, two NICs have been configured: NAT and Host-Only.

The NAT NIC is required for both the Domain Controller (DC) and the development machine (Dev) to download updates or access external resources.

The Host-Only adapter is used specifically for DNS resolution. The DC uses the loopback address of this adapter to resolve DNS queries. Clients can only join the domain if they share the same local network adapter.

NAT is disabled for DNS registration to enhance security by isolating the DC from the external network. This prevents potential threats like DNS spoofing, caching poisoning, or other man-in-the-middle attacks.

This setup ensures that only authorised and trusted machines can join the domain and query DNS, significantly reducing the risk of unauthorised access.

9.4 OU and Delegation Design Intent

The OU structure is split into three sections:

Control Plane: Contains critical assets like the Domain Controller (DC) and related administrative policies.

Management Plane: Houses IT admins and privileged accounts, but these are scoped outside of domain-level policies.

User Access Plane: Covers user endpoints, clients, and service accounts with restricted privileges.

The purpose of this structure is to apply GPOs and delegation logically, ensuring that policies only impact the intended objects. This setup follows the least privilege model, granting only the necessary permissions for each group or OU, preventing unnecessary access or conflicts across different objects.

9.5 RBAC Design

RBAC is implemented based on the least privilege principle. The security groups reflect necessary roles within the organisation, and permissions are assigned to these groups, not individual users.

Key security groups:

GG-IT-Admins: Administrative access scoped through delegation and group membership.

GG-HR-Staff: Role-based access with no admin rights.

GG-Server-Admins: Admin access to server-related objects (as defined in the build).

Security group usage:

To give users outside an OU the ability to perform privileged tasks, a security group is created and permissions are applied to the group rather than the user.

For example, if a user from the User Access Plane needs controlled access to administer an OU:

A security group is created.

The user is added to the group.

The group is granted the required permissions at the OU scope.

This ensures access is specific and controlled, keeping the environment secure while enabling required duties without over-privileging users.

9.6 Delegation and Least Privilege Enforcement

Delegation in an Active Directory infrastructure has to respect least privilege. Users must be granted privileges only to the minimum level required to carry out a specific task.

According to Microsoft (2025), the Least Privilege principle consists of users only receiving the minimum amount of permissions required for them to perform their role, this helps mitigate attack surface in the AD environment.

Additionally, Stallings (2018) argues that the least privileged model is a fundamental rather than optional security practice in an enterprise environment.

A security group is defined where users inside that group receive delegated privileges. Delegation means a user from one OU can perform specific actions within another OU scope. This works because permissions are assigned to the security group at the OU level, not to the individual user.

In this infrastructure, GG-IT-Admins includes the user ismail.admin, which is delegated control over the UserAccessPlane OU to reset passwords. This allows ismail.admin to reset the password of adam.khan, who resides within that OU.

The only permission granted is the ability to reset passwords within that specific scope. No additional administrative rights are provided outside that boundary.

Delegation must be carefully designed and applied. Granting excessive privileges, or allowing a lower-tier OU to modify objects within a higher-tier OU, would break the governance model and violate least privilege principles. This would weaken the environment and expose it to security risks.

9.7 Delegation Validation (Allow / Deny Outcome)

Delegation was tested to confirm that permissions were applied correctly and scoped only to the intended OU.

The user ismail.admin, as a member of GG-IT-Admins, successfully reset the password of adam.khan, who resides inside the UserAccessPlane OU. This confirms that the delegated permission was correctly applied at the OU level.

An additional test was performed against paul.evans, who is located in the ManagementPlane OU. The password reset attempt failed due to insufficient permissions. This confirms that delegation does not extend outside of the intended OU scope.

This behaviour proves that least privilege has been enforced correctly. The PowerShell transcript capturing both the successful and denied operations is stored under:

.\Evidence\AD\RBAC_Reset_Test.txt

9.8 Explicit Trade-Offs Made for Lab Realism vs Enterprise Practice

Trade-Off 1: Use of a Single Domain Controller

Only one Domain Controller (DC) is deployed because higher-level complexity is not required for the scope of this project demonstration. This increases simplicity, reduces configuration overhead, and allows controlled testing of the automation workflow.

In an enterprise environment, multiple Domain Controllers would be deployed to eliminate a single point of failure, provide redundancy, improve fault tolerance, and support scalability. Active Directory replication between DCs would ensure directory consistency and availability across the network. The lab design prioritises clarity and reproducibility over high availability.

Trade-Off 2: Limited GPO Depth

The GPO configuration implemented in this lab is security relevant and functions as intended, however it does not reflect the depth expected in a production enterprise environment.

In a real-world infrastructure, GPO design would be significantly more layered and structured. Additional policies would typically include:

Advanced auditing

Security baselines aligned to frameworks (e.g., CIS)

Password complexity enforcement for privileged accounts

WMI filtering for precise targeting

Layered inheritance strategies

In this lab, GPOs are intentionally scoped only to the relevant OUs to demonstrate correct linkage and enforcement. The objective is to prove correct linkage and enforcement, not to implement a full enterprise governance framework.

Trade-Off 3: DNS Architecture

In this lab environment, DNS is hosted on the single Domain Controller. This is sufficient to demonstrate the relationship between DNS, clients, and Active Directory name resolution.

In an enterprise infrastructure, DNS redundancy is required to avoid a single point of failure and to support load balancing. Multiple DNS servers would be deployed, often across different sites, with replication and potentially conditional forwarders or split-DNS configurations. The lab environment simplifies DNS to focus on functional correctness rather than infrastructure resilience.

10. Evidence Mapping

This section maps each key requirement/outcome to the supporting evidence stored in the repository. Evidence is organised under the Evidence\ folder to separate generated artefacts from configuration logic.

10.1 Domain Controller Build and Automation

Domain Controller built and converged using the DSC orchestrator.

Run_BuildMain execution transcripts (multiple runs captured)
Evidence\Transcripts\20260225_000339_Run_BuildMain.txt

DSC compilation evidence (BuildMain compile output)
Evidence\DSC\BuildMain-Compile.txt

Compilation artefact listing (compiled files logs)
Evidence\DSC\20260304_222322_compiled_files.txt
Evidence\DSC\20260304_221412_compiled_files.txt

Idempotent rerun / convergence evidence with hashes
Evidence\Transcripts\Build_And_Filehash_run1.txt
Evidence\Transcripts\Build_And_Filehash_run2.txt

10.2 Active Directory Health and Core Services

Domain and forest state evidence
Evidence\HealthChecks\domain_info.txt
Evidence\HealthChecks\forest_info.txt

Domain Controller diagnostics (dcdiag)
Evidence\AD\dcdiag_output.txt
Evidence\AD\dcdiag_dns_health.txt

Kerberos / authentication-related service evidence
Evidence\HealthChecks\Kerberos_info.txt

Windows Time service evidence (time sync for Kerberos)
Evidence\HealthChecks\Windows_Time_Service_info.txt

DNS records / zone validation
Evidence\HealthChecks\DNS_Records_info.txt
Evidence\HealthChecks\DNS_Records_Global_info.txt

Server verification / baseline service checks
Evidence\HealthChecks\Server_Verification_info.txt

10.3 OU Structure and Governance Model

OU structure validated (ControlPlane / ManagementPlane / UserAccessPlane and sub-OUs)
Evidence\HealthChecks\ou_listing.txt

10.4 Group Policy Design and Enforcement

GPO backups captured (backup artefacts + manifest)
Evidence\GPOBackups\manifest.xml
Evidence\GPOBackups{05B4C64E-4D1B-4348-AF29-6B81BF6616A0}\
Evidence\GPOBackups{29DFEE28-2CC0-4AC0-8A1B-EDBE2F59DA35}\
Evidence\GPOBackups{CA6E22F5-602C-471B-AB79-58C99372844C}\
Evidence\GPOBackups{FEEAF7CE-2AD2-4A9C-AC1B-4106CF497563}\

Baseline policy application evidence (computer/user)
Evidence\HealthChecks\gpresult_computer.txt
Evidence\HealthChecks\gpresult_user.txt

GPO proof summary
Evidence\GPOBackups\02-GPO-Proof.txt

FGPP Application
Evidence\AD\fgpp_policy.txt

10.5 Windows Client Domain Join and OU-Scoped Policy Proof

Windows client domain join + policy enforcement evidence.

Windows client transcript (domain context + gpresult output)
Evidence\Transcripts\client-session_windows10.txt

User policy report captured on Windows client
Evidence\AD\gpresult_adam.kahan_windowsclient.txt

RSoP HTML report exported from Windows client
Evidence\AD\gpresult.html

DSC client proof-of-life file
Evidence\HealthChecks\03-DSC-Applied.txt

Screenshot evidence of policy enforcement (Command Prompt blocked)
Evidence\Screenshots\Capture_cmd_deactivated.PNG

10.6 Ubuntu Domain Authentication

Ubuntu client identity resolution and authentication evidence
Evidence\AD\ubuntu_join.txt

10.7 Delegation Validation

Delegated password reset test demonstrating explicit allow/deny outcomes
Evidence\AD\RBAC_Reset_Test.txt

10.8 Network Validation

Network configuration validation captured across runs (IP + time status)
Evidence\Network\20260304_222322_ipconfig.txt
Evidence\Network\20260304_222322_w32tm_status.txt

(Additional timestamped ipconfig/w32tm evidence is also stored under Evidence\Network.)

10.9 Validation and Testing Model

Pester results (XML output suitable for marker verification)
Evidence\Pester\PesterResults_20260224_193234.xml

Detailed Pester transcripts
Evidence\Pester\Pester-Detailed-20260224-192037.txt

Student-authored validation tests evidence
Evidence\Pester\Pester_RBAC_Groups.txt
Evidence\Pester\Pester_OU_Placement.txt
Evidence\Pester\Pester_Users.txt
Evidence\Pester\Pester_Data_Driven_Created.txt

10.10 Provenance and Academic Integrity

AI interaction log
Evidence\AI_LOG\AI-Usage.md

Git reflog location (structure retained)
Evidence\Git\Reflog\

11. Known Limitations and reflections
11.1 WinRM Push Failure – Client DSC Application

During the build process, DSC was attempting to push the compiled MOF file for the Windows 10 client to the client machine so that it could update automatically through remote execution. However, a transport issue occurred on the client side.

The most likely cause was related to WinRM communication or firewall configuration preventing remote DSC push from completing successfully. This meant the Domain Controller could compile the client MOF, but could not remotely apply it over the network.

As a workaround, once the orchestrator completed the build and generated the separate client MOF file, the file was manually copied to the Windows client using a shared folder. The configuration was then applied locally on the client using:

Start-DscConfiguration -Path C:\Temp -Wait -Verbose -Force

This allowed the Local Configuration Manager (LCM) on the client to read and enforce the desired state.

Although remote push did not function, the core architecture remains valid. The build successfully demonstrates that:

A separate MOF file is generated for the client

Client configuration is modular and independent

The client can enforce its own desired state using DSC

In an enterprise environment, WinRM over HTTPS with proper certificate configuration and firewall rules would be implemented to enable secure and automated remote DSC push or pull-based configuration management.

11.2 PowerShell 7 vs Windows PowerShell 5.1 Compatibility

During development, it was identified that Windows PowerShell 5.1 runs on the .NET Framework and is the native shell for many Active Directory and DSC resources. This became clear when running Pester tests, where certain error messages indicated that some resources were expected to run under a specific PowerShell context.

When executing AD-related commands such as Get-ADUser inside PowerShell 7 (pwsh), the command was not recognised. However, running the same command inside Windows PowerShell 5.1 (powershell.exe) worked immediately.

This behaviour occurs because:

The ActiveDirectory module is built for Windows PowerShell 5.1

Some DSC resources depend on .NET Framework-based modules

PowerShell 7 runs on .NET (Core) and does not fully support all legacy AD modules natively

As a result, certain Pester validations and DSC-related tasks needed to be executed in Windows PowerShell 5.1, while other tasks could run in PowerShell 7.

This required awareness of shell context during testing and validation. It was concluded that both shells must be used appropriately depending on the resource or module being invoked.

In an enterprise environment, shell standardisation and module compatibility testing would be implemented to avoid inconsistencies between PowerShell versions.

11.3 DNS Misconfiguration

DNS misconfigurations occurred when attempting to join hosts to the domain. The internal adapter of the host machines was correctly configured to point to the Domain Controller IPv4 address for DNS resolution. However, the NAT adapter was still being prioritised for DNS queries.

As a result, SRV record lookups such as:

_ldap._tcp.dc._msdcs.bolton.corp

were being sent through the NAT interface instead of the internal network. Since the Domain Controller operates within the isolated host-only network, the NAT adapter could not resolve these queries.

This caused failures in:

Windows domain join

realm discover bolton.corp on Ubuntu

SRV record resolution

The issue was identified after confirming that the internal adapter was correctly configured, but DNS queries were still failing. Network inspection revealed that adapter priority was incorrect.

To resolve the issue:

The internal NIC was configured with higher priority for DNS resolution

The Domain Controller IPv4 address was set as the primary DNS server

The NAT adapter was either deprioritised or prevented from registering in DNS

This ensured that domain-related queries were resolved internally first. If a query was external, it would then be forwarded appropriately through the NAT DNS server.

In a production environment, DNS resolution would typically be centrally managed via DHCP and controlled network segmentation to avoid interface-priority conflicts.

11.4 Kerberos Authentication

Kerberos is the authentication mechanism used within Active Directory environments to validate user identities. It relies heavily on time-based tickets and therefore is very sensitive to clock drift between the client and the Domain Controller. By default, Kerberos allows a maximum time difference of approximately five minutes between systems. If the client clock is more than five minutes ahead or behind the Domain Controller, authentication will fail.

During the Ubuntu client integration stage of this deployment, authentication attempts initially failed when trying to join the domain. The error message displayed was not very descriptive and suggested that the domain password was incorrect.

Initial troubleshooting focused on verifying common causes such as:

Incorrect domain credentials

Incorrect domain name during the join process

However, further analysis suggested that the issue could be related either to DNS resolution or Kerberos authentication.

DNS functionality was verified first. The command:

nslookup bolton.corp

successfully resolved the domain, confirming that DNS was functioning correctly.

The command:

sudo realm discover bolton.corp

also returned the correct domain and Kerberos realm information, further confirming that DNS and domain discovery were working.

Since DNS was functioning, time synchronisation between the Ubuntu client and the Domain Controller was then checked. Time checks confirmed that the clocks were synchronised and within the Kerberos tolerance window.

This narrowed the issue down to Kerberos not being installed or configured correctly on the Ubuntu client. The Kerberos utilities were not present on the system.

After installing the required Kerberos packages, authentication tools became available. The command:

klist

was used to verify Kerberos ticket functionality and confirm that the authentication infrastructure was operational.

Once Kerberos was installed correctly, the Ubuntu client was able to authenticate successfully against the Active Directory domain.

In a production environment, Kerberos dependencies and required authentication packages would typically be included in a baseline system configuration to avoid this issue during domain integration.

11.5 MOF Encryption

For simplicity and demonstration purposes this lab deployment does not include MOF encryption, which leaves credentials exposed to threat actors. This is not a good security practice and should be pointed out. In a production environment encryption would have been enabled to avoid potential threats. However, the AD environment does not include hardcoded passwords for the users belonging to the environment, as these are passed directly in the AD environment rather than hardcoded in configuration files.

11.6 Reflection

From a technical perspective this automated AD deployment sits within Band A. The implementation has successfully achieved all outcomes expected from Bands D through A. This Active Directory deployment is data-driven and highly automated, and can be replicated from clean VMs using the provided documentation and runbook.

The work was AI assisted during development; however student knowledge and understanding were prioritised throughout the process. Each command or configuration step was first understood by the student before execution, ensuring the infrastructure remained reliable and reproducible rather than blindly generated.

Pester tests and additional health-check commands were conducted to validate the configuration state and confirm that the deployed environment matches the intended architecture.

Overall the deployment demonstrates a reproducible Infrastructure as Code Active Directory environment that is idempotent and supports convergence, while maintaining a clear separation between governance, structure and policy enforcement, with system reliability verified through automated testing.

12. References

Microsoft (2025) Desired State Configuration overview. Available at: https://learn.microsoft.com/en-us/powershell/dsc/overview

(Accessed: 6 March 2026).

Microsoft (2025) Desired State Configuration resources and idempotent operations. Available at: https://learn.microsoft.com/en-us/powershell/dsc/concepts/resources/overview

(Accessed: 6 March 2026).

Microsoft (2025) Implementing least-privilege administrative models in Active Directory. Available at: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/implementing-least-privilege-administrative-models

(Accessed: 6 March 2026).

Microsoft (2025) Reducing the Active Directory attack surface. Available at: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/reducing-the-active-directory-attack-surface

(Accessed: 6 March 2026).

Morris, K. (2016) Infrastructure as Code: Managing Servers in the Cloud. 2nd edn. Sebastopol: O’Reilly Media.

Sander Berkouwer (2022) Active Directory Administration Cookbook. Birmingham: Packt Publishing.

Stallings, W. (2018) Effective Cybersecurity: A Guide to Using Best Practices and Standards. Boston: Pearson.

National Cyber Security Centre (2023) Practitioner guidance for securing Microsoft Active Directory services. Available at: https://www.cyber.gc.ca/en/guidance/practitioner-guidance-securing-microsoft-active-directory-services-your-organization-itsp60100

(Accessed: 23rd February 2026).