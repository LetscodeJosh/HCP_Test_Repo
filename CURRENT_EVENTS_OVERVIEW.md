# Current Events Overview

This document provides a chronological and comprehensive overview of all architectural developments, server configurations, UI enhancements, and workflow testing completed during this session for the **HCP Profiling Application**.

---

## 1. Executive Summary & Core Milestones

1. **Managerial Viewing Access & Program Data Isolation**:
   - Enforced strict program-level boundary isolation across `Doctor Masterlist`, `Dashboard`, and `Submissions History`.
   - Managers (DSM / NSM) only see data tied to their assigned program (e.g., Bayer, RiteMed, ADC), while System Managers retain universal cross-program visibility.
   - Normalized program abbreviations (`RTMD` $\leftrightarrow$ `RiteMed`, `BCH` $\leftrightarrow$ `Bayer`, `ADC` $\leftrightarrow$ `Abbott Diabetes Care`) via `LocationResolver`.

2. **Apple Glassmorphic Login Screen Redesign**:
   - Upgraded the login page to modern Apple glassmorphism (macOS / iOS / visionOS design language).
   - Added real optical Gaussian backdrop blur (`sigmaX: 30`, `sigmaY: 30`), frosted acrylic translucency, Apple-style squircle icons, and responsive constraints.

3. **ERPNext Workflow Alignment (Strictly 10 Transition Rules)**:
   - Synchronized the mobile application with the server-side `HCP Profile Submission WF` on `https://dev.pmii-marketing.com`.
   - Maintained exactly **10 transition rows** without altering workflow actions or condition strings (`doc.profile_action=="Existing HCP"` / `doc.profile_action=="New HCP"`).
   - Updated **Row 9 Allowed Role from `System Manager` to `Sales Manager`** to empower District Sales Managers (DSM) to execute `Submit for Approval` on `Rejected` submissions.

4. **District 1, 2, and 3 Bayer Workflow Testing Matrix**:
   - Resolved the full sales hierarchy (DSM $\rightarrow$ MedRep) and territory codes across District 1 (`BA1`), District 2 (`BA2 - West GMA`), and District 3 (`BA4 - South Luzon`).
   - Validated that testing can be performed on the existing installed app without rebuilding or reinstalling `.ipa` files.

---

## 2. Server-Side Workflow Transition Rules (Strictly 10 Rows)

Server configuration verified on `https://dev.pmii-marketing.com` (`HCP Profile Submission WF`):

| Row | State | Action | Next State | Allowed Role | Condition Expression | Workflow Role / Purpose |
| :---: | :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | `Draft` | `Submit for Processing` | `Processed` | `System Manager` | `doc.profile_action=="Existing HCP"` | Existing Doctor (Admin) |
| **2** | `Draft` | `Submit for Processing` | `Processed` | **`Sales User`** | `doc.profile_action=="Existing HCP"` | **MedRep Existing Doctor Auto-Merge** |
| **3** | `Draft` | `Submit for Approval` | `Pending Approval` | `System Manager` | `doc.profile_action=="New HCP"` | New Doctor (Admin) |
| **4** | `Draft` | `Submit for Approval` | `Pending Approval` | **`Sales User`** | `doc.profile_action=="New HCP"` | **MedRep New Doctor Submission** |
| **5** | `Pending Approval` | `Approve` | `Approved` | `System Manager` | `doc.profile_action=="New HCP"` | Doctor Approval (Admin) |
| **6** | `Pending Approval` | `Approve` | `Approved` | **`Sales Manager`** | `doc.profile_action=="New HCP"` | **DSM Doctor Approval** |
| **7** | `Pending Approval` | `Reject` | `Rejected` | `System Manager` | `doc.profile_action=="New HCP"` | Doctor Rejection (Admin) |
| **8** | `Pending Approval` | `Reject` | `Rejected` | **`Sales Manager`** | `doc.profile_action=="New HCP"` | **DSM Doctor Rejection** |
| **9** | `Rejected` | `Submit for Approval` | `Pending Approval` | **`Sales Manager`** | `doc.profile_action=="New HCP"` | **DSM Resubmit for Approval** *(Updated)* |
| **10** | `Rejected` | `Submit for Approval` | `Pending Approval` | **`Sales User`** | `doc.profile_action=="New HCP"` | **MedRep Resubmit for Approval** |

> **Key Rationale for Row 9 Update**: In ERPNext, `System Manager` has global administrator bypass privileges. Updating Row 9 to `Sales Manager` allowed District Sales Managers to resubmit rejected submissions directly, fulfilling the spreadsheet test matrix while adhering strictly to the 10-row limit.

---

## 3. Bayer Districts Accounts & Hierarchy Matrix

```text
Bayer Consumer Health
├── District 1 (BA1 - South Luzon / GMA)
│   └── DSM: Raymond Viray (BA1)
│       └── MedRep: Arlane Ferraren (BA1-05)
│
├── District 2 (BA2 - West GMA)
│   └── DSM: Gin Orcullo (BA2)
│       ├── MedRep: Charisse Capulong (BA2-02)  ★ Primary Active
│       ├── MedRep: Marie Joy Sadia (BA2-08)
│       └── MedRep: Adrian Pagdanganan (BA2-03)
│
└── District 3 (BA4 - South Luzon)
    └── DSM: Christopher Rinon (BA4)
        ├── MedRep: Carmel Videna (BA4-01)      ★ Primary Active
        ├── MedRep: Nelson Rivera (BA4-03)
        └── MedRep: Jericho Agapito (BA4-08)
```

### Complete Accounts Table:

