# Design Notes (Student)

Explain your decisions:
- OU structure rationale
Derby as child domain within the Bolton forest.
Nottingham is implemented as an OU within the Derby domain instead of a separate domain.
- Group model rationale
Groups follow role based access control (RBAC)
Least priviledge principle
Policy focused
- GPO linking choices (later)
The domain is the primary security boundary
OU's are used only for administrative/policy boundaries
Derby needs different security and policy measures as it is an independent domain.
- Any security controls you applied

