1. Solution Overview

This solution implements an automated Active Directory forest deployment using Infrastructure as Code (IaC) principles. The environment uses Windows Server 2025 as the Domain Controller and Windows 11 as the development machine. Deployment is fully declarative and driven by DSC v3.

The current implementation is based on a single-domain forest model, aligned with the business requirements described in the BarmBuzz scenario.

The forest layout is:

Forest Root Domain: bolton.corp

Domain Functional Level: Defined in ConfigurationData

Forest Functional Level: Defined in ConfigurationData

The Domain Controller is built entirely through DSC v3. No manual configuration of Active Directory objects is required after initial VM preparation.

Operating systems involved in the solution:

Windows Server 2025 (Domain Controller)

Windows 11 (Development machine)

Windows 11 (Domain-joined client)

Ubuntu (Domain-joined client)

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

The solution follows a modular design. Although the baseline is single-domain, the structure allows for extension to a multi-domain forest (for example, adding derby.bolton.corp as a child domain). This supports higher-grade requirements without redesigning the automation logic.

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

Control Plane – Contains high-privilege administrative groups and accounts.

Management Plane – Contains delegated administrative groups and infrastructure-related objects.

User Access Plane – Contains standard user accounts, role-based security groups, and client computers.

Example high-level structure:

bolton.corp
│
├── OU=ControlPlane
├── OU=ManagementPlane
├── OU=UserAccessPlane

The purpose of this structure is to:

Prevent privilege sprawl

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

The IT-Helpdesk group does not receive Domain Admin privileges.

Delegation is applied at the OU scope rather than at the domain root. This prevents excessive privilege inheritance and ensures administrative permissions remain restricted to their intended boundary.

This model supports operational efficiency while maintaining least privilege enforcement.

2.5 RBAC Intent

Role-Based Access Control (RBAC) is implemented through:

Security groups representing job roles

Group-based permission assignment

Separation between administrative and standard accounts

No direct permissions are assigned to user accounts outside of role-based groups.

Administrative accounts are separated from daily-use accounts to reduce exposure risk.

This structure ensures that access to resources, administrative actions, and policy enforcement can be traced to group membership rather than individual discretionary permissions.

2.6 Default Container Hygiene

The default Active Directory containers:

CN=Users
CN=Computers

are not used for governance.

User and computer objects are placed into structured OUs to ensure:

Predictable Group Policy application

Delegation control at the correct scope

Consistent automation behaviour

Reduced administrative ambiguity

Leaving objects in default containers would bypass the governance model and weaken policy targeting consistency.

2.7 Security Boundary Clarification

It is important to explicitly state:

An OU is not a security boundary.

A domain is a security boundary.

Although OUs allow administrative delegation and policy scoping, authentication and trust enforcement occur at the domain level.

Cross Domain Acess:

Users from one domain can be authorized to another domain by default because of the existing trust relationship within the forest, however they cannot access resources unlesss explicitily configured to do so by the domain admins.

