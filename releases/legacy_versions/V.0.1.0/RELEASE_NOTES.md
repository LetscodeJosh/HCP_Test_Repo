# Release Notes: Version V.0.1.0

- **Application Name**: HCP Profiling
- **Version**: V.0.1.0 (Build 1)
- **Release Date**: August 27, 2026
- **Target Backend**: ERPNext v15
- **Supported Platforms**: iOS (.ipa), Android (.apk)

---

## What's New in V.0.1.0

### 1. Rebranded Application Identity
- Full app rebrand from "PIMS HCP" to **"HCP Profiling"**.
- Updated branding across Login Screen, App Drawer, Navigation Bars, and Biometric prompts.

### 2. Streamlined Step 2 Interactive Wizard
- Initial view shows only the doctor photo placeholder and search picker.
- Tapping **"Add New Doctor"** initiates a clean doctor entry flow with real-time field validation.
- Tapping an existing doctor loads all doctor masterlist details and sets Profile Action to `Existing HCP (HCP-ID)`.
- Left-aligned all `+ Add Row` action buttons across Specialization, Workplace, and Contact tables.
- Removed duplicate `+ Create a new HCP` button from the dropdown picker modal.

### 3. Automated Form Data & Hidden Fields
- Eliminated redundant "Others" tab.
- Automatically derives required fields (`account_or_program`, `territory`, `sales_person`, `submission_date`) behind the scenes.

### 4. Real-Time Accurate Timestamping
- Submissions automatically capture real-time 12-hour AM/PM timestamps.

### 5. In-Place Doctor Masterlist Tampering & Instant Sync
- Existing doctor updates apply directly to the doctor master record and active HCP Account without requiring manual approval or generating redundant submission records.

### 6. Accurate Submissions Counting & PSGC Geography Resolution
- Fixed denominator calculations across MedRep, Manager, and Admin roles.
- Added comprehensive PSGC dictionary for human-readable city and province names.

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. Doctor Record Duplication on Every Profile Update
- **Problem Encountered:**
  - Re-profiling an existing doctor created a duplicate `HCP` record instead of updating the existing doctor record.
- **Root Cause Identified:**
  - Lack of separation between universal doctor identity and program-specific commercial affiliation.
- **Solution Applied:**
  - Designed the Two-Tier Masterlist architecture (`HCP` Universal vs `HCP Account` Program Affiliation) enabling in-place doctor profile updates.
- **Files Modified:**
  - `lib/models/hcp.dart`
  - `lib/models/hcp_account.dart`
  - `lib/services/api_service.dart`
- **Verification Status:** In-place updating verified without duplicate creation (PASSED).

### 2. Submission Denominator Count Inaccuracies Across Roles
- **Problem Encountered:**
  - Doctor account denominator calculations were mismatched between MedRep, Manager, and Admin views.
- **Root Cause Identified:**
  - Query filters calculated total doctor denominators using unsegmented masterlist counts rather than role-scoped territory assignments.
- **Solution Applied:**
  - Re-architected denominator queries per user role.
- **Files Modified:**
  - `lib/screens/doctor_account_screen.dart`
- **Verification Status:** Count alignment verified (PASSED).

### 3. Raw PSGC Technical Codes Rendered in UI
- **Problem Encountered:**
  - App displayed raw technical codes (e.g. `133900000`) instead of clean municipality names.
- **Solution Applied:**
  - Built human-readable PSGC translation dictionary in `LocationResolver`.
- **Files Modified:**
  - `lib/services/location_resolver.dart`
- **Verification Status:** Human-readable city/province names verified (PASSED).

---

## Release Binaries Included in this Folder
### iOS (.ipa)
- `HCP_Profiling_V.0.1.0.ipa`
- `HCP_Profiling.ipa`
- `PIMS_HCP_V.0.1.0.ipa`

### Android (.apk)
- `HCP_Profiling_V.0.1.0.apk`
- `HCP_Profiling.apk`
- `HCP_Profiling_Release.apk`
