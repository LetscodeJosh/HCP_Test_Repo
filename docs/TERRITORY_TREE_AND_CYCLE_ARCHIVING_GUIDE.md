# Territory Tree & Sales Person Tree Reconfiguration & Cycle Archiving Architecture Guide

## 📌 Executive Summary
In pharmaceutical field sales operations (e.g., Abbott Diabetes Care, Bayer, COREnergy), commercial realignments frequently require:
1. **Consolidating territories** due to headcount downsizing or regional mergers.
2. **Renaming territory codes** for program-specific rebranding without losing historical physician linkages.
3. **Preserving decommissioned areas** without deleting historical sales records or physician call logs.
4. **Freezing and auditing commercial cycles** (Cycle 1, Cycle 2, Cycle 3, Cycle 4) so Sales Force Effectiveness (SFE) Leads, District Sales Managers (DSM), and compliance auditors can jump back to any historical cycle in read-only audit mode with 100% precision.

This guide details the technical and operational mechanics of how the **`Territory Tree`**, the **`Sales Person Tree`**, and the **`Cycle Snapshot Archive Vault`** handle these changes inside ERPNext and the built-in Territory Reconfiguration Portal.

---

## 🌳 1. How the Territory Tree Handles Merges & Edits

### A. The Frappe / ERPNext Nested Set Model
In ERPNext, the `Territory` DocType is modeled as a **Modified Preorder Tree Traversal (Nested Set)**. Each node in the tree possesses four key structural attributes:
* `name`: Primary key (e.g., `RM101`, `ADC-T01`, `Cluster A: Pampanga Central`).
* `parent_territory`: The parent group node.
* `is_group`: `1` if the node contains child territories, `0` if it is an assigned leaf territory.
* `lft` and `rgt`: Integer boundary indices used to query entire regional subtrees efficiently in a single query (`WHERE lft >= parent.lft AND rgt <= parent.rgt`).

```
                              📂 All Territories (Root) [lft: 1, rgt: 20]
                                          │
                     ┌────────────────────┴────────────────────┐
                     ▼                                         ▼
    📂 North Luzon Region [lft: 2, rgt: 15]        🗄️ Archived Territories [lft: 16, rgt: 19]
                     │                                         │
        ┌────────────┴────────────┐                            ▼
        ▼                         ▼                  📄 RM106 (Subic Extended)
📂 Cluster A: Pampanga   📂 Cluster B: Bulacan             [lft: 17, rgt: 18]
  [lft: 3, rgt: 8]         [lft: 9, rgt: 14]             (14 Doctors Preserved)
        │                         │
  ┌─────┴─────┐             ┌─────┴─────┐
  ▼           ▼             ▼           ▼
📄 ADC-T01   📄 RM102      📄 ADC-T02   📄 RM104
[lft: 4,     [lft: 6,      [lft: 10,    [lft: 12,
 rgt: 5]      rgt: 7]       rgt: 11]     rgt: 13]
 (Renamed)   (Reparented)  (Renamed)   (Reparented)
```

---

### B. In-Place Code Editing & Renaming (Foreign Key Cascades)
When an SFE Lead renames a territory code (e.g., `RM101` $\rightarrow$ `ADC-T01`):
1. **Primary Key Update**: ERPNext invokes `frappe.rename_doc("Territory", "RM101", "ADC-T01", merge=False)`.
2. **Automatic Cascade Across Linked DocTypes**:
   - `HCP Account.territory`: All doctor affiliations pointing to `RM101` automatically update to `ADC-T01`.
   - `Sales Person Territory.territory`: Medical Rep territory assignments update in place.
   - `Customer.territory` & `Sales Invoice.territory`: Historical sales data remains linked.
3. **Doctor Links Preserved**: No doctor is orphaned; their preferred affiliations, visiting schedules, and clinic records remain 100% intact.

---

### C. Merging Specific Areas via District Groups (Non-Destructive Merge)
In pharmaceutical CRM systems, **destructive SQL merges** (`DELETE FROM tabTerritory WHERE name='RM101'`) are catastrophic because they destroy past sales audit trails and break past interaction histories.

