# Release Notes - HCP Profiling & Territory Reconfiguration Portal V.0.6.2

## Version Overview
- **Version**: V.0.6.2 (Build 34)
- **Release Date**: October 6, 2026
- **Component**: Territory Reconfiguration Web Portal (Streamlit Cloud & Desktop)

## Key Fixes & Architectural Enhancements
1. **Permanent Invariant View Mode Enforcement**:
   - High-priority body[data-editor-view="grid"] and body[data-editor-view="tree"] CSS rules with !important guarantee that Table Grid View and Territory Tree View cannot be overridden or forced to revert.
2. **Triple-Redundancy Persistence**:
   - window.activeEditorViewMode synchronized with getter/setter on window.isTreeViewActive, mirrored in sessionStorage, localStorage, and DOM root attributes.
3. **Event Debounce Protection**:
   - 350ms cooldown and event propagation cancellation on view mode toggle to eliminate rapid bounce / double-fire hazards.
4. **Purged Forced Resets**:
   - Removed all legacy view resets from session auth, background sync, and Streamlit render handlers.
5. **Cache-Busting HTTP Headers**:
   - Ensured browsers never serve stale cached iframe builds.

- **App Logo & Launch Icon Restoration**: Fully registered `assets/app_logo.png` and sub-assets in `pubspec.yaml`, enabled centered launcher icon in Android `launch_background.xml`, added `android:roundIcon` in `AndroidManifest.xml`, and implemented defensive fallback `errorBuilder`s in `login_screen.dart` and `app_drawer.dart`.