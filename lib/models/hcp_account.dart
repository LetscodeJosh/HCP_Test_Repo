import 'lookup_models.dart';
import '../services/data_sanitizer.dart';

class HcpAccount {
  final String? name;
  final String accountName; // Map to account_or_program
  final String? territory;
  final String? salesPerson;
  final String? accountType;
  final String? userId;
  final bool isActive;
  final bool isArchived;
  final String? status; // Active, Archived, Expired
  final String? validFrom; // e.g. 2026-08-01
  final String? validTo; // e.g. 2026-08-31
  final String? startDate;
  final String? endDate;
  final String? validityPeriod; // e.g. "August 2026"
  final String? hcp; // Doctor ID Link -> HCP
  final String? hcpName; // Doctor Full Name (e.g. Joshua Pambuena Tan)
  final String? specialty;
  final String? subSpecialty;
  final String? workplaceId;
  final String? workplaceApprovalNote;
  final String? contactNumber;
  final String? contactEmail;
  final List<HcpAccountSpecialization> specialties;
  final List<HcpAccountWorkplace> workplaces;
  final List<HcpAccountContact> contacts;
  final bool isRolledOver;
  final String? sourceAccountName;
  final String? rolloverDate;

  String get accountOrProgram => accountName;

  String get effectiveWorkplaceApprovalNote {
    if (workplaceApprovalNote != null && workplaceApprovalNote!.trim().isNotEmpty) {
      return workplaceApprovalNote!.trim();
    }
    final wp = workplaceId ?? (workplaces.isNotEmpty ? workplaces.first.hcpWorkplace : '');
    return LocationResolver.getInstitutionApprovalStatusNote(wp);
  }

  String getEffectiveWorkplaceApprovalNote([List<Institution>? dynamicInsts]) {
    final wp = workplaceId ?? (workplaces.isNotEmpty ? workplaces.first.hcpWorkplace : '');
    if (LocationResolver.isRejectedInstitution(wp, dynamicInsts)) {
      final reason = getRejectedInstitutionReason(dynamicInsts);
      return (reason != null && reason.isNotEmpty)
          ? '[REJECTED INSTITUTION: $reason]'
          : '[REJECTED INSTITUTION]';
    }
    if (workplaceApprovalNote != null && workplaceApprovalNote!.trim().isNotEmpty) {
      return workplaceApprovalNote!.trim();
    }
    return LocationResolver.getInstitutionApprovalStatusNote(wp, dynamicInsts);
  }

  bool isWorkplaceRejected([List<Institution>? dynamicInsts]) {
    final wp = workplaceId ?? (workplaces.isNotEmpty ? workplaces.first.hcpWorkplace : '');
    return LocationResolver.isRejectedInstitution(wp, dynamicInsts) ||
        (workplaceApprovalNote != null && workplaceApprovalNote!.toUpperCase().contains('REJECTED')) ||
        workplaces.any((w) => LocationResolver.isRejectedInstitution(w.hcpWorkplace, dynamicInsts));
  }

  String? getRejectedInstitutionReason([List<Institution>? dynamicInsts]) {
    final wp = workplaceId ?? (workplaces.isNotEmpty ? workplaces.first.hcpWorkplace : '');
    if (LocationResolver.isRejectedInstitution(wp, dynamicInsts)) {
      final match = dynamicInsts?.firstWhere(
        (i) => i.name.toLowerCase() == wp.toLowerCase() || i.institutionName.toLowerCase() == wp.toLowerCase(),
        orElse: () => Institution(name: '', institutionName: ''),
      );
      if (match != null && match.rejectionReason != null && match.rejectionReason!.trim().isNotEmpty) {
        return match.rejectionReason!.trim();
      }
    }
    for (var w in workplaces) {
      if (LocationResolver.isRejectedInstitution(w.hcpWorkplace, dynamicInsts)) {
        final match = dynamicInsts?.firstWhere(
          (i) => i.name.toLowerCase() == w.hcpWorkplace.toLowerCase() || i.institutionName.toLowerCase() == w.hcpWorkplace.toLowerCase(),
          orElse: () => Institution(name: '', institutionName: ''),
        );
        if (match != null && match.rejectionReason != null && match.rejectionReason!.trim().isNotEmpty) {
          return match.rejectionReason!.trim();
        }
      }
    }
    if (workplaceApprovalNote != null && workplaceApprovalNote!.toUpperCase().contains('REJECTED')) {
      return workplaceApprovalNote;
    }
    return null;
  }

