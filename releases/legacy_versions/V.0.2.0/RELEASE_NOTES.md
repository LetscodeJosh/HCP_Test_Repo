# Release Notes: Version V.0.2.0

- **Application Name**: HCP Profiling
- **Version**: V.0.2.0 (Build 2)
- **Release Date**: September 15, 2026
- **Target Backend**: ERPNext v15
- **Supported Platforms**: Android (.apk)

---

## What's New in V.0.2.0

### 1. SFE Specialist Institution Approval System & Gating Architecture
- Newly created institutions are submitted in state `Pending Approval`.
- Unapproved institutions are blocked from doctor profiling selection across all MedReps to prevent phantom associations.
- SFE Specialists (`sfe_specialist` role / `Sales User` + `SFE Specialist` role profile) have dedicated approval authority to inspect newly created healthcare institutions.
- SFE approval action transitions institution to `Approved`, unlocking it for doctor workplace selection.
- SFE rejection transitions institution to `Rejected` with a mandatory rejection comment.

### 2. MedRep "Institution Approvals" Hub
- Added dedicated navigation drawer option **"Institution Approvals"** for Medical Representatives.
- Displays all institutions submitted by the logged-in MedRep with status pills (`Pending Approval`, `Approved`, `Rejected`).
- Allows MedReps to view SFE reviewer feedback/rejection comments.
- Supports editing details and resubmission directly from the app back into `Pending Approval`.

### 3. Role-Based Navigation & SFE Isolation
- SFE Specialists log in directly to the **SFE Institution Dashboard** (queue review mode).
- MedReps maintain their doctor profiling and workflow hubs with access to the new Institution Approvals center.

### 4. Visual & Branding Enhancements
- Updated login page subtitle to **"Your Health Profile Buddy"**.
- App drawer dynamically reflects **HCP Profiling V.0.2.0** above the Log Out button.

### 5. Mandatory Repository Cleanliness
- Clean workspace structure maintaining zero root-level clutter.

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. Uncontrolled Institution Creation & Lack of SFE Governance
- **Problem Encountered:**
  - New institutions were created without administrative review, leading to duplicate and unverified healthcare clinics in doctor profiles.
- **Root Cause Identified:**
  - Absence of an approval lifecycle state machine in the mobile client allowed directly committed unverified clinics into the masterlist.
- **Solution Applied:**
  - Introduced SFE Institution Approval System, strict gating architecture (`isApprovedForProfiling == false`), dedicated MedRep `Institution Approvals` hub, and role-based SFE isolation.
- **Files Modified:**
  - `lib/screens/institution_approvals_screen.dart`
  - `lib/screens/sfe_institution_dashboard_screen.dart`
  - `lib/services/api_service.dart`
- **Verification Status:** Role isolation and gating verified (PASSED).

---

## Release Binaries Included in this Folder
### Android (.apk)
- `HCP_Profiling_V.0.2.0.apk`
- `HCP_Profiling_Release.apk`
