# Release Notes - HCP Profiling App V.0.4.0 (Build 11)

**Release Date:** September 16, 2026  
**Build Number:** 11  
**Target ERPNext Version:** v15  
**Version Increment:** Minor (+1 Minor)

---

## 🌟 Key Updates & Highlights

### 1. 🏛️ ERPNext-Style Institution Directory Search Filter & Aligned Layout
- **Dedicated `InstitutionDirectoryScreen`**:
  - Replaces the basic bottom sheet with an intuitive, full-screen facility masterlist accessible from the navigation drawer.
- **Direct Column Search Filters (Matching ERPNext Desk)**:
  - Ergonomic search inputs for each column attribute:
    - **`ID`**: Instant lookup by ID (e.g. `INST-07990`, `00123`).
    - **`Institution Name`**: Real-time facility name search.
    - **`Region`**: Filter by Philippine administrative region (e.g. `NCR`, `Region III`).
    - **`Province`**: Filter by province (e.g. `Metro Manila`, `Cebu`, `Davao`).
    - **`City/Municipality`**: Filter by town or city (e.g. `Quezon City`, `Makati`).
  - **No Collapsible Filter Popup Button**: Excluded the `[ ≡ Filter | × ]` popup button (Image 2) per explicit request, keeping all filter inputs directly and immediately accessible.
  - Added a **`Clear Filters`** reset action that automatically appears when any filter is active.
- **Sort Dropdown & Direction Toggle**:
  - Sort fields: `Last Updated On`, `Institution Name`, `ID`, `Created On`, `Region`, `Province`, `City/Municipality`, `Status`.
  - Ascending / Descending toggle button (`↑` / `↓`).
- **Status Filter Tabs**:
  - Live metric chips: `All`, `Approved`, `Pending Approval`, `Rejected`.
- **Aligned Layout (Mobile & Tablet Compatible)**:
  - Header row: `INSTITUTION NAME` | `STATUS` | `ID`.
  - Data rows: Healthcare icon, bold facility name, color-coded status badges, Region, Province, and City badges, and monospaced ID chip with 1-tap clipboard copying.
  - Tap row opens detailed facility breakdown modal showing full addresses, SFE rejection remarks (if rejected), and audit timestamps.

### 2. ⚡ SFE Functional Parity with Admin Across All Modules
- Upgraded the **Sales Force Effectiveness (SFE)** role to have full parity in accessibility, functionality, and usability with **Admin**:
  - Full access to the universal **HCP Dashboard** with multi-program metrics and program switcher.
  - Full access to **Doctor Listing** (`DoctorMasterlistScreen`) with program filtering and doctor creation.
  - Full access to **Doctor Account** (`DoctorAccountScreen`) with full scope management, cycle filtering, and editing.
  - Full access to **HCP Profile Submissions** (`SubmissionHistoryScreen`) with All Scope toggle, program filtering, and approval transitions.
- **Dedicated Institution Submission Separation**:
  - **SFE / Admin**: Dedicated **SFE Approval Hub** (`SfeInstitutionDashboardScreen`) for evaluating facility proposals and approving/rejecting them.
  - **MedRep / Manager**: Dedicated **Submission Hub** (`InstitutionApprovalsScreen`) for proposing new facilities and tracking approval states.

---

## 📦 Binaries
- [HCP_Profiling_V.0.4.0.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.0/HCP_Profiling_V.0.4.0.apk)
- [HCP_Profiling_Release.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. SFE Role Administrative Parity Lockout
- **Problem Encountered:**
  - SFE Specialists encountered early return blocks when trying to view doctor masterlists or program submission summaries.
- **Root Cause Identified:**
  - Restrictive role checks in `ApiService.fetchDoctors()`, `fetchHcpAccounts()`, and `fetchSubmissions()`.
- **Solution Applied:**
  - Removed early return blocks granting SFE full administrative parity with System Manager while maintaining dedicated SFE Approval Hub separation.
  - Built dedicated `InstitutionDirectoryScreen` with desk list alignment.
- **Files Modified:**
  - `lib/services/api_service.dart`
  - `lib/screens/institution_directory_screen.dart`
- **Verification Status:** SFE administrative access and program switcher verified (PASSED).
