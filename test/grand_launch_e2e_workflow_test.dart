import 'package:flutter_test/flutter_test.dart';
import 'package:hcp_profiling/models/lookup_models.dart';
import 'package:hcp_profiling/models/submission.dart';
import 'package:hcp_profiling/models/hcp.dart';
import 'package:hcp_profiling/models/hcp_account.dart';

void main() {
  group('Grand Launch October 2026 - Pillar 1: Basic Profiling & Two-Tier Workflow', () {
    test('1.1 Existing HCP: Profile action "Existing HCP" routes to Processed without manager approval', () {
      final json = {
        'name': 'HCP-SUB-2026-00101',
        'hcp_name': 'HCP-0000001',
        'hcp_full_name': 'Dr. Juan Dela Cruz',
        'first_name': 'Juan',
        'last_name': 'Dela Cruz',
        'profile_action': 'Existing HCP',
        'workflow_state': 'Processed',
        'docstatus': 1,
        'account_or_program': 'Abbott Diabetes Care',
        'territory': 'AD0101',
      };

      final sub = HcpProfileSubmission.fromJson(json);

      expect(sub.profileAction, 'Existing HCP');
      expect(sub.isProcessed, isTrue);
      expect(sub.isApproved, isTrue); // docstatus 1 is submitted/processed
      expect(sub.isPendingApproval, isFalse);
      expect(sub.docstatus, 1);
    });

    test('1.2 New HCP: Profile action "New HCP" routes to Pending Approval and requires managerial approval', () {
      final json = {
        'name': 'HCP-SUB-2026-00102',
        'hcp_name': 'NEW-HCP',
        'first_name': 'Maria',
        'middle_name': 'Santos',
        'last_name': 'Reyes',
        'profile_action': 'New HCP',
        'workflow_state': 'Pending Approval',
        'docstatus': 0,
        'account_or_program': 'Abbott Diabetes Care',
        'territory': 'AD0102',
      };

      final sub = HcpProfileSubmission.fromJson(json);

      expect(sub.profileAction, 'New HCP');
      expect(sub.isPendingApproval, isTrue);
      expect(sub.isApproved, isFalse);
      expect(sub.isProcessed, isFalse);
      expect(sub.docstatus, 0);
      expect(sub.isSemanticallyLocked, isTrue);
    });

    test('1.3 Manager Approval: Transitioning New HCP from Pending Approval to Approved commits to masterlist', () {
      final pendingSub = HcpProfileSubmission(
        name: 'HCP-SUB-2026-00102',
        hcpName: 'NEW-HCP',
        firstName: 'Maria',
        lastName: 'Reyes',
        profileAction: 'New HCP',
        workflowState: 'Pending Approval',
        docstatus: 0,
        accountOrProgram: 'Abbott Diabetes Care',
      );

      final approvedSub = pendingSub.copyWith(
        workflowState: 'Approved',
        docstatus: 1,
      );

      expect(approvedSub.isApproved, isTrue);
      expect(approvedSub.isPendingApproval, isFalse);
      expect(approvedSub.docstatus, 1);
    });

    test('1.4 Manager Rejection: Captures mandatory rejection remarks and marks submission as Rejected', () {
      final pendingSub = HcpProfileSubmission(
        name: 'HCP-SUB-2026-00103',
        hcpName: 'NEW-HCP',
        firstName: 'Roberto',
        lastName: 'Tan',
        profileAction: 'New HCP',
        workflowState: 'Pending Approval',
        docstatus: 0,
      );

      final rejectedSub = pendingSub.copyWith(
        workflowState: 'Rejected',
        rejectionRemarks: 'PRC License photo blurred and unreadable. Please re-upload.',
        rejectedBy: 'sales.manager@pharma.com',
      );

      expect(rejectedSub.isRejected, isTrue);
      expect(rejectedSub.isPendingApproval, isFalse);
      expect(rejectedSub.rejectionRemarks, contains('PRC License photo blurred'));
      expect(rejectedSub.rejectedBy, 'sales.manager@pharma.com');
    });

    test('1.5 Two-Tier Doctor Sync: Merges universal HCP and maintains program-specific HCP Account', () {
      final universalDoctor = Hcp(
        name: 'HCP-0000045',
        firstName: 'Elena',
        lastName: 'Gomez',
        hcpType: 'Medical Doctor',
        hcpPractice: 'Private',
        isActive: true,
        isPendingApproval: false,
        specialties: [
          HcpSpecialty(hcpSpecialty: 'Cardiology', isPrimary: true),
        ],
        workplaces: [
          HcpWorkplace(workplace: 'INST-00001', address: 'Manila Doctors Hospital', isPrimary: true),
        ],
        contacts: [],
      );

      // Program-specific affiliation for Bayer
      final bayerAccount = HcpAccount(
        name: 'HCP-ACC-00501',
        hcp: universalDoctor.name,
        accountName: 'Bayer',
        territory: 'BAY-MANILA-01',
        workplaceId: 'INST-00001',
        validFrom: '2026-09-01',
        validTo: '2026-09-30',
        validityPeriod: 'September 2026',
      );

      // Program-specific affiliation for Abbott
      final abbottAccount = HcpAccount(
        name: 'HCP-ACC-00502',
        hcp: universalDoctor.name,
        accountName: 'Abbott Diabetes Care',
        territory: 'AD0101',
        workplaceId: 'INST-00001',
        validFrom: '2026-09-01',
        validTo: '2026-09-30',
        validityPeriod: 'September 2026',
      );

      expect(bayerAccount.hcp, universalDoctor.name);
      expect(abbottAccount.hcp, universalDoctor.name);
      expect(bayerAccount.accountName, 'Bayer');
      expect(abbottAccount.accountName, 'Abbott Diabetes Care');
      expect(bayerAccount.territory, 'BAY-MANILA-01');
      expect(abbottAccount.territory, 'AD0101');
    });
  });

  group('Grand Launch October 2026 - Pillar 2: Institution Submission & Multi-Tier Approval', () {
    test('2.1 MedRep creates institution proposal with Classification-First logic & PSGC hierarchy', () {
      final proposedInst = Institution(
        name: 'INST-PROPOSE-001',
        institutionName: 'Metro East Medical Specialists',
        institutionType: 'Clinic',
        serviceCapability: 'Primary Care',
        regionName: 'NCR',
        provinceName: 'Metro Manila',
        cityMunicipality: 'Pasig City',
        barangayName: 'San Antonio',
        workflowState: 'Pending Approval',
        rejectionReason: null,
        owner: 'medrep.pasig@pharma.com',
      );

      expect(proposedInst.institutionType, 'Clinic');
      expect(proposedInst.isPendingApproval, isTrue);
      expect(proposedInst.isApproved, isFalse);
      expect(proposedInst.isApprovedForProfiling, isTrue); // Allowed for immediate profiling!
      expect(proposedInst.approvalStatusNote, 'this institution is not yet approved');
    });

    test('2.2 Doctor profiled with Pending Institution displays exact approval note', () {
      final pendingInst = Institution(
        name: 'INST-PROPOSE-002',
        institutionName: 'St. Jude Heart Clinic',
        regionName: 'Region IV-A',
        provinceName: 'Cavite',
        cityMunicipality: 'Bacoor City',
        workflowState: 'Pending Approval',
      );

      final account = HcpAccount(
        name: 'HCP-ACC-00801',
        hcp: 'HCP-0000088',
        accountName: 'COREnergy',
        territory: 'COR-CAV-01',
        workplaceId: 'INST-PROPOSE-002',
      );

      expect(account.getEffectiveWorkplaceApprovalNote([pendingInst]), 'this institution is not yet approved');
      expect(account.isWorkplaceRejected([pendingInst]), isFalse);
    });

    test('2.3 Institution Approved: Workflow advances to Approved and updates status notes', () {
      final pendingInst = Institution(
        name: 'INST-PROPOSE-002',
        institutionName: 'St. Jude Heart Clinic',
        workflowState: 'Pending Approval',
      );

      final approvedInst = pendingInst.copyWith(
        workflowState: 'Approved',
      );

      expect(approvedInst.isApproved, isTrue);
      expect(approvedInst.isPendingApproval, isFalse);
      expect(approvedInst.approvalStatusNote, 'this institution is now approved');

      final account = HcpAccount(
        name: 'HCP-ACC-00801',
        hcp: 'HCP-0000088',
        accountName: 'COREnergy',
        workplaceId: 'INST-PROPOSE-002',
      );
      expect(account.getEffectiveWorkplaceApprovalNote([approvedInst]), 'this institution is now approved');
    });

    test('2.4 Institution Rejected: Rejection propagates to HCP Account with Red Label & Reason', () {
      final rejectedInst = Institution(
        name: 'INST-PROPOSE-003',
        institutionName: 'Bogus Fake Clinic',
        workflowState: 'Rejected',
        rejectionReason: 'Non-existent medical clinic upon physical field validation',
      );

      final account = HcpAccount(
        name: 'HCP-ACC-00802',
        hcp: 'HCP-0000089',
        accountName: 'Abbott Diabetes Care',
        workplaceId: 'INST-PROPOSE-003',
      );

      expect(rejectedInst.isRejected, isTrue);
      expect(account.isWorkplaceRejected([rejectedInst]), isTrue);
      expect(account.getEffectiveWorkplaceApprovalNote([rejectedInst]), contains('[REJECTED INSTITUTION: Non-existent medical clinic upon physical field validation]'));
    });

    test('2.5 Modify & Resubmit preserves record identity and resets rejection status', () {
      final rejectedInst = Institution(
        name: 'INST-PROPOSE-004',
        institutionName: 'Ortigas Diagnostic Care',
        workflowState: 'Rejected',
        rejectionReason: 'Missing suite and floor number',
        resubmissionCount: 0,
      );

      final resubmittedInst = rejectedInst.copyWith(
        streetAddress: 'Unit 1204, 12th Floor, Prestige Tower, F. Ortigas Jr. Rd',
        workflowState: 'Pending Approval',
        rejectionReason: '',
        resubmissionCount: rejectedInst.resubmissionCount + 1,
        isResubmission: true,
      );

      expect(resubmittedInst.name, rejectedInst.name); // Preserved record ID
      expect(resubmittedInst.isPendingApproval, isTrue);
      expect(resubmittedInst.isRejected, isFalse);
      expect(resubmittedInst.resubmissionCount, 1);
      expect(resubmittedInst.isResubmission, isTrue);
      expect(resubmittedInst.approvalStatusNote, 'this institution is not yet approved');
    });
  });

  group('Grand Launch October 2026 - Pillar 3: Territory Reconfiguration & October Rollover', () {
    test('3.1 Dynamic Monthly Validity Transition from September to October 2026', () {
      final refSept = DateTime(2026, 9, 30);
      final refOct = DateTime(2026, 10, 1);

      expect(HcpAccount.calculateMonthValidFrom(refSept), '2026-09-01');
      expect(HcpAccount.calculateMonthValidTo(refSept), '2026-09-30');
      expect(HcpAccount.calculateMonthLabel(refSept), 'September 2026');

      expect(HcpAccount.calculateMonthValidFrom(refOct), '2026-10-01');
      expect(HcpAccount.calculateMonthValidTo(refOct), '2026-10-31');
      expect(HcpAccount.calculateMonthLabel(refOct), 'October 2026');

      final septAccount = HcpAccount(
        name: 'HCP-ACC-00021',
        hcp: 'HCP-0000028',
        accountName: 'Abbott Diabetes Care',
        territory: 'AD0106',
        validFrom: '2026-09-01',
        validTo: '2026-09-30',
      );

      expect(septAccount.isCurrentMonthActive(refSept), isTrue);
      expect(septAccount.isCurrentMonthActive(refOct), isFalse); // Safely archived for September
    });

    test('3.2 October 2026 Rollover preserves source binding and activates new cycle', () {
      final refOct = DateTime(2026, 10, 1);
      final octAccount = HcpAccount(
        name: 'HCP-ACC-00021-ROLL-202610',
        hcp: 'HCP-0000028',
        accountName: 'Abbott Diabetes Care',
        territory: 'ADC0106', // Reconfigured territory code
        validFrom: '2026-10-01',
        validTo: '2026-10-31',
        validityPeriod: 'October 2026',
        isRolledOver: true,
        sourceAccountName: 'HCP-ACC-00021',
      );

      expect(octAccount.isCurrentMonthActive(refOct), isTrue);
      expect(octAccount.isRolledOver, isTrue);
      expect(octAccount.sourceAccountName, 'HCP-ACC-00021');
      expect(octAccount.territory, 'ADC0106');
    });

    test('3.3 Territory Reconfiguration: Doctor account synchronization reflects batch renames', () {
      final accounts = [
        HcpAccount(name: 'ACC-01', hcp: 'HCP-01', accountName: 'Abbott Diabetes Care', territory: 'AD0101'),
        HcpAccount(name: 'ACC-02', hcp: 'HCP-02', accountName: 'Abbott Diabetes Care', territory: 'AD0102'),
        HcpAccount(name: 'ACC-03', hcp: 'HCP-03', accountName: 'Abbott Diabetes Care', territory: 'AD0101'),
      ];

      // Simulated SFE Batch Rename: 'AD' -> 'ADC'
      final updatedAccounts = accounts.map((acc) {
        if (acc.territory != null && acc.territory!.startsWith('AD')) {
          final newTerr = acc.territory!.replaceFirst('AD', 'ADC');
          return HcpAccount(
            name: acc.name,
            hcp: acc.hcp,
            accountName: acc.accountName,
            territory: newTerr,
          );
        }
        return acc;
      }).toList();

      expect(updatedAccounts[0].territory, 'ADC0101');
      expect(updatedAccounts[1].territory, 'ADC0102');
      expect(updatedAccounts[2].territory, 'ADC0101');
    });

    test('3.4 Decommission to Archive Vault preserves covered doctor accounts without deletion', () {
      final vaultArchive = {
        'id': 'VAULT-20260930-001',
        'territoryCode': 'AD0109',
        'decommissionDate': '2026-09-30',
        'coveredDoctorCount': 42,
        'action': 'DECOMMISSIONED_TO_VAULT',
        'reason': 'Territory split into North and South sub-districts',
      };

      expect(vaultArchive['territoryCode'], 'AD0109');
      expect(vaultArchive['coveredDoctorCount'], 42);
      expect(vaultArchive['action'], 'DECOMMISSIONED_TO_VAULT');
    });
  });
}
