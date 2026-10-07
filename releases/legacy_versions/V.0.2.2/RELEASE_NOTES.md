# Release Notes: Version V.0.2.2

- **Application Name**: HCP Profiling
- **Version**: V.0.2.2 (Build 4)
- **Release Date**: September 15, 2026
- **Target Backend**: ERPNext v15
- **Supported Platforms**: Android (.apk)

---

## What's Changed in V.0.2.2 (+1 Patch)

### 1. Automatic Permanent Deletion of Rejected Resubmissions
- **Behavior**: When a MedRep modifies and resubmits a previously rejected institution (`is_resubmission == 1`), if the SFE Specialist rejects it again, the proposal is permanently deleted from ERPNext (`DELETE /api/resource/Institution/{name}`) and purged from local memory/cache.
- **Result**: The resubmission is completely removed from both the SFE approval queue and the MedRep's tracking screen.

### 2. Discard Option for Rejected Submissions
- Added a **`Discard`** button next to **`Modify & Resubmit`** in the MedRep's **Institution Approvals** hub.
- Allows MedReps to permanently delete unneeded or invalid rejected proposals directly without resubmitting.

### 3. Absolute Masterlist Isolation of Non-Approved Institutions
- Ensured across all screens (`actualInstitutions`, doctor profiling wizard, doctor masterlist, dashboard metrics, and report lists) that rejected or pending institutions are strictly excluded from the `Institution` DocType list.
- An institution only ever enters the selectable institution masterlist once it receives official approval (`Approved`) from the SFE Specialist.

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. Re-rejected Submissions Lingering Indefinitely on Server
- **Problem Encountered:**
  - Proposals that were resubmitted and rejected a second time remained in the database indefinitely.
- **Root Cause Identified:**
  - Rejection handler only flagged status without evaluating resubmission cycles, causing multi-cycle rejected records to accumulate as database clutter.
- **Solution Applied:**
  - Implemented automatic deletion of rejected resubmissions (`is_resubmission == 1`) and introduced Discard option for unfixable proposals.
- **Files Modified:**
  - `lib/services/api_service.dart`
  - `lib/screens/institution_approvals_screen.dart`
- **Verification Status:** Verified second rejection cleanup (PASSED).

---

## Release Binaries Included in this Folder
### Android (.apk)
- `HCP_Profiling_V.0.2.2.apk`
- `HCP_Profiling_Release.apk`
