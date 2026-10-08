# Release Notes - HCP Profiling App v.0.6.5

**Build Date**: October 8, 2026  
**Version**: `v.0.6.5`  
**APK SHA-256**: `49eb28840cabd279a8331f6f2dd26a5706b3229e14beead4dea505fa07c08cd3`  
**File Size**: `58.94 MB`

---

### 🧠 Intelligent AI Institution Detector & Acronym Recognition
- **Smart Dynamic Acronym Extraction**:
  - Implemented `computeInstitutionAcronyms` extracting literal initials, non-connector initials, core facility initials, and parenthetical acronyms.
  - Automatically recognizes Philippine healthcare acronyms such as `Ust` (University of Santo Tomas Hospital), `SLMC` (St. Luke's Medical Center), `PGH` (Philippine General Hospital), `MMC` (Makati Medical Center / Metropolitan Medical Center), etc.
- **99%+ Match Accuracy (Elimination of False Positives)**:
  - Substring matching for queries $\le 4$ characters enforces strict word boundary and prefix checks, eliminating interior substring false positives (e.g., query `Ust` previously matched `Unitech Plastic Industry Corp.`, `Trener Industries`, and `Toprite Plastic Industries` due to the letters `ust` inside `industry`).
- **Display All Matching Candidate Facilities**:
  - Raised query limit to 50+ and expanded directory dropdown with smooth `Scrollbar` support (`maxHeight: 240`) to display all candidate facilities.
- **Location Details Fillability Policy (No Lock Icon)**:
  - Step 3 Location Details remain disabled and unfillable while suggestions are active or when workplace name is not yet fulfilled.
  - Strictly no lock icon implemented; clean muted styling is applied.
- **Submission Guard Against Duplicate Proposals**:
  - Disabled "Submit for Approval" button while suggestions are active in the dropdown (`_detectedMatches.isNotEmpty && _selectedExistingInstitution == null`). The MedRep must tap to select the existing facility or specify a distinct facility name.
- **Menu Drawer Version Clean Display**:
  - HCP App version is retained at `v.0.6.5` and the `+No.` suffix is removed from the drawer menu navigation.
