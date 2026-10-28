# Release Notes — `v.0.8.2` (Build `53`)

**Release Date**: October 28, 2026

## Key Fixes & Improvements
1. **1,328 Embedded Baseline Institutions (`BASELINE_INSTITUTIONS_COMPACT`)**:
   - Pre-seeded all 1,328 ERPNext `Institution` records directly inside `territory_reconfiguration_portal.html` so the **Institution Approvals** (`#tab-institutions`) workbench displays all 1,328 records immediately (`0ms`) without ever rendering a blank/0-record table.
2. **Restored `Draft` -> `Pending Approval` (`Pending SFE Review`) Mapping**:
   - Unapproved `Draft` / `Pending Approval` records (`docstatus == 0`) now populate `Pending SFE Review` (`1,328`) by default and transition to `Approved Directory` (`Approved`) or `Pending DSM` (`Pending DSM Approval`) upon SFE approval via the **`Actions ⌄`** dropdown menu.
3. **PSGC 1,655-City Dropdown & ERPNext Column Alignment**:
   - Fixed `initPsgcLookupIndex()` city type matching (`'City' || 'City / Municipality'`), trailing code suffix resolution (`1381400000C` -> `San Juan City`), and `Institution` REST field names (`street_address`, `barangay_name`).
4. **Hardened Streamlit Background Auto-Sync (`app.py`)**:
   - Guarded `st.secrets` via `get_safe_secret()` to eliminate `StreamlitSecretNotFoundError` and added `@st.cache_resource` session opener persistence.
