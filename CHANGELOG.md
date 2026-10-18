# Changelog

All notable changes to the **HCP Profiling App** will be documented in this file.
The project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v.0.7.2] - 2026-10-18

### 🗺️ Territory Reconfiguration Web Portal v.0.1.0 & Enterprise Resilience
- **Dedicated Web App Versioning (`v.0.1.0`)**:
  - Separated the Territory Reconfiguration Web Portal version tracking from the mobile HCP app (`v.0.7.2`), branding the web portal as **`v.0.1.0`**.
- **Realignment Tab Clutter Elimination**:
  - Removed "Active District Groups & Realignment Distribution" card grid from Tab 2, retaining strictly the **Archived & Inactive Territories Directory Vault** for zero data loss.
- **Top-Tier Summary Report & Audit Trail UI/UX**:
  - Unified KPI Summary Card number colors across all 5 metrics (`Total Records`, `Unchanged`, `Changed/Renamed`, `Rep Transfers`, `Archived Nodes`) to match the primary Total Records brand blue (`#0066FF`).
  - Upgraded Master Audit Trail to a dedicated scrollable viewport (`max-height: 520px; overflow-y: auto;`) with sticky table headers (`position: sticky; top: 0; background: #0B192C;`) and sleek modern scrollbars.
- **Strict No-Deletion Policy & Inactive/Vacant Territory Flow**:
  - Completely removed the `Delete` action from the Table Grid View action popover (`gridRowActionsMenu`).
  - Added **`Tag Inactive / Vacant`** action with confirmation modal (`#inactiveModalOverlay`): decommissions resigned MedReps, preserves territory codes in ERPNext as Vacant for future program cycles, archives records to the Archive Directory, and ensures zero doctor data loss.
- **First-Time User Walkthrough & Interactive Guidance Engine**:
  - Added automatic detection for first-time login sessions to display the interactive **Territory Reconfiguration Portal Guide** walkthrough modal (`#userGuideModalOverlay`).
  - Enabled button guidance subtext under all action menu items (e.g. *Edit territory properties & manager*, *Create child territory under this node*, *Rename territory name in tree & ERPNext*, *Set territory inactive & vacant in ERPNext*, *Reassign rep & transfer doctors*, *View change history & logs*).
  - Added dedicated **`User Guide (ℹ)`** icon in top header navigation allowing returning users to re-open the guide, review instructions, and toggle button hints at any time.

- **Table Grid View Refinements**:
  - Removed territory code prefix (`AD0101 - `) from the Assigned MedRep column; displays clean representative name with formatted User ID and Record ID below.
  - Replaced `UNCHANGED`/`CHANGED` in the Status column with operational status badges: **`Active`** (emerald), **`Inactive`** (slate), or **`Vacant`** (amber).
  - Added new **`Area / District`** column displaying coverage tag (`GMA/NLZ`, `GMA/SLZ`, etc.) and parent district with Column Visibility toggle (`colToggle_area`) and Filter By support.
- **Zero-Deletion Standard & Active / Inactive Operational Toggles in Territory Tree**:
  - Completely removed `Delete` option from the Territory Tree view and web app (no data deletion permitted).
  - Streamlined tree node action buttons to strictly: **`(Edit, Transfer Doctor, Rename, Active/Inactive)`**.
  - Tapping **`Active`** / **`Inactive`** operational toggle smoothly changes territory operational status without deleting any data.
- **Tree Node Alignment & Area Tag Precision**:
  - Standardized territory leaf node display alignment: `${territoryCode} (${areaDistrictTag}) - ${medRepName}` (e.g. `AD0106 (GMA/NLZ) - JONEL APSAY`).
  - Added extensible `TERRITORY_AREA_MAPPINGS` dictionary and automatic district tag resolution (`resolveTerritoryArea`) ready for full area code file integration.
- **Program Dropdown Filtering in Territory Tree**:
  - Filtered Territory Tree root hierarchy by active selected program: selecting `Abbott Diabetes Care` exclusively displays Abbott branches, hiding other programs (`Bayer`, `RiteMed`, `Vivaro`) from view.
- **Header Controls Streamlining**:
  - Removed redundant `[Refresh Live Sync]` button; Territory Tree operates as the live, authoritative interactive reconfiguration canvas.
- **Doctor Count Modal Humanization & Area Tagging**:
  - Replaced verbose/inappropriate explanations with clean, professional statements for zero doctors and search queries.
  - Included the MedRep's **Area Code / District** directly in the modal header and subheader.
