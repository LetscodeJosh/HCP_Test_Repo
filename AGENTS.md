# Critical Project Rules & Workflow Constraints

## 📋 Core App Workflow & Architecture Standard

### 1. The Two-Tier Masterlist Architecture
* **`HCP` DocType**: Universal masterlist of all doctors present across every program.
* **`HCP Account` DocType**: Masterlist **per program** (e.g., Abbott Diabetes Care, Bayer, COREnergy) where doctor affiliations repeat across different programs with program-specific preferred items (workplace, specialization, contacts).

### 2. Application Workflow Rules (Strictly Aligned with ERPNext HCP Profile Submission WF)
1. **Existing Doctor (`Existing HCP`)**:
   * **Action**: `Submit for Processing` $\rightarrow$ State: **`Processed`** (Rows 1 & 2: `doc.profile_action=="Existing HCP"`).
   * **Requires NO Managerial Approval**.
   * Merges automatically upon submission directly into the `HCP` record and syncs `HCP Account` with the **preferred** features active.
2. **New Doctor (`+ Add New Doctor` / `New HCP`)**:
   * **Action**: `Submit for Approval` $\rightarrow$ State: **`Pending Approval`** (Rows 3, 4, 5: `doc.profile_action=="New HCP"`).
   * **Requires Managerial Approval** (`Sales Manager` or `System Manager`).
   * Manager clicks **`Approve`** $\rightarrow$ State: **`Approved`** (Rows 6 & 7: `doc.profile_action=="New HCP"`).
   * Committed to the masterlist only after approval.

### 3. ERPNext Workflow Rule
* Do **NOT** modify or change the set `condition` expressions (`doc.profile_action=="Existing HCP"` / `doc.profile_action=="New HCP"`) in `HCP Profile Submission WF` on the ERPNext server. The app matches this server-side workflow 1:1.


