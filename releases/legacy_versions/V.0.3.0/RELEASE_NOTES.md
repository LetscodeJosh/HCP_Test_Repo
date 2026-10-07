# Release Notes - HCP Profiling App V.0.3.0 (Build 9)

**Release Date:** September 16, 2026  
**Build Number:** 9  
**Target ERPNext Version:** v15  
**Version Increment:** Minor (+1 Minor)

---

## 🌟 Key Updates & Highlights

### 1. 🏥 Pending Institution Profiling Enabled for MedReps
- MedReps can now immediately assign and profile doctors with newly proposed institutions even while their workflow status is `Pending Approval`.
- Removed strict blocking barriers in `ApiService.createSubmission()`, `updateSubmission()`, `syncHcpAccount()`, and `HcpWizardScreen`.
- Only explicitly `Rejected` facilities remain prevented from submission, safeguarding masterlist data integrity while empowering field efficiency.

### 2. 📝 Dynamic Workplace Approval Status Notes
- **ERPNext Desk Backend**:
  - Provisioned Custom Field `workplace_approval_note` on DocType `HCP Account`.
  - Configured Frappe Client Script `HCP Account-Client` on ERPNext to dynamically set description badges below the `workplace` field:
    - Amber note: `<i class="fa fa-clock-o"></i> this institution is still pending for approval`
    - Green note: `<i class="fa fa-check-circle"></i> this institution are now approved`
- **Mobile HCP App**:
  - Implemented dynamic status note banners below the Workplace card in the Doctor Account detail modal, doctor list cards, and HCP Profiling Wizard Step 2.
  - Automatically transitions note from pending to approved in real time upon SFE Specialist verification.

### 3. 🔍 Smart Predictive Autocomplete & Duplicate Detection Dropdown
- When typing in the institution name text field during facility proposal:
  - Predictive search inspects all ~7,000 baseline healthcare facilities and dynamically registered institutions.
  - Suggests top matches embedding verified PSGC locations: `[City], [Province], [Region]`.
  - Intelligently flags potential duplicate entries with high-visibility warning banners.
  - 1-tap selection auto-fills workplace name, Region, Province, and City fields.
  - Added duplicate validation safeguard preventing redundant submissions for already approved directory institutions.

---

## 📦 Binaries
- [HCP_Profiling_V.0.3.0.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.3.0/HCP_Profiling_V.0.3.0.apk)
- [HCP_Profiling_Release.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. Duplicate Facility Submissions & Inability to Profile Pending Clinics
- **Problem Encountered:**
  - Reps repeatedly proposed identical clinics already in the masterlist; reps were blocked from doctor profiling if a clinic was unapproved.
- **Root Cause Identified:**
  - Lack of autocomplete duplicate checking during institution creation; strict gating blocking pending clinics.
- **Solution Applied:**
  - Built smart predictive autocomplete with real-time duplicate detection dropdown across ~7,000 facilities with 1-tap auto-fill.
  - Provisioned backend Custom Field `workplace_approval_note` on `HCP Account` with Frappe client script dynamically setting amber/green status descriptions.
- **Files Modified:**
  - `lib/screens/institution_approvals_screen.dart`
  - `lib/services/api_service.dart`
  - `lib/models/hcp_account.dart`
- **Verification Status:** Duplicate warning banner and dynamic note updates verified (PASSED).
