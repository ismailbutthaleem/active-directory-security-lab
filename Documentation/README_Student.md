1. Solution Overview

This solution implements an automated Active Directory forest deployment using Infrastructure as Code (IaC) principles. The environment uses Windows Server 2025 as the Domain Controller and Windows 11 as the development machine. Deployment is fully declarative and driven by DSC v3.

The current implementation is based on a single-domain forest model, aligned with the business requirements described in the BarmBuzz scenario.

Forest Root Domain: bolton.corp

Domain: bolton.corp

The Domain Controller is built entirely through DSC v3. No manual configuration of Active Directory objects is required after initial VM preparation.

Operating systems involved in the solution:

Windows Server 2025 (Domain Controller)

Windows 11 (Dev Machine)

Windows 11 (client)

Ubuntu (client)

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

The solution follows a modular design. Although the baseline is single-domain, the structure allows for extension to a multi-domain forest (for example, adding derby.bolton.corp as a child domain).

Boundary Justification

A single-domain model was selected to:

Reduce operational complexity

Simplify replication and DNS configuration

Focus on identity, policy enforcement, and automation quality

Within this architecture:

The domain acts as the primary security boundary.

Organisational Units (OUs) are used for delegation and Group Policy scoping.

Subnets represent network segmentation but do not define security boundaries.

This separation is intentional and will later be demonstrated through testing and access control validation.

2.3 OU Scope and Structure

The OU structure follows a role-based governance model aligned with least privilege principles.

The OUs are divided into logical tiers:

Control Plane – Contains high-privilege administrative groups and accounts. These are isolated from the lower tier levels and should never login with their credentials in such tiers.

Management Plane – Contains delegated administrative groups and infrastructure-related objects. Includes Admins and role based personnel

User Access Plane – Contains standard user accounts, role-based security groups, and client computers.

Example high-level structure:

bolton.corp
│
├── OU=ControlPlane
├── OU=ManagementPlane
├── OU=UserAccessPlane

The purpose of this structure is to:

Implement a Least Priviledge approach with the structured tiers and OU's separation.

Separate high-risk administrative accounts from standard users

Support targeted Group Policy application

Enable controlled delegation

OUs are used for management structure and policy targeting, not as security boundaries.

2.4 Delegation Model

Delegation is implemented using role-based security groups rather than assigning permissions directly to individual users.

For example:

An IT-Helpdesk security group exists within the Management Plane. Members of this group are delegated limited administrative control over the User Access Plane OU. This delegation allows:

Resetting user passwords

Unlocking user accounts

Reading user object properties

The IT-Helpdesk group does not receive Domain Admin privileges. (RBAC)

Delegation is applied at the OU scope rather than at the domain root. This prevents excessive privilege inheritance and ensures administrative permissions remain restricted to their intended boundary.

This model supports operational efficiency while maintaining least privilege enforcement.

2.5 RBAC Intent

Role-Based Access Control (RBAC) is implemented through:

Security groups representing job roles or functions.

Group-based permission assignment

Separation between administrative and standard accounts

No direct permissions are assigned to user accounts outside of role-based groups.

This structure allows a more flexible and controlled policy application and policy enforcement by tracking down and narrowing these attributes to a group membership instead of single users.

2.6 Default Container Hygiene

The default Active Directory containers:

CN=Users
CN=Computers

are not used for governance as these do not really count as OU more as containers, best practice is to move objects from these containers into a specific OU or move the container to a OU.
This ensures:

Predictable Group Policy application

Delegation control at the correct scope

Consistent automation behaviour

Reduced administrative ambiguity

Leaving objects in default containers would bypass the governance model and weaken policy targeting consistency.

2.7 Security Boundary Clarification

It is important to explicitly state:

An OU is not a security boundary.

A domain is a security boundary.

Although OUs allow administrative delegation and policy scoping, authentication and trust enforcement occur at the domain level, therefore domain level attributes bypass any policies or separations made in OU's

Cross Domain Acess:

