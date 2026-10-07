# HCP Profiling & SFE Territory Reconfiguration Release Notes
## Version: V.0.5.2 (Build 28)
**Release Date**: September 30, 2026  
**Status**: Stable Enterprise Release  

---

### 🌟 Executive Overview
Release **V.0.5.2 (Build 28)** establishes the definitive production release consolidating the **Search Filter & Column Visibility Engine**, the **4-in-1 Bulk Operations Workbench**, the **Sound-Alike Phonetic Workplace Search**, and the **Enterprise Clean, Trim, Proper Backend Engine** ensuring flawless ERPNext external exports and SFE analytics.

---

### 🩺 Doctor Account Deduplication, Monthly Archive Folder Directory & Data Retention (Bugfix)
1. **Active Doctor Account Deduplication (Zero Redundancy in Current Month)**:
   - Fixed the issue where captured doctors appeared doubled or repeated when the month has already past or during monthly rollover.
   - Enforces strict single-doctor resolution (`_getDoctorDeduplicationKey`) in the Active / Current Month list. Every doctor appears strictly once.
   - All past month accounts (`isPastMonth() == true` or `isArchived == true`) are filtered out of the current active list and cleanly routed to the Archive.
2. **Monthly Archive Folder Format (Clean & Properly Aligned)**:
   - The Archive view organizes past doctors into **Month Folders** (e.g. `📁 September 2026 Archive`, `📁 August 2026 Archive`), sorted chronologically descending.
   - Each month card displays the validity cycle period, doctor count badge, and clean aesthetic layout.
   - Clicking a folder opens the archived doctors captured in that particular month with an intuitive `[◀ Back to Archive Folders]` breadcrumb button.
   - Inside each month folder, doctors are deduplicated with zero redundancy.
3. **Data Retention & Previous Month Copying**:
   - Specialization, workplace, and contact information automatically retain and copy previous month data.
   - If an account has empty child rows, fallback resolvers (`_getEffectiveSpecialties`, `_getEffectiveWorkplaces`, `_getEffectiveContacts`, `_getEffectiveInstitutionDisplay`) retrieve the doctor's previous month records or universal masterlist, guaranteeing that no profile details are lost or blank.

---

### 🛡️ Enterprise Clean, Trim, Proper Backend Engine (Always-Active)
1. **Pristine Data Sanitization for ERPNext & SFE External Workflows**:
   - **Clean**: Eliminates invisible zero-width spaces (`\u200B`, `\uFEFF`), non-breaking spaces (`\u00A0`), tabs, and carriage returns; collapses multiple spaces; strips literal `'null'` and `'undefined'` strings.
   - **Trim**: Deeply trims leading and trailing whitespace on all string attributes before sending to ERPNext DocTypes (`HCP`, `HCP Account`, `HCP Profile Submission`, `Institution`).
   - **Proper Casing**: Converts doctor names, institutions, specializations, and geographic locations into standard Title Case while preserving critical medical acronyms (`MD`, `PRC`, `OB-GYN`, `ENT`, `PIMS`, `SFE`, `NCR`, `BGC`, `PGH`).
   - **Standardized Formats**: Guarantees uppercase territory codes (`ADC0101`), uppercase IDs (`HCP-XXXXXXX`, `EMP-XXXXX`), lowercase emails, and normalized phone numbers.
2. **Web Portal CSV Export Quality Engine**:
   - Upgraded `Export CSV`, `Export Doctor List`, and `Export Audit Trail` in the Territory Reconfiguration Web App.
   - Embeds Microsoft Excel UTF-8 BOM (`\uFEFF`) so external spreadsheets, Pivot Tables, and `VLOOKUP`/`XLOOKUP` formulas open without character garbling or formula mismatch.
Release **V.0.5.2 (Build 28)** establishes the definitive production release consolidating the **Search Filter & Column Visibility Engine**, the **4-in-1 Bulk Operations Workbench** (Modify, Rename, Delete, Bulk Add), the **Sound-Alike Phonetic Workplace Search**, and official **App Branding & ERPNext Authentication**.

---