Instead, the reconfiguration portal performs a **structural cluster merge**:
1. **Create District Cluster Node**: The system creates an intermediate group node, e.g., `Cluster A: Pampanga Central` (`is_group = 1`, `parent_territory = "North Luzon Region"`).
2. **Re-Parent Historical Territories**:
   - `ADC-T01` (San Fernando) is reparented: `parent_territory = "Cluster A: Pampanga Central"`.
   - `RM102` (Angeles City) is reparented: `parent_territory = "Cluster A: Pampanga Central"`.
3. **Atomic Boundary Rebuild**: The system executes `frappe.utils.nestedset.rebuild_tree("Territory")`, which recalculates `lft` and `rgt` across all nodes in under 200ms.
4. **Zero Circular Reference Guarantee**: Pre-flight validation confirms `parent_territory != self.name` and verifies that no ancestor is set as a child of its own descendant.

---

### D. Decommissioned / Downsized Areas: The Zero Deletion Rule
When a sales territory is eliminated due to manpower reduction (e.g., `RM106 - Subic Extended`):
1. **Never Deleted**: The territory record and its doctor affiliations are NOT removed from the database.
2. **Relocated to Archive Root Node**:
   - The territory's parent is updated: `parent_territory = "Archived Territories"`.
   - The territory is flagged `is_active = 0` in commercial program views so it no longer appears in the active rep's mobile daily call roster.
3. **Physicians Remain Preserved**: All 14 doctors assigned to `RM106` remain registered in `HCP Account`.
4. **Instant Reactivation**: If management adds headcount in a future cycle, the SFE Lead clicks **`Restore`** in the portal, selects the target district cluster, and the territory returns to active field status instantly.

---

## 👤 2. How the Sales Person Tree Handles Territory Reconfiguration

### A. The Sales Person Hierarchy
The `Sales Person` DocType represents the commercial organizational reporting structure:
```
                      👤 Commercial Sales Director (National Root)
                                          │
                                          ▼
                👤 Carlos Mendoza (District Sales Manager - North Luzon)
                                          │
                     ┌────────────────────┴────────────────────┐
                     ▼                                         ▼
            👤 Juan Dela Cruz                         👤 Maria Santos
             Medical Rep (EMP-0142)                    Medical Rep (EMP-0198)
                     │                                         │
        ┌────────────┴────────────┐               ┌────────────┴────────────┐
        ▼                         ▼               ▼                         ▼
   🔗 ADC-T01                  🔗 RM102       🔗 ADC-T02                 🔗 RM104
   (24 Doctors)              (19 Doctors)     (31 Doctors)              (22 Doctors)
   ──────────────────────────────────────     ──────────────────────────────────────
   🎯 Total Target: 43 Doctors                🎯 Total Target: 53 Doctors
```

### B. Manpower Downsizing & Territory Absorption Mechanics
When territory areas are merged and headcount is reduced:
1. **Surviving Reps Absorb Multiple Codes**:
   - Rather than forcing one territory code to be deleted, the surviving Medical Rep's child table (`Sales Person Territory`) receives both territory codes.
   - For example, `Juan Dela Cruz` is assigned both `ADC-T01` and `RM102`.
2. **Automatic Target & Quota Aggregation**:
   - `ADC-T01` has 24 doctors.
   - `RM102` has 19 doctors.
   - Juan's target doctor coverage dynamically sums to **43 doctors**.
3. **Deactivated Reps Preserved in Headcount Reserve**:
   - Deactivated reps are reparented under `👤 Headcount Reserve / Inactive Reps`.
   - Their past call logs, sample issuances, and performance metrics are preserved for HR and compliance audits.

---

## 📅 3. Cycle-Based Versioning & Archiving for SFE Audit Review

### A. Why Commercial Cycle Versioning is Mandatory
Sales Force Effectiveness teams operate on discrete planning cycles (typically quarterly or semi-annually):
* **Cycle 1 (2025 H2)**: Historical baseline.
* **Cycle 2 (2026 H1)**: Previous operating model.
* **Cycle 3 (2026 Q3 Frozen Baseline)**: Baseline before restructuring.
* **Cycle 4 (Proposed Active)**: The new consolidated territory layout.

If an SFE Lead, District Manager, or internal auditor needs to know:
> *"Which Medical Rep covered Dr. Ricardo Santos during Cycle 2 vs Cycle 3?"*
> *"How many endocrinologists were assigned to RM101 before it was renamed to ADC-T01?"*
> *"Why did RM106 move to the Archive node, and which clinic addresses were recorded at that time?"*

