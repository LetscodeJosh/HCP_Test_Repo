# Release Notes: Version V.0.1.0

- **Application Name**: HCP Profiling
- **Version**: V.0.1.0 (Build 1)
- **Release Date**: August 27, 2026
- **Target Backend**: ERPNext v15
- **Supported Platforms**: iOS (.ipa)

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

## Release Binaries Included in this Folder
- `HCP_Profiling_V.0.1.0.ipa`
- `PIMS_HCP_V.0.1.0.ipa`
