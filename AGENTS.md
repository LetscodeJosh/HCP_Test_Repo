# Critical Project Rules & Workflow Constraints

## 📋 Core App Workflow & Architecture Standard

### 1. The Two-Tier Masterlist Architecture
* **`HCP` DocType**: Universal masterlist of all doctors present across every program.
* **`HCP Account` DocType**: Masterlist **per program** (e.g., Abbott Diabetes Care, Bayer, COREnergy) where doctor affiliations repeat across different programs with program-specific preferred items (workplace, specialization, contacts).

### 2. Application Workflow Rules (Strictly Aligned with ERPNext HCP Profile Submission WF)
1. **Existing Doctor (`Existing HCP`)**:
   * **Action**: `Submit for Processing` $\rightarrow$ State: **`Processed`** (Rows 1 & 2: `doc.profile_action=="Existing HCP"`).
   * **Requires NO Managerial Approval**.
   * Merges automatically upon submission directly into the `HCP` record and syncs `HCP Account` with the **preferred** features active.
2. **New Doctor (`+ Add New Doctor` / `New HCP`)**:
   * **Action**: `Submit for Approval` $\rightarrow$ State: **`Pending Approval`** (Rows 3, 4, 5: `doc.profile_action=="New HCP"`).
   * **Requires Managerial Approval** (`Sales Manager` or `System Manager`).
   * Manager clicks **`Approve`** $\rightarrow$ State: **`Approved`** (Rows 6 & 7: `doc.profile_action=="New HCP"`).
   * Committed to the masterlist only after approval.

### 3. ERPNext Workflow Rule
* Do **NOT** modify or change the set `condition` expressions (`doc.profile_action=="Existing HCP"` / `doc.profile_action=="New HCP"`) in `HCP Profile Submission WF` on the ERPNext server. The app matches this server-side workflow 1:1.

