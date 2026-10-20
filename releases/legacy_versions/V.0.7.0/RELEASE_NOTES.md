# Release Notes - HCP Profiling App v.0.7.0 (Build 48)

**Release Date:** October 19, 2026  
**Build Number:** 48  
**Binary Packages:**
- Android Release APK: [`HCP_Profiling_V.0.7.0.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/legacy_versions/V.0.7.0/HCP_Profiling_V.0.7.0.apk)
- Root Production APK: [`HCP_Profiling_Release.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)
- Territory Setup EXE: [`Territory_Reconfiguration_Setup.exe`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/Territory_Reconfiguration_Setup.exe)
- Territory Setup ZIP: [`Territory_Reconfiguration_Setup.zip`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/Territory_Reconfiguration_Setup.zip)
- Web Portal Production: [`territory_reconfiguration_portal.html`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/docs/territory_reconfiguration_portal.html)

---

## 🌟 Executive Summary

Version **v.0.7.0** represents the definitive consolidated production release of the **HCP Profiling Mobile App** and **Territory Reconfiguration Web Suite**, incorporating:

1. **Live ERPNext HCP Synchronization & Zero-Data Accuracy**:
   - Eliminated the stale cache masking bug where `fetchDoctors()` previously served old cached doctors when ERPNext had 0 records.
   - All network tiers now treat `HTTP 200 OK` as authoritative and synchronize in real-time with ERPNext, reserving local cache fallback exclusively for actual network outages.
2. **Conditional MedRep Institution Accuracy Certification**:
   - The certification checkbox only appears when an encoded institution is strictly unique with zero duplicate/similarity candidates in the master directory (`_detectedMatches.isEmpty`).
   - Automatically records certification note to ERPNext DocType (`certification_note`, `is_certified: 1`) and logs Frappe audit Comments for seamless `.xlsx` exports.
3. **Sequential Step Progression & Form Security Guardrails**:
   - Step 2 requires Step 1 completion (consent + signature/photo); Step 3 and Changes tabs require Step 2 completion.
   - Replaced raw monospace JSON with a human-centric Executive Change Summary card.
   - Upgraded Cancel Doctor action into an elevated interactive button (`_isStep2Complete()`) guarded by confirmation dialogs.
4. **Dynamic Multi-Program Corporate Consent Formulation**:
   - Adapts consent agreements, purpose clauses, and privacy notices dynamically to the active logged-in program (e.g. `PMII Abbott Diabetic Care (ADC)`, `PMII Bayer`, `PMI Fonterra`, `PMII Galderma`).
5. **Gemini 4 Argon Intelligent Doctor Recognizer & Workplace Search**:
   - Real-time recognizer across First, Middle, and Last Name fields with 180ms debounce and 1-click auto-fill pop-up window.
   - Progressive phrase shrinking on institution search prunes unrelated facilities and prevents false-positive Levenshtein drift.
6. **Territory Reconfiguration Web Portal Enterprise Hardening**:
   - Zero-deletion standard with Active/Inactive operational toggles.
   - Area/District column, clean representative display, program dropdown isolation, and `SecurityIntrusionGuard` (SQLi, XSS, and command injection defense).

---

## 🚀 Detailed Features & Enhancements

### 1. Live ERPNext HCP DocType Synchronization & Cache Resilience
- **Authoritative Network Synchronization**:
  - Resolved an issue in `fetchDoctors()`, `fetchHcpAccounts()`, and `fetchSubmissions()` where empty dataset responses (`{"data": []}`) were conflated with network failures due to `if (dataList.isNotEmpty)`.
  - Every network tier now treats an `HTTP 200 OK` response from ERPNext as authoritative, immediately updating in-memory cache and overwriting local disk cache (`doctors_cache.json`, `hcp_accounts_cache.json`, `submissions_cache.json`) with the live record set.
  - Offline cache fallback is strictly gated to execute only when live network requests genuinely fail (timeout, DNS failure, 5xx server errors, or true offline mode).

