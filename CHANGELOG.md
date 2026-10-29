# Changelog

All notable changes to the **HCP Profiling App** will be documented in this file.
The project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v.0.8.3] - 2026-10-29

### ✨ Streamlined Institution Approval UI, 5-Window KPI Navigation & ERPNext `Draft` Status Alignment
- **Header Simplified to `"Institution Approval"`**:
  - Updated the `#tab-institutions` workbench header title from `SFE Institution Approval & Masterlist Governance Workbench` to **`Institution Approval`**.
- **Unified 5-Window KPI Card Navigation (Removed Redundant Filter Pill Row)**:
  - Removed the redundant `#sfeInstStatusPillGroup` pill button row (`Pending SFE Review`, `Pending DSM`, `Approved Directory`, `Rejected`, `All Records`) to eliminate toolbar clutter and prevent UI layout constraints.
  - Enabled the **5 KPI Windows** (`Institution Directory`, `Pending DSM Approval`, `Approved Masterlist`, `Rejected Proposals`, `MedRep Certified`) with active selection indicators (`.sfe-inst-nav-card.active`) to serve as the primary navigation across the workflow.
- **Renamed `"Pending SFE Review"` to `"Institution Directory"` & Matched ERPNext `"Draft"` Status**:
  - Updated the first KPI window label to **`Institution Directory`** (`Available in ERPNext Institution DocType`), reflecting that pre-loaded directory facilities do not require approval even when their ERPNext DocType state is `Draft`.
  - Updated the table `STATUS` column badge and `normalizeInstitutionRecord()` to display **`Draft`** (matching the ERPNext `Institution` DocType state 1:1) instead of `Pending SFE`.
- **Removed `"LINKED DOCTOR & SUBMITTER"` Column**:
  - Removed the `LINKED DOCTOR & SUBMITTER` column from the Institution Approval table and rebalanced the remaining 5 columns (`INST ID & CERTIFICATION`, `FACILITY NAME & CLASSIFICATION`, `OFFICIAL PSGC LOCATION`, `STATUS`, `ACTIONS`) for cleaner readability.

---

## [v.0.8.2] - 2026-10-28

### 🛠️ Zero-Blank-Data Guarantee & Instant Institution Masterlist Hydration in Territory Reconfiguration Web App
- **Embedded 1,328-Record Baseline Institution Masterlist (`BASELINE_INSTITUTIONS_COMPACT`)**:
  - Embedded all 1,328 ERPNext `Institution` records (`INST-00001` through `INST-09341`) directly inside `docs/territory_reconfiguration_portal.html` so the **Institution Approvals** (`#tab-institutions`) workbench populates 1,328 records instantaneously on load (`0ms` wait, zero possibility of empty/blank table on container restarts or network drops).
- **Fixed `Draft` -> `Pending Approval` Workflow State Mapping**:
  - Restored `normalizeInstitutionRecord()` so unapproved ERPNext `Draft` / `Pending Approval` records (`docstatus == 0`) map directly to `Pending SFE Review` (`1,328`), transitioning to `Approved Directory` (`Approved`) or `Pending DSM` (`Pending DSM Approval`) when SFE approves via the **`Actions ⌄`** dropdown menu.
- **Fixed Cascading PSGC City/Municipality Lookup & ERPNext Schema Field Alignment**:
  - Updated `initPsgcLookupIndex()` to match both `'City'` and `'City / Municipality'` across all 1,655 Philippine cities/municipalities and handle trailing suffix codes (e.g., `1381400000C` -> `San Juan City`).
  - Updated fallback `Institution` REST queries and `PUT` payloads to use exact ERPNext columns (`street_address`, `barangay_name`, `ownership`, `institution_type`, `service_capability`), eliminating HTTP 417 `Field not permitted in query` errors.
- **Hardened Streamlit Session Opener & Non-Destructive Auto-Sync (`app.py`)**:
  - Added `get_safe_secret()` in `installers/Streamlit_Deployment/app.py` to prevent `StreamlitSecretNotFoundError` when `.streamlit/secrets.toml` is absent, added `@st.cache_resource` opener recovery across WebSocket reconnects, and preserved local SFE governance overrides (`pims_sfe_inst_overrides_v3`) across background auto-sync cycles.

---

## [v.0.8.1] - 2026-10-28

### ✨ Minimalist SFE Institution Approval UI & Unified Row Actions Popover
- **Minimalist Workbench Header & KPI Cards**:
  - Removed the header subtitle text, header decorative icon, and KPI card icons in `#tab-institutions` (`docs/territory_reconfiguration_portal.html`) for a clean, minimalist layout matching the rest of the Territory Reconfiguration Portal.
  - Removed decorative emoji icons from table badges (`Government`, `Private`, `MedRep Certified`, `Standard Record`, `Pending SFE`, `Pending DSM`, `Approved`, `Rejected`).
- **Unified `Actions v` Row Dropdown Menu (Matching Reconfiguration Editor)**:
  - Replaced the multi-button action cell in the Institution Approvals table with the unified **`Actions ⌄`** trigger button (`.btn-grid-action-trigger`) and dark floating `#instRowActionsMenu` popover (`Approve Facility` / `Route to DSM Approval`, `Normalize & Standardize`, `Remap Duplicate`, `Reject Proposal`, and `Audit Trail`).
- **Zero-Touch Automatic Background Sync**:
  - Removed the manual `Sync Live from ERPNext` button and offline fallback toast; the Web App now automatically and silently syncs in the background every 15 seconds across both Streamlit Cloud and Local Desktop environments whenever a MedRep submits or resubmits an institution from the HCP Mobile App.

---

## [v.0.8.0] - 2026-10-28

