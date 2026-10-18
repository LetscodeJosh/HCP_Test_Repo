# Release Notes - HCP Profiling App v.0.7.3

**Release Date:** October 19, 2026  
**Build Number:** 48  
**Package:** `HCP_Profiling_v.0.7.3.apk`  
**Distribution:** Production Enterprise Mobile Deployment  

---

## 🌟 Key Features & Enhancements

### 1. Conditional Visibility for MedRep Institution Accuracy Certification
* **Strict Uniqueness Rule**: The certification checkbox (*"This certifies that this institution which is not in the directory is accurate and active for coverage"*) now **only displays below the search field** if the encoded institution is verified to be completely **unique** with **zero duplicates or similarities** in the directory (`_detectedMatches.isEmpty`).
* **Active Match Suppression**: If matching facilities, acronym similarities, or duplicate names are detected, or while the representative is actively typing, the certification checkbox remains completely hidden to prevent premature or duplicate submissions.
* **Instant Typing Feedback**: Integrated an in-field progress indicator during async debounce resolution to eliminate UI flicker.

### 2. ERPNext DocType Recording & XLSX Export Visibility
* **Direct DocType Field Persistence**: When an institution proposal is submitted with certification, the metadata is saved to the ERPNext DocType (`certification_note`, `is_certified: 1`, and `remarks`):
  `"Certified by MedRep: Institution is accurate and active for coverage"`.
* **Universal Activity Timeline Audit Comment**: Frappe Comment logged via `/api/resource/Comment` with `reference_doctype: 'Institution'`, creating an indelible audit record visible in ERPNext Desk.
* **Dynamic Status Note for Excel Export**:
  * Unapproved certified institutions dynamically render:  
    `"this institution is not yet approved (Certified accurate and active for coverage)"`.
  * Approved facilities transition to:  
    `"this institution is now approved"`.
  * When administrators export `.xlsx` files from ERPNext Desk for `Institution`, `HCP Account` (`workplace_approval_note`), or `HCP Profile Submission`, this check note is clearly visible in the export.

### 3. Production Verification & Enterprise Quality Assurance
* **Full Automated Test Coverage**: 72/72 tests passing (`test/inst_profiling_test.dart`).
* **Clean Code Invariant**: 0 analyzer errors and warnings (`flutter analyze --no-fatal-infos`).
* **Zero Technical Debt Audit**: Grade A+ achieved across all 5 production invariants.