### 2. MedRep Institution Certification & ERPNext DocType XLSX Export Reflection
- **Conditional Visibility for Certification Checkbox**:
  - The certification checkbox (*"This certifies that this institution which is not in the directory is accurate and active for coverage"*) now **only displays below the search field** when the encoded institution name is verified to be **strictly unique** with **zero duplicates or similarities** in the directory (`_detectedMatches.isEmpty`).
  - If matching suggestions, similar names, or duplicates are detected, or while the representative is actively typing, the certification checkbox remains completely hidden to prevent premature or duplicate submissions.
  - Added an instant search loading indicator in the search bar and automatic debounce state protection (`_isSearching`) to eliminate UI flashing.
- **DocType Note Recording & Seamless ERPNext XLSX Export**:
  - Recorded MedRep certification note directly on the ERPNext DocType (`certification_note`, `is_certified: 1`, and `remarks`):
    `"Certified by MedRep: Institution is accurate and active for coverage"`.
  - Added Frappe Comment audit logging via `/api/resource/Comment` on the `Institution` doc upon submission.
  - Updated `approvalStatusNote` and `LocationResolver.getInstitutionApprovalStatusNote`:
    Unapproved certified facilities dynamically display:
    `"this institution is not yet approved (Certified accurate and active for coverage)"`.
    Approved facilities transition to:
    `"this institution is now approved"`.
  - When administrators export `.xlsx` files from ERPNext Desk for `Institution`, `HCP Account` (`workplace_approval_note`), or `HCP Profile Submission`, this check note is clearly visible in the export.

### 3. Enterprise Form Security, Dynamic Multi-Program Consent & Progression Guardrails
- **Doctor Search Redundancy Elimination**:
  - Removed the redundant "+ Add as New Doctor" button from inside the doctor search modal (`_showHcpSelectorModal()`).
  - Search HCP strictly queries and selects existing doctors from the universal HCP masterlist; new doctor registrations are exclusively initiated through the dedicated "+ Add New Doctor" card in Step 2.
- **Dynamic Multi-Program Corporate Consent System**:
  - Step 1 consent agreement clause and privacy notices dynamically adapt based on the active logged-in program (e.g. `PMII Abbott Diabetic Care (ADC)`, `PMII Bayer`, `PMI Fonterra`, `PMII Galderma`, etc.), replacing static generic references with authentic corporate identity clauses.
- **Guarded & Interactive Cancel Doctor Action**:
  - Upgraded the inline text link into a prominent, outlined interactive button with icon (`Icons.close_rounded`) and confirmation alert dialog (`_confirmResetDoctor`).
  - Button visibility is cleanly guarded: it only appears when all mandatory fields of Step 2 (First Name, Last Name, Specialization, Workplace, Workplace Type, Practice) are completely fulfilled, avoiding screen clutter.
- **Step Progression & Tab Security Guardrails**:
  - Sequential unlocking enforced: Step 2 requires Step 1 completion (consent + signature/photo); Step 3 and Changes tabs require Step 2 completion.
  - Tapping locked tabs displays feedback SnackBars detailing the missing prerequisite.
- **Human-Centric Changes Summary Card**:
  - Eliminated the developer-style raw JSON monospace terminal card.
  - Implemented an executive, structured summary card grouping Basic Information changes, Specializations, Workplaces, Contact Channels, Survey Detailing, and Submission Audit Metadata.
- **Context-Specific Action Labels & Styling**:
  - Renamed generic "Add Row" buttons to descriptive action labels: `+ Add Specialization`, `+ Add Institution`, and `+ Add Contact/Email`.
  - Mandatory disclaimer `* indicates information that are mandatory` styled in crisp red (`#DC2626`).
  - First, Middle, and Last Name labels use `Text.rich` displaying neutral slate text with a red asterisk `*` without red input borders.
  - Removed `(Optional)` tag and helper text from Birth Date.

### 4. Gemini 4 Argon-Grade Smart HCP Recognizer & Progressive Phrase Shrinking
- **Institution / Workplace Progressive Phrase Shrinking**:
  - Dynamic multi-token shrinking algorithm in `LocationResolver.fuzzySearchInstitutions` and `searchDirectoryWithDuplicateDetection` starts with broad potential matches and dynamically narrows to strictly co-related facilities and direct branches as the user completes the full phrase.
  - Prunes unrelated facilities sharing only generic words (e.g. "hospital", "clinic", "center"), preventing false-positive Levenshtein drift.
  - Added live Smart Detector Phrase Bar with dynamic shrinking match count pill.