| District | Hierarchy | Sales Person Tree Name | Territory Code | Login Email | ERPNext Roles |
| :--- | :--- | :--- | :---: | :--- | :--- |
| **District 1** | **DSM** | Raymond Viray (BA1) | `BA1` | `rbviray@profinsights.biz` | `Sales Manager`, `Sales User`, `Employee` |
| **District 1** | **MedRep** | Arlane Ferraren (BA1-05) | `BA1-05` | `arlaneferraren8@gmail.com` | `Sales User`, `Employee` |
| **District 2** | **DSM** | Gin Orcullo (BA2) | `BA2` | `ginlorcullo@profinsights.biz` | `Sales Manager`, `Sales User`, `Employee` |
| **District 2** | **MedRep** | Charisse Capulong (BA2-02) | `BA2-02` | `gallegoscharisse@gmail.com` | `Sales User`, `Employee` |
| **District 2** | *Alt MedRep*| Marie Joy Sadia (BA2-08) | `BA2-08` | `sadiamjoy1266@gmail.com` | `Sales User`, `Employee` |
| **District 3** | **DSM** | Christopher Rinon (BA4) | `BA4` | `cmrinon@profinsights.biz` | `Sales Manager`, `Employee` |
| **District 3** | **MedRep** | Carmel Videna (BA4-01) | `BA4-01` | `carmelannevidena@yahoo.com` | `Sales User`, `Employee` |
| **District 3** | *Alt MedRep*| Nelson Rivera (BA4-03) | `BA4-03` | `nelson_rivera18@yahoo.com` | `Sales User`, `Employee` |

---

## 4. End-to-End Workflow & Testing Verification Guide

```
                          ┌──────────────────────────┐
                          │   1. Existing Doctor     │ (MedRep: arlaneferraren8@gmail.com)
                          │  Submit for Processing   │
                          └─────────────┬────────────┘
                                        ▼
                                  [ Processed ] ──► (Auto-merged to HCP Masterlist)
                                  
                          ┌──────────────────────────┐
                          │     2. New Doctor        │ (MedRep: arlaneferraren8@gmail.com)
                          │   Submit for Approval    │
                          └─────────────┬────────────┘
                                        ▼
                               [ Pending Approval ]
                                        │
                                        │ (DSM: rbviray@profinsights.biz clicks Reject)
                                        ▼
                                  [ Rejected ]
                                        │
                    ┌───────────────────┴───────────────────┐
                    ▼                                       ▼
       (DSM: rbviray@profinsights.biz)        (MedRep: arlaneferraren8@gmail.com)
         "Resubmit for Approval"                 "Resubmit for Approval"
                    │                                       │
                    └───────────────────┬───────────────────┘
                                        ▼
                               [ Pending Approval ]
                                        │
                                        │ (DSM: rbviray@profinsights.biz clicks Approve)
                                        ▼
                                  [ Approved ] ──► (Committed to HCP & HCP Account)
```

### Flow A: Existing Doctor Workflow (`Submit for Processing`)
- **Action**: `Submit for Processing (Draft/Processed)`
- **Role**: `Sales User`
- **Steps**:
  1. Log in as MedRep (`arlaneferraren8@gmail.com` / `gallegoscharisse@gmail.com` / `carmelannevidena@yahoo.com`).
  2. Select program **Bayer Consumer Health - Team 1** (or BCH).
  3. Open **Doctor Masterlist**, select an existing doctor (e.g., `Dr. Carmela Reyes Villanueva`).
  4. Modify contact/workplace details, tap **Submit for Processing**.
- **Expected Result**: Transitions immediately to **`Processed`**. Direct auto-merge into `HCP` masterlist without requiring manager approval.

---

### Flow B: New Doctor Workflow (5-Step Lifecycle)

1. **MedRep Submits New Doctor (`Draft` $\rightarrow$ `Pending Approval`)**:
   - Tap `+ Add Doctor` $\rightarrow$ New Doctor, fill details, and tap **Submit for Approval**.
   - Result: State becomes **`Pending Approval`**.
2. **DSM Rejects Submission (`Pending Approval` $\rightarrow$ `Rejected`)**:
   - Log in as DSM, open the submission under **Submissions History**.
   - Tap **Reject**, provide remarks, and confirm.
   - Result: State becomes **`Rejected`**.
3. **DSM Resubmits for Approval (`Rejected` $\rightarrow$ `Pending Approval`)**:
   - **Remain logged in as DSM**. Tap the **`Rejected`** submission in **Submissions History**.
   - Tap the orange **"Resubmit for Approval"** button.
   - Result: State transitions back to **`Pending Approval`** (Enabled by Row 9 update).
4. **MedRep Resubmits for Approval (`Rejected` $\rightarrow$ `Pending Approval`)**:
   - DSM rejects again to return state to `Rejected`.
   - Log in as MedRep, open the `Rejected` submission, and tap **"Resubmit for Approval"**.
   - Result: State transitions back to **`Pending Approval`** (Row 10).
5. **DSM Approves Doctor (`Pending Approval` $\rightarrow$ `Approved`)**:
   - Log in as DSM, open the submission in `Pending Approval`.
   - Tap **Approve** and confirm.
   - Result: State becomes **`Approved`**. Doctor is created in universal `HCP` masterlist and linked to `HCP Account`.

---

## 5. Technical Validation & Repository Status

- **Zero Client Reinstall**: Mobile client communicates dynamically with the ERPNext API; updating Row 9 on the server enabled the DSM resubmission immediately on all currently installed mobile clients without new IPA distribution.
- **Git Repository Status**: 
  - Working tree clean.
  - Branch `main` up to date with `origin/main`.
  - All unit tests and static analysis verified with 0 errors.
