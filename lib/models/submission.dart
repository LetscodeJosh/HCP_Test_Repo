import 'lookup_models.dart';
import '../services/data_sanitizer.dart';

class HcpProfileSubmission {
  final String? name;
  final String hcpName; // Link -> HCP
  final String? hcpFullName;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? birthDate;
  final bool consentPrivacyUnderstood;
  final String? consentSignature;
  final String? consentPhoto;
  final String? hcpPhoto;
  final String? hcpType;
  final String? hcpPractice;
  final List<SubmissionSpecialty> specialties;
  final List<SubmissionWorkplace> workplaces;
  final List<SubmissionContact> contacts;
  final String? regionName;
  final String? provinceName;
  final String? cityMunicipality;
  final String? barangayName;
  final String? institution;
  final String? accountOrProgram; // Link -> Branch
  final String? territory; // Link -> Territory
  final String? salesPerson; // Territory Manager
  final String? userId; // Link -> User
  final String? surveyTemplate; // Link -> HCP Survey Template
  final String? surveyTemplateTitle;
  final String? medrepEmail; // Link -> User
  final String? owner;
  final String? submissionDate;
  final String? surveyResponse; // Link -> HCP Survey Response
  final List<SubmissionAnswer> answers; // Table -> HCP Profile Submission Answer
  final String? validFrom;
  final String? validTo;
  final String? validityPeriod;
  final String? status; // ERPNext status field
  final String? workflowState; // Draft, Pending Approval, Approved, Rejected, Cancelled
  final String? applicationStatus; // Not Applied, Applying, Applied, Failed
  final String? changeSummaryHtml;
  final String? changesJson;
  final int docstatus; // 0: Draft/Pending, 1: Approved/Submitted, 2: Cancelled
  final String? profileAction; // 'New HCP' or 'Existing HCP'
  final String? rejectionRemarks;
  final String? rejectedBy;

  bool isWorkplaceRejected([List<Institution>? dynamicInsts]) {
    if (institution != null && LocationResolver.isRejectedInstitution(institution, dynamicInsts)) {
      return true;
    }
    if (rejectionRemarks != null && rejectionRemarks!.toUpperCase().contains('REJECTED')) {
      return true;
    }
    return workplaces.any((w) =>
        w.isRejected ||
        LocationResolver.isRejectedInstitution(w.hcpWorkplace, dynamicInsts) ||
        LocationResolver.isRejectedInstitution(w.workplaceName, dynamicInsts));
  }

  String? getRejectedInstitutionReason([List<Institution>? dynamicInsts]) {
    if (institution != null && LocationResolver.isRejectedInstitution(institution, dynamicInsts)) {
      final match = dynamicInsts?.firstWhere(
        (i) => i.name.toLowerCase() == institution!.toLowerCase() || i.institutionName.toLowerCase() == institution!.toLowerCase(),
        orElse: () => Institution(name: '', institutionName: ''),
      );
      if (match != null && match.rejectionReason != null && match.rejectionReason!.trim().isNotEmpty) {
        return match.rejectionReason!.trim();
      }
    }
    for (var w in workplaces) {
      if (w.rejectionReason != null && w.rejectionReason!.trim().isNotEmpty) {
        return w.rejectionReason!.trim();
      }
      if (LocationResolver.isRejectedInstitution(w.hcpWorkplace, dynamicInsts)) {
        final match = dynamicInsts?.firstWhere(
          (i) => i.name.toLowerCase() == (w.hcpWorkplace ?? '').toLowerCase() || i.institutionName.toLowerCase() == (w.hcpWorkplace ?? '').toLowerCase(),
          orElse: () => Institution(name: '', institutionName: ''),
        );
        if (match != null && match.rejectionReason != null && match.rejectionReason!.trim().isNotEmpty) {
          return match.rejectionReason!.trim();
        }
      }
    }
    if (rejectionRemarks != null && rejectionRemarks!.toUpperCase().contains('REJECTED')) {
      return rejectionRemarks;
    }
    return null;
  }

