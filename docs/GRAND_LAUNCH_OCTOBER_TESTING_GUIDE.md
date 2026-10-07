# Grand Launch October 2026: End-to-End Enterprise Testing Guide

## 🎯 Executive Overview
This guide provides the definitive, production-grade User Acceptance Testing (UAT) and Quality Assurance (QA) protocol for the **October 2026 Grand Launch** of the **HCP Profiling & SFE Territory Reconfiguration System**.

The launch centers on three mandatory pillars that must execute without error:
1. **Pillar 1: Basic Doctor Profiling & Two-Tier Masterlist Approval Workflow**
2. **Pillar 2: Institution Submission & Multi-Tier Review Workflow**
3. **Pillar 3: SFE Territory Reconfiguration Web Portal & Doctor Realignment**

---

## 🏗️ Architecture & Core Principles (Zero Deviation Standard)

### 1. Two-Tier Masterlist Model
* **Universal `HCP` Record**: Master registry of all doctors across the entire pharmaceutical enterprise (PRC license, core specialties, all clinic/hospital affiliations).
* **Program-Specific `HCP Account` Record**: Doctor affiliations segmented by commercial program (e.g. *Abbott Diabetes Care*, *Bayer*, *COREnergy*). Contains program-specific preferred workplace, contact information, and territory code (`AD0101`, `ADC0101`).

### 2. ERPNext `HCP Profile Submission WF` Aligned Routing
* **Existing Doctor (`doc.profile_action == "Existing HCP"`)**:
  * Action: **`Submit for Processing`** $\rightarrow$ Target State: **`Processed`**.
  * **Requires NO Managerial Approval**.
  * Additively merges new specialties and clinics into the universal `HCP` and updates program `HCP Account` immediately.
* **New Doctor (`doc.profile_action == "New HCP"`)**:
  * Action: **`Submit for Approval`** $\rightarrow$ Target State: **`Pending Approval`**.
  * **Requires Managerial Approval** (`Sales Manager`, `District Sales Manager`, or `System Manager`).
  * Action: **`Approve`** $\rightarrow$ Target State: **`Approved`** (creates `HCP-XXXXXXX` and commits to masterlist).
  * Action: **`Reject`** $\rightarrow$ Target State: **`Rejected`** (requires mandatory rejection reason).

---

## 🧪 Automated Test Suite Execution (Self-Verification)

The repository includes a comprehensive automated test suite validating every rule, model, search algorithm, and workflow state.

To execute the automated test suites, open PowerShell in the project directory and run:

```powershell
# 1. Run the Grand Launch E2E Workflow Test Suite (14 Critical Tests)
flutter test test/grand_launch_e2e_workflow_test.dart

# 2. Run the Complete 49-Test Master Suite
flutter test
```

### ✅ Expected Result:
```text
00:02 +49: All tests passed!
```
All 49 unit and integration tests across 5 test suites pass with 100% green checkmarks.

---

## 📋 Comprehensive UAT Test Matrices (Manual Field Verification)

---

### 🔹 Pillar 1: Basic Doctor Profiling & Approval Workflow

