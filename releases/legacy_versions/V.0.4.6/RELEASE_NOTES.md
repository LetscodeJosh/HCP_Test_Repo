# Release Notes - HCP Profiling App V.0.4.6 (Build 17)

**Release Date:** September 17, 2026  
**Build Number:** 17  
**Target ERPNext Version:** v15  
**Version Increment:** Patch (+1 Patch)

---

## 🌟 Key Updates & Architectural Alignment

### 🛠️ 1. Elimination of Deletion / Discard for Added Institutions
- **User Directive**:
  - *"We must not have deletion in any Institution added, remove the 'discard' option, they do modify and resubmit as they want (continously)."*
- **MedRep Experience (`InstitutionApprovalsScreen`)**:
  - **Removed "Discard" Option**: Eliminated the Discard button and corresponding deletion confirmation dialogs (`_handleDeleteSubmission`).
  - **Uninterrupted Modify & Resubmit**: For any rejected institution, MedReps now exclusively have the prominent **"Modify & Resubmit"** option. They can update the name, region, province, or city/municipality and resubmit the institution continuously as many times as necessary without any risk of accidental data deletion.
- **SFE Specialist Dashboard (`SfeInstitutionDashboardScreen`)**:
  - **Eliminated "Reject & Delete Resubmission"**: Removed the conditional branch that permanently deleted resubmitted institutions upon rejection.
  - **Unified Rejection Flow**: Every rejection simply prompts for a rejection reason and transitions the institution to `Rejected` state. The MedRep can see the reason, adjust their details, and resubmit again.
- **API & Service Layer (`ApiService.rejectInstitution`)**:
  - Removed the `isResubmission` parameter and the `deleteInstitution` trigger from `rejectInstitution`.
  - Rejection transitions strictly and cleanly to `workflow_state: 'Rejected'` on ERPNext while preserving the document in the masterlist for subsequent updates.

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. Accidental Deletion & Permanent Data Loss of Added Institutions
- **Problem Encountered:**
  - MedReps had a "Discard / Discard & Delete" button, and SFE Specialists had a "Reject & Delete Resubmission" dialog. When triggered, the institution record was permanently expunged via `DELETE /api/resource/Institution/...`, destroying audit trails and forcing reps to re-type facilities from scratch if rejected or modified.
- **Root Cause Identified:**
  - Deletion methods were wired into `_handleDeleteSubmission()` in `InstitutionApprovalsScreen` and `ApiService.rejectInstitution()` via the `isResubmission` parameter.
- **Solution Applied:**
  - Completely removed the "Discard" button and `_handleDeleteSubmission()` from `InstitutionApprovalsScreen`.
  - Replaced with exclusive, prominent **"Modify & Resubmit"** button allowing continuous edits without data loss.
  - Removed `isResubmission` deletion branch from `ApiService.rejectInstitution()`. SFE rejections now strictly transition status to `Rejected`.
- **Files Modified:**
  - `lib/screens/institution_approvals_screen.dart`
  - `lib/screens/sfe_institution_dashboard_screen.dart`
  - `lib/services/api_service.dart`
- **Verification Status:** Verified via `test/inst_profiling_test.dart` simulating continuous multi-cycle rejections without data loss (PASSED).

---

## 🧪 Verification & Testing
- **Unit Testing**: Added dedicated test case in `test/inst_profiling_test.dart` simulating multiple rejection and resubmission cycles without deletion. All 4 test suites passed (0 failures).
- **Code Analysis**: Clean compilation with 0 syntax or lint errors.
- **Release Build**: Built with `flutter build apk --release` targeting `android-arm64`.

---

## 📦 Release Artifacts
- **Universal Release APK:** [`releases/HCP_Profiling_Release.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)
- **Versioned APK:** [`releases/V.0.4.6/HCP_Profiling_V.0.4.6.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.6/HCP_Profiling_V.0.4.6.apk)