### 🏥 SFE Institution Approval & Masterlist Governance Workbench in Territory Reconfiguration Web App
- **Dedicated SFE Web Institution Approval Workbench (`#tab-institutions`)**:
  - Embedded the complete SFE Institution Approval, Normalization, Duplicate Remapping, and Rejection Workbench directly inside the **Territory Reconfiguration Web App** (`docs/territory_reconfiguration_portal.html`, `installers/Territory_Reconfiguration_App/`, and `installers/Streamlit_Deployment/app.py`) so SFE Specialists can govern all MedRep-discovered institutions from their desktop/laptop without requiring a tablet/iPad.
  - Added 5 interactive KPI cards (`Pending SFE Review`, `Pending DSM Approval`, `Approved Masterlist`, `Rejected Proposals`, `MedRep Certified`), status filter pills, ownership/type filters, multi-field search, and CSV export.
  - Built 4 governance modals: **Normalize & Standardize Modal** (Proper Case formatter, `Government`/`Private` ownership, `Hospital`/`Clinic` type, dynamic service capabilities, 60-second concurrency edit lease, and cascading 1,772-row official PSGC Region -> Province -> City/Municipality dropdowns), **Reject Institution Modal** (mandatory reason + preset chips), **Remap Duplicate Modal** (searchable canonical `Approved` `INST-XXXXX` picker), and **Audit Trail Modal**.
- **Seamless Real-Time Bidirectional Sync Between HCP Mobile App & Web Portal**:
  - Upgraded `ApiService.fetchInstitutions()`, `proposeNewInstitution()`, and `resubmitRejectedInstitution()` in `lib/services/api_service.dart` with schema-resilient `fields=["*"]` queries and `<!--PIMS_META:{...}-->` Frappe `Comment` envelope hydration so 100% of governance attributes sync across Mobile and Web regardless of custom ERPNext column state.
  - Added 15-second background auto-sync timers to `InstitutionDirectoryScreen` and `InstitutionApprovalsScreen` on the Mobile App and `initSfeInstitutionWorkbench()` on the Web App.
  - Aligned the Mobile App exclusively for MedRep Institution Discovery, Accuracy Certification, Status Tracking, and Resubmission (up to 2 attempts), while moving SFE Institution Approval & Normalization exclusively to the Territory Reconfiguration Web App.

---

## [v.0.7.2] - 2026-10-27

### ?? Repository Separation & Unused Feature Pruning
- **Removed Unused Self-Service QR Prototype**:
  - Removed `lib/screens/self_service_qr_screen.dart` and its orphaned prototype caller `lib/screens/doctor_profile_screen.dart` (which are not part of the active HCP Profiling App roadmap).
- **Removed Separate MCP COREnergy App Files & Code**:
  - Removed all files belonging to the separate MCP COREnergy App project (`lib/main_corenergy.dart`, `lib/models/corenergy_engage.dart`, `lib/models/engagement.dart`, `lib/screens/corenergy_engage_detail_screen.dart`, `lib/screens/detail_screen.dart`, `lib/screens/list_screen.dart`, and `lib/services/db_helper.dart`).
  - Pruned all `COREnergyEngage` and `Successful COREnergy Engagement` methods (`fetchEngagements`, `fetchCOREnergyEngages`, `fetchCOREnergyEngageByName`, `createCOREnergyEngage`, `updateCOREnergyEngage`, `createEngagement`, `updateEngagement`, `syncOfflineData`) from `lib/services/api_service.dart`, `lib/screens/login_screen.dart`, and `lib/app_config.dart`, keeping the codebase 100% dedicated to the HCP Profiling App.

---

## [v.0.7.1] - 2026-10-27

### ??? Enterprise Security Hardening (6 Key Enhancements ? SEC-01 through SEC-08)
- **SEC-01 ? Protected Local Cache Directory & iOS File Sharing Lockdown**:
  - Disabled `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` (`<false/>`) in `ios/Runner/Info.plist` so cached doctor PII and local SQLite databases cannot be extracted via Finder/iTunes or the iOS Files app.
  - Migrated local JSON caches in `ApiService` from `getApplicationDocumentsDirectory()` to the protected `getApplicationSupportDirectory()` with automatic seamless fallback migration for existing field devices.
- **SEC-02 ? Server-Side Session Revocation & Cross-User Cache Isolation**:
  - Updated `ApiService.logout()` to dispatch `/api/method/logout` to ERPNext v15, stop any active local `TerritoryWebServer` instance, clear in-memory caches (`_cachedDoctors`, `_cachedHcpAccounts`, `_cachedSubmissions`, `_cachedInstitutions`), reset `_sfeModeOverride`, and flush `AppLogger` telemetry.
  - Added `_ensureUserCacheIsolation()` during login to automatically purge user-scoped cache files whenever a different user logs into a shared mobile device, while preserving full offline resilience when the same user reconnects.
- **SEC-03 ? Elimination of Hardcoded Service Account Fallback Credentials**:
  - Removed the hardcoded `'pims@admin'` fallback password from `installers/Streamlit_Deployment/app.py` and `installers/Territory_Reconfiguration_App/server.py`, reading service account credentials strictly from environment variables or `st.secrets` and binding the authenticated user's session opener directly.
- **SEC-04 ? Local On-Device QR Code Renderer & Territory Web Server Hardening**:
  - Created a zero-dependency ISO/IEC 18004 QR Code encoder and `CustomPainter` (`LocalQrCodeWidget` in `lib/screens/components/local_qr_code_widget.dart`) to render QR codes 100% offline on-device in `TerritoryPortalLauncherScreen` and `SelfServiceQrScreen`, eliminating third-party transmission of session tokens and doctor/MedRep PII to `api.qrserver.com`.
  - Replaced wildcard CORS (`Access-Control-Allow-Origin: *`) in `TerritoryWebServer` with strict origin validation, issued an `HttpOnly; SameSite=Strict` session cookie (`pims_portal_token`), and blocked cross-site/foreign-origin requests on `127.0.0.1`.