| Test ID | Test Scenario | Step-by-Step Actions | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :---: |
| **P1-01** | **Existing Doctor Update (No Manager Approval Required)** | 1. Log in as a Medical Representative (MedRep).<br>2. Select program: **Abbott Diabetes Care**.<br>3. Open **Doctor Directory** and search for an existing doctor (e.g. `Dr. Juan Dela Cruz`).<br>4. Tap **Edit Profile**.<br>5. Add a secondary specialty or update contact number.<br>6. Verify button text displays **`Submit for Processing`**.<br>7. Tap **`Submit for Processing`**. | • Submission state immediately becomes **`Processed`**.<br>• `docstatus` is set to `1`.<br>• Does **NOT** enter "Pending Approval".<br>• Universal `HCP` record is updated via additive merge.<br>• `HCP Account` reflects preferred contact info. | [ ] |
| **P1-02** | **New Doctor Profile Submission (Approval Required)** | 1. Log in as MedRep.<br>2. On Dashboard, tap **`+ Add New Doctor`**.<br>3. Enter First Name, Last Name, PRC License, and Primary Specialty.<br>4. Select an existing workplace or propose a new clinic.<br>5. Fill out Data Privacy Consent and capture signature.<br>6. Verify button text displays **`Submit for Approval`**.<br>7. Tap **`Submit for Approval`**. | • Submission state enters **`Pending Approval`**.<br>• `docstatus` is set to `0`.<br>• Profile is locked from conflicting edits (`isSemanticallyLocked == true`).<br>• App notification shows "Submitted for Manager Approval". | [ ] |
| **P1-03** | **Manager Approval Flow (DSM / Sales Manager)** | 1. Log in as Sales Manager or DSM (`manager@pharma.com`).<br>2. Open **Submission Approvals** screen.<br>3. Tap the pending submission from **P1-02**.<br>4. Review doctor details, specialty, and attached documents.<br>5. Tap **`Approve`**. | • Submission state transitions to **`Approved`** (`docstatus: 1`).<br>• System auto-generates universal master ID (`HCP-XXXXXXX`).<br>• Active `HCP Account` is initialized under the rep's territory.<br>• Doctor appears in the global masterlist. | [ ] |
| **P1-04** | **Manager Rejection Flow with Remarks** | 1. In **Submission Approvals**, select a pending submission.<br>2. Tap **`Reject`**.<br>3. System displays a modal requiring a mandatory rejection reason.<br>4. Enter rejection note: *"PRC license photo is blurred. Please retake photo."*<br>5. Confirm rejection. | • State transitions to **`Rejected`** (`docstatus: 2`).<br>• Rejection remark and reviewer ID are saved.<br>• MedRep dashboard shows the rejected profile with the exact remark.<br>• MedRep can edit and resubmit. | [ ] |
| **P1-05** | **Two-Tier Cross-Program Affiliation** | 1. Profile an existing doctor in **Abbott Diabetes Care** under territory `AD0101`.<br>2. Switch active program to **Bayer**.<br>3. Search for the same doctor in **Bayer**.<br>4. Profile the doctor under Bayer territory `BAY-MNL-01` with a different preferred clinic. | • Universal `HCP` record retains both clinics and core credentials.<br>• Two independent `HCP Account` records exist: one for Abbott (`AD0101`) and one for Bayer (`BAY-MNL-01`).<br>• Changes in Bayer do not overwrite Abbott's preferred territory or contact. | [ ] |

---

### 🔹 Pillar 2: Institution Submission & Verification Workflow

