# Release Notes - HCP Profiling App V.0.2.6 (Build 8)

**Release Date:** September 15, 2026  
**Build Number:** 8  
**Target ERPNext Version:** v15  
**Version Increment:** Patch (+1 Patch)

---

## 🌟 Key Updates & Highlights

### 1. 🔒 Strict Blocking of Unapproved / Pending Institutions Across Doctor Profiling
- **Identified Gap**:
  - Previously, newly proposed institutions awaiting approval (e.g. `INST-07990` "Simulate Institution" in `Pending Approval`) could still be selected, linked, and submitted in doctor profiling workflows because validation was checking against a filtered list that defaulted unapproved institutions to empty/passing values.
  - Furthermore, newly proposed institutions were being registered into the dynamic `LocationResolver` memory cache regardless of approval state.
- **Root Cause & Structural Fixes**:
  - **`Institution.isApprovedForProfiling`**:
    - Strictly blocks facilities in `Pending Approval`, `Rejected`, or `Draft` states (`isApprovedForProfiling == false`).
    - Custom facilities (`INST-07001` and above) strictly require SFE Specialist approval (`workflow_state == 'Approved'` or `docstatus == 1`).
    - Baseline legacy institutions (`INST-00001` through `INST-07000`) and standard facilities remain accessible.
  - **`LocationResolver.registerInstitutions`**:
    - Only registers institutions where `isApprovedForProfiling == true`. Unapproved facilities are never registered in dynamic lookup tables.
    - `LocationResolver.resolveInstitutionId` and `LocationResolver.isApprovedInstitution` strictly validate approval.
  - **Wizard & Doctor Masterlist Validation**:
    - `HcpWizardScreen._hasUnapprovedWorkplaces`: Fixed inverted lookup bug. Validates against all cached institutions and blocks proceeding if any workplace is pending or unapproved.
    - `HcpWizardScreen._showInstitutionSearchDialog`: Strictly filters out pending and rejected facilities from the selection list.
    - `HcpWizardScreen._showAddWorkplaceSelector` & `_showEditWorkplaceDialog`: Enforce real-time validation and show an immediate warning snackbar if an unapproved institution is selected or entered.
    - `DoctorMasterlistScreen._showAddDoctorDialog`: Validates and blocks doctor creation if the entered primary workplace is pending or unapproved.
  - **Defense-in-Depth in `ApiService`**:
    - Added server-side submission checks in `createSubmission()`, `updateSubmission()`, and `syncHcpAccount()`. Profiling submissions or account syncs containing unapproved institutions are intercepted and rejected before sending to ERPNext.

---

## 📦 Binaries
- [HCP_Profiling_V.0.2.6.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.6/HCP_Profiling_V.0.2.6.apk)
- [HCP_Profiling_Release.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. Unapproved Custom Clinics Leaking into Doctor Profiles
- **Problem Encountered:**
  - Newly added custom facilities awaiting approval (e.g. `INST-07990`) were selectable in doctor profiling before SFE approval.
- **Root Cause Identified:**
  - Inverted boolean check in `HcpWizardScreen._hasUnapprovedWorkplaces` and unrestricted registration in `LocationResolver`.
- **Solution Applied:**
  - Hardened `Institution.isApprovedForProfiling` and `LocationResolver.registerInstitutions` to strictly filter for approved facilities (`workflow_state == 'Approved'` or `docstatus == 1`).
- **Files Modified:**
  - `lib/screens/hcp_wizard_screen.dart`
  - `lib/services/api_service.dart`
- **Verification Status:** Verified unapproved clinics are locked from wizard selection (PASSED).