### 🔍 Search Filter & Real-Time Column Visibility Checkboxes
1. **Dynamic Column Visibility Dropdown (`Columns (6/6) 👁️`)**:
   - Independent checkboxes to show or hide each table column (`Latest Previous Code`, `Active Code`, `Assigned MedRep`, `Doctor Count`, `Status`, `Actions`).
   - **Unchecked**: Column and all cell data are immediately hidden (`display: none`).
   - **Checked**: Column and all cell data are immediately visible and accessible.
   - Quick **All**, **None**, and **Reset** controls for one-click toggling.
   - **Zero-Columns Clean State**: When all columns are unchecked (`Columns (0/6)`), the table header and all checkboxes (master header checkbox and individual row checkboxes) are completely removed. The grid renders an aesthetic, centered placeholder card (`👁️‍🗨️ All Table Columns Are Hidden`) with a one-click `👁️ Restore All Columns` action.
2. **Universal Global Search ("All Columns")**:
   - Real-time search across all columns, codes, MedReps, user IDs, districts, and doctor counts.
   - Integrated **`✕`** delete icon resets the search field instantly.
3. **Status Filter Multi-Select Checkboxes**:
   - `[✓] UNCHANGED` and `[✓] CHANGED` checkboxes appear when filtering by status.
   - Unchecking a status immediately hides records of that status from view.
4. **Unified Filtering Across All Portal Tables**:
   - **Tab 1: Active Territory Editor Grid**
   - **Tab 2: Archived / Decommissioned Vault Table** (Date, Record ID, Historical Code, Rep, Doctors, Reason, Action)
   - **Tab 3: Master Reconfiguration Audit Trail Table** (with action type checkboxes: `MODIFIED`, `BULK_EDIT`, `BULK_RENAME`, `BULK_ADD`, `BULK_DELETE`)

---

### ⚡ Comprehensive 4-in-1 Bulk Operations Workbench
1. **✏️ Modify Tab**:
   - Bulk update Status, MedRep reassignment, District Group / Cluster, and SFE compliance notes.
   - Automatically synchronizes doctor account representative bindings and logs individual `BULK_EDIT` audit entries.
2. **🏷️ Rename Tab**:
   - 4 Batch Rename Modes: `Find & Replace`, `Add Prefix`, `Add Suffix`, and `Sequential Pattern`.
   - **Live Transformation Preview Table**: Real-time before/after preview of code changes as parameters are typed.
   - Auto-checks for duplicate code conflicts before applying and marks status as `CHANGED`.
3. **🗑️ Delete Tab**:
   - Bulk Decommission to Archive Vault (preserves historical doctor mapping) or Permanent Removal.
   - Displays affected territory count and total doctor count.
   - Protected by mandatory confirmation safety checkbox.
4. **➕ Bulk Add Tab**:
   - Multi-line or comma-separated territory code input.
   - Real-time valid code parser and duplicate conflict detector.
   - Auto-generates unique record IDs (`TERR-XXX-XXXX`), user IDs (`EMP-XXXXX`), and audit trails.
   - Automatically selects newly added territories for instant verification.

---

### 🏥 Workplace Sound-Alike & Same-Phrase Dropdown Search
- Bilingual English/Filipino phonetic normalization (`LocationResolver.soundex`).
- Damerau-Levenshtein edit distance for typo tolerance (e.g. `lordes` -> `Our Lady of Lourdes Hospital`, `kardinal` -> `Cardinal Santos Medical Center`).
- Same-phrase permutation priority boost (+3200 points).

---

### 📦 Release Distribution
- **Active Release APK**: [releases/HCP_Profiling_Release.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)
- **Versioned Release APK**: [releases/V.0.5.2/HCP_Profiling_V.0.5.2.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.5.2/HCP_Profiling_V.0.5.2.apk)
- **Standalone Setup Package**: [releases/Territory_Reconfiguration_Setup.zip](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/Territory_Reconfiguration_Setup.zip)
- **Versioned Setup Package**: [releases/V.0.5.2/Territory_Reconfiguration_Setup.zip](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.5.2/Territory_Reconfiguration_Setup.zip)