## 🧹 Mandatory Repository Cleanliness & Organization Standard
1. **Zero Clutter in Repository Root**:
   * The repository root must strictly contain ONLY core project configuration files: `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `README.md`, `CHANGELOG.md`, `VERSION`, `AGENTS.md`, `.gitignore`, `.metadata`.
2. **Dedicated Directories**:
   * **Documentation**: All guides, architecture specs, and markdown documents belong in `docs/`.
   * **Binaries & Releases**: All APKs, IPAs, and release builds belong in `releases/`.
   * **Scratch & Test Scripts**: All temporary scripts, Python test tools, and data inspections belong in `scratch/`.
   * **Never place PDFs, IPAs, APKs, extra markdown guides, or scripts in the root directory**.
3. **Autonomous Proactive Maintenance**:
   * Clean up and preserve repository root hygiene automatically in all tasks without waiting for user prompts.

## 🔢 Mandatory Semantic Versioning & Release Tracking Standard
1. **Semantic Versioning Structure (`MAJOR.MINOR.PATCH`)**:
   * **`MAJOR` (`X.0.0`)**: Incremented for breaking changes or fundamental system upgrades.
   * **`MINOR` (`0.Y.0`)**: Incremented for new features, modules, and workflows (e.g., Add New Institution & Approval Workflow).
   * **`PATCH` (`0.0.Z`)**: Incremented (+1) for every bug fix, UI correction, or data adjustment.
2. **Synchronized Version Files**:
   * Whenever a version change occurs (whether Major, Minor, or Patch), update in lockstep:
     * `VERSION` (e.g. `V.0.2.0`)
     * `pubspec.yaml` (`version: 0.2.0+2`)
     * `lib/constants/app_version.dart` (`version`, `buildNumber`, `releaseDate`, `fullVersion`)
     * `CHANGELOG.md` (documented entries under version header)
     * `releases/legacy_versions/V.X.Y.Z/` (artifacts, `metadata.json`, `RELEASE_NOTES.md`)
3. **Continuous Version Tracking**:
   * Always explicitly note and confirm the current active version in every response so the team and user have real-time visibility.
   * All version releases (e.g., `V.0.1.0` through `V.0.5.2` and beyond) are preserved inside `releases/legacy_versions/`.
4. **Mandatory Autonomous APK Generation on Changes**:
   * Every time code modifications (bug fixes, features, or UI adjustments) are implemented in response to a prompt:
     * Bump the version accordingly (`PATCH` for fixes, `MINOR` for features).
     * Automatically build the release APK (`flutter build apk --release`).
     * Package and copy the output into `releases/HCP_Profiling_Release.apk` and `releases/legacy_versions/V.X.Y.Z/HCP_Profiling_V.X.Y.Z.apk`.
     * Update `metadata.json` and `RELEASE_NOTES.md` in `releases/legacy_versions/V.X.Y.Z/`.
     * Provide direct clickable links to the generated APK in the response.

## 🛡️ Mandatory 24/7 Production Resilience & Operational Continuity Guarantee

### 1. Operational Invariance (Untouched Code & Long-Term Deployment)
* The HCP Profiling Mobile App and Territory Reconfiguration Web App are mission-critical enterprise systems requiring continuous 24/7 field operation.
* Even if the repository, codebase, or APIs remain untouched for months or years, the apps **must NEVER crash, freeze, or stop executing their complete workflows**.

### 2. Five Pillars of Production Resilience
1. **Cache-Aside & Stale-While-Revalidate Engine**:
   * All ERPNext queries (`HCP`, `HCP Account`, `Medical Institution`, `HCP Profile Submission`, `Territory`, `Specialization`) automatically persist to local disk cache (`frappe_<docType>_list.json`).
   * When ERPNext v15 is temporarily offline, rebooting for backup, or unreachable due to network drops, cached records are served immediately. The UI never throws unhandled exceptions or blank screens.
2. **Autonomous Session & Token Renewal**:
   * Frappe session cookies (`sid`) and CSRF tokens naturally expire. `ApiService` automatically intercepts HTTP `401 Unauthorized` / `403 Forbidden`, auto-renews credentials, and replays the original request without user interruption.
3. **Strict 15-Second Timeouts & Transient Error Retry**:
   * All network operations enforce a strict 15-second timeout with 2-stage exponential backoff. No HTTP call can hang indefinitely in low-connectivity hospital basements or remote clinics.
4. **Offline-First Submission Queue (Zero Data Loss Guarantee)**:
   * Every profile submission and institution proposal writes to local SQLite (`DbHelper`) *before* attempting network dispatch.
   * Background auto-sync timers poll `/api/method/ping` and automatically flush queued submissions to ERPNext as soon as connectivity resumes.
5. **Defensive Schema Sanitization (`DataSanitizer`)**:
   * All JSON payload parsing applies defensive null-coalescing, string trimming, and safe type coercion. Any future ERPNext DocType schema changes (added custom fields, modified nullability, or changed types) will never crash the mobile or web applications.

### 3. Territory Reconfiguration Web Portal Resilience
1. **Client-Side Single-Page Architecture**:
   * Completely self-contained HTML/CSS/Vanilla JavaScript with browser `localStorage` state backup.
   * Territory trees, doctor assignments, and cycle snapshots survive backend disruptions.
2. **Dual Authentication Engine**:
   * Authenticates against live ERPNext (`dev.pmii-marketing.com`) when online.
   * Automatically falls back to authorized local token authentication if ERPNext is unreachable, ensuring SFE Leads are never locked out of critical cycle planning.
3. **Comprehensive Specification & Disaster Recovery**:
   * Full operational specifications and runbooks are permanently documented in `docs/24_7_PRODUCTION_RESILIENCE_AND_FAILOVER_SPECIFICATION.md`.

## 🏛️ Mandatory Zero-Technical-Debt & Perpetual Viability Standard

### 1. The Zero-Warning & Clean Compilation Invariant
* **Zero Compiler Warnings & Zero Errors**: `flutter analyze` must strictly maintain **0 errors and 0 warnings** at all times.
* **Proactive Dead Code Elimination**: Any unreferenced methods, dead state classes, unused local variables, or obsolete imports must be pruned immediately without lingering in the codebase.
* **Asynchronous Context Safety**: Every asynchronous callback interacting with `BuildContext` must guard against unmounted widgets (`if (!mounted) return;`) to eliminate UI thread leaks and disposal crashes.

### 2. Structured Telemetry & Zero Raw `print()` Policy (`AppLogger`)
* **Structured Diagnostic Logging**: Raw `print()` statements in production services and widgets are forbidden. All diagnostic events route through `AppLogger` (`AppLogger.d()`, `AppLogger.i()`, `AppLogger.w()`, `AppLogger.e()`).
* **Automated Sensitive Data Redaction**: Passwords, API tokens, session cookies, and credentials are automatically scrubbed and redacted from log buffers.
* **In-Memory Diagnostic Ring Buffer**: A 500-entry rotating ring buffer records live system health in memory and supports 1-click diagnostic export (`AppLogger.exportLogsAsText()`) for remote field troubleshooting.

### 3. Single Source of Truth & Zero-Drift Asset Mirroring
* **Byte-for-Byte Parity Guarantee**: All four copies of `territory_reconfiguration_portal.html` (`docs/`, `assets/web/`, `installers/Territory_Reconfiguration_App/`, and `releases/legacy_versions/`) must share identical SHA-256 hashes.
* **Automated Packaging Synchronization**: Whenever web portal features or mobile app versions change, `scratch/package_installer_suite.py` and `scratch/audit_tech_debt.py` must run to verify 100% parity across executables, zips, and documentation.

### 4. Self-Healing Schema Evolution
* **Total Schema Decoupling**: Flutter models and web portal parsers never assume rigid ERPNext JSON structures.
* All incoming payloads run through defensive null-coalescing, type casting (`int`/`String`/`double`), and fallback structures via `DataSanitizer`.
* New, modified, or omitted DocType fields on ERPNext v15 will never trigger unhandled exceptions, infinite loops, or blank screens.

### 5. Automated Architectural Audit Tooling
* Run `python scratch/audit_tech_debt.py` to evaluate technical debt across:
  1. Asset Hash Parity
  2. Version Synchronization
  3. Repository Cleanliness
  4. Release Package Integrity
* The system must always achieve **Grade A+ (Zero Technical Debt)** before any release or field deployment.

## 🔐 Mandatory Web App Authentication Invariance & Zero-Regression Login Guarantee
1. **Inviolable Authentication Pipeline**:
   * The complete login and session management architecture (`handlePortalLogin`, `applyAuthenticatedUser`, `checkAuthSession`, `streamlit:render` auth message handler, `sfe_session` token cache, and `verify_erpnext_credentials`) is a sacred production invariant.
   * **NEVER alter, break, or inadvertently rename the authentication lifecycle methods** (`applyAuthenticatedUser`, `showLoginView`, `showLoginError`) when modifying or adding UI features.
2. **Dual-Environment Authentication Viability**:
   * **Streamlit Cloud Environment**: Must always support seamless single-click login, URL token caching (`?sfe_session=...`), and persistent reload recovery without throwing unhandled JavaScript exceptions or triggering infinite reloads.
   * **Local Desktop Environment (`server.py`)**: Must always support direct `/api/login` authentication and persistent session cookies.
3. **Mandatory Automated Auth Regression Check**:
   * Any change touching `territory_reconfiguration_portal.html` or `app.py` must explicitly verify that `applyAuthenticatedUser`, `checkAuthSession`, `handlePortalLogin`, and `streamlit:render` remain completely intact, syntactically correct, and free of undefined references before pushing or publishing builds.