Users from one domain are authorized to another domain by default because of the existing trust relationship within a forest, however they cannot access resources unlesss explicitily configured to do so by the domain admins.
This proves forest relationship of trust without breaking the principle that each domain has its security boundaries regardless.

3. Automation Strategy

This solution imposes an idempotent and reproducible environment that can be replicated via automation. The use of manual configurations would increase the risk of settings being overwritten or altered by external changes. DSC reduces this risk because it enforces the desired configuration state defined for the system.

The environment can be easily replicated, as it depends on declared resources and a configuration that defines the required state. The system continuously ensures compliance with the requirements specified in the desired configuration.

The orchestrator runs the configuration in a layered and logical order for it to work correctly. It first establishes the infrastructure (server state, networking, DNS, Domain Controller role). It checks that the baseline is in the correct desired state. If everything within the baseline is compliant, it would normally proceed to configure the system to promote to DC.

If this step has already been completed, DSC will detect that the state of the machine being a DC is already true. Therefore, it will not run the DC promotion again, but instead move on to the next layered step, which is applying AD objects.

It will then check that the OUs, users, security groups, GPOs and links are in the desired state. If not, it will enforce them so that the values from the configuration match the machine state.

A MOF artifact is a set of instructions produced for the system to read and enforce after the DSC configuration has been compiled. When the orchestrator runs and matches values from the data file with the configuration file, it produces a MOF file. This MOF file is then read by the Local Configuration Manager (LCM), which enforces the defined state of the machine.

4. Repository Structure

4. Repository Structure

The repository is structured to clearly separate configuration logic, validation tests, and generated evidence artifacts. The layout is designed to allow a tutor to extract the ZIP file and understand the execution flow from the root directory.

4.1 Entry Point

The primary entry point for compiling the configuration is:

.\BuildMain.ps1

This script compiles the DSC configuration and generates MOF output files.

Validation can then be executed using:

Invoke-Validation

or directly:

Invoke-Pester -Path .\Tests\Pester\
4.2 DSC Configuration Location

DSC configuration files are located under:

.\DSC\

Subdirectories:

.\DSC\Configurations\StudentConfig.ps1
.\DSC\Data\AllNodes.psd1
.\DSC\Outputs\

StudentConfig.ps1 contains the DSC configuration logic.

AllNodes.psd1 contains environment-specific data values.

Outputs contains compiled MOF files generated during build.

This separation ensures configuration logic and data definitions remain distinct.

4.3 Pester Test Location

All Pester tests are located under:

.\Tests\Pester\

This includes:

Tutor-provided validation tests

Custom student validation tests

Tests are structured to validate domain state, OU structure, group placement, GPO linking, DNS configuration and service health.

4.4 Evidence and Transcripts

Execution evidence and transcripts are stored under:

.\Evidence\

Subdirectories include:

Pester – validation output files

Transcripts – PowerShell transcripts

Screenshots – supporting visual evidence

GPOBackups – exported policy backups (if applicable)

This ensures all generated artifacts are separate from configuration logic.

4.5 Relative Path Usage

All scripts use relative paths within the repository. No absolute file system paths are hardcoded. This ensures portability when the repository is extracted from a ZIP archive onto a different system.

5. Execution Order (Runbook)

5.1 Pre Conditions

Before running the buld certain characteristics have to be met for it to work and applied the desired configuration:

- Confirm correct values exist in the data file .\DSC\Data\AllNodes.psd1 values set should match the machine internal settings (computer name, internal NIC alias, IPV4 address, DNS address, domain name and role)

- Ensure DSC required modules by the orchestrator are installed with the correct version. eg; ActiveDirectoryDsc, NetworkingDsc, ComputerManagmentsDsc

- Ensure credentials are passed at runtime and not harcoded into configuration or data files.

5.2 Compile the DSC Configuration

Compilation is triggered from the repository root:

.\BuildMain.ps1

This step:

Loads configuration data (AllNodes.psd1)