  HcpAccount({
    this.name,
    required this.accountName,
    this.territory,
    this.salesPerson,
    this.accountType,
    this.userId,
    this.isActive = true,
    this.isArchived = false,
    this.status,
    String? validFrom,
    String? validTo,
    String? startDate,
    String? endDate,
    this.validityPeriod,
    this.hcp,
    this.hcpName,
    this.specialty,
    this.subSpecialty,
    this.workplaceId,
    this.workplaceApprovalNote,
    this.contactNumber,
    this.contactEmail,
    this.specialties = const [],
    this.workplaces = const [],
    this.contacts = const [],
    this.isRolledOver = false,
    this.sourceAccountName,
    this.rolloverDate,
  })  : validFrom = validFrom ?? startDate ?? calculateMonthValidFrom(),
        validTo = validTo ?? endDate ?? calculateMonthValidTo(),
        startDate = startDate ?? validFrom ?? calculateMonthValidFrom(),
        endDate = endDate ?? validTo ?? calculateMonthValidTo();

  /// Calculate dynamic start date of the month (YYYY-MM-01)
  static String calculateMonthValidFrom([DateTime? date]) {
    final d = date ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-01';
  }

  /// Calculate dynamic last day of the month (handles Feb 28/29 leap year, 30, 31)
  static String calculateMonthValidTo([DateTime? date]) {
    final d = date ?? DateTime.now();
    final lastDay = DateTime(d.year, d.month + 1, 0);
    return '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';
  }