They require **immediate, tamper-proof access to past cycle snapshots**.

---

### B. The Cycle Snapshot Archive Vault Architecture
In the portal's Tab 3 (`Multi-Cycle Historical Dataset Matcher`), the **Cycle Snapshot Vault** provides:

| Snapshot ID | Cycle Name | State | SFE Access Mode | Key Characteristics |
| :--- | :--- | :--- | :--- | :--- |
| **`C1`** | **Cycle 1 (2025 H2)** | Archived | 📜 **Read-Only Audit** | Original 4-rep baseline (`RM101` - `RM106`) |
| **`C2`** | **Cycle 2 (2026 H1)** | Archived | 📜 **Read-Only Audit** | Intermediate operating cycle |
| **`C3`** | **Cycle 3 (2026 Q3 Baseline)** | Frozen | 📜 **Read-Only Audit** | Baseline immediately prior to headcount downsizing |
| **`C4`** | **Cycle 4 (Proposed Active)** | Active / Staged | ✏️ **Full Staging / Edit** | Consolidated district clusters & renamed codes (`ADC-T01`) |

---

### C. Operational SFE Workflows

#### 1. Switching to Past Cycles for Audit Review
1. Open **Tab 3: Multi-Cycle Historical Dataset Matcher**.
2. Click any archived cycle button (e.g., **`Cycle 3 (2026 Q3 Baseline)`**).
3. The vault instantly loads the snapshot:
   - Displays an amber banner: `📜 Archived Snapshot: Cycle 3 (2026 Q3 Frozen Baseline) • Read-Only SFE Audit Mode`.
   - Replaces the doctor table with the exact historical assignments from Cycle 3.
   - Prevents accidental edits or overwrites while in historical review mode.

#### 2. Exporting Cycle Snapshot CSVs
* SFE Leads can click **`📥 Export Cycle Snapshot CSV`** while viewing any cycle.
* The browser generates an immutable audit CSV file (e.g., `territory_C3_historical_snapshot.csv` or `territory_C1_historical_snapshot.csv`) containing:
  - Doctor Name & Medical Specialty
  - Primary Hospital / Institution
  - Cycle 1 Territory Code
  - Cycle 2 Territory Code
  - Cycle 3 Territory Code
  - Proposed Cycle 4 Territory Code
  - Match & Audit Status

#### 3. Freezing the Active State Before Cutover
* Before publishing any new reconfiguration to production, SFE Leads click **`📸 Freeze Active State as Snapshot`**.
* The portal captures an immutable snapshot of all current doctor-to-territory links and stores it in the Cycle Vault, ensuring that a rollback or audit baseline is always guaranteed.

---

## 🚀 4. Summary Matrix: Changes Handled by Tree & Vault

| Operational Event | How Territory Tree Handles It | How Sales Person Tree Handles It | How Cycle Vault Handles It |
| :--- | :--- | :--- | :--- |
| **Rename Territory Code** (`RM101` $\rightarrow$ `ADC-T01`) | `frappe.rename_doc` updates primary key and cascades to `HCP Account` with zero broken links | Rep's territory child table updates to new code automatically | Cross-references old code in Cycles 1-3 against new code in Cycle 4 (100% Match) |
| **Merge 2 Areas into 1 Rep** (`RM101` + `RM102`) | Creates parent district node (`Cluster A`) and reparents leaf nodes under it; `rebuild_tree` recalcs boundaries | Rep absorbs both territory child records; target quota aggregates ($24 + 19 = 43$ docs) | Historical cycles retain separate reps; Cycle 4 reflects consolidated cluster |
| **Downsize Manpower / Decommission Area** (`RM106`) | Reparents leaf node to `Archived Territories` root node; 0 doctor records deleted | Rep moved to `Headcount Reserve`; commission & call logs preserved | Previous cycles retain active status; Cycle 4 flags code as `PRESERVED / ARCHIVED` |
| **SFE Historical Review** | Tree maintains historical node integrity | Org chart maintains reporting trail | One-click switch to read-only audit mode + instant CSV snapshot export |

---
*Active Portal Implementation: [territory_reconfiguration_portal.html](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/assets/web/territory_reconfiguration_portal.html)*
*Release Version: `V.0.5.3` (Build 23)*
