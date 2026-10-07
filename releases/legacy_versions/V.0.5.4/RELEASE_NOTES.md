# Release Notes - V.0.5.4 (Build 30)
**Release Date:** October 2, 2026  
**APK SHA-256:** `c06579c96753d8b7c2ae4741430c9ba67424324d0a8df942fc02d3c2e2e5eb60` (57.68 MB)  
**Master HTML SHA-256:** `04d33646670abf0dc720987bb1f335064f23581b809fc6caa7cf9b45a19840fb`  

## Summary
Version **V.0.5.4** is the active enterprise release anchored with all core features and hardened with the complete 8-pillar enterprise security overhaul:

### 🛡️ Enterprise Security Overhaul
1. **Hardware-Backed Credential Storage (`FlutterSecureStorage`)**:
   - `BiometricService` encrypts all stored credentials using hardware-backed Android KeyStore / iOS Keychain (AES-GCM).
   - Automatically migrates and purges legacy plaintext `SharedPreferences` keys on initial application launch.
2. **Offline Authentication Gating**:
   - `ApiService.login()` enforces strict biometric device-owner validation during offline / airplane-mode authentication, preventing unauthorized access on lost or stolen mobile devices.
3. **Embedded Web Server Session Token Authorization**:
   - `TerritoryWebServer` (`lib/services/territory_web_server.dart`) enforces cryptographically secure ephemeral session tokens (`X-Portal-Token` / `?token=`) for all `/api/` endpoints on local area networks (LAN).
   - Loopback connections (`127.0.0.1`) remain seamless.
   - Enforces `X-Content-Type-Options: nosniff` and `X-Frame-Options: SAMEORIGIN` security headers.
4. **Android Network Security Configuration & Sandbox Hardening**:
   - `res/xml/network_security_config.xml` enforces HTTPS across all domain endpoints while permitting HTTP loopback strictly for local embedded components.
   - Android manifest enforces `android:usesCleartextTraffic="false"` and `android:allowBackup="false"`.
5. **Production Keystore Signing Configuration**:
   - `android/app/build.gradle` dynamically loads production signing certificates from environment variables (`KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, etc.) or secure secrets.
6. **Strict SSL/TLS Certificate Validation**:
   - Desktop and Streamlit Python ERPNext web proxies enforce trusted CA validation without insecure bypasses.
7. **Streamlit CORS Protection & Memory Scrubbing**:
   - `enableCORS = true` in `.streamlit/config.toml` blocks unauthorized cross-origin requests.
   - In-memory credential scrubbing (`del pwd`, `del usr`) immediately purges raw passwords upon authentication.
8. **Automated CI/CD Pipeline**:
   - GitHub Actions workflow (`.github/workflows/ci_cd.yml`) automates Bandit SAST security scans, `flutter analyze`, 64 unit & workflow tests, architectural audits, and multi-platform packaging.

### 🌟 Layout & Functional Enhancements
1. **Responsive Viewport & Sticky Table Pagination**:
   - Resolved pagination clipping on laptop screens without requiring browser zoom-out (`Ctrl -`).
   - Nested flexbox (`flex: 1 1 0; min-height: 0;`) with internal vertical scroll container (`overflow-y: auto !important;`).
   - Docked `.table-pagination-center` (`position: sticky; bottom: 12px; z-index: 30;`).
2. **Notification Auto-Dismiss & Zoom Popup Prevention**:
   - Bottom-right logged-in notification auto-dismisses completely after 4.5 seconds with zero lingering elements.
   - Gated `streamlit:render` message handling with `loginNotificationShown` state protection to eliminate popup loops when zooming in or out.
   - Dynamically synchronized Streamlit iframe height to `window.innerHeight`.
3. **High-Performance Fast Backend Authentication**:
   - Replaced single-threaded socketserver with `ThreadedTCPServer` and 6-second AbortController watchdogs.
   - Fast-path administrator login and `Connection: close` socket starvation protection.
4. **Interactive ERPNext 1:1 Territory Tree Workbench**:
   - Add Child (folders only), Edit, Rename, and Delete with live cycle archiving and doctor transfer audit trails.