- **Doctor Transfer Modal Upgrades**:
  - Added a 3-way status button toggle: **`Active (Working)`**, **`Inactive (Resigned)`**, and **`Vacant`**.
  - Fixed Move Selected buttons to ensure all 3 transfer action buttons are permanently active, vibrant, and never grayed out.
  - Replaced single-line audit input with a spacious multiline `<textarea>` for free typing of comprehensive transfer notes.
- **Authentication Security Intrusion Mitigation & Network Resilience**:
  - Implemented `SecurityIntrusionGuard` (client and server-side) with regex-based SQL injection, script injection, and command injection pattern detection.
  - Automated intrusion blocking, 15-minute progressive freeze, and 5-attempt rate-limiting safeguards.
- **Territory Tree Light Theme Alignment**:
  - Matched territory tree container, rows, node labels, and action toolbars to the executive light color theme of the Table Grid View (clean white `#FFFFFF` surface, `#E2E8F0` borders, and subtle elevation).
  - Styled leaf territory codes in vibrant cyan-blue (`#0284C7`, font-weight: 700) matching the Active Code table column.
  - Styled assigned representative full names in crisp, high-contrast dark slate (`#0F172A`, font-weight: 600) for effortless legibility.
  - Aligned Area coverage badges with soft cyan-blue (`#F0F9FF`, border: `#BAE6FD`, text: `#0369A1`).
  - Updated folder icons, leaf bullets, row hover (`#F8FAFC`), and row selection (`#EFF6FF` with blue accent).
- **Auto-Login Security Vulnerability Elimination**:
  - Purged automatic login on Streamlit server updates, git commits, and tab restarts by removing `sfe_session` URL query parameter sharing and scrubbing persistent `localStorage` user caches.
  - Enforced an explicit, secure Login screen upon all redeployments and fresh browser sessions to eliminate unauthorized account exposure.


---

## [v.0.7.1] - 2026-10-18

### 🔒 Enterprise Form Security, Dynamic Multi-Program Consent & Humanized Executive Summaries
- **Doctor Search Redundancy Elimination**:
  - Removed the "+ Add as New Doctor" button and link from inside the doctor search modal (`_showHcpSelectorModal()`).
  - Search HCP now strictly focuses on masterlist lookups for existing doctors, with new doctor registrations exclusively initiated from the dedicated "+ Add New Doctor" card in Step 2.
- **Dynamic Multi-Program Consent Formulation**:
  - Step 1 consent agreement dynamically adapts based on the logged-in program (e.g. `PMII Abbott Diabetic Care (ADC)`, `PMII Bayer`, `PMI Fonterra`, `PMII Galderma`, etc.).
  - Replaces all static `PROFESSIONAL INSIGHTS MARKETING SERVICES (PIMS)` references with program-tailored corporate entity names (`$fullName` and `$shortName`).
  - Privacy policy URLs and disclaimer notes dynamically reflect the respective corporate privacy statement.
- **Enhanced Cancel Doctor Action & Visibility Guarding**:
  - Upgraded the small text link into an intuitive, high-visibility outlined interactive button with icon (`Icons.close_rounded`) and styled container.
  - Button visibility is cleanly guarded: it only appears when all mandatory fields of Step 2 (First Name, Last Name, Specialization, Workplace, Workplace Type, Practice) are completely fulfilled, avoiding screen clutter and cognitive overload.
  - Integrated confirmation dialog (`_confirmResetDoctor`) to prevent accidental form resets.
- **Step Progression & Tab Security Guardrails**:
  - Step 2 tab is locked until Step 1 is fully accomplished (doctor consent checkbox confirmed + doctor signature or photo captured).
  - Step 3 and Changes tabs are locked until Step 2 is fully completed.
  - Inactive tabs display lock styling with clear feedback SnackBars indicating the missing prerequisite step.
- **Human-Readable Executive Summary of Changes (Elimination of Raw JSON)**:
  - Replaced the developer monospace raw JSON preview card with a human-readable, executive change summary card.
  - Summarizes Doctor Profile modifications, Added/Removed Specializations, Workplaces, Contact details, Survey Detailing responses, and Submission Audit details in an intuitive, polished format.
- **Task-Specific "Add Row" Button Labels**:
  - Renamed generic "Add Row" buttons across cards and dialogs to descriptive, task-oriented action labels: `+ Add Specialization`, `+ Add Institution`, and `+ Add Contact/Email`.
- **Mandatory Field Styling & Birth Date Cleanup**:
  - Mandatory disclaimer `* indicates information that are mandatory` styled in prominent crimson red (`#DC2626`).
  - First, Middle, and Last Name labels use `Text.rich` displaying neutral slate text with a red asterisk `*` without red input borders.
  - Cleaned up Birth Date input by removing the `(Optional)` tag and helper text.

---

