# HCP Profiling App - Master Version Bug Fix & Root Cause Analysis Index

This document consolidates all bug logs, technical root cause analyses, solutions applied, and modified files across every released version of the **HCP Profiling Mobile Application** (V.0.1.0 through V.0.4.8).

Each individual version folder under `releases/` also contains its own dedicated `RELEASE_NOTES.md` file.

---

## 📋 Version Quick Navigation

- [V.0.4.8 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.8/RELEASE_NOTES.md)
- [V.0.4.7 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.7/RELEASE_NOTES.md)
- [V.0.4.6 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.6/RELEASE_NOTES.md)
- [V.0.4.5 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.5/RELEASE_NOTES.md)
- [V.0.4.4 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.4/RELEASE_NOTES.md)
- [V.0.4.3 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.3/RELEASE_NOTES.md)
- [V.0.4.2 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.2/RELEASE_NOTES.md)
- [V.0.4.1 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.1/RELEASE_NOTES.md)
- [V.0.4.0 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.0/RELEASE_NOTES.md)
- [V.0.3.1 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.3.1/RELEASE_NOTES.md)
- [V.0.3.0 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.3.0/RELEASE_NOTES.md)
- [V.0.2.6 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.6/RELEASE_NOTES.md)
- [V.0.2.5 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.5/RELEASE_NOTES.md)
- [V.0.2.4 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.4/RELEASE_NOTES.md)
- [V.0.2.3 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.3/RELEASE_NOTES.md)
- [V.0.2.2 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.2/RELEASE_NOTES.md)
- [V.0.2.1 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.1/RELEASE_NOTES.md)
- [V.0.2.0 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.0/RELEASE_NOTES.md)
- [V.0.1.0 Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.1.0/RELEASE_NOTES.md)

---

## [V.0.4.8 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.8/RELEASE_NOTES.md)

- **Release Date:** September 22, 2026 | **Build Number:** 19

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. Dropdown Institution Fuzzy Search Lacked Prefix Grouping and Risked Clue Displacement
- **Problem Encountered:**
  - In dropdown selection of institutions, typing keyword clues such as "Philippine" did not cluster all facilities starting with "Philippine" at the front of the results, and facilities matching related clue words (like "Phil.", "Philippines", or non-prefix occurrences) risked either being displaced or omitted.
- **Root Cause Identified:**
  - In earlier versions, institutions starting with the query competed on a standard substring scoring tier (+600.0 pts). Because non-prefix institutions could accumulate token match bonuses, facilities whose names literally started with "Philippine" were not strictly guaranteed to appear at the very beginning of the dropdown list. Furthermore, unidirectional synonym lookup failed when users typed a longer keyword ("Philippine") against shortened names ("Phil.") in database records.
- **Solution Applied:**
  - Built a 2-tier prefix prioritization and bidirectional clue matching system in `LocationResolver.fuzzySearchInstitutions`:
    1. **Tier 1 Prefix Bonus (+2500.0 pts)**: Explicitly tests `instNameClean.startsWith(cleanQ)` to position all institutions starting with the query word at the very beginning.
    2. **Primary Token Prefix Bonus (+1800.0 pts)**: Tests if the institution name starts with the primary query word.
    3. **Alphabetical Secondary Tie-Breaker**: Sorts institutions in the same score tier alphabetically by facility name.
    4. **Bidirectional Synonym & Prefix Matching**: Added `exp.startsWith(nt)` and `lt.startsWith(exp)` across tokens and locations, and registered bidirectional mappings for `philippine` $\leftrightarrow$ `philippines`, `phil`, `phils`, `ph`, `filipino`, `pilipinas`.
    5. **Inclusive Clue Retention**: Guarantees any potential clue match keeps the institution in the dropdown list without premature filtering.
- **Files Modified:**
  - `lib/models/lookup_models.dart`
  - `test/fuzzy_search_test.dart`
  - `lib/constants/app_version.dart`
  - `pubspec.yaml`
  - `VERSION`
  - `CHANGELOG.md`
- **Verification Status:** Verified via `test/fuzzy_search_test.dart` asserting that searching "Philippine" places all 4 facilities beginning with "Philippine" at the front of the list (indices 0..3) in alphabetical order, followed by clue word matches ("Heart Center of the Philippines", "Phil. Orthopedic Center", "PhilHealth"). All 14 test cases passed.

