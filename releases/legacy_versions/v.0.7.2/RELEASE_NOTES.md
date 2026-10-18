# Release Notes - Territory Reconfiguration Portal & HCP Mobile Suite v.0.7.2 (Build 47)

**Release Date:** October 18, 2026  
**Binary Packages & Portals:**
- Android Release APK: [`HCP_Profiling_V.0.7.2.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/legacy_versions/v.0.7.2/HCP_Profiling_V.0.7.2.apk)
- Root Production APK: [`HCP_Profiling_Release.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)
- Territory Setup EXE: [`Territory_Reconfiguration_Setup.exe`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/Territory_Reconfiguration_Setup.exe)
- Territory Setup ZIP: [`Territory_Reconfiguration_Setup.zip`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/Territory_Reconfiguration_Setup.zip)
- Web Portal Production: [`territory_reconfiguration_portal.html`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/docs/territory_reconfiguration_portal.html)

---

## 🌟 Executive Summary

Version **v.0.7.2** implements an extensive alignment and security hardening release for the **Territory Reconfiguration Web Portal** and backend architecture:

1. **Table Grid View Refinements**:
   - Stripped the redundant territory code prefix (`AD0101 - `) from the Assigned MedRep column; now displays clean representative names.
   - Replaced development state labels (`UNCHANGED`/`CHANGED`) in the Status column with operational status badges: **`Active`** (emerald), **`Inactive`** (slate), or **`Vacant`** (amber).
   - Added an **`Area / District`** column displaying the coverage tag (`GMA/NLZ`, `GMA/SLZ`, etc.) and parent district with Column Visibility toggle (`colToggle_area`) and Filter By support.

2. **Zero-Deletion Standard & Active / Inactive Operational Toggles in Territory Tree**:
   - Completely pruned the `Delete` option across the Territory Tree and web app (in strict adherence to the zero-deletion rule).
   - Streamlined tree node action buttons to strictly: **`(Edit, Transfer Doctor, Rename, Active/Inactive)`**.
   - Tapping the **`Active`** / **`Inactive`** operational toggle smoothly changes territory status without deleting data.

3. **Tree Node Alignment & Area Tag Precision**:
   - Standardized territory leaf node display alignment: `${territoryCode} (${areaDistrictTag}) - ${medRepName}` (e.g. `AD0106 (GMA/NLZ) - JONEL APSAY`).
   - Integrated extensible `TERRITORY_AREA_MAPPINGS` dictionary and automatic district tag resolution (`resolveTerritoryArea`) ready for the full area code file.

4. **Program Dropdown Filtering in Territory Tree**:
   - Filtered Territory Tree root hierarchy by the active selected program: selecting `Abbott Diabetes Care` exclusively displays Abbott branches, hiding other programs (`Bayer`, `RiteMed`, `Vivaro`) from view.

5. **Header Controls Streamlining**:
   - Removed the redundant `[Refresh Live Sync]` button; Territory Tree operates as the live, authoritative interactive reconfiguration canvas.

6. **Doctor Count Modal Humanization & Area Tagging**:
   - Replaced verbose/inappropriate explanations with clean, professional statements for zero doctors and search queries.
   - Included the MedRep's **Area Code / District** directly in the modal header and subheader.

7. **Doctor Transfer Modal Upgrades**:
   - Added a 3-way status button toggle: **`Active (Working)`**, **`Inactive (Resigned)`**, and **`Vacant`**.
   - Fixed Move Selected buttons to ensure all 3 transfer action buttons are permanently active, vibrant, and never grayed out.
   - Replaced single-line audit input with a spacious multiline `<textarea>` for free typing of comprehensive transfer notes.

8. **Authentication Security Intrusion Mitigation & Network Resilience**:
   - Implemented `SecurityIntrusionGuard` (client and server-side) with regex-based SQL injection, script injection, and command injection pattern detection.
   - Automated intrusion blocking, 15-minute progressive freeze, and 5-attempt rate-limiting safeguards.
   - Extended network timeout to 15-25s with 2-stage gentle retry for field users on slow/unstable mobile networks.

---

## 🧪 Verification & Quality Assurance
- **Static Analysis**: `flutter analyze` verified with **0 errors and 0 warnings**.
- **Automated Test Suite**: `flutter test test/inst_profiling_test.dart` passed all **18/18** test suites.
- **Asset Parity**: Zero-drift byte-for-byte SHA-256 parity validated across all web portal mirrors (`d17f87bbe9315650...`).
- **Packaging Integrity**: Standalone EXE, portable ZIP, root release APK, and legacy version archives successfully generated.
