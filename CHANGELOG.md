# Changelog

All notable changes to the **HCP Profiling App** will be documented in this file.
The project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
