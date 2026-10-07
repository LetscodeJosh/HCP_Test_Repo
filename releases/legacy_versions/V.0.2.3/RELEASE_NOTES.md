# Release Notes: Version V.0.2.3

- **Application Name**: HCP Profiling
- **Version**: V.0.2.3 (Build 5)
- **Release Date**: September 15, 2026
- **Target Backend**: ERPNext v15
- **Supported Platforms**: Android (.apk)

---

## What's Changed in V.0.2.3 (+1 Patch)

### 1. Centralized Institution Proposing in "Institution Approvals" Menu
- **Clean Workplace Selector**: The doctor profiling wizard workplace field is now strictly reserved for searching and selecting verified, approved facilities. All inline "+ Add New Facility" popups and buttons have been removed from the wizard to ensure the profiling flow is simple, clean, and uncluttered.
- **Dedicated Propose Flow**: A prominent **`+ Propose New Institution`** Floating Action Button (FAB), AppBar action button, and empty-state quick action have been added to the MedRep's **"Institution Approvals"** hub (`InstitutionApprovalsScreen`).
- **Comprehensive Facility Proposal Form**: MedReps can submit new facilities with full validation: Workplace Name, Province (with PSGC location picker), and City / Municipality (with PSGC location picker).

### 2. Resolved "Faking Submission" & Fixed ERPNext Link Validation
- **Eliminated Fake Submissions**: Removed the deceptive local cache mock fallback in `api_service.dart` that previously caught HTTP 417 `LinkValidationError` and created a client-side mock object without persisting to ERPNext.
- **PSGC Location Handling & Automatic Fallback**: Added strict 10-digit PSGC location ID validation. If ERPNext returns a `LinkValidationError` (e.g., PSGC code mismatch), the app automatically falls back to creating the `Institution` with `institution_name` only (which ERPNext accepts with HTTP 200/201).
- **Workflow State Transition**: Newly created records immediately execute `frappe.model.workflow.apply_workflow` with action `Submit for Approval`, transitioning them from `Draft` to `Pending Approval`.
- **True SFE Visibility**: The proposal now genuinely persists on the server and displays immediately in the SFE Specialist's pending approval queue.
- **Transparent Error Reporting**: Any real server failures are now thrown and displayed explicitly rather than giving false success feedback.

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. "Faking Submissions" — App Concealed Server Validation Failures
- **Problem Encountered:**
  - App reported successful facility proposal, but facilities never appeared in the SFE approval queue.
- **Root Cause Identified:**
  - Deceptive client-side mock fallback in `api_service.dart` caught HTTP 417 `LinkValidationError` and silently returned mock data without persisting to ERPNext.
- **Solution Applied:**
  - Removed mock fallback; added strict 10-digit PSGC location validation with automatic fallback; surfaced genuine server exceptions.
- **Files Modified:**
  - `lib/services/api_service.dart`
  - `lib/screens/institution_approvals_screen.dart`
- **Verification Status:** Server persistence verified; proposals appear in SFE queue (PASSED).

---

## Release Binaries Included in this Folder
### Android (.apk)
- `HCP_Profiling_V.0.2.3.apk`
- `HCP_Profiling_Release.apk`
