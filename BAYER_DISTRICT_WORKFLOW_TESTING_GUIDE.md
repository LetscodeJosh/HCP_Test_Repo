# Bayer District Workflow Testing Guide & Chat Record

> **Generated on:** September 10, 2026  
> **Repository:** `HCP_Test_Repo`  
> **Server:** `https://dev.pmii-marketing.com`  
> **DocType:** `HCP Profile Submission`  
> **Workflow:** `HCP Profile Submission WF`  

---

## 1. ERPNext Transition Rules Alignment (Strictly 10 Rows)

The server developer strictly defined 10 transition rules for `HCP Profile Submission WF`. To ensure DSM (`Sales Manager`) can execute **`Submit for Approval (Rejected/Pending Approval)`** without exceeding the 10-row limit or altering the action workflow, **Row 9 was adjusted from `System Manager` to `Sales Manager`**.

### Master Transition Table (10 Rows Locked)

| Row | State | Action | Next State | Allowed Role | Condition | Workflow Role |
| :---: | :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | `Draft` | `Submit for Processing` | `Processed` | `System Manager` | `doc.profile_action=="Existing HCP"` | Admin Existing Doctor |
| **2** | `Draft` | `Submit for Processing` | `Processed` | `Sales User` | `doc.profile_action=="Existing HCP"` | **MedRep Existing Doctor (Auto-Merge)** |
| **3** | `Draft` | `Submit for Approval` | `Pending Approval` | `System Manager` | `doc.profile_action=="New HCP"` | Admin New Doctor |
| **4** | `Draft` | `Submit for Approval` | `Pending Approval` | `Sales User` | `doc.profile_action=="New HCP"` | **MedRep New Doctor Submission** |
| **5** | `Pending Approval` | `Approve` | `Approved` | `System Manager` | `doc.profile_action=="New HCP"` | Admin Approval |
| **6** | `Pending Approval` | `Approve` | `Approved` | `Sales Manager` | `doc.profile_action=="New HCP"` | **DSM Doctor Approval** |
| **7** | `Pending Approval` | `Reject` | `Rejected` | `System Manager` | `doc.profile_action=="New HCP"` | Admin Rejection |
| **8** | `Pending Approval` | `Reject` | `Rejected` | `Sales Manager` | `doc.profile_action=="New HCP"` | **DSM Doctor Rejection** |
| **9** | `Rejected` | `Submit for Approval` | `Pending Approval` | **`Sales Manager`** | `doc.profile_action=="New HCP"` | **DSM Resubmit for Approval** *(Updated)* |
| **10** | `Rejected` | `Submit for Approval` | `Pending Approval` | **`Sales User`** | `doc.profile_action=="New HCP"` | **MedRep Resubmit for Approval** |

---

## 2. Test Account Directory by District (Bayer Consumer Health)

### District 1: BA1 (Team 1 / South Luzon)
- **DSM**: Raymond Viray (BA1)
  - **Login Email:** `rbviray@profinsights.biz`
  - **Territory:** `BA1`
  - **Roles:** `Sales Manager`, `Sales User`, `Employee`
- **MedRep**: Arlane Ferraren (BA1-05)
  - **Login Email:** `arlaneferraren8@gmail.com`
  - **Territory:** `BA1-05`
  - **Roles:** `Sales User`, `Employee`

---

### District 2: BA2 (West GMA)
- **DSM**: Gin Orcullo (BA2)
  - **Login Email:** `ginlorcullo@profinsights.biz`
  - **Territory:** `BA2`
  - **Roles:** `Sales Manager`, `Sales User`, `Employee`
- **MedRep (Primary)**: Charisse Capulong (BA2-02)
  - **Login Email:** `gallegoscharisse@gmail.com`
  - **Territory:** `BA2-02`
  - **Roles:** `Sales User`, `Employee`
- **Alternative MedReps**:
  - Marie Joy Sadia (`BA2-08`): `sadiamjoy1266@gmail.com`
  - Adrian Pagdanganan (`BA2-03`): `adrianpagdanganan16@gmail.com`

---

### District 3: BA4 (South Luzon)
- **DSM**: Christopher Rinon (BA4)
  - **Login Email:** `cmrinon@profinsights.biz`
  - **Territory:** `BA4` (or `BA4 - SOUTH LUZON`)
  - **Roles:** `Sales Manager`, `Employee`
- **MedRep (Primary)**: Carmel Videna (BA4-01)
  - **Login Email:** `carmelannevidena@yahoo.com`
  - **Territory:** `BA4-01`
  - **Roles:** `Sales User`, `Employee`
