# Release Notes — v.0.8.0 (Build 51)

## [v.0.8.0] - 2026-10-28

### 🏥 SFE Institution Approval & Masterlist Governance Workbench in Territory Reconfiguration Web App
- **Dedicated SFE Web Institution Approval Workbench (`#tab-institutions`)**:
  - Embedded the complete SFE Institution Approval, Normalization, Duplicate Remapping, and Rejection Workbench directly inside the **Territory Reconfiguration Web App** (`docs/territory_reconfiguration_portal.html`, `installers/Territory_Reconfiguration_App/`, and `installers/Streamlit_Deployment/app.py`) so SFE Specialists can govern all MedRep-discovered institutions from their desktop/laptop without requiring a tablet/iPad.
  - Added 5 interactive KPI cards (`Pending SFE Review`, `Pending DSM Approval`, `Approved Masterlist`, `Rejected Proposals`, `MedRep Certified`), status filter pills, ownership/type filters, multi-field search, and CSV export.
  - Built 4 governance modals: **Normalize & Standardize Modal** (Proper Case formatter, `Government`/`Private` ownership, `Hospital`/`Clinic` type, dynamic service capabilities, 60-second concurrency edit lease, and cascading 1,772-row official PSGC Region -> Province -> City/Municipality dropdowns), **Reject Institution Modal** (mandatory reason + preset chips), **Remap Duplicate Modal** (searchable canonical `Approved` `INST-XXXXX` picker), and **Audit Trail Modal**.
- **Seamless Real-Time Bidirectional Sync Between HCP Mobile App & Web Portal**:
  - Upgraded `ApiService.fetchInstitutions()`, `proposeNewInstitution()`, and `resubmitRejectedInstitution()` in `lib/services/api_service.dart` with schema-resilient `fields=["*"]` queries and `<!--PIMS_META:{...}-->` Frappe `Comment` envelope hydration so 100% of governance attributes sync across Mobile and Web regardless of custom ERPNext column state.
  - Added 15-second background auto-sync timers to `InstitutionDirectoryScreen` and `InstitutionApprovalsScreen` on the Mobile App and `initSfeInstitutionWorkbench()` on the Web App.
  - Aligned the Mobile App exclusively for MedRep Institution Discovery, Accuracy Certification, Status Tracking, and Resubmission (up to 2 attempts), while moving SFE Institution Approval & Normalization exclusively to the Territory Reconfiguration Web App.

---

