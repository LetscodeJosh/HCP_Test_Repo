# HCP Profiling App - Release Notes V.0.4.8 (Build 19)

**Release Date:** September 22, 2026  
**Version:** `V.0.4.8`  
**Build Number:** `19`  
**Target Backend:** ERPNext v15  
**Binaries:**
- [HCP_Profiling_V.0.4.8.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.8/HCP_Profiling_V.0.4.8.apk)
- [HCP_Profiling_Release.apk](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)

---

## 🚀 Overview & Key Highlights

### 1. 🔍 Institution Dropdown Fuzzy Search: Prefix Prioritization & Inclusive Clue Retention
- **Tier 1 Prefix Match Priority (+3000.0 pts)**:
  - When typing terms like `"Philippine"`, institutions starting with `"Philippine"` (e.g. *Philippine General Hospital*, *Philippine Heart Center*) are placed directly at the top of the dropdown.
  - Word boundary matches (+2600.0 pts) and exact word matches (+2000.0 pts) ensure predictable, natural ranking.
- **Inclusive Potential Clue Retention (Never Filterized Out)**:
  - Clues across any word in the institution name or address (e.g. *Lung Center of the Philippines*, *phil*, *pgh*, *pcmc*, *lcp*) remain in the list and are not prematurely discarded.
  - Bidirectional stemming and synonym dictionary coverage (`philippine` <-> `philippines`, `pediatric` <-> `pedia`, `center` <-> `ctr`, `hospital` <-> `hosp`, `manila`, `cebu`, `davao`).

---

### 2. 🛡️ Mandatory Workplace Location Resolution: Zero Blank Region & Province
- **Issue**: 360 of 500 institutions in ERPNext backend lack explicit province links or city links, causing submissions to have blank `region_name`, `province_name`, and `city_municipality` values.
- **Comprehensive Resolver (`LocationResolver.resolveCompleteWorkplaceLocation`)**:
  - Automatically resolves non-empty `workplace_id`, `workplace_name`, `region_id`, `region_name`, `province_id`, `province_name`, `city_id`, and `city_name`.
  - Hierarchical inference from street addresses (e.g., Taft Ave -> Manila / Metro Manila / NCR; BGC -> Taguig / Metro Manila / NCR; Ortigas -> Pasig / Metro Manila / NCR) and PSGC master data.
- **Guaranteed Population Across All Schemas**:
  - `HCP Profile Submission`: Parent doctype fields (`region_name`, `province_name`, `city_municipality`, `institution`) and child table `table_workplaces` are 100% complete and non-empty.
  - `HCP` (Doctor Master): Child table `hcp_workplace` and parent location fields are 100% complete.
  - `HCP Account`: Child table `workplace_info` is 100% complete.
  - `HcpWizardScreen`: Pre-filling, adding, editing, and final submission passes enforce non-empty fields.

---

## 🧪 Verification & Testing
- Automated unit test suite `test/fuzzy_search_test.dart` (10 tests, ALL PASSED).
- Automated regression suite `test/inst_profiling_test.dart` (4 tests, ALL PASSED).
- `flutter analyze` completed with 0 errors.
