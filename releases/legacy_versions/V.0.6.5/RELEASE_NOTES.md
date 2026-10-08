# Release Notes - HCP Profiling App v.0.6.5

**Build Date**: October 8, 2026  
**Version**: `v.0.6.5`  
**APK SHA-256**: `a74ea8a3d4067056637b565a448408f6d2f3c306e93eb5ec9c1f6b15e4f4d2f0`  
**File Size**: `58.94 MB`

---

### 🧠 Smart Detector & Resubmission Governance
- **Smart Detector Active on Resubmit**:
  - Live debounced (300ms) duplicate and acronym detection is fully activated during MedRep/DSM resubmission dialogs. Renamed cleanly from "AI Smart Detector" to **"Smart Detector"**.
  - SFE Specialists remain unconstrained as they reference the canonical DOH-accredited hospital/clinic masterlist.
- **Human-Readable Location Fields**:
  - Eliminated raw PSGC codes (e.g. `1380600000`, `PRV-1380600000`) in the resubmission dialog. Region, Province, and City fields strictly resolve to human-readable names via `LocationResolver`.
- **Immediate Submission Lock**:
  - Institution proposals lock immediately into read-only mode upon submission. Editable only when rejected by SFE.
- **Two-Strike Resubmission Ceiling & Strict Zero Deletion**:
  - MedReps/DSMs have up to 2 attempts (`Attempt 1/2` and `Attempt 2/2`) to correct rejected proposals. If still unverified after 2 attempts, editing is permanently disabled and the facility is archived (strictly zero deletion) with guidance to contact SFE directly.
- **SFE Canonical Remapping Workflow**:
  - SFE Specialists rebind doctor profiles directly to approved DOH facilities without recycling MedRep typos. The flawed submission is archived/rejected, and doctor profiling is unblocked immediately.
- **Multi-Tier Push Notification Architecture**:
  - High-priority public lockscreen and homescreen heads-up alerts with a 5-tier fail-safe matrix ensuring 100% notification reach even if device notifications are turned off.
- **Menu Drawer Version Clean Display**:
  - HCP App version is retained at `v.0.6.5` and the `+No.` suffix is removed from the drawer menu navigation.
