import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/services.dart' show rootBundle;

class InstitutionClassification {
  static const List<String> ownershipOptions = ['Government', 'Private'];
  static const List<String> typeOptions = ['Hospital', 'Clinic'];
  static const List<String> institutionTypeOptions = typeOptions;

  static const List<String> hospitalCapabilities = [
    'Primary',
    'Secondary',
    'Tertiary',
  ];

  static const List<String> clinicCapabilities = [
    'Baranggay Health Center',
    'Municipal Health Center',
    'Lying-In Clinic',
    'Dental Clinic',
    'General Clinic',
  ];

  static List<String> getCapabilitiesForType(String? type) {
    if (type == null) return [];
    final lower = type.trim().toLowerCase();
    if (lower == 'hospital') {
      return hospitalCapabilities;
    } else if (lower == 'clinic') {
      return clinicCapabilities;
    }
    return [];
  }
}

class InstitutionAuditLogEntry {
  final DateTime timestamp;
  final String user;
  final String role;
  final String action;
  final String? details;
  final Map<String, dynamic>? snapshot;

  InstitutionAuditLogEntry({
    required this.timestamp,
    required this.user,
    required this.role,
    required this.action,
    this.details,
    this.snapshot,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'user': user,
    'role': role,
    'action': action,
    if (details != null) 'details': details,
    if (snapshot != null) 'snapshot': snapshot,
  };

  factory InstitutionAuditLogEntry.fromJson(Map<String, dynamic> json) {
    return InstitutionAuditLogEntry(
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      user: json['user']?.toString() ?? 'System',
      role: json['role']?.toString() ?? 'User',
      action: json['action']?.toString() ?? '',
      details: json['details']?.toString(),
      snapshot: json['snapshot'] != null ? Map<String, dynamic>.from(json['snapshot']) : null,
    );
  }
}

class Institution {
  final String name; // e.g. INST-00001
  final String institutionName;
  final String? regionName;
  final String? provinceName;
  final String? cityMunicipality;
  final String? barangayName;
  final String? streetAddress;
  final String? rawProvinceName;
  final String? rawCityMunicipality;
  final String? rawRegionName;
  final String? workflowState;
  final String? rejectionReason;
  final bool isCustom;
  final String? owner;
  final String? creation;
  final String? modified;
  final int? docstatus;
  final bool isResubmission;
  final String? ownership; // Government, Private
  final String? institutionType; // Hospital, Clinic
  final String? serviceCapability; // Primary, Secondary, Tertiary, Baranggay Health Center, etc.
  final int resubmissionCount; // Max 2 resubmissions allowed
  final DateTime? lastSubmittedAt; // Submission timestamp
  final DateTime? activeEditingLock; // Concurrency anti-collision active 60s edit lock
  final String? editingUser; // User currently editing the institution
  final bool requiresDsmApproval; // True if submitted along with a New HCP
  final String? linkedDoctorName; // Link to doctor if proposed during doctor profiling
  final List<InstitutionAuditLogEntry> auditTrail; // Read-only history of submissions & reviews

  Institution({
    required this.name,
    required this.institutionName,
    this.regionName,
    this.provinceName,
    this.cityMunicipality,
    this.barangayName,
    this.streetAddress,
    this.rawProvinceName,
    this.rawCityMunicipality,
    this.rawRegionName,
    this.workflowState,
    this.rejectionReason,
    this.isCustom = false,
    this.owner,
    this.creation,
    this.modified,
    this.docstatus,
    this.isResubmission = false,
    this.ownership,
    this.institutionType,
    this.serviceCapability,
    this.resubmissionCount = 0,
    this.lastSubmittedAt,
    this.activeEditingLock,
    this.editingUser,
    this.requiresDsmApproval = false,
    this.linkedDoctorName,
    this.auditTrail = const [],
  });

  String? get region => regionName;

  /// Exact status of the institution matching ERPNext Institution DocType workflow_state:
  /// - 'Approved' (Green)
  /// - 'Pending Approval' / 'For SFE Approval' (Amber/Orange)
  /// - 'Draft' (Red - matches ERPNext initial masterlist import / draft state)
  /// - 'Rejected' (Red)
  String get status {
    final state = (workflowState ?? '').trim();
    if (state.isNotEmpty) {
      final lower = state.toLowerCase();
      if (lower == 'approved') return 'Approved';
      if (lower == 'pending dsm approval') return 'Pending DSM Approval';
      if (lower == 'pending approval' || lower == 'pending sfe approval' || lower == 'for sfe approval') {
        return 'For SFE Approval';
      }
      if (lower == 'draft') return 'Draft';
      if (lower == 'rejected') return 'Rejected';
      return state;
    }
    if (docstatus == 1) return 'Approved';
    if (docstatus == 2) return 'Cancelled';
    return 'Draft';
  }

  bool get isDraft {
    final state = (workflowState ?? '').trim().toLowerCase();
    return state == 'draft' || (state.isEmpty && docstatus == 0);
  }

  bool get isRejected {
    final state = (workflowState ?? '').trim().toLowerCase();
    return state == 'rejected';
  }

  bool get isRemapped {
    final state = (workflowState ?? '').trim().toLowerCase();
    return state == 'remapped';
  }

  bool get isPendingApproval {
    if (isRejected) return false;
    final state = (workflowState ?? '').trim().toLowerCase();
    return state == 'pending approval' || state == 'pending sfe approval' || state == 'for sfe approval' || state == 'pending dsm approval';
  }

  bool get isApproved {
    final state = (workflowState ?? '').trim().toLowerCase();
    return state == 'approved' || docstatus == 1;
  }

  /// Whether this institution can be used by the MedRep for doctor profiling & coverage.
  /// Newly added institutions awaiting SFE approval (Pending Approval) and existing Draft masterlist facilities CAN be used.
  /// Only explicitly rejected facilities are prohibited until modified and resubmitted.
  bool get isApprovedForProfiling {
    if (isRejected) return false;
    return true;
  }

  /// Concurrency lock: True if submitted or actively being edited within the last 60 seconds
  bool get isCooldownActive {
    final lockTime = activeEditingLock ?? lastSubmittedAt;
    if (lockTime == null) return false;
    final diff = DateTime.now().difference(lockTime).inSeconds;
    return diff >= 0 && diff < 60;
  }

  /// Remaining seconds on the 1-minute concurrency lock
  int get cooldownRemainingSeconds {
    final lockTime = activeEditingLock ?? lastSubmittedAt;
    if (lockTime == null) return 0;
    final diff = DateTime.now().difference(lockTime).inSeconds;
    if (diff < 0) return 60;
    if (diff >= 60) return 0;
    return 60 - diff;
  }

  /// MedRep can only resubmit maximum 2 times after rejection
  bool get canResubmit => isRejected && resubmissionCount < 2;

  /// If rejected and resubmission hits 2, prompt to call SFE Specialist
  bool get requiresSfeSpecialistCall => isRejected && resubmissionCount >= 2;

  /// Prominent label for rejected institution across DocTypes
  String get rejectionDisplayLabel => (rejectionReason != null && rejectionReason!.trim().isNotEmpty)
      ? '[REJECTED INSTITUTION: ${rejectionReason!.trim()}]'
      : '[REJECTED INSTITUTION]';

  /// Dynamic note per ERPNext HCP Account standard:
  /// - Rejected: "[REJECTED INSTITUTION: <Reason>]" or "[REJECTED INSTITUTION]"
  /// - Pending / Unapproved: "this institution is not yet approved"
  /// - Approved: "this institution is now approved"
  String get approvalStatusNote {
    if (isRejected) return rejectionDisplayLabel;
    return isApproved
        ? 'this institution is now approved'
        : 'this institution is not yet approved';
  }

  Institution copyWith({
    String? name,
    String? institutionName,
    String? regionName,
    String? provinceName,
    String? cityMunicipality,
    String? barangayName,
    String? streetAddress,
    String? rawProvinceName,
    String? rawCityMunicipality,
    String? rawRegionName,
    String? workflowState,
    String? rejectionReason,
    bool? isCustom,
    String? owner,
    String? creation,
    String? modified,
    int? docstatus,
    bool? isResubmission,
    String? ownership,
    String? institutionType,
    String? serviceCapability,
    int? resubmissionCount,
    DateTime? lastSubmittedAt,
    DateTime? activeEditingLock,
    String? editingUser,
    bool? requiresDsmApproval,
    String? linkedDoctorName,
    List<InstitutionAuditLogEntry>? auditTrail,
  }) {
    return Institution(
      name: name ?? this.name,
      institutionName: institutionName ?? this.institutionName,
      regionName: regionName ?? this.regionName,
      provinceName: provinceName ?? this.provinceName,
      cityMunicipality: cityMunicipality ?? this.cityMunicipality,
      barangayName: barangayName ?? this.barangayName,
      streetAddress: streetAddress ?? this.streetAddress,
      rawProvinceName: rawProvinceName ?? this.rawProvinceName,
      rawCityMunicipality: rawCityMunicipality ?? this.rawCityMunicipality,
      rawRegionName: rawRegionName ?? this.rawRegionName,
      workflowState: workflowState ?? this.workflowState,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      isCustom: isCustom ?? this.isCustom,
      owner: owner ?? this.owner,
      creation: creation ?? this.creation,
      modified: modified ?? this.modified,
      docstatus: docstatus ?? this.docstatus,
      isResubmission: isResubmission ?? this.isResubmission,
      ownership: ownership ?? this.ownership,
      institutionType: institutionType ?? this.institutionType,
      serviceCapability: serviceCapability ?? this.serviceCapability,
      resubmissionCount: resubmissionCount ?? this.resubmissionCount,
      lastSubmittedAt: lastSubmittedAt ?? this.lastSubmittedAt,
      activeEditingLock: activeEditingLock ?? this.activeEditingLock,
      editingUser: editingUser ?? this.editingUser,
      requiresDsmApproval: requiresDsmApproval ?? this.requiresDsmApproval,
      linkedDoctorName: linkedDoctorName ?? this.linkedDoctorName,
      auditTrail: auditTrail ?? this.auditTrail,
    );
  }