---

## [V.0.4.7 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.7/RELEASE_NOTES.md)

- **Release Date:** September 22, 2026 | **Build Number:** 18

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. Overly Rigid Substring Search Filterizing Out Valid Institution Matches
- **Problem Encountered:**
  - When searching for a hospital or clinic in dropdown pickers (e.g. typing "st lukes bgc", "asian alabang", "makati med", or "delos santos"), the app returned "No matching institutions found" or completely filtered out valid candidate institutions.
- **Root Cause Identified:**
  - The previous search filter performed a rigid single-string check (`contains(query)`). When multiple words were entered, words in different fields (name vs. location) or out-of-order words failed the consecutive substring match. Furthermore, abbreviations and acronyms were ignored, causing candidates matching individual clues to be discarded.
- **Solution Applied:**
  - Built `LocationResolver.fuzzySearchInstitutions` featuring:
    1. Multi-token query parsing with apostrophe/punctuation stripping.
    2. Medical abbreviation & geographical synonym expansion.
    3. Acronym and compound word resolution.
    4. Multi-tier relevance scoring (exact phrase > acronym > all tokens matched > partial clues).
    5. Inclusive clue retention policy ensuring all potential matches remain in the dropdown list sorted by relevance score.
- **Files Modified:**
  - `lib/models/lookup_models.dart`
  - `lib/screens/hcp_wizard_screen.dart`
  - `lib/screens/doctor_masterlist_screen.dart`
  - `lib/screens/detail_screen.dart`
  - `lib/screens/list_screen.dart`
  - `lib/screens/institution_directory_screen.dart`
  - `test/fuzzy_search_test.dart`
- **Verification Status:** Verified via `test/fuzzy_search_test.dart` across 8 multi-token, acronym, and abbreviation test scenarios (PASSED).

---

## [V.0.4.6 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.6/RELEASE_NOTES.md)

- **Release Date:** September 17, 2026 | **Build Number:** 17

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. Accidental Deletion & Permanent Data Loss of Added Institutions
- **Problem Encountered:**
  - MedReps had a "Discard / Discard & Delete" button, and SFE Specialists had a "Reject & Delete Resubmission" dialog. When triggered, the institution record was permanently expunged via `DELETE /api/resource/Institution/...`, destroying audit trails and forcing reps to re-type facilities from scratch if rejected or modified.
- **Root Cause Identified:**
  - Deletion methods were wired into `_handleDeleteSubmission()` in `InstitutionApprovalsScreen` and `ApiService.rejectInstitution()` via the `isResubmission` parameter.
- **Solution Applied:**
  - Completely removed the "Discard" button and `_handleDeleteSubmission()` from `InstitutionApprovalsScreen`.
  - Replaced with exclusive, prominent **"Modify & Resubmit"** button allowing continuous edits without data loss.
  - Removed `isResubmission` deletion branch from `ApiService.rejectInstitution()`. SFE rejections now strictly transition status to `Rejected`.
- **Files Modified:**
  - `lib/screens/institution_approvals_screen.dart`
  - `lib/screens/sfe_institution_dashboard_screen.dart`
  - `lib/services/api_service.dart`
- **Verification Status:** Verified via `test/inst_profiling_test.dart` simulating continuous multi-cycle rejections without data loss (PASSED).

---

## [V.0.4.5 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.5/RELEASE_NOTES.md)

- **Release Date:** September 17, 2026 | **Build Number:** 16

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. SFE Institution Rejection Failure (HTTP 417 Workflow Permission Error)
- **Problem Encountered:**
  - When an SFE Specialist attempted to reject a proposed facility, the app displayed: *"Please verify your internet connection"*. The rejection note was saved, but the workflow state remained stuck at `Pending Approval` instead of changing to `Rejected`.
- **Root Cause Identified:**
  - In ERPNext, the `Institution WF` workflow transition strictly mandated the role `Sales Force Effectiveness`. The active SFE account (`lesantos@pims-marketing.com`) only possessed `System Manager` and `Sales Manager`, causing ERPNext to reject the transition with `HTTP 417: Not a valid Workflow Action`.
