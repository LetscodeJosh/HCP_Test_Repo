# Release Notes: Version V.0.2.4

- **Application Name**: HCP Profiling
- **Version**: V.0.2.4 (Build 6)
- **Release Date**: September 15, 2026
- **Target Backend**: ERPNext v15
- **Supported Platforms**: Android (.apk)

---

## What's Changed in V.0.2.4 (+1 Patch)

### 1. Removal of INST-07982 ("Asian Hospital Wellness") from Backend
- Permanently deleted `INST-07982` ("Asian Hospital Wellness", Cavite / Bacoor City) directly from the ERPNext `Institution` DocType per user instruction.
- Server query verified: returns HTTP 404 (Not Found).

### 2. Diagnosis & Fix for Discard Not Deleting on Server
- **Root Cause Identified**:
  - In ERPNext's `Custom DocPerm` table for DocType `Institution`, the role `Sales User` had `delete: 0`.
  - When MedReps clicked "Discard" (`DELETE /api/resource/Institution/{name}`), Frappe returned HTTP 403 Forbidden.
  - In the Flutter app, `deleteInstitution()` had a premature cache-purge and lacked CSRF token handling, which removed the card from local memory and reported success even though the server rejected the deletion.
- **Server Permission Granted**:
  - Updated `Custom DocPerm` for `Sales User` and `Employee - COREnergy` to `delete: 1` on DocType `Institution`.
  - Tested end-to-end: MedRep can now delete rejected and draft submissions with HTTP 202 from Frappe.
- **Client App Reliability & Error Transparency**:
  - Added `await ensureCsrfToken()` to `deleteInstitution()` in `api_service.dart`.
  - Verified server response (HTTP 200, 202, 204, 404) before removing from `_cachedInstitutions`.
  - Added a discard progress indicator and accurate error display in `InstitutionApprovalsScreen._handleDeleteSubmission()`.

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. MedRep "Discard" Not Deleting Records on ERPNext Server
- **Problem Encountered:**
  - Rep tapped Discard and facility disappeared locally, but ERPNext retained the record on the server (HTTP 403 Forbidden).
- **Root Cause Identified:**
  - ERPNext's `Custom DocPerm` for `Sales User` on `Institution` had `delete: 0`. App had premature cache-purge and lacked CSRF token handling.
- **Solution Applied:**
  - Granted `delete: 1` on ERPNext `Custom DocPerm` for `Sales User`; added `ensureCsrfToken()` in `deleteInstitution()`; validated HTTP responses (200, 202, 204) before local cache deletion.
- **Files Modified:**
  - `lib/services/api_service.dart`
  - `lib/screens/institution_approvals_screen.dart`
- **Verification Status:** Verified server deletion returning HTTP 202 from Frappe (PASSED).

---

## Release Binaries Included in this Folder
### Android (.apk)
- `HCP_Profiling_V.0.2.4.apk`
- `HCP_Profiling_Release.apk`
