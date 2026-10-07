# 📊 Guide: Managing Version Testing Data Accurately in Excel / Google Sheets

**Active Version:** `V.0.4.6` (Build 17)  
**Ready-to-Use Excel File:** [`docs/HCP_Profiling_Version_Testing_Matrix.xlsx`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/docs/HCP_Profiling_Version_Testing_Matrix.xlsx)  
**Importable CSV File:** [`docs/HCP_Profiling_Version_Testing_Matrix.csv`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/docs/HCP_Profiling_Version_Testing_Matrix.csv)

---

## 🔍 Multi-Program Testing Clarification: Bayer, ADC, and RiteMed

> **Did you test using Bayer and Abbott Diabetes Care (ADC) accounts?**  
> **YES, ABSOLUTELY!** Both Bayer and ADC were heavily tested and have extensive verified submission records on the ERPNext backend:
> * **Abbott Diabetes Care (ADC):** **31 Submissions** logged across Approved (13), Processed (10), Pending Approval (6), Rejected (1), and Draft (1).
> * **Bayer Consumer Health:** **22 Submissions** logged across Team 1 and Team 3 (Approved: 13, Processed: 8, Draft: 1).
> * **RiteMed (RTMD):** **10 Submissions** logged across Approved (7), Processed (2), and Rejected (1).

### Why did the previous guide mention only 2 RiteMed accounts?
The snippet image uploaded in the prior prompt specifically captured rows from the **RiteMed (RM106 / NGMA/NLZ/VIZ)** section of your verification sheet. The guide matched those exact territory codes (`RM106` for MedRep and `NGMA/NLZ/VIZ` for DSM). 

In your full testing spreadsheet, you should include the accounts across **all three programs** as detailed below!

---

## 👥 Verified Test Accounts by Commercial Program

*(In strict compliance with security policies, passwords are omitted — only authorized account emails and territories are listed).*

### 1. Bayer Consumer Health
| Role | Territory Code | Assigned Account Email | User Persona |
| :--- | :--- | :--- | :--- |
| **MedRep (District 1)** | `BA1-05` | `arlaneferraren8@gmail.com` | Arlane Ferraren |
| **MedRep (District 2)** | `BA2-02` | `gallegoscharisse@gmail.com` | Charisse Capulong |
| **MedRep (District 3)** | `BA4-01` | `carmelannevidena@yahoo.com` | Carmel Videna |
| **DSM (District 1)** | `BA1` | `rbviray@profinsights.biz` | Raymond Viray |
| **DSM (District 2)** | `BA2` | `ginlorcullo@profinsights.biz` | Gin Orcullo |
| **DSM (District 3)** | `BA4` | `cmrinon@profinsights.biz` | Christopher Rinon |

### 2. Abbott Diabetes Care (ADC)
| Role | Territory Code | Assigned Account Email | User Persona |
| :--- | :--- | :--- | :--- |
| **MedRep (Team 1)** | `AD0101` | `grivo@profinsights.biz` | Graziel Rivo |
| **MedRep (Team 1)** | `AD0102` | `lr_roxas@yahoo.com` | Liza Roxas |
| **MedRep (Team 2)** | `AD0110` | `mengoriojorge123@gmail.com` | Jorge Mengorio |
| **MedRep (Team COOR)** | `AD0106` | `jonelapsay27@gmail.com` | Jonel Apsay |
| **DSM (Team 1)** | `AD1` | `rlbanasihan@profinsights.biz` | Regalado Banasihan |
| **DSM (Team 2)** | `AD2` | `admendoza@profinsights.biz` | Adrian Mendoza |
| **DSM (COOR)** | `AD0105` | `syucaran@profinsights.biz` | Shella Yucaran |

### 3. RiteMed (RTMD)
| Role | Territory Code | Assigned Account Email | User Persona |
| :--- | :--- | :--- | :--- |
| **MedRep** | `RM106` | `leritargieian@gmail.com` | Argie Ian Lerit |
| **DSM** | `NGMA/NLZ/VIZ` | `dbdelossantos@profinsights.biz` | Donato Delos Santos |

### 4. Cross-Program Roles (Administrator & SFE)
| Role | Scope | Assigned Account Email | Responsibilities |
| :--- | :--- | :--- | :--- |
| **System Administrator** | Universal | `jptan@profinsights.biz` | Universal system oversight, cross-program masterlists, emergency transitions. |
| **SFE Specialist** *(V.0.2.0+)* | National | `lesantos@pims-marketing.com` | Dedicated SFE Hub, institution proposals review, nationwide approval/rejection. |

---

## 🏗️ The 2 Methods for Structuring Multi-Version Testing in Excel

### Method 1: Tab-Per-Version (Sheet per Version)
Each version has its own tab (`V.0.1.0`, `V.0.2.0`, `V.0.3.0`, `V.0.4.6`, etc.) with sections for each program:
* `Medical Representative — Bayer`
* `District Manager — Bayer`
* `Medical Representative — Abbott Diabetes Care`
* `District Manager — Abbott Diabetes Care`
* `Medical Representative — RiteMed`
* `District Manager — RiteMed`
* `Administrator`
* `Sales Force Effectiveness (SFE)` *(V.0.2.0+)*

