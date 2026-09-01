# Changelog

All notable changes to the **HCP Profiling App** will be documented in this file.
The project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [V.0.1.0] - 2026-08-27

### 🚀 Major Highlights & Workflows
- **App Rebranding**: Renamed application from "PIMS HCP" to **"HCP Profiling"** across Login, Navigation Drawer, and App metadata.
- **Redesigned Step 2 (Doctor's Information)**:
  - Uncluttered default view displaying only the top DOCTOR'S INFORMATION card and search input.
  - Interactive **Profile Action** auto-detection for existing vs new HCP.
  - Form fields dynamically pop up when selecting an existing doctor or clicking `[ Add New Doctor ]`.
  - Left-aligned all `+ Add Row` buttons across Specializations, Workplaces, and Contacts.
- **Removed "Others" Tab & Auto-Populated Hidden Form Fields**:
  - Automatically derives `account_or_program`, `territory`, `sales_person`, and `submission_date` behind the scenes.
  - Hidden from direct view to streamline user workflow while ensuring all mandatory ERPNext fields are populated.
- **Accurate Real-Time Submission Timestamping**:
  - Automatically captures the exact system submission timestamp (formatted for 12-hour AM/PM display) in ERPNext doctype `HCP Profile Submission`.
- **In-Place Doctor Update & Overwrite (Tamper Prevention)**:
  - Updating an existing doctor profile immediately updates the doctor record in ERPNext master list and syncs the corresponding HCP Account without requiring manual managerial approval or creating duplicate submission entries.
- **Accurate Counting & Filter Alignment**:
  - Doctor account screen denominator counting resolved accurately across all account roles (medrep, managerial, admin).
- **Human-Readable PSGC Geo-Resolution**:
  - Added comprehensive PSGC dictionary for Philippine cities and provinces to render clean names (e.g. "Manila City", "Metro Manila-Manila") rather than raw technical codes.

### 📦 Release Binaries
- `releases/V.0.1.0/HCP_Profiling_V.0.1.0.ipa`
- `releases/V.0.1.0/PIMS_HCP_V.0.1.0.ipa`
- `HCP_Profiling.ipa` (root symlink/build)
