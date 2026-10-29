# Release Notes — v.0.8.3 (Build 54)
**Release Date:** October 29, 2026

## Highlights
1. **Header Text Simplified (`Institution Approval`)**:
   - Replaced `SFE Institution Approval & Masterlist Governance Workbench` with **`Institution Approval`**.
2. **Uncluttered 5-Window KPI Navigation**:
   - Removed the redundant 5 status filter pill buttons inside the search bar (`#sfeInstStatusPillGroup`) so the search & filter bar remains spacious and unconstrained.
   - Configured the 5 top KPI cards (`Institution Directory`, `Pending DSM Approval`, `Approved Masterlist`, `Rejected Proposals`, `MedRep Certified`) with active selection states (`.sfe-inst-nav-card.active`) to navigate seamlessly through the workflow.
3. **`Institution Directory` Label & ERPNext `"Draft"` Status Alignment**:
   - Renamed the first KPI card from `Pending SFE Review` to **`Institution Directory`** (`Available in ERPNext Institution DocType`).
   - Updated the table `STATUS` column and internal state normalization to display **`Draft`** (matching the ERPNext `Institution` DocType state 1:1).
4. **Removed `"LINKED DOCTOR & SUBMITTER"` Column**:
   - Removed the `LINKED DOCTOR & SUBMITTER` column from the Institution Approval table for a cleaner 5-column layout.