- **Solution Applied:**
  - Assigned `Sales Force Effectiveness` role to active SFE account on ERPNext.
  - Updated ERPNext's `Institution WF` to allow `System Manager` and `Sales Manager` for both `Approve` and `Reject` actions.
  - Added CSRF token handling (`ensureCsrfToken()`) and a direct `PUT` fallback in `ApiService.rejectInstitution`.
  - Replaced generic network error toasts with specific permission feedback.
- **Files Modified:**
  - `lib/services/api_service.dart`
  - `lib/screens/sfe_institution_dashboard_screen.dart`
- **Verification Status:** End-to-end rejection verified with active SFE account; state transitions cleanly to `Rejected` (PASSED).

---

## [V.0.4.4 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.4/RELEASE_NOTES.md)

- **Release Date:** September 17, 2026 | **Build Number:** 15

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. Red Rejection Remark Banners Leaking onto Approved & Pending Submissions
- **Problem Encountered:**
  - Verified doctor submissions in `Approved` or `Pending Approval` states displayed alarming red rejection remark cards in submission history lists and detail drawers.
- **Root Cause Identified:**
  - `HcpProfileSubmission.fromJson` pulled the latest Frappe timeline comment and assigned it to `rejectionRemarks` without checking if the document was actually rejected.
- **Solution Applied:**
  - Enforced strict gating (`rawDocstatus == 2 || resolvedWorkflow == 'Rejected'`). If not rejected, rejection fields are strictly set to `null`.
  - Added UI guards in `SubmissionHistoryScreen` requiring `item.isRejected && item.rejectionRemarks != null`.
- **Files Modified:**
  - `lib/models/submission.dart`
  - `lib/services/api_service.dart`
  - `lib/screens/submission_history_screen.dart`
- **Verification Status:** Verified via `test/inst_profiling_test.dart`; approved profiles retain clean presentation (PASSED).

### 2. SFE Specialists Unable to Directly Propose Missing Facilities
- **Problem Encountered:**
  - SFE Specialists discovering unlisted facilities in the field had no way to propose or add institutions directly from their hub.
- **Root Cause Identified:**
  - The SFE dashboard only supported reviewing incoming submissions with no creation action triggers.
- **Solution Applied:**
  - Added `+ Propose Institution` FAB and AppBar action buttons in `SfeInstitutionDashboardScreen` with duplicate detection, PSGC hierarchy pickers, and dual actions (`Submit for Approval` and `Submit & Approve`).
- **Files Modified:**
  - `lib/screens/sfe_institution_dashboard_screen.dart`
- **Verification Status:** SFE institution proposal and immediate approval verified end-to-end (PASSED).

---

## [V.0.4.3 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.3/RELEASE_NOTES.md)

- **Release Date:** September 17, 2026 | **Build Number:** 14

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. MedReps Blocked from Profiling Doctors at Newly Proposed Clinics
- **Problem Encountered:**
  - When a MedRep added a new clinic awaiting SFE review (`Pending Approval`), the doctor profiling wizard blocked selecting it, preventing field reps from profiling doctors during hospital visits.
- **Root Cause Identified:**
  - Validation checks in `HcpWizardScreen._showAddWorkplaceSelector` and `_showEditWorkplaceDialog` (lines 2412 & 2908) restricted workplace selection strictly to `Approved`.
- **Solution Applied:**
  - Unlocked `Pending Approval` and `Draft` facilities for doctor profiling. Only explicitly `Rejected` facilities remain blocked.
  - Implemented dynamic approval notes: `"this institution is not yet approved"` (amber hourglass) which dynamically transitions to `"this institution is now approved"` (emerald green check) upon SFE approval.
- **Files Modified:**
  - `lib/screens/hcp_wizard_screen.dart`
  - `lib/models/lookup_models.dart`
  - `lib/screens/doctor_masterlist_screen.dart`
- **Verification Status:** MedRep profiling verified with pending facility linking (PASSED).

---

## [V.0.4.2 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.2/RELEASE_NOTES.md)

- **Release Date:** September 16, 2026 | **Build Number:** 13

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. 3,900+ Master Facilities Misclassified as Rejected
- **Problem Encountered:**
  - Over 3,900 baseline healthcare facilities imported into ERPNext in `Draft` state were rendered with red rejected badges in the app, blocking doctors from linking to valid hospitals.
