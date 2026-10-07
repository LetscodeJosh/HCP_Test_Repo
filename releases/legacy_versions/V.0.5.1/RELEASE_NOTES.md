# Release Notes - HCP Profiling App V.0.5.1 (Build 27)

**Release Date:** September 30, 2026  
**Version:** V.0.5.1  
**Build Number:** 27  
**Target Environment:** ERPNext v15 Production & PIMS Offline Edge

---

### 🌐 Summary of Key Changes in Build 27 (Territory Reconfiguration SFE Laptop Edition)

#### 1. Standalone Installer & Mobile App Separation
- **Mobile Menu Streamlined**: Removed the "Territory Reconfiguration" option from `AppDrawer` in the HCP mobile app. The mobile app is strictly reserved for doctor profiling, while territory reconfiguration is executed on the laptop web application.
- **Laptop Installer**: Built an automated Windows installer in `installers/Territory_Reconfiguration_App/install_territory_portal.bat` creating desktop and Start Menu shortcuts, with zero dependencies required.
- **Distribution Package**: Packaged complete standalone setup archive into `releases/Territory_Reconfiguration_Setup.zip`.

#### 2. Interactive Reconfiguration Editor (No CSV Dependency)
- Removed CSV upload requirement; SFE leads now operate directly on live interactive records with add, modify, delete, transfer, and rename capabilities.
- Aligned table columns to the required 6-column specification:
  - **Latest Previous Code**: Historical / reference code.
  - **Active Code**: Active / newly assigned territory code.
  - **Assigned MedRep**: Formatted strictly as `[Territory Code] - [Name of MedRep]` with distinct User ID badges.
  - **Doctor Count**: Pure integer number only (`0`, `3`, `1`, `2`), removing "Doctors" text.
  - **Status**: High-contrast `UNCHANGED` and `CHANGED` badges.
  - **Actions**: Direct interactive Edit, Audit Trail, and Archive/Delete triggers.

#### 3. Platforce CRM-Style Column Filtering
- Embedded an inline filter row directly beneath table headers allowing real-time, multi-column search filtering by Previous Code, Active Code, Rep Name/ID, Doctor Count, and Status.

#### 4. Unique User ID vs Record ID & Transfer Tracking
- Maintained immutable `Record ID` (e.g. `REC-AD0101`) for territory slots while tracking `Unique User ID` (e.g. `EMP-10492`) for representatives.
- When representatives resign or transfer, the territory slot is preserved and reassigned to a new representative with a new User ID, logging the full event history to the record's audit trail.

#### 5. Interactive Territory Tree Format View
- Added toggle between grid table and collapsible hierarchical territory tree view (Program $\rightarrow$ District Cluster $\rightarrow$ Territory Code - MedRep $\rightarrow$ Linked Doctors) with expand/collapse all controls and quick editing.

#### 6. Realignment & Archive (Tab 2) & Summary Report (Tab 3)
- Retained only 3 tabs in the sidebar: **Reconfiguration Editor**, **Realignment & Archive**, and **Summary Report**.
- Tab 2 features active district clusters and an archive vault preserving decommissioned codes with one-click reactivation.
- Tab 3 provides metric KPIs and a master chronological audit log with CSV export.

---

### 🏥 Summary of Key Changes in Build 26

#### 1. Title-Case Auto-Capitalization for Institution & Workplace Names
- **Standardized Data Format**:
  - Implemented `TitleCaseTextInputFormatter` combined with `TextCapitalization.words` across `ProposeInstitutionDialog`, `InstitutionApprovalsScreen` (Modify & Resubmit dialog), and `SfeInstitutionDashboardScreen` (Normalize Facility dialog).
  - Automatically capitalizes the initial letter of every word typed in real time (e.g., `test institution` $\rightarrow$ `Test Institution`, `st. luke's medical center - bgc` $\rightarrow$ `St. Luke's Medical Center - Bgc`).
  - Ensures all facilities adhere to the normalized enterprise naming convention regardless of soft or hard keyboard input.

#### 2. Refined, Non-Intrusive Locked UX for Step 3 Location Details
- **Theme-Aligned Aesthetic Disabled State**:
  - Removed all intrusive `Locked` labels, lock padlocks, and harsh disabled styling from Step 3: Location Details.
  - Replaced with a subtle, elegant disabled styling consistent with the dark blue / slate theme of the HCP App:
    - Soft container background (`#F8FAFC`).
    - Crisp slate borders (`#CBD5E1`).
    - Standard placeholder text (`#94A3B8`) without "Locked" tags.
    - Fields remain non-clickable until the facility name is uniquely fulfilled.
  - Removed confusing header status indicators (`(Locked: ...)` and `(Unlocked & Editable)`).

#### 3. Automatic Step 3 Location Clear-Out on Name Wipe
- **Preventing Stale Location Data Retention**:
  - Whenever the Institution Name field is emptied or has fewer than 3 characters, all Step 3 location fields (**Region**, **Province**, **City**, and **Street Address**) and directory selections are automatically cleared.
  - Prevents retaining previously encoded location details from prior typed facilities.

#### 4. Immediate 60-Second Edit Concurrency Lock Trigger on "Edit" Icon Click
- **Eliminating DSM & MedRep Collision**:
  - The 60-second concurrency cooldown now starts **immediately when the MedRep or DSM taps the "Edit" / "Modify & Resubmit" icon**, rather than only upon submit.
  - Both DSM and MedRep views reflect that the facility is currently being edited with a live countdown timer (`Being edited by [User] (Xs)`).
  - If another user attempts to edit the facility during an active cooldown, an alert informs them who is editing and displays the remaining seconds to prevent conflicting modifications.
  - If the user cancels out of the edit dialog without submitting, the lock is freed up automatically (`clearEditingCooldown`).

#### 5. Read-Only Resubmission Audit Trail
- **Tamper-Evident History for All Facilities**:
  - Created `InstitutionAuditTrailDialog` recording the full lifecycle history of each facility:
    - **Initial Proposal** (User, Role, Facility Classification, and Location Snapshot).
    - **Resubmission Attempts** (Attempt N/2 with updated parameters).
    - **SFE Normalization** (SFE Specialist standardized metadata).
    - **Approvals & Rejections** (Reviewer notes, rejection reasons, routing).
  - Accessible in verified **Read-Only** mode for **SFE/Admin**, **DSM**, and **MedRep** directly from cards in `InstitutionApprovalsScreen` and `SfeInstitutionDashboardScreen`.

#### 6. UI & Redundancy Clean-Up
- **Removal of Redundant Proposal Button in Institution Submission**:
  - Removed the `[+ Propose New Institution]` button from `InstitutionApprovalsScreen` AppBar actions and FAB.
  - Facility proposals are now consolidated within **Step 2 of HCP Profile Submission**.
  - Restyled proposal buttons in doctor wizard Step 2 to dark blue (`#0B192C` and `#1E3E62`) matching the HCP App button design standard.

---

### 📦 Artifacts & File Locations
- **Universal Release Binary:** [HCP_Profiling_Release.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)
- **Versioned Binary:** [HCP_Profiling_V.0.5.1.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.5.1/HCP_Profiling_V.0.5.1.apk)
- **Metadata Spec:** [metadata.json](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.5.1/metadata.json)