| Test ID | Test Scenario | Step-by-Step Actions | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :---: |
| **P2-01** | **Classification-First Proposal Entry** | 1. In doctor profiling or Institution Directory, tap **`+ Propose New Institution`**.<br>2. In the dialog, select **Classification**: **`Hospital`** or **`Clinic`**.<br>3. Observe dynamic capability options: Hospital displays 3 service levels (Level 1, 2, 3); Clinic displays 5 specialized ambulatory care options.<br>4. Enter facility name: *"Metro East Medical Specialists"* (verify title auto-capitalization).<br>5. Select official PSGC location: Region $\rightarrow$ Province $\rightarrow$ City/Municipality $\rightarrow$ Barangay.<br>6. Tap **`Submit Proposal`**. | • Institution is registered with state **`Pending Approval`** (`INST-XXXXX`).<br>• Audit trail logs submission timestamp and submitting MedRep.<br>• Predictive search detects potential duplicate facilities within 100m. | [ ] |
| **P2-02** | **Profiling with a Pending Institution** | 1. While profiling a doctor, search for the newly proposed institution from **P2-01**.<br>2. Select the pending institution as the primary workplace.<br>3. Observe the workplace badge. | • MedRep is **NOT** blocked from profiling doctors at pending institutions.<br>• Institution badge clearly displays: <br> `[this institution is not yet approved]` in amber.<br>• Doctor submission can be submitted for review. | [ ] |
| **P2-03** | **Manager Institution Approval** | 1. Log in as DSM or SFE Administrator.<br>2. Open **Institution Approvals** screen.<br>3. Review the proposed institution details and PSGC mapping.<br>4. Tap **`Approve Institution`**. | • Institution state becomes **`Approved`**.<br>• Approval status note updates to: <br> `[this institution is now approved]`.<br>• Facility is permanently committed to verified PSGC Directory. | [ ] |
| **P2-04** | **Manager Institution Rejection & Propagation** | 1. In **Institution Approvals**, select an invalid clinic proposal.<br>2. Tap **`Reject Institution`**.<br>3. Enter mandatory rejection reason: *"Non-existent medical clinic upon physical field validation"*.<br>4. Confirm rejection. | • Institution state transitions to **`Rejected`**.<br>• Doctor profiles linked to this facility immediately flag a red warning: <br> `[REJECTED INSTITUTION: Non-existent medical clinic upon physical field validation]`.<br>• Prevents final doctor profile approval until workplace is updated. | [ ] |
| **P2-05** | **Modify & Resubmit Cycle (Concurrency Lock)** | 1. Open the rejected institution from **P2-04**.<br>2. Tap **`Edit & Resubmit`**.<br>3. Verify that a 60-second active editing lock is placed.<br>4. Correct street address and suite number.<br>5. Tap **`Resubmit`**. | • Same record ID (`INST-XXXXX`) is preserved (no duplicate creation).<br>• `resubmissionCount` increments by 1 (max 2 allowed).<br>• State resets to **`Pending Approval`**.<br>• Rejection note is cleared. | [ ] |

---

### 🔹 Pillar 3: SFE Territory Reconfiguration Web Portal

