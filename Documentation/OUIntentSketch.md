# OU Intent Sketch — BarmBuzz

## Forest Root Domain: bolton.corp

OU Structure (Management Model)

OU=Bolton
│
├── OU=Users
├── OU=Computers
├── OU=Servers
├── OU=Workstations
├── OU=Groups
├── OU=Admin
└── OU=ServiceAccounts

Rationale:
This structure separates identities, endpoints, and roles to support
policy targeting, administrative delegation, and operational clarity.

---

## Planned Child Domain: derby.bolton.corp

OU Structure (Regional Management Model)

OU=Derby
│
├── OU=Users
├── OU=Computers
├── OU=Servers
├── OU=Workstations
├── OU=Groups
├── OU=Admin
├── OU=ServiceAccounts
└── OU=Nottingham

Rationale:
Derby operates as a delegated regional domain.
Nottingham is modelled as an OU for management separation,
NOT as a security boundary.

---

## Governance & Policy Intent

• Group Policy Objects (GPOs) will be linked at OU level  
• Policies will NOT be blindly applied at domain root  
• OUs define management scope, NOT security isolation  

Key Principle:
An OU is NOT a security boundary.
A domain IS a security boundary.

---

## Administrative Delegation Model (Planned)

Example Delegation Strategy:

• Helpdesk → OU=Workstations  
• HR Admin → OU=Users  
• Server Admin → OU=Servers  

Rationale:
Delegation follows least-privilege / RBAC principles.

---

## Security Boundary Clarification

Within bolton.corp:

• All OUs share the same security boundary

Between bolton.corp and derby.bolton.corp:

• Domains represent security boundaries
• Trust enables authentication, NOT automatic authorisation