- **Root Cause Identified:**
  - Mobile app logic treated any facility that was not `Approved` as rejected.
- **Solution Applied:**
  - Aligned status colors directly with ERPNext Desk: `Draft` badged in Red pill, matching ERPNext Desk indicator.
  - Restored profiling linkage across all 3,990+ facilities from cached masterlist.
  - Rebuilt search filter engine with collapsible `[= Filter]` bar, dynamic counter (`Showing X of Y`), and inline `[Clear Filters]` badge.
- **Files Modified:**
  - `lib/screens/institution_directory_screen.dart`
  - `lib/services/api_service.dart`
- **Verification Status:** Verified search and filtering across 3,990+ facilities with zero UI lag (PASSED).

---

## [V.0.4.1 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.1/RELEASE_NOTES.md)

- **Release Date:** September 16, 2026 | **Build Number:** 12

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. Directory Fragmentation Across Status Tabs & Screen Space Clutter
- **Problem Encountered:**
  - Facilities were split into separate tabs (`Approved`, `Pending`, `Rejected`), and non-collapsible search filter rows consumed over 40% of vertical screen space on mobile phones.
- **Root Cause Identified:**
  - Multi-tab architecture in `InstitutionDirectoryScreen` preventing unified masterlist search.
- **Solution Applied:**
  - Removed status tabs to create a unified masterlist directory.
  - Added an animated, collapsible `[= Filter]` panel with dual triggers (AppBar action + centered quick trigger bar).
- **Files Modified:**
  - `lib/screens/institution_directory_screen.dart`
- **Verification Status:** Verified unified layout and collapsible filter bar on mobile devices (PASSED).

---

## [V.0.4.0 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.0/RELEASE_NOTES.md)

- **Release Date:** September 16, 2026 | **Build Number:** 11

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. SFE Role Administrative Parity Lockout
- **Problem Encountered:**
  - SFE Specialists encountered early return blocks when trying to view doctor masterlists or program submission summaries.
- **Root Cause Identified:**
  - Restrictive role checks in `ApiService.fetchDoctors()`, `fetchHcpAccounts()`, and `fetchSubmissions()`.
- **Solution Applied:**
  - Removed early return blocks granting SFE full administrative parity with System Manager while maintaining dedicated SFE Approval Hub separation.
  - Built dedicated `InstitutionDirectoryScreen` with desk list alignment.
- **Files Modified:**
  - `lib/services/api_service.dart`
  - `lib/screens/institution_directory_screen.dart`
- **Verification Status:** SFE administrative access and program switcher verified (PASSED).

---

## [V.0.3.1 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.3.1/RELEASE_NOTES.md)

- **Release Date:** September 16, 2026 | **Build Number:** 10

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. Misleading Navigation Menu ("Institution Approvals" Shown to MedReps)
- **Problem Encountered:**
  - MedReps saw "Institution Approvals" in the drawer menu, implying they approve facilities rather than submit/propose them.
- **Root Cause Identified:**
  - Menu item naming lacked role-based semantic clarity.
- **Solution Applied:**
  - Renamed drawer navigation item and screen titles to **"Institution Submission"** (MedRep: `Track & Resubmit`, SFE: `SFE Approval Hub`). Updated all in-app wizard guidance banners and error messages.
- **Files Modified:**
  - `lib/screens/components/app_drawer.dart`
  - `lib/screens/institution_approvals_screen.dart`
  - `lib/screens/sfe_institution_dashboard_screen.dart`
- **Verification Status:** Verified UI drawer titles across MedRep and SFE accounts (PASSED).

---

## [V.0.3.0 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.3.0/RELEASE_NOTES.md)

- **Release Date:** September 16, 2026 | **Build Number:** 9

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. Duplicate Facility Submissions & Inability to Profile Pending Clinics
- **Problem Encountered:**
  - Reps repeatedly proposed identical clinics already in the masterlist; reps were blocked from doctor profiling if a clinic was unapproved.
- **Root Cause Identified:**
  - Lack of autocomplete duplicate checking during institution creation; strict gating blocking pending clinics.