  factory Institution.fromJson(Map<String, dynamic> json) {
    final rawCity = (json['city_municipality'] ?? json['city'] ?? json['city_title'])?.toString();
    final rawProv = (json['province_name'] ?? json['province'] ?? json['province_title'])?.toString();
    final rawReg = (json['region_name'] ?? json['region'] ?? json['region_title'])?.toString();
    final rawInstName = json['institution_name'] ?? json['institution'] ?? json['name'] ?? '';
    
    DateTime? parsedLastSubmitted;
    if (json['last_submitted_at'] != null) {
      parsedLastSubmitted = DateTime.tryParse(json['last_submitted_at'].toString());
    } else if (json['modified'] != null) {
      parsedLastSubmitted = DateTime.tryParse(json['modified'].toString());
    }

    DateTime? parsedEditingLock;
    if (json['active_editing_lock'] != null) {
      parsedEditingLock = DateTime.tryParse(json['active_editing_lock'].toString());
    }

    List<InstitutionAuditLogEntry> parsedAuditTrail = [];
    if (json['audit_trail'] is List) {
      parsedAuditTrail = (json['audit_trail'] as List)
          .map((e) => InstitutionAuditLogEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return Institution(
      name: json['name'] ?? '',
      institutionName: LocationResolver.resolveInstitutionName(rawInstName.toString()),
      regionName: rawReg != null ? LocationResolver.resolveRegionName(rawReg) : null,
      provinceName: rawProv != null ? LocationResolver.resolveProvinceName(rawProv) : null,
      cityMunicipality: rawCity != null ? LocationResolver.resolveCityName(rawCity) : null,
      barangayName: json['barangay_name'],
      streetAddress: json['street_address'],
      rawProvinceName: rawProv,
      rawCityMunicipality: rawCity,
      rawRegionName: rawReg,
      workflowState: json['workflow_state']?.toString(),
      rejectionReason: (json['rejection_reason'] ?? json['rejection_remarks'])?.toString(),
      isCustom: json['is_custom'] == true || json['is_custom'] == 1,
      owner: json['owner']?.toString(),
      creation: json['creation']?.toString(),
      modified: json['modified']?.toString(),
      docstatus: json['docstatus'] is int ? json['docstatus'] : int.tryParse(json['docstatus']?.toString() ?? ''),
      isResubmission: json['is_resubmission'] == 1 || json['is_resubmission'] == true || json['is_resubmission'] == '1',
      ownership: (json['ownership'] ?? json['custom_ownership'])?.toString(),
      institutionType: (json['institution_type'] ?? json['custom_institution_type'])?.toString(),
      serviceCapability: (json['service_capability'] ?? json['custom_service_capability'])?.toString(),
      resubmissionCount: json['resubmission_count'] is int ? json['resubmission_count'] : int.tryParse(json['resubmission_count']?.toString() ?? '') ?? 0,
      lastSubmittedAt: parsedLastSubmitted,
      activeEditingLock: parsedEditingLock,
      editingUser: json['editing_user']?.toString(),
      requiresDsmApproval: json['requires_dsm_approval'] == 1 || json['requires_dsm_approval'] == true || json['requires_dsm_approval'] == '1',
      linkedDoctorName: json['linked_doctor_name']?.toString(),
      auditTrail: parsedAuditTrail,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'institution_name': institutionName,
      if (rawRegionName != null || regionName != null) 'region_name': rawRegionName ?? regionName,
      if (rawProvinceName != null || provinceName != null) 'province_name': rawProvinceName ?? provinceName,
      if (rawCityMunicipality != null || cityMunicipality != null) 'city_municipality': rawCityMunicipality ?? cityMunicipality,
      if (barangayName != null) 'barangay_name': barangayName,
      if (streetAddress != null) 'street_address': streetAddress,
      if (workflowState != null) 'workflow_state': workflowState,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (isCustom) 'is_custom': 1,
      if (owner != null) 'owner': owner,
      if (creation != null) 'creation': creation,
      if (modified != null) 'modified': modified,
      if (docstatus != null) 'docstatus': docstatus,
      if (isResubmission) 'is_resubmission': 1,
      if (ownership != null) 'ownership': ownership,
      if (institutionType != null) 'institution_type': institutionType,
      if (serviceCapability != null) 'service_capability': serviceCapability,
      'resubmission_count': resubmissionCount,
      if (lastSubmittedAt != null) 'last_submitted_at': lastSubmittedAt!.toIso8601String(),
      if (activeEditingLock != null) 'active_editing_lock': activeEditingLock!.toIso8601String(),
      if (editingUser != null) 'editing_user': editingUser,
      'requires_dsm_approval': requiresDsmApproval ? 1 : 0,
      if (linkedDoctorName != null) 'linked_doctor_name': linkedDoctorName,
      if (auditTrail.isNotEmpty) 'audit_trail': auditTrail.map((e) => e.toJson()).toList(),
    };
  }
}

class Specialization {
  final String name; // e.g. SPEC-00001
  final String specialty;
  final String specialtyGroup;
  final String? parentSpecialization;
  final bool isGroup;

  Specialization({
    required this.name,
    required this.specialty,
    required this.specialtyGroup,
    this.parentSpecialization,
    this.isGroup = false,
  });

  factory Specialization.fromJson(Map<String, dynamic> json) {
    return Specialization(
      name: json['name'] ?? '',
      specialty: json['specialty'] ?? '',
      specialtyGroup: json['specialty_group'] ?? '',
      parentSpecialization: json['parent_specialization'],
      isGroup: json['is_group'] == 1 || json['is_group'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'specialty': specialty,
      'specialty_group': specialtyGroup,
      if (parentSpecialization != null) 'parent_specialization': parentSpecialization,
      'is_group': isGroup ? 1 : 0,
    };
  }
}

class InstitutionSearchResult {
  final Institution institution;
  final bool isExactOrHighConfidenceDuplicate;
  final double matchScore;
  final String formattedLocation;

  InstitutionSearchResult({
    required this.institution,
    required this.isExactOrHighConfidenceDuplicate,
    required this.matchScore,
    required this.formattedLocation,
  });
}

class _ScoredInstitutionItem {
  final Institution institution;
  final double score;
  const _ScoredInstitutionItem(this.institution, this.score);
}

class PsgcLocation {
  final String name; // ID
  final String locationLabel;
  final String locationType; // Region, Province, City, Barangay
  final String? parentPsgcLocation;
  final String? psgcCode;
  final bool isGroup;

  PsgcLocation({
    required this.name,
    required this.locationLabel,
    required this.locationType,
    this.parentPsgcLocation,
    this.psgcCode,
    this.isGroup = false,
  });

  factory PsgcLocation.fromJson(Map<String, dynamic> json) {
    return PsgcLocation(
      name: json['name'] ?? '',
      locationLabel: json['location_label'] ?? '',
      locationType: json['location_type'] ?? '',
      parentPsgcLocation: json['parent_psgc_location'],
      psgcCode: json['psgc_code'],
      isGroup: json['is_group'] == 1 || json['is_group'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'location_label': locationLabel,
      'location_type': locationType,
      if (parentPsgcLocation != null) 'parent_psgc_location': parentPsgcLocation,
      if (psgcCode != null) 'psgc_code': psgcCode,
      'is_group': isGroup ? 1 : 0,
    };
  }
}

class HcpSurveyTemplate {
  final String name; // ID
  final String templateName;
  final bool isActive;
  final String? accountOrProgram;
  final String? description;
  final List<HcpSurveyQuestion> questions;

  HcpSurveyTemplate({
    required this.name,
    required this.templateName,
    this.isActive = true,
    this.accountOrProgram,
    this.description,
    this.questions = const [],
  });

  factory HcpSurveyTemplate.fromJson(Map<String, dynamic> json) {
    return HcpSurveyTemplate(
      name: json['name'] ?? '',
      templateName: json['template_name'] ?? '',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      accountOrProgram: json['account_or_program'],
      description: json['description'],
      questions: (json['questions'] as List?)
              ?.map((e) => HcpSurveyQuestion.fromJson(e))
              .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'template_name': templateName,
      'is_active': isActive ? 1 : 0,
      if (accountOrProgram != null) 'account_or_program': accountOrProgram,
      if (description != null) 'description': description,
      'questions': questions.map((e) => e.toJson()).toList(),
    };
  }
}

class HcpSurveyQuestion {
  final String question; // e.g., "What products do you prescribe?"
  final String questionType; // Select, Multi-select, Data, etc.
  final String? options; // newline-separated choices

  HcpSurveyQuestion({
    required this.question,
    required this.questionType,
    this.options,
  });

  factory HcpSurveyQuestion.fromJson(Map<String, dynamic> json) {
    return HcpSurveyQuestion(
      question: json['question'] ?? '',
      questionType: json['question_type'] ?? 'Data',
      options: json['options'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'question_type': questionType,
      if (options != null) 'options': options,
    };
  }
}

class HcpType {
  final String name; // e.g. HCP-TYPE-01 — this is the Link value ERPNext validates
  final String typeName; // e.g. "Physician" — human-readable display label
  final String? description;

  HcpType({
    required this.name,
    required this.typeName,
    this.description,
  });

  factory HcpType.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] ?? '').toString();
    final rawType = (json['hcp_type'] ?? json['type_name'] ?? json['hcp_type_name'] ?? json['title'])?.toString();
    String resolvedTypeName = rawType ?? '';
    if (resolvedTypeName.isEmpty || resolvedTypeName == rawName) {
      if (rawName == 'HCP-TYPE-01') {
        resolvedTypeName = 'Consultant';
      } else if (rawName == 'HCP-TYPE-02') {
        resolvedTypeName = 'Resident';
      } else if (rawName == 'HCP-TYPE-03') {
        resolvedTypeName = 'Fellow';
      } else {
        resolvedTypeName = rawName;
      }
    }
    return HcpType(
      name: rawName,
      typeName: resolvedTypeName,
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type_name': typeName,
      if (description != null) 'description': description,
    };
  }
}

class HcpSurveyResponse {
  final String? name;
  final String surveyTemplate; // Link -> HCP Survey Template
  final String hcp; // Link -> HCP
  final String? surveyDate;
  final String? respondent; // Medrep email or username
  final List<HcpSurveyAnswer> answers;

  HcpSurveyResponse({
    this.name,
    required this.surveyTemplate,
    required this.hcp,
    this.surveyDate,
    this.respondent,
    this.answers = const [],
  });

  factory HcpSurveyResponse.fromJson(Map<String, dynamic> json) {
    return HcpSurveyResponse(
      name: json['name'],
      surveyTemplate: json['survey_template'] ?? '',
      hcp: json['hcp'] ?? '',
      surveyDate: json['survey_date'],
      respondent: json['respondent'],
      answers: (json['answers'] as List?)
              ?.map((e) => HcpSurveyAnswer.fromJson(e))
              .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'survey_template': surveyTemplate,
      'hcp': hcp,
      if (surveyDate != null) 'survey_date': surveyDate,
      if (respondent != null) 'respondent': respondent,
      'answers': answers.map((e) => e.toJson()).toList(),
    };
  }
}

class HcpSurveyAnswer {
  final String question; // Link -> HCP Survey Question or question text
  final String answer; // Answer selection / input text

  HcpSurveyAnswer({
    required this.question,
    required this.answer,
  });

  factory HcpSurveyAnswer.fromJson(Map<String, dynamic> json) {
    return HcpSurveyAnswer(
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'answer': answer,
    };
  }
}

class TerritoryInfo {
  final String name; // e.g. "BA2-05", "AD0110"
  final String territoryName; // e.g. "BA2-05", "AD0110 - Manila North"
  final String territoryManager; // e.g. "Ivy Marie Mateo (BA2-05)"
  final String? parentTerritory;
  final bool isGroup;
  final String? program;
  final String? customUserId;
  final String? customAccountOrProgram;

  TerritoryInfo({
    required this.name,
    required this.territoryName,
    required this.territoryManager,
    this.parentTerritory,
    this.isGroup = false,
    this.program,
    this.customUserId,
    this.customAccountOrProgram,
  });

  factory TerritoryInfo.fromJson(Map<String, dynamic> json) {
    final tName = (json['territory_name'] ?? json['name'] ?? '').toString().trim();
    final manager = (json['territory_manager'] ?? json['sales_person'] ?? json['manager'] ?? json['custom_territory_manager'] ?? '').toString().trim();
    final isGrp = json['is_group'] == 1 || json['is_group'] == true || json['is_group'] == '1';
    final uid = json['custom_user_id']?.toString().trim();
    final prog = (json['custom_account_or_program'] ?? json['program'] ?? json['account_or_program'])?.toString().trim();
    return TerritoryInfo(
      name: json['name'] ?? '',
      territoryName: tName.isNotEmpty ? tName : (json['name'] ?? ''),
      territoryManager: manager,
      parentTerritory: json['parent_territory']?.toString(),
      isGroup: isGrp,
      program: prog,
      customUserId: (uid != null && uid.isNotEmpty) ? uid : null,
      customAccountOrProgram: (prog != null && prog.isNotEmpty) ? prog : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'territory_name': territoryName,
      'territory_manager': territoryManager,
      if (parentTerritory != null) 'parent_territory': parentTerritory,
      'is_group': isGroup ? 1 : 0,
      if (program != null) 'program': program,
      if (customUserId != null) 'custom_user_id': customUserId,
      if (customAccountOrProgram != null) 'custom_account_or_program': customAccountOrProgram,
    };
  }
}

class ResolvedTerritory {
  final String territoryCode;
  final String territoryName;
  final String territoryManager;

  const ResolvedTerritory({
    required this.territoryCode,
    required this.territoryName,
    required this.territoryManager,
  });

  @override
  String toString() => '$territoryCode ($territoryManager)';
}


class GeographicUnit {
  final String name;
  final String code;

  const GeographicUnit(this.name, this.code);
}

/// Fully-resolved workplace location containing guaranteed non-empty fields
/// for Workplace, Region, Province, and City.
class ResolvedWorkplaceLocation {
  final String regionId;
  final String regionName;
  final String provinceId;
  final String provinceName;
  final String cityId;
  final String cityName;
  final String workplaceId;
  final String workplaceName;

  const ResolvedWorkplaceLocation({
    required this.regionId,
    required this.regionName,
    required this.provinceId,
    required this.provinceName,
    required this.cityId,
    required this.cityName,
    required this.workplaceId,
    required this.workplaceName,
  });

  @override
  String toString() => '$workplaceName ($cityName, $provinceName, $regionName)';
}

/// Centralized resolver that translates ERPNext IDs (SPEC-XXXX, INST-XXXX) and
/// PSGC numeric location codes (e.g. 0301400000 -> Bulacan) to human-readable names.
class LocationResolver {
  // In-memory dynamic registries populated from API fetches
  static final Map<String, String> _dynamicSpecialties = {};
  static final Map<String, String> _dynamicInstitutions = {};
  static final Map<String, String> _dynamicPsgcLocations = {};
  static final Map<String, String> _dynamicHcpTypes = {};

  // Structured PSGC Collections and Parent-Child Mappings (1,772 official Philippine locations)
  static final List<PsgcLocation> _psgcLocations = [];
  static final Map<String, PsgcLocation> _psgcById = {};
  static final Map<String, PsgcLocation> _psgcByLabelLower = {};
  static final List<PsgcLocation> _psgcRegions = [];
  static final List<PsgcLocation> _psgcProvinces = [];
  static final List<PsgcLocation> _psgcCities = [];
  static final Map<String, List<PsgcLocation>> _psgcProvincesByRegion = {};
  static final Map<String, List<PsgcLocation>> _psgcCitiesByProvince = {};
  static final Map<String, PsgcLocation> _provinceToRegionMap = {};
  static final Map<String, PsgcLocation> _cityToProvinceMap = {};
  static bool _isPsgcInitialized = false;

  static const Map<String, String> _staticHcpTypes = {
    'HCP-TYPE-01': 'Consultant',
    'HCP-TYPE-02': 'Resident',
    'HCP-TYPE-03': 'Fellow',
  };

  // Standard Specializations Fallback Map (complete from assets/specializations.json)
  static const Map<String, String> _staticSpecialties = {
    'SPEC-00001': 'Pathology',
    'SPEC-00002': 'Palliative Medicine',
    'SPEC-00003': 'Family Medicine',
    'SPEC-00004': 'Internal Medicine',
    'SPEC-00005': 'Anesthesiology',
    'SPEC-00006': 'Radiology',
    'SPEC-00007': 'Dermatology',
    'SPEC-00008': 'Rehabilitation Medicine',
    'SPEC-00009': 'Obstetrics and Gynecology',
    'SPEC-00010': 'Ophthalmology',
    'SPEC-00011': 'Preventive Medicine',
    'SPEC-00012': 'General Surgery',
    'SPEC-00013': 'Pediatrics',
    'SPEC-00014': 'Otolaryngology ENT',
    'SPEC-00015': 'Neurology',
    'SPEC-00016': 'Psychiatry',
    'SPEC-00017': 'Medical Genetics',
    'SPEC-00018': 'Urology',
    'SPEC-00019': 'Emergency Medicine',
    'SPEC-00020': 'Physical Medicine and Rehabilitation',
    'SPEC-00021': 'Nuclear Medicine',
    'SPEC-00022': 'Cardiology',
    'SPEC-00023': 'Plastic Surgery',
    'SPEC-00024': 'Endocrinology',
    'SPEC-00025': 'Infectious Disease',
    'SPEC-00026': 'Pulmonology',
    'SPEC-00027': 'Gastroenterology',
    'SPEC-00028': 'Nephrology',
    'SPEC-00029': 'Rheumatology',
    'SPEC-00030': 'Hematology',
    'SPEC-00031': 'Medical Oncology',
    'SPEC-00032': 'Critical Care Medicine',
    'SPEC-00033': 'Allergy and Immunology',
    'SPEC-00034': 'Geriatrics',
    'SPEC-00035': 'Pediatric Cardiology',
    'SPEC-00036': 'Pediatric Endocrinology',
    'SPEC-00037': 'Pediatric Pulmonology',
    'SPEC-00038': 'Pediatric Infectious Disease',
    'SPEC-00039': 'Pediatric Nephrology',
    'SPEC-00040': 'Pediatric Gastroenterology',
    'SPEC-00041': 'Neonatology',
    'SPEC-00042': 'Developmental Pediatrics',
    'SPEC-00043': 'Pediatric Hematology-Oncology',
    'SPEC-00045': 'Maternal-Fetal Medicine',
    'SPEC-00046': 'Gynecologic Oncology',
    'SPEC-00047': 'Reproductive Endocrinology and Infertility',
    'SPEC-00048': 'Female Pelvic Medicine and Reconstructive Surgery',
    'SPEC-00049': 'Cardiothoracic Surgery',
    'SPEC-00050': 'Neurosurgery',
    'SPEC-00051': 'Orthopedic Surgery',
    'SPEC-00052': 'Plastic and Reconstructive Surgery',
    'SPEC-00053': 'Vascular Surgery',
    'SPEC-00054': 'Pediatric Surgery',
    'SPEC-00055': 'Colorectal Surgery',
    'SPEC-00056': 'Surgical Oncology',
    'SPEC-00057': 'Trauma and Critical Care Surgery',
    'SPEC-00058': 'Sports Medicine',
    'SPEC-00059': 'Lifestyle Medicine',
    'SPEC-00060': 'Geriatric Medicine',
    'SPEC-00061': 'Critical Care',
    'SPEC-00062': 'Toxicology',
    'SPEC-00063': 'Emergency Ultrasound',
    'SPEC-00064': 'Pain Medicine',
    'SPEC-00065': 'Critical Care Medicine',
    'SPEC-00066': 'Pediatric Anesthesiology',
    'SPEC-00067': 'Dermatopathology',
    'SPEC-00068': 'Cosmetic Dermatology',
    'SPEC-00069': 'Stroke Medicine',
    'SPEC-00070': 'Epilepsy',
    'SPEC-00071': 'Movement Disorders',
    'SPEC-00072': 'Neurocritical Care',
    'SPEC-00073': 'Child and Adolescent Psychiatry',
    'SPEC-00074': 'Addiction Psychiatry',
    'SPEC-00075': 'Geriatric Psychiatry',
    'SPEC-00076': 'Interventional Radiology',
    'SPEC-00077': 'Neuroradiology',
    'SPEC-00078': 'Hematopathology',
    'SPEC-00079': 'Forensic Pathology',
    'SPEC-00080': 'Retina',
    'SPEC-00081': 'Cornea',
    'SPEC-00082': 'Pediatric Ophthalmology',
    'SPEC-00083': 'Head and Neck Surgery',
    'SPEC-00084': 'Rhinology',
    'SPEC-00085': 'Otology',
    'SPEC-00086': 'Pain Rehabilitation',
    'SPEC-00087': 'Stroke Rehabilitation',
    'SPEC-00088': 'Occupational Medicine',
    'SPEC-00089': 'Public Health',
    'SPEC-00090': 'Clinical Genetics',
    'SPEC-00091': 'Hospice Care',
    'SPEC-00092': 'PET Imaging',
    'SPEC-00093': 'Theranostics',
    'SPEC-00094': 'Sports Rehabilitation',
    'SPEC-00095': 'Pain Management',
    'SPEC-00096': 'Pediatric Urology',
    'SPEC-00097': 'Urologic Oncology',
    'SPEC-00098': 'Cosmetic Surgery',
    'SPEC-00099': 'Hand Surgery',
    'SPEC-00100': 'Burn Surgery',
    'SPEC-00101': 'General Practice',
  };

  // Standard Institutions Fallback Map (complete from assets/institutions.json)
  static const Map<String, String> _staticInstitutions = {
    'INST-00001': 'Manila Doctors Hospital',
    'INST-00002': 'Chinese General Hospital & Medical Center',
    'INST-00003': 'Medical Center Manila',
    'INST-00004': 'Our Lady of Lourdes Hospital',
    'INST-00005': 'University of Santo Tomas Hospital',
    'INST-00006': 'UP-Philippine General Hospital',
    'INST-00007': 'Metropolitan Medical Center',
    'INST-00008': 'Zagu Foods Corporation',
    'INST-00009': 'test laguna',
    'INST-00010': 'test quezon',
    'INST-00011': 'test batangas',
    'INST-00012': '(A Rural Bank), Inc., Bank Of Makati',
    'INST-00013': '(Phil) Inc, Taihei Alltech Construction',
    'INST-00014': '578 Resources Inc.',
    'INST-00015': '88 Corporate Center Condo Corp',
    'INST-00016': '8990 Housing Development Corporation',
    'INST-00017': 'A C Enterprises Inc',
    'INST-00018': '& Marketing Cooperative, Cavite Farmer\'S Feedmilling',
    'INST-00019': '2L Batangas Corporation',
    'INST-00020': '678 First Cavite Molino Boulev',
    'INST-00021': '818 East Asia Group Corp',
    'INST-00022': '88 Spa & Resorts Inc.',
    'INST-00023': 'A To Z Packaging Solution Inc.',
    'INST-00024': 'A.M. Rieta Corporation',
    'INST-00025': 'Abagatan Hotels Inc.',
    'INST-00026': '(Las Pinas District Hospital2), Doh-Ncr',
    'INST-00027': '& Development, Inc., Sta. Lucia Realty',
    'INST-00028': '21St Drive Land Corporation',
    'INST-00029': '286 Edsa Corp',
    'INST-00030': '2Blue Realty Corp.',
    'INST-00031': '456 Realty Corporation',
    'INST-00032': 'A-Jaycee Chemicals Trading Corporation',
    'INST-00033': 'Abc Philippines',
    'INST-00034': '1 Cooperative Insurance System Of The Philippines Life And General Insurance',
    'INST-00035': '101 Xavierville Condominium Corp.',
    'INST-00036': '11 Ftc Enterprises, Inc.',
    'INST-00037': '21Century Corporation',
    'INST-00038': '861 Dragonfish Restaurant',
    'INST-00039': 'A Brown Chemical Corporation',
    'INST-00040': 'A.M. Gatbonton Ventures Corporation',
    'INST-00041': 'Abenson Ventures, Inc.,',
    'INST-00042': '168 Residences Condominium Corporation',
    'INST-00043': '4Th Watch Maranatha Christian',
    'INST-00044': '8 Adriatico Condominium Corporation',
    'INST-00045': '899 Leasing Management Inc.',
    'INST-00046': 'A-Flow Properties I Corp.,',
    'INST-00047': 'Aau Real Estate & Devt Corp',
    'INST-00048': '21 Dev. Corporation',
    'INST-00049': '2K3 Industries Incorporated',
    'INST-00050': 'Academy Of Saint John, Inc., General Trias Cavite-',
    'INST-00051': 'Accuplas Int\'L. Corp.',
    'INST-00052': 'Accutech Steel & Service Ctr',
    'INST-00053': 'Ace Ayala Yakal Development Corp.',
    'INST-00054': 'Ace Landstream Inc.',
    'INST-00055': 'Ace Medical Center Sariaya Inc.',
    'INST-00056': 'Ace-Med, Inc',
    'INST-00057': 'Aci Inc.',
    'INST-00058': 'Aci, Inc. -Ali Mall 24-F',
    'INST-00059': 'Acropolis Greens Homeowners Association, Inc.',
    'INST-00060': 'Acs Manufacturing Corporation',
    'INST-00061': 'Actimed, Inc.',
    'INST-00062': 'Active Food Innovators Corp.',
    'INST-00063': 'Acuatico Beach Resort',
    'INST-00064': 'Ad-Drugstel Pharmaceutical Lab',
    'INST-00065': 'Adampak & Print (Phils.) Inc.',
    'INST-00066': 'Adamson Ozanam Educational Institutions, Inc.',
    'INST-00067': 'Admiral Realty Company, Inc.',
    'INST-00068': 'Advanced Medical Systems Inc',
    'INST-00069': 'Advanced Molding Co Inc.',
    'INST-00070': 'Advantek, Llc',
    'INST-00071': 'Adventist Int\'L Inst Advnc St',
    'INST-00072': 'Afp Finance Center Multi-Purpose Cooperative',
    'INST-00073': 'Afp Savings & Loan Asso Inc',
    'INST-00074': 'Agc Bakeries Inc.',
    'INST-00075': 'Agoncillo - Ice Plant',
    'INST-00076': 'Agri Pacific Corporation',
    'INST-00077': 'Agri Specialist, Inc.',
    'INST-00078': 'Agro Azienda Inc.',
    'INST-00079': 'Ahnex Builders And Ready Mix Corporation',
    'INST-00080': 'Aic Center Inc',
    'INST-00081': 'Aic Realty Corporation',
    'INST-00082': 'Aim High Tolling Solutions Inc.,',
    'INST-00083': 'Air Link International Aviation College, Inc.',
    'INST-00084': 'Air Material Wing Sav & Loan',
    'INST-00085': 'Air Water Philippines, Inc.',
    'INST-00086': 'Airline Pilots Asso Of The Phi',
    'INST-00087': 'Airspeed International Corp.',
    'INST-00088': 'Ajax Trading Corp.',
    'INST-00089': 'Aji-No Chinmi-Co., Inc.',
    'INST-00090': 'Al Frontera De Taal, Lakestore Activity Pt., Inc.',
    'INST-00091': 'Alabang Commercial Corporation (Atc Corp Center)',
    'INST-00092': 'Alabang Golf And Country Club',
    'INST-00093': 'Alabang Medical Center, Inc.',
    'INST-00094': 'Alabenso Marketing Co.',
    'INST-00095': 'Alaska Land, Inc.',
    'INST-00096': 'Alc Realty Development Corp',
    'INST-00097': 'Alcos Global Corporation',
    'INST-00098': 'Ale Builders Construction And Development Corporation',
    'INST-00099': 'Alfamart Trading Phil. Inc.',
    'INST-00100': 'Alfredo C Ramos (Natl Bkstore)',
    'INST-00101': 'All Homes Corporation',
    'INST-00102': 'All Year Home Products, Inc.',
    'INST-00103': 'Allgemeine Bau Chemie Phil Inc',
    'INST-00104': 'Alliance Packaging Lti Corp.',
    'INST-00105': 'Allied Botanical Corp #2',
    'INST-00106': 'Allied Care Experts (Ace) Inc.',
    'INST-00107': 'Allied Pacific Packaging Solutions Corporation',
    'INST-00108': 'Allied Wires & Cables Corp',
    'INST-00109': 'Alltech Contractors Inc',
    'INST-00110': 'Allysum Realty Corp',
    'INST-00111': 'Almazora Motors Corp',
    'INST-00112': 'Alngoc Corp.',
  };

  // Standard Philippine Provinces Map
  static const List<GeographicUnit> standardProvinces = [
    GeographicUnit('Ilocos Norte', '0102800000'),
    GeographicUnit('Ilocos Sur', '0102900000'),
    GeographicUnit('La Union', '0103300000'),
    GeographicUnit('Pangasinan', '0105500000'),
    GeographicUnit('Batanes', '0200900000'),
    GeographicUnit('Cagayan', '0201500000'),
    GeographicUnit('Isabela', '0203100000'),
    GeographicUnit('Nueva Vizcaya', '0205000000'),
    GeographicUnit('Quirino', '0205700000'),
    GeographicUnit('Bataan', '0300800000'),
    GeographicUnit('Bulacan', '0301400000'),
    GeographicUnit('Nueva Ecija', '0304900000'),
    GeographicUnit('Pampanga', '0305400000'),
    GeographicUnit('Tarlac', '0306900000'),
    GeographicUnit('Zambales', '0307100000'),
    GeographicUnit('Aurora', '0307700000'),
    GeographicUnit('Batangas', '0401000000'),
    GeographicUnit('Cavite', '0402100000'),
    GeographicUnit('Laguna', '0403400000'),
    GeographicUnit('Quezon', '0405600000'),
    GeographicUnit('Rizal', '0405800000'),
    GeographicUnit('Marinduque', '1704000000'),
    GeographicUnit('Occidental Mindoro', '1705100000'),
    GeographicUnit('Oriental Mindoro', '1705200000'),
    GeographicUnit('Palawan', '1705300000'),
    GeographicUnit('Romblon', '1705900000'),
    GeographicUnit('Albay', '0500500000'),
    GeographicUnit('Camarines Norte', '0501600000'),
    GeographicUnit('Camarines Sur', '0501700000'),
    GeographicUnit('Catanduanes', '0502000000'),
    GeographicUnit('Masbate', '0504100000'),
    GeographicUnit('Sorsogon', '0506200000'),
    GeographicUnit('Aklan', '0600400000'),
    GeographicUnit('Antique', '0600600000'),
    GeographicUnit('Capiz', '0601900000'),
    GeographicUnit('Guimaras', '0607900000'),
    GeographicUnit('Iloilo', '0603000000'),
    GeographicUnit('Negros Occidental', '0604500000'),
    GeographicUnit('Bohol', '0701200000'),
    GeographicUnit('Cebu', '0702200000'),
    GeographicUnit('Negros Oriental', '0704600000'),
    GeographicUnit('Siquijor', '0706100000'),
    GeographicUnit('Eastern Samar', '0802600000'),
    GeographicUnit('Leyte', '0803700000'),
    GeographicUnit('Northern Samar', '0804800000'),
    GeographicUnit('Samar', '0806000000'),
    GeographicUnit('Southern Leyte', '0806400000'),
    GeographicUnit('Biliran', '0807800000'),
    GeographicUnit('Zamboanga del Norte', '0907200000'),
    GeographicUnit('Zamboanga del Sur', '0907300000'),
    GeographicUnit('Zamboanga Sibugay', '0908300000'),
    GeographicUnit('Bukidnon', '1001300000'),
    GeographicUnit('Camiguin', '1001800000'),
    GeographicUnit('Lanao del Norte', '1003500000'),
    GeographicUnit('Misamis Occidental', '1004200000'),
    GeographicUnit('Misamis Oriental', '1004300000'),
    GeographicUnit('Davao de Oro', '1108200000'),
    GeographicUnit('Davao del Norte', '1102300000'),
    GeographicUnit('Davao del Sur', '1102400000'),
    GeographicUnit('Davao Occidental', '1108600000'),
    GeographicUnit('Davao Oriental', '1102500000'),
    GeographicUnit('Cotabato', '1204700000'),
    GeographicUnit('South Cotabato', '1206300000'),
    GeographicUnit('Sultan Kudarat', '1206500000'),
    GeographicUnit('Sarangani', '1208000000'),
    GeographicUnit('Agusan del Norte', '1600200000'),
    GeographicUnit('Agusan del Sur', '1600300000'),
    GeographicUnit('Dinagat Islands', '1608500000'),
    GeographicUnit('Surigao del Norte', '1606700000'),
    GeographicUnit('Surigao del Sur', '1606800000'),
    GeographicUnit('Basilan', '1900700000'),
    GeographicUnit('Lanao del Sur', '1903600000'),
    GeographicUnit('Maguindanao', '1903800000'),
    GeographicUnit('Sulu', '1906600000'),
    GeographicUnit('Tawi-Tawi', '1907000000'),
    GeographicUnit('Abra', '1400100000'),
    GeographicUnit('Apayao', '1408100000'),
    GeographicUnit('Benguet', '1401100000'),
    GeographicUnit('Ifugao', '1402700000'),
    GeographicUnit('Kalinga', '1403200000'),
    GeographicUnit('Mountain Province', '1404400000'),
    GeographicUnit('Metro Manila-Caloocan', '1380100000'),
    GeographicUnit('Metro Manila-Las Piñas', '1380200000'),
    GeographicUnit('Metro Manila-Makati', '1380300000'),
    GeographicUnit('Metro Manila-Malabon', '1380400000'),
    GeographicUnit('Metro Manila-Mandaluyong', '1380500000'),
    GeographicUnit('Metro Manila-Manila', '1380600000'),
    GeographicUnit('Metro Manila-Marikina', '1380700000'),
    GeographicUnit('Metro Manila-Muntinlupa', '1380800000'),
    GeographicUnit('Metro Manila-Navotas', '1380900000'),
    GeographicUnit('Metro Manila-Parañaque', '1381000000'),
    GeographicUnit('Metro Manila-Pasay', '1381100000'),
    GeographicUnit('Metro Manila-Pasig', '1381200000'),
    GeographicUnit('Metro Manila-Quezon City', '1381300000'),
    GeographicUnit('Metro Manila-San Juan', '1381400000'),
    GeographicUnit('Metro Manila-Taguig', '1381500000'),
    GeographicUnit('Metro Manila-Valenzuela', '1381600000'),
    GeographicUnit('Metro Manila-Pateros', '1381701000'),
  ];

  static const List<GeographicUnit> standardRegions = [
    GeographicUnit('Region I (Ilocos Region)', '0100000000'),
    GeographicUnit('Region II (Cagayan Valley)', '0200000000'),
    GeographicUnit('Region III (Central Luzon)', '0300000000'),
    GeographicUnit('CALABARZON', '0400000000'),
    GeographicUnit('MIMAROPA Region', '1700000000'),
    GeographicUnit('Region V (Bicol Region)', '0500000000'),
    GeographicUnit('Region VI (Western Visayas)', '0600000000'),
    GeographicUnit('Region VII (Central Visayas)', '0700000000'),
    GeographicUnit('Region VIII (Eastern Visayas)', '0800000000'),
    GeographicUnit('Region IX (Zamboanga Peninsula)', '0900000000'),
    GeographicUnit('Region X (Northern Mindanao)', '1000000000'),
    GeographicUnit('Region XI (Davao Region)', '1100000000'),
    GeographicUnit('Region XII (SOCCSKSARGEN)', '1200000000'),
    GeographicUnit('Region XIII (Caraga)', '1600000000'),
    GeographicUnit('BARMM', '1900000000'),
    GeographicUnit('CAR', '1400000000'),
    GeographicUnit('NCR', '1300000000'),
  ];

  static const List<GeographicUnit> standardCities = [
    // NCR / Metro Manila
    GeographicUnit('City of Manila', '1380600000'),
    GeographicUnit('Ermita, Manila', '1380608000'),
    GeographicUnit('Binondo, Manila', '1380602000'),
    GeographicUnit('Quiapo, Manila', '1380603000'),
    GeographicUnit('San Nicolas, Manila', '1380604000'),
    GeographicUnit('Santa Cruz, Manila', '1380605000'),
    GeographicUnit('Sampaloc, Manila', '1380606000'),
    GeographicUnit('San Miguel, Manila', '1380607000'),
    GeographicUnit('Intramuros, Manila', '1380609000'),
    GeographicUnit('Malate, Manila', '1380610000'),
    GeographicUnit('Paco, Manila', '1380611000'),
    GeographicUnit('Pandacan, Manila', '1380612000'),
    GeographicUnit('Port Area, Manila', '1380613000'),
    GeographicUnit('Santa Ana, Manila', '1380614000'),
    GeographicUnit('Tondo, Manila', '1380601000'),
    GeographicUnit('Caloocan City', '1380100000'),
    GeographicUnit('Las Piñas City', '1380200000'),
    GeographicUnit('Makati City', '1380300000'),
    GeographicUnit('Malabon City', '1380400000'),
    GeographicUnit('Mandaluyong City', '1380500000'),
    GeographicUnit('Marikina City', '1380700000'),
    GeographicUnit('Muntinlupa City', '1380800000'),
    GeographicUnit('Navotas City', '1380900000'),
    GeographicUnit('Parañaque City', '1381000000'),
    GeographicUnit('Pasay City', '1381100000'),
    GeographicUnit('Pasig City', '1381200000'),
    GeographicUnit('Quezon City', '1381300000'),
    GeographicUnit('San Juan City', '1381400000'),
    GeographicUnit('Taguig City', '1381500000'),
    GeographicUnit('Valenzuela City', '1381600000'),
    GeographicUnit('Pateros', '1381701000'),
    // Cavite
    GeographicUnit('General Trias', '0402123000'),
    GeographicUnit('Bacoor', '0402102000'),
    GeographicUnit('Cavite City', '0402105000'),
    GeographicUnit('Dasmariñas', '0402106000'),
    GeographicUnit('Imus', '0402111000'),
    GeographicUnit('Tagaytay', '0402119000'),
    GeographicUnit('Tanza', '0402120000'),
    GeographicUnit('Kawit', '0402114000'),
    GeographicUnit('Silang', '0402118000'),
    GeographicUnit('Rosario', '0402117000'),
    GeographicUnit('Carmona', '0402113000'),
    GeographicUnit('Alfonso', '0402101000'),
    GeographicUnit('Amadeo', '0402103000'),
    GeographicUnit('General Emilio Aguinaldo', '0402107000'),
    GeographicUnit('General Mariano Alvarez', '0402108000'),
    GeographicUnit('Indang', '0402109000'),
    GeographicUnit('Magallanes', '0402112000'),
    GeographicUnit('Maragondon', '0402113000'),
    GeographicUnit('Mendez', '0402115000'),
    GeographicUnit('Naic', '0402116000'),
    GeographicUnit('Noveleta', '0402110000'),
    GeographicUnit('Ternate', '0402121000'),
    GeographicUnit('Trece Martires', '0402122000'),
    // Laguna
    GeographicUnit('Biñan', '0403403000'),
    GeographicUnit('Cabuyao', '0403404000'),
    GeographicUnit('Calamba', '0403405000'),
    GeographicUnit('San Pablo City', '0403424000'),
    GeographicUnit('San Pedro', '0403425000'),
    GeographicUnit('Santa Rosa', '0403427000'),
    GeographicUnit('Santa Cruz', '0403426000'),
    GeographicUnit('Los Baños', '0403418000'),
    GeographicUnit('Alaminos', '0403401000'),
    GeographicUnit('Bay', '0403402000'),
    GeographicUnit('Calauan', '0403406000'),
    GeographicUnit('Cavinti', '0403407000'),
    GeographicUnit('Famy', '0403408000'),
    GeographicUnit('Kalayaan', '0403409000'),
    GeographicUnit('Liliw', '0403410000'),
    GeographicUnit('Luisiana', '0403411000'),
    GeographicUnit('Lumban', '0403412000'),
    GeographicUnit('Mabitac', '0403413000'),
    GeographicUnit('Magdalena', '0403414000'),
    GeographicUnit('Majayjay', '0403415000'),
    GeographicUnit('Nagcarlan', '0403416000'),
    GeographicUnit('Paete', '0403417000'),
    GeographicUnit('Pagsanjan', '0403419000'),
    GeographicUnit('Pakil', '0403420000'),
    GeographicUnit('Pangil', '0403421000'),
    GeographicUnit('Pila', '0403422000'),
    GeographicUnit('Rizal', '0403423000'),
    GeographicUnit('Siniloan', '0403428000'),
    GeographicUnit('Victoria', '0403429000'),
    GeographicUnit('Santa Maria', '0403430000'),
    // Batangas
    GeographicUnit('Batangas City', '0401005000'),
    GeographicUnit('Lipa City', '0401019000'),
    GeographicUnit('Tanauan City', '0401030000'),
    GeographicUnit('Santo Tomas', '0401027000'),
    GeographicUnit('Agoncillo', '0401001000'),
    GeographicUnit('Alitagtag', '0401002000'),
    GeographicUnit('Balayan', '0401003000'),
    GeographicUnit('Balete', '0401004000'),
    GeographicUnit('Bauan', '0401006000'),
    GeographicUnit('Calaca', '0401007000'),
    GeographicUnit('Calatagan', '0401008000'),
    GeographicUnit('Cuenca', '0401009000'),
    GeographicUnit('Ibaan', '0401010000'),
    GeographicUnit('Laurel', '0401011000'),
    GeographicUnit('Lemery', '0401012000'),
    GeographicUnit('Lian', '0401013000'),
    GeographicUnit('Lobo', '0401014000'),
    GeographicUnit('Mabini', '0401015000'),
    GeographicUnit('Malvar', '0401016000'),
    GeographicUnit('Mataasnakahoy', '0401017000'),
    GeographicUnit('Nasugbu', '0401018000'),
    GeographicUnit('Padre Garcia', '0401020000'),
    GeographicUnit('Rosario', '0401021000'),
    GeographicUnit('San Jose', '0401022000'),
    GeographicUnit('San Juan', '0401023000'),
    GeographicUnit('San Luis', '0401024000'),
    GeographicUnit('San Nicolas', '0401025000'),
    GeographicUnit('San Pascual', '0401026000'),
    GeographicUnit('Santa Teresita', '0401028000'),
    GeographicUnit('Taal', '0401029000'),
    GeographicUnit('Taysan', '0401031000'),
    GeographicUnit('Tingloy', '0401032000'),
    GeographicUnit('Tuy', '0401033000'),
    // Quezon
    GeographicUnit('Lucena City', '0405624000'),
    GeographicUnit('Tayabas City', '0405641000'),
    GeographicUnit('Sariaya', '0405637000'),
    GeographicUnit('Candelaria', '0405611000'),
    GeographicUnit('Tiaong', '0405642000'),
    GeographicUnit('Pagbilao', '0405629000'),
    GeographicUnit('Lucban', '0405623000'),
    GeographicUnit('Mauban', '0405626000'),
    // Rizal
    GeographicUnit('Antipolo City', '0405802000'),
    GeographicUnit('Angono', '0405801000'),
    GeographicUnit('Baras', '0405803000'),
    GeographicUnit('Binangonan', '0405804000'),
    GeographicUnit('Cainta', '0405805000'),
    GeographicUnit('Cardona', '0405806000'),
    GeographicUnit('Jala-jala', '0405807000'),
    GeographicUnit('Rodriguez (Montalban)', '0405808000'),
    GeographicUnit('Morong', '0405809000'),
    GeographicUnit('Pililla', '0405810000'),
    GeographicUnit('San Mateo', '0405811000'),
    GeographicUnit('Tanay', '0405812000'),
    GeographicUnit('Taytay', '0405813000'),
    GeographicUnit('Teresa', '0405814000'),
    // Bulacan
    GeographicUnit('Malolos City', '0301401000'),
    GeographicUnit('Meycauayan City', '0301402000'),
    GeographicUnit('San Jose del Monte City', '0301403000'),
    GeographicUnit('Marilao', '0301404000'),
    GeographicUnit('Santa Maria', '0301405000'),
    GeographicUnit('Baliuag', '0301406000'),
    GeographicUnit('Bocaue', '0301407000'),
    GeographicUnit('Guiguinto', '0301408000'),
    GeographicUnit('Plaridel', '0301409000'),
    GeographicUnit('Balagtas', '0301410000'),
    GeographicUnit('Bulakan', '0301411000'),
    GeographicUnit('Bustos', '0301412000'),
    GeographicUnit('Calumpit', '0301413000'),
    GeographicUnit('Hagonoy', '0301414000'),
    GeographicUnit('Norzagaray', '0301415000'),
    GeographicUnit('Pandi', '0301416000'),
    GeographicUnit('Paombong', '0301417000'),
    GeographicUnit('Pulilan', '0301418000'),
    GeographicUnit('San Ildefonso', '0301419000'),
    GeographicUnit('San Miguel', '0301420000'),
    GeographicUnit('San Rafael', '0301421000'),
    // Pampanga
    GeographicUnit('Angeles City', '0305401000'),
    GeographicUnit('City of San Fernando', '0305402000'),
    GeographicUnit('Mabalacat City', '0305403000'),
    GeographicUnit('Guagua', '0305404000'),
    GeographicUnit('Lubao', '0305405000'),
    GeographicUnit('Mexico', '0305406000'),
    // Major Visayas & Mindanao Cities
    GeographicUnit('Cebu City', '0702217000'),
    GeographicUnit('Mandaue City', '0702230000'),
    GeographicUnit('Lapu-Lapu City', '0702226000'),
    GeographicUnit('Davao City', '1102404000'),
    GeographicUnit('Iloilo City', '0603010000'),
    GeographicUnit('Bacolod City', '0604501000'),
    GeographicUnit('Cagayan de Oro City', '1004305000'),
    GeographicUnit('Zamboanga City', '0907332000'),
    GeographicUnit('General Santos City', '1206303000'),
    GeographicUnit('Baguio City', '1401102000'),
    GeographicUnit('Laoag City', '0102812000'),
    GeographicUnit('Vigan City', '0102921000'),
  ];

  // Dynamic registration methods
  static void registerSpecializations(Iterable<Specialization> list) {
    for (var s in list) {
      if (s.name.isNotEmpty && s.specialty.isNotEmpty) {
        _dynamicSpecialties[s.name] = s.specialty;
        _dynamicSpecialties[s.name.toLowerCase()] = s.specialty;
      }
    }
  }

  static void registerInstitutions(Iterable<Institution> list) {
    for (var i in list) {
      if (!i.isRejected && i.name.isNotEmpty && i.institutionName.isNotEmpty) {
        _dynamicInstitutions[i.name] = i.institutionName;
        _dynamicInstitutions[i.name.toLowerCase()] = i.institutionName;
      }
    }
  }

  static void registerPsgcLocations(Iterable<PsgcLocation> list) {
    for (var p in list) {
      if (p.name.isNotEmpty && p.locationLabel.isNotEmpty) {
        final label = p.locationLabel.trim();
        _dynamicPsgcLocations[p.name] = label;
        _dynamicPsgcLocations[p.name.toLowerCase()] = label;
        if (p.psgcCode != null && p.psgcCode!.isNotEmpty) {
          _dynamicPsgcLocations[p.psgcCode!] = label;
          _dynamicPsgcLocations[p.psgcCode!.toLowerCase()] = label;
        }

        _psgcById[p.name] = p;
        _psgcByLabelLower[label.toLowerCase()] = p;
        if (p.psgcCode != null && p.psgcCode!.isNotEmpty) {
          _psgcById[p.psgcCode!] = p;
        }

        if (!_psgcLocations.any((loc) => loc.name == p.name)) {
          _psgcLocations.add(p);
        }

        final type = p.locationType.toLowerCase();
        if (type == 'region') {
          if (!_psgcRegions.any((r) => r.name == p.name)) {
            _psgcRegions.add(p);
          }
        } else if (type == 'province') {
          if (!_psgcProvinces.any((pr) => pr.name == p.name)) {
            _psgcProvinces.add(p);
          }
          if (p.parentPsgcLocation != null && p.parentPsgcLocation!.isNotEmpty) {
            _psgcProvincesByRegion.putIfAbsent(p.parentPsgcLocation!, () => []);
            if (!_psgcProvincesByRegion[p.parentPsgcLocation!]!.any((pr) => pr.name == p.name)) {
              _psgcProvincesByRegion[p.parentPsgcLocation!]!.add(p);
            }
          }
        } else if (type == 'city') {
          if (!_psgcCities.any((c) => c.name == p.name)) {
            _psgcCities.add(p);
          }
          if (p.parentPsgcLocation != null && p.parentPsgcLocation!.isNotEmpty) {
            _psgcCitiesByProvince.putIfAbsent(p.parentPsgcLocation!, () => []);
            if (!_psgcCitiesByProvince[p.parentPsgcLocation!]!.any((c) => c.name == p.name)) {
              _psgcCitiesByProvince[p.parentPsgcLocation!]!.add(p);
            }
          }
        }
      }
    }

    // Link parent mappings for strict cascading
    for (var prov in _psgcProvinces) {
      if (prov.parentPsgcLocation != null && _psgcById.containsKey(prov.parentPsgcLocation!)) {
        final reg = _psgcById[prov.parentPsgcLocation!]!;
        _provinceToRegionMap[prov.name] = reg;
        _provinceToRegionMap[prov.locationLabel.trim().toLowerCase()] = reg;
      }
    }

    for (var city in _psgcCities) {
      if (city.parentPsgcLocation != null && _psgcById.containsKey(city.parentPsgcLocation!)) {
        final prov = _psgcById[city.parentPsgcLocation!]!;
        _cityToProvinceMap[city.name] = prov;
        _cityToProvinceMap[city.locationLabel.trim().toLowerCase()] = prov;
      }
    }

    _isPsgcInitialized = true;
  }

  /// Synchronous fallback to ensure bundled PSGC dataset is loaded from disk if available
  static void _ensurePsgcSynchronousFallback() {
    if (_isPsgcInitialized && _psgcLocations.isNotEmpty) return;
    try {
      final f = File('assets/data/psgc_locations.json');
      if (f.existsSync()) {
        final content = f.readAsStringSync();
        final List<dynamic> parsed = jsonDecode(content);
        final list = parsed.map((j) => PsgcLocation.fromJson(j)).toList();
        registerPsgcLocations(list);
      }
    } catch (_) {
      // Ignored if file access is restricted (e.g. web/sandboxed mobile)
    }
  }

  /// Asynchronously loads and indexes all 1,772 official Philippine PSGC locations
  /// (18 Regions, 99 Provinces, 1,655 Cities/Municipalities) from assets/data/psgc_locations.json.
  static Future<void> initializePsgc({String? jsonString}) async {
    if (_isPsgcInitialized && _psgcLocations.isNotEmpty) return;
    try {
      String content = '';
      if (jsonString != null && jsonString.isNotEmpty) {
        content = jsonString;
      } else {
        try {
          content = await rootBundle.loadString('assets/data/psgc_locations.json');
        } catch (_) {
          final f = File('assets/data/psgc_locations.json');
          if (f.existsSync()) {
            content = f.readAsStringSync();
          }
        }
      }

      if (content.isNotEmpty) {
        final List<dynamic> parsed = jsonDecode(content);
        final list = parsed.map((j) => PsgcLocation.fromJson(j)).toList();
        registerPsgcLocations(list);
      }
    } catch (e) {
      print('Warning: initializePsgc encountered: $e');
    }
  }

  /// Returns all official Regions from PSGC (18 regions)
  static List<String> getRegions() {
    _ensurePsgcSynchronousFallback();
    if (_psgcRegions.isNotEmpty) {
      return _psgcRegions.map((r) => r.locationLabel).toList();
    }
    return standardRegions.map((r) => r.name).toList();
  }

  /// Returns strictly the Provinces belonging to the specified Region.
  /// If [regionNameOrCode] is null or empty, returns all Provinces in the Philippines.
  static List<String> getProvincesForRegion(String? regionNameOrCode) {
    _ensurePsgcSynchronousFallback();
    final regInput = regionNameOrCode?.trim() ?? '';
    if (regInput.isEmpty) {
      if (_psgcProvinces.isNotEmpty) {
        final list = <String>[];
        list.add('Metro Manila');
        for (var p in _psgcProvinces) {
          if (!list.contains(p.locationLabel)) {
            list.add(p.locationLabel);
          }
        }
        return list;
      }
      final list = standardProvinces.map((p) => p.name).toList();
      if (!list.contains('Metro Manila')) list.insert(0, 'Metro Manila');
      return list;
    }

    final regId = resolveRegionId(regInput);
    if (_psgcProvincesByRegion.containsKey(regId)) {
      final list = _psgcProvincesByRegion[regId]!.map((p) => p.locationLabel).toList();
      if (regId == '1300000000' || regInput.toLowerCase().contains('ncr') || regInput.toLowerCase().contains('capital')) {
        if (!list.contains('Metro Manila')) {
          list.insert(0, 'Metro Manila');
        }
      }
      return list;
    }

    // Fallback using 2-digit PSGC prefix
    if (regId.length >= 2) {
      final prefix = regId.substring(0, 2);
      if (_psgcProvinces.isNotEmpty) {
        final list = _psgcProvinces
            .where((p) => p.name.startsWith(prefix) || (p.psgcCode != null && p.psgcCode!.startsWith(prefix)))
            .map((p) => p.locationLabel)
            .toList();
        if (prefix == '13' && !list.contains('Metro Manila')) {
          list.insert(0, 'Metro Manila');
        }
        if (list.isNotEmpty) return list;
      }
      final standard = standardProvinces.where((p) => p.code.startsWith(prefix)).map((p) => p.name).toList();
      if (prefix == '13' && !standard.contains('Metro Manila')) {
        standard.insert(0, 'Metro Manila');
      }
      return standard;
    }

    return standardProvinces.map((p) => p.name).toList();
  }

  /// Returns strictly the Cities / Municipalities belonging to the specified Province.
  /// Strict cascading: NO other provinces' cities are EVER appended!
  static List<String> getCitiesForProvince(String? provinceNameOrCode) {
    _ensurePsgcSynchronousFallback();
    final provInput = provinceNameOrCode?.trim() ?? '';
    if (provInput.isEmpty) {
      if (_psgcCities.isNotEmpty) {
        return _psgcCities.map((c) => c.locationLabel).toSet().toList();
      }
      return standardCities.map((c) => c.name).toSet().toList();
    }

    // Handle "Metro Manila" umbrella province -> returns all NCR cities
    if (provInput.toLowerCase() == 'metro manila' || provInput.toLowerCase().contains('national capital')) {
      if (_psgcCities.isNotEmpty) {
        final ncrCities = _psgcCities
            .where((c) => c.name.startsWith('13') || (c.parentPsgcLocation != null && c.parentPsgcLocation!.startsWith('13')))
            .map((c) => c.locationLabel)
            .toSet()
            .toList();
        if (ncrCities.isNotEmpty) return ncrCities;
      }
      return standardCities.where((c) => c.code.startsWith('13')).map((c) => c.name).toSet().toList();
    }

    // Lookup province record by ID or label
    PsgcLocation? provLoc;
    final provId = resolveProvinceId(provInput);
    if (_psgcById.containsKey(provId)) {
      provLoc = _psgcById[provId];
    } else if (_psgcByLabelLower.containsKey(provInput.toLowerCase())) {
      provLoc = _psgcByLabelLower[provInput.toLowerCase()];
    }

    final targetProvId = provLoc?.name ?? provId;
    if (_psgcCitiesByProvince.containsKey(targetProvId)) {
      final cities = _psgcCitiesByProvince[targetProvId]!.map((c) => c.locationLabel).toSet().toList();
      if (cities.isNotEmpty) return cities;
    }

    // Fallback: match by 4-digit PSGC prefix
    if (targetProvId.length >= 4) {
      final prefix = targetProvId.substring(0, 4);
      if (_psgcCities.isNotEmpty) {
        final cities = _psgcCities
            .where((c) => c.name.startsWith(prefix) || (c.parentPsgcLocation != null && c.parentPsgcLocation!.startsWith(prefix)))
            .map((c) => c.locationLabel)
            .toSet()
            .toList();
        if (cities.isNotEmpty) return cities;
      }
      return standardCities.where((c) => c.code.startsWith(prefix)).map((c) => c.name).toSet().toList();
    }

    return [];
  }

  /// Automatically derive parent Province name from a City name or PSGC code
  static String? resolveProvinceFromCity(String? cityNameOrCode) {
    if (cityNameOrCode == null || cityNameOrCode.trim().isEmpty) return null;
    _ensurePsgcSynchronousFallback();
    final trimmed = cityNameOrCode.trim();

    if (_cityToProvinceMap.containsKey(trimmed.toLowerCase())) {
      return _cityToProvinceMap[trimmed.toLowerCase()]!.locationLabel;
    }
    final cityId = resolveCityId(trimmed);
    if (_cityToProvinceMap.containsKey(cityId)) {
      return _cityToProvinceMap[cityId]!.locationLabel;
    }

    // If city is an NCR city (e.g. Las Piñas City, Makati City)
    if (cityId.startsWith('13') || trimmed.toLowerCase().contains('las piñ') || trimmed.toLowerCase().contains('las pin')) {
      for (var p in _psgcProvinces) {
        if (p.name.startsWith('13802') || p.locationLabel.toLowerCase().contains('las piñ') || p.locationLabel.toLowerCase().contains('las pin')) {
          return p.locationLabel;
        }
      }
      return 'Metro Manila-Las Piñas';
    }

    // Fallback: find province matching city prefix (first 4 digits)
    if (cityId.length >= 4) {
      final provPrefix = cityId.substring(0, 4);
      for (var p in _psgcProvinces) {
        if (p.name.startsWith(provPrefix)) {
          return p.locationLabel;
        }
      }
      for (var p in standardProvinces) {
        if (p.code.startsWith(provPrefix)) {
          return p.name;
        }
      }
    }

    return null;
  }

  static void registerHcpTypes(Iterable<HcpType> list) {
    for (var t in list) {
      if (t.name.isNotEmpty && t.typeName.isNotEmpty) {
        _dynamicHcpTypes[t.name] = t.typeName;
        _dynamicHcpTypes[t.name.toLowerCase()] = t.typeName;
      }
    }
  }

  /// Resolve an HCP Type ID (e.g. HCP-TYPE-01) or raw name to its human-readable title (e.g. "Consultant")
  static String resolveHcpTypeName(String? raw, [List<HcpType>? dynamicTypes]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '';
    final trimmed = raw.trim();

    if (dynamicTypes != null && dynamicTypes.isNotEmpty) {
      final found = dynamicTypes.firstWhere(
        (t) => t.name == trimmed || t.name.toLowerCase() == trimmed.toLowerCase() || t.typeName.toLowerCase() == trimmed.toLowerCase(),
        orElse: () => HcpType(name: '', typeName: ''),
      );
      if (found.typeName.isNotEmpty) return found.typeName;
    }

    if (_dynamicHcpTypes.containsKey(trimmed)) return _dynamicHcpTypes[trimmed]!;
    if (_dynamicHcpTypes.containsKey(trimmed.toLowerCase())) return _dynamicHcpTypes[trimmed.toLowerCase()]!;

    if (_staticHcpTypes.containsKey(trimmed)) return _staticHcpTypes[trimmed]!;
    if (_staticHcpTypes.containsKey(trimmed.toUpperCase())) return _staticHcpTypes[trimmed.toUpperCase()]!;

    final lower = trimmed.toLowerCase();
    if (lower == 'consultant' || lower.contains('consultant')) return 'Consultant';
    if (lower == 'resident' || lower.contains('resident')) return 'Resident';
    if (lower == 'fellow' || lower.contains('fellow')) return 'Fellow';

    return trimmed;
  }

  /// Resolve an HCP Type human name (e.g. "Consultant") to its ERPNext Link ID (e.g. "HCP-TYPE-01")
  static String resolveHcpTypeId(String? raw, [List<HcpType>? dynamicTypes]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return 'HCP-TYPE-01';
    final trimmed = raw.trim();

    if (trimmed.toUpperCase().startsWith('HCP-TYPE-')) return trimmed.toUpperCase();

    if (dynamicTypes != null && dynamicTypes.isNotEmpty) {
      final found = dynamicTypes.firstWhere(
        (t) => t.typeName.toLowerCase() == trimmed.toLowerCase() || t.name.toLowerCase() == trimmed.toLowerCase(),
        orElse: () => HcpType(name: '', typeName: ''),
      );
      if (found.name.isNotEmpty) return found.name;
    }

    for (var entry in _dynamicHcpTypes.entries) {
      if (entry.value.toLowerCase() == trimmed.toLowerCase()) {
        return entry.key;
      }
    }

    for (var entry in _staticHcpTypes.entries) {
      if (entry.value.toLowerCase() == trimmed.toLowerCase()) {
        return entry.key;
      }
    }

    final lower = trimmed.toLowerCase();
    if (lower == 'consultant' || lower.contains('consultant')) return 'HCP-TYPE-01';
    if (lower == 'resident' || lower.contains('resident')) return 'HCP-TYPE-02';
    if (lower == 'fellow' || lower.contains('fellow')) return 'HCP-TYPE-03';

    return trimmed;
  }

  /// Resolve a Specialty ID (e.g. SPEC-00003) or name to its human-readable title
  static String resolveSpecialtyName(String? raw, [List<Specialization>? dynamicSpecs]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '';
    final trimmed = raw.trim();

    // 1. Check passed dynamic list
    if (dynamicSpecs != null && dynamicSpecs.isNotEmpty) {
      final found = dynamicSpecs.firstWhere(
        (s) => s.name == trimmed || s.name.toLowerCase() == trimmed.toLowerCase() || s.specialty.toLowerCase() == trimmed.toLowerCase(),
        orElse: () => Specialization(name: '', specialty: '', specialtyGroup: ''),
      );
      if (found.specialty.isNotEmpty) return found.specialty;
    }

    // 2. Check dynamic in-memory registry
    if (_dynamicSpecialties.containsKey(trimmed)) {
      return _dynamicSpecialties[trimmed]!;
    }
    if (_dynamicSpecialties.containsKey(trimmed.toLowerCase())) {
      return _dynamicSpecialties[trimmed.toLowerCase()]!;
    }

    // 3. Check static map
    if (_staticSpecialties.containsKey(trimmed)) {
      return _staticSpecialties[trimmed]!;
    }
    final upperKey = trimmed.toUpperCase();
    if (_staticSpecialties.containsKey(upperKey)) {
      return _staticSpecialties[upperKey]!;
    }

    // Check by integer index (e.g. SPEC-3 -> SPEC-00003)
    if (upperKey.startsWith('SPEC-')) {
      final numPart = upperKey.replaceFirst('SPEC-', '');
      final parsed = int.tryParse(numPart);
      if (parsed != null) {
        final formattedKey = 'SPEC-${parsed.toString().padLeft(5, '0')}';
        if (_staticSpecialties.containsKey(formattedKey)) {
          return _staticSpecialties[formattedKey]!;
        }
      }
    }

    // If it is already human-readable and doesn't look like an unmapped SPEC- code, return it
    if (!trimmed.startsWith('SPEC-')) {
      return trimmed;
    }
    return trimmed;
  }

  /// Resolve an Institution ID (e.g. INST-00006) or name to its human-readable title
  static String resolveInstitutionName(String? raw, [List<Institution>? dynamicInsts]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '';
    final trimmed = raw.trim();

    // 1. Check passed dynamic list
    if (dynamicInsts != null && dynamicInsts.isNotEmpty) {
      final found = dynamicInsts.firstWhere(
        (i) => i.name == trimmed || i.name.toLowerCase() == trimmed.toLowerCase() || i.institutionName.toLowerCase() == trimmed.toLowerCase(),
        orElse: () => Institution(name: '', institutionName: ''),
      );
      if (found.institutionName.isNotEmpty) return found.institutionName;
    }

    // 2. Check dynamic in-memory registry
    if (_dynamicInstitutions.containsKey(trimmed)) {
      return _dynamicInstitutions[trimmed]!;
    }
    if (_dynamicInstitutions.containsKey(trimmed.toLowerCase())) {
      return _dynamicInstitutions[trimmed.toLowerCase()]!;
    }

    // 3. Check static map
    if (_staticInstitutions.containsKey(trimmed)) {
      return _staticInstitutions[trimmed]!;
    }
    final upperKey = trimmed.toUpperCase();
    if (_staticInstitutions.containsKey(upperKey)) {
      return _staticInstitutions[upperKey]!;
    }

    // Check by integer index (e.g. INST-6 -> INST-00006)
    if (upperKey.startsWith('INST-')) {
      final numPart = upperKey.replaceFirst('INST-', '');
      final parsed = int.tryParse(numPart);
      if (parsed != null) {
        final formattedKey = 'INST-${parsed.toString().padLeft(5, '0')}';
        if (_staticInstitutions.containsKey(formattedKey)) {
          return _staticInstitutions[formattedKey]!;
        }
      }
    }

    // If already human readable, return it
    if (!trimmed.startsWith('INST-')) {
      return trimmed;
    }
    return trimmed;
  }

  /// Resolve a PSGC code (e.g. 0301400000, 0402100000) to its human-readable Province Name
  static String resolveProvinceName(String? raw, [List<PsgcLocation>? dynamicLocations]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '';
    final trimmed = raw.trim();

    // 1. Check dynamic locations
    if (dynamicLocations != null && dynamicLocations.isNotEmpty) {
      final match = dynamicLocations.firstWhere(
        (loc) => loc.name == trimmed || loc.psgcCode == trimmed || loc.name.toLowerCase() == trimmed.toLowerCase(),
        orElse: () => PsgcLocation(name: '', locationLabel: '', locationType: ''),
      );
      if (match.locationLabel.isNotEmpty && !RegExp(r'^\d+$').hasMatch(match.locationLabel)) {
        return match.locationLabel;
      }
    }

    // 2. Check in-memory registered PSGC locations
    if (_dynamicPsgcLocations.containsKey(trimmed) && !RegExp(r'^\d+$').hasMatch(_dynamicPsgcLocations[trimmed]!)) {
      return _dynamicPsgcLocations[trimmed]!;
    }
    if (_dynamicPsgcLocations.containsKey(trimmed.toLowerCase()) && !RegExp(r'^\d+$').hasMatch(_dynamicPsgcLocations[trimmed.toLowerCase()]!)) {
      return _dynamicPsgcLocations[trimmed.toLowerCase()]!;
    }

    // Extract digits for numeric matching (e.g. "0301400000" or "PRV-0301400000" or "1380600000")
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');

    // NCR / Metro Manila check (starts with 13)
    if (digitsOnly.startsWith('13')) {
      return 'Metro Manila';
    }

    // 3. Check standard provinces list
    for (var p in standardProvinces) {
      if (p.code == trimmed || p.name.toLowerCase() == trimmed.toLowerCase()) {
        return p.name;
      }
      if (digitsOnly.isNotEmpty && (p.code == digitsOnly || digitsOnly.startsWith(p.code))) {
        return p.name;
      }
      // Check prefix (first 4 or 5 digits of PSGC code e.g. 04021 -> Cavite, 04010 -> Batangas, 04034 -> Laguna)
      if (digitsOnly.length >= 4 && p.code.length >= 4 && p.code.substring(0, 4) == digitsOnly.substring(0, 4)) {
        return p.name;
      }
    }

    // If not digits only and not a code, return clean trimmed string
    final isAllDigits = RegExp(r'^\d+$').hasMatch(trimmed);
    if (!isAllDigits && !trimmed.startsWith('PRV-') && !trimmed.startsWith('REG-') && !trimmed.startsWith('CTY-')) {
      return trimmed;
    }

    return trimmed;
  }

  /// Resolve a City/Municipality PSGC code or name
  static String resolveCityName(String? raw, [List<PsgcLocation>? dynamicLocations]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '';
    final trimmed = raw.trim();

    // 1. Check dynamic locations
    if (dynamicLocations != null && dynamicLocations.isNotEmpty) {
      final match = dynamicLocations.firstWhere(
        (loc) => loc.name == trimmed || loc.psgcCode == trimmed || loc.name.toLowerCase() == trimmed.toLowerCase(),
        orElse: () => PsgcLocation(name: '', locationLabel: '', locationType: ''),
      );
      if (match.locationLabel.isNotEmpty && !RegExp(r'^\d+$').hasMatch(match.locationLabel)) {
        return match.locationLabel;
      }
    }

    // 2. Check in-memory registered PSGC locations
    if (_dynamicPsgcLocations.containsKey(trimmed) && !RegExp(r'^\d+$').hasMatch(_dynamicPsgcLocations[trimmed]!)) {
      return _dynamicPsgcLocations[trimmed]!;
    }
    if (_dynamicPsgcLocations.containsKey(trimmed.toLowerCase()) && !RegExp(r'^\d+$').hasMatch(_dynamicPsgcLocations[trimmed.toLowerCase()]!)) {
      return _dynamicPsgcLocations[trimmed.toLowerCase()]!;
    }

    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');

    // 3. Check standardCities list exact code or name
    for (var c in standardCities) {
      if (c.code == trimmed || c.name.toLowerCase() == trimmed.toLowerCase()) {
        return c.name;
      }
      if (digitsOnly.isNotEmpty && (c.code == digitsOnly || digitsOnly.startsWith(c.code) || c.code.startsWith(digitsOnly))) {
        return c.name;
      }
    }

    // 4. Intelligently map known PSGC city/district patterns
    if (digitsOnly.startsWith('13806')) return 'City of Manila';
    if (digitsOnly.startsWith('13801')) return 'Caloocan City';
    if (digitsOnly.startsWith('13802')) return 'Las Piñas City';
    if (digitsOnly.startsWith('13803') || digitsOnly.startsWith('137602')) return 'Makati City';
    if (digitsOnly.startsWith('13804')) return 'Malabon City';
    if (digitsOnly.startsWith('13805')) return 'Mandaluyong City';
    if (digitsOnly.startsWith('13807')) return 'Marikina City';
    if (digitsOnly.startsWith('13808')) return 'Muntinlupa City';
    if (digitsOnly.startsWith('13809')) return 'Navotas City';
    if (digitsOnly.startsWith('13810')) return 'Parañaque City';
    if (digitsOnly.startsWith('13811')) return 'Pasay City';
    if (digitsOnly.startsWith('13812') || digitsOnly.startsWith('137603')) return 'Pasig City';
    if (digitsOnly.startsWith('13813') || digitsOnly.startsWith('1374')) return 'Quezon City';
    if (digitsOnly.startsWith('13814')) return 'San Juan City';
    if (digitsOnly.startsWith('13815')) return 'Taguig City';
    if (digitsOnly.startsWith('13816')) return 'Valenzuela City';
    if (digitsOnly.startsWith('13817')) return 'Pateros';

    // Cavite cities & towns
    if (digitsOnly.startsWith('0402123')) return 'General Trias';
    if (digitsOnly.startsWith('0402102')) return 'Bacoor';
    if (digitsOnly.startsWith('0402105')) return 'Cavite City';
    if (digitsOnly.startsWith('0402106')) return 'Dasmariñas';
    if (digitsOnly.startsWith('0402111')) return 'Imus';
    if (digitsOnly.startsWith('0402119')) return 'Tagaytay';
    if (digitsOnly.startsWith('0402120')) return 'Tanza';
    if (digitsOnly.startsWith('0402114')) return 'Kawit';
    if (digitsOnly.startsWith('0402118')) return 'Silang';
    if (digitsOnly.startsWith('0402117')) return 'Rosario';
    if (digitsOnly.startsWith('0402113')) return 'Carmona';
    if (digitsOnly.startsWith('0402122')) return 'Trece Martires';

    // Batangas cities & towns
    if (digitsOnly.startsWith('0401005')) return 'Batangas City';
    if (digitsOnly.startsWith('0401019')) return 'Lipa City';
    if (digitsOnly.startsWith('0401030')) return 'Tanauan City';
    if (digitsOnly.startsWith('0401027')) return 'Santo Tomas';

    // Laguna cities & towns
    if (digitsOnly.startsWith('0403403')) return 'Biñan';
    if (digitsOnly.startsWith('0403404')) return 'Cabuyao';
    if (digitsOnly.startsWith('0403405')) return 'Calamba';
    if (digitsOnly.startsWith('0403424')) return 'San Pablo City';
    if (digitsOnly.startsWith('0403425')) return 'San Pedro';
    if (digitsOnly.startsWith('0403427')) return 'Santa Rosa';
    if (digitsOnly.startsWith('0403426')) return 'Santa Cruz';
    if (digitsOnly.startsWith('0403418')) return 'Los Baños';

    // Quezon & Rizal
    if (digitsOnly.startsWith('0405624')) return 'Lucena City';
    if (digitsOnly.startsWith('0405641')) return 'Tayabas City';
    if (digitsOnly.startsWith('0405637')) return 'Sariaya';
    if (digitsOnly.startsWith('0405611')) return 'Candelaria';
    if (digitsOnly.startsWith('0405802')) return 'Antipolo City';
    if (digitsOnly.startsWith('0405801')) return 'Angono';
    if (digitsOnly.startsWith('0405804')) return 'Cainta';
    if (digitsOnly.startsWith('0405811') || digitsOnly.startsWith('0405812')) return 'San Mateo';
    if (digitsOnly.startsWith('0405813')) return 'Taytay';

    // Bulacan & Pampanga
    if (digitsOnly.startsWith('0301401')) return 'Malolos City';
    if (digitsOnly.startsWith('0301402')) return 'Meycauayan City';
    if (digitsOnly.startsWith('0301403')) return 'San Jose del Monte City';
    if (digitsOnly.startsWith('0301404')) return 'Marilao';
    if (digitsOnly.startsWith('0301405')) return 'Santa Maria';
    if (digitsOnly.startsWith('0301406')) return 'Baliuag';
    if (digitsOnly.startsWith('0304901')) return 'Cabanatuan City';
    if (digitsOnly.startsWith('0305401')) return 'Angeles City';
    if (digitsOnly.startsWith('0305402')) return 'City of San Fernando';
    if (digitsOnly.startsWith('0305403')) return 'Mabalacat City';
    if (digitsOnly.startsWith('0306901')) return 'Tarlac City';
    if (digitsOnly.startsWith('0307101')) return 'Olongapo City';

    // Major Visayas / Mindanao
    if (digitsOnly.startsWith('0702217')) return 'Cebu City';
    if (digitsOnly.startsWith('1102404')) return 'Davao City';
    if (digitsOnly.startsWith('0603010')) return 'Iloilo City';
    if (digitsOnly.startsWith('0604501')) return 'Bacolod City';
    if (digitsOnly.startsWith('1004305')) return 'Cagayan de Oro City';
    if (digitsOnly.startsWith('1206303')) return 'General Santos City';
    if (digitsOnly.startsWith('1401102')) return 'Baguio City';

    final isAllDigits = RegExp(r'^\d+$').hasMatch(trimmed);
    if (!isAllDigits && !trimmed.startsWith('CTY-') && !trimmed.startsWith('MUN-')) {
      return trimmed;
    }

    return trimmed;
  }

  /// Format a complete, clean human-readable location address string
  static String formatLocation({
    String? streetAddress,
    String? cityMunicipality,
    String? provinceName,
    String? regionName,
  }) {
    final cleanStreet = (streetAddress != null && streetAddress.trim().isNotEmpty && streetAddress.trim() != '-')
        ? streetAddress.trim()
        : null;
    final cleanCity = resolveCityName(cityMunicipality);
    final cleanProv = resolveProvinceName(provinceName);
    final cleanReg = resolveRegionName(regionName);

    final Set<String> parts = {};
    if (cleanStreet != null && !RegExp(r'^\d+$').hasMatch(cleanStreet)) {
      parts.add(cleanStreet);
    }
    if (cleanCity.isNotEmpty && cleanCity != '-' && !RegExp(r'^\d+$').hasMatch(cleanCity)) {
      parts.add(cleanCity);
    }
    if (cleanProv.isNotEmpty &&
        cleanProv != '-' &&
        !RegExp(r'^\d+$').hasMatch(cleanProv) &&
        !parts.contains(cleanProv) &&
        !cleanCity.toLowerCase().contains(cleanProv.toLowerCase())) {
      parts.add(cleanProv);
    }
    if (cleanReg.isNotEmpty &&
        cleanReg != '-' &&
        !RegExp(r'^\d+$').hasMatch(cleanReg) &&
        !parts.contains(cleanReg) &&
        !cleanProv.toLowerCase().contains(cleanReg.toLowerCase()) &&
        !cleanCity.toLowerCase().contains(cleanReg.toLowerCase())) {
      parts.add(cleanReg);
    }
    return parts.join(', ');
  }

  /// Resolve a Region PSGC code or name
  static String resolveRegionName(String? raw, [List<PsgcLocation>? dynamicLocations]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '';
    final trimmed = raw.trim();

    if (dynamicLocations != null && dynamicLocations.isNotEmpty) {
      final match = dynamicLocations.firstWhere(
        (loc) => loc.name == trimmed || loc.psgcCode == trimmed || loc.name.toLowerCase() == trimmed.toLowerCase(),
        orElse: () => PsgcLocation(name: '', locationLabel: '', locationType: ''),
      );
      if (match.locationLabel.isNotEmpty && !RegExp(r'^\d+$').hasMatch(match.locationLabel)) {
        return match.locationLabel;
      }
    }

    if (_dynamicPsgcLocations.containsKey(trimmed) && !RegExp(r'^\d+$').hasMatch(_dynamicPsgcLocations[trimmed]!)) {
      return _dynamicPsgcLocations[trimmed]!;
    }
    if (_dynamicPsgcLocations.containsKey(trimmed.toLowerCase()) && !RegExp(r'^\d+$').hasMatch(_dynamicPsgcLocations[trimmed.toLowerCase()]!)) {
      return _dynamicPsgcLocations[trimmed.toLowerCase()]!;
    }

    for (var r in standardRegions) {
      if (r.code == trimmed || r.name.toLowerCase() == trimmed.toLowerCase()) {
        return r.name;
      }
      if (trimmed.length >= 2 && r.code.length >= 2 && r.code.substring(0, 2) == trimmed.substring(0, 2)) {
        return r.name;
      }
    }

    final isAllDigits = RegExp(r'^\d+$').hasMatch(trimmed);
    if (!isAllDigits && !trimmed.startsWith('REG-')) {
      return trimmed;
    }

    return trimmed;
  }

  /// Resolve a Specialty title (e.g. "Family Medicine") to its ERPNext Link ID (e.g. "SPEC-00003")
  static String resolveSpecialtyId(String? raw, [List<Specialization>? dynamicSpecs]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '';
    final trimmed = raw.trim();

    // 1. Check dynamicSpecs
    if (dynamicSpecs != null && dynamicSpecs.isNotEmpty) {
      final found = dynamicSpecs.firstWhere(
        (s) => s.specialty.toLowerCase() == trimmed.toLowerCase() || s.name.toLowerCase() == trimmed.toLowerCase(),
        orElse: () => Specialization(name: '', specialty: '', specialtyGroup: ''),
      );
      if (found.name.isNotEmpty) return found.name;
    }

    // 2. Check dynamic in-memory registry
    for (var entry in _dynamicSpecialties.entries) {
      if (entry.value.toLowerCase() == trimmed.toLowerCase()) {
        return entry.key.toUpperCase();
      }
    }

    // 3. Check static map
    for (var entry in _staticSpecialties.entries) {
      if (entry.value.toLowerCase() == trimmed.toLowerCase()) {
        return entry.key;
      }
    }

    // If it already starts with SPEC-, return it
    if (trimmed.toUpperCase().startsWith('SPEC-')) {
      return trimmed.toUpperCase();
    }

    return trimmed;
  }

  /// Resolve an Institution title (e.g. "UP-Philippine General Hospital") to its ERPNext Link ID (e.g. "INST-00006")
  static String resolveInstitutionId(String? raw, [List<Institution>? dynamicInsts]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '';
    final trimmed = raw.trim();

    // 1. Check dynamicInsts
    if (dynamicInsts != null && dynamicInsts.isNotEmpty) {
      final found = dynamicInsts.firstWhere(
        (i) => i.institutionName.toLowerCase() == trimmed.toLowerCase() || i.name.toLowerCase() == trimmed.toLowerCase(),
        orElse: () => Institution(name: '', institutionName: ''),
      );
      if (found.name.isNotEmpty) {
        if (found.isRejected) return '';
        return found.name;
      }
    }

    // 2. Check dynamic in-memory registry
    for (var entry in _dynamicInstitutions.entries) {
      if (entry.value.toLowerCase() == trimmed.toLowerCase()) {
        return entry.key.toUpperCase();
      }
    }

    // 3. Check static map
    for (var entry in _staticInstitutions.entries) {
      if (entry.value.toLowerCase() == trimmed.toLowerCase()) {
        return entry.key;
      }
    }

    // If it starts with INST-, return it
    if (trimmed.toUpperCase().startsWith('INST-')) {
      return trimmed.toUpperCase();
    }

    return trimmed;
  }

  /// Check if a given institution (by ID or display name) was rejected by SFE.
  static bool isRejectedInstitution(String? raw, [List<Institution>? dynamicInsts]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return false;
    final trimmed = raw.trim().toLowerCase();
    if (dynamicInsts != null && dynamicInsts.isNotEmpty) {
      final found = dynamicInsts.firstWhere(
        (i) => i.name.toLowerCase() == trimmed || i.institutionName.toLowerCase() == trimmed,
        orElse: () => Institution(name: '', institutionName: ''),
      );
      if (found.name.isNotEmpty) {
        if (found.isRemapped) return false;
        return found.isRejected;
      }
    }
    return false;
  }

  /// Get rejection reason for a rejected institution if available.
  static String? getRejectedInstitutionReason(String? raw, [List<Institution>? dynamicInsts]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return null;
    final trimmed = raw.trim().toLowerCase();
    if (dynamicInsts != null && dynamicInsts.isNotEmpty) {
      final found = dynamicInsts.firstWhere(
        (i) => i.name.toLowerCase() == trimmed || i.institutionName.toLowerCase() == trimmed,
        orElse: () => Institution(name: '', institutionName: ''),
      );
      if (found.name.isNotEmpty && found.isRejected && !found.isRemapped) {
        return found.rejectionReason?.trim();
      }
    }
    return null;
  }

  /// Check if a given institution (by ID or display name) is verified and approved by SFE.
  static bool isApprovedInstitution(String? raw, [List<Institution>? dynamicInsts]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return false;
    final trimmed = raw.trim();

    if (dynamicInsts != null && dynamicInsts.isNotEmpty) {
      final found = dynamicInsts.firstWhere(
        (i) => i.name.toLowerCase() == trimmed.toLowerCase() || i.institutionName.toLowerCase() == trimmed.toLowerCase(),
        orElse: () => Institution(name: '', institutionName: ''),
      );
      if (found.name.isNotEmpty) {
        return found.isApproved && !found.isRejected;
      }
    }

    final match = RegExp(r'^INST-(\d+)$', caseSensitive: false).firstMatch(trimmed);
    if (match != null) {
      final num = int.tryParse(match.group(1)!) ?? 0;
      if (num > 0 && num <= 7000) return true;
    }

    if (_staticInstitutions.containsKey(trimmed.toUpperCase())) {
      return true;
    }
    for (var entry in _staticInstitutions.entries) {
      if (entry.value.toLowerCase() == trimmed.toLowerCase()) {
        return true;
      }
    }

    return false;
  }

  /// Exact note required for HCP Account:
  /// - "[REJECTED INSTITUTION: <Reason>]" (Red)
  /// - "this institution is not yet approved"
  /// - "this institution is now approved"
  static String getInstitutionApprovalStatusNote(String? raw, [List<Institution>? dynamicInsts]) {
    if (isRejectedInstitution(raw, dynamicInsts)) {
      if (dynamicInsts != null && dynamicInsts.isNotEmpty && raw != null) {
        final trimmed = raw.trim().toLowerCase();
        final found = dynamicInsts.firstWhere(
          (i) => i.name.toLowerCase() == trimmed || i.institutionName.toLowerCase() == trimmed,
          orElse: () => Institution(name: '', institutionName: ''),
        );
        if (found.rejectionReason != null && found.rejectionReason!.trim().isNotEmpty) {
          return '[REJECTED INSTITUTION: ${found.rejectionReason!.trim()}]';
        }
      }
      return '[REJECTED INSTITUTION]';
    }
    final isApproved = isApprovedInstitution(raw, dynamicInsts);
    return isApproved
        ? 'this institution is now approved'
        : 'this institution is not yet approved';
  }

  /// Known Philippine healthcare institution acronyms and common abbreviations
  static const Map<String, List<String>> _philippineMedicalAcronyms = {
    'ust': ['university of santo tomas', 'ust hospital', 'usth'],
    'usth': ['university of santo tomas hospital', 'ust'],
    'slmc': ['st luke', 'st lukes', 'saint luke', 'saint lukes'],
    'pgh': ['philippine general hospital', 'up pgh'],
    'mmc': ['makati medical center', 'metropolitan medical center'],
    'csmc': ['cardinal santos medical center', 'cardinal santos'],
    'tmc': ['the medical city', 'medical city'],
    'ahmc': ['asian hospital and medical center', 'asian hospital'],
    'nkti': ['national kidney and transplant institute', 'national kidney'],
    'lcp': ['lung center of the philippines', 'lung center'],
    'phc': ['philippine heart center'],
    'eamc': ['east avenue medical center', 'east avenue'],
    'vmmc': ['veterans memorial medical center', 'veterans memorial'],
    'mdh': ['manila doctors hospital', 'manila doctors'],
    'cgh': ['chinese general hospital', 'chinese general'],
    'cghmc': ['chinese general hospital and medical center'],
    'feu': ['far eastern university', 'feu nrmf'],
    'feunrmf': ['far eastern university nicanor reyes', 'feu nrmf'],
    'uerm': ['university of the east ramon magsaysay', 'uerm memorial'],
    'uermmmc': ['university of the east ramon magsaysay memorial medical center'],
    'doh': ['department of health'],
    'rhu': ['rural health unit'],
    'bhs': ['barangay health station'],
    'ncmh': ['national center for mental health'],
    'poc': ['philippine orthopedic center'],
    'qmmc': ['quirino memorial medical center'],
    'armmc': ['amang rodriguez memorial medical center'],
    'rmc': ['rizal medical center'],
    'dlsu': ['de la salle university medical center'],
    'dlsumc': ['de la salle university medical center'],
    'uphs': ['university of perpetual help'],
    'uphmc': ['university of perpetual help dalta medical center'],
    'cmc': ['capitol medical center'],
    'cdh': ['cebu doctors hospital', 'cebu doctors university hospital'],
    'cduh': ['cebu doctors university hospital'],
    'spmc': ['southern philippines medical center'],
    'bgh': ['baguio general hospital and medical center'],
    'bghmc': ['baguio general hospital and medical center'],
    'mcm': ['medical center manila'],
  };

  /// Computes all dynamic acronym variations for an institution name:
  /// 1. Literal initials of all tokens (e.g. "uosth" for "University of Santo Tomas Hospital")
  /// 2. Initials excluding connectors ("of", "and", "the", etc.) -> "usth"
  /// 3. Core initials excluding connectors AND facility terms ("hospital", "medical", etc.) -> "ust"
  /// 4. Acronyms enclosed in parentheses -> "ust"
  /// 5. Standalone uppercase/abbreviation tokens
  static Set<String> computeInstitutionAcronyms(String rawInstName) {
    final Set<String> acronyms = {};

    // 1. Parentheses acronyms e.g. "University of Santo Tomas (UST) Hospital"
    final parenMatches = RegExp(r'\(([^)]+)\)').allMatches(rawInstName);
    for (var m in parenMatches) {
      final inside = m.group(1)?.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim() ?? '';
      if (inside.length >= 2 && inside.length <= 8) {
        acronyms.add(inside);
      }
    }

    final norm = rawInstName
        .replaceAll("'", "")
        .replaceAll("’", "")
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (norm.isEmpty) return acronyms;

    final tokens = norm.split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return acronyms;

    for (var t in tokens) {
      if (t.length >= 2 && t.length <= 5 && RegExp(r'^[a-z]+$').hasMatch(t)) {
        acronyms.add(t);
      }
    }

    final literal = tokens.map((t) => t[0]).join('');
    if (literal.length >= 2) acronyms.add(literal);

    const connectors = {
      'of', 'and', 'the', 'de', 'del', 'la', 'ng', 'sa', 'in', 'at', 'for', 'to', 'by', 'on', 'with', 'a', 'an'
    };

    final nonConnectorTokens = tokens.where((t) => !connectors.contains(t)).toList();
    if (nonConnectorTokens.isNotEmpty) {
      final nonConnInitials = nonConnectorTokens.map((t) => t[0]).join('');
      if (nonConnInitials.length >= 2) acronyms.add(nonConnInitials);
    }

    const facilityStopWords = {
      'hospital', 'medical', 'center', 'centre', 'clinic', 'clinics',
      'foundation', 'infirmary', 'sanitarium', 'institute', 'inc', 'corp',
      'corporation', 'co', 'ltd', 'memorial', 'general', 'community',
      'district', 'city', 'provincial', 'regional', 'phils', 'philippines',
      'care', 'health', 'diagnostic', 'lying',
    };

    final coreFacilityTokens = nonConnectorTokens.where((t) => !facilityStopWords.contains(t)).toList();
    if (coreFacilityTokens.isNotEmpty) {
      final coreInitials = coreFacilityTokens.map((t) => t[0]).join('');
      if (coreInitials.length >= 2) acronyms.add(coreInitials);
    }

    return acronyms;
  }

  /// Evaluates similarity between search query and institution candidate.
  /// Returns a record: (score, isHighConfidence). Score >= 65.0 is considered a match.
  static (double, bool) _scoreInstitutionCandidate({
    required String cleanQ,
    required List<String> qTokens,
    required List<String> coreTokens,
    required bool isAcronymCandidate,
    required String rawInstName,
    required String normInstName,
    required List<String> instTokens,
    required Set<String> instAcronyms,
  }) {
    final bool isKnownAcronym = _philippineMedicalAcronyms.containsKey(cleanQ) &&
        _philippineMedicalAcronyms[cleanQ]!.any((target) => normInstName.contains(target));

    final bool isDynamicAcronym = isAcronymCandidate &&
        (instAcronyms.contains(cleanQ) || (cleanQ.length >= 3 && instAcronyms.any((a) => a.startsWith(cleanQ))));

    final bool hasWordBoundary = normInstName.startsWith(cleanQ) ||
        normInstName.contains(' $cleanQ') ||
        instTokens.any((t) => t == cleanQ || t.startsWith(cleanQ));

    final bool hasDirectPhrase = cleanQ.length >= 5 && normInstName.contains(cleanQ);

    final bool hasCoreMatch = coreTokens.isNotEmpty &&
        coreTokens.any((ct) => instTokens.any((it) =>
            it == ct ||
            (it.length >= 4 && ct.length >= 4 && (it.startsWith(ct) || ct.startsWith(it))) ||
            (_fuzzySynonyms[ct]?.contains(it) ?? false)));

    // Fast reject: eliminates unrelated entries (including short substring collisions like "industry" on "ust")
    if (!isKnownAcronym && !isDynamicAcronym && !hasWordBoundary && !hasDirectPhrase && !hasCoreMatch) {
      return (0.0, false);
    }

    double score = 0.0;
    bool isHighConfidence = false;

    // 1. Exact match
    if (normInstName == cleanQ) {
      score = 100.0;
      isHighConfidence = true;
    }
    // 2. Known medical acronym (e.g. "ust" -> "University of Santo Tomas Hospital", "slmc" -> "St Luke's")
    else if (isKnownAcronym) {
      score = 96.0;
      isHighConfidence = true;
    }
    // 3. Dynamic exact acronym match (e.g. "ust" from "University of Santo Tomas Hospital")
    else if (isAcronymCandidate && instAcronyms.contains(cleanQ)) {
      score = 94.0;
      isHighConfidence = true;
    }
    // 4. Starts with query (prefix phrase match)
    else if (normInstName.startsWith(cleanQ)) {
      score = 92.0;
      if (cleanQ.length >= 4) isHighConfidence = true;
    }
    // 5. Whole word phrase match
    else if (normInstName.contains(' $cleanQ ') || normInstName.endsWith(' $cleanQ')) {
      score = 88.0;
      if (cleanQ.length >= 5) isHighConfidence = true;
    }
    // 6. Word prefix match (e.g. "metrop" matches "metropolitan")
    else if (instTokens.any((t) => t.startsWith(cleanQ))) {
      score = 85.0;
      if (cleanQ.length >= 6) isHighConfidence = true;
    }
    // 7. Dynamic acronym prefix match
    else if (isAcronymCandidate && instAcronyms.any((a) => a.startsWith(cleanQ))) {
      score = 82.0;
    }
    // 8. Substring match for longer queries only (>= 5 chars)
    else if (cleanQ.length >= 5 && normInstName.contains(cleanQ)) {
      score = 80.0;
      if (cleanQ.length >= 8) isHighConfidence = true;
    }

    // 9. Distinctive core token overlap
    if (score < 80.0 && coreTokens.isNotEmpty) {
      int matchedCore = 0;
      for (var ct in coreTokens) {
        if (instTokens.any((it) =>
            it == ct ||
            (it.length >= 4 && ct.length >= 4 && (it.startsWith(ct) || ct.startsWith(it))) ||
            (ct.length >= 4 && isSoundAlikeMatch(ct, it)) ||
            (_fuzzySynonyms[ct]?.contains(it) ?? false))) {
          matchedCore++;
        }
      }

      if (coreTokens.length == 1) {
        if (matchedCore == 1 && coreTokens.first.length >= 4) {
          score = 75.0;
        }
      } else if (coreTokens.length >= 2) {
        final ratio = matchedCore / coreTokens.length;
        if (ratio >= 0.5) {
          final tokenScore = 70.0 + (ratio * 25.0);
          if (tokenScore > score) {
            score = tokenScore;
            if (ratio == 1.0 && coreTokens.length >= 2) {
              isHighConfidence = true;
            }
          }
        }
      }
    }

    return score >= 65.0 ? (score, isHighConfidence) : (0.0, false);
  }

  /// Smart predictive directory search with duplicate detection and PSGC location embedding.
  /// Detects if an institution is already present in the directory (exact match, token overlap, or acronym).
  static List<InstitutionSearchResult> searchDirectoryWithDuplicateDetection(
    String rawQuery,
    Iterable<Institution> allInstitutions, {
    int limit = 50,
  }) {
    final cleanQ = rawQuery
        .replaceAll("'", "")
        .replaceAll("’", "")
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanQ.length < 2) return [];

    final qTokens = cleanQ.split(' ').where((t) => t.isNotEmpty && t.length > 1).toList();
    if (qTokens.isEmpty) return [];

    const stopWords = {
      'hospital', 'medical', 'center', 'clinic', 'inc', 'corporation', 'corp',
      'phils', 'philippines', 'dr', 'san', 'sta', 'saint', 'of', 'and', 'the',
      'care', 'health', 'foundation', 'memorial', 'general', 'community',
      'district', 'city', 'provincial', 'lying', 'in', 'diagnostic',
    };

    final coreTokens = <String>[];
    for (var t in qTokens) {
      if (!stopWords.contains(t) && t.length > 2) {
        coreTokens.add(t);
        if (t.endsWith('s') && t.length > 3) {
          coreTokens.add(t.substring(0, t.length - 1));
        }
      }
    }

    final isAcronymCandidate = cleanQ.length >= 2 && cleanQ.length <= 5 && RegExp(r'^[a-z]+$').hasMatch(cleanQ);

    final List<InstitutionSearchResult> results = [];
    final Set<String> seenIds = {};

    for (var inst in allInstitutions) {
      if (inst.institutionName.isEmpty && inst.name.isEmpty) continue;
      final instId = inst.name;
      if (seenIds.contains(instId)) continue;

      final instName = inst.institutionName.isNotEmpty ? inst.institutionName : inst.name;
      final normInstName = instName
          .replaceAll("'", "")
          .replaceAll("’", "")
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final instTokens = normInstName.split(' ').where((t) => t.isNotEmpty).toList();
      final instAcronyms = computeInstitutionAcronyms(instName);

      final (score, isHighConfidence) = _scoreInstitutionCandidate(
        cleanQ: cleanQ,
        qTokens: qTokens,
        coreTokens: coreTokens,
        isAcronymCandidate: isAcronymCandidate,
        rawInstName: instName,
        normInstName: normInstName,
        instTokens: instTokens,
        instAcronyms: instAcronyms,
      );

      if (score >= 65.0) {
        seenIds.add(instId);
        final locStr = formatLocation(
          streetAddress: inst.streetAddress,
          cityMunicipality: inst.cityMunicipality,
          provinceName: inst.provinceName,
          regionName: inst.regionName,
        );

        results.add(InstitutionSearchResult(
          institution: inst,
          isExactOrHighConfidenceDuplicate: isHighConfidence,
          matchScore: score,
          formattedLocation: locStr,
        ));
      }
    }

    // Also search baseline static institutions if not already matched
    for (var entry in _staticInstitutions.entries) {
      if (seenIds.contains(entry.key)) continue;

      final instName = entry.value;
      final normInstName = instName
          .replaceAll("'", "")
          .replaceAll("’", "")
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final instTokens = normInstName.split(' ').where((t) => t.isNotEmpty).toList();
      final instAcronyms = computeInstitutionAcronyms(instName);

      final (score, isHighConfidence) = _scoreInstitutionCandidate(
        cleanQ: cleanQ,
        qTokens: qTokens,
        coreTokens: coreTokens,
        isAcronymCandidate: isAcronymCandidate,
        rawInstName: instName,
        normInstName: normInstName,
        instTokens: instTokens,
        instAcronyms: instAcronyms,
      );

      if (score >= 65.0) {
        seenIds.add(entry.key);
        results.add(InstitutionSearchResult(
          institution: Institution(
            name: entry.key,
            institutionName: entry.value,
            workflowState: 'Approved',
          ),
          isExactOrHighConfidenceDuplicate: isHighConfidence,
          matchScore: score,
          formattedLocation: '',
        ));
      }
    }

    results.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return results.take(limit).toList();
  }

  static const Map<String, List<String>> _fuzzySynonyms = {
    'st': ['saint', 'ste', 'st.', 'santo', 'sta', 'sto', 'san'],
    'saint': ['st', 'ste', 'santo', 'sta', 'sto', 'san'],
    'santo': ['sto', 'st', 'saint', 'thomas', 'tomas'],
    'santa': ['sta', 'st', 'saint'],
    'sto': ['santo', 'saint', 'st'],
    'sta': ['santa', 'saint', 'st'],
    'san': ['saint', 'st', 'santo'],
    'dr': ['doctor', 'doctors', 'doc', 'docs', 'dr.'],
    'doctor': ['dr', 'doc', 'docs', 'doctors'],
    'doctors': ['dr', 'doc', 'docs', 'doctor'],
    'doc': ['doctor', 'doctors', 'dr', 'docs'],
    'docs': ['doctor', 'doctors', 'dr', 'doc'],
    'med': ['medical', 'medicine'],
    'medical': ['med', 'medicine'],
    'medicine': ['med', 'medical'],
    'ctr': ['center', 'centre'],
    'center': ['ctr', 'centre', 'centers'],
    'lourdes': ['lordes', 'lourds', 'lady'],
    'lordes': ['lourdes', 'lourds', 'lady'],
    'cardinal': ['kardinal', 'cardynal', 'csmc'],
    'kardinal': ['cardinal', 'cardynal', 'csmc'],
    'tomas': ['thomas', 'ust'],
    'thomas': ['tomas', 'ust'],
    'chinese': ['chines', 'chynese', 'china', 'cgh'],
    'chines': ['chinese', 'chynese', 'cgh'],
    'lukes': ['luke', 'lucas', 'slmc'],
    'luke': ['lukes', 'lucas', 'slmc'],
    'asian': ['asiya', 'alabang'],
    'perpetual': ['perpetuel', 'succor'],
    'succor': ['succour', 'socorro', 'perpetual'],
    'providence': ['probidens'],
    'probidens': ['providence'],
    'makati': ['makaty', 'mmc'],
    'makaty': ['makati', 'mmc'],
    'metropolitan': ['metropolytan', 'metro', 'mmc'],
    'filipino': ['philippine', 'phil', 'pgh'],
    'philipine': ['philippine', 'phil', 'pgh'],
    'chiles': ['child', 'children', 'chile', 'chyles'],
    'chile': ['chiles', 'child'],
    'clinica': ['clinic', 'clnc'],
    'clnc': ['clinic', 'clinica'],
    'cgh': ['chinese', 'general', 'hospital'],
    'hosp': ['hospital'],
    'hospital': ['hosp', 'hospitals'],
    'hospitals': ['hosp', 'hospital'],
    'gen': ['general'],
    'general': ['gen'],
    'cln': ['clinic'],
    'clinic': ['cln', 'clnc', 'clinics', 'clinica'],
    'clinics': ['cln', 'clinic'],
    'mem': ['memorial'],
    'memorial': ['mem'],
    'natl': ['national'],
    'national': ['natl'],
    'univ': ['university'],
    'university': ['univ'],
    'fdn': ['foundation', 'fndn'],
    'foundation': ['fdn', 'fndn'],
    'inst': ['institute'],
    'institute': ['inst', 'institutes'],
    'delos': ['de', 'los'],
    'bgc': ['bonifacio', 'global', 'taguig'],
    'global': ['bgc', 'bonifacio'],
    'qc': ['quezon'],
    'quezon': ['qc'],
    'ncr': ['metro', 'manila'],
    'manila': ['ncr', 'metro'],
    'pgh': ['philippine', 'general', 'hospital'],
    'slmc': ['st', 'lukes', 'medical', 'center'],
    'mmc': ['makati', 'medical', 'center'],
    'mdh': ['manila', 'doctors', 'hospital'],
    'ust': ['university', 'santo', 'tomas'],
    'tmc': ['the', 'medical', 'city'],
    'csmc': ['cardinal', 'santos', 'medical', 'center'],
    'nkti': ['national', 'kidney', 'transplant', 'institute'],
    'vmmc': ['veterans', 'memorial', 'medical', 'center'],
    'pcmc': ['philippine', 'childrens', 'medical', 'center'],
    'eamc': ['east', 'avenue', 'medical', 'center'],
    'dls': ['de', 'la', 'salle'],
    'dlsumc': ['de', 'la', 'salle', 'university', 'medical', 'center'],
    'phc': ['philippine', 'heart', 'center'],
    'lcp': ['lung', 'center', 'philippines'],
    'poc': ['philippine', 'orthopedic', 'center'],
    'philippine': ['philippines', 'phil', 'pgh', 'phc', 'pcmc', 'poc', 'filipino'],
    'philippines': ['philippine', 'phil', 'pgh', 'phc', 'pcmc', 'lcp', 'poc', 'filipino'],
    'phil': ['philippine', 'philippines', 'pgh', 'phc', 'pcmc', 'filipino'],
    'children': ['childrens', 'pediatric', 'pedia'],
    'childrens': ['children', 'pediatric', 'pedia'],
    'heart': ['cardio', 'cardiac', 'phc'],
    'lung': ['pulmo', 'pulmonary', 'lcp'],
    'kidney': ['renal', 'nephro', 'nkti'],
    'orthopedic': ['ortho', 'poc'],
  };

  /// Generates a 4-character phonetic Soundex code for sound-alike comparison.
  /// Normalizes English & Filipino phonetic variations (e.g. PH/F, C/K/S, Z/S, V/B).
  static String soundex(String s) {
    if (s.isEmpty) return '';
    final lower = s.toLowerCase().replaceAll("'", "").replaceAll("’", "").trim();
    final normalized = lower
        .replaceAll('ph', 'f')
        .replaceAll('ck', 'k')
        .replaceAll('qu', 'k')
        .replaceAll('ch', 'k')
        .replaceAll('th', 't')
        .replaceAll('dg', 'j')
        .replaceAll('gh', 'g')
        .replaceAll(RegExp(r'[^a-z]'), '');
    if (normalized.isEmpty) return '';

    // Normalize initial phonetic character (Hard C -> K, Soft C -> S, V -> B, Z -> S)
    String initial = normalized[0];
    if (initial == 'c') {
      if (normalized.length > 1 && (normalized[1] == 'e' || normalized[1] == 'i' || normalized[1] == 'y')) {
        initial = 's';
      } else {
        initial = 'k';
      }
    } else if (initial == 'v') {
      initial = 'b';
    } else if (initial == 'z') {
      initial = 's';
    }

    final firstLetter = initial.toUpperCase();
    final buffer = StringBuffer(firstLetter);

    String lastCode = _soundexCode(initial);
    for (int i = 1; i < normalized.length && buffer.length < 4; i++) {
      final code = _soundexCode(normalized[i]);
      if (code != '0' && code != lastCode) {
        buffer.write(code);
      }
      lastCode = code;
    }
    while (buffer.length < 4) {
      buffer.write('0');
    }
    return buffer.toString();
  }

  static String _soundexCode(String char) {
    switch (char) {
      case 'b':
      case 'f':
      case 'p':
      case 'v':
        return '1';
      case 'c':
      case 'g':
      case 'j':
      case 'k':
      case 'q':
      case 's':
      case 'x':
      case 'z':
        return '2';
      case 'd':
      case 't':
        return '3';
      case 'l':
        return '4';
      case 'm':
      case 'n':
        return '5';
      case 'r':
        return '6';
      default:
        return '0';
    }
  }

  /// Fast Damerau-Levenshtein edit distance for typo tolerance and sound-alike spelling.
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        final cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((min, val) => val < min ? val : min);
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[s2.length];
  }