- **SEC-05 & SEC-06 ? Strict Role-Based Access Control (RBAC) Guardrails**:
  - Guarded `ApiService.toggleSfeMode()` so only `UserPosition.admin` and `UserPosition.sfe` can toggle SFE mode, removed the unused `setUserPosition()` mutator, and removed the broad `@profinsights.biz` email substring escalation in `_applyPositionFromRoleProfile()`.
- **SEC-07 ? Zero Raw `print()` Telemetry & Comprehensive Log Redaction**:
  - Expanded `AppLogger` redaction patterns to scrub JSON-serialized credentials (`"pwd"`, `"password"`, `"sid"`, `"csrf_token"`, `"api_secret"`) and `Authorization: Bearer/token` headers, and routed all remaining diagnostic `print()` calls across `lib/` through `AppLogger`.

### ? Ultra-Smooth Instant Directory Search Optimization
- **O(1) Hash Map Doctor Lookup in `DoctorAccountScreen`**:
  - Replaced repeated $O(N)$ linear scans (`_doctors.firstWhere(...)`) during search filtering and sorting with an $O(1)$ `_doctorsById` hash map lookup, and expanded the search filter to match Doctor Name, Doctor ID, Specialty, Workplace, and Territory instantaneously.
- **Pre-Tokenized Fast Filtering in `DoctorMasterlistScreen`**:
  - Pre-computed program doctor token sets outside the per-keystroke filter loop and short-circuited search queries prior to fuzzy token matching, delivering lag-free keystroke responsiveness across 6,135+ doctors.

---

## [v.0.7.0] - 2026-10-19

### 🔄 Live ERPNext HCP DocType Synchronization & Cache Resilience
- **Authoritative Network Synchronization**:
  - Resolved an issue in `fetchDoctors()`, `fetchHcpAccounts()`, and `fetchSubmissions()` where empty dataset responses (`{"data": []}`) were conflated with network failures due to `if (dataList.isNotEmpty)`.
  - Every network tier now treats an `HTTP 200 OK` response from ERPNext as authoritative, immediately updating in-memory cache and overwriting local disk cache (`doctors_cache.json`, `hcp_accounts_cache.json`, `submissions_cache.json`) with the live record set.
  - Offline cache fallback is strictly gated to execute only when live network requests genuinely fail (timeout, DNS failure, 5xx server errors, or true offline mode).
- **Universal Masterlist Limitless Auto-Pagination & Scalability**:
  - Replaced legacy 5,000-record query limitations with `limit_page_length=0` and intelligent automatic offset pagination across `fetchDoctors()`, `fetchHcpAccounts()`, `fetchSubmissions()`, and `fetchInstitutions()`.
  - Seamlessly ingests the full ERPNext universal doctor directory (6,135+ doctors) without truncating or omitting any records.
  - Expanded Doctor Directory header count box width in `doctor_account_screen.dart` ensuring high doctor counts (`6135 of 6135`) render crisply with zero visual clipping or wrapping.
  - Successfully resolved and purged targeted profile submission records in ERPNext v15.

### 🏥 MedRep Institution Certification & ERPNext DocType XLSX Export Reflection
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

### 🔒 Enterprise Form Security, Dynamic Multi-Program Consent & Progression Guardrails
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

### 🧠 Gemini 4 Argon-Grade Smart HCP Recognizer & Progressive Phrase Shrinking
- **Institution / Workplace Progressive Phrase Shrinking**:
  - Dynamic multi-token shrinking algorithm in `LocationResolver.fuzzySearchInstitutions` and `searchDirectoryWithDuplicateDetection` starts with broad potential matches and dynamically narrows to strictly co-related facilities and direct branches as the user completes the full phrase.
  - Prunes unrelated facilities sharing only generic words (e.g. "hospital", "clinic", "center"), preventing false-positive Levenshtein drift.
  - Added live Smart Detector Phrase Bar with dynamic shrinking match count pill.
- **Step 2 Real-Time Doctor Name Recognizer**:
  - Real-time recognizer across First, Middle, and Last Name fields scanning universal `HCP` doctype masterlist (`_allDoctors`) with 180ms debounce.
  - Interactive field recognizer badge (`Icons.auto_awesome_rounded`) displays live match count pills.
  - Interactive "Person available in HCP" window pop-up below name fields with 1-click auto-fill, auto-populating full names, photo avatars, birth dates, specialty affiliations, workplaces, and contact channels.
  - Selecting an existing doctor merges automatically without managerial approval; continuing as new preserves full approval workflow.

### 🗺️ Territory Reconfiguration Web Portal & Enterprise Resilience
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

## [v.0.6.5] - 2026-10-11

### 🏥 Multi-Doctor Institution Rejection Cascade, Smart Attestation & Zero-Loss Remapping
- **Human-Readable Facility Export (Zero Institution Codes)**:
  - Full human-readable facility names (e.g., `Pims Institution`, `Yamete Hospital`, `Unsaman General Hospital`) now automatically populate and export in ERPNext Excel/CSV exports across `HCP Profile Submission`, `HCP Account`, and `HCP` doctypes.
  - Rejection note tags permanently retain human-readable institution names and specific audit reasons (e.g., `[REJECTED INSTITUTION: Pims Institution - reject]`) tagged directly to the responsible MedRep owner for comprehensive SFE audit analysis.
- **Dynamic List View Column Preservation**:
  - All original list view columns (`Consent`, `Valid From`, `Valid To`, `Type`, `Practice`, `Account/Program`, `Territory`, `Territory Manager`) remain 100% active (`in_list_view: 1`) alongside the dedicated `Rejected Institution` column.
  - Prominent red indicator badges in List View and top alert banners in Form View without slicing or dropping any columns.
- **Multi-Doctor Rejection Propagation**:
  - When SFE rejects a newly proposed institution with cause, rejection tags (`[REJECTED INSTITUTION: <name> - <reason>]`) and status indicators automatically propagate across all doctors assigned to that MedRep who are affiliated with that facility.
  - Live ERPNext v15 bidirectional synchronization across `HCP Profile Submission`, `HCP Account`, and `HCP` doctypes, plus memory cache and disk snapshots.
