# Release Notes - HCP Profiling & Territory Management System V.0.6.5 (Build 37)

**Release Date:** October 7, 2026  
**Status:** Production Ready  

---

## 🌟 Highlights in V.0.6.5

### 1. Optional Territory Manager on Child Folders & Territory Nodes
- **Non-Mandatory Field**:
  - Removed mandatory constraint (`*`) from Territory Manager in the Add Child modal (`#treeAddModalOverlay`) and Edit modal (`#treeEditModalOverlay`).
  - Child folders (Group nodes) and initial unassigned territory nodes can be freely created without requiring an immediate manager assignment.
- **Clear "Unassigned" Input Indication**:
  - Replaced generic placeholder with an explicit `"Unassigned"` placeholder in the search box.
  - Added dedicated `(Unassigned)` choice at the very top of the Territory Manager searchable dropdown so users can explicitly set or clear manager assignments with a single click.

### 2. Intelligent Auto-Detection on Territory Code Input
- **Reactive Territory Code Detection**:
  - Bound `onTreeAddNameInput(val)` to the Territory Name / Code field in the Add Child dialog.
  - Instantly checks against existing hierarchy data (`territoryTreeData`), program territory masterlist (`programTerritories`), and sales representatives (`availableSalesPersons`).
- **Dynamic Auto-Populate & Graceful Reset**:
  - If an assigned manager exists for the typed territory code, the Territory Manager and associated User ID automatically populate.
  - If the code is unassigned or cleared (and the user hasn't manually selected another manager), the field gracefully reverts to the clean `"Unassigned"` state.

### 3. Repository-Wide Synchronization & Compliance
- Byte-for-byte asset parity maintained across all web deployment targets.
- All version files synchronized in lockstep with zero technical debt.