- **Alternative MedReps**:
  - Nelson Rivera (`BA4-03`): `nelson_rivera18@yahoo.com`
  - Jericho Mercado Agapito (`BA4-08`): `jerichoagapito@gmail.com`
  - Romana dela Cuesta (`BA4-07`): `rona_delacuesta@yahoo.com`

---

## 3. Spreadsheet Testing Matrix Alignment

| Action in Spreadsheet | State Transition | Allowed Role | District 1 Tester | District 2 Tester | District 3 Tester |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Submit for Processing** | `Draft` $\rightarrow$ `Processed` | `Sales User` | `arlaneferraren8@gmail.com` | `gallegoscharisse@gmail.com` | `carmelannevidena@yahoo.com` |
| **Submit for Approval** | `Draft` $\rightarrow$ `Pending Approval` | `Sales User` | `arlaneferraren8@gmail.com` | `gallegoscharisse@gmail.com` | `carmelannevidena@yahoo.com` |
| **Submit for Approval** | `Rejected` $\rightarrow$ `Pending Approval` | `Sales User` | `arlaneferraren8@gmail.com` | `gallegoscharisse@gmail.com` | `carmelannevidena@yahoo.com` |
| **Approve** | `Pending Approval` $\rightarrow$ `Approved` | `Sales Manager` | `rbviray@profinsights.biz` | `ginlorcullo@profinsights.biz` | `cmrinon@profinsights.biz` |
| **Reject** | `Pending Approval` $\rightarrow$ `Rejected` | `Sales Manager` | `rbviray@profinsights.biz` | `ginlorcullo@profinsights.biz` | `cmrinon@profinsights.biz` |
| **Submit for Approval** | `Rejected` $\rightarrow$ `Pending Approval` | `Sales Manager` | `rbviray@profinsights.biz` | `ginlorcullo@profinsights.biz` | `cmrinon@profinsights.biz` |

---

## 4. Step-by-Step Testing Procedure (Per District)

### Flow 1: Existing Doctor Auto-Merge (`Submit for Processing`)
1. Log in as the **MedRep**.
2. Go to **Doctor Masterlist**, select **Bayer Consumer Health - Team 1**.
3. Select an existing doctor (e.g. `Dr. Carmela Reyes Villanueva` / `HCP-0000029`).
4. Tap **Review Profile**, edit an affiliation or schedule, and tap **Submit for Processing**.
5. **Expected Result**: Document state transitions immediately to **`Processed`**. Direct merge to `HCP` masterlist; no manager review required.

---

### Flow 2: New Doctor End-to-End Cycle (All 5 Remaining Rows)

1. **MedRep Submits New Doctor (`Draft` $\rightarrow$ `Pending Approval`)**:
   - MedRep taps `+ Add Doctor` $\rightarrow$ New Doctor.
   - Enter name, license, specialty, and workplace.
   - Tap **Submit for Approval**.
   - *Status is now: `Pending Approval`.*

2. **DSM Rejects Submission (`Pending Approval` $\rightarrow$ `Rejected`)**:
   - Log in as the district **DSM**.
   - In **Submissions History**, tap the pending submission.
   - Tap **Reject** (enter remark: *"Missing clinic details"*).
   - *Status is now: `Rejected`.*

3. **DSM Resubmits for Approval (`Rejected` $\rightarrow$ `Pending Approval`) ⭐**:
   - **Stay logged in as DSM** — open the same `Rejected` submission.
   - Tap the orange button: **"Resubmit for Approval"**.
   - *Status transitions back to `Pending Approval` via Transition Rule #9.*
   - **Mark Passed on spreadsheet for DSM!**

4. **MedRep Resubmits for Approval (`Rejected` $\rightarrow$ `Pending Approval`)**:
   - DSM taps **Reject** once more to return it to `Rejected`.
   - Log out, and log in as the **MedRep**.
   - MedRep opens the `Rejected` submission in **Submissions History** and taps **"Resubmit for Approval"**.
   - *Status transitions back to `Pending Approval` via Transition Rule #10.*

5. **DSM Approves Doctor (`Pending Approval` $\rightarrow$ `Approved`)**:
   - Log in as the **DSM**.
   - Open the submission in `Pending Approval` and tap **Approve**.
   - *Status transitions to `Approved`. Doctor is registered in universal `HCP` doctype and linked to `HCP Account`.*

---

## 5. Frequently Asked Questions

#### Q: Do I need to reinstall or install a new `.ipa` file on the phone?
**No.** The app installed on your device communicates dynamically with the ERPNext REST API. Because the transition rules fix was performed on the ERPNext server (`dev.pmii-marketing.com`), the app currently on your device will execute the transitions immediately.

#### Q: Are repository files committed and up to date?
**Yes.** Working tree is completely clean and pushed to `origin/main`.
