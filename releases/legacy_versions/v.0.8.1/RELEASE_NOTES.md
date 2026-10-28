# Release Notes — v.0.8.1 (Build 52)

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

