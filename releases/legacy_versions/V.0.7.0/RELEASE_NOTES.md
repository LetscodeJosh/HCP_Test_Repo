# HCP Profiling App - Release Notes V.0.7.0 (Build 43)
**Release Date**: October 11, 2026

---

## 🏥 Key Feature Highlights & Operational Workflows

### 1. Multi-Doctor Institution Rejection Cascade & Batch Remapping
- **Multi-Doctor Rejection Propagation**:
  - When SFE rejects a newly proposed institution with cause, rejection tags (`[REJECTED INSTITUTION: <reason>]`) and status indicators automatically propagate across all doctors assigned to that MedRep who are affiliated with that facility.
  - Live ERPNext v15 bidirectional synchronization across `HCP Profile Submission`, `HCP Account`, and `HCP` doctypes, plus memory cache and disk snapshots.
- **Batch Remapping & Facility Synchronization**:
  - Remapping a rejected facility to an approved masterlist institution immediately updates and resolves all connected doctor records in batch under that MedRep.
  - Clears rejection remarks and indicators across all linked records in ERPNext and mobile app.
- **1-Click Remapping UI**:
  - Added direct `Remap` action buttons in Doctor Profiling Wizard and Doctor Profile Workplace Table next to rejected institution badges.

### 2. Inviolable Consent Signature Preservation
- **Zero Consent Loss Guarantee**:
  - Captured doctor digital signatures (`consent_signature`) and consent agreements are strictly preserved byte-for-byte during facility remapping, editing, and resubmissions. MedReps never lose signed consents when modifying rejected institutions.
  - End-to-end integration test validated 100% byte parity of stored signatures post-remap.

### 3. Smart Detector & Mandatory Certification Gate
- **Active Real-Time Detector**:
  - AI Similarity Detector remains continuously active while typing workplace names.
- **Mandatory Attestation Checkbox**:
  - Location detail fields (Region, Province, City, Barangay, Street) remain locked until the MedRep checks the explicit certification checkbox:
    > *"This certifies that this institution which is not in the directory is valid and accurate."*
  - Submission remains blocked if matching directory items exist or if the certification is unacknowledged.

### 4. ERPNext v15 Dedicated List View Column & CSV/Excel Audit Parity
- **Custom Field `rejected_institution_tag`**:
  - Added on `HCP Profile Submission`, `HCP Account`, and `HCP` doctypes with `in_list_view: 1` and `in_standard_filter: 1`.
  - Prominent red indicator badges in List View and top alert banners in Form View.
  - SFE Specialists can filter and export all past rejected occurrences by MedRep via standard Frappe Export (Excel/CSV).

---

## 📦 Release Artifacts
- **Android Release APK**: `releases/HCP_Profiling_Release.apk`
- **Legacy Version APK**: `releases/legacy_versions/V.0.7.0/HCP_Profiling_V.0.7.0.apk`
- **Territory Portal Windows Installer**: `releases/Territory_Reconfiguration_Setup.exe`
- **Territory Portal Zip Package**: `releases/Territory_Reconfiguration_Setup.zip`
- **Metadata Spec**: `releases/legacy_versions/V.0.7.0/metadata.json`
