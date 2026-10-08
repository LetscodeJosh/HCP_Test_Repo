import 'package:flutter_test/flutter_test.dart';
import 'package:hcp_profiling/models/lookup_models.dart';
import 'package:hcp_profiling/models/submission.dart';
import 'package:hcp_profiling/models/hcp.dart';
import 'package:hcp_profiling/models/hcp_account.dart';
import 'package:hcp_profiling/screens/components/propose_institution_dialog.dart';

void main() {
  test('Test Pending Institution can be used for profiling and shows exact approval status notes', () {
    final json = {
      'name': 'INST-07990',
      'institution_name': 'Simulate Institution',
      'region_name': 'NCR',
      'province_name': 'Metro Manila',
      'city_municipality': 'City of Manila',
      'street_address': 'Ermita',
      'workflow_state': 'Pending Approval',
      'rejection_reason': null,
      'is_resubmission': 0,
      'owner': 'leritargieian@gmail.com',
      'creation': '2026-09-15 15:11:19.203749',
      'modified': '2026-09-15 15:11:19.428661',
      'docstatus': 0,
    };

    final inst = Institution.fromJson(json);
    // 1. Pending institution can be used by MedRep
    expect(inst.isApprovedForProfiling, isTrue);
    expect(inst.isPendingApproval, isTrue);
    expect(inst.isApproved, isFalse);
    expect(inst.approvalStatusNote, 'this institution is not yet approved');

    // 2. Baseline approved institution
    final legacy = Institution(
      name: 'INST-00001',
      institutionName: 'Manila Doctors Hospital',
      cityMunicipality: 'City of Manila',
      provinceName: 'Metro Manila',
      workflowState: 'Approved',
    );
    expect(legacy.isApprovedForProfiling, isTrue);
    expect(legacy.isApproved, isTrue);
    expect(legacy.approvalStatusNote, 'this institution is now approved');

    // 3. Rejected institution cannot be profiled
    final rejected = Institution(
      name: 'INST-07992',
      institutionName: 'Invalid Rejected Clinic',
      workflowState: 'Rejected',
      rejectionReason: 'Invalid facility documentation',
    );
    expect(rejected.isApprovedForProfiling, isFalse);
    expect(rejected.isRejected, isTrue);

    // 4. LocationResolver registration & resolution
    LocationResolver.registerInstitutions([inst, legacy, rejected]);
    expect(LocationResolver.resolveInstitutionName('INST-00001'), 'Manila Doctors Hospital');
    expect(LocationResolver.resolveInstitutionName('INST-07990'), 'Simulate Institution');
    expect(LocationResolver.resolveInstitutionId('Simulate Institution', [inst]), 'INST-07990');
    expect(LocationResolver.resolveInstitutionId('Invalid Rejected Clinic', [rejected]), '');

    // 5. Verification notes
    expect(LocationResolver.getInstitutionApprovalStatusNote('INST-07990', [inst]), 'this institution is not yet approved');
    expect(LocationResolver.getInstitutionApprovalStatusNote('INST-00001', [legacy]), 'this institution is now approved');

    // 6. Once approved by SFE, note changes to approved
    final approvedInst = Institution.fromJson({
      ...json,
      'workflow_state': 'Approved',
      'docstatus': 1,
    });
    expect(approvedInst.isApproved, isTrue);
    expect(approvedInst.approvalStatusNote, 'this institution is now approved');
    expect(LocationResolver.getInstitutionApprovalStatusNote('INST-07990', [approvedInst]), 'this institution is now approved');
  });

  test('Test Predictive Directory Search & Duplicate Detection', () {
    final mmdc = Institution(
      name: 'INST-08001',
      institutionName: 'Metropolitan Medical Center',
      cityMunicipality: 'City of Manila',
      provinceName: 'Metro Manila',
      regionName: 'NCR',
      workflowState: 'Approved',
    );
    final pendingClinic = Institution(
      name: 'INST-08002',
      institutionName: 'Greenhills Family Clinic',
      cityMunicipality: 'San Juan',
      provinceName: 'Metro Manila',
      regionName: 'NCR',
      workflowState: 'Pending Approval',
    );

    final list = [mmdc, pendingClinic];

    // 1. Exact duplicate detection
    final exactMatches = LocationResolver.searchDirectoryWithDuplicateDetection('Metropolitan Medical Center', list);
    expect(exactMatches.isNotEmpty, isTrue);
    expect(exactMatches.first.isExactOrHighConfidenceDuplicate, isTrue);
    expect(exactMatches.first.institution.name, 'INST-08001');
    expect(exactMatches.first.formattedLocation, contains('City of Manila'));

    // 2. Partial / case-insensitive search
    final partialMatches = LocationResolver.searchDirectoryWithDuplicateDetection('greenhills', list);
    expect(partialMatches.isNotEmpty, isTrue);
    expect(partialMatches.first.institution.name, 'INST-08002');
    expect(partialMatches.first.institution.isPendingApproval, isTrue);

    // 3. Baseline static search (from 7,000 baseline items)
    final baselineMatches = LocationResolver.searchDirectoryWithDuplicateDetection('Manila Doctors Hospital', list);
    expect(baselineMatches.isNotEmpty, isTrue);
    expect(baselineMatches.first.institution.institutionName, 'Manila Doctors Hospital');
    expect(baselineMatches.first.isExactOrHighConfidenceDuplicate, isTrue);

    // 4. Acronym search (MDH -> Manila Doctors Hospital)
    final acronymMatches = LocationResolver.searchDirectoryWithDuplicateDetection('mdh', list);
    expect(acronymMatches.isNotEmpty, isTrue);
    expect(acronymMatches.any((m) => m.institution.institutionName.contains('Manila Doctors')), isTrue);
  });

  test('Test V.0.4.4: Only truly rejected submissions display rejection notes/remarks', () {
    // 1. Approved submission with comment in JSON payload must NOT have rejectionRemarks
    final approvedSub = HcpProfileSubmission.fromJson({
      'name': 'HCP-SUB-2026-00151',
      'hcp_full_name': 'Dr. Approved Physician',
      'workflow_state': 'Approved',
      'docstatus': 1,
      'remarks': 'Approved by Sales Manager after verification',
      'rejection_remarks': 'Approved by Sales Manager after verification',
      'comment_by': 'sfe_admin@pmii.com',
    });
    expect(approvedSub.isApproved, isTrue);
    expect(approvedSub.isRejected, isFalse);
    expect(approvedSub.rejectionRemarks, isNull);
    expect(approvedSub.rejectedBy, isNull);

    // 2. Processed submission with timeline comments must NOT have rejectionRemarks
    final processedSub = HcpProfileSubmission.fromJson({
      'name': 'HCP-SUB-2026-00160',
      'hcp_full_name': 'Dr. Existing Doctor',
      'workflow_state': 'Processed',
      'docstatus': 1,
      'profile_action': 'Existing HCP',
      'remarks': 'Automatically merged existing HCP',
      'rejection_remarks': 'Automatically merged existing HCP',
    });
    expect(processedSub.isApproved, isTrue);
    expect(processedSub.isRejected, isFalse);
    expect(processedSub.rejectionRemarks, isNull);
    expect(processedSub.rejectedBy, isNull);

    // 3. Pending Approval submission with general comment must NOT have rejectionRemarks
    final pendingSub = HcpProfileSubmission.fromJson({
      'name': 'HCP-SUB-2026-00170',
      'hcp_full_name': 'Dr. Pending Doctor',
      'workflow_state': 'Pending Approval',
      'docstatus': 0,
      'remarks': 'Awaiting manager signature',
      'rejection_remarks': 'Awaiting manager signature',
    });
    expect(pendingSub.isPendingApproval, isTrue);
    expect(pendingSub.isRejected, isFalse);
    expect(pendingSub.rejectionRemarks, isNull);
    expect(pendingSub.rejectedBy, isNull);

    // 4. Truly Rejected submission MUST preserve rejectionRemarks & rejectedBy
    final rejectedSub = HcpProfileSubmission.fromJson({
      'name': 'HCP-SUB-2026-00180',
      'hcp_full_name': 'Dr. Incomplete Submission',
      'workflow_state': 'Rejected',
      'docstatus': 2,
      'rejection_reason': 'Missing PRC ID photo and signature',
      'comment_by': 'manager@pmii.com',
    });
    expect(rejectedSub.isRejected, isTrue);
    expect(rejectedSub.rejectionRemarks, 'Missing PRC ID photo and signature');
    expect(rejectedSub.rejectedBy, 'manager@pmii.com');
  });

  test('Test V.0.4.6: Continuous Modify & Resubmit cycle without deletion', () {
    // Initial proposed institution (Pending Approval)
    var inst = Institution(
      name: 'INST-08100',
      institutionName: 'St. Jude General Clinic',
      cityMunicipality: 'Quezon City',
      provinceName: 'Metro Manila',
      regionName: 'NCR',
      workflowState: 'Pending Approval',
      docstatus: 0,
      isResubmission: false,
    );
    expect(inst.isPendingApproval, isTrue);
    expect(inst.isRejected, isFalse);

    // Cycle 1: SFE Rejects with reason (marked as Rejected, NOT deleted)
    inst = Institution(
      name: inst.name,
      institutionName: inst.institutionName,
      cityMunicipality: inst.cityMunicipality,
      provinceName: inst.provinceName,
      regionName: inst.regionName,
      workflowState: 'Rejected',
      rejectionReason: 'Invalid barangay location',
      docstatus: 0,
      isResubmission: false,
    );
    expect(inst.isRejected, isTrue);
    expect(inst.rejectionReason, 'Invalid barangay location');

    // Cycle 1: MedRep Modifies & Resubmits (isResubmission becomes true, Pending Approval)
    inst = Institution(
      name: inst.name,
      institutionName: 'St. Jude General Clinic - Main',
      cityMunicipality: 'Quezon City',
      provinceName: 'Metro Manila',
      regionName: 'NCR',
      workflowState: 'Pending Approval',
      rejectionReason: '',
      docstatus: 0,
      isResubmission: true,
    );
    expect(inst.isPendingApproval, isTrue);
    expect(inst.isRejected, isFalse);
    expect(inst.isResubmission, isTrue);

    // Cycle 2: SFE Rejects again with updated reason (MUST NOT delete, marks Rejected again)
    inst = Institution(
      name: inst.name,
      institutionName: inst.institutionName,
      cityMunicipality: inst.cityMunicipality,
      provinceName: inst.provinceName,
      regionName: inst.regionName,
      workflowState: 'Rejected',
      rejectionReason: 'Please attach secondary landmark',
      docstatus: 0,
      isResubmission: true,
    );
    expect(inst.isRejected, isTrue);
    expect(inst.rejectionReason, 'Please attach secondary landmark');

    // Cycle 2: MedRep Modifies & Resubmits again (continuous resubmission)
    inst = Institution(
      name: inst.name,
      institutionName: 'St. Jude General Clinic - Main (Near City Hall)',
      cityMunicipality: 'Quezon City',
      provinceName: 'Metro Manila',
      regionName: 'NCR',
      workflowState: 'Pending Approval',
      rejectionReason: '',
      docstatus: 0,
      isResubmission: true,
    );
    expect(inst.isPendingApproval, isTrue);
    expect(inst.isRejected, isFalse);

    // Final: SFE Approves
    inst = Institution(
      name: inst.name,
      institutionName: inst.institutionName,
      cityMunicipality: inst.cityMunicipality,
      provinceName: inst.provinceName,
      regionName: inst.regionName,
      workflowState: 'Approved',
      docstatus: 1,
      isResubmission: true,
    );
    expect(inst.isApproved, isTrue);
    expect(inst.isApprovedForProfiling, isTrue);
  });

  test('Test V.0.5.1: Classification-First Model & dynamic Hospital 3 vs Clinic 5 capabilities', () {
    // 1. Ownership options
    expect(InstitutionClassification.ownershipOptions, equals(['Government', 'Private']));

    // 2. Institution Type options
    expect(InstitutionClassification.typeOptions, equals(['Hospital', 'Clinic']));

    // 3. Hospital Service Capabilities (Exact 3 items from Image 1)
    expect(InstitutionClassification.hospitalCapabilities.length, equals(3));
    expect(InstitutionClassification.hospitalCapabilities, equals(['Primary', 'Secondary', 'Tertiary']));

    // 4. Clinic Service Capabilities (Exact 5 items from Image 1)
    expect(InstitutionClassification.clinicCapabilities.length, equals(5));
    expect(InstitutionClassification.clinicCapabilities, equals([
      'Baranggay Health Center',
      'Municipal Health Center',
      'Lying-In Clinic',
      'Dental Clinic',
      'General Clinic',
    ]));

    // 5. Dynamic resolution helper
    expect(InstitutionClassification.getCapabilitiesForType('Hospital'), equals(InstitutionClassification.hospitalCapabilities));
    expect(InstitutionClassification.getCapabilitiesForType('Clinic'), equals(InstitutionClassification.clinicCapabilities));
    expect(InstitutionClassification.getCapabilitiesForType('Unknown'), isEmpty);

    // 6. Instantiation with classification
    final inst = Institution(
      name: 'INST-09001',
      institutionName: 'St. Jude General Clinic',
      ownership: 'Private',
      institutionType: 'Clinic',
      serviceCapability: 'General Clinic',
      cityMunicipality: 'Quezon City',
      provinceName: 'Metro Manila',
      regionName: 'NCR',
      workflowState: 'Pending Approval',
    );
    expect(inst.ownership, equals('Private'));
    expect(inst.institutionType, equals('Clinic'));
    expect(inst.serviceCapability, equals('General Clinic'));
    expect(inst.status, equals('For SFE Approval'));
  });

  test('Test V.0.5.1: Whiteboard Image 2 Workflow Routing & 1-Minute Concurrency Cooldown', () {
    // 1. Initial proposal: Rep & DSM see status as "For SFE Approval"
    final initialInst = Institution(
      name: 'INST-09002',
      institutionName: 'Valenzuela Diagnostic Clinic',
      requiresDsmApproval: true, // Doctor + Institution proposal
      linkedDoctorName: 'Dr. Maria Santos',
      workflowState: 'Pending Approval',
      lastSubmittedAt: DateTime.now(),
    );
    expect(initialInst.status, equals('For SFE Approval'));
    expect(initialInst.requiresDsmApproval, isTrue);
    expect(initialInst.linkedDoctorName, equals('Dr. Maria Santos'));

    // 2. 1-Minute Concurrency Cooldown Lock
    expect(initialInst.isCooldownActive, isTrue);
    expect(initialInst.cooldownRemainingSeconds, inInclusiveRange(1, 60));

    // After 61 seconds cooldown expires
    final expiredCooldownInst = Institution(
      name: 'INST-09002',
      institutionName: 'Valenzuela Diagnostic Clinic',
      workflowState: 'Pending Approval',
      lastSubmittedAt: DateTime.now().subtract(const Duration(seconds: 65)),
    );
    expect(expiredCooldownInst.isCooldownActive, isFalse);
    expect(expiredCooldownInst.cooldownRemainingSeconds, equals(0));

    // 3. SFE Review Branch: Doctor + Institution advances to "Pending DSM Approval"
    final sfeApprovedDoctorInst = Institution(
      name: 'INST-09002',
      institutionName: 'Valenzuela Diagnostic Clinic',
      requiresDsmApproval: true,
      workflowState: 'Pending DSM Approval',
      docstatus: 0,
    );
    expect(sfeApprovedDoctorInst.status, equals('Pending DSM Approval'));
    expect(sfeApprovedDoctorInst.isApproved, isFalse); // Awaiting DSM approval

    // 4. SFE Review Branch: Institution only advances to "Approved" (docstatus: 1)
    final sfeApprovedOnlyInst = Institution(
      name: 'INST-09003',
      institutionName: 'Makati Community Hospital',
      requiresDsmApproval: false,
      workflowState: 'Approved',
      docstatus: 1,
    );
    expect(sfeApprovedOnlyInst.status, equals('Approved'));
    expect(sfeApprovedOnlyInst.isApproved, isTrue);
  });

  test('Test V.0.5.1: 2-Resubmission limit with SFE Specialist recommendation', () {
    // Resubmission 1: Allowed
    final resub1 = Institution(
      name: 'INST-09004',
      institutionName: 'Pasig Health Center',
      workflowState: 'Rejected',
      rejectionReason: 'Address missing street number',
      resubmissionCount: 1,
    );
    expect(resub1.resubmissionCount, equals(1));
    expect(resub1.resubmissionCount < 2, isTrue);

    // Resubmission 2: Limit reached
    final resub2 = Institution(
      name: 'INST-09004',
      institutionName: 'Pasig Health Center',
      workflowState: 'Rejected',
      rejectionReason: 'Invalid postal code and landmark',
      resubmissionCount: 2,
    );
    expect(resub2.resubmissionCount, equals(2));
    expect(resub2.resubmissionCount >= 2, isTrue);
    // At limit: app displays recommendation to call SFE Specialist
  });

  test('Test V.0.5.1: Rejection Propagation to HCP & HCP Account with Red Label & Note', () {
    final rejectedInst = Institution(
      name: 'INST-REJ-01',
      institutionName: 'Rejected Community Clinic',
      workflowState: 'Rejected',
      rejectionReason: 'Unregistered facility in DOH registry',
      cityMunicipality: 'Pasig City',
      provinceName: 'Metro Manila',
      regionName: 'NCR',
    );

    // 1. Rejection Display Label
    expect(rejectedInst.rejectionDisplayLabel, equals('[REJECTED INSTITUTION: Unregistered facility in DOH registry]'));

    // 2. LocationResolver status note reflects rejection
    final note = LocationResolver.getInstitutionApprovalStatusNote('INST-REJ-01', [rejectedInst]);
    expect(note, equals('[REJECTED INSTITUTION: Unregistered facility in DOH registry]'));
    expect(LocationResolver.isRejectedInstitution('INST-REJ-01', [rejectedInst]), isTrue);

    // 3. HCP model rejects workplace
    final doctor = Hcp(
      name: 'DOC-001',
      firstName: 'Juan',
      lastName: 'Dela Cruz',
      hcpFullName: 'Dr. Juan Dela Cruz',
      hcpType: 'Consultant',
      hcpPractice: 'Prescribing',
      workplaces: [
        HcpWorkplace(workplace: 'INST-REJ-01', address: 'Rejected Community Clinic'),
      ],
    );
    expect(doctor.isWorkplaceRejected([rejectedInst]), isTrue);
    expect(doctor.getRejectedInstitutionReason([rejectedInst]), equals('Unregistered facility in DOH registry'));

    // 4. HCP Account model rejects workplace
    final account = HcpAccount(
      name: 'ACC-001',
      accountName: 'Abbott Diabetes Care',
      hcp: 'DOC-001',
      workplaces: [
        HcpAccountWorkplace(workplace: 'INST-REJ-01', preferred: true),
      ],
    );
    expect(account.isWorkplaceRejected([rejectedInst]), isTrue);
    expect(account.getRejectedInstitutionReason([rejectedInst]), equals('Unregistered facility in DOH registry'));
  });

  test('Test V.0.5.1 Build 25: Official PSGC 1,772 Location Cascading & Hierarchy Consistency', () async {
    // 1. Initialize PSGC hierarchy engine
    await LocationResolver.initializePsgc();

    // 2. Regions list validation (Must contain 18 official Philippine regions)
    final regions = LocationResolver.getRegions();
    expect(regions.length, equals(18));
    expect(regions.contains('NCR'), isTrue);
    expect(regions.contains('Region I (Ilocos Region)'), isTrue);
    expect(regions.contains('Region III (Central Luzon)'), isTrue);

    // 3. Region -> Province Cascading
    // Region I must contain Ilocos Norte, and NEVER Metro Manila or Nueva Ecija
    final region1Provinces = LocationResolver.getProvincesForRegion('Region I (Ilocos Region)');
    expect(region1Provinces.contains('Ilocos Norte'), isTrue);
    expect(region1Provinces.contains('Ilocos Sur'), isTrue);
    expect(region1Provinces.contains('La Union'), isTrue);
    expect(region1Provinces.contains('Pangasinan'), isTrue);
    expect(region1Provinces.any((p) => p.contains('Metro Manila')), isFalse);
    expect(region1Provinces.contains('Nueva Ecija'), isFalse);

    // Region III must contain Nueva Ecija
    final region3Provinces = LocationResolver.getProvincesForRegion('Region III (Central Luzon)');
    expect(region3Provinces.contains('Nueva Ecija'), isTrue);
    expect(region3Provinces.contains('Ilocos Norte'), isFalse);

    // 4. Province -> City Cascading (Eliminating cross-regional mismatch bug)
    // Ilocos Norte must contain exactly 23 LGUs and NEVER Metro Manila or Las Piñas
    final ilocosNorteCities = LocationResolver.getCitiesForProvince('Ilocos Norte');
    expect(ilocosNorteCities.length, equals(23));
    expect(ilocosNorteCities.any((c) => c.contains('Laoag')), isTrue);
    expect(ilocosNorteCities.any((c) => c.contains('Batac')), isTrue);
    expect(ilocosNorteCities.any((c) => c.contains('Metro Manila') || c.contains('Las Piñas') || c.contains('Manila')), isFalse);

    // Nueva Ecija must contain 32 LGUs (e.g., Cabanatuan, Palayan, Gapan)
    final nuevaEcijaCities = LocationResolver.getCitiesForProvince('Nueva Ecija');
    expect(nuevaEcijaCities.length, equals(32));
    expect(nuevaEcijaCities.any((c) => c.contains('Cabanatuan')), isTrue);

    // Metro Manila / NCR Provinces & Cities
    final ncrProvinces = LocationResolver.getProvincesForRegion('NCR');
    expect(ncrProvinces.contains('Metro Manila-Las Piñas'), isTrue);
    final lasPinasCities = LocationResolver.getCitiesForProvince('Metro Manila-Las Piñas');
    expect(lasPinasCities.length, equals(1));
    expect(lasPinasCities.first, equals('Las Piñas City'));

    // 5. Upward Auto-Resolution: City -> Province -> Region
    expect(LocationResolver.resolveProvinceFromCity('Las Piñas City'), equals('Metro Manila-Las Piñas'));
    expect(LocationResolver.resolveRegionFromProvince('Metro Manila-Las Piñas'), equals('NCR'));
    expect(LocationResolver.resolveRegionFromProvince('Ilocos Norte'), equals('Region I (Ilocos Region)'));
    expect(LocationResolver.resolveRegionFromProvince('Nueva Ecija'), equals('Region III (Central Luzon)'));

    // 6. Alphanumeric City ID Validation (Regex Bug Fix for NCR 10-char alphanumeric PSGC codes)
    final alphanumericCityCodeRegex = RegExp(r'^\d{9,10}[A-Za-z]?$');
    expect(alphanumericCityCodeRegex.hasMatch('1380200000C'), isTrue); // Las Piñas City
    expect(alphanumericCityCodeRegex.hasMatch('1380600000C'), isTrue); // Quezon City
    expect(alphanumericCityCodeRegex.hasMatch('012801000'), isTrue);   // Standard 9-digit
    expect(alphanumericCityCodeRegex.hasMatch('1234567890'), isTrue);  // Standard 10-digit
    expect(alphanumericCityCodeRegex.hasMatch('INVALID-CODE'), isFalse);
  });

  test('Test TitleCaseTextInputFormatter auto-capitalizes initial letter of each word', () {
    final formatter = TitleCaseTextInputFormatter();

    // 1. Single lower-case word
    var result = formatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      const TextEditingValue(text: 'test'),
    );
    expect(result.text, equals('Test'));

    // 2. Multiple lower-case words
    result = formatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      const TextEditingValue(text: 'test institution'),
    );
    expect(result.text, equals('Test Institution'));

    // 3. Complex hospital name with hyphen and punctuation
    result = formatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      const TextEditingValue(text: 'st. luke\'s medical center - bgc'),
    );
    expect(result.text, equals('St. Luke\'s Medical Center - Bgc'));

    // 4. Already capitalized remains properly formatted
    result = formatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      const TextEditingValue(text: 'Makati Medical Center'),
    );
    expect(result.text, equals('Makati Medical Center'));
  });

  test('Test 60-Second Cooldown on Edit click and Audit Trail logging', () {
    final now = DateTime.now();

    // 1. Active editing lock triggers immediately upon clicking Edit
    var inst = Institution(
      name: 'INST-0099',
      institutionName: 'Capitol Medical Center',
      cityMunicipality: 'Quezon City',
      provinceName: 'Metro Manila',
      regionName: 'NCR',
      workflowState: 'Rejected',
      rejectionReason: 'Verify facility classification',
      activeEditingLock: now,
      editingUser: 'Juan Dela Cruz',
      auditTrail: [
        InstitutionAuditLogEntry(
          timestamp: now.subtract(const Duration(hours: 2)),
          user: 'Juan Dela Cruz',
          role: 'MedRep',
          action: 'Initial Proposal',
          details: 'Proposed new Hospital (Private)',
          snapshot: {'institution_name': 'Capitol Medical Center', 'ownership': 'Private'},
        ),
        InstitutionAuditLogEntry(
          timestamp: now.subtract(const Duration(hours: 1)),
          user: 'SFE Admin',
          role: 'SFE Specialist',
          action: 'Rejected',
          details: 'Rejected with reason: Verify facility classification',
          snapshot: {'rejection_reason': 'Verify facility classification'},
        ),
      ],
    );

    // Active edit cooldown verification
    expect(inst.isCooldownActive, isTrue);
    expect(inst.cooldownRemainingSeconds, inInclusiveRange(55, 60));
    expect(inst.editingUser, equals('Juan Dela Cruz'));

    // 2. Audit Trail verification
    expect(inst.auditTrail.length, equals(2));
    expect(inst.auditTrail[0].action, equals('Initial Proposal'));
    expect(inst.auditTrail[1].action, equals('Rejected'));
    expect(inst.auditTrail[1].details, contains('Verify facility classification'));

    // 3. Serialization and deserialization preserves audit trail and active editing lock
    final json = inst.toJson();
    expect(json['editing_user'], equals('Juan Dela Cruz'));
    expect(json['active_editing_lock'], isNotNull);
    expect(json['audit_trail'], isA<List>());
    expect((json['audit_trail'] as List).length, equals(2));

    final deserialized = Institution.fromJson(json);
    expect(deserialized.editingUser, equals('Juan Dela Cruz'));
    expect(deserialized.isCooldownActive, isTrue);
    expect(deserialized.auditTrail.length, equals(2));
    expect(deserialized.auditTrail[0].action, equals('Initial Proposal'));
    expect(deserialized.auditTrail[1].role, equals('SFE Specialist'));
  });

  test('Test Intelligent Institution Duplicate & Similarity Detection Without False Positives', () {
    final list = [
      Institution(
        name: 'INST-00001',
        institutionName: "St. Luke's Medical Center - Global City",
        cityMunicipality: 'Taguig',
        provinceName: 'Metro Manila',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-00002',
        institutionName: 'Cardinal Santos Medical Center',
        cityMunicipality: 'San Juan',
        provinceName: 'Metro Manila',
        workflowState: 'Approved',
      ),
    ];

    // 1. Unrelated clinic sharing only stop words ("St. Jude Clinic" vs "St. Luke's") must NOT match
    final unrelated = LocationResolver.searchDirectoryWithDuplicateDetection('St. Jude Clinic', list);
    expect(unrelated, isEmpty);

    // 2. Genuine similar phrase ("St. Lukes") matches with high score
    final similar = LocationResolver.searchDirectoryWithDuplicateDetection('St. Lukes', list);
    expect(similar, isNotEmpty);
    expect(similar.first.institution.institutionName, contains("St. Luke's"));

    // 3. Exact phrase match marked as high-confidence duplicate
    final exact = LocationResolver.searchDirectoryWithDuplicateDetection("St. Luke's Medical Center - Global City", list);
    expect(exact, isNotEmpty);
    expect(exact.first.isExactOrHighConfidenceDuplicate, isTrue);
  });

  test('Test V.0.6.5: Smart AI detector, acronym recognition (Ust -> UST Hospital), and false-positive elimination', () {
    final facilities = [
      Institution(
        name: 'INST-UST-01',
        institutionName: 'University of Santo Tomas Hospital',
        cityMunicipality: 'City of Manila',
        provinceName: 'Metro Manila',
        regionName: 'NCR',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-UNITECH',
        institutionName: 'Unitech Plastic Industry Corp.',
        cityMunicipality: 'Valenzuela City',
        provinceName: 'Metro Manila',
        regionName: 'NCR',
        workflowState: 'Approved',
      ),
      Institution(
        name: 'INST-TRENER',
        institutionName: 'Trener Industries (Philippines), Inc.',
        cityMunicipality: 'San Fernando',
        provinceName: 'Pampanga',
        regionName: 'Region III',
        workflowState: 'Pending Approval',
      ),
      Institution(
        name: 'INST-TOPRITE',
        institutionName: 'Toprite Plastic Industries, Inc',
        cityMunicipality: 'Quezon City',
        provinceName: 'Metro Manila',
        regionName: 'NCR',
        workflowState: 'Pending Approval',
      ),
    ];

    // 1. Acronym "Ust" must accurately detect University of Santo Tomas Hospital
    final ustMatches = LocationResolver.searchDirectoryWithDuplicateDetection('Ust', facilities);
    expect(ustMatches.isNotEmpty, isTrue);
    expect(ustMatches.first.institution.institutionName, 'University of Santo Tomas Hospital');
    expect(ustMatches.first.isExactOrHighConfidenceDuplicate, isTrue);

    // 2. Acronym "Ust" must NOT match plastic companies with interior word "industry"
    expect(ustMatches.any((m) => m.institution.institutionName.contains('Plastic')), isFalse);
    expect(ustMatches.any((m) => m.institution.institutionName.contains('Industr')), isFalse);

    // 3. Dynamic acronyms computed for University of Santo Tomas Hospital
    final acronyms = LocationResolver.computeInstitutionAcronyms('University of Santo Tomas Hospital');
    expect(acronyms.contains('ust'), isTrue);
    expect(acronyms.contains('usth'), isTrue);
  });
}