  /// Checks whether two tokens sound alike or have high phonetic/spelling similarity.
  static bool isSoundAlikeMatch(String t1, String t2) {
    if (t1 == t2) return true;
    if (t1.isEmpty || t2.isEmpty) return false;

    // Direct Soundex comparison
    final s1 = soundex(t1);
    final s2 = soundex(t2);
    if (s1.isNotEmpty && s1 == s2) return true;

    // Levenshtein edit distance for small typos and phonetic spelling
    final maxLen = t1.length > t2.length ? t1.length : t2.length;
    final minLen = t1.length < t2.length ? t1.length : t2.length;
    if (minLen >= 3 && (maxLen - minLen <= 2)) {
      final dist = levenshteinDistance(t1, t2);
      if (dist <= 1) return true;
      if (minLen >= 5 && dist <= 2) return true;
    }
    return false;
  }

  /// Advanced multi-clue fuzzy search for institution dropdowns and selection pickers.
  /// 
  /// Guarantees that any potential clue of any word of that particular institution
  /// is matched and included in the dropdown list (not filterized or excluded prematurely),
  /// while ranking results by multi-clue relevance score with heavy prefix prioritization,
  /// sound-alike phonetic matching, and same-phrase permutation matching.
  static List<Institution> fuzzySearchInstitutions(
    String rawQuery,
    Iterable<Institution> allInstitutions, {
    int? limit,
  }) {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) {
      final list = allInstitutions.toList();
      return limit != null && limit > 0 ? list.take(limit).toList() : list;
    }

