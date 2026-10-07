# Release Notes: Version V.0.2.1

- **Application Name**: HCP Profiling
- **Version**: V.0.2.1 (Build 3)
- **Release Date**: September 15, 2026
- **Target Backend**: ERPNext v15
- **Supported Platforms**: Android (.apk)

---

## What's Fixed in V.0.2.1 (+1 Patch)

### 1. SFE Specialist Dashboard Display for Newly Submitted Institutions
- **Problem**: When a MedRep submitted a new institution, the app sent `'workflow_state': 'Pending Approval'` in the insert payload, causing ERPNext Frappe to return HTTP 417 `WorkflowPermissionError` (as docs under workflow must be inserted in state `Draft`). The app fell back to client-only cache, preventing the record from saving to ERPNext and hiding it from the SFE Specialist Dashboard.
- **Fix**: The insert payload now posts clean facility attributes (`institution_name`, `city_municipality`, `province_name`) into initial state `Draft`, and immediately executes `apply_workflow` with action `Submit for Approval`. The record is successfully created in ERPNext under state `Pending Approval` and instantly appears in the SFE Specialist queue.

### 2. Institution Doctype Masterlist Hygiene & Isolation
- **Problem**: Rejected institutions appeared in the workplace selector during doctor profiling with a rejected badge, cluttering the masterlist.
- **Fix**: The doctor profiling workplace picker strictly filters and presents only actual, verified masterlist institutions (`!i.isRejected && !i.isPendingApproval`). Rejected and pending facilities are excluded from the doctor workplace list.
- **MedRep Access**: Rejected facilities remain accessible and editable exclusively within the MedRep's dedicated **"Institution Approvals"** area, where the MedRep can review SFE rejection remarks, modify facility data, and resubmit for approval.

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. Newly Submitted Facilities Not Appearing in SFE Queue (HTTP 417)
- **Problem Encountered:**
  - Facilities proposed by MedReps failed to appear on SFE Specialist's dashboard with HTTP 417 `WorkflowPermissionError`.
- **Root Cause Identified:**
  - App attempted to insert records directly as `'workflow_state': 'Pending Approval'`, violating ERPNext workflow rules requiring initial insertion in `Draft`.
- **Solution Applied:**
  - Implemented two-stage insert flow: created in `Draft` state first, then immediately applied `Submit for Approval` workflow transition.
- **Files Modified:**
  - `lib/services/api_service.dart`
- **Verification Status:** SFE approval queue immediately displays new submissions (PASSED).

---

## Release Binaries Included in this Folder
### Android (.apk)
- `HCP_Profiling_V.0.2.1.apk`
- `HCP_Profiling_Release.apk`
