# Release Notes — HCP Profiling App `v.0.7.2` (Build 50)

**Release Date**: October 27, 2026  
**Build Number**: `50`  
**Full Version**: `v.0.7.2+50`

---

## 🧹 Repository Separation & Unused Feature Pruning

1. **Removed Unused Self-Service QR Prototype**:
   - Removed `lib/screens/self_service_qr_screen.dart` and its orphaned prototype caller `lib/screens/doctor_profile_screen.dart`, which are not part of the active HCP Profiling App workflow or roadmap.
2. **Removed Separate MCP COREnergy App Files & Code**:
   - Removed all standalone files belonging to the separate MCP COREnergy App repository:
     - `lib/main_corenergy.dart`
     - `lib/models/corenergy_engage.dart`
     - `lib/models/engagement.dart`
     - `lib/screens/corenergy_engage_detail_screen.dart`
     - `lib/screens/detail_screen.dart`
     - `lib/screens/list_screen.dart`
     - `lib/services/db_helper.dart`
   - Pruned all `COREnergyEngage` and `Successful COREnergy Engagement` methods (`fetchEngagements`, `fetchCOREnergyEngages`, `fetchCOREnergyEngageByName`, `createCOREnergyEngage`, `updateCOREnergyEngage`, `createEngagement`, `updateEngagement`, `syncOfflineData`) and `AppMode.corenergy` branching from `lib/services/api_service.dart`, `lib/screens/login_screen.dart`, and `lib/app_config.dart`, keeping the repository 100% dedicated to the HCP Profiling App.