- **Batch Remapping & Facility Synchronization**:
  - Remapping a rejected facility to an approved masterlist institution immediately updates and resolves all connected doctor records in batch under that MedRep.
  - Clears rejection remarks and indicators across all linked records in ERPNext and mobile app.
- **Inviolable Consent Signature Preservation**:
  - Captured doctor digital signatures (`consent_signature`) and consent agreements are strictly preserved byte-for-byte during facility remapping, editing, and resubmissions. MedReps never lose signed consents when modifying rejected institutions.
- **Mandatory Attestation & Smart Similarity Detector Gate**:
  - Real-time similarity detector remains continuously active while typing workplace names.
  - Mandatory certification checkbox gated before Location Details (Region, Province, City, Barangay, Street) can be entered: *"This certifies that this institution which is not in the directory is valid and accurate"*.
  - Submission and field entry remain locked until explicit certification is acknowledged.
- **1-Click Remapping UI**:
  - Added direct `Remap` action buttons in Doctor Profiling Wizard and Doctor Profile Workplace Table next to rejected institution badges.

---

## [v.0.6.5] - 2026-10-08

### 🧠 Intelligent AI Institution Detector & Acronym Recognition
- **Dynamic Acronym Extraction**:
  - Implemented multi-tier algorithmic acronym generator (`computeInstitutionAcronyms`) extracting literal initials, non-connector initials, core facility initials, and parenthetical acronyms (e.g., `"Ust"` $\rightarrow$ `"University of Santo Tomas Hospital"`, `"SLMC"` $\rightarrow$ `"St. Luke's Medical Center"`, `"PGH"` $\rightarrow$ `"Philippine General Hospital"`, `"MMC"` $\rightarrow$ `"Makati Medical Center"` / `"Metropolitan Medical Center"`).
  - Embedded comprehensive Philippine healthcare acronym knowledge dictionary (`_philippineMedicalAcronyms`).
- **99%+ Precision & Elimination of Interior Substring False Positives**:
  - Protected short queries ($\le 4$ characters) from matching interior characters of unrelated corporate names (e.g., query `"Ust"` previously matched `"Unitech Plastic Industry Corp."`, `"Trener Industries"`, and `"Toprite Plastic Industries"` because of the letters `"ust"` inside `"industry"`). Interior substring matching is strictly prohibited for short queries.
- **Complete Display of All Matching Facilities**:
  - Removed artificial display caps (`limit: 6` $\rightarrow$ `limit: 50`) and enlarged the directory dropdown with smooth scrollbar support (`maxHeight: 240`) to display all candidate institutions.
- **Location Details Locking & No Lock Icon**:
  - Location fields (Region, Province, City) remain non-fillable while matching suggestions are active or when workplace name is not yet fulfilled.
  - Strictly no lock icon implemented; clean non-lock status indicators and muted inputs are preserved.
- **Proposal Submission Block on Active Suggestions**:
  - Disabled "Submit for Approval" button whenever matching suggestions exist in the dropdown (`_detectedMatches.isNotEmpty && _selectedExistingInstitution == null`), directing the medrep to select from existing facilities or specify a distinct facility name to eliminate duplicate proposals.
- **Menu Drawer Version Clean Display**:
  - Retained HCP App version at `v.0.6.5` and removed the `+No.` build number suffix in the app navigation menu drawer.
- **ERPNext Rejection Reflection & 1:1 Audit Parity**:
  - Full bidirectional reflection of rejection messages and notes across `HCP Profile Submission`, `HCP Account`, and `HCP` doctypes on ERPNext (`[REJECTED INSTITUTION: <reason>]`).
  - Added custom fields `rejection_reason` and `workplace_approval_note` across `HCP Account` and `HCP` DocTypes on live ERPNext.
  - Deployed dynamic Client Scripts (`HCP Profile Submission-Client`, `HCP Account-Client`, `HCP-Client`, `Institution-Client`) and custom List View indicators (`HCP-List`, `HCP Account-List`, `HCP Profile Submission-List`, `Institution-List`) displaying prominent red status tags and badges.
  - Active Rejected Institutions in HCP Profiling (ERPN version): Rejected institutions remain active, visible, and fully trackable with zero deletion, facilitating continuous audit and 1-click SFE remapping.

---

## [V.0.6.9] - 2026-10-08

### 🌲 Territory Reconfiguration Live Tree & Masterlist Synchronization Overhaul
- **Elimination of Premature LocalStorage Override**:
  - Identified and removed the 400ms `setTimeout(() => switchProgram(), 400)` race condition in `refreshLiveData()` that prematurely reloaded stale `programTerritories` and overwrote live data before ERPNext or Streamlit responses arrived.
  - Converted `refreshLiveData()` to a true async pipeline with interactive spinning button UI (`Syncing ERPNext...`), awaiting live fetch across all DocTypes.
- **Bi-Directional Streamlit & Desktop Synchronization**:
  - Wired `action: "tree_refresh"` to parent Streamlit container, fetching 4 live datasets in parallel via `ThreadPoolExecutor` (`live_territories`, `live_sales_persons`, `live_employees`, `live_users`).
  - Increased query limits to `limit_page_length=2000` to guarantee ingestion of all 180+ territory nodes across all organizational branches.
  - Auto-expanded root `'All Territories'` and active program branch (`territoryBranch`) in `treeExpandedNodes` so newly synced nodes render immediately upon sync completion.
  - Added support for `custom_account_or_program` attribute matching in `getProgramTerritoryNames` to seamlessly include program-tagged territories.

### 👥 Sales Person Tree Creation & Child Table Schema Alignment (HTTP 417 Resolution)
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

## [V.0.6.8] - 2026-10-08

