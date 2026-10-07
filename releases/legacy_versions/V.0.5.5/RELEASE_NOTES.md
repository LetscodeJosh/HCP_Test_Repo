# Release Notes - HCP Profiling & Territory Reconfiguration Suite V.0.5.5 (Build 31)

**Release Date:** October 5, 2026  
**Status:** Production Ready (Grade A+ Technical Debt Verification)  
**APK SHA-256:** `33ba56af95898b003c7ffae4d641376d6b44c5c019b985fb52d2afe809e47541` (57.68 MB)  
**Portal HTML SHA-256:** `a0b518f85cc8863f81232052bd7d7e49002f1ab32e7e9c67533b8fc6b1056422`  

---

### 1. User Account Full Name Subtitle Display
- Updated the User Account search dropdown menu in Territory Add, Edit, and Management modals to display the true, registered **Full Name** from ERPNext live `User` doctype (e.g., `lesantos@pims-marketing.com` shows subtitle `Leonniel Santos`, `leritargieian@gmail.com` shows subtitle `Argie Adaptar Lerit`, `jptan@profinsights.biz` shows subtitle `Joshua Tan`, etc.) matching the live ERPNext user directory 1:1.
- Injected verified active users into baseline dataset and synchronized with live ERPNext database.

### 2. Live ERPNext User Masterlist Integration
- Added `fetch_live_users(opener)` in `app.py` fetching up to 3,000 live users concurrently via multi-threaded ThreadPoolExecutor during login.
- Streamlit component passes `live_users` to the frontend with persistent cross-refresh token caching.

### 3. Table Grid & Territory Tree Unified Database Reflection
- Implemented `syncProgramTerritoriesWithTree()` in the web app, ensuring that every simulation (Add Child/New Territory, Edit Parent/Manager/User, Rename, and Delete) performed in Table Grid View or Territory Tree View immediately updates the local model, persists to cache, and dispatches directly to the ERPNext backend.
- Hardened backend `execute_tree_action` with automatic fallback retry on `tree_add` and `tree_edit` if manager links trigger validation constraints, guaranteeing that all territory mutations reflect live in the ERPNext database (`dev.pmii-marketing.com`).
- Both views render in synchronized lockstep upon every user action and ERPNext backend feedback event.

---
### Artifact Verification
- **Release APK:** [`releases/HCP_Profiling_Release.apk`](../../HCP_Profiling_Release.apk)
- **Version APK:** [`HCP_Profiling_V.0.5.5.apk`](HCP_Profiling_V.0.5.5.apk)
- **Setup ZIP:** [`Territory_Reconfiguration_Setup.zip`](Territory_Reconfiguration_Setup.zip)
- **Setup EXE:** [`Territory_Reconfiguration_Setup.exe`](Territory_Reconfiguration_Setup.exe)