- **Step 2 Real-Time Doctor Name Recognizer**:
  - Real-time recognizer across First, Middle, and Last Name fields scanning universal `HCP` doctype masterlist (`_allDoctors`) with 180ms debounce.
  - Interactive field recognizer badge (`Icons.auto_awesome_rounded`) displays live match count pills.
  - Interactive "Person available in HCP" window pop-up below name fields with 1-click auto-fill, auto-populating full names, photo avatars, birth dates, specialty affiliations, workplaces, and contact channels.
  - Selecting an existing doctor merges automatically without managerial approval; continuing as new preserves full approval workflow.

### 5. Territory Reconfiguration Web Portal & Enterprise Resilience
- **Dedicated Web App Versioning (`v.0.1.0`)**:
  - Separated the Territory Reconfiguration Web Portal version tracking from the mobile HCP app, branding the web portal as **`v.0.1.0`**.
- **Table Grid View Refinements**:
  - Cleaned up Assigned MedRep column by removing redundant territory code prefixes (`AD0101 - `).
  - Replaced development state labels with operational status badges: **`Active`** (emerald), **`Inactive`** (slate), or **`Vacant`** (amber).
  - Added **`Area / District`** column displaying coverage tag (`GMA/NLZ`, `GMA/SLZ`, etc.) and parent district with Column Visibility toggle (`colToggle_area`) and Filter By support.
- **Zero-Deletion Standard & Active / Inactive Operational Toggles**:
  - Completely pruned `Delete` action across Territory Tree and web app (strict zero-deletion policy).
  - Streamlined tree node action buttons strictly to: **`(Edit, Transfer Doctor, Rename, Active/Inactive)`**.
  - Added **`Tag Inactive / Vacant`** action with confirmation modal: decommissions resigned reps, preserves territory codes in ERPNext as Vacant for future cycles, and ensures zero doctor data loss.
- **Tree Node Alignment & Area Tag Precision**:
  - Standardized territory leaf node display: `${territoryCode} (${areaDistrictTag}) - ${medRepName}` (e.g. `AD0106 (GMA/NLZ) - JONEL APSAY`).
  - Added extensible `TERRITORY_AREA_MAPPINGS` dictionary and automatic district tag resolution (`resolveTerritoryArea`).
- **Program Dropdown Filtering in Territory Tree**:
  - Territory Tree root hierarchy strictly isolates branches by active selected program (`Abbott Diabetes Care`, `Bayer`, `RiteMed`, `Vivaro`).
- **Doctor Count Modal & Transfer Modal Upgrades**:
  - Clean, professional messaging for zero doctors and search queries; displays MedRep area code and district in header.
  - 3-way status button toggle: **`Active (Working)`**, **`Inactive (Resigned)`**, and **`Vacant`**.
  - Vibrant blue transfer action buttons with spacious multiline `<textarea>` for comprehensive transfer notes.
- **Authentication Security Intrusion Mitigation & Network Resilience**:
  - Implemented `SecurityIntrusionGuard` (client and server-side) with regex-based SQL injection, script injection, and command injection pattern detection.
  - Automated intrusion blocking, 15-minute progressive freeze, and 5-attempt rate-limiting safeguards.
  - Enforced an explicit, secure Login screen upon all redeployments and fresh browser sessions to eliminate unauthorized account exposure.
  - Extended network timeout to 15-25s with 2-stage gentle retry for field users on slow/unstable mobile networks.

---

## 🔒 Verification & Compliance

- **Full Automated Test Coverage**: 73/73 tests passing (`test/inst_profiling_test.dart`).
- **Static Analysis**: 0 compiler errors and 0 warnings (`flutter analyze --no-fatal-infos`).
- **Asset Parity**: 100% byte-for-byte SHA-256 parity validated across all web portal mirrors.
- **Technical Debt Audit**: Grade A+ (5/5 invariants passed).
- **Packaging Integrity**: Standalone EXE, portable ZIP, and root release APK verified.