Compiles the StudentBaseline configuration (from StudentConfig.ps1)

Generates MOF output under:

.\DSC\Outputs\

5.3 Apply the Configuration

The compiled configuration is applied using:

Start-DscConfiguration -Path .\DSC\Outputs -Wait -Verbose -Force

Execution order (high level) is:

Base OS configuration (computer name / time zone / services)

Network configuration (static IP + internal DNS settings, NAT DNS registration disabled)

AD DS feature installation

Forest creation and DC promotion (requires credentials)

Post-promotion AD configuration (OUs, groups, users)

GPO creation/linking to scoped OUs (where applicable)

This ordering ensures AD objects and policy links are only applied after the domain exists.

5.4 Reboot and Promotion Behaviour

Domain promotion triggers an automatic reboot as part of AD DS forest creation. If promotion does not complete within the orchestrator run, a manual reboot is performed to finalise the promotion stage. After reboot, the system is validated before any further changes are made.

5.5 Validate the Baseline

Validation is executed in two layers:

Tutor validation suite (full baseline compliance):

Invoke-Validation

Student validation suite (governance structure + security policy targeting):

Invoke-Pester -Path .\Tests\Pester\Student-Pester_ProofOfLife.ps1 -Output Detailed

Expected outcome is all tests passing. Failed tests indicate configuration drift, missing objects, incorrect OU paths, incorrect policy links, or misconfigured DNS.

5.6 Evidence Capture Locations

Evidence is stored under the repository Evidence folder to keep build artifacts separate from source code:

MOF output: .\DSC\Outputs\

Pester transcripts/results: .\Evidence\Pester\

PowerShell transcripts: .\Evidence\Transcripts\

Screenshots (if required): .\Evidence\Screenshots\

6. Idempotence and Re-Run Behaviour 

- Idempotence

This means that the system is safe to be run multiple times. The build can be executed as many times as needed, and if the actual state of the machine already matches the DSC configuration, the orchestrator will not generate duplicates or throw errors.

- Convergence

This allows an easy rebuild. If something was deleted by accident, such as an OU for example, and the orchestrator detects that it is not present, it will recreate it and link the correct properties to that object. If the object is already there, the system acknowledges it and skips it, meaning no error and no duplicate is created. Avoiding drifts in the environment.

DSC gets the data file and uses it together with the configuration file. The data file represents what has to be there (the exact values), and the configuration file defines how it should be there.

DSC then compares this with the current system state, for example the system’s own IPv4 address.

After compilation, a MOF file is generated which defines the execution order and what must be implemented. This MOF file is then read by the Local Configuration Manager (LCM), which enforces the desired state on the system rather than just describing it.

DSC follows an execution order described before if any of the dependencies mentioned before was to fail the orchestrator will stop the build, signal where is the error and why it was caused.

Evidence of the second run of execution:

.\Evidence\Transcripts\20260225_000339_Run_BuildMain.txt

7. Validation and Testing Model

After the system is built by DSC, it is considered best practice to validate whether the desired state has been fully applied or if something is missing. Pester tests are declarative scripts that check whether a given condition is true or not.

They are highly useful because they indicate both the input received and the expected input. They also have the capability to be specific when highlighting where something is wrong, although this depends on how the Pester test is written and structured.

A system cannot be considered reliable if it has not been validated. Validating through declarative tests is one of the easiest and most effective ways to assess the state of a machine or environment.

As mentioned previously, Pester tests can validate multiple aspects of the configuration, such as:

Whether a GPO is linked to the correct OU

Whether the correct objects exist in the directory

Whether policies are applied as intended

Pester output is relatively easy to follow, as it produces a human-readable result. When a test fails, the output highlights the error location and shows the expected versus actual values.

As seen in the evidence:

.\Evidence\Pester\Pester-Detailed-20260224-185115.txt

The Pester framework evaluates whether the defined condition has been met. If the condition is satisfied, the result is marked as Passed. If it is not satisfied, it is marked as Failed, and the output highlights where the error occurred or what external issue caused it (for example, a missing DSC resource).

