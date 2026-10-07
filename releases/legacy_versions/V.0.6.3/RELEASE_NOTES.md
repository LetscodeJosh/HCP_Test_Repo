# Release Notes - V.0.6.3 (Build 35)

## 🏥 Institution Field & Workplace Search: Lag Elimination & Smart Non-Blocking Intelligence

- **Zero-Lag Typing & UI Debouncing Engine**:
  - Implemented asynchronous 200ms debouncing across `ProposeInstitutionDialog`, `HcpWizardScreen` workplace picker, and `SfeInstitutionDashboardScreen`.
  - Added O(1) fast-path candidate pre-filtering to `searchDirectoryWithDuplicateDetection` that skips 95%+ of irrelevant records before regex execution, eliminating UI thread freezing and delivering smooth 60fps typing.
- **Smart Phrase & Keyword Similarity Precision**:
  - Replaced whole-phrase Soundex collisions that previously produced unrelated recommendations (e.g. matching "St. Jude Clinic" against "St. Luke's Medical Center").
  - Added apostrophe normalization (`st lukes` matching `st. luke's`) and word stemming to accurately detect genuine facility phrases and distinctive keywords.
  - Raised suggestion confidence threshold to 65.0+ so only truly relevant facilities are suggested.
- **Complete Elimination of MedRep Lock-Up**:
  - Unlocked Step 3 Location fields (Region, Province, City, Address) immediately upon classification and workplace name entry (>= 3 chars), removing the previous `!_hasDuplicateMatches` barrier.
  - Transformed the aggressive red "Submission Locked" banner into an informative, non-blocking green suggestion banner ("💡 Similar Facilities in Masterlist").
  - Empowered MedReps to freely submit new institution proposals even when similar facilities exist in other locations, while maintaining exact identical duplicate safeguards.
