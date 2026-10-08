# HCP Profiling App - Release Notes V.0.6.8 (Build 40)
**Release Date**: October 8, 2026

---

## 🏥 Key Feature Highlights & Bug Fixes

### 1. SFE / Admin Institution Remapping Multi-DocType Synchronization
- **Backend Workflow State Alignment (`Remapped`)**:
  - Registered `Workflow State` **`Remapped`** and `Workflow Action Master` **`Remap`** in ERPNext v15.
  - Configured `Institution WF` with allowed transitions from `Rejected` and `Pending Approval` to `Remapped` via action `Remap`, eliminating HTTP 417 `WorkflowPermissionError: Workflow State transition not allowed from Rejected to Remapped`.
- **Cross-DocType Child Table Schema Alignment**:
  - Overhauled `remapRejectedInstitution` in `ApiService` to dynamically query ERPNext backend for all linked submissions, doctors, and program accounts.
  - Aligned exact child table schemas for all three DocTypes:
    - **`HCP Profile Submission`**: child table `table_workplaces` (`HCP Profile Submission Workplaces`) with `hcp_workplace`, `workplace_name`, `city_municipality`, `province_name`.
    - **`HCP`**: child table `hcp_workplace` (`HCP Workplaces`) with `hcp_workplace`, `city_municipality`, `province_name`.
    - **`HCP Account`**: child table `workplace_info` (`HCP Account Workplace`) with `hcp_workplace`, `city_municipality`, `province_name`.
  - Automatically updates in-memory stores and persists updated local cache files (`frappe_hcp_profile_submission_list.json`, `frappe_hcp_list.json`, `frappe_hcp_account_list.json`).
  - Clears rejected facility filters so remapped institutions are immediately removed from the Rejected list and unblocks MedRep profiling.

### 2. Title Case Normalization for HCP Middle Names & Full Names
- **Root Cause Elimination in `DataSanitizer`**:
  - Identified that `DataSanitizer.sanitizePayload` checked `key.contains('id')` to convert IDs to uppercase; because `'middle_name'` contains `'id'` (`m-id-dle`), all middle names were inadvertently uppercased to ALL CAPS (`PAMBUENA`, `DE LEON`).
  - Constrained ID uppercasing to standalone `id`, prefix `id_`, suffix `_id`, or `_id_`, while routing `name` and `middle` fields strictly through `cleanTrimProper`.
- **HCP Profiling Wizard & Model Serialization**:
  - Added `cleanTrimProper` normalization in `Hcp.toJson()`, `HcpProfileSubmission.toJson()`, and `_syncFullName()` in `HcpWizardScreen`.
  - Added `TextCapitalization.words` to doctor name text fields in `HcpWizardScreen`.
  - Fixed and normalized existing ERPNext records with uppercase middle names across `HCP` and `HCP Profile Submission`.

---

## 📦 Release Artifacts
- **Android Release APK**: `releases/HCP_Profiling_Release.apk` (58.94 MB)
- **Legacy Version APK**: `releases/legacy_versions/V.0.6.8/HCP_Profiling_V.0.6.8.apk`
- **Territory Portal Windows Installer**: `releases/Territory_Reconfiguration_Setup.exe`
- **Territory Portal Zip Package**: `releases/Territory_Reconfiguration_Setup.zip`
- **Metadata Spec**: `releases/legacy_versions/V.0.6.8/metadata.json`