Add this near the end:

The validation suite is structured to test multiple categories of the environment, including domain state, OU structure, security group placement, user provisioning, GPO linking and DNS configuration. This ensures that the baseline is assessed as a complete system rather than in isolation.

Validation can be executed repeatedly after configuration runs to confirm that no drift has occurred and that the environment remains compliant with the defined state.

8. Security Considerations

8.1 Credentials Hardening

Credential management is not handled directly by DSC in the deployment of this environment. This decision aligns with best security practices, as sensitive data such as passwords should never be stored in plain text within configuration files. Instead, PSCredential objects are used to pass password values during Active Directory setup, but these credentials are not hardcoded anywhere.

MOF files are generated artifacts that should not contain or expose any credentials. If exposed, these could allow a threat actor to modify, disrupt, or compromise the system.

The Local Configuration Manager (LCM) reads the MOF files and enforces the defined configuration locally. No external sources or credential management systems are used to read or deploy the desired configuration in this lab environment.

Considerations for Production-level Security:
In a production environment, certificate-based MOF encryption and integration with a secure vault (e.g., Azure Key Vault) would be implemented for enhanced security, ensuring credentials are protected at all times.

8.2 DNS Security and Network Exposure

For the deployment of this environment, two NICs have been configured: NAT and Host-Only.

The NAT NIC is required for both the Domain Controller (DC) and the development machine (Dev) to download updates or access external resources.

The Host-Only adapter is used specifically for DNS resolution. The DC uses the loopback address of this adapter to resolve DNS queries. Clients can only join the domain if they share the same local network adapter.

NAT is disabled for DNS registration to enhance security by isolating the DC from the external network. This prevents potential threats like DNS spoofing, caching poisoning, or other man-in-the-middle attacks.

This setup ensures that only authorized and trusted machines can join the domain and query DNS, significantly reducing the risk of unauthorized access.

8.3 OU and Delegation Design Intent

The OU structure is split into three sections:

Control Plane: Contains critical assets like the Domain Controller (DC) and related administrative policies.

Management Plane: Houses IT admins and privileged accounts, but these are scoped outside of domain-level policies.

User Access Plane: Covers user endpoints, clients, and service accounts with restricted privileges.

The purpose of this structure is to apply GPOs and delegation logically, ensuring that policies only impact the intended objects. This setup follows the least privilege model, granting only the necessary permissions for each group or OU, preventing unnecessary access or conflicts across different objects.

8.4 RBAC Design

RBAC is implemented based on the least privilege principle. The security groups reflect necessary roles within the organization, and permissions are assigned to these groups, not individual users.

Key security groups:

GG-IT-Admins: Full administrative access to the IT infrastructure.

GG-HR-Staff: Access to HR-related resources with no admin rights.

GG-Server-Admins: Admin access to server resources.

Security Group Usage

To give users outside an OU the ability to perform privileged tasks, a security group is created and added to the OU's permissions.

For example, if a user from the User Access Plane needs access to resources in the Computers OU:

A security group like GG-Computer-Admins is created.

The user is added to this group.

The group is granted the necessary permissions.

This ensures that access is specific and controlled, keeping the environment secure while enabling required actions without over-privileging users.

8.6 Explicit Trade-Offs Made for Lab Realism vs Enterprise Practice
Trade-Off 1: Use of a Single Domain Controller

Only one Domain Controller (DC) is deployed because higher-level complexity is not required for the scope of this project demonstration. This increases simplicity, reduces configuration overhead, and allows controlled testing of the automation workflow.

In an enterprise environment, multiple Domain Controllers would be deployed to eliminate a single point of failure, provide redundancy, improve fault tolerance, and support scalability. Active Directory replication between DCs would ensure directory consistency and availability across the network. The lab design prioritises clarity and reproducibility over high availability.

Trade-Off 2: Limited GPO Depth