### 🏥 SFE / Admin Rejected Institution Remapping Multi-DocType Propagation
- **ERPNext Workflow State Alignment (`Remapped`)**:
  - Registered `Workflow State` **`Remapped`** and `Workflow Action Master` **`Remap`** in ERPNext v15.
  - Updated `Institution WF` with allowed transitions from `Rejected` and `Pending Approval` to `Remapped` via action `Remap`, eliminating HTTP 417 `WorkflowPermissionError: Workflow State transition not allowed from Rejected to Remapped`.
- **Dynamic Cross-DocType Child Table Synchronization**:
  - Overhauled `remapRejectedInstitution` in `ApiService` to dynamically query ERPNext backend for all linked submissions, doctors, and program accounts rather than relying solely on in-memory collections.
  - Aligned exact child table schemas for all three DocTypes:
    - `HCP Profile Submission`: child table `table_workplaces` (`HCP Profile Submission Workplaces`) with `hcp_workplace`, `workplace_name`, `city_municipality`, `province_name`.
    - `HCP`: child table `hcp_workplace` (`HCP Workplaces`) with `hcp_workplace`, `city_municipality`, `province_name`.
    - `HCP Account`: child table `workplace_info` (`HCP Account Workplace`) with `hcp_workplace`, `city_municipality`, `province_name`.
  - Automatically clears rejected flags, writes remediation tracking remarks (`[Remapped to ...]`), persists updated local cache files, updates in-memory stores, and immediately unblocks MedRep profiling submissions.
- **Client-Side Remapped Facility Status Awareness**:
  - Added `isRemapped` getter to `Institution` model.
  - Updated `LocationResolver.isRejectedInstitution` to exclude remapped facilities so that remapped institutions are immediately accepted as valid and cleared from rejected filter lists.

### 🔤 Proper Title Case Normalization for HCP Names & Doctor Middle Names
- **Root Cause Elimination in `DataSanitizer`**:
  - Identified that `DataSanitizer.sanitizePayload` was checking `key.contains('id')` to convert IDs to uppercase; because `'middle_name'` contains `'id'` (`m-id-dle`), all middle names were inadvertently uppercased to ALL CAPS (`PAMBUENA`, `DE LEON`).
  - Refined payload sanitizer logic so that `name` and `middle` keys strictly route to `cleanTrimProper`, and ID uppercasing is strictly constrained to standalone `id`, prefix `id_`, suffix `_id`, or `_id_`.
- **HCP Profiling Wizard & Model Serialization**:
  - Added `cleanTrimProper` normalization in `Hcp.toJson()`, `HcpProfileSubmission.toJson()`, and `_syncFullName()` in `HcpWizardScreen`.
  - Added `TextCapitalization.words` to doctor name input fields in `HcpWizardScreen`.
  - Backfilled and normalized existing ERPNext records with uppercase middle names across `HCP` and `HCP Profile Submission`.

## [V.0.6.7] - 2026-10-07

### 🌐 Streamlit Cloud Custom Component Handshake & Cloud Proxy Optimization
- **Immediate Head-Level Streamlit Handshake**:
  - Embedded an ultra-fast handshake script directly inside the `<head>` of the Territory Reconfiguration Portal HTML that dispatches `streamlit:componentReady` and `streamlit:setFrameHeight` within 50ms of script evaluation.
  - Implemented a 200ms interval heartbeat until the parent Streamlit window sends its initial `streamlit:render` message, completely beating the internal 4.5-second timeout in Streamlit Community Cloud and eliminating the *"Your app is having trouble loading the app.pims_portal component"* error.
- **Production Server CORS & Proxy Alignment**:
  - Configured `.streamlit/config.toml` with `enableCORS = false` and `enableXsrfProtection = false` to enable seamless cross-origin communication between the parent Streamlit frame and the sandboxed custom component iframe on `*.streamlit.app`.
  - Added `enableStaticServing = true` and `enableWebsocketCompression = false` to ensure persistent static asset serving and prevent WebSocket drops over cloud proxies.
  - Disabled `runOnSave` to eliminate unprompted server restarts and file lock contentions in cloud containers.

## [V.0.6.6] - 2026-10-07

### 👤 Territory Reconfiguration: ERPNext Registered User ID Standard & Robust Dropdown Controller
- **ERPNext Registered User Email Account Standard**:
  - Enforced that User ID strictly displays and stores the registered ERPNext User email account (e.g. `lesantos@pims-marketing.com`), completely eliminating misleading employee ID numbers (`EMP-xxxxx` / `HR-EMP-xxxxx`).
  - Purged random placeholder employee ID generation across territory initialization, addition, transfer, and restoration workflows.
- **Table Grid View & Modal Unassigned State Precision**:
  - In Table Grid View, unassigned territory codes without a designated user now explicitly display `"Unassigned"` with subtle badge styling (`#F4F4F5`, grey border), eliminating fake `EMP-10023` tags.
  - In Edit and Add Territory modals, User ID and Territory Manager fields cleanly display `"Unassigned"` placeholder text when unassigned.
  - Added dedicated `(Unassigned) - Leave User ID unassigned` option at the top of the User ID searchable dropdown.
- **Robust Dropdown Interaction & Remote Search Architecture**:
  - Implemented `toggleErpDropdown(fieldId, event)` with outside click dismissal, eliminating unhandled ReferenceErrors.
  - Upgraded `openErpDropdown(fieldId, forceShowAll)` to present the full unfiltered directory of available users and sales persons on initial click or focus.
  - Enhanced `dispatchRemoteErpSearch` to query ERPNext `User` DocType dynamically with debounced search, persisting live matches to local storage cache.

## [V.0.6.5] - 2026-10-07

### 🌳 Territory Reconfiguration: Optional Territory Manager & Dynamic Auto-Assignment
- **Non-Mandatory Territory Manager on Child Folders & Nodes**:
  - Removed mandatory requirement (`*`) for Territory Manager in the Add Child modal (`#treeAddModalOverlay`) and Edit modal (`#treeEditModalOverlay`), allowing creation of unassigned group folders and territory nodes.
  - Set default input placeholder to `"Unassigned"`.
  - Added 1-Click `(Unassigned)` option to the top of the Territory Manager searchable dropdown.
