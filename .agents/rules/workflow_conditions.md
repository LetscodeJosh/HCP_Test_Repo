# Frappe Workflow Rule: HCP Profile Submission WF

## STRICT CONSTRAINT: EXACTLY 12 TRANSITION ROWS & PRESERVED CONDITIONS

### 1. Row Count & Structure Constraint
The Transition Rules table for **`HCP Profile Submission WF`** must **always remain exactly 12 rows**.
- **NO rows may be added.**
- **NO rows may be deleted.**

The exact 12-row configuration:
1. `Draft` -> `Submit for Processing` -> `Processed` (`System Manager`) [Condition: `doc.profile_action=="Existing HCP"`]
2. `Draft` -> `Submit for Processing` -> `Processed` (`Sales User`) [Condition: `doc.profile_action=="Existing HCP"`]
3. `Draft` -> `Submit for Approval` -> `Pending Approval` (`System Manager`) [Condition: `doc.profile_action=="New HCP"`]
4. `Draft` -> `Submit for Approval` -> `Pending Approval` (`Sales Manager`) [Condition: `doc.profile_action=="New HCP"`]
5. `Draft` -> `Submit for Approval` -> `Pending Approval` (`Sales User`) [Condition: `doc.profile_action=="New HCP"`]
6. `Pending Approval` -> `Approve` -> `Approved` (`System Manager`)
7. `Pending Approval` -> `Approve` -> `Approved` (`Sales Manager`)
8. `Pending Approval` -> `Reject` -> `Rejected` (`System Manager`)
9. `Pending Approval` -> `Reject` -> `Rejected` (`Sales Manager`)
10. `Rejected` -> `Submit for Approval` -> `Pending Approval` (`System Manager`)
11. `Rejected` -> `Submit for Approval` -> `Pending Approval` (`Sales User`)
12. `Rejected` -> `Submit for Approval` -> `Pending Approval` (`Sales Manager`)

### 2. Mandatory Condition Expressions
Under no circumstances should the `condition` field in the Transition Rules table be deleted, cleared, or modified:
- `doc.profile_action=="New HCP"`
- `doc.profile_action=="Existing HCP"`

**Any deviation, row removal, row addition, or condition edit is strictly prohibited without explicit user instruction and approval.**