    final cleanQ = trimmed
        .replaceAll("'", "")
        .replaceAll("’", "")
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final qTokens = cleanQ.split(' ').where((t) => t.isNotEmpty).toList();
    if (qTokens.isEmpty) {
      final list = allInstitutions.toList();
      return limit != null && limit > 0 ? list.take(limit).toList() : list;
    }

    final List<_ScoredInstitutionItem> scoredList = [];

    for (final inst in allInstitutions) {
      final instName = inst.institutionName.isNotEmpty ? inst.institutionName : inst.name;
      final instNameClean = instName
          .replaceAll("'", "")
          .replaceAll("’", "")
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final locStr = [
        inst.streetAddress ?? '',
        inst.barangayName ?? '',
        inst.cityMunicipality ?? inst.rawCityMunicipality ?? '',
        inst.provinceName ?? inst.rawProvinceName ?? '',
        inst.regionName ?? inst.rawRegionName ?? '',
      ].join(' ');

      final locClean = locStr
          .replaceAll("'", "")
          .replaceAll("’", "")
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final combinedClean = '${inst.name.toLowerCase()} $instNameClean $locClean';
      final nameTokens = instNameClean.split(' ').where((t) => t.isNotEmpty).toList();
      final locTokens = locClean.split(' ').where((t) => t.isNotEmpty).toSet();
      final acronym = nameTokens.where((t) => t.isNotEmpty).map((t) => t[0]).join();

      double score = 0.0;
      int tokensMatched = 0;
      int nameTokensMatched = 0;

      // 1. Exact phrase matches, Prefix matching, and Sound-Alike (Highest Tier - Appears readily at top of dropdown)
      if (instNameClean == cleanQ) {
        score += 3500.0;
      } else if (instNameClean.startsWith(cleanQ)) {
        // Entire institution name starts with query (e.g. "Philippine General Hospital", "Philippine Heart Center" when searching "Philippine")
        score += 3000.0;
      } else if (nameTokens.isNotEmpty && (nameTokens[0] == cleanQ || nameTokens[0].startsWith(cleanQ))) {
        // First word starts with query
        score += 2600.0;
      } else if (nameTokens.any((nt) => nt == cleanQ)) {
        // A whole word in institution name matches query exactly
        score += 2000.0;
      } else if (nameTokens.any((nt) => isSoundAlikeMatch(cleanQ, nt))) {
        // A whole word in institution name sounds like the query (e.g. "lordes" -> "lourdes", "kardinal" -> "cardinal", "makaty" -> "makati", "chines" -> "chinese")
        score += 2400.0;
      } else if (nameTokens.any((nt) => nt.startsWith(cleanQ))) {
        // A word in institution name starts with query
        score += 1600.0;
      } else if (instNameClean.contains(cleanQ)) {
        // Substring anywhere in name (e.g. "Lung Center of the Philippines")
        score += 1200.0;
      } else if (cleanQ.length >= 4 && (soundex(cleanQ).isNotEmpty && soundex(cleanQ) == soundex(instNameClean) || isSoundAlikeMatch(cleanQ, instNameClean))) {
        // Whole query sounds like entire institution name
        score += 3200.0;
      } else if (combinedClean.contains(cleanQ)) {
        // In location, address, or ID
        score += 800.0;
      }

      // 2. Acronym matching
      if (cleanQ.length >= 2 && cleanQ.length <= 6 && RegExp(r'^[a-z]+$').hasMatch(cleanQ)) {
        if (cleanQ == acronym) {
          score += 1800.0;
        } else if (acronym.startsWith(cleanQ)) {
          score += 1200.0;
        }
      }

      // 3. Multi-token clue evaluation (Inclusive retention: any potential clue matches)
      for (final qt in qTokens) {
        bool tokenFound = false;
        bool isNameMatch = false;
        final syns = _fuzzySynonyms[qt];
        final expanded = [qt, ...?syns];
        // Stemming: also add stripped 's' or 'es'
        if (qt.endsWith('s') && qt.length > 3) {
          expanded.add(qt.substring(0, qt.length - 1));
        }
        if (qt.endsWith('es') && qt.length > 4) {
          expanded.add(qt.substring(0, qt.length - 2));
        }

        // A. Match against institution name tokens (bidirectional token & prefix matching & sound-alike)
        for (final nt in nameTokens) {
          final ntStem = (nt.endsWith('s') && nt.length > 3) ? nt.substring(0, nt.length - 1) : nt;
          if (expanded.any((exp) => exp == nt || exp == ntStem)) {
            score += 300.0;
            tokenFound = true;
            isNameMatch = true;
            break;
          } else if (expanded.any((exp) => isSoundAlikeMatch(exp, nt))) {
            // Sound-alike token match (e.g. "lordes" -> "lourdes", "kardinal" -> "cardinal")
            score += 280.0;
            tokenFound = true;
            isNameMatch = true;
            break;
          } else if (expanded.any((exp) => (exp.length >= 2 && nt.startsWith(exp)) || (nt.length >= 2 && exp.startsWith(nt)))) {
            score += 200.0;
            tokenFound = true;
            isNameMatch = true;
            break;
          } else if (expanded.any((exp) => (exp.length >= 3 && nt.contains(exp)) || (nt.length >= 3 && exp.contains(nt)))) {
            score += 120.0;
            tokenFound = true;
            isNameMatch = true;
            break;
          }
        }

        // B. Compound names (e.g. "delos" matching "de" + "los")
        if (!tokenFound && qt == 'delos' && nameTokens.contains('de') && nameTokens.contains('los')) {
          score += 250.0;
          tokenFound = true;
          isNameMatch = true;
        }

        // C. Match against location tokens (city, municipality, province, street)
        if (!tokenFound) {
          for (final exp in expanded) {
            if (locTokens.contains(exp)) {
              score += 100.0;
              tokenFound = true;
              break;
            } else if (locTokens.any((lt) => isSoundAlikeMatch(exp, lt))) {
              score += 90.0;
              tokenFound = true;
              break;
            } else if (locTokens.any((lt) => (exp.length >= 2 && lt.startsWith(exp)) || (lt.length >= 2 && exp.startsWith(lt)))) {
              score += 80.0;
              tokenFound = true;
              break;
            } else if (exp.length >= 3 && locClean.contains(exp)) {
              score += 60.0;
              tokenFound = true;
              break;
            }
          }
        }

        // D. Match against Institution ID (e.g. "INST-00123" or "00123")
        if (!tokenFound && (qt.startsWith('inst') || RegExp(r'^\d+$').hasMatch(qt))) {
          if (inst.name.toLowerCase().contains(qt)) {
            score += 150.0;
            tokenFound = true;
          }
        }

        if (tokenFound) {
          tokensMatched++;
          if (isNameMatch) {
            nameTokensMatched++;
          }
        }
      }

      // 4. Same Phrase & Multi-token synergy bonus
      if (qTokens.length > 1) {
        // SAME PHRASE MATCH: When 100% of query tokens match institution name tokens in any order
        // (e.g. "Doctors Manila" or "Manila Doctors", "General Chinese", "St Lukes BGC", "Lourdes Lady")
        if (nameTokensMatched == qTokens.length) {
          score += 3200.0; // Massive Same-Phrase Priority Boost so it immediately appears readily at the top!
          if (nameTokens.length == qTokens.length) {
            score += 500.0; // Exact permutation bonus
          }
        } else if (tokensMatched == qTokens.length) {
          score += 600.0; // All tokens matched across name + location
        } else if (tokensMatched > 0) {
          score += (tokensMatched / qTokens.length) * 250.0;
        }
      }

      // Inclusion rule: any potential clue matches keeps it in the dropdown list (never filterized out)!
      if (score > 0.0 || tokensMatched > 0) {
        scoredList.add(_ScoredInstitutionItem(inst, score));
      }
    }

