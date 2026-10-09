# Release Notes - HCP Profiling App v.0.6.5

**Build Date**: October 8, 2026  
**Version**: `v.0.6.5`  
**APK SHA-256**: `94535f9010c8ad2ccbdfd9a391d1f902c2e1b358bc92bbc0c9afa3b5a952f490`  
**File Size**: `58.94 MB`

---

### 🔤 Doctor Name Title Casing & Sanitizer Parity
- **Strict Uppercase Initial Letter for Every Word**:
  - Eliminated automatic lowercasing of Philippine surname particles (`Dela`, `De`, `Del`, `Da`, `Dos`) in `DataSanitizer.cleanTrimProper()`.
  - Every word in doctor names (first name, middle name, last name, full name) across both the mobile application and ERPNext is strictly capitalized (`John Anthony Dela Luna`, `Pantalone Yan De Luna`, `Gabriel Antonio De Leon Cruz`).
  - Scanned and harmonized all existing records in ERPNext (`HCP`, `HCP Account`, and `HCP Profile Submission`) to ensure 100% compliance.

### 🏛️ ERPNext Rejection Reflection & 1:1 Audit Parity
- **Full Rejection Reflection Across ERPNext (`ERPN`)**:
  - Rejection messages and reasons now reflect seamlessly across `HCP Profile Submission`, `HCP Account`, and `HCP` doctypes on ERPNext with identical wording as the HCP App (`[REJECTED INSTITUTION: <reason>]`).
  - Added custom fields `rejection_reason` and `workplace_approval_note` to `HCP Account` and `HCP` doctypes.
  - Deployed dynamic Client Scripts (`HCP Profile Submission-Client`, `HCP Account-Client`, `HCP-Client`, `Institution-Client`) that automatically highlight rejected entities with prominent red warning banners and descriptive notes.
  - Deployed custom List View indicators (`HCP-List`, `HCP Account-List`, `HCP Profile Submission-List`, `Institution-List`) that render red indicator tags and badges directly in list view tables for 1-click audit verification.
- **Active Rejected Institutions in HCP Profiling (ERPN Version)**:
  - Rejected institutions (such as `INST-08005` - *Yamete Hospital*) remain fully active and visible across ERPNext and mobile profiling. They are never suppressed, hidden, or deleted, allowing SFE Specialists and managers to track, audit, and remap doctor affiliations smoothly.

### 🧠 Smart Detector & Resubmission Governance
- **Smart Detector Active on Resubmit**:
  - Live debounced (300ms) duplicate and acronym detection is fully activated during MedRep/DSM resubmission dialogs. Renamed cleanly from "AI Smart Detector" to **"Smart Detector"**.
  - SFE Specialists remain unconstrained as they reference the canonical DOH-accredited hospital/clinic masterlist.
- **Human-Readable Location Fields**:
  - Eliminated raw PSGC codes (e.g. `1380600000`, `PRV-1380600000`) in the resubmission dialog. Region, Province, and City fields strictly resolve to human-readable names via `LocationResolver`.
- **Immediate Submission Lock**:
  - Institution proposals lock immediately into read-only mode upon submission. Editable only when rejected by SFE.
- **Two-Strike Resubmission Ceiling & Strict Zero Deletion**:
  - MedReps/DSMs have up to 2 attempts (`Attempt 1/2` and `Attempt 2/2`) to correct rejected proposals. If still unverified after 2 attempts, editing is permanently disabled and the facility is archived (strictly zero deletion) with guidance to contact SFE directly.
- **SFE Canonical Remapping Workflow**:
  - SFE Specialists rebind doctor profiles directly to approved DOH facilities without recycling MedRep typos. The flawed submission is archived/rejected, and doctor profiling is unblocked immediately.
- **Multi-Tier Push Notification Architecture**:
  - High-priority public lockscreen and homescreen heads-up alerts with a 5-tier fail-safe matrix ensuring 100% notification reach even if device notifications are turned off.
- **Menu Drawer Version Clean Display**:
  - HCP App version is retained at `v.0.6.5` and the `+No.` suffix is removed from the drawer menu navigation.