| Test ID | Test Scenario | Step-by-Step Actions | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :---: |
| **P3-01** | **Portal Launch & Initial Rendering** | 1. Launch the portal on Windows desktop by double-clicking `run_territory_portal.bat` or opening `http://127.0.0.1:8765/`.<br>2. Alternatively, in the mobile app drawer, tap **Territory Portal Launcher**. | • Portal opens cleanly in browser at `http://127.0.0.1:8765/`.<br>• Footer displays **`Standalone SFE Edition (V.0.5.2)`**.<br>• Tab 1 loads active program territories with interactive grid and selection checkboxes. | [ ] |
| **P3-02** | **Search Filter & Column Visibility Dropdown** | 1. Type a search query into **"Search across all columns..."** (e.g. `ADC` or MedRep name).<br>2. Click the **`✕`** icon inside the search input.<br>3. Open the **`Columns (6/6) ▾`** dropdown.<br>4. Uncheck `Latest Previous Code` and `Doctor Count`. | • Search filters rows instantly; clicking **`✕`** resets search in 1 click.<br>• Unchecked columns immediately hide (`display: none`) from table header and all data rows.<br>• Dropdown badge updates to **`Columns (4/6) ▾`**. | [ ] |
| **P3-03** | **Zero-Columns Clean State & Checkbox Removal** | 1. Open the **`Columns (X/6) ▾`** dropdown.<br>2. Click the **`None`** quick action link (or manually uncheck all 6 columns). | • Master header checkbox (`th.col-cb`) and entire dark header bar (`<thead>`) are **completely removed** (`display: none`).<br>• All row checkboxes (`td.col-cb`) and empty row lines are **completely cleared**.<br>• A clean, centered placeholder card is displayed: <br> `👁️‍🗨️ All Table Columns Are Hidden`.<br>• Counter displays **`Showing 0 of 23 territories`**.<br>• Clicking **`👁️ Restore All Columns`** restores the grid and all 6 columns instantly. | [ ] |
| **P3-04** | **4-in-1 Bulk Workbench: Modify Tab** | 1. Select 3 territories using the row checkboxes.<br>2. Click **`Batch Modify`** in the bulk actions bar.<br>3. In the **✏️ Modify** tab, change Status to `CHANGED`, select a new MedRep, and enter an audit justification.<br>4. Click **`Apply Batch Changes`**. | • Selected territories reflect updated rep and `CHANGED` status badge.<br>• Covered doctor accounts are synced with new representative.<br>• Master audit trail logs `BULK_EDIT` entries. | [ ] |
| **P3-05** | **4-in-1 Bulk Workbench: Rename Tab** | 1. Select territories starting with `AD` (e.g. `AD0101`, `AD0102`).<br>2. Click **`Batch Code Rename`**.<br>3. Select **Mode: `Find & Replace`**.<br>4. Find: `AD`, Replace: `ADC`.<br>5. Inspect the **Live Transformation Preview Table**.<br>6. Click **`Apply Batch Rename`**. | • Codes update from `AD0101` $\rightarrow$ `ADC0101`.<br>• Historical previous code is preserved in `Latest Previous Code`.<br>• Territory status changes to `CHANGED`.<br>• Doctor `HCP Account` records automatically update to the new territory code. | [ ] |
| **P3-06** | **4-in-1 Bulk Workbench: Delete / Decommission Tab** | 1. Select a territory with assigned doctors.<br>2. In the Bulk Workbench, select the **🗑️ Delete** tab.<br>3. Select **`Decommission to Archive Vault`**.<br>4. Review affected doctor count.<br>5. Check the mandatory safety confirmation box and click **`Confirm Decommission`**. | • Territory is removed from active grid.<br>• Row is moved to **Tab 2 (Archive Vault Table)**.<br>• Doctor accounts are not orphaned; they retain historical vault lineage. | [ ] |
| **P3-07** | **4-in-1 Bulk Workbench: Bulk Add Tab** | 1. In Bulk Workbench, select **➕ Bulk Add**.<br>2. Paste multi-line codes:<br>`ADC_NORTH_01`<br>`ADC_NORTH_02`<br>3. Click **`Add Territories`**. | • Both territories are parsed, validated against duplicates, and added.<br>• Generated IDs (`TERR-ADC-XXXX`) and default MedRep assigned.<br>• Newly added rows are automatically highlighted and checked. | [ ] |

---

### 🔹 Pillar 4: October 2026 Monthly Rollover & Cycle Archiving

| Test ID | Test Scenario | Step-by-Step Actions | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- | :---: |
| **P4-01** | **September to October 2026 Cycle Rollover** | 1. Verify accounts with validity `2026-09-01` to `2026-09-30`.<br>2. Advance device/system date to **October 1, 2026**.<br>3. Launch the HCP Profiling app. | • September 2026 cycle is archived (`isCurrentMonthActive == false`).<br>• System initializes October 2026 cycle (`validFrom: 2026-10-01`, `validTo: 2026-10-31`).<br>• Rolled-over accounts preserve `sourceAccountName` and reflect reconfigured territory codes (`ADC0101`). | [ ] |

---

## 🚀 Pre-Deployment Readiness Checklist

Before final deployment in early October, verify that:
- [x] All 49 automated unit and integration tests pass cleanly (`flutter test`).
- [x] Android release APK is compiled and packaged at [releases/HCP_Profiling_Release.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk) (57.7 MB).
- [x] Standalone Territory Reconfiguration setup package is archived at [releases/Territory_Reconfiguration_Setup.zip](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/Territory_Reconfiguration_Setup.zip).
- [x] Versioning is strictly locked at **`V.0.5.2` (Build 28)** across `VERSION`, `pubspec.yaml`, `lib/constants/app_version.dart`, and `CHANGELOG.md`.
- [x] ERPNext `HCP Profile Submission WF` expressions (`doc.profile_action=="Existing HCP"` / `doc.profile_action=="New HCP"`) remain intact without modification.
