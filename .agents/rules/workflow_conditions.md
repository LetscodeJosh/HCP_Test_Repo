# Frappe Workflow Rule: HCP Profile Submission WF

## APPLICATION WORKFLOW & ARCHITECTURE STANDARD

1. **Two-Tier Architecture**:
   - **`HCP` DocType**: Universal masterlist of all doctors across all programs.
   - **`HCP Account` DocType**: Masterlist per program (e.g. Abbott Diabetes Care, Bayer) with program-specific preferred items.

2. **Application Submission Rules (1:1 with ERPNext WF)**:
   - **Existing Doctor (`Existing HCP`)**:
     - Action: `Submit for Processing` $\rightarrow$ State: `Processed` (Rows 1 & 2: `doc.profile_action=="Existing HCP"`).
     - Requires NO managerial approval; merges automatically upon submission with preferred items active.
   - **New Doctor (`+ Add New Doctor` / `New HCP`)**:
     - Action: `Submit for Approval` $\rightarrow$ State: `Pending Approval` (Rows 3, 4, 5: `doc.profile_action=="New HCP"`).
     - Requires Managerial Approval (`Sales Manager` or `System Manager`).
     - Action: `Approve` $\rightarrow$ State: `Approved` (Rows 6 & 7: `doc.profile_action=="New HCP"`).

3. **ERPNext Workflow Conditions Preservation**:
   - The set conditions (`doc.profile_action=="Existing HCP"` and `doc.profile_action=="New HCP"`) in `HCP Profile Submission WF` are standard and must NOT be changed or removed by the agent.


