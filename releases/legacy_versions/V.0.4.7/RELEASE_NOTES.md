# Release Notes - HCP Profiling App V.0.4.7 (Build 18)

**Release Date:** September 22, 2026  
**Build Number:** 18  
**Target ERPNext Version:** v15  
**Version Increment:** Patch (+1 Patch)

---

## 🌟 Key Updates & Architectural Alignment

### 🔍 1. Multi-Clue Fuzzy Search for Institution Dropdown Pickers
- **User Directive**:
  - *"on the dropdown selection of institution (improvement and enhancement the institution dropdown fuzzy search), when searching all potential clue of any word of that particular institution should be in the dropdown list and not be filterized its results. do it as far more accurate"*
- **Fuzzy Multi-Clue Relevance Scoring**:
  - Implemented `LocationResolver.fuzzySearchInstitutions` which evaluates each institution against every token and clue word typed by the user.
  - Normalized strings strip apostrophes (e.g. `Luke's` $\rightarrow$ `Lukes`) and punctuation to prevent syntax mismatch.
  - Generates bidirectional synonym and abbreviation expansions (e.g., `med` $\leftrightarrow$ `medical`, `hosp` $\leftrightarrow$ `hospital`, `ctr` $\leftrightarrow$ `center`, `st` $\leftrightarrow$ `saint`, `gen` $\leftrightarrow$ `general`, `bgc` $\leftrightarrow$ `bonifacio/global/taguig`).
  - Resolves acronyms (e.g. `pgh` $\rightarrow$ Philippine General Hospital, `slmc` $\rightarrow$ St. Luke's Medical Center, `mmc` $\rightarrow$ Makati Medical Center).
  - Resolves compound words (e.g. `delos` $\leftrightarrow$ `de los`).
  - Evaluates location tokens (city, municipality, province, street address) so location clues seamlessly match the institution.
- **Zero Premature Filtering ("Not Filterized Its Results")**:
  - Any institution matching any clue word or token remains in the dropdown list.
  - The list is sorted strictly by multi-clue relevance score so that exact and multi-token matches appear right at the top, while partial clue matches remain accessible below.
- **Integrated Across All App Selection Surfaces**:
  - **Doctor Profiling Wizard (`HcpWizardScreen._showInstitutionSearchDialog`)**: Primary workplace picker modal in Step 2 when adding or editing doctor workplaces.
  - **Doctor Masterlist Screen (`DoctorMasterlistScreen._showAddDoctorDialog`)**: Searchable bottom sheet picker for assigning workplaces to new doctor master records.
  - **Detail Screen (`SearchableInstitutionPicker`)**: Company and institution selection bottom sheet.
  - **List Screen (`_showInstitutionFilterPicker`)**: Institution filter bottom sheet for COREnergy Engage and submissions.
  - **Institution Directory Screen (`InstitutionDirectoryScreen._getFilteredAndSorted`)**: Name and location filter token matching.

---

## 🐛 Bug Fix Log & Technical Root Cause Analysis

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

## 🧪 Verification & Testing
- **Unit Testing**:
  - `test/fuzzy_search_test.dart`: 8 unit tests passed (0 failures).
  - `test/inst_profiling_test.dart`: 4 regression tests passed (0 failures).
- **Code Analysis**: `flutter analyze` completed cleanly with zero compilation errors.
- **Release Build**: Built with `flutter build apk --release` targeting `android-arm64`.

---

## 📦 Release Artifacts
- **Universal Release APK:** [`releases/HCP_Profiling_Release.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)
- **Versioned APK:** [`releases/V.0.4.7/HCP_Profiling_V.0.4.7.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/V.0.4.7/HCP_Profiling_V.0.4.7.apk)
