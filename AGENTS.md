# Critical Project Rules & Workflow Constraints

## ⚠️ STRICT RULE: HCP Profile Submission Workflow (`HCP Profile Submission WF`)

### 1. Fixed 12 Transition Rules (NO ADDITIONS, NO DELETIONS)
The **Transition Rules** (`transitions`) table in `HCP Profile Submission WF` must **ALWAYS REMAIN EXACTLY 12 ROWS**.
- **DO NOT** delete any of the 12 transition rows.
- **DO NOT** add any new rows.
- The 12 rows are strictly defined as follows:

| No. | State | Action | Next State | Allowed Role | Notes / Condition |
| :---: | :--- | :--- | :--- | :--- | :--- |
| **1** | Draft | Submit for Processing | Processed | System Manager | `doc.profile_action=="Existing HCP"` |
| **2** | Draft | Submit for Processing | Processed | Sales User | `doc.profile_action=="Existing HCP"` |
| **3** | Draft | Submit for Approval | Pending Approval | System Manager | `doc.profile_action=="New HCP"` |
| **4** | Draft | Submit for Approval | Pending Approval | Sales Manager | `doc.profile_action=="New HCP"` |
| **5** | Draft | Submit for Approval | Pending Approval | Sales User | `doc.profile_action=="New HCP"` |
| **6** | Pending Approval | Approve | Approved | System Manager | |
| **7** | Pending Approval | Approve | Approved | Sales Manager | |
| **8** | Pending Approval | Reject | Rejected | System Manager | |
| **9** | Pending Approval | Reject | Rejected | Sales Manager | |
| **10** | Rejected | Submit for Approval | Pending Approval | System Manager | |
| **11** | Rejected | Submit for Approval | Pending Approval | Sales User | |
| **12** | Rejected | Submit for Approval | Pending Approval | Sales Manager | |

---

### 2. Mandatory Preservation of Conditions
**DO NOT EVER DELETE OR REMOVE** the condition expressions under the **Transition Rules** (`transitions`) table:
- **`doc.profile_action=="New HCP"`**
- **`doc.profile_action=="Existing HCP"`**

These conditions control the core business routing between automatic processing and approval cycles.

---

### 3. Absolute Constraint
Any modification, row addition, row removal, or condition deletion in this workflow is **strictly prohibited** unless explicitly requested and approved by the user.
