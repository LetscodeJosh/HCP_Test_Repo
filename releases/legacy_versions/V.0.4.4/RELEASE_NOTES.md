# Release Notes - HCP Profiling App V.0.4.4 (Build 15)

**Release Date:** September 17, 2026  
**Build Number:** 15  
**Target ERPNext Version:** v15  
**Version Increment:** Patch (+1 Patch)

---

## 🌟 Key Bug Fixes & Feature Enhancements

### 1. 🛡️ HCP Profile Submission Rejection Note / Remarks Display Isolation
- **Background & Issue**:
  - In `HCP Profile Submission`, submissions in `Approved`, `Processed`, or `Pending Approval` states were erroneously showing red rejection remark cards and badges whenever general Frappe timeline comments or remarks existed on the document.
- **Root Cause & Fix**:
  - `HcpProfileSubmission.fromJson`: Enforced strict `isActuallyRejected` verification (`rawDocstatus == 2 || resolvedWorkflow == 'Rejected'`). Non-rejected submissions unconditionally retain `null` for `rejectionRemarks` and `rejectedBy`.
  - `ApiService.fetchSubmissions` & `fetchSubmissionDetail`: Guarded timeline comment retrieval so comments are only parsed as rejection remarks when the submission is genuinely in `Rejected` state.
  - `SubmissionHistoryScreen`: Updated the detail drawer rejection card and the list item status badge to require `item.isRejected` before displaying any rejection remark banners.
- **Result**:
  - Only submissions that actually underwent rejection will display the red rejection note. `Approved`, `Processed`, and `Pending Approval` profiles now display cleanly without misleading rejection notes.

### 2. 🏛️ SFE Specialist / Admin Institution Creation & Proposal Functionality
- **Background & Requirement**:
  - SFE Specialists previously only had review/approval cards on their dashboard (`SfeInstitutionDashboardScreen`) and had no way to add or propose new healthcare facilities directly when discovering missing institutions in the field.
- **Enhancements Implemented**:
  - **Prominent Action Triggers**: Added a primary FloatingActionButton (`+ Propose Institution`) and an AppBar action button (`Icons.add_business_rounded`), plus an empty-state action button.
  - **Comprehensive Institution Dialog (`_openCreateInstitutionDialog`)**:
    - **Live Directory Search & Duplicate Prevention**: Automatically searches active facilities in real time as the user types, warning against duplicates and offering 1-tap auto-fill.
    - **PSGC Location Hierarchy**: Integrated Region, Province, and City/Municipality pickers with automatic standard code resolution.
    - **Dual SFE Action Buttons**:
      - **`Submit for Approval`**: Submits the facility request in `Pending Approval` state for review.
      - **`Submit & Approve`**: Immediately creates and activates the institution into the universal masterlist (`Approved` / `docstatus: 1`), leveraging SFE administrative privileges without needing a second review step.
  - **Immediate Local Refresh**: Instantly updates local caches and triggers a data refresh so newly added institutions appear immediately on the dashboard and in doctors profiling.

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. Red Rejection Remark Banners Leaking onto Approved & Pending Submissions
- **Problem Encountered:**
  - Verified doctor submissions in `Approved` or `Pending Approval` states displayed alarming red rejection remark cards in submission history lists and detail drawers.
- **Root Cause Identified:**
  - `HcpProfileSubmission.fromJson` pulled the latest Frappe timeline comment and assigned it to `rejectionRemarks` without checking if the document was actually rejected.
- **Solution Applied:**
  - Enforced strict gating (`rawDocstatus == 2 || resolvedWorkflow == 'Rejected'`). If not rejected, rejection fields are strictly set to `null`.
  - Added UI guards in `SubmissionHistoryScreen` requiring `item.isRejected && item.rejectionRemarks != null`.
- **Files Modified:**
  - `lib/models/submission.dart`
  - `lib/services/api_service.dart`
  - `lib/screens/submission_history_screen.dart`
- **Verification Status:** Verified via `test/inst_profiling_test.dart`; approved profiles retain clean presentation (PASSED).

### 2. SFE Specialists Unable to Directly Propose Missing Facilities
- **Problem Encountered:**
  - SFE Specialists discovering unlisted facilities in the field had no way to propose or add institutions directly from their hub.
- **Root Cause Identified:**
  - The SFE dashboard only supported reviewing incoming submissions with no creation action triggers.
- **Solution Applied:**
  - Added `+ Propose Institution` FAB and AppBar action buttons in `SfeInstitutionDashboardScreen` with duplicate detection, PSGC hierarchy pickers, and dual actions (`Submit for Approval` and `Submit & Approve`).
- **Files Modified:**
  - `lib/screens/sfe_institution_dashboard_screen.dart`
- **Verification Status:** SFE institution proposal and immediate approval verified end-to-end (PASSED).

---

## 🧪 Verification & Testing
- **Unit Testing**: `test/inst_profiling_test.dart` passes (3/3 test suites, 0 failures) verifying approval status notes, duplicate detection, and rejection remarks isolation across Approved, Processed, Pending, and Rejected states.
- **Code Analysis**: `flutter analyze` verified clean with 0 compilation errors.
- **Release Build**: `flutter build apk --release` compiled cleanly (56.6 MB).

---

## 📦 Release Artifacts
- **Universal Release APK:** [`releases/HCP_Profiling_Release.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)
- **Versioned APK:** [`releases/V.0.4.4/HCP_Profiling_V.0.4.4.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.4/HCP_Profiling_V.0.4.4.apk)
