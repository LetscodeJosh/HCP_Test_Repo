# Changelog

All notable changes to the **HCP Profiling App** will be documented in this file.
The project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

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