- **Solution Applied:**
  - Built smart predictive autocomplete with real-time duplicate detection dropdown across ~7,000 facilities with 1-tap auto-fill.
  - Provisioned backend Custom Field `workplace_approval_note` on `HCP Account` with Frappe client script dynamically setting amber/green status descriptions.
- **Files Modified:**
  - `lib/screens/institution_approvals_screen.dart`
  - `lib/services/api_service.dart`
  - `lib/models/hcp_account.dart`
- **Verification Status:** Duplicate warning banner and dynamic note updates verified (PASSED).

---

## [V.0.2.6 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.6/RELEASE_NOTES.md)

- **Release Date:** September 15, 2026 | **Build Number:** 8

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. Unapproved Custom Clinics Leaking into Doctor Profiles
- **Problem Encountered:**
  - Newly added custom facilities awaiting approval (e.g. `INST-07990`) were selectable in doctor profiling before SFE approval.
- **Root Cause Identified:**
  - Inverted boolean check in `HcpWizardScreen._hasUnapprovedWorkplaces` and unrestricted registration in `LocationResolver`.
- **Solution Applied:**
  - Hardened `Institution.isApprovedForProfiling` and `LocationResolver.registerInstitutions` to strictly filter for approved facilities (`workflow_state == 'Approved'` or `docstatus == 1`).
- **Files Modified:**
  - `lib/screens/hcp_wizard_screen.dart`
  - `lib/services/api_service.dart`
- **Verification Status:** Verified unapproved clinics are locked from wizard selection (PASSED).

---

## [V.0.2.5 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.5/RELEASE_NOTES.md)

- **Release Date:** September 15, 2026 | **Build Number:** 7

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. Missing Region Field Causing Discrepancy with ERPNext DocType
- **Problem Encountered:**
  - New facility proposals only submitted Province and City, leaving Region blank in ERPNext.
- **Root Cause Identified:**
  - Mobile proposal form lacked Region selection and mapping to ERPNext `Institution` schema.
- **Solution Applied:**
  - Added dedicated Region selector with bidirectional auto-resolution in `LocationResolver` (Province auto-selects Region; Region filters Provinces). Linked official 10-digit PSGC region codes.
- **Files Modified:**
  - `lib/screens/institution_approvals_screen.dart`
  - `lib/services/api_service.dart`
- **Verification Status:** Verified Region, Province, and City persist cleanly to ERPNext (PASSED).

---

## [V.0.2.4 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.4/RELEASE_NOTES.md)

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. MedRep "Discard" Not Deleting Records on ERPNext Server
- **Problem Encountered:**
  - Rep tapped Discard and facility disappeared locally, but ERPNext retained the record on the server (HTTP 403 Forbidden).
- **Root Cause Identified:**
  - ERPNext's `Custom DocPerm` for `Sales User` on `Institution` had `delete: 0`. App had premature cache-purge and lacked CSRF token handling.
- **Solution Applied:**
  - Granted `delete: 1` on ERPNext `Custom DocPerm` for `Sales User`; added `ensureCsrfToken()` in `deleteInstitution()`; validated HTTP responses (200, 202, 204) before local cache deletion.
- **Files Modified:**
  - `lib/services/api_service.dart`
  - `lib/screens/institution_approvals_screen.dart`
- **Verification Status:** Verified server deletion returning HTTP 202 from Frappe (PASSED).

---

## [V.0.2.3 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.3/RELEASE_NOTES.md)

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. "Faking Submissions" — App Concealed Server Validation Failures
- **Problem Encountered:**
  - App reported successful facility proposal, but facilities never appeared in the SFE approval queue.
- **Root Cause Identified:**
  - Deceptive client-side mock fallback in `api_service.dart` caught HTTP 417 `LinkValidationError` and silently returned mock data without persisting to ERPNext.
- **Solution Applied:**
  - Removed mock fallback; added strict 10-digit PSGC location validation with automatic fallback; surfaced genuine server exceptions.
- **Files Modified:**
  - `lib/services/api_service.dart`
  - `lib/screens/institution_approvals_screen.dart`
- **Verification Status:** Server persistence verified; proposals appear in SFE queue (PASSED).

---

