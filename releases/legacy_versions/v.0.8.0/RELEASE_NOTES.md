# Release Notes - v.0.8.0 (Build 51)

**Release Date:** October 30, 2026

## Highlights
- **DPA of 2012 Compliant Consent Naming (`<Company *> <Branch>`)**:
  - Connected Step 1 Privacy Notice & Consent directly to the logged-in user's ERPNext `Employee` DocType (`Company *` mandatory field and `Branch` field).
  - Replaced legacy `<Company Acronym> <Program Name>` strings (e.g., `PMII RiteMed`) with the Compliance-approved `<Full Company Name> <Branch Acronym>` format (e.g., `Professional Insights Marketing Services RTMD`, `Professional Marketing Insights Inc. TPPI - Pedia`).
- **SFE Institution Approval Workbench (`#tab-institutions`)**:
  - 5 KPI Navigation Windows (`Institution Directory`, `Pending DSM Approval`, `Approved Masterlist`, `Rejected Proposals`, `MedRep Certified`) with theme-matched hover & active borderlines.
  - Pre-hydrated 1,328 ERPNext `Institution` records (`Draft` status alignment) and unified `Actions v` row dropdown menu.