### Method 2: Consolidated Master Sheet
A single table with a **`Program`** column and a **`Version`** column. This allows filtering by **Program** (Bayer, ADC, RiteMed) or by **Version** in seconds.

---

## 📅 Complete Version Master Data (V.0.1.0 to V.0.4.6)

| Version | Build # | Date Tested (Col G) | Version In-Release (Col D) | Version Info / Milestone Focus (Col F) |
| :--- | :---: | :---: | :--- | :--- |
| **`V.0.1.0`** | `Build 1` | `2026-08-27` | `V.0.1.0 (Build 1)` | Two-Tier Masterlist, basic profiling, 0-approval for existing doctors, PSGC geo resolution. |
| **`V.0.2.0`** | `Build 2` | `2026-09-15` | `V.0.2.0 (Build 2)` | Add New Institution workflow, SFE approval engine, territory scoping, strict approved gating. |
| **`V.0.2.1`** | `Build 3` | `2026-09-15` | `V.0.2.1 (Build 3)` | SFE Specialist dashboard instant display for new facilities & masterlist hygiene. |
| **`V.0.2.2`** | `Build 4` | `2026-09-15` | `V.0.2.2 (Build 4)` | Automatic deletion of rejected resubmissions & MedRep Discard option. |
| **`V.0.2.3`** | `Build 5` | `2026-09-15` | `V.0.2.3 (Build 5)` | Centralized institution proposing in Institution Approvals & server persistence fix. |
| **`V.0.2.4`** | `Build 6` | `2026-09-15` | `V.0.2.4 (Build 6)` | Server-side Discard deletion permission & fix silent deletion mock. |
| **`V.0.2.5`** | `Build 7` | `2026-09-15` | `V.0.2.5 (Build 7)` | Region field support with bidirectional PSGC auto-resolution (Region/Province/City). |
| **`V.0.2.6`** | `Build 8` | `2026-09-15` | `V.0.2.6 (Build 8)` | Strict gating (isApprovedForProfiling) blocking unapproved clinics from profiling. |
| **`V.0.3.0`** | `Build 9` | `2026-09-16` | `V.0.3.0 (Build 9)` | Dynamic workplace approval notes, pending clinic profiling, duplicate detection banner. |
| **`V.0.3.1`** | `Build 10` | `2026-09-16` | `V.0.3.1 (Build 10)` | Terminology alignment: Renamed Institution Approval to Institution Submission. |
| **`V.0.4.0`** | `Build 11` | `2026-09-16` | `V.0.4.0 (Build 11)` | Dedicated Institution Directory Screen, Desk List alignment, SFE full administrative parity. |
| **`V.0.4.1`** | `Build 12` | `2026-09-16` | `V.0.4.1 (Build 12)` | Unified Institution Directory listing (removed status tabs) & centered hideable search filter. |
| **`V.0.4.2`** | `Build 13` | `2026-09-16` | `V.0.4.2 (Build 13)` | ERPNext status color parity (Draft in red pill), restored 3,900+ facilities, search filter parity. |
| **`V.0.4.3`** | `Build 14` | `2026-09-17` | `V.0.4.3 (Build 14)` | Unlocked pending facility profiling in wizard & dynamic approval notes ("this institution is now approved"). |
| **`V.0.4.4`** | `Build 15` | `2026-09-17` | `V.0.4.4 (Build 15)` | Rejection remarks isolation (red banner only on rejected) & SFE direct institution proposal. |
| **`V.0.4.5`** | `Build 16` | `2026-09-17` | `V.0.4.5 (Build 16)` | SFE workflow HTTP 417 fix, role alignment for Sales Force Effectiveness, CSRF fallback. |
| **`V.0.4.6`** | `Build 17` | `2026-09-17` | `V.0.4.6 (Build 17)` | Institution zero-deletion policy, continuous modify & resubmit, discard button removed. |

---

## 📁 Artifact References in Repository

* 📗 **Excel Spreadsheet (.xlsx):** [`docs/HCP_Profiling_Version_Testing_Matrix.xlsx`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/docs/HCP_Profiling_Version_Testing_Matrix.xlsx)
* 📄 **CSV Data File (.csv):** [`docs/HCP_Profiling_Version_Testing_Matrix.csv`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/docs/HCP_Profiling_Version_Testing_Matrix.csv)
* 📘 **Bayer District Testing Guide:** [`docs/BAYER_DISTRICT_WORKFLOW_TESTING_GUIDE.md`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/docs/BAYER_DISTRICT_WORKFLOW_TESTING_GUIDE.md)
* 📖 **RiteMed (RM106/NGMA) Guide:** [`docs/MEDREP_DSM_WORKFLOW_TESTING_GUIDE.md`](file:///c:/Users/User%201/Downloads/HCP_Test/HCP_Test_Repo/docs/MEDREP_DSM_WORKFLOW_TESTING_GUIDE.md)
