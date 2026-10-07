# Release Notes - HCP Profiling App V.0.2.5 (Build 7)

**Release Date:** September 15, 2026  
**Build Number:** 7  
**Target ERPNext Version:** v15  
**Version Increment:** Patch (+1 Patch)

---

## 🌟 Key Updates & Highlights

### 1. 🏥 Region Field Support Aligned with ERPNext DocType
- **Direct ERPNext Column Alignment**:
  - The ERPNext `Institution` table view displays columns: **`Region` | `Province` | `City/Municipality`**.
  - Previously, new institution proposals in the mobile app only submitted workplace, province, and city, leaving `region_name` unpopulated on ERPNext.
  - Added dedicated **Region** selector to both `Propose New Institution` and `Modify & Resubmit Facility` modal sheets.
- **Smart Bidirectional Auto-Resolution**:
  - Automatically resolves and populates Region based on the selected Province (e.g., Selecting *Cavite* auto-resolves *CALABARZON*, Selecting *Metro Manila-Manila* auto-resolves *NCR*, Selecting *Pampanga* auto-resolves *Region III (Central Luzon)*).
  - When a user selects a Region first, the Province picker prioritizes provinces situated within that specific region.
- **Strict 10-Digit PSGC Code Binding**:
  - Correctly maps and submits official 10-digit PSGC codes for `region_name` (e.g., `0400000000` for CALABARZON, `1300000000` for NCR) in both creation and resubmission payloads.
  - Cards on MedRep and SFE dashboards now display full location context: `[City], [Province], [Region]`.

### 2. 🔐 Verified Test Accounts & Step-by-Step Workflow Guide
- **MedRep Account**:
  - Email: `arlaneferraren8@gmail.com`
  - Password: `UEPCS101c!`
  - Role: `Sales User` / `Employee - COREnergy`
- **SFE Specialist Account**:
  - Email: `lesantos@pims-marketing.com`
  - Password: `UEPCS101c!`
  - Role: `Sales Force Effectiveness`

---

## 📦 Binaries
- [HCP_Profiling_V.0.2.5.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.5/HCP_Profiling_V.0.2.5.apk)
- [HCP_Profiling_Release.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

### 1. Missing Region Field Causing Discrepancy with ERPNext DocType
- **Problem Encountered:**
  - New facility proposals only submitted Province and City, leaving Region blank in ERPNext.
- **Root Cause Identified:**
  - Mobile proposal form lacked Region selection and mapping to ERPNext `Institution` schema.
- **Solution Applied:**
  - Added dedicated Region selector with bidirectional auto-resolution in `LocationResolver` (Province auto-selects Region; Region filters Provinces). Linked official 10-digit PSGC region codes.
- **Files Modified:**
  - `lib/screens/institution_approvals_screen.dart`
  - `lib/services/api_service.dart`
- **Verification Status:** Verified Region, Province, and City persist cleanly to ERPNext (PASSED).
