# HCP Profiling App - Release Notes V.0.6.9 (Build 41)
**Release Date**: October 8, 2026

---

## 🏥 Key Feature Highlights & Bug Fixes

### 1. Territory Reconfiguration Live Tree & Masterlist Synchronization Overhaul
- **Elimination of Premature LocalStorage Override**:
  - Identified and removed the 400ms `setTimeout(() => switchProgram(), 400)` race condition in `refreshLiveData()` that prematurely reloaded stale `programTerritories` and overwrote live data before ERPNext or Streamlit responses arrived.
  - Converted `refreshLiveData()` to a true async pipeline with interactive spinning button UI (`Syncing ERPNext...`), awaiting live fetch across all DocTypes.
- **Bi-Directional Streamlit & Desktop Synchronization**:
  - Wired `action: "tree_refresh"` to parent Streamlit container, fetching 4 live datasets in parallel via `ThreadPoolExecutor` (`live_territories`, `live_sales_persons`, `live_employees`, `live_users`).
  - Increased query limits to `limit_page_length=2000` to guarantee ingestion of all 180+ territory nodes across all organizational branches.
  - Auto-expanded root `'All Territories'` and active program branch (`territoryBranch`) in `treeExpandedNodes` so newly synced nodes render immediately upon sync completion.
  - Added support for `custom_account_or_program` attribute matching in `getProgramTerritoryNames` to seamlessly include program-tagged territories.

### 2. Sales Person Tree Creation & Child Table Schema Alignment (HTTP 417 Resolution)
- **ERPNext v15 Child Table Link Alignment**:
  - Registered missing `Monthly Distribution` master record **`Evenly Distributed`** for Fiscal Year 2026 (100% allocation across 12 months) on `dev.pmii-marketing.com`.
  - Registered missing healthcare `Item Group` categories (`Pharmaceuticals`, `Consumables`, `Diagnostic Equipment`, `Medical Devices`, `Oral Hypoglycemics`, `Insulin Delivery`, `Nutritional Supplements`, `Products`).
  - Removed unsupported `user_id` attribute from the `Sales Person` DocType payload to comply with Frappe schema constraints.
- **Multi-Stage Gateway & Client Resilience**:
  - Implemented 3-stage fallback recovery in `app.py` and `territory_reconfiguration_portal.html`:
    - **Stage 1**: Omit target child rows if linked distributions fail.
    - **Stage 2**: Reassign parent to `'Sales Team'` if parent node validation fails.
    - **Stage 3**: Unlink employee if employee link validation fails.
  - Immediate cascade refresh of `availableSalesPersons` upon creation to update dropdowns and hierarchy trees instantly.

---

## 📦 Release Artifacts
- **Android Release APK**: `releases/HCP_Profiling_Release.apk` (58.94 MB)
- **Legacy Version APK**: `releases/legacy_versions/V.0.6.9/HCP_Profiling_V.0.6.9.apk`
- **Territory Portal Windows Installer**: `releases/Territory_Reconfiguration_Setup.exe`
- **Territory Portal Zip Package**: `releases/Territory_Reconfiguration_Setup.zip`
- **Metadata Spec**: `releases/legacy_versions/V.0.6.9/metadata.json`