The GPO configuration implemented in this lab is security-relevant and functions as intended, however it does not reflect the depth expected in a production enterprise environment.

In a real-world infrastructure, GPO design would be significantly more layered and structured. Additional policies would typically include:

Advanced auditing

Security baselines aligned to frameworks (e.g., CIS)

Password complexity enforcement for privileged accounts

WMI filtering for precise targeting

Layered inheritance strategies

In this lab, GPOs are intentionally scoped only to the relevant OUs to demonstrate policy targeting and avoid over-complication. The objective is to prove correct linkage and enforcement, not to implement a full enterprise governance framework.

Trade-Off 3: DNS Architecture

In this lab environment, DNS is hosted on the single Domain Controller. This is sufficient to demonstrate the relationship between DNS, clients, and Active Directory name resolution.

In an enterprise infrastructure, DNS redundancy is required to avoid a single point of failure and to support load balancing. Multiple DNS servers would be deployed, often across different sites, with replication and potentially conditional forwarders or split-DNS configurations. The lab environment simplifies DNS to focus on functional correctness rather than infrastructure resilience.

9. Evidence Mapping

9.1 Domain Controller Build & Automation

DC promoted using DSC via Run_BuildMain.ps1	
Evidence/Transcripts/20260225_000339_Run_BuildMain.txt

DSC configuration compiled successfully	
Evidence/DSC/BuildMain-Compile.txt

MOF generated for StudentBaseline	
DSC/Outputs/StudentBaseline/localhost.mof

Idempotent re-run confirmed	
Evidence/Transcripts/20260225_000339_Run_BuildMain.txt

9.2 Active Directory Health & Core Services

Domain information validated 
Evidence/HealthChecks/domain_info.txt

Forest information validated
Evidence/HealthChecks/forest_info.txt

DC health verified (dcdiag)
Evidence/AD/dcdiag_output.txt

Kerberos functioning
Evidence/HealthChecks/Kerberos_info.txt

Windows Time service verified
Evidence/HealthChecks/Windows_Time_Service_info.txt

9.3 OU Structure & Governance Model

ControlPlane, ManagementPlane, UserAccessPlane exist
Evidence/HealthChecks/ou_listing.txt

Sub-OUs (Users, Groups, Computers, AdminUsers) created
Evidence/HealthChecks/ou_listing.txt

9.4 Group Policy Design & Enforcement

User hardening GPO created and backed up 
Evidence/GPOBackups/

Computer baseline GPO created and backed up
Evidence/GPOBackups/

Computer GPO applied successfully
Evidence/HealthChecks/gpresult_computer.txt

User GPO applied successfully
Evidence/HealthChecks/gpresult_user.txt

9.5 DNS & Network Validation

DNS zone information verified
Evidence/HealthChecks/DNS_Records_info.txt

Global DNS records verified	
Evidence/HealthChecks/DNS_Records_Global_info.txt

Network configuration verified
Evidence/Network/*_ipconfig.txt

9.6 Validation & Testing (Pester)

Tutor baseline tests pass
Evidence/Pester/PesterResults_20260224_193234.xml

Student tests validate OU and RBAC 
Evidence/Pester/Pester_RBAC_Groups.txt

Detailed Pester execution log
Evidence/Pester/Pester-Detailed-20260224-192037.txt

9.7 Provenance & Academic Integrity

AI usage declared 
Evidence/AI_LOG/AI-Usage.md

Git reflog captured	
Evidence/Git/Reflog/

This implementation prioritises automation clarity and reproducibility over enterprise-scale resilience.

A single Domain Controller is deployed; no replication or multi-DC failover is demonstrated.

DNS is hosted on the DC and is not redundant.

GPO design demonstrates correct targeting and enforcement but does not represent a full enterprise security baseline.

No multi-site topology or WAN replication scenario is implemented.

Secret management is handled via PSCredential objects; certificate-based MOF encryption is not configured.

These constraints reflect the scope of the lab environment rather than a production deployment model.