# HCP Profiling App - Release Notes V.0.6.0 (Build 32)
**Release Date**: October 6, 2026

---

## 🏥 Key Feature Highlights

### 1. Institution Rejection & Multi-DocType Reflection
- When an institution submitted or used by a MedRep is rejected by SFE, the rejection note (`[REJECTED INSTITUTION: <cause>]`) is immediately reflected across:
  - **`HCP Profile Submission`**: Stored in `status_note` and child table `workplaces[].workflow_state = "Rejected"`.
  - **`HCP Account`**: Stored in `remarks` and flags unapproved facility status.
  - **`HCP` (Universal Masterlist)**: Stored in universal doctor `notes` and marked in child workplaces table.

### 2. Pre-Submission Guard in HCP Wizard
- If a MedRep attempts to submit HCP Profiling using an institution that has been rejected by SFE, the submission is strictly blocked.
- A prominent error banner informs the MedRep:
  `Cannot submit: <Facility> (Reason: <cause>) was rejected by SFE and cannot be used for profiling. Please remove or have SFE remap this institution.`

### 3. High-Priority Lockscreen & Logged-Out Notifications
- Integrates `flutter_local_notifications` with public lockscreen visibility.
- Banners pop up on the lockscreen/homescreen even when the MedRep is logged out of the app, powered by cached `last_active_medrep_user` in `SharedPreferences`.

### 4. SFE Remapping Hub ("Change / Remap for MedRep")
- SFE Specialists have a dedicated action in `SfeInstitutionDashboardScreen` and `InstitutionApprovalsScreen` to remap rejected facilities to active, approved masterlist facilities.
- Remapping replaces the rejected facility across all 3 DocTypes, clears the rejection block, notifies the MedRep, and allows profiling to proceed smoothly.

### 5. Label Standardization
- **Doctor Listing** $ightarrow$ **HCP**
- **Doctor Account** $ightarrow$ **HCP Account**

---

## 📦 Release Artifacts
- **Android Release APK**: `releases/HCP_Profiling_Release.apk` (58.21 MB)
- **Legacy Version APK**: `releases/legacy_versions/V.0.6.0/HCP_Profiling_V.0.6.0.apk`
- **Territory Portal Windows Installer**: `releases/Territory_Reconfiguration_Setup.exe`
- **Territory Portal Zip Package**: `releases/Territory_Reconfiguration_Setup.zip`
- **Simulation Guide**: `docs/INSTITUTION_REJECTION_AND_REMAP_SIMULATION_GUIDE.md`
- **Automated Simulation Tool**: `scratch/simulate_institution_rejection_workflow.py`
