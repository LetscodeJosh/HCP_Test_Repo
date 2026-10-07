# Release Notes - HCP Profiling App V.0.4.3 (Build 14)

**Release Date:** September 17, 2026  
**Build Number:** 14  
**Target ERPNext Version:** v15  
**Version Increment:** Patch (+1 Patch)

---

## 🌟 Key Updates & Highlights

### 1. 🏥 Pending Institution Profiling Unlocked in Wizard
- **Unrestricted Field Workflow**:
  - Removed lingering validation blocks in `HcpWizardScreen` (`_showAddWorkplaceSelector` and `_showEditWorkplaceDialog`) that previously blocked MedReps from attaching healthcare facilities with `Pending Approval` or `Draft` status.
  - Field representatives can now immediately select and link newly proposed institutions to doctor profiles without having to wait for SFE Specialist approval.
  - Only explicitly `Rejected` facilities remain blocked until corrected and resubmitted via **Institution Submission**.

### 2. 🏷️ Dynamic Workplace Approval Status Notes
- **Dynamic Status Labeling**:
  - Aligned status labels in `Institution.approvalStatusNote` and `LocationResolver.getInstitutionApprovalStatusNote`:
    - **Pending / Unapproved Facilities**: Displayed with **`"this institution is not yet approved"`** (amber hourglass icon `#D97706`).
    - **Approved Facilities**: Displayed with **`"this institution is now approved"`** (emerald green check icon `#059669`).
  - Seamlessly updates in real time across the workplace search picker, doctor info card in wizard Step 2, Doctor Account screen, and backend ERPNext `workplace_approval_note` fields.

### 3. 👨‍⚕️ Doctor Masterlist Creation Parity
- **Updated Direct Doctor Creation**:
  - Updated `DoctorMasterlistScreen._showAddDoctorDialog` so administrators and managers can also assign newly proposed facilities while awaiting SFE review, only prohibiting rejected facilities.

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. MedReps Blocked from Profiling Doctors at Newly Proposed Clinics
- **Problem Encountered:**
  - When a MedRep added a new clinic awaiting SFE review (`Pending Approval`), the doctor profiling wizard blocked selecting it, preventing field reps from profiling doctors during hospital visits.
- **Root Cause Identified:**
  - Validation checks in `HcpWizardScreen._showAddWorkplaceSelector` and `_showEditWorkplaceDialog` (lines 2412 & 2908) restricted workplace selection strictly to `Approved`.
- **Solution Applied:**
  - Unlocked `Pending Approval` and `Draft` facilities for doctor profiling. Only explicitly `Rejected` facilities remain blocked.
  - Implemented dynamic approval notes: `"this institution is not yet approved"` (amber hourglass) which dynamically transitions to `"this institution is now approved"` (emerald green check) upon SFE approval.
- **Files Modified:**
  - `lib/screens/hcp_wizard_screen.dart`
  - `lib/models/lookup_models.dart`
  - `lib/screens/doctor_masterlist_screen.dart`
- **Verification Status:** MedRep profiling verified with pending facility linking (PASSED).

---

## 📦 Release Artifacts
- **Universal Release APK:** [`releases/HCP_Profiling_Release.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)
- **Versioned APK:** [`releases/V.0.4.3/HCP_Profiling_V.0.4.3.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.3/HCP_Profiling_V.0.4.3.apk)