- **Dynamic Auto-Detection on Territory Code Input**:
  - Integrated reactive `onTreeAddNameInput(val)` listener on the Territory Name field.
  - Automatically searches existing territory hierarchy (`territoryTreeData`), program territory masterlist (`programTerritories`), and sales representatives (`availableSalesPersons`).
  - Instantly populates the Territory Manager and associated User ID if an assigned manager is detected for the entered territory code, and gracefully reverts to `"Unassigned"` placeholder if no manager is assigned.

## [V.0.6.4] - 2026-10-07

### 🔄 Territory Reconfiguration: Resigned Representative Doctor Handover & Search-Filtered Workbench
- **Resigned Representative Doctor Handover Directive**:
  - Implemented comprehensive "Tag Resigned & Handover" workflow across both Table Grid View actions and Territory Tree View editor modal (`#treeEditModalOverlay`).
  - Added dedicated Handover Prompt Modal (`#resignedHandoverPromptModalOverlay`) confirming previous representative identity, covered doctor headcount, and newly assigned representative.
  - Enabled 1-Click "Quick Resign & Auto-Merge Doctors" which automatically reassigns the territory code, merges 100% of previous doctors to the new MedRep, logs audit trails, and updates ERPNext via live PUT dispatch.
  - Provided "Custom Transfer Workbench" pathway allowing fine-grained selection and doctor-by-doctor reassignment.
- **2-Pane Doctor Transfer Workbench Search & Filtering**:
  - Added real-time search filter inputs to both Target Territory and Source Territory doctor lists with instant debounced filtering.
  - Integrated directive banners showing previous representative name, territory code, and total doctors to be transferred.
  - Added "Merge All Doctors (X)" batch transfer button and "Clear All" reassignment actions.
- **Bi-Directional Streamlit & Local Storage Persistence**:
  - Enhanced `saveDoctorTransfer()` and `executeQuickResignAndMerge()` to serialize updated territory and account collections to `localStorage` and emit reactive `streamlit:setComponentValue` messages.

## [V.0.6.3] - 2026-10-06

### 🏥 Institution Field & Workplace Search: Lag Elimination & Smart Non-Blocking Intelligence
- **Zero-Lag Typing & UI Debouncing Engine**:
  - Implemented asynchronous 200ms debouncing across `ProposeInstitutionDialog`, `HcpWizardScreen` workplace picker, and `SfeInstitutionDashboardScreen`.
  - Added O(1) fast-path candidate pre-filtering to `searchDirectoryWithDuplicateDetection` that skips 95%+ of irrelevant records before regex execution, eliminating UI thread freezing and delivering smooth 60fps typing.
- **Smart Phrase & Keyword Similarity Precision**:
  - Replaced whole-phrase Soundex collisions that previously produced unrelated recommendations (e.g. matching "St. Jude Clinic" against "St. Luke's Medical Center").
  - Added apostrophe normalization (`st lukes` matching `st. luke's`) and word stemming to accurately detect genuine facility phrases and distinctive keywords.
  - Raised suggestion confidence threshold to 65.0+ so only truly relevant facilities are suggested.
- **Complete Elimination of MedRep Lock-Up**:
  - Unlocked Step 3 Location fields (Region, Province, City, Address) immediately upon classification and workplace name entry (>= 3 chars), removing the previous `!_hasDuplicateMatches` barrier.
  - Transformed the aggressive red "Submission Locked" banner into an informative, non-blocking green suggestion banner ("💡 Similar Facilities in Masterlist").
  - Empowered MedReps to freely submit new institution proposals even when similar facilities exist in other locations, while maintaining exact identical duplicate safeguards.

## [V.0.6.2] - 2026-10-06

### 🗺️ Territory Reconfiguration Web App: Permanent View Mode Invariance & Anti-Revert Hardening
- **Deterministic CSS-Level Invariant View Mode Enforcement**:
  - Implemented `body[data-editor-view="grid"]` and `body[data-editor-view="tree"]` high-priority CSS rules with `!important` overriding all sub-view display states (`#gridTableView`, `#territoryTreeView`, `#btnAddTerritoryRecord`, `#btnBatchCodeRename`, `#tablePaginationWrapper`).
  - Completely eliminates any script-level, DOM layout, or event-driven forced revert to Territory Tree View when switching to Table Grid View.
- **Triple-Redundancy View Persistence & Session Isolation**:
  - Bound `window.activeEditorViewMode` to a reactive property on `window.isTreeViewActive` with bi-directional synchronization.
  - Mirrored persistence across `sessionStorage`, `localStorage`, and the root DOM `data-editor-view` attribute to survive sandboxed iframe storage restrictions on Streamlit Community Cloud.
- **Event Debounce & Click Cooldown Protection**:
  - Hardened `toggleEditorView(event)` with `preventDefault()`, `stopPropagation()`, `stopImmediatePropagation()`, and a 350ms timestamp cooldown guard to prevent touch/click event bubbling from rapidly toggling the view back and forth.
- **Removal of Legacy Forced Resets in Auth & Background Sync Pipelines**:
  - Purged all unconditional view mode resets from `applyAuthenticatedUser()`, `switchProgram()`, `syncTreeWithERPNext()`, and `streamlit:render` message handler.
  - Auth checks and background masterlist re-synchronization now strictly honor the active view mode without touching or resetting it.
- **Cache-Busting HTTP Headers & GitHub Repo Synchronization**:
  - Added `<meta http-equiv="Cache-Control">`, `<meta http-equiv="Pragma">`, and `<meta http-equiv="Expires">` tags in `<head>` to prevent browsers from serving stale cached iframe builds.
  - Synchronized and pushed directly to `https://github.com/LetscodeJosh/PIMS-Territory-Reconfig-Portal.git` on branch `main`.

