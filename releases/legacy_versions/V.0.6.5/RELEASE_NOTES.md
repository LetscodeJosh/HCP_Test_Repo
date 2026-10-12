# Release Notes - HCP Profiling App v.0.6.5

**Build Date**: October 11, 2026  
**Version**: `v.0.6.5`  
**APK SHA-256**: `d3155edebd163e888cb7f428cead9f2c678fe5b45892acbe5d4609c21105e4a1`  
**File Size**: `58.89 MB` (61754884 bytes)

---

### 🏥 Human-Readable Institution Name Export & SFE Audit Tagging
- **Zero Institution Code Export Guarantee**:
  - Exported Excel and CSV files from ERPNext across `HCP Profile Submission`, `HCP Account`, and `HCP` doctypes display human-readable institution names (e.g., `Pims Institution`, `Yamete Hospital`, `Unsaman General Hospital`) rather than foreign key codes (`INST-08007`).
  - Added custom fields and synchronized data models ensuring facility names remain clean and descriptive across all reporting layers.
- **Permanent Facility Identification in Rejection Notes**:
  - Rejection note tags permanently retain human-readable facility names paired with specific rejection causes (e.g., `[REJECTED INSTITUTION: Pims Institution - reject]`).
  - Tagged directly to the submitting MedRep owner email for effortless SFE tracking and analysis.

### 📋 Complete List View Column Preservation (Zero Columns Disabled)
- **100% Active Column Invariant**:
  - Retained all original list view columns (`Consent`, `Valid From`, `Valid To`, `Type`, `Practice`, `Account/Program`, `Territory`, `Territory Manager`) in active status (`in_list_view: 1`).
  - Added dedicated `Rejected Institution` column with prominent red badges and tooltip rejection notes without column slicing.

### 🔁 Multi-Doctor Rejection Cascade & Autonomous Synchronization
- **Instant Facility-Wide Rejection Cascading**:
  - Rejection of an unverified institution immediately marks all linked doctors under that MedRep across `HCP Profile Submission`, `HCP Account`, and `HCP`.
- **Zero-Loss Batch Remapping**:
  - Remapping a facility updates all linked doctors in batch and clears rejection flags immediately.
- **Inviolable Consent Signature Preservation**:
  - Captured doctor digital signatures (`consent_signature`) are preserved byte-for-byte during remapping.

### 🛡️ Dashboard Streamlining & Unified Administrator Parity
- **Temporary HCP Dashboard Suppression**:
  - Removed HCP Dashboard from application navigation drawer and post-login routing pending data finalization. Users and administrators land directly on the unified Doctor Account screen.
- **Admin Switch Toggle Pruning**:
  - Removed the "Switch to SFE Portal" / "SFE View Active" toggle for administrators.
- **Unified 6-Administrator Access Standard**:
  - Fully standardized access and privileges for all six administrators: `lesantos@pims-marketing.com`, `jptan@profinsights.biz`, `crpineda@pims-marketing.com`, `bsbenitez@profinsights.biz`, `dahuinda@profinsights.biz`, and `ammiole@profinsights.biz`. All 6 administrators share identical functionality, purposes, full masterlist doctor counts, and approval workflows.
- **Institution Name Resolution in HCP Account Screen**:
  - Fixed raw code display (`INST-08007`) across HCP Account cards, workplace chips, and doctor detail dialogs. Pre-warms dynamic institution lookup and resolves rejected institutions (e.g., `Pims Institution`) to their human-readable title 100% in sync with ERPNext.

