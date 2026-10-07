# HCP Profiling App • Release Notes V.0.5.0 (Build 20)

**Release Date:** 2026-09-29  
**Active Release:** `V.0.5.0`  
**Build Number:** `20`  
**Artifact Size:** 59,946,493 bytes  
**SHA-256 Checksum:** `E6327AC32CAF2E5CBB41FEFFF3E60E57D0DCA6EEE5ED8074F83DC04F0E3A742F`

---

## 🌟 Executive Summary
Version **V.0.5.0** represents the official baseline release incorporating the new **Dynamic Monthly Validity Lifecycle Management & Automated Cycle Rollover** alongside the staged **Territory Reconfiguration Web Portal**:
1. **Dynamic Monthly Validity Lifecycle**: Automatically computes exact first day (`YYYY-MM-01`) and last day (`YYYY-MM-DD`, accounting for 28/29/30/31-day months and leap years) from active calendar time.
2. **Automated Active Cycle Rollover**: Upon transition to a new calendar month without staged submissions, the app auto-rolls forward active doctor affiliations from the latest historical month into the current active cycle with full `(Carried Over)` lineage tracking.
3. **Zero-Overwrite Historical Integrity**: Merges and updates strictly target current active month records in `HCP Account`, keeping historical cycle affiliations immutably preserved in ERPNext.
4. **Dedicated Territory Reconfiguration Web Portal**: High-precision web portal matching the HCP Profiling dark blue and white UI, powered by an embedded local web server (`TerritoryWebServer` on port 8765) for instant access on device browsers or laptop Wi-Fi. Features pure-text buttons, hideable sidebar, live ERPNext DocType binding, zero dummy accounts, and blank historical cycle columns.
5. **Backend Workflow Status**: *Web portal execution operates in staged pre-flight mode; live database execution will be activated upon IT Manager workflow sign-off.*

---

## 📦 Verified Binaries & Direct Links
- [HCP_Profiling_V.0.5.0.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/version%20releases/V.0.5.0/HCP_Profiling_V.0.5.0.apk)
- [HCP_Profiling_Release.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)