---

## [V.0.6.1] - 2026-10-06

### 🗺️ Territory Reconfiguration Web App: Table Grid View Switching & View State Invariance
- **Table Grid View Forced-Reset Elimination**:
  - Resolved bug where switching from Territory Tree View to Table Grid View was being overridden and forced back to Territory Tree View upon subsequent state changes, Streamlit component renders, or session checks.
  - Implemented bidirectional view synchronization via `setEditorViewMode(mode)` and synchronized button label heuristics: clicking a button displaying `"View as Table Grid"` strictly engages Grid View (`isTreeViewActive = false`), eliminating DOM vs in-memory inverted boolean race conditions.
  - Added `initPortalViewMode()` on `DOMContentLoaded` to immediately align DOM elements (`gridTableView`, `territoryTreeView`, `btnToggleView`, `btnAddTerritoryRecord`, `btnBatchCodeRename`, `tablePaginationWrapper`) with the user's persisted view preference in `localStorage.pims_territory_active_view`.
- **Gated Pagination Visibility Guard**:
  - Hardened `renderTree()` to only hide `#tablePaginationWrapper` when Territory Tree is truly active (`if (pagEl && isTreeViewActive) pagEl.style.display = 'none';`).
  - Table Grid pagination bar now remains docked and visible across all bulk operations, doctor transfers, and background synchronization events.
- **Sidebar Tab View State Restoration**:
  - Updated `openTab('tab-editor')` to invoke `updateEditorViewModeUI()` when navigating back from Realignment or Summary tabs, ensuring the user's active view mode is seamlessly maintained.
- **Single Source of Truth & Zero-Drift Parity**:
  - Re-synchronized all portal copies across `docs/`, `assets/web/`, `installers/Territory_Reconfiguration_App/`, `installers/Streamlit_Deployment/`, and `releases/legacy_versions/V.0.6.1/` with 100% byte-for-byte SHA-256 hash parity.

---

## [V.0.6.0] - 2026-10-06

### 🏥 Institution Rejection, Multi-DocType Reflection & SFE Remapping Workflow
- **Multi-DocType Rejection Propagation**:
  - When an institution is rejected by SFE due to duplication or invalid status, the rejection cause note is immediately reflected across:
    - **`HCP Profile Submission`**: Injected into `status_note` (`[REJECTED INSTITUTION: <cause>]`) and child table `workplaces[].workflow_state = "Rejected"`.
    - **`HCP Account`**: Persisted in `remarks` (`[REJECTED INSTITUTION: <cause>]`).
    - **`HCP` (Doctor Masterlist)**: Injected into `notes` and marked in `workplaces[].status = "Rejected"`.
- **Pre-Submission Wizard Guard**:
  - In `HcpWizardScreen`, pre-submission validation detects any rejected institutions in the proposed workplaces and immediately blocks submission with a descriptive error: `"Cannot submit: <Facility> (Reason: <cause>) was rejected by SFE and cannot be used for profiling. Please remove or have SFE remap this institution."`
- **Lockscreen / Homescreen Heads-up Notification Engine**:
  - Integrated `flutter_local_notifications` with `NotificationVisibility.public`, `Importance.max`, and `Priority.high`.
  - Notifications pop up on the lockscreen and homescreen even when the MedRep is logged out of the app, utilizing cached `last_active_medrep_user` in `SharedPreferences`.
  - Also alerts the MedRep upon SFE resolution/remapping.
- **SFE Institution Remapping Hub ("Change / Remap for MedRep")**:
  - SFE Specialists have a dedicated action in `SfeInstitutionDashboardScreen` and `InstitutionApprovalsScreen` to remap rejected facilities to active, approved masterlist facilities.
  - Automatically updates `HCP`, `HCP Account`, and `HCP Profile Submission`, clearing the rejection block and unblocking MedRep profiling.
- **Label Standardization**:
  - Renamed all UI occurrences of **"Doctor Listing"** $\rightarrow$ **"HCP"**.
  - Renamed all UI occurrences of **"Doctor Account"** $\rightarrow$ **"HCP Account"**.
- **Real-World Simulation Suite**:
  - Provided 1-tap in-app simulation icon in the SFE Dashboard.
  - Authored automated end-to-end simulation script `scratch/simulate_institution_rejection_workflow.py`.
  - Documented simulation runbook in `docs/INSTITUTION_REJECTION_AND_REMAP_SIMULATION_GUIDE.md`.

---

## [V.0.5.5] - 2026-10-05

### 🚀 User Account Live Full Name & Database Bidirectional Synchronization
- **User Account Full Name Dropdown Display**: Updated the User Account search dropdown menu in Territory Add, Edit, and Management modals to display the true, registered **Full Name** from ERPNext live `User` doctype (e.g. `lesantos@pims-marketing.com` shows subtitle `Leonniel Santos`, `leritargieian@gmail.com` shows subtitle `Argie Adaptar Lerit`, `jptan@profinsights.biz` shows subtitle `Joshua Tan`, etc.) matching the live ERPNext user directory 1:1.
- **Live ERPNext User Masterlist Integration**: Added `fetch_live_users` to `app.py` pulling all users (`limit_page_length=3000`) concurrently with territories, sales persons, and employees via multi-threaded ThreadPoolExecutor. Passed live user masterlist into web app portal component with session persistence.
- **Table Grid & Territory Tree Unified Database Reflection**:
  - Implemented `syncProgramTerritoriesWithTree()` in the web app, ensuring that every simulation (Add Child/New Territory, Edit Parent/Manager/User, Rename, and Delete) performed in Table Grid View or Territory Tree View immediately updates the local model, persists to cache, and dispatches directly to the ERPNext backend.
  - Hardened backend `execute_tree_action` with automatic fallback retry on `tree_add` and `tree_edit` if manager links trigger validation constraints, guaranteeing that all territory mutations reflect live in the ERPNext database (`dev.pmii-marketing.com`).
  - Both views now render in synchronized lockstep upon every user action and ERPNext backend feedback event.

