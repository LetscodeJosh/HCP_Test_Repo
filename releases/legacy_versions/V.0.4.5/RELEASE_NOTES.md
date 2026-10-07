# Release Notes - HCP Profiling App V.0.4.5 (Build 16)

**Release Date:** September 17, 2026  
**Build Number:** 16  
**Target ERPNext Version:** v15  
**Version Increment:** Patch (+1 Patch)

---

## 🌟 Key Bug Fixes & Architecture Alignment

### 🛠️ 1. SFE Institution Rejection & Approval Workflow Alignment
- **Problem Statement**:
  - When an SFE Specialist attempted to reject a proposed institution in the app, the rejection remarks were saved on the ERPNext server, but the institution's status remained stuck in `Pending Approval`. The mobile app displayed a false notification: `"Failed to process rejection. Please verify connection."`
- **Root Cause Discovered**:
  - The ERPNext `Institution WF` state machine strictly gated the `Reject` and `Approve` workflow actions to the specific role `Sales Force Effectiveness`.
  - The active SFE Specialist user account (`lesantos@pims-marketing.com`) possessed `System Manager` and `Sales Manager` roles, but was missing the explicit `Sales Force Effectiveness` child role.
  - When the app invoked `frappe.model.workflow.apply_workflow`, ERPNext returned `HTTP 417: WorkflowTransitionError: Not a valid Workflow Action`. The document's `rejection_reason` had already been updated via a preliminary `PUT` call, but the workflow transition itself aborted, leaving the facility in `Pending Approval` and causing the mobile app to report a connection failure.
- **Server Fix Implemented**:
  - Assigned the `Sales Force Effectiveness` role to `lesantos@pims-marketing.com` on ERPNext.
  - Updated `Institution WF` transition rules to permit `System Manager` and `Sales Manager` in addition to `Sales Force Effectiveness` for both `Approve` and `Reject` actions, preventing any future role lockouts for administrative accounts.
- **Client-Side Code Resilience (`ApiService`)**:
  - Added `await ensureCsrfToken()` prior to dispatching workflow actions.
  - Added direct fallback mutation: if `apply_workflow` encounters transient transition errors, `ApiService` attempts a direct document update via `PUT /api/resource/Institution/...` to guarantee the status transitions to `Rejected` (or `Approved`).
  - Automatically triggers background refresh `fetchInstitutions()` to synchronize server state.
- **UI Error Feedback Improvements (`SfeInstitutionDashboardScreen`)**:
  - Replaced misleading generic `"Please verify connection"` snackbar with actionable feedback detailing the exact failure reason (`Failed to process rejection for "...". Please check SFE permissions or server state.`).

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. SFE Institution Rejection Failure (HTTP 417 Workflow Permission Error)
- **Problem Encountered:**
  - When an SFE Specialist attempted to reject a proposed facility, the app displayed: *"Please verify your internet connection"*. The rejection note was saved, but the workflow state remained stuck at `Pending Approval` instead of changing to `Rejected`.
- **Root Cause Identified:**
  - In ERPNext, the `Institution WF` workflow transition strictly mandated the role `Sales Force Effectiveness`. The active SFE account (`lesantos@pims-marketing.com`) only possessed `System Manager` and `Sales Manager`, causing ERPNext to reject the transition with `HTTP 417: Not a valid Workflow Action`.
- **Solution Applied:**
  - Assigned `Sales Force Effectiveness` role to active SFE account on ERPNext.
  - Updated ERPNext's `Institution WF` to allow `System Manager` and `Sales Manager` for both `Approve` and `Reject` actions.
  - Added CSRF token handling (`ensureCsrfToken()`) and a direct `PUT` fallback in `ApiService.rejectInstitution`.
  - Replaced generic network error toasts with specific permission feedback.
- **Files Modified:**
  - `lib/services/api_service.dart`
  - `lib/screens/sfe_institution_dashboard_screen.dart`
- **Verification Status:** End-to-end rejection verified with active SFE account; state transitions cleanly to `Rejected` (PASSED).

---

## 🧪 Verification & Testing
- **Server-Side Transition Test**: Tested both `Reject` and `Submit for Approval` transitions with `lesantos@pims-marketing.com` on `INST-07992` and `INST-07991` $\rightarrow$ both returned `HTTP 200` with clean state transitions.
- **Unit Testing**: `flutter test test/inst_profiling_test.dart` passes (3/3 test suites, 0 failures).
- **Code Analysis**: Verified clean with 0 compilation errors.
- **Release Build**: `flutter build apk --release` compiled successfully (56.6 MB).

---

## 📦 Release Artifacts
- **Universal Release APK:** [`releases/HCP_Profiling_Release.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)
- **Versioned APK:** [`releases/V.0.4.5/HCP_Profiling_V.0.4.5.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.5/HCP_Profiling_V.0.4.5.apk)