  HcpProfileSubmission({
    this.name,
    required this.hcpName,
    this.hcpFullName,
    this.firstName,
    this.middleName,
    this.lastName,
    this.birthDate,
    this.consentPrivacyUnderstood = false,
    this.consentSignature,
    this.consentPhoto,
    this.hcpPhoto,
    this.hcpType,
    this.hcpPractice,
    this.specialties = const [],
    this.workplaces = const [],
    this.contacts = const [],
    this.regionName,
    this.provinceName,
    this.cityMunicipality,
    this.barangayName,
    this.institution,
    this.accountOrProgram,
    this.territory,
    this.salesPerson,
    this.userId,
    this.surveyTemplate,
    this.surveyTemplateTitle,
    this.medrepEmail,
    this.owner,
    this.submissionDate,
    this.surveyResponse,
    this.answers = const [],
    this.validFrom,
    this.validTo,
    this.validityPeriod,
    this.status,
    this.workflowState,
    this.applicationStatus,
    this.changeSummaryHtml,
    this.changesJson,
    this.docstatus = 0,
    this.profileAction,
    this.rejectionRemarks,
    this.rejectedBy,
  });

  factory HcpProfileSubmission.fromJson(Map<String, dynamic> json) {
    final rawDocstatus = json['docstatus'] is int ? json['docstatus'] as int : int.tryParse('${json['docstatus']}') ?? 0;
    
    // Resolve workflow state accurately according to ERPNext HCP Profile Submission WF
    String resolvedWorkflow = 'Draft';
    final rawWf = (json['workflow_state'] ?? json['status'] ?? '').toString().trim();
    if (rawWf.isNotEmpty) {
      final lower = rawWf.toLowerCase();
      if (lower == 'draft') {
        resolvedWorkflow = 'Draft';
      } else if (lower == 'processed' || lower.contains('proc')) {
        resolvedWorkflow = 'Processed';
      } else if (lower == 'pending approval' || lower.contains('pend')) {
        resolvedWorkflow = 'Pending Approval';
      } else if (lower == 'approved' || (lower.contains('appr') && !lower.contains('pend'))) {
        resolvedWorkflow = 'Approved';
      } else if (lower == 'rejected' || lower.contains('reject')) {
        resolvedWorkflow = 'Rejected';
      } else if (lower == 'cancelled' || lower.contains('cancel')) {
        resolvedWorkflow = 'Cancelled';
      } else {
        resolvedWorkflow = rawWf;
      }
    } else {
      if (rawDocstatus == 1) {
        resolvedWorkflow = 'Approved';
      } else if (rawDocstatus == 2) {
        resolvedWorkflow = 'Rejected';
      } else {
        resolvedWorkflow = 'Draft';
      }
    }

    // Resolve full name cleanly if hcp_full_name is missing
    String? resolvedFullName = json['hcp_full_name'];
    if (resolvedFullName == null || resolvedFullName.toString().trim().isEmpty) {
      final fn = (json['first_name'] ?? '').toString().trim();
      final mn = (json['middle_name'] ?? '').toString().trim();
      final ln = (json['last_name'] ?? '').toString().trim();
      final parts = [fn, mn.isNotEmpty && mn != '-' ? mn : null, ln].where((p) => p != null && p.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        resolvedFullName = parts.join(' ');
      }
    }

    // Resolve application status (Not Applied, Applying, Applied, Failed)
    String resolvedAppStatus = json['application_status'] ?? ((resolvedWorkflow == 'Approved' || resolvedWorkflow == 'Processed' || rawDocstatus == 1) ? 'Applied' : 'Not Applied');

    // Resolve Profile Action (Existing HCP vs New HCP)
    final rawProfileAction = (json['profile_action'] ?? '').toString().trim();
    final String resolvedHcpId = (json['hcp_name'] ?? '').toString().trim();
    final String resolvedAction = rawProfileAction.isNotEmpty
        ? rawProfileAction
        : (resolvedHcpId.isNotEmpty ? 'Existing HCP' : 'New HCP');

    final bool isActuallyRejected = rawDocstatus == 2 || resolvedWorkflow == 'Rejected';

    final parsedWorkplaces = (json['table_workplaces'] as List? ?? json['workplaces'] as List? ?? json['hcp_workplace'] as List?)
            ?.map((e) => SubmissionWorkplace.fromJson(e))
            .toList() ?? [];

    SubmissionWorkplace? primaryWp;
    if (parsedWorkplaces.isNotEmpty) {
      primaryWp = parsedWorkplaces.firstWhere((w) => w.preferred, orElse: () => parsedWorkplaces.first);
    }

    final rawReg = (json['region_name'] ?? json['region'] ?? primaryWp?.regionName ?? primaryWp?.regionTitle)?.toString();
    final rawProv = (json['province_name'] ?? json['province'] ?? primaryWp?.provinceName ?? primaryWp?.provinceTitle)?.toString();
    final rawCity = (json['city_municipality'] ?? json['city'] ?? primaryWp?.cityMunicipality ?? primaryWp?.cityTitle)?.toString();
    final rawInst = (json['institution'] ?? primaryWp?.hcpWorkplace ?? primaryWp?.workplaceName)?.toString();

    final resolvedLoc = LocationResolver.resolveCompleteWorkplaceLocation(
      institutionIdOrName: rawInst,
      institutionName: rawInst,
      cityIdOrName: rawCity,
      provinceIdOrName: rawProv,
      regionIdOrName: rawReg,
    );

    return HcpProfileSubmission(
      name: json['name'],
      hcpName: json['hcp_name'] ?? '',
      hcpFullName: resolvedFullName,
      firstName: json['first_name'],
      middleName: json['middle_name'],
      lastName: json['last_name'],
      birthDate: json['birth_date'],
      consentPrivacyUnderstood: json['consent_privacy_understood'] == 1 || json['consent_privacy_understood'] == true,
      consentSignature: json['consent_signature'],
      consentPhoto: json['consent_photo'],
      hcpPhoto: json['hcp_photo'],
      hcpType: json['hcp_type'],
      hcpPractice: json['hcp_practice'],
      specialties: (json['table_specialties'] as List? ?? json['specialties'] as List? ?? json['hcp_specialty'] as List?)
              ?.map((e) => SubmissionSpecialty.fromJson(e))
              .toList() ?? [],
      workplaces: parsedWorkplaces,
      contacts: (json['table_contact_info'] as List? ?? json['contacts'] as List? ?? json['hcp_contact_info'] as List?)
              ?.map((e) => SubmissionContact.fromJson(e))
              .toList() ?? [],
      regionName: resolvedLoc.regionName,
      provinceName: resolvedLoc.provinceName,
      cityMunicipality: resolvedLoc.cityName,
      barangayName: json['barangay_name'],
      institution: resolvedLoc.workplaceName,
      accountOrProgram: json['account_or_program'],
      territory: json['territory'],
      salesPerson: json['sales_person'],
      userId: json['user_id'] ?? json['medrep_email'],
      surveyTemplate: json['survey_template'],
      surveyTemplateTitle: json['survey_template_title'],
      medrepEmail: json['medrep_email'] ?? json['user_id'],
      owner: json['owner'] ?? json['user_id'] ?? json['medrep_email'],
      submissionDate: json['submission_date'],
      surveyResponse: json['survey_response'],
      answers: (json['answers'] as List?)
              ?.map((e) => SubmissionAnswer.fromJson(e))
              .toList() ?? [],
      validFrom: json['valid_from'] ?? json['start_date'],
      validTo: json['valid_to'] ?? json['end_date'],
      validityPeriod: json['validity_period'] ?? json['month_period'],
      status: resolvedWorkflow,
      workflowState: resolvedWorkflow,
      applicationStatus: resolvedAppStatus,
      changeSummaryHtml: json['change_summary_html'],
      changesJson: json['changes_json'],
      docstatus: rawDocstatus,
      profileAction: resolvedAction,
      rejectionRemarks: isActuallyRejected ? (json['rejection_reason'] ?? json['rejection_remarks'] ?? json['remarks']) : null,
      rejectedBy: isActuallyRejected ? (json['rejected_by'] ?? json['comment_by'] ?? json['owner']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final fn = firstName?.trim() ?? '';
    final mn = (middleName != null && middleName!.trim().isNotEmpty) ? middleName!.trim() : '-';
    final ln = lastName?.trim() ?? '';
    final computedFullName = (hcpFullName != null && hcpFullName!.trim().isNotEmpty)
        ? hcpFullName!.trim()
        : [fn, mn != '-' ? mn : null, ln].where((p) => p != null && p.isNotEmpty).join(' ');

    final resolvedAction = (profileAction != null && profileAction!.trim().isNotEmpty)
        ? profileAction!.trim()
        : (hcpName.isNotEmpty ? 'Existing HCP' : 'New HCP');

      SubmissionWorkplace? primaryWp;
      if (workplaces.isNotEmpty) {
        primaryWp = workplaces.firstWhere((w) => w.preferred, orElse: () => workplaces.first);
      }
      final resolvedPrimary = LocationResolver.resolveCompleteWorkplaceLocation(
        institutionIdOrName: primaryWp?.hcpWorkplace ?? primaryWp?.workplaceName ?? institution,
        institutionName: primaryWp?.workplaceName ?? primaryWp?.hcpWorkplace ?? institution,
        cityIdOrName: primaryWp?.cityMunicipality ?? primaryWp?.cityTitle ?? cityMunicipality,
        provinceIdOrName: primaryWp?.provinceName ?? primaryWp?.provinceTitle ?? provinceName,
        regionIdOrName: primaryWp?.regionName ?? primaryWp?.regionTitle ?? regionName,
      );

      final finalRegId = (regionName != null && regionName!.trim().isNotEmpty && regionName != '-')
          ? LocationResolver.resolveRegionId(regionName)
          : resolvedPrimary.regionId;
      final finalProvId = (provinceName != null && provinceName!.trim().isNotEmpty && provinceName != '-')
          ? LocationResolver.resolveProvinceId(provinceName)
          : resolvedPrimary.provinceId;
      final finalCityId = (cityMunicipality != null && cityMunicipality!.trim().isNotEmpty && cityMunicipality != '-')
          ? LocationResolver.resolveCityId(cityMunicipality)
          : resolvedPrimary.cityId;
      final finalInstId = (institution != null && institution!.trim().isNotEmpty)
          ? LocationResolver.resolveInstitutionId(institution)
          : resolvedPrimary.workplaceId;

      return DataSanitizer.sanitizePayload({
        if (name != null) 'name': name,
        'hcp_name': hcpName,
        'hcp_full_name': computedFullName.isNotEmpty ? computedFullName : null,
        'first_name': fn,
        'middle_name': mn,
        'last_name': ln,
        if (birthDate != null && birthDate!.isNotEmpty) 'birth_date': birthDate,
        'consent_privacy_understood': consentPrivacyUnderstood ? 1 : 0,
        if (consentSignature != null) 'consent_signature': consentSignature,
        if (consentPhoto != null) 'consent_photo': consentPhoto,
        if (hcpPhoto != null) 'hcp_photo': hcpPhoto,
        if (hcpType != null) 'hcp_type': hcpType,
        if (hcpPractice != null) 'hcp_practice': hcpPractice,
        'table_specialties': specialties.map((e) => e.toJson()).toList(),
        'table_workplaces': workplaces.map((e) => e.toJson()).toList(),
        'table_contact_info': contacts.map((e) => e.toJson()).toList(),
        'region_name': finalRegId.isNotEmpty ? finalRegId : resolvedPrimary.regionId,
        'province_name': finalProvId.isNotEmpty ? finalProvId : resolvedPrimary.provinceId,
        'city_municipality': finalCityId.isNotEmpty ? finalCityId : resolvedPrimary.cityId,
        if (barangayName != null) 'barangay_name': barangayName,
        'institution': finalInstId.isNotEmpty ? finalInstId : resolvedPrimary.workplaceId,
        'custom_workplace': {
          'institution_name': resolvedPrimary.workplaceName,
          'region_name': resolvedPrimary.regionName,
          'province_name': resolvedPrimary.provinceName,
          'city_municipality': resolvedPrimary.cityName,
        },
      if (accountOrProgram != null) 'account_or_program': accountOrProgram,
      if (territory != null) 'territory': territory,
      if (salesPerson != null) 'sales_person': salesPerson,
      if (userId != null || medrepEmail != null) 'user_id': userId ?? medrepEmail,
      if (medrepEmail != null) 'medrep_email': medrepEmail,
      if (surveyTemplate != null) 'survey_template': surveyTemplate,
      if (surveyTemplateTitle != null) 'survey_template_title': surveyTemplateTitle,
      if (submissionDate != null) 'submission_date': submissionDate,
      if (surveyResponse != null) 'survey_response': surveyResponse,
      'answers': answers.map((e) => e.toJson()).toList(),
      if (validFrom != null) 'valid_from': validFrom,
      if (validTo != null) 'valid_to': validTo,
      if (validityPeriod != null) 'validity_period': validityPeriod,
      if (workflowState != null) 'workflow_state': workflowState,
      if (applicationStatus != null) 'application_status': applicationStatus,
      if (changeSummaryHtml != null) 'change_summary_html': changeSummaryHtml,
      if (changesJson != null) 'changes_json': changesJson,
      'docstatus': docstatus,
      'profile_action': resolvedAction,
      if (rejectionRemarks != null) ...{
        'rejection_reason': rejectionRemarks,
        'rejection_remarks': rejectionRemarks,
      },
      if (rejectedBy != null) 'rejected_by': rejectedBy,
    });
  }

  // Countermeasure 1: Semantic Locks (Application-level status properties)
  bool get isPendingApproval => workflowState == 'Pending Approval';
  bool get isApproved => workflowState == 'Approved' || docstatus == 1;
  bool get isProcessed => workflowState == 'Processed';
  bool get isRejected => workflowState == 'Rejected' || docstatus == 2;
  bool get isDraft => (workflowState == 'Draft' || workflowState == null) && docstatus == 0;
  bool get isSemanticallyLocked => isPendingApproval || isApproved;

  HcpProfileSubmission copyWith({
    String? name,
    String? hcpName,
    String? hcpFullName,
    String? firstName,
    String? middleName,
    String? lastName,
    String? birthDate,
    bool? consentPrivacyUnderstood,
    String? consentSignature,
    String? consentPhoto,
    String? hcpPhoto,
    String? hcpType,
    String? hcpPractice,
    List<SubmissionSpecialty>? specialties,
    List<SubmissionWorkplace>? workplaces,
    List<SubmissionContact>? contacts,
    String? regionName,
    String? provinceName,
    String? cityMunicipality,
    String? barangayName,
    String? institution,
    String? accountOrProgram,
    String? territory,
    String? salesPerson,
    String? userId,
    String? surveyTemplate,
    String? surveyTemplateTitle,
    String? medrepEmail,
    String? owner,
    String? submissionDate,
    String? surveyResponse,
    List<SubmissionAnswer>? answers,
    String? validFrom,
    String? validTo,
    String? validityPeriod,
    String? status,
    String? workflowState,
    String? applicationStatus,
    String? changeSummaryHtml,
    String? changesJson,
    int? docstatus,
    String? profileAction,
    String? rejectionRemarks,
    String? rejectedBy,
  }) {
    return HcpProfileSubmission(
      name: name ?? this.name,
      hcpName: hcpName ?? this.hcpName,
      hcpFullName: hcpFullName ?? this.hcpFullName,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      birthDate: birthDate ?? this.birthDate,
      consentPrivacyUnderstood: consentPrivacyUnderstood ?? this.consentPrivacyUnderstood,
      consentSignature: consentSignature ?? this.consentSignature,
      consentPhoto: consentPhoto ?? this.consentPhoto,
      hcpPhoto: hcpPhoto ?? this.hcpPhoto,
      hcpType: hcpType ?? this.hcpType,
      hcpPractice: hcpPractice ?? this.hcpPractice,
      specialties: specialties ?? this.specialties,
      workplaces: workplaces ?? this.workplaces,
      contacts: contacts ?? this.contacts,
      regionName: regionName ?? this.regionName,
      provinceName: provinceName ?? this.provinceName,
      cityMunicipality: cityMunicipality ?? this.cityMunicipality,
      barangayName: barangayName ?? this.barangayName,
      institution: institution ?? this.institution,
      accountOrProgram: accountOrProgram ?? this.accountOrProgram,
      territory: territory ?? this.territory,
      salesPerson: salesPerson ?? this.salesPerson,
      userId: userId ?? this.userId,
      surveyTemplate: surveyTemplate ?? this.surveyTemplate,
      surveyTemplateTitle: surveyTemplateTitle ?? this.surveyTemplateTitle,
      medrepEmail: medrepEmail ?? this.medrepEmail,
      owner: owner ?? this.owner,
      submissionDate: submissionDate ?? this.submissionDate,
      surveyResponse: surveyResponse ?? this.surveyResponse,
      answers: answers ?? this.answers,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      validityPeriod: validityPeriod ?? this.validityPeriod,
      status: status ?? this.status,
      workflowState: workflowState ?? this.workflowState,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      changeSummaryHtml: changeSummaryHtml ?? this.changeSummaryHtml,
      changesJson: changesJson ?? this.changesJson,
      docstatus: docstatus ?? this.docstatus,
      profileAction: profileAction ?? this.profileAction,
      rejectionRemarks: rejectionRemarks ?? this.rejectionRemarks,
      rejectedBy: rejectedBy ?? this.rejectedBy,
    );
  }
}

class SubmissionSpecialty {
  final bool preferred;
  final String? hcpSpecialty; // Link -> Specialization or title
  final String? specialtyName;
  final String? subSpecialty; // Link -> Specialization or title
  final String? subSpecialtyName;

  SubmissionSpecialty({
    this.preferred = false,
    this.hcpSpecialty,
    this.specialtyName,
    this.subSpecialty,
    this.subSpecialtyName,
  });

  factory SubmissionSpecialty.fromJson(Map<String, dynamic> json) {
    final rawSpec = (json['specialty_name'] ?? json['specialty'] ?? json['hcp_specialty'] ?? '').toString().trim();
    final rawSub = (json['sub_specialty_name'] ?? json['sub_specialty'] ?? '').toString().trim();
    final hcpSpec = (json['hcp_specialty'] ?? json['specialty'] ?? '').toString().trim();
    final subSpec = (json['sub_specialty'] ?? '').toString().trim();

    final resolvedSpecName = LocationResolver.resolveSpecialtyName(rawSpec.isNotEmpty ? rawSpec : hcpSpec);
    final resolvedSubName = (rawSub.isNotEmpty && rawSub != 'None' && rawSub != '-')
        ? LocationResolver.resolveSpecialtyName(rawSub)
        : ((subSpec.isNotEmpty && subSpec != 'None' && subSpec != '-') ? LocationResolver.resolveSpecialtyName(subSpec) : null);

    final finalSpec = resolvedSpecName.isNotEmpty ? resolvedSpecName : (rawSpec.isNotEmpty ? rawSpec : (hcpSpec.isNotEmpty ? hcpSpec : null));
    final finalSub = (resolvedSubName != null && resolvedSubName.isNotEmpty && resolvedSubName != '-')
        ? resolvedSubName
        : ((subSpec.isNotEmpty && subSpec != 'None' && subSpec != '-') ? LocationResolver.resolveSpecialtyName(subSpec) : null);

    return SubmissionSpecialty(
      preferred: json['preferred'] == 1 || json['preferred'] == true ||
          json['is_preferred'] == 1 || json['is_preferred'] == true ||
          json['is_primary'] == 1 || json['is_primary'] == true ||
          json['primary'] == 1 || json['primary'] == true,
      hcpSpecialty: finalSpec,
      specialtyName: finalSpec,
      subSpecialty: finalSub,
      subSpecialtyName: finalSub,
    );
  }

  Map<String, dynamic> toJson() {
    final specId = LocationResolver.resolveSpecialtyId(specialtyName ?? hcpSpecialty);
    final specName = LocationResolver.resolveSpecialtyName(specialtyName ?? hcpSpecialty);
    final subId = LocationResolver.resolveSpecialtyId(subSpecialtyName ?? subSpecialty);
    final subName = LocationResolver.resolveSpecialtyName(subSpecialtyName ?? subSpecialty);

    final finalSpecId = specId.isNotEmpty ? specId : (hcpSpecialty ?? '');
    final finalSpecName = specName.isNotEmpty ? specName : (specialtyName ?? finalSpecId);
    final finalSubId = (subId.isNotEmpty && subId != '-') ? subId : subSpecialty;
    final finalSubName = (subName.isNotEmpty && subName != '-') ? subName : (subSpecialtyName ?? finalSubId);

    return {
      'preferred': preferred ? 1 : 0,
      'is_preferred': preferred ? 1 : 0,
      'is_primary': preferred ? 1 : 0,
      'primary': preferred ? 1 : 0,
      if (finalSpecId.isNotEmpty) 'hcp_specialty': finalSpecId,
      if (finalSpecId.isNotEmpty) 'specialty': finalSpecId,
      if (finalSpecName.isNotEmpty) 'specialty_name': finalSpecName,
      if (finalSubId != null && finalSubId.isNotEmpty && finalSubId != '-') 'sub_specialty': finalSubId,
      if (finalSubName != null && finalSubName.isNotEmpty && finalSubName != '-') 'sub_specialty_name': finalSubName,
    };
  }
}

class SubmissionWorkplace {
  final bool preferred;
  final String? hcpWorkplace; // Link -> Institution or title
  final String? workplaceName;
  final String? cityMunicipality;
  final String? cityTitle;
  final String? provinceName;
  final String? provinceTitle;
  final String? regionName;
  final String? regionTitle;
  final String? workflowState;
  final String? rejectionReason;
  final bool isCustom;

  SubmissionWorkplace({
    this.preferred = false,
    this.hcpWorkplace,
    this.workplaceName,
    this.cityMunicipality,
    this.cityTitle,
    this.provinceName,
    this.provinceTitle,
    this.regionName,
    this.regionTitle,
    this.workflowState,
    this.rejectionReason,
    this.isCustom = false,
  });

  factory SubmissionWorkplace.fromJson(Map<String, dynamic> json) {
    final rawWp = (json['workplace_name'] ?? json['address'] ?? json['workplace'] ?? json['hcp_workplace'] ?? '').toString().trim();
    final rawCity = (json['city_municipality'] ?? json['city_title'] ?? json['city_name'] ?? json['city'] ?? '').toString().trim();
    final rawProv = (json['province_name'] ?? json['province_title'] ?? json['province'] ?? '').toString().trim();
    final rawReg = (json['region_name'] ?? json['region_title'] ?? json['region'] ?? '').toString().trim();
    final hcpWp = (json['hcp_workplace'] ?? json['workplace'] ?? '').toString().trim();

    final resolvedLoc = LocationResolver.resolveCompleteWorkplaceLocation(
      institutionIdOrName: hcpWp.isNotEmpty ? hcpWp : rawWp,
      institutionName: rawWp.isNotEmpty ? rawWp : hcpWp,
      cityIdOrName: rawCity,
      provinceIdOrName: rawProv,
      regionIdOrName: rawReg,
    );

    return SubmissionWorkplace(
      preferred: json['preferred'] == 1 || json['preferred'] == true ||
          json['is_preferred'] == 1 || json['is_preferred'] == true ||
          json['is_primary'] == 1 || json['is_primary'] == true ||
          json['primary'] == 1 || json['primary'] == true,
      hcpWorkplace: resolvedLoc.workplaceId,
      workplaceName: resolvedLoc.workplaceName,
      cityMunicipality: resolvedLoc.cityId,
      cityTitle: resolvedLoc.cityName,
      provinceName: resolvedLoc.provinceId,
      provinceTitle: resolvedLoc.provinceName,
      regionName: resolvedLoc.regionId,
      regionTitle: resolvedLoc.regionName,
      workflowState: json['workflow_state']?.toString(),
      rejectionReason: (json['rejection_reason'] ?? json['rejection_remarks'])?.toString(),
      isCustom: json['is_custom'] == true || json['is_custom'] == 1,
    );
  }

  bool get isRejected =>
      (workflowState ?? '').trim().toLowerCase() == 'rejected' ||
      (rejectionReason != null && rejectionReason!.trim().isNotEmpty && rejectionReason!.toUpperCase().contains('REJECTED'));

  SubmissionWorkplace copyWith({
    bool? preferred,
    String? hcpWorkplace,
    String? workplaceName,
    String? cityMunicipality,
    String? cityTitle,
    String? provinceName,
    String? provinceTitle,
    String? regionName,
    String? regionTitle,
    String? workflowState,
    String? rejectionReason,
    bool? isCustom,
  }) {
    return SubmissionWorkplace(
      preferred: preferred ?? this.preferred,
      hcpWorkplace: hcpWorkplace ?? this.hcpWorkplace,
      workplaceName: workplaceName ?? this.workplaceName,
      cityMunicipality: cityMunicipality ?? this.cityMunicipality,
      cityTitle: cityTitle ?? this.cityTitle,
      provinceName: provinceName ?? this.provinceName,
      provinceTitle: provinceTitle ?? this.provinceTitle,
      regionName: regionName ?? this.regionName,
      regionTitle: regionTitle ?? this.regionTitle,
      workflowState: workflowState ?? this.workflowState,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() {
    final resolvedLoc = LocationResolver.resolveCompleteWorkplaceLocation(
      institutionIdOrName: hcpWorkplace ?? workplaceName,
      institutionName: workplaceName ?? hcpWorkplace,
      cityIdOrName: cityMunicipality ?? cityTitle,
      provinceIdOrName: provinceName ?? provinceTitle,
      regionIdOrName: regionName ?? regionTitle,
    );

    return {
      'preferred': preferred ? 1 : 0,
      'is_preferred': preferred ? 1 : 0,
      'is_primary': preferred ? 1 : 0,
      'primary': preferred ? 1 : 0,
      'hcp_workplace': resolvedLoc.workplaceId,
      'workplace': resolvedLoc.workplaceId,
      'workplace_name': resolvedLoc.workplaceName,
      'address': resolvedLoc.workplaceName,
      'city_municipality': resolvedLoc.cityId,
      'city': resolvedLoc.cityId,
      'city_title': resolvedLoc.cityName,
      'city_name': resolvedLoc.cityName,
      'province_name': resolvedLoc.provinceId,
      'province': resolvedLoc.provinceId,
      'province_title': resolvedLoc.provinceName,
      'region_name': resolvedLoc.regionId,
      'region_title': resolvedLoc.regionName,
      if (workflowState != null) 'workflow_state': workflowState,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (isCustom) 'is_custom': 1,
    };
  }


}


class SubmissionContact {
  final bool preferred;
  final String? contactNumber;
  final String? emailAddress;

  SubmissionContact({
    this.preferred = false,
    this.contactNumber,
    this.emailAddress,
  });

  factory SubmissionContact.fromJson(Map<String, dynamic> json) {
    return SubmissionContact(
      preferred: json['preferred'] == 1 || json['preferred'] == true ||
          json['is_preferred'] == 1 || json['is_preferred'] == true ||
          json['is_primary'] == 1 || json['is_primary'] == true ||
          json['primary'] == 1 || json['primary'] == true,
      contactNumber: json['contact_number'] ?? json['contact_value'] ?? json['mobile_number'] ?? json['phone_number'],
      emailAddress: json['email_address'] ?? json['contact_type'] ?? json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferred': preferred ? 1 : 0,
      'is_preferred': preferred ? 1 : 0,
      'is_primary': preferred ? 1 : 0,
      'primary': preferred ? 1 : 0,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (emailAddress != null) 'email_address': emailAddress,
    };
  }
}

class SubmissionAnswer {
  final String surveyQuestion;
  final String questionText;
  final String answer;

  SubmissionAnswer({
    required this.surveyQuestion,
    required this.questionText,
    required this.answer,
  });

  factory SubmissionAnswer.fromJson(Map<String, dynamic> json) {
    return SubmissionAnswer(
      surveyQuestion: json['survey_question'] ?? json['question'] ?? '',
      questionText: json['question_text'] ?? json['question'] ?? '',
      answer: json['answer'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final validSq = surveyQuestion.trim().isNotEmpty ? surveyQuestion.trim() : 'SQ-00001';
    final validQt = questionText.trim().isNotEmpty ? questionText.trim() : 'General Question';
    final validAns = answer.trim().isNotEmpty ? answer.trim() : 'N/A';

    return {
      'survey_question': validSq,
      'question_text': validQt,
      'answer': validAns,
    };
  }
}
