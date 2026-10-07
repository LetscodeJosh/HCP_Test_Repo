# Release Notes - HCP Profiling App V.0.4.2 (Build 13)

**Release Date:** September 16, 2026  
**Build Number:** 13  
**Target ERPNext Version:** v15  
**Version Increment:** Patch (+1 Patch)

---

## 🌟 Key Updates & Highlights

### 1. 🏛️ ERPNext Institution DocType Status Parity (`https://dev.pmii-marketing.com/app/institution`)
- **Direct Workflow State Mapping**:
  - Matched healthcare facility status directly with ERPNext's workflow state engine:
    - **`Approved`**: Emerald Green badge (`Color(0xFF059669)` / `Color(0xFFECFDF5)`).
    - **`Pending Approval`**: Amber/Orange badge (`Color(0xFFD97706)` / `Color(0xFFFFFBEB)`).
    - **`Draft`**: Correctly badged with a Red pill (`Color(0xFFDC2626)` / `Color(0xFFFEF2F2)`), matching ERPNext's red `Draft` pill indicator for initial masterlist facilities.
    - **`Rejected`**: Red badge (`Color(0xFFDC2626)`) with SFE rejection remarks.
- **Fixed Masterlist Availability**:
  - Resolved issue where 3,900+ initial facilities imported into ERPNext in `Draft` state were misclassified as rejected, restoring doctor profiling linkage across all valid facilities.

### 2. 🔍 Search Filter UI & Interaction Parity (Matching HCP Profile Submission)
- **Search Filter UI Parity**:
  - Re-styled and structured the search filter engine to match `SubmissionHistoryScreen` (HCP Profile Submission):
    - **Toggle Button**: `= Filter` / `Filter ×` button styled with dark slate container (`#1E293B`) and slate borders (`#334155`).
    - **Inline `Clear Filters` Action**: Pill badge with clear icon that automatically appears when any filter parameter is active.
    - **Sort Controls**: Ascending / Descending toggle (`↑` / `↓`) and dynamic sort dropdown (`Last Updated On`, `Institution Name`, `ID`, `Created On`, `Status`, `Region`, `Province`, `City/Municipality`).
    - **Horizontal Scroll Filter Row**: Sleek input row with dark text fields (`ID`, `Institution Name`, `Status` dropdown [`All`, `Approved`, `Pending Approval`, `Draft`, `Rejected`], `Region`, `Province`, `City/Municipality`).
- **Dynamic Record Count Header**:
  - Table column header displays live filtered record count (`Showing X of Y` when filters are active, or total count when unfiltered).

---

## 📦 Binaries
- [HCP_Profiling_V.0.4.2.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.2/HCP_Profiling_V.0.4.2.apk)
- [HCP_Profiling_Release.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. 3,900+ Master Facilities Misclassified as Rejected
- **Problem Encountered:**
  - Over 3,900 baseline healthcare facilities imported into ERPNext in `Draft` state were rendered with red rejected badges in the app, blocking doctors from linking to valid hospitals.
- **Root Cause Identified:**
  - Mobile app logic treated any facility that was not `Approved` as rejected.
- **Solution Applied:**
  - Aligned status colors directly with ERPNext Desk: `Draft` badged in Red pill, matching ERPNext Desk indicator.
  - Restored profiling linkage across all 3,990+ facilities from cached masterlist.
  - Rebuilt search filter engine with collapsible `[= Filter]` bar, dynamic counter (`Showing X of Y`), and inline `[Clear Filters]` badge.
- **Files Modified:**
  - `lib/screens/institution_directory_screen.dart`
  - `lib/services/api_service.dart`
- **Verification Status:** Verified search and filtering across 3,990+ facilities with zero UI lag (PASSED).
