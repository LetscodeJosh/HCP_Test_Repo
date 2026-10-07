# Release Notes - HCP Profiling App V.0.4.1 (Build 12)

**Release Date:** September 16, 2026  
**Build Number:** 12  
**Target ERPNext Version:** v15  
**Version Increment:** Patch (+1 Patch)

---

## 🌟 Key Updates & Highlights

### 1. 🏛️ Unified Institution Directory Listing (Removed Status Tabs)
- Removed `Approved`, `Pending Approval`, and `Rejected` tabs from `InstitutionDirectoryScreen`.
- The directory now displays a single unified listing of all institutions across the healthcare system.
- Direct column filters operate across the entire directory without pre-filtering by workflow state.

### 2. 🔍 Centered, Hideable Search Filter Panel
- Re-architected search filters into a centered, balanced layout:
  - **Centered Inputs**:
    - **`ID`**: Instant lookup by ID (e.g. `INST-07990`).
    - **`Institution Name`**: Real-time facility name search.
    - **`Region`**: Administrative region filter.
    - **`Province`**: Province filter.
    - **`City/Municipality`**: Town / city filter.
  - **Centered Controls**:
    - Sort dropdown (`Last Updated On`, `Institution Name`, `ID`, `Created On`, `Region`, `Province`, `City/Municipality`, `Status`).
    - Ascending / Descending toggle (`↑` / `↓`).
    - `Clear Filters` action button (auto-displayed when filters are active).
- **Hideable / Collapsible Design**:
  - Maximizes intuitive viewing of the healthcare directory by allowing users to toggle filters on or off.
  - **Dual Trigger Mechanisms**:
    - **AppBar Toggle Button**: Shows a filter badge with active filter count.
    - **Centered Quick Trigger Bar**: Centered pill button (`Show Search Filter ▾` / `X Filters Active • Tap to Edit ▾`).
    - **Inline "Hide" Action**: Direct collapse button at top-right of expanded filter panel.

---

## 📦 Binaries
- [HCP_Profiling_V.0.4.1.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.1/HCP_Profiling_V.0.4.1.apk)
- [HCP_Profiling_Release.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. Directory Fragmentation Across Status Tabs & Screen Space Clutter
- **Problem Encountered:**
  - Facilities were split into separate tabs (`Approved`, `Pending`, `Rejected`), and non-collapsible search filter rows consumed over 40% of vertical screen space on mobile phones.
- **Root Cause Identified:**
  - Multi-tab architecture in `InstitutionDirectoryScreen` preventing unified masterlist search.
- **Solution Applied:**
  - Removed status tabs to create a unified masterlist directory.
  - Added an animated, collapsible `[= Filter]` panel with dual triggers (AppBar action + centered quick trigger bar).
- **Files Modified:**
  - `lib/screens/institution_directory_screen.dart`
- **Verification Status:** Verified unified layout and collapsible filter bar on mobile devices (PASSED).