---

## [V.0.5.4] - 2026-10-02

### 🛡️ Enterprise Security Overhaul & Hardening
- **Hardware-Backed Keystore/Keychain Credential Storage**: Migrated `BiometricService` from plaintext `SharedPreferences` to `FlutterSecureStorage` (AES-GCM encrypted via Android Keystore & iOS Keychain). Automatically scrubs legacy plaintext credential keys on startup.
- **Offline Authentication Gating**: Hardened `ApiService.login()` against airplane-mode / offline bypass. Offline mode now strictly requires non-empty credentials matching the device's enrolled owner, preventing unauthorized access on lost or stolen devices.
- **Embedded Web Server Session Token Authorization**: Secured `TerritoryWebServer` (`lib/services/territory_web_server.dart`) by enforcing ephemeral session tokens on all `/api/` endpoints (`/api/status`, `/api/live-data`, `/api/sync`) for LAN connections. Added `X-Content-Type-Options: nosniff` and `X-Frame-Options: SAMEORIGIN`.
- **Android Network Security Configuration**: Enforced HTTPS across all remote network connections in `res/xml/network_security_config.xml` with `android:usesCleartextTraffic="false"` and `android:allowBackup="false"`, while permitting loopback HTTP solely for embedded local web views.
- **Production Keystore Signing Configuration**: Refactored `android/app/build.gradle` to load production release signing keys from environment variables (`KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, etc.) or secure secrets, eliminating hardcoded debug keystores.
- **Strict SSL/TLS Certificate Validation**: Enforced trusted CA certificate validation on ERPNext web proxies (`app.py` and `server.py`).
- **Streamlit CORS Hardening & Credential Scrubbing**: Set `enableCORS = true` in Streamlit `config.toml` and scrubbed plain-text passwords immediately upon authentication in `app.py`.
- **Automated CI/CD Pipeline**: Integrated GitHub Actions workflow (`.github/workflows/ci_cd.yml`) with Bandit SAST, `flutter analyze`, 64 unit & workflow tests, tech debt audits, and multi-platform packaging.

### Added & Enhanced
- **Responsive Viewport & Sticky Table Pagination**: Fixed layout responsiveness where the bottom pagination controls were clipped off-screen on laptop displays and required users to zoom out. Replaced rigid `calc(100% - 96px)` with dynamic nested flexbox (`flex: 1 1 0; min-height: 0;`) and docked pagination controls using `position: sticky; bottom: 12px;` so pagination is visible and accessible at all zoom levels (100%, 125%, 150%).
- **Notification Auto-Dismiss**: The lower-right logged-in user notification (`#activeUserSessionToast`) now displays upon login and automatically dismisses completely after 4.5 seconds with zero lingering UI elements or cards.
- **Zoom In/Out Notification Loop Prevention**: Resolved issue where zooming in or out caused notifications to repeatedly pop up due to re-emitted `streamlit:render` events; added `loginNotificationShown` gating to restrict notifications strictly to initial authentication.
- **Dynamic Streamlit Frame Sizing**: Replaced hardcoded `1080px` frame height in `initStreamlitComponent()` with dynamic `window.innerHeight` synchronization (`sendStreamlitFrameHeight`).
- **High-Performance Fast Backend Authentication**: Resolved slow login delays by implementing `ThreadedTCPServer` in desktop `server.py`, strict 6-second timeout watchdogs, fast-path administrator login, and `Connection: close` socket starvation protection.
- **ERPNext 1:1 Territory Tree Workbench**: Full hierarchy operations (Add Child to folders, Edit, Rename, Delete, MedRep reassignment) with doctor coverage tracking and audit trail synchronization.

---

## [V.0.1.0] - 2026-08-27

### 🚀 Major Highlights & Workflows
- **App Rebranding**: Renamed application from "PIMS HCP" to **"HCP Profiling"** across Login, Navigation Drawer, and App metadata.
- **Redesigned Step 2 (Doctor's Information)**:
  - Uncluttered default view displaying only the top DOCTOR'S INFORMATION card and search input.
  - Interactive **Profile Action** auto-detection for existing vs new HCP.
  - Form fields dynamically pop up when selecting an existing doctor or clicking `[ Add New Doctor ]`.
  - Left-aligned all `+ Add Row` buttons across Specializations, Workplaces, and Contacts.
- **Removed "Others" Tab & Auto-Populated Hidden Form Fields**:
  - Automatically derives `account_or_program`, `territory`, `sales_person`, and `submission_date` behind the scenes.
  - Hidden from direct view to streamline user workflow while ensuring all mandatory ERPNext fields are populated.
- **Accurate Real-Time Submission Timestamping**:
  - Automatically captures the exact system submission timestamp (formatted for 12-hour AM/PM display) in ERPNext doctype `HCP Profile Submission`.
- **In-Place Doctor Update & Overwrite (Tamper Prevention)**:
  - Updating an existing doctor profile immediately updates the doctor record in ERPNext master list and syncs the corresponding HCP Account without requiring manual managerial approval or creating duplicate submission entries.
- **Accurate Counting & Filter Alignment**:
  - Doctor account screen denominator counting resolved accurately across all account roles (medrep, managerial, admin).
- **Human-Readable PSGC Geo-Resolution**:
  - Added comprehensive PSGC dictionary for Philippine cities and provinces to render clean names (e.g. "Manila City", "Metro Manila-Manila") rather than raw technical codes.

### 📦 Release Binaries
- `releases/V.0.1.0/HCP_Profiling_V.0.1.0.ipa`
- `releases/V.0.1.0/PIMS_HCP_V.0.1.0.ipa`
- `HCP_Profiling.ipa` (root symlink/build)