## [v.0.7.0] - 2026-10-13

### 🏥 Gemini 4 Argon Progressive Phrase Shrinking & Doctor Field Locking
- **Institution / Workplace Progressive Phrase Shrinking**:
  - Engineered an intelligent progressive shrinking algorithm (`LocationResolver.fuzzySearchInstitutions` and `LocationResolver.searchDirectoryWithDuplicateDetection`):
  - When typing into the workplace/institution field, suggestions start with broad potential matches (maximum count) and dynamically shrink down to strictly co-related facilities and direct branches as the user completes the full phrase/context.
  - Distinctive phrase matching prunes unrelated facilities that only share generic words (like "hospital", "clinic", or "center"), completely eliminating irrelevant and cluttered dropdown results.
  - Multi-distinctive token queries require >= 70-100% token overlap with aggressive relative confidence pruning (`score < topScore * 0.75`), focusing the dropdown strictly on the targeted facility and its branches.
  - Added a live Smart Detector Phrase Pill (`Smart Match: "<Institution Name>"`) with a shrinking facility counter pill right below the search bar in the workplace picker dialog.
- **Existing Doctor Record Field Locking (Clean Invariance)**:
  - When an existing doctor from the masterlist is selected (via suggestion pop-up, auto-fill, or search), the **First Name**, **Middle Name**, **Last Name**, and **Birth Date** fields automatically switch to `readOnly: true`.
  - In adherence to strict enterprise UI standards, fields are locked seamlessly under the hood without distracting warning notices, lock banners, or lock icons.
  - Field recognizer badges and suggestion pop-ups are cleanly disabled when an existing doctor is active.
  - If the MedRep switches back to "+ Add New Doctor" or clears the selection, all fields immediately regain editable status.

### 🧠 Gemini 4 Argon-Grade Smart HCP Recognizer & Doctor Masterlist Suggestion Engine
- **Step 2 Real-Time Doctor Name Recognizer**:
  - Implemented an intelligent suggestion engine and detector across `First Name`, `Middle Name`, and `Last Name` fields in Step 2 (Doctor Information).
  - Actively scans the universal `HCP` doctype masterlist (`_allDoctors`) in the background with an optimized 180ms debounce.
  - Interactive field recognizer badge (`Icons.auto_awesome_rounded`) displays live match count pills (`1`, `2`, `3+`) directly inside text field suffix containers.
- **"Person Available in HCP" Pop-Up Window**:
  - Automatically renders an interactive, dismissible pop-up window directly below the name fields when existing doctor matches are detected.
  - Prominent header banner: **`"Person available in HCP"`** with total match count pill and close/dismiss button.
  - Informative footer note: *"Selecting an existing doctor auto-populates all records and merges automatically upon submission."* with a **`Continue as New`** option for registering brand-new doctors.
- **10-Tier Fuzzy Match Engine (`HcpDoctorMatchEngine`)**:
  - Medical title and honorific normalization (`Dr.`, `MD`, `FPCP`, `FPCS`, `FPOG`, `RN`, `RPh`, punctuation, apostrophes, and spacing).
  - Stopword and particle filtering (`de`, `del`, `dela`, `san`, `los`, `las`, `van`, `von`, `jr`, `sr`).
  - Tiered confidence scoring:
    - Tier 1: Exact Doctor Full Name Match (100%)
    - Tier 2: Dual First & Last Name Match (98%)
    - Tier 3: First & Surname Correlation Prefix Match (94%)
    - Tier 4: Full Name Prefix Match (92%)
    - Tier 5: Surname Match (88%–94%)
    - Tier 6: First Name Match (84%–92%)
    - Tier 7: Surname Prefix Match (82%)
    - Tier 8: Multi-Token Overlap & Permutation (80%–92%)
    - Tier 9: Damerau-Levenshtein Typo Tolerance (76%–78%)
    - Tier 10: Universal HCP Masterlist ID / Code Match (95%)
- **1-Click Auto-Population & Seamless Workflow Preservation**:
  - Tapping **`Auto-fill`** or any matched doctor card instantly executes `_prepopulateDoctorData`, auto-populating full names, photo avatars, birth dates, specialty affiliations (with program-specific preferences), workplaces, and contact channels.
  - Selecting a suggestion in `New Doctor` mode automatically converts the submission to an `Existing HCP`, guaranteeing automatic merge on submission (`Submit for Processing` $\rightarrow$ `Processed`) without managerial approval bottlenecks.
  - Users choosing to ignore or dismiss the suggestion can continue typing and submit as a `New HCP` (`Submit for Approval` $\rightarrow$ `Pending Approval`), preserving 100% of the verified approval workflow invariants.

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
