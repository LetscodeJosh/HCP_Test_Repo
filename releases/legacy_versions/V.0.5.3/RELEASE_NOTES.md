# Release Notes - HCP Profiling & Territory Reconfiguration Portal V.0.5.3 (Build 29)

**Release Date:** October 1, 2026  
**Status:** Enterprise Production Ready  

---

### 🌟 Key Highlights & Enhancements

1. **Default Territory Tree Viewing with Seamless Grid Toggle**:
   - The Territory Reconfiguration portal now opens directly into the **Territory Tree View** by default.
   - SFE Leads can seamlessly toggle back and forth between **Territory Tree** and **Table Grid** with a single click.

2. **1:1 ERPNext Territory Tree Hierarchy & Operations**:
   - Replicated the live ERPNext tree hierarchy (`https://dev.pmii-marketing.com/app/territory/view/Tree`) with 181 masterlist territories organized under root `📁 All Territories`.
   - **Folder-Only Child Creation Invariant**: Only folder icon nodes (`is_group: 1`) can add child territories (`[Add Child]`). Non-group leaf nodes display circle bullets (`⚪`) with child creation disabled.
   - **Interactive Action Pill Group**: Each node provides inline action pills on selection/hover: `[Edit]`, `[Add Child]`, `[Rename]`, `[Delete]`.
   - **Dedicated Modals**:
     - **New Territory**: Allows specifying `Group Node` toggle and `Territory Name` under the selected parent.
     - **Edit Territory**: Enables re-parenting, Is Group toggle, Account/Program association, User ID, and Territory Manager.
     - **Rename Territory**: Instant renaming with cascading child updates.
     - **Delete Territory**: Guarded validation preventing deletion of populated branches.

3. **24/7 Resilience & Masterlist Sanitization**:
   - LocalStorage backup guarantees full operational continuity offline.
   - Automated live synchronization with ERPNext `/api/resource/Territory`.
   - Complete cleanup of test facilities (`INST-07987` through `INST-07999`) from `Institution` DocType with descending sorting.
