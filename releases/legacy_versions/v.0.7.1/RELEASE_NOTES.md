# Release Notes - HCP Profiling App v.0.7.1 (Build 46)

**Release Date:** October 18, 2026  
**Binary Packages:**
- Android Release APK: [`HCP_Profiling_V.0.7.1.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/legacy_versions/v.0.7.1/HCP_Profiling_V.0.7.1.apk)
- Root Production APK: [`HCP_Profiling_Release.apk`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/HCP_Profiling_Release.apk)
- Territory Setup EXE: [`Territory_Reconfiguration_Setup.exe`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/Territory_Reconfiguration_Setup.exe)
- Territory Setup ZIP: [`Territory_Reconfiguration_Setup.zip`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/releases/Territory_Reconfiguration_Setup.zip)

---

## 🌟 Executive Summary

Version **v.0.7.1** introduces a critical suite of enterprise usability, form security guardrails, multi-program corporate consent adaptation, and a human-centric redesign of the change summary:

1. **Doctor Search Redundancy Pruned**: Eliminated the redundant "+ Add as New Doctor" link from inside the Search HCP masterlist lookup dialog. Step 2 cleanly separates masterlist searching from new doctor registration.
2. **Dynamic Multi-Program Consent System**: The Step 1 consent agreement clause and privacy notices now dynamically resolve based on the active logged-in program (e.g. `PMII Abbott Diabetic Care (ADC)`, `PMII Bayer`, `PMI Fonterra`, `PMII Galderma`, etc.), replacing static generic references with authentic corporate identity clauses.
3. **Interactive & Guarded Cancel Doctor Action**: Replaced the small text link with an elevated, interactive outlined button (`Icons.close_rounded`) paired with an explicit confirmation dialog. The button is intelligently guarded: it only appears when all mandatory fields of Step 2 are fulfilled, keeping the UI clean and distraction-free.
4. **Step Progression & Tab Security Guardrails**: Tabs are sequentially guarded: Step 2 requires Step 1 completion (consent + signature/photo), while Step 3 and Changes tabs require Step 2 completion. Tapping locked tabs presents clear feedback SnackBars.
5. **Human-Centric Changes Summary (Zero Raw JSON Monospace)**: Replaced the developer-style JSON block with an executive, human-readable summary card grouping Basic Information changes, Specializations, Workplaces, Contact Channels, Survey Detailing, and Submission Audit Metadata.
6. **Task-Specific "Add Row" Button Labels**: Updated all generic "Add Row" buttons to context-specific action labels (`+ Add Specialization`, `+ Add Institution`, `+ Add Contact/Email`).
7. **Refined Mandatory Field Styling & Birth Date Cleanup**: The mandatory indicator note is styled in vibrant red (`#DC2626`). Name fields feature clean slate borders with red asterisk indicators, and the `(Optional)` tag has been removed from Birth Date.

---

## 🚀 Key Features & Architectural Enhancements

### 1. Doctor Search Redundancy Elimination
- **Context-Specific Search**: The "+ Add as New Doctor" action button inside the doctor search modal (`_showHcpSelectorModal()`) has been pruned.
- **Workflow Clarity**: The search modal strictly queries and selects existing doctors from the universal HCP masterlist.
- **New Doctor Dedicated Flow**: New doctor registrations are initiated exclusively through the "+ Add New Doctor" card in Step 2.

### 2. Program-Specific Dynamic Consent Formulation
- **Automatic Corporate Branch Detection**: Step 1 queries the active logged-in program and resolves the official corporate entity:
  - `Abbott Diabetes Care` $\rightarrow$ `PROFESSIONAL INSIGHTS MARKETING SERVICES (PMII Abbott Diabetic Care (ADC))`
  - `Bayer` $\rightarrow$ `PROFESSIONAL INSIGHTS MARKETING SERVICES (PMII Bayer)`
  - `Fonterra` $\rightarrow$ `PROFESSIONAL INSIGHTS MARKETING SERVICES (PMI Fonterra)`
  - `Galderma` $\rightarrow$ `PROFESSIONAL INSIGHTS MARKETING SERVICES (PMII Galderma)`
  - Generic / Other programs $\rightarrow$ `PROFESSIONAL INSIGHTS MARKETING SERVICES (PIMS)`
- **Dynamic Agreement Body**: Every instance of the corporate name and acronym in the consent clauses, purpose list (a–g), privacy policy acknowledgment, and National Privacy Commission notice dynamically formats using the program's registered company identity.

### 3. Guarded & Interactive Cancel Doctor Button
- **Intuitive Visual Hierarchy**: Redesigned from a hard-to-tap inline text link to a prominent, outlined interactive button with icon (`Icons.close_rounded`), red accenting (`#DC2626`), and rounded border radius.
- **Cognitive Guarding (`_isStep2Complete()`)**: Button only renders when all mandatory fields in Step 2 (First Name, Last Name, Specialization, Workplace, Workplace Type, Practice) have been populated.
- **Confirmation Safety**: Tapping prompts a confirmation alert dialog (`_confirmResetDoctor`) preventing unintended form resets.

### 4. Step Progression & Form Security Guardrails
- **Sequential Unlocking**: Users cannot bypass Step 1 without confirming consent and capturing a signature or photo. Step 3 (Survey Detailing) and Changes tabs remain locked until Step 2 is fulfilled.
- **Visual Feedback**: Locked tabs display a lock icon (`Icons.lock_outline_rounded`) and disabled opacity. Tapping an inactive tab triggers a SnackBar detailing the exact prerequisite step needed.

### 5. Human-Centric Summary of Changes
- **Elimination of Monospace Code**: Completely removed the raw JSON string terminal box that confused field representatives.
- **Executive Card Layout**: Renders structured, color-coded change cards:
  - Basic Profile Details (Field, Old Value vs New Value)
  - Specializations (Added / Removed)
  - Workplaces & Medical Institutions (Added / Removed)
  - Contact Channels (Added / Removed)
  - Survey Detailing Responses
  - Submission Metadata & Audit Summary (Author, Timestamp, ERPNext Integration Status)

### 6. Context-Specific "Add Row" Buttons
- **Specialization Card & Dialog**: `+ Add Specialization`
- **Workplace Card & Dialog**: `+ Add Institution`
- **Contact Channels Card & Dialog**: `+ Add Contact/Email`

### 7. Form Aesthetics & Mandatory Field Precision
- **Mandatory Disclaimer**: `* indicates information that are mandatory` rendered in crisp red (`#DC2626`).
- **Clean Input Borders**: First, Middle, and Last Name labels use `Text.rich` displaying neutral slate text with a red asterisk `*` without red input borders.
- **Birth Date Cleanup**: Removed `(Optional)` tag and helper text from Birth Date.

---

## 🧪 Verification & Quality Assurance
- **Static Analysis**: `flutter analyze` verified clean with **0 errors and 0 warnings**.
- **Automated Regression Suite**: `flutter test test/inst_profiling_test.dart` passed all **18/18** test suites.
- **Asset Parity**: Zero-drift byte-for-byte SHA-256 parity validated across all web portal mirrors.
- **Packaging Integrity**: Standalone EXE, portable ZIP, root release APK, and legacy version archives successfully generated.
