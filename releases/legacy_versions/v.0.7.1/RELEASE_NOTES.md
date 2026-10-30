# Release Notes — HCP Profiling App `v.0.7.1` (Build 49)

**Release Date**: October 27, 2026  
**Build Number**: `49`  
**Full Version**: `v.0.7.1+49`

---

## 🛡️ 6 Key Enterprise Security Enhancements (`SEC-01` – `SEC-08`)

1. **Protected Local Cache Directory & iOS File Sharing Lockdown (`SEC-01`)**:
   - Disabled `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` (`<false/>`) in `ios/Runner/Info.plist` to block external extraction of cached doctor PII and SQLite queues via Finder/iTunes or the iOS Files app.
   - Migrated local JSON caches in `ApiService` from `getApplicationDocumentsDirectory()` to `getApplicationSupportDirectory()` with automatic seamless fallback migration for existing field devices.
2. **Server-Side Session Revocation & Cross-User Cache Isolation (`SEC-02`)**:
   - `ApiService.logout()` now dispatches `/api/method/logout` to ERPNext v15, stops any running `TerritoryWebServer`, resets `_sfeModeOverride`, clears in-memory lists (`_cachedDoctors`, `_cachedHcpAccounts`, `_cachedSubmissions`, `_cachedInstitutions`), and flushes `AppLogger` telemetry.
   - Added `_ensureUserCacheIsolation()` during login to purge user-scoped cache files when a different user logs into a shared mobile device while preserving offline resilience for the same user.
3. **Elimination of Hardcoded Service Account Fallback Credentials (`SEC-03`)**:
   - Removed the hardcoded `'pims@admin'` fallback password from `installers/Streamlit_Deployment/app.py` and `installers/Territory_Reconfiguration_App/server.py`, reading service credentials strictly from environment variables or `st.secrets` and binding the authenticated user's session opener.
4. **Local On-Device QR Code Renderer & Territory Web Server Hardening (`SEC-04`)**:
   - Implemented `LocalQrCodeWidget` (`lib/screens/components/local_qr_code_widget.dart`), a zero-dependency ISO/IEC 18004 QR Code encoder and `CustomPainter`, rendering QR codes 100% locally in `TerritoryPortalLauncherScreen` and `SelfServiceQrScreen` without calling `api.qrserver.com`.
   - Replaced wildcard CORS (`Access-Control-Allow-Origin: *`) in `TerritoryWebServer` with strict origin validation, issued an `HttpOnly; SameSite=Strict` cookie (`pims_portal_token`), and blocked cross-site/foreign-origin requests on `127.0.0.1`.
5. **Strict Role-Based Access Control (RBAC) Guardrails (`SEC-05` & `SEC-06`)**:
   - Guarded `ApiService.toggleSfeMode()` so only `UserPosition.admin` and `UserPosition.sfe` can toggle SFE mode, removed the unused `setUserPosition()` mutator, and removed the broad `@profinsights.biz` email substring escalation in `_applyPositionFromRoleProfile()`.
6. **Zero Raw `print()` Telemetry & Comprehensive Log Redaction (`SEC-07`)**:
   - Expanded `AppLogger` redaction patterns to scrub JSON-serialized credentials (`"pwd"`, `"password"`, `"sid"`, `"csrf_token"`, `"api_secret"`) and `Authorization: Bearer/token` headers, and routed all remaining diagnostic `print()` calls across `lib/` through `AppLogger`.

## ⚡ Ultra-Smooth Instant Directory Search Optimization
- **$O(1)$ Hash Map Doctor Lookup in `DoctorAccountScreen`**:
  - Replaced repeated $O(N)$ linear scans (`_doctors.firstWhere(...)`) during search filtering and sorting with an $O(1)$ `_doctorsById` hash map lookup, and expanded the search filter to match Doctor Name, Doctor ID, Specialty, Workplace, and Territory instantaneously.
- **Pre-Tokenized Fast Filtering in `DoctorMasterlistScreen`**:
  - Pre-computed program doctor token sets outside the per-keystroke filter loop and short-circuited search queries prior to fuzzy token matching.