    // 5. Fallback typo tolerance & sound-alike: if no tokens matched at all, check phonetic and subsequence
    if (scoredList.isEmpty && cleanQ.length >= 3) {
      for (final inst in allInstitutions) {
        final instName = inst.institutionName.isNotEmpty ? inst.institutionName : inst.name;
        final instLower = instName.toLowerCase();
        if (isSoundAlikeMatch(cleanQ, instLower)) {
          scoredList.add(_ScoredInstitutionItem(inst, 100.0));
        } else if (_hasSubsequenceMatch(cleanQ, instLower)) {
          scoredList.add(_ScoredInstitutionItem(inst, 15.0));
        }
      }
    }

    // Sort descending by relevance score; on tie, sort alphabetically A-Z by institutionName
    scoredList.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.institution.institutionName.toLowerCase().compareTo(b.institution.institutionName.toLowerCase());
    });

    final results = scoredList.map((e) => e.institution);
    return limit != null && limit > 0 ? results.take(limit).toList() : results.toList();
  }

  static bool _hasSubsequenceMatch(String query, String target) {
    if (query.isEmpty || target.isEmpty) return false;
    int qIdx = 0;
    for (int tIdx = 0; tIdx < target.length && qIdx < query.length; tIdx++) {
      if (target[tIdx] == query[qIdx]) {
        qIdx++;
      }
    }
    return qIdx == query.length;
  }


  /// Resolve a Province name (e.g. "Metro Manila", "Bulacan") to its ERPNext Link ID / PSGC Code
  static String resolveProvinceId(String? raw, [List<PsgcLocation>? dynamicLocations]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '';
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();

    // 1. Check dynamic locations from ERPNext
    if (dynamicLocations != null && dynamicLocations.isNotEmpty) {
      final match = dynamicLocations.firstWhere(
        (loc) => loc.locationLabel.toLowerCase() == lower ||
                 loc.name.toLowerCase() == lower ||
                 (loc.psgcCode != null && loc.psgcCode == trimmed),
        orElse: () => PsgcLocation(name: '', locationLabel: '', locationType: ''),
      );
      if (match.name.isNotEmpty) return match.name;
    }

    // 2. Check in-memory registered PSGC locations
    for (var entry in _dynamicPsgcLocations.entries) {
      if (entry.value.toLowerCase() == lower || entry.key.toLowerCase() == lower) {
        return entry.key;
      }
    }

    // 3. Known ERPNext Province aliases
    if (lower == 'metro manila' || lower == 'ncr' || lower == 'national capital region' || lower == 'metro manila-manila' || lower == 'manila') {
      return '1380600000';
    }
    if (lower == 'metro manila-makati' || lower == 'makati') {
      return '1380300000';
    }
    if (lower == 'metro manila-pasig' || lower == 'pasig') {
      return '1381200000';
    }
    if (lower == 'metro manila-quezon city' || lower == 'quezon city' || lower == 'qc') {
      return '1381300000';
    }
    if (lower == 'metro manila-taguig' || lower == 'taguig') {
      return '1381500000';
    }
    if (lower == 'metro manila-mandaluyong' || lower == 'mandaluyong') {
      return '1380500000';
    }
    if (lower == 'metro manila-marikina' || lower == 'marikina') {
      return '1380700000';
    }
    if (lower == 'metro manila-pasay' || lower == 'pasay') {
      return '1381100000';
    }
    if (lower == 'metro manila-paranaque' || lower == 'metro manila-parañaque' || lower == 'paranaque' || lower == 'parañaque') {
      return '1381000000';
    }
    if (lower == 'metro manila-las pinas' || lower == 'metro manila-las piñas' || lower == 'las pinas' || lower == 'las piñas') {
      return '1380200000';
    }
    if (lower == 'metro manila-muntinlupa' || lower == 'muntinlupa') {
      return '1380800000';
    }
    if (lower == 'metro manila-caloocan' || lower == 'caloocan') {
      return '1380100000';
    }
    if (lower == 'metro manila-malabon' || lower == 'malabon') {
      return '1380400000';
    }
    if (lower == 'metro manila-navotas' || lower == 'navotas') {
      return '1380900000';
    }
    if (lower == 'metro manila-valenzuela' || lower == 'valenzuela') {
      return '1381600000';
    }
    if (lower == 'metro manila-san juan' || lower == 'san juan') {
      return '1381400000';
    }
    if (lower == 'metro manila-pateros' || lower == 'pateros') {
      return '1381701000';
    }

    // 4. Check standard provinces list
    for (var p in standardProvinces) {
      final pNameLower = p.name.toLowerCase();
      if (pNameLower == lower || p.code == trimmed || pNameLower.contains(lower) || lower.contains(pNameLower)) {
        return p.code;
      }
    }

    // If it's already a numeric PSGC code
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return trimmed;
    }

    return trimmed;
  }

  /// Resolve a City/Municipality name (e.g. "Ermita", "Manila City") to its ERPNext Link ID / PSGC Code
  static String resolveCityId(String? raw, [List<PsgcLocation>? dynamicLocations]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '';
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();

    // 1. Check dynamic locations from ERPNext
    if (dynamicLocations != null && dynamicLocations.isNotEmpty) {
      final match = dynamicLocations.firstWhere(
        (loc) => loc.locationLabel.toLowerCase() == lower ||
                 loc.name.toLowerCase() == lower ||
                 (loc.psgcCode != null && loc.psgcCode == trimmed),
        orElse: () => PsgcLocation(name: '', locationLabel: '', locationType: ''),
      );
      if (match.name.isNotEmpty) return match.name;
    }

    // 2. Check in-memory registered PSGC locations
    for (var entry in _dynamicPsgcLocations.entries) {
      if (entry.value.toLowerCase() == lower || entry.key.toLowerCase() == lower) {
        return entry.key;
      }
    }

    // 3. Known ERPNext City / District aliases
    if (lower == 'ermita') {
      return '1380608000';
    }
    if (lower == 'malate') {
      return '1380610000';
    }
    if (lower == 'intramuros') {
      return '1380609000';
    }
    if (lower == 'tondo') {
      return '1380601000';
    }
    if (lower == 'binondo') {
      return '1380602000';
    }
    if (lower == 'quiapo') {
      return '1380603000';
    }
    if (lower == 'san nicolas') {
      return '1380604000';
    }
    if (lower == 'santa cruz' || lower == 'sta cruz') {
      return '1380605000';
    }
    if (lower == 'sampaloc') {
      return '1380606000';
    }
    if (lower == 'san miguel') {
      return '1380607000';
    }
    if (lower == 'paco') {
      return '1380611000';
    }
    if (lower == 'pandacan') {
      return '1380612000';
    }
    if (lower == 'port area') {
      return '1380613000';
    }
    if (lower == 'santa ana' || lower == 'sta ana') {
      return '1380614000';
    }
    if (lower == 'city of manila' || lower == 'manila city' || lower == 'manila') {
      return '1380600000';
    }
    if (lower == 'makati' || lower == 'makati city') {
      return '1380300000';
    }
    if (lower == 'quezon city' || lower == 'qc') {
      return '1381300000';
    }
    if (lower == 'pasig' || lower == 'pasig city') {
      return '1381200000';
    }
    if (lower == 'taguig' || lower == 'taguig city' || lower == 'bgc' || lower == 'bonifacio global city') {
      return '1381500000';
    }
    if (lower == 'mandaluyong' || lower == 'mandaluyong city') {
      return '1380500000';
    }
    if (lower == 'marikina' || lower == 'marikina city') {
      return '1380700000';
    }
    if (lower == 'pasay' || lower == 'pasay city') {
      return '1381100000';
    }
    if (lower == 'paranaque' || lower == 'parañaque' || lower == 'paranaque city') {
      return '1381000000';
    }
    if (lower == 'las pinas' || lower == 'las piñas' || lower == 'las pinas city') {
      return '1380200000';
    }
    if (lower == 'muntinlupa' || lower == 'muntinlupa city') {
      return '1380800000';
    }
    if (lower == 'caloocan' || lower == 'caloocan city') {
      return '1380100000';
    }
    if (lower == 'malabon' || lower == 'malabon city') {
      return '1380400000';
    }
    if (lower == 'navotas' || lower == 'navotas city') {
      return '1380900000';
    }
    if (lower == 'valenzuela' || lower == 'valenzuela city') {
      return '1381600000';
    }
    if (lower == 'san juan' || lower == 'san juan city') {
      return '1381400000';
    }
    if (lower == 'pateros') {
      return '1381701000';
    }

    // 4. Standard cities list
    for (var c in standardCities) {
      final cNameLower = c.name.toLowerCase();
      if (cNameLower == lower || c.code == trimmed || cNameLower.startsWith(lower) || lower.startsWith(cNameLower)) {
        return c.code;
      }
    }

    // If it's already a numeric PSGC code
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return trimmed;
    }

    return trimmed;
  }

  /// Resolve a Region name to its ERPNext Link ID / PSGC Code
  static String resolveRegionId(String? raw, [List<PsgcLocation>? dynamicLocations]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '';
    final trimmed = raw.trim();
    if (RegExp(r'^\d{10}$').hasMatch(trimmed)) return trimmed;

    if (dynamicLocations != null && dynamicLocations.isNotEmpty) {
      final match = dynamicLocations.firstWhere(
        (loc) => loc.locationLabel.toLowerCase() == trimmed.toLowerCase() || loc.name.toLowerCase() == trimmed.toLowerCase(),
        orElse: () => PsgcLocation(name: '', locationLabel: '', locationType: ''),
      );
      if (match.name.isNotEmpty) return match.name;
    }

    for (var r in standardRegions) {
      if (r.name.toLowerCase() == trimmed.toLowerCase() || r.code == trimmed) {
        return r.code;
      }
      if (trimmed.length > 2 && r.name.toLowerCase().contains(trimmed.toLowerCase())) {
        return r.code;
      }
    }

    return trimmed;
  }

  /// Automatically derive Region name from a Province name or PSGC code
  static String resolveRegionFromProvince(String? provinceNameOrCode) {
    if (provinceNameOrCode == null || provinceNameOrCode.trim().isEmpty) return '';
    _ensurePsgcSynchronousFallback();
    final trimmed = provinceNameOrCode.trim();

    // Check direct parent mapping
    if (_provinceToRegionMap.containsKey(trimmed.toLowerCase())) {
      return _provinceToRegionMap[trimmed.toLowerCase()]!.locationLabel;
    }
    final provId = resolveProvinceId(trimmed);
    if (_provinceToRegionMap.containsKey(provId)) {
      return _provinceToRegionMap[provId]!.locationLabel;
    }

    // Special case for Metro Manila
    if (trimmed.toLowerCase().contains('metro manila') || provId.startsWith('13')) {
      final ncr = _psgcRegions.where((r) => r.name == '1300000000').firstOrNull;
      if (ncr != null) return ncr.locationLabel;
      return 'NCR';
    }

    if (provId.length >= 2) {
      final regPrefix = provId.substring(0, 2);
      for (var r in _psgcRegions) {
        if (r.name.startsWith(regPrefix)) {
          return r.locationLabel;
        }
      }
      for (var r in standardRegions) {
        if (r.code.startsWith(regPrefix)) {
          return r.name;
        }
      }
    }
    return '';
  }

  /// Comprehensively resolves all workplace location fields (Workplace, Region, Province, City)
  /// ensuring that NONE of them are EVER empty during HCP Profiling submissions.
  /// 
  /// Automatically resolves missing provinces/cities from PSGC geographic hierarchy,
  /// institution address keywords, or regional defaults.
  static ResolvedWorkplaceLocation resolveCompleteWorkplaceLocation({
    String? workplaceNameOrId,
    String? institutionIdOrName,
    String? institutionName,
    String? rawRegion,
    String? regionIdOrName,
    String? rawProvince,
    String? provinceIdOrName,
    String? rawCity,
    String? cityIdOrName,
    String? streetAddress,
    Iterable<Institution>? institutions,
    List<PsgcLocation>? dynamicLocations,
  }) {
    Institution? instMatch;
    final wpInput = (workplaceNameOrId ?? institutionIdOrName ?? institutionName ?? '').trim();
    if (wpInput.isNotEmpty) {
      final pool = institutions ?? _dynamicInstitutions.entries.map((e) => Institution(name: e.key, institutionName: e.value));
      instMatch = pool.where((i) =>
          i.name.toLowerCase() == wpInput.toLowerCase() ||
          i.institutionName.toLowerCase() == wpInput.toLowerCase()
      ).firstOrNull;
    }

    final effWpName = (institutionName != null && institutionName.trim().isNotEmpty)
        ? institutionName.trim()
        : ((instMatch != null && instMatch.institutionName.isNotEmpty)
            ? instMatch.institutionName
            : resolveInstitutionName(wpInput, institutions?.toList()));
    final effWpId = (instMatch != null && instMatch.name.isNotEmpty)
        ? instMatch.name
        : resolveInstitutionId(wpInput, institutions?.toList());
    final finalWpName = effWpName.isNotEmpty ? effWpName : (wpInput.isNotEmpty ? wpInput : 'Workplace');
    final finalWpId = effWpId.isNotEmpty ? effWpId : (wpInput.isNotEmpty ? wpInput : 'INST-00001');

    final givenCity = (cityIdOrName != null && cityIdOrName.trim().isNotEmpty && cityIdOrName.trim() != '-')
        ? cityIdOrName.trim()
        : ((rawCity != null && rawCity.trim().isNotEmpty && rawCity.trim() != '-') ? rawCity.trim() : '');
    final instCity = (instMatch?.rawCityMunicipality ?? instMatch?.cityMunicipality ?? '').trim();
    String candCity = givenCity.isNotEmpty ? givenCity : (instCity.isNotEmpty && instCity != '-' ? instCity : '');

    final givenProv = (provinceIdOrName != null && provinceIdOrName.trim().isNotEmpty && provinceIdOrName.trim() != '-')
        ? provinceIdOrName.trim()
        : ((rawProvince != null && rawProvince.trim().isNotEmpty && rawProvince.trim() != '-') ? rawProvince.trim() : '');
    final instProv = (instMatch?.rawProvinceName ?? instMatch?.provinceName ?? '').trim();
    String candProv = givenProv.isNotEmpty ? givenProv : (instProv.isNotEmpty && instProv != '-' ? instProv : '');

    final givenReg = (regionIdOrName != null && regionIdOrName.trim().isNotEmpty && regionIdOrName.trim() != '-')
        ? regionIdOrName.trim()
        : ((rawRegion != null && rawRegion.trim().isNotEmpty && rawRegion.trim() != '-') ? rawRegion.trim() : '');
    final instReg = (instMatch?.rawRegionName ?? instMatch?.regionName ?? '').trim();
    String candReg = givenReg.isNotEmpty ? givenReg : (instReg.isNotEmpty && instReg != '-' ? instReg : '');

    final combinedLocText = '$finalWpName ${instMatch?.streetAddress ?? ''} ${streetAddress ?? ''}'.toLowerCase();

    // 1. Infer City if empty
    if (candCity.isEmpty) {
      if (combinedLocText.contains('taguig') || combinedLocText.contains('bgc') || combinedLocText.contains('bonifacio') || combinedLocText.contains('global city')) {
        candCity = 'Taguig';
      } else if (combinedLocText.contains('makati') || combinedLocText.contains('ayala') || combinedLocText.contains('legaspi') || combinedLocText.contains('salcedo')) {
        candCity = 'Makati';
      } else if (combinedLocText.contains('quezon city') || combinedLocText.contains('qc') || combinedLocText.contains('east ave') || combinedLocText.contains('quezon ave') || combinedLocText.contains('diliman') || combinedLocText.contains('cubao')) {
        candCity = 'Quezon City';
      } else if (combinedLocText.contains('pasig') || combinedLocText.contains('ortigas')) {
        candCity = 'Pasig';
      } else if (combinedLocText.contains('alabang') || combinedLocText.contains('muntinlupa') || combinedLocText.contains('filinvest')) {
        candCity = 'Muntinlupa';
      } else if (combinedLocText.contains('san juan') || combinedLocText.contains('greenhills')) {
        candCity = 'San Juan';
      } else if (combinedLocText.contains('mandaluyong') || combinedLocText.contains('shaw') || combinedLocText.contains('wack wack')) {
        candCity = 'Mandaluyong';
      } else if (combinedLocText.contains('manila') || combinedLocText.contains('ermita') || combinedLocText.contains('taft') || combinedLocText.contains('santa cruz') || combinedLocText.contains('sta cruz') || combinedLocText.contains('sampaloc') || combinedLocText.contains('binondo')) {
        candCity = 'Manila';
      } else if (combinedLocText.contains('marikina')) {
        candCity = 'Marikina';
      } else if (combinedLocText.contains('pasay') || combinedLocText.contains('roxas')) {
        candCity = 'Pasay';
      } else if (combinedLocText.contains('paranaque') || combinedLocText.contains('parañaque') || combinedLocText.contains('sucat') || combinedLocText.contains('bf homes')) {
        candCity = 'Parañaque';
      } else if (combinedLocText.contains('las pinas') || combinedLocText.contains('las piñas')) {
        candCity = 'Las Piñas';
      } else if (combinedLocText.contains('caloocan') || combinedLocText.contains('monumento')) {
        candCity = 'Caloocan';
      } else if (combinedLocText.contains('valenzuela')) {
        candCity = 'Valenzuela';
      } else if (combinedLocText.contains('malabon')) {
        candCity = 'Malabon';
      } else if (combinedLocText.contains('navotas')) {
        candCity = 'Navotas';
      } else if (combinedLocText.contains('pateros')) {
        candCity = 'Pateros';
      } else if (combinedLocText.contains('cebu')) {
        candCity = 'Cebu City';
      } else if (combinedLocText.contains('davao')) {
        candCity = 'Davao City';
      } else if (combinedLocText.contains('iloilo')) {
        candCity = 'Iloilo City';
      } else if (combinedLocText.contains('bacolod')) {
        candCity = 'Bacolod City';
      } else if (combinedLocText.contains('baguio')) {
        candCity = 'Baguio City';
      } else if (combinedLocText.contains('angeles')) {
        candCity = 'Angeles City';
      } else if (combinedLocText.contains('san fernando')) {
        candCity = 'City of San Fernando';
      } else if (combinedLocText.contains('cagayan de oro') || combinedLocText.contains('cdo')) {
        candCity = 'Cagayan de Oro City';
      } else if (combinedLocText.contains('general santos') || combinedLocText.contains('gensan')) {
        candCity = 'General Santos City';
      } else if (combinedLocText.contains('batangas')) {
        candCity = 'Batangas City';
      } else if (combinedLocText.contains('lipa')) {
        candCity = 'Lipa City';
      } else if (combinedLocText.contains('lucena')) {
        candCity = 'Lucena City';
      } else if (combinedLocText.contains('calamba')) {
        candCity = 'Calamba City';
      } else if (combinedLocText.contains('santa rosa') || combinedLocText.contains('sta rosa')) {
        candCity = 'City of Santa Rosa';
      } else if (combinedLocText.contains('binan') || combinedLocText.contains('biñan')) {
        candCity = 'City of Biñan';
      } else if (combinedLocText.contains('san pedro')) {
        candCity = 'City of San Pedro';
      } else if (combinedLocText.contains('cabuyao')) {
        candCity = 'City of Cabuyao';
      } else if (combinedLocText.contains('bacoor')) {
        candCity = 'City of Bacoor';
      } else if (combinedLocText.contains('imus')) {
        candCity = 'City of Imus';
      } else if (combinedLocText.contains('dasmarinas') || combinedLocText.contains('dasmariñas')) {
        candCity = 'City of Dasmariñas';
      } else if (combinedLocText.contains('general trias') || combinedLocText.contains('gen trias')) {
        candCity = 'City of General Trias';
      } else if (combinedLocText.contains('malolos')) {
        candCity = 'City of Malolos';
      } else if (combinedLocText.contains('meycauayan')) {
        candCity = 'City of Meycauayan';
      } else if (combinedLocText.contains('san jose del monte') || combinedLocText.contains('sjdm')) {
        candCity = 'City of San Jose del Monte';
      }
    }

    // 2. Infer Province if empty
    if (candProv.isEmpty) {
      final cityLower = candCity.toLowerCase();
      const ncrCities = [
        'manila', 'quezon city', 'taguig', 'makati', 'pasig', 'muntinlupa',
        'san juan', 'mandaluyong', 'marikina', 'pasay', 'parañaque', 'paranaque',
        'las piñas', 'las pinas', 'caloocan', 'valenzuela', 'malabon', 'navotas', 'pateros'
      ];
      if (ncrCities.any((c) => cityLower.contains(c))) {
        candProv = 'Metro Manila';
      } else if (cityLower.contains('cebu')) {
        candProv = 'Cebu';
      } else if (cityLower.contains('davao')) {
        candProv = 'Davao del Sur';
      } else if (cityLower.contains('iloilo')) {
        candProv = 'Iloilo';
      } else if (cityLower.contains('bacolod')) {
        candProv = 'Negros Occidental';
      } else if (cityLower.contains('baguio')) {
        candProv = 'Benguet';
      } else if (cityLower.contains('angeles') || cityLower.contains('san fernando') || combinedLocText.contains('pampanga')) {
        candProv = 'Pampanga';
      } else if (cityLower.contains('malolos') || cityLower.contains('meycauayan') || cityLower.contains('marilao') || combinedLocText.contains('bulacan')) {
        candProv = 'Bulacan';
      } else if (cityLower.contains('bacoor') || cityLower.contains('imus') || cityLower.contains('dasmarinas') || cityLower.contains('dasmariñas') || combinedLocText.contains('cavite')) {
        candProv = 'Cavite';
      } else if (cityLower.contains('calamba') || cityLower.contains('santa rosa') || cityLower.contains('binan') || cityLower.contains('biñan') || combinedLocText.contains('laguna')) {
        candProv = 'Laguna';
      } else if (cityLower.contains('batangas') || cityLower.contains('lipa')) {
        candProv = 'Batangas';
      } else if (cityLower.contains('lucena') || combinedLocText.contains('quezon')) {
        candProv = 'Quezon';
      } else if (combinedLocText.contains('rizal') || cityLower.contains('antipolo')) {
        candProv = 'Rizal';
      } else {
        for (final p in standardProvinces) {
          if (combinedLocText.contains(p.name.toLowerCase())) {
            candProv = p.name;
            break;
          }
        }
      }

      if (candProv.isEmpty && candReg.isNotEmpty) {
        final regDigits = candReg.replaceAll(RegExp(r'\D'), '');
        if (regDigits.startsWith('13') || candReg.toLowerCase().contains('ncr') || candReg.toLowerCase().contains('capital')) {
          candProv = 'Metro Manila';
        } else if (regDigits.startsWith('01')) {
          candProv = 'Ilocos Norte';
        } else if (regDigits.startsWith('02')) {
          candProv = 'Isabela';
        } else if (regDigits.startsWith('03')) {
          candProv = 'Bulacan';
        } else if (regDigits.startsWith('04')) {
          candProv = 'Cavite';
        } else if (regDigits.startsWith('05')) {
          candProv = 'Albay';
        } else if (regDigits.startsWith('06')) {
          candProv = 'Iloilo';
        } else if (regDigits.startsWith('07')) {
          candProv = 'Cebu';
        } else if (regDigits.startsWith('08')) {
          candProv = 'Leyte';
        } else if (regDigits.startsWith('09')) {
          candProv = 'Zamboanga del Sur';
        } else if (regDigits.startsWith('10')) {
          candProv = 'Misamis Oriental';
        } else if (regDigits.startsWith('11')) {
          candProv = 'Davao del Sur';
        } else if (regDigits.startsWith('12')) {
          candProv = 'South Cotabato';
        } else if (regDigits.startsWith('14')) {
          candProv = 'Benguet';
        } else if (regDigits.startsWith('15')) {
          candProv = 'Maguindanao del Norte';
        } else if (regDigits.startsWith('16')) {
          candProv = 'Agusan del Norte';
        } else if (regDigits.startsWith('17')) {
          candProv = 'Palawan';
        }
      }

      if (candProv.isEmpty) {
        candProv = 'Metro Manila';
      }
    }

    // 3. Infer Region if empty
    if (candReg.isEmpty) {
      final regFromProv = resolveRegionFromProvince(candProv);
      if (regFromProv.isNotEmpty) {
        candReg = regFromProv;
      } else {
        candReg = 'National Capital Region (NCR)';
      }
    }

    // 4. Infer City if still empty
    if (candCity.isEmpty) {
      if (candProv.toLowerCase().contains('metro manila') || candReg.toLowerCase().contains('ncr')) {
        candCity = 'Manila';
      } else if (candProv.toLowerCase().contains('cebu')) {
        candCity = 'Cebu City';
      } else if (candProv.toLowerCase().contains('davao')) {
        candCity = 'Davao City';
      } else if (candProv.toLowerCase().contains('iloilo')) {
        candCity = 'Iloilo City';
      } else if (candProv.toLowerCase().contains('cavite')) {
        candCity = 'City of Dasmariñas';
      } else if (candProv.toLowerCase().contains('laguna')) {
        candCity = 'Calamba City';
      } else if (candProv.toLowerCase().contains('bulacan')) {
        candCity = 'City of Malolos';
      } else if (candProv.toLowerCase().contains('pampanga')) {
        candCity = 'City of San Fernando';
      } else {
        candCity = 'Manila';
      }
    }

    // 5. Final resolution to official PSGC Link IDs and human-readable names
    final resolvedCityName = resolveCityName(candCity, dynamicLocations);
    final resolvedCityId = resolveCityId(candCity, dynamicLocations);
    final finalCityName = resolvedCityName.isNotEmpty ? resolvedCityName : candCity;
    var finalCityId = resolvedCityId.isNotEmpty ? resolvedCityId : candCity;
    if (finalCityId == '133900000' || finalCityId.startsWith('1339')) {
      finalCityId = '1380608000'; // Ermita, Manila in ERPNext
    }

    final resolvedProvName = resolveProvinceName(candProv, dynamicLocations);
    final resolvedProvId = resolveProvinceId(candProv, dynamicLocations);
    final finalProvName = resolvedProvName.isNotEmpty ? resolvedProvName : candProv;
    var finalProvId = resolvedProvId.isNotEmpty ? resolvedProvId : candProv;
    if (finalProvId == '1376000000' || finalProvId.startsWith('1376')) {
      finalProvId = '1380600000'; // Metro Manila in ERPNext
    }

    final resolvedRegName = resolveRegionName(candReg, dynamicLocations);
    final resolvedRegId = resolveRegionId(candReg, dynamicLocations);
    final finalRegName = resolvedRegName.isNotEmpty ? resolvedRegName : candReg;
    var finalRegId = resolvedRegId.isNotEmpty ? resolvedRegId : candReg;
    if (finalRegId.isEmpty || finalRegId == '-') {
      finalRegId = '1300000000';
    }

    return ResolvedWorkplaceLocation(
      regionId: finalRegId.isNotEmpty ? finalRegId : '1300000000',
      regionName: finalRegName.isNotEmpty ? finalRegName : 'National Capital Region (NCR)',
      provinceId: finalProvId.isNotEmpty ? finalProvId : '1380600000',
      provinceName: finalProvName.isNotEmpty ? finalProvName : 'Metro Manila',
      cityId: finalCityId.isNotEmpty ? finalCityId : '1380608000',
      cityName: finalCityName.isNotEmpty ? finalCityName : 'Manila',
      workplaceId: finalWpId,
      workplaceName: finalWpName,
    );
  }

  /// Resolve program / branch name to official ERPNext Branch name
  static String resolveProgramBranch(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Abbott Diabetes Care';
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();
    if (lower == 'adc' || lower.contains('abbott diabetes') || lower == 'abbott') {
      return 'Abbott Diabetes Care';
    }
    if (lower.contains('corenergy')) {
      return 'COREnergy';
    }
    if (lower.contains('bayer')) {
      if (lower.contains('team 3')) return 'Bayer Consumer Health - Team 3';
      if (lower.contains('team 2')) return 'Bayer Consumer Health - Team 2';
      if (lower.contains('team 1')) return 'Bayer Consumer Health - Team 1';
      if (lower.contains('free clinician') || lower.contains('fcp')) return 'Bayer Free Clinician Program';
      if (lower.contains('pharma')) return 'Bayer Pharma';
      return 'Bayer Consumer Health - Team 1';
    }
    if (lower.contains('ritemed') || lower == 'rtmd') {
      if (lower.contains('dental')) return 'RITEMED DENTAL';
      return 'RTMD';
    }
    if (lower.contains('vivaro')) {
      return 'VIVARO';
    }
    if (lower.contains('exeltis')) {
      return 'Exeltis (Philippines)';
    }
    if (lower.contains('taisho')) {
      if (lower.contains('pedia')) return 'Taisho Hospital Team - Pedia';
      if (lower.contains('primary') || lower.contains('adult')) return 'Taisho Hospital Team - Primary Care (Adult)';
      if (lower.contains('mdrp')) return 'Taisho PH-MDRP';
      if (lower.contains('merchandising') || lower.contains('tmp')) return 'Taisho Trade Merchandising Program';
      return 'Taisho Hospital Team - Primary Care (Adult)';
    }
    if (lower.contains('fonterra') || lower.contains('fon ')) {
      if (lower.contains('anlene')) return 'FONTERRA ANLENE';
      if (lower.contains('anmum') || lower.contains('hcap')) return 'FONTERRA ANMUM';
      return 'FONTERRA ANMUM';
    }
    if (lower.contains('biomerieux')) {
      return 'BIOMERIEUX';
    }
    if (lower.contains('pascual')) {
      return 'Pascual Dental Program';
    }
    if (lower.contains('gsk')) {
      return 'GSK HCP Profiling';
    }
    return trimmed;
  }

  /// Canonicalize a program name to its core key to handle synonyms across ERPNext
  static String canonicalizeProgram(String? raw) {
    if (raw == null) return '';
    final p = raw.trim().toLowerCase();
    if (p.isEmpty) return '';
    if (p == 'rtmd' || p.contains('ritemed') || p.startsWith('rtmd')) {
      return 'ritemed';
    }
    if (p == 'bch' || p.contains('bayer') || p.startsWith('bch')) {
      return 'bayer';
    }
    if (p == 'adc' || p.contains('abbott') || p.contains('adc-detailing') || p.startsWith('adc')) {
      return 'abbott';
    }
    if (p.contains('corenergy') || p.contains('cor energy')) {
      return 'corenergy';
    }
    if (p.contains('vivaro') || p == 'vhsi') {
      return 'vivaro';
    }
    if (p.contains('exeltis')) {
      return 'exeltis';
    }
    if (p.contains('taisho') || p.contains('tppi')) {
      return 'taisho';
    }
    if (p.contains('fonterra') || p.contains('anmum') || p.contains('anlene') || p.contains('hcap')) {
      return 'fonterra';
    }
    if (p.contains('biomerieux')) {
      return 'biomerieux';
    }
    if (p.contains('nes')) {
      return 'nes';
    }
    if (p.contains('nurturemed')) {
      return 'nurturemed';
    }
    if (p.contains('pch')) {
      return 'pch';
    }
    if (p.contains('pharmabest')) {
      return 'pharmabest';
    }
    if (p.contains('pascual')) {
      return 'pascual';
    }
    if (p.contains('gsk')) {
      return 'gsk';
    }
    if (p.contains('tstacco')) {
      return 'tstacco';
    }
    if (p.contains('tstacc1')) {
      return 'tstacc1';
    }
    return p;
  }

  /// Checks if two program representations refer to the same program.
  /// Strictly rejects null/empty or non-matching programs.
  static bool isSameProgram(String? progA, String? progB) {
    if (progA == null || progB == null) return false;
    final a = progA.trim().toLowerCase();
    final b = progB.trim().toLowerCase();
    if (a.isEmpty || b.isEmpty) return false;
    if (a == 'all' || b == 'all') return true;
    if (a == b) return true;

    final canonA = canonicalizeProgram(a);
    final canonB = canonicalizeProgram(b);
    if (canonA.isNotEmpty && canonB.isNotEmpty && canonA == canonB) {
      return true;
    }

    return a.contains(b) || b.contains(a);
  }
}