  /// Calculate human-readable month label e.g. "August 2026"
  static String calculateMonthLabel([DateTime? date]) {
    final d = date ?? DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  /// Clones this account for a new active monthly cycle, carrying over all details
  HcpAccount copyForNewMonth({DateTime? targetMonth}) {
    final target = targetMonth ?? DateTime.now();
    final vFrom = calculateMonthValidFrom(target);
    final vTo = calculateMonthValidTo(target);
    final vPeriod = calculateMonthLabel(target);

    // Retain specialization details (cross-fallback from child list or top-level)
    String? resSpecialty = (specialty != null && specialty!.trim().isNotEmpty) ? specialty!.trim() : null;
    if (resSpecialty == null && specialties.isNotEmpty) {
      resSpecialty = specialties.first.hcpSpecialty.trim();
    }
    String? resSubSpecialty = (subSpecialty != null && subSpecialty!.trim().isNotEmpty) ? subSpecialty!.trim() : null;
    if (resSubSpecialty == null && specialties.isNotEmpty) {
      resSubSpecialty = specialties.first.subSpecialty?.trim();
    }

    // Retain workplace details (cross-fallback from child list or top-level)
    String? resWorkplaceId = (workplaceId != null && workplaceId!.trim().isNotEmpty) ? workplaceId!.trim() : null;
    if (resWorkplaceId == null && workplaces.isNotEmpty) {
      resWorkplaceId = workplaces.first.hcpWorkplace.trim();
    }

    // Retain contact details (cross-fallback from child list or top-level)
    String? resContactNumber = (contactNumber != null && contactNumber!.trim().isNotEmpty) ? contactNumber!.trim() : null;
    if (resContactNumber == null && contacts.isNotEmpty) {
      resContactNumber = contacts.first.contactNumber?.trim();
    }
    String? resContactEmail = (contactEmail != null && contactEmail!.trim().isNotEmpty) ? contactEmail!.trim() : null;
    if (resContactEmail == null && contacts.isNotEmpty) {
      resContactEmail = contacts.first.emailAddress?.trim();
    }

    // Retain Child lists or synthesize from top-level fields so data is never lost
    List<HcpAccountSpecialization> resSpecialties = List.from(specialties);
    if (resSpecialties.isEmpty && resSpecialty != null && resSpecialty.isNotEmpty) {
      resSpecialties = [
        HcpAccountSpecialization(
          hcpSpecialty: resSpecialty,
          subSpecialty: resSubSpecialty,
          isPrimary: true,
          preferred: true,
        ),
      ];
    }

    List<HcpAccountWorkplace> resWorkplaces = List.from(workplaces);
    if (resWorkplaces.isEmpty && resWorkplaceId != null && resWorkplaceId.isNotEmpty) {
      resWorkplaces = [
        HcpAccountWorkplace(
          hcpWorkplace: resWorkplaceId,
          isPrimary: true,
          preferred: true,
        ),
      ];
    }

    List<HcpAccountContact> resContacts = List.from(contacts);
    if (resContacts.isEmpty && (resContactNumber != null || resContactEmail != null)) {
      resContacts = [
        HcpAccountContact(
          contactNumber: resContactNumber,
          emailAddress: resContactEmail,
          isPrimary: true,
          preferred: true,
        ),
      ];
    }

    return HcpAccount(
      name: name ?? sourceAccountName, // Maintain account identifier for detail resolution
      accountName: accountName,
      territory: territory,
      salesPerson: salesPerson,
      accountType: accountType,
      userId: userId,
      isActive: true,
      isArchived: false,
      status: 'Active',
      validFrom: vFrom,
      validTo: vTo,
      startDate: vFrom,
      endDate: vTo,
      validityPeriod: vPeriod,
      hcp: hcp,
      hcpName: hcpName,
      specialty: resSpecialty,
      subSpecialty: resSubSpecialty,
      workplaceId: resWorkplaceId,
      workplaceApprovalNote: workplaceApprovalNote,
      contactNumber: resContactNumber,
      contactEmail: resContactEmail,
      specialties: resSpecialties,
      workplaces: resWorkplaces,
      contacts: resContacts,
      isRolledOver: true,
      sourceAccountName: name,
      rolloverDate: DateTime.now().toIso8601String(),
    );
  }

  HcpAccount copyWith({
    String? name,
    String? accountName,
    String? territory,
    String? salesPerson,
    String? accountType,
    String? userId,
    bool? isActive,
    bool? isArchived,
    String? status,
    String? validFrom,
    String? validTo,
    String? startDate,
    String? endDate,
    String? validityPeriod,
    String? hcp,
    String? hcpName,
    String? specialty,
    String? subSpecialty,
    String? workplaceId,
    String? workplaceApprovalNote,
    String? contactNumber,
    String? contactEmail,
    List<HcpAccountSpecialization>? specialties,
    List<HcpAccountWorkplace>? workplaces,
    List<HcpAccountContact>? contacts,
    bool? isRolledOver,
    String? sourceAccountName,
    String? rolloverDate,
  }) {
    return HcpAccount(
      name: name ?? this.name,
      accountName: accountName ?? this.accountName,
      territory: territory ?? this.territory,
      salesPerson: salesPerson ?? this.salesPerson,
      accountType: accountType ?? this.accountType,
      userId: userId ?? this.userId,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      status: status ?? this.status,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      validityPeriod: validityPeriod ?? this.validityPeriod,
      hcp: hcp ?? this.hcp,
      hcpName: hcpName ?? this.hcpName,
      specialty: specialty ?? this.specialty,
      subSpecialty: subSpecialty ?? this.subSpecialty,
      workplaceId: workplaceId ?? this.workplaceId,
      workplaceApprovalNote: workplaceApprovalNote ?? this.workplaceApprovalNote,
      contactNumber: contactNumber ?? this.contactNumber,
      contactEmail: contactEmail ?? this.contactEmail,
      specialties: specialties ?? this.specialties,
      workplaces: workplaces ?? this.workplaces,
      contacts: contacts ?? this.contacts,
      isRolledOver: isRolledOver ?? this.isRolledOver,
      sourceAccountName: sourceAccountName ?? this.sourceAccountName,
      rolloverDate: rolloverDate ?? this.rolloverDate,
    );
  }

  /// Returns the human-readable month label for this account, e.g. "September 2026"
  String get monthLabel {
    // 1. Explicit validity date range is the definitive source of truth
    final fromStr = validFrom ?? startDate;
    final toStr = validTo ?? endDate;
    final dateStr = fromStr ?? toStr;
    if (dateStr != null && dateStr.isNotEmpty) {
      final d = DateTime.tryParse(dateStr);
      if (d != null) {
        return calculateMonthLabel(d);
      }
    }
    // 2. Fall back to validityPeriod if dateStr was not parseable
    if (validityPeriod != null && validityPeriod!.trim().isNotEmpty) {
      return validityPeriod!.trim();
    }
    return calculateMonthLabel();
  }

  /// Returns a sortable month key, e.g. "2026-09"
  String get monthKey {
    final fromStr = validFrom ?? startDate;
    final toStr = validTo ?? endDate;
    final dateStr = fromStr ?? toStr;
    if (dateStr != null && dateStr.isNotEmpty) {
      final d = DateTime.tryParse(dateStr);
      if (d != null) {
        return '${d.year}-${d.month.toString().padLeft(2, '0')}';
      }
    }
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Returns true if this account belongs strictly to a previous / past month
  bool isPastMonth([DateTime? referenceDate]) {
    if (isArchived) return true;
    final now = referenceDate ?? DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final toStr = validTo ?? endDate;
    if (toStr != null && toStr.isNotEmpty) {
      try {
        final toDate = DateTime.parse(toStr);
        if (toDate.isBefore(currentMonthStart)) return true;
      } catch (_) {}
    }
    final fromStr = validFrom ?? startDate;
    if (fromStr != null && fromStr.isNotEmpty) {
      try {
        final fromDate = DateTime.parse(fromStr);
        if (fromDate.isBefore(currentMonthStart) && (toStr == null || toStr.isEmpty)) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Check if this account is active for the current monthly cycle
  bool isCurrentMonthActive([DateTime? referenceDate]) {
    if (isArchived) return false;
    if (isPastMonth(referenceDate)) return false;
    final now = referenceDate ?? DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final fromStr = validFrom ?? startDate;
    final toStr = validTo ?? endDate;

    if (fromStr != null && fromStr.isNotEmpty && toStr != null && toStr.isNotEmpty) {
      try {
        final fromDate = DateTime.parse(fromStr);
        final toDate = DateTime.parse(toStr);
        if (toDate.isBefore(currentMonthStart)) return false;
        if (fromDate.isAfter(currentMonthEnd)) return false;
        return isActive;
      } catch (_) {}
    }
    return isActive;
  }

  factory HcpAccount.fromJson(Map<String, dynamic> json) {
    final rawValidFrom = json['valid_from'] ?? json['start_date'];
    final rawValidTo = json['valid_to'] ?? json['end_date'];
    final archived = json['is_archived'] == 1 || json['is_archived'] == true;
    final resolvedStatus = json['status'] ?? (archived ? 'Archived' : 'Active');

    DateTime? refDate;
    if (rawValidFrom != null) {
      refDate = DateTime.tryParse(rawValidFrom.toString().trim());
    }
    if (refDate == null && rawValidTo != null) {
      refDate = DateTime.tryParse(rawValidTo.toString().trim());
    }

    final vFrom = rawValidFrom != null ? DataSanitizer.trim(rawValidFrom.toString()) : calculateMonthValidFrom(refDate);
    final vTo = rawValidTo != null ? DataSanitizer.trim(rawValidTo.toString()) : calculateMonthValidTo(refDate);
    final vPeriod = (json['validity_period'] != null && json['validity_period'].toString().trim().isNotEmpty)
        ? DataSanitizer.cleanTrimProper(json['validity_period'])
        : (json['month_period'] != null && json['month_period'].toString().trim().isNotEmpty)
            ? DataSanitizer.cleanTrimProper(json['month_period'])
            : calculateMonthLabel(refDate);

    return HcpAccount(
      name: json['name'] != null ? DataSanitizer.cleanTrimUpper(json['name']) : null,
      accountName: DataSanitizer.cleanTrimProper(json['account_or_program'] ?? json['account_name'] ?? ''),
      territory: (json['territory'] != null || json['territory_mr_code'] != null)
          ? DataSanitizer.cleanTrimUpper(json['territory'] ?? json['territory_mr_code'])
          : null,
      salesPerson: (json['sales_person'] != null || json['territory_manager'] != null)
          ? DataSanitizer.cleanTrimProper(json['sales_person'] ?? json['territory_manager'])
          : null,
      accountType: json['account_type'] != null ? DataSanitizer.cleanTrimProper(json['account_type']) : null,
      userId: json['user_id'] != null ? DataSanitizer.cleanTrimUpper(json['user_id']) : null,
      isActive: json['is_active'] == 1 || json['is_active'] == true || json['is_active'] == null,
      isArchived: archived,
      status: DataSanitizer.cleanTrimProper(resolvedStatus),
      validFrom: vFrom,
      validTo: vTo,
      startDate: vFrom,
      endDate: vTo,
      validityPeriod: vPeriod,
      hcp: (json['hcp'] != null || json['hcp_doctor_unique_id'] != null)
          ? DataSanitizer.cleanTrimUpper(json['hcp'] ?? json['hcp_doctor_unique_id'])
          : null,
      hcpName: (json['hcp_name'] != null || json['doctor_name'] != null || json['hcp_full_name'] != null || json['hcp'] != null)
          ? DataSanitizer.cleanTrimProper(json['hcp_name'] ?? json['doctor_name'] ?? json['hcp_full_name'] ?? json['hcp'])
          : null,
      specialty: (json['specialty'] != null || json['hcp_specialty'] != null)
          ? DataSanitizer.cleanTrimProper(json['specialty'] ?? json['hcp_specialty'])
          : null,
      subSpecialty: json['sub_specialty'] != null ? DataSanitizer.cleanTrimProper(json['sub_specialty']) : null,
      workplaceId: (json['workplace_id'] != null || json['hcp_workplace'] != null || json['workplace'] != null)
          ? DataSanitizer.cleanTrimUpper(json['workplace_id'] ?? json['hcp_workplace'] ?? json['workplace'])
          : null,
      workplaceApprovalNote: (json['workplace_approval_note'] != null || json['custom_workplace_approval_note'] != null || json['institution_approval_note'] != null)
          ? DataSanitizer.trim(json['workplace_approval_note'] ?? json['custom_workplace_approval_note'] ?? json['institution_approval_note'])
          : null,
      contactNumber: (json['contact_number'] != null || json['mobile_number'] != null || json['phone_number'] != null)
          ? DataSanitizer.cleanPhone(json['contact_number'] ?? json['mobile_number'] ?? json['phone_number'])
          : null,
      contactEmail: (json['contact_email'] != null || json['email_address'] != null)
          ? DataSanitizer.cleanTrimLower(json['contact_email'] ?? json['email_address'])
          : null,
      specialties: _parseSpecialties(json),
      workplaces: _parseWorkplaces(json),
      contacts: _parseContacts(json),
      isRolledOver: json['is_rolled_over'] == 1 || json['is_rolled_over'] == true,
      sourceAccountName: json['source_account_name'] != null ? DataSanitizer.cleanTrimUpper(json['source_account_name']) : null,
      rolloverDate: json['rollover_date'] != null ? DataSanitizer.trim(json['rollover_date']) : null,
    );
  }

  static List<HcpAccountSpecialization> _parseSpecialties(Map<String, dynamic> json) {
    final primarySpec = json['specialty'] ?? json['hcp_specialty'];
    final rawSpecs = (json['specialization'] as List? ?? json['specialties'] as List?) ?? [];
    final List<HcpAccountSpecialization> result = [];
    for (int i = 0; i < rawSpecs.length; i++) {
      final e = rawSpecs[i];
      if (e is Map) {
        final map = Map<String, dynamic>.from(e);
        final sId = (map['hcp_specialty'] ?? map['specialty'] ?? '').toString().trim();
        final isExplicitPref = map['preferred'] == 1 || map['preferred'] == true ||
            map['is_preferred'] == 1 || map['is_preferred'] == true ||
            map['is_primary'] == 1 || map['is_primary'] == true;
        final isTopMatch = primarySpec != null && sId.isNotEmpty &&
            (sId == primarySpec || LocationResolver.resolveSpecialtyId(sId) == primarySpec);
        final bool isPref = isExplicitPref || isTopMatch || (rawSpecs.length == 1) || (i == 0);
        map['preferred'] = isPref ? 1 : 0;
        map['is_preferred'] = isPref ? 1 : 0;
        map['is_primary'] = isPref ? 1 : 0;
        result.add(HcpAccountSpecialization.fromJson(map));
      }
    }

    // Synthesize if child table was not returned by API list query but top-level specialty is present
    if (result.isEmpty && primarySpec != null && primarySpec.toString().trim().isNotEmpty) {
      final specStr = primarySpec.toString().trim();
      final resolvedSpec = LocationResolver.resolveSpecialtyName(specStr);
      final rawSub = json['sub_specialty']?.toString().trim();
      final resolvedSub = (rawSub != null && rawSub.isNotEmpty && rawSub != '-')
          ? LocationResolver.resolveSpecialtyName(rawSub)
          : null;
      result.add(HcpAccountSpecialization(
        hcpSpecialty: resolvedSpec.isNotEmpty ? resolvedSpec : specStr,
        subSpecialty: (resolvedSub != null && resolvedSub.isNotEmpty) ? resolvedSub : rawSub,
        isPrimary: true,
        preferred: true,
      ));
    }
    return result;
  }

  static List<HcpAccountWorkplace> _parseWorkplaces(Map<String, dynamic> json) {
    final primaryWp = json['workplace_id'] ?? json['hcp_workplace'] ?? json['workplace'];
    final rawWps = (json['workplace_info'] as List? ?? json['workplaces'] as List?) ?? [];
    final List<HcpAccountWorkplace> result = [];
    for (int i = 0; i < rawWps.length; i++) {
      final e = rawWps[i];
      if (e is Map) {
        final map = Map<String, dynamic>.from(e);
        final wId = (map['hcp_workplace'] ?? map['workplace'] ?? '').toString().trim();
        final isExplicitPref = map['preferred'] == 1 || map['preferred'] == true ||
            map['is_preferred'] == 1 || map['is_preferred'] == true ||
            map['is_primary'] == 1 || map['is_primary'] == true;
        final isTopMatch = primaryWp != null && wId.isNotEmpty &&
            (wId == primaryWp || LocationResolver.resolveInstitutionId(wId) == primaryWp);
        final bool isPref = isExplicitPref || isTopMatch || (rawWps.length == 1) || (i == 0);
        map['preferred'] = isPref ? 1 : 0;
        map['is_preferred'] = isPref ? 1 : 0;
        map['is_primary'] = isPref ? 1 : 0;
        result.add(HcpAccountWorkplace.fromJson(map));
      }
    }

    // Synthesize if child table was not returned by API list query but top-level workplace is present
    if (result.isEmpty && primaryWp != null && primaryWp.toString().trim().isNotEmpty) {
      final wpStr = primaryWp.toString().trim();
      final resolvedWp = LocationResolver.resolveInstitutionName(wpStr);
      final rawCity = json['city_municipality'] ?? json['city'] ?? json['city_title'];
      final rawProvince = json['province_name'] ?? json['province'] ?? json['province_title'];
      String? cityStr = rawCity?.toString().trim();
      String? provStr = rawProvince?.toString().trim();

      // If city or province is missing or code, resolve from LocationResolver complete workplace location
      if (cityStr == null || cityStr.isEmpty || provStr == null || provStr.isEmpty || RegExp(r'^\d+$').hasMatch(cityStr)) {
        final instLoc = LocationResolver.resolveCompleteWorkplaceLocation(
          workplaceNameOrId: resolvedWp.isNotEmpty ? resolvedWp : wpStr,
          rawCity: cityStr,
          rawProvince: provStr,
        );
        cityStr = instLoc.cityName;
        provStr = instLoc.provinceName;
      }

      result.add(HcpAccountWorkplace(
        hcpWorkplace: resolvedWp.isNotEmpty ? resolvedWp : wpStr,
        cityMunicipality: cityStr,
        provinceName: provStr,
        isPrimary: true,
        preferred: true,
      ));
    }
    return result;
  }

  static List<HcpAccountContact> _parseContacts(Map<String, dynamic> json) {
    final primaryNum = json['contact_number'] ?? json['mobile_number'] ?? json['phone_number'];
    final primaryEmail = json['contact_email'] ?? json['email_address'];
    final rawContacts = (json['contact_info'] as List? ?? json['contacts'] as List?) ?? [];
    final List<HcpAccountContact> result = [];
    for (int i = 0; i < rawContacts.length; i++) {
      final e = rawContacts[i];
      if (e is Map) {
        final map = Map<String, dynamic>.from(e);
        final num = (map['contact_number'] ?? map['mobile_number'] ?? '').toString().trim();
        final em = (map['email_address'] ?? map['contact_email'] ?? '').toString().trim();
        final isExplicitPref = map['preferred'] == 1 || map['preferred'] == true ||
            map['is_preferred'] == 1 || map['is_preferred'] == true ||
            map['is_primary'] == 1 || map['is_primary'] == true;
        final isTopMatch = (primaryNum != null && num.isNotEmpty && num == primaryNum) ||
            (primaryEmail != null && em.isNotEmpty && em == primaryEmail);
        final bool isPref = isExplicitPref || isTopMatch || (rawContacts.length == 1) || (i == 0);
        map['preferred'] = isPref ? 1 : 0;
        map['is_preferred'] = isPref ? 1 : 0;
        map['is_primary'] = isPref ? 1 : 0;
        result.add(HcpAccountContact.fromJson(map));
      }
    }

    // Synthesize if child table was not returned by API list query but top-level contact info is present
    if (result.isEmpty && (primaryNum != null || primaryEmail != null)) {
      final numStr = primaryNum?.toString().trim();
      final emStr = primaryEmail?.toString().trim();
      if ((numStr != null && numStr.isNotEmpty) || (emStr != null && emStr.isNotEmpty)) {
        result.add(HcpAccountContact(
          contactNumber: (numStr != null && numStr.isNotEmpty) ? numStr : null,
          emailAddress: (emStr != null && emStr.isNotEmpty) ? emStr : null,
          isPrimary: true,
          preferred: true,
        ));
      }
    }
    return result;
  }

  Map<String, dynamic> toJson() {
    return DataSanitizer.sanitizePayload({
      if (name != null) 'name': DataSanitizer.cleanTrimUpper(name),
      'account_or_program': DataSanitizer.cleanTrimProper(accountName),
      if (territory != null) 'territory': DataSanitizer.cleanTrimUpper(territory),
      if (salesPerson != null) ...{
        'sales_person': DataSanitizer.cleanTrimProper(salesPerson),
        'territory_manager': DataSanitizer.cleanTrimProper(salesPerson),
      },
      if (accountType != null) 'account_type': DataSanitizer.cleanTrimProper(accountType),
      if (userId != null) 'user_id': DataSanitizer.cleanTrimUpper(userId),
      'is_active': isActive ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      if (status != null) 'status': DataSanitizer.cleanTrimProper(status),
      if (validFrom != null) 'valid_from': DataSanitizer.trim(validFrom),
      if (validTo != null) 'valid_to': DataSanitizer.trim(validTo),
      if (startDate != null) 'start_date': DataSanitizer.trim(startDate),
      if (endDate != null) 'end_date': DataSanitizer.trim(endDate),
      if (validityPeriod != null) 'validity_period': DataSanitizer.cleanTrimProper(validityPeriod),
      if (hcp != null) 'hcp': DataSanitizer.cleanTrimUpper(hcp),
      if (hcpName != null) 'hcp_name': DataSanitizer.cleanTrimProper(hcpName),
      if (specialty != null) 'specialty': DataSanitizer.cleanTrimProper(specialty),
      if (subSpecialty != null) 'sub_specialty': DataSanitizer.cleanTrimProper(subSpecialty),
      if (workplaceId != null) 'workplace_id': DataSanitizer.cleanTrimUpper(workplaceId),
      if (effectiveWorkplaceApprovalNote.isNotEmpty) 'workplace_approval_note': DataSanitizer.trim(effectiveWorkplaceApprovalNote),
      if (contactNumber != null) 'contact_number': DataSanitizer.cleanPhone(contactNumber),
      if (contactEmail != null) 'contact_email': DataSanitizer.cleanTrimLower(contactEmail),
      if (specialties.isNotEmpty) 'specialization': specialties.map((e) => e.toJson()).toList(),
      if (workplaces.isNotEmpty) 'workplace_info': workplaces.map((e) => e.toJson()).toList(),
      if (contacts.isNotEmpty) 'contact_info': contacts.map((e) => e.toJson()).toList(),
      'is_rolled_over': isRolledOver ? 1 : 0,
      if (sourceAccountName != null) 'source_account_name': DataSanitizer.cleanTrimUpper(sourceAccountName),
      if (rolloverDate != null) 'rollover_date': DataSanitizer.trim(rolloverDate),
    });
  }
}

class HcpAccountSpecialization {
  final String hcpSpecialty;
  final String? subSpecialty;
  final bool isPrimary;
  final bool preferred;

  // Compatibility getter
  String get specialty => hcpSpecialty;

  HcpAccountSpecialization({
    String? hcpSpecialty,
    String? specialty,
    this.subSpecialty,
    this.isPrimary = false,
    bool? preferred,
  }) : hcpSpecialty = (hcpSpecialty != null && hcpSpecialty.isNotEmpty) ? hcpSpecialty : (specialty ?? ''),
       preferred = preferred ?? isPrimary;

  factory HcpAccountSpecialization.fromJson(Map<String, dynamic> json) {
    final pref = json['preferred'] == 1 || json['preferred'] == true ||
        json['is_preferred'] == 1 || json['is_preferred'] == true ||
        json['is_primary'] == 1 || json['is_primary'] == true ||
        json['primary'] == 1 || json['primary'] == true;
    final rawSpec = json['specialty_name'] ?? json['specialty'] ?? json['hcp_specialty'] ?? '';
    final specName = LocationResolver.resolveSpecialtyName(rawSpec.toString());
    final rawSub = json['sub_specialty_name'] ?? json['sub_specialty'];
    final subName = (rawSub != null && rawSub.toString().isNotEmpty && rawSub != '-') ? LocationResolver.resolveSpecialtyName(rawSub.toString()) : null;
    return HcpAccountSpecialization(
      hcpSpecialty: specName.isNotEmpty ? specName : rawSpec.toString(),
      subSpecialty: subName ?? rawSub?.toString(),
      isPrimary: pref,
      preferred: pref,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doctype': 'HCP Account Specialization',
      'hcp_specialty': hcpSpecialty,
      'specialty': hcpSpecialty, // for backwards compatibility with legacy schemas
      if (subSpecialty != null && subSpecialty!.isNotEmpty && subSpecialty != '-') 'sub_specialty': subSpecialty,
      'is_primary': (isPrimary || preferred) ? 1 : 0,
      'primary': (isPrimary || preferred) ? 1 : 0,
      'preferred': (isPrimary || preferred) ? 1 : 0,
      'is_preferred': (isPrimary || preferred) ? 1 : 0,
    };
  }
}

class HcpAccountWorkplace {
  final String hcpWorkplace;
  final String? cityMunicipality;
  final String? provinceName;
  final String? address;
  final bool isPrimary;
  final bool preferred;

  // Compatibility getters
  String get workplace => hcpWorkplace;
  String? get city => cityMunicipality;
  String? get province => provinceName;
  String get approvalStatusNote => LocationResolver.getInstitutionApprovalStatusNote(hcpWorkplace);
  bool get isApproved => LocationResolver.isApprovedInstitution(hcpWorkplace);

  HcpAccountWorkplace({
    String? hcpWorkplace,
    String? workplace,
    String? cityMunicipality,
    String? provinceName,
    String? city,
    String? province,
    this.address,
    this.isPrimary = false,
    bool? preferred,
  }) : hcpWorkplace = (hcpWorkplace != null && hcpWorkplace.isNotEmpty) ? hcpWorkplace : (workplace ?? ''),
       cityMunicipality = cityMunicipality ?? city,
       provinceName = provinceName ?? province,
       preferred = preferred ?? isPrimary;

  factory HcpAccountWorkplace.fromJson(Map<String, dynamic> json) {
    final pref = json['preferred'] == 1 || json['preferred'] == true ||
        json['is_preferred'] == 1 || json['is_preferred'] == true ||
        json['is_primary'] == 1 || json['is_primary'] == true ||
        json['primary'] == 1 || json['primary'] == true;
    final rawWp = json['workplace_name'] ?? json['workplace'] ?? json['hcp_workplace'] ?? '';
    final wpName = LocationResolver.resolveInstitutionName(rawWp.toString());
    final rawCity = json['city_municipality'] ?? json['city'] ?? json['city_title'];
    final rawProv = json['province_name'] ?? json['province'] ?? json['province_title'];
    return HcpAccountWorkplace(
      hcpWorkplace: wpName.isNotEmpty ? wpName : rawWp.toString(),
      cityMunicipality: rawCity != null ? LocationResolver.resolveCityName(rawCity.toString()) : null,
      provinceName: rawProv != null ? LocationResolver.resolveProvinceName(rawProv.toString()) : null,
      address: json['address'],
      isPrimary: pref,
      preferred: pref,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doctype': 'HCP Account Workplace',
      'hcp_workplace': hcpWorkplace,
      'workplace': hcpWorkplace, // for backwards compatibility with legacy schemas
      if (cityMunicipality != null) 'city_municipality': cityMunicipality,
      if (cityMunicipality != null) 'city': cityMunicipality,
      if (provinceName != null) 'province_name': provinceName,
      if (provinceName != null) 'province': provinceName,
      if (address != null) 'address': address,
      'is_primary': (isPrimary || preferred) ? 1 : 0,
      'primary': (isPrimary || preferred) ? 1 : 0,
      'preferred': (isPrimary || preferred) ? 1 : 0,
      'is_preferred': (isPrimary || preferred) ? 1 : 0,
    };
  }
}

class HcpAccountContact {
  final String? contactNumber;
  final String? emailAddress;
  final bool isPrimary;
  final bool preferred;

  // Compatibility getters
  String get contactValue => contactNumber ?? emailAddress ?? '';
  String get contactType => (emailAddress != null && emailAddress!.isNotEmpty) ? 'Email' : 'Mobile';

  HcpAccountContact({
    String? contactNumber,
    String? emailAddress,
    String? contactType,
    String? contactValue,
    this.isPrimary = false,
    bool? preferred,
  }) : contactNumber = contactNumber ?? (contactType == 'Email' ? null : contactValue),
       emailAddress = emailAddress ?? (contactType == 'Email' ? contactValue : null),
       preferred = preferred ?? isPrimary;

  factory HcpAccountContact.fromJson(Map<String, dynamic> json) {
    final pref = json['preferred'] == 1 || json['preferred'] == true ||
        json['is_preferred'] == 1 || json['is_preferred'] == true ||
        json['is_primary'] == 1 || json['is_primary'] == true ||
        json['primary'] == 1 || json['primary'] == true;
    String? num = json['contact_number'] ?? json['mobile_number'] ?? json['phone_number'];
    String? email = json['email_address'] ?? json['email'];

    if (num == null && email == null && json['contact_value'] != null) {
      final val = '${json['contact_value']}';
      if (val.contains('@')) {
        email = val;
      } else {
        num = val;
      }
    }

    return HcpAccountContact(
      contactNumber: num,
      emailAddress: email,
      isPrimary: pref,
      preferred: pref,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doctype': 'HCP Account Contact',
      if (contactNumber != null) 'contact_number': contactNumber,
      if (contactNumber != null) 'mobile_number': contactNumber,
      if (contactNumber != null) 'phone_number': contactNumber,
      if (emailAddress != null) 'email_address': emailAddress,
      if (emailAddress != null) 'contact_email': emailAddress,
      if (emailAddress != null) 'email': emailAddress,
      'is_primary': (isPrimary || preferred) ? 1 : 0,
      'primary': (isPrimary || preferred) ? 1 : 0,
      'preferred': (isPrimary || preferred) ? 1 : 0,
      'is_preferred': (isPrimary || preferred) ? 1 : 0,
    };
  }
}

class HcpAccountDoctors {
  final String? name;
  final String hcp;
  final String hcpAccount;
  final String? role;

  HcpAccountDoctors({
    this.name,
    required this.hcp,
    required this.hcpAccount,
    this.role,
  });

  factory HcpAccountDoctors.fromJson(Map<String, dynamic> json) {
    return HcpAccountDoctors(
      name: json['name'],
      hcp: json['hcp'] ?? '',
      hcpAccount: json['hcp_account'] ?? '',
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'hcp': hcp,
      'hcp_account': hcpAccount,
      if (role != null) 'role': role,
    };
  }
}
