# Release Notes - HCP Profiling & Territory Reconfiguration System V.0.6.6 (Build 38)
**Release Date**: October 7, 2026  
**APK Size**: 58.90 MB
**SHA-256**: 0cbcea9183083f54fa3dfca948f41978b790be63994226b8131420732df2d7ed

## 🎯 Highlights & System Enhancements
1. **ERPNext Registered User Email Account Standard**:
   - Fixed User ID field to strictly display and record registered ERPNext User email accounts (e.g. `lesantos@pims-marketing.com`, `bsbenitez@profinsights.biz`), completely eliminating legacy employee ID numbers (`EMP-xxxxx` / `HR-EMP-xxxxx`).
   - Purged random placeholder employee ID generation across territory initialization, addition, transfer, and restoration workflows.

2. **Table Grid View & Modal "Unassigned" State Precision**:
   - In Table Grid View, unassigned territory codes without a designated user now explicitly display `"Unassigned"` with subtle badge styling (`#F4F4F5`, grey border), eliminating fake `EMP-10023` tags.
   - In Edit and Add Territory modals, User ID and Territory Manager fields cleanly display `"Unassigned"` placeholder text when unassigned.
   - Added dedicated `(Unassigned) - Leave User ID unassigned` option at the top of the User ID searchable dropdown.

3. **Robust Dropdown Interaction & Remote Search Architecture**:
   - Implemented `toggleErpDropdown(fieldId, event)` with outside click dismissal, eliminating unhandled ReferenceErrors when clicking input boxes or dropdown chevrons.
   - Upgraded `openErpDropdown(fieldId, forceShowAll)` to present the full unfiltered directory of available users and sales persons on initial click or focus.
   - Enhanced `dispatchRemoteErpSearch` to query ERPNext `User` DocType dynamically with debounced search, persisting live matches to local storage cache.

4. **Master Parity & Technical Debt Grade A+**:
   - 100% byte-for-byte SHA-256 parity across all 4 portal mirrors.
   - Verified Grade A+ technical debt score across all architectural checks.
