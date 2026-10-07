# Release Notes - HCP Profiling & Territory Management System V.0.6.4 (Build 36)

**Release Date:** October 7, 2026  
**Status:** Production Ready  

---

## 🌟 Highlights in V.0.6.4

### 1. Resigned Representative Doctor Handover Directive
- **1-Click "Tag Resigned & Handover" Action**:
  - Accessible directly from Table Grid View row actions and the Territory Tree View editor modal (`#treeEditModalOverlay`).
  - Automatically identifies previous representative's doctor roster and presents structured directive banner options.
- **Dedicated Handover Prompt Modal (`#resignedHandoverPromptModalOverlay`)**:
  - Displays original territory code, previous representative name, and total covered doctor headcount.
  - Allows instant expansion of covered doctor preview list with specialization and workplace information.
  - Supports 1-Click **"Quick Resign & Auto-Merge Doctors"** which updates the territory manager, merges 100% of previous doctors to the newly assigned MedRep, records detailed audit trail logs, and triggers background ERPNext API updates.
  - Provides a **"Custom Transfer Workbench"** path for selective doctor-by-doctor reassignment.

### 2. Two-Pane Doctor Transfer Workbench Search & Debouncing
- **Real-Time Doctor Search Filtering**:
  - Independent search inputs on both Target Territory and Source Territory panes.
  - Instant debounced filtering allows SFE leads to quickly isolate doctors by name, hospital, specialization, or HCP ID.
- **Interactive Handover Directives**:
  - Dynamic advisory banner highlighting Source Rep, Target Rep, Territory Code, and pending transfer count.
  - Quick action buttons: **"Merge All Doctors"** and **"Clear All"** for streamlined bulk operations.

### 3. Bidirectional Persistence & Synchronization
- Local storage persistence ensures zero data loss across browser reloads.
- Streamlit message dispatch (`streamlit:setComponentValue`) synchronizes handover state with cloud hosting.
