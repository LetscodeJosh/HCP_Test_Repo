# Release Notes - HCP Profiling App V.0.3.1 (Build 10)

**Release Date:** September 16, 2026  
**Build Number:** 10  
**Target ERPNext Version:** v15  
**Version Increment:** Patch (+1 Patch)

---

## 🌟 Key Updates & Highlights

### 1. 🏷️ UI & Terminology Alignment: "Institution Approval" $\rightarrow$ "Institution Submission"
- **Clear Role Alignment**: Proposing and resubmitting healthcare facilities is fundamentally a **submission** task for Medical Representatives, while reviewing/authorizing remains an SFE Specialist function.
- **Drawer Menu Navigation**:
  - **MedRep Navigation Item**: Renamed from **`Institution Approvals`** to **`Institution Submission`** (subtitle: `Track & Resubmit`).
  - **SFE Specialist Navigation Item**: Renamed from **`Institution Approvals`** to **`Institution Submission`** (subtitle: `SFE Approval Hub`).
  - **Admin Switcher**: Updated tooltip and subtitle to reflect `Preview SFE Institution submissions`.
- **Screen & AppBar Titles**:
  - `InstitutionApprovalsScreen`: Updated title to **`Institution Submission`** (subtitle: `Request Status & Resubmissions`).
  - Added `InstitutionSubmissionScreen` type alias for flexible and backwards-compatible widget referencing.
  - `SfeInstitutionDashboardScreen`: Updated title to **`Institution Submission`** (subtitle: `Sales Force Effectiveness Hub`).
- **Doctor Profiling Wizard Guidance & Snackbars**:
  - Updated all in-wizard instructions and validation prompts across Step 2 and Workplace dialogs:
    - Search empty state: *"To propose a new hospital or clinic, use the 'Institution Submission' menu in the drawer."*
    - Unmatched facility hint: *"Can't find hospital? Propose new facilities via 'Institution Submission' in the drawer."*
    - SFE rejection banners: *"Workplace was rejected by SFE and cannot be linked to this doctor. Please use 'Institution Submission' in the menu to modify and resubmit."*
- **Backend API Exception Messages**:
  - Updated `ApiService.createSubmission()` and `ApiService.updateSubmission()` error messages to direct field reps to resubmit facilities via **Institution Submission**.

---

## 📦 Binaries
- [HCP_Profiling_V.0.3.1.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.3.1/HCP_Profiling_V.0.3.1.apk)
- [HCP_Profiling_Release.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. Misleading Navigation Menu ("Institution Approvals" Shown to MedReps)
- **Problem Encountered:**
  - MedReps saw "Institution Approvals" in the drawer menu, implying they approve facilities rather than submit/propose them.
- **Root Cause Identified:**
  - Menu item naming lacked role-based semantic clarity.
- **Solution Applied:**
  - Renamed drawer navigation item and screen titles to **"Institution Submission"** (MedRep: `Track & Resubmit`, SFE: `SFE Approval Hub`). Updated all in-app wizard guidance banners and error messages.
- **Files Modified:**
  - `lib/screens/components/app_drawer.dart`
  - `lib/screens/institution_approvals_screen.dart`
  - `lib/screens/sfe_institution_dashboard_screen.dart`
- **Verification Status:** Verified UI drawer titles across MedRep and SFE accounts (PASSED).
