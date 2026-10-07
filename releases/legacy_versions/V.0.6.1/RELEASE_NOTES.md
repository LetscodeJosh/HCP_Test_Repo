# Release Notes • V.0.6.1

**Release Date:** October 6, 2026  
**Build Number:** 33  
**Portal Hash (SHA-256):** `38e76e6d49e6e4917f8c365ba57113e0ba7321a876a9469a9073f7b9e97c60b6`  
**APK Hash (SHA-256):** `a1e7a72ce134c0a079723e662867668769e7a30a13bb81c701a14453ed8ae698`  

---

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