## [V.0.2.2 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.2/RELEASE_NOTES.md)

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. Re-rejected Submissions Lingering Indefinitely on Server
- **Problem Encountered:**
  - Proposals that were resubmitted and rejected a second time remained in the database indefinitely.
- **Root Cause Identified:**
  - Rejection handler only flagged status without evaluating resubmission cycles, causing multi-cycle rejected records to accumulate as database clutter.
- **Solution Applied:**
  - Implemented automatic deletion of rejected resubmissions (`is_resubmission == 1`) and introduced Discard option for unfixable proposals.
- **Files Modified:**
  - `lib/services/api_service.dart`
  - `lib/screens/institution_approvals_screen.dart`
- **Verification Status:** Verified second rejection cleanup (PASSED).

---

## [V.0.2.1 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.1/RELEASE_NOTES.md)

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. Newly Submitted Facilities Not Appearing in SFE Queue (HTTP 417)
- **Problem Encountered:**
  - Facilities proposed by MedReps failed to appear on SFE Specialist's dashboard with HTTP 417 `WorkflowPermissionError`.
- **Root Cause Identified:**
  - App attempted to insert records directly as `'workflow_state': 'Pending Approval'`, violating ERPNext workflow rules requiring initial insertion in `Draft`.
- **Solution Applied:**
  - Implemented two-stage insert flow: created in `Draft` state first, then immediately applied `Submit for Approval` workflow transition.
- **Files Modified:**
  - `lib/services/api_service.dart`
- **Verification Status:** SFE approval queue immediately displays new submissions (PASSED).

---

## [V.0.2.0 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.2.0/RELEASE_NOTES.md)

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. Uncontrolled Institution Creation & Lack of SFE Governance
- **Problem Encountered:**
  - New institutions were created without administrative review, leading to duplicate and unverified healthcare clinics in doctor profiles.
- **Root Cause Identified:**
  - Absence of an approval lifecycle state machine in the mobile client allowed directly committed unverified clinics into the masterlist.
- **Solution Applied:**
  - Introduced SFE Institution Approval System, strict gating architecture (`isApprovedForProfiling == false`), dedicated MedRep `Institution Approvals` hub, and role-based SFE isolation.
- **Files Modified:**
  - `lib/screens/institution_approvals_screen.dart`
  - `lib/screens/sfe_institution_dashboard_screen.dart`
  - `lib/services/api_service.dart`
- **Verification Status:** Role isolation and gating verified (PASSED).

---

## [V.0.1.0 - Release Notes](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.1.0/RELEASE_NOTES.md)

### 🐛 Bug Fixes & Technical Root Cause Analysis

& Technical Root Cause Analysis

### 1. Doctor Record Duplication on Every Profile Update
- **Problem Encountered:**
  - Re-profiling an existing doctor created a duplicate `HCP` record instead of updating the existing doctor record.
- **Root Cause Identified:**
  - Lack of separation between universal doctor identity and program-specific commercial affiliation.
- **Solution Applied:**
  - Designed the Two-Tier Masterlist architecture (`HCP` Universal vs `HCP Account` Program Affiliation) enabling in-place doctor profile updates.
- **Files Modified:**
  - `lib/models/hcp.dart`
  - `lib/models/hcp_account.dart`
  - `lib/services/api_service.dart`
- **Verification Status:** In-place updating verified without duplicate creation (PASSED).

### 2. Submission Denominator Count Inaccuracies Across Roles
- **Problem Encountered:**
  - Doctor account denominator calculations were mismatched between MedRep, Manager, and Admin views.
- **Root Cause Identified:**
  - Query filters calculated total doctor denominators using unsegmented masterlist counts rather than role-scoped territory assignments.
- **Solution Applied:**
  - Re-architected denominator queries per user role.
- **Files Modified:**
  - `lib/screens/doctor_account_screen.dart`
- **Verification Status:** Count alignment verified (PASSED).

### 3. Raw PSGC Technical Codes Rendered in UI
- **Problem Encountered:**
  - App displayed raw technical codes (e.g. `133900000`) instead of clean municipality names.
- **Solution Applied:**
  - Built human-readable PSGC translation dictionary in `LocationResolver`.
- **Files Modified:**
  - `lib/services/location_resolver.dart`
- **Verification Status:** Human-readable city/province names verified (PASSED).

---
