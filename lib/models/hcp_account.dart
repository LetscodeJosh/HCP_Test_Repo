import 'lookup_models.dart';

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
  final List<HcpAccountSpecialization> specialties;
  final List<HcpAccountWorkplace> workplaces;
  final List<HcpAccountContact> contacts;

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
    this.specialties = const [],
    this.workplaces = const [],
    this.contacts = const [],
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

  /// Check if this account is active for the current monthly cycle
  bool isCurrentMonthActive([DateTime? referenceDate]) {
    if (isArchived) return false;
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

    return HcpAccount(
      name: json['name'],
      accountName: json['account_or_program'] ?? json['account_name'] ?? '',
      territory: json['territory'] ?? json['territory_mr_code'],
      salesPerson: json['sales_person'] ?? json['territory_manager'],
      accountType: json['account_type'],
      userId: json['user_id'],
      isActive: json['is_active'] == 1 || json['is_active'] == true || json['is_active'] == null,
      isArchived: archived,
      status: resolvedStatus,
      validFrom: rawValidFrom != null ? rawValidFrom.toString() : calculateMonthValidFrom(),
      validTo: rawValidTo != null ? rawValidTo.toString() : calculateMonthValidTo(),
      startDate: rawValidFrom != null ? rawValidFrom.toString() : calculateMonthValidFrom(),
      endDate: rawValidTo != null ? rawValidTo.toString() : calculateMonthValidTo(),
      validityPeriod: json['validity_period'] ?? json['month_period'] ?? calculateMonthLabel(),
      hcp: json['hcp'] ?? json['hcp_doctor_unique_id'],
      hcpName: json['hcp_name'] ?? json['doctor_name'] ?? json['hcp_full_name'] ?? json['hcp'],
      specialties: (json['specialization'] as List? ?? json['specialties'] as List?)
              ?.map((e) => HcpAccountSpecialization.fromJson(e))
              .toList() ?? [],
      workplaces: (json['workplace_info'] as List? ?? json['workplaces'] as List?)
              ?.map((e) => HcpAccountWorkplace.fromJson(e))
              .toList() ?? [],
      contacts: (json['contact_info'] as List? ?? json['contacts'] as List?)
              ?.map((e) => HcpAccountContact.fromJson(e))
              .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'account_or_program': accountName,
      if (territory != null) 'territory': territory,
      if (salesPerson != null) ...{
        'sales_person': salesPerson,
        'territory_manager': salesPerson,
      },
      if (accountType != null) 'account_type': accountType,
      if (userId != null) 'user_id': userId,
      'is_active': isActive ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      if (status != null) 'status': status,
      if (validFrom != null) 'valid_from': validFrom,
      if (validTo != null) 'valid_to': validTo,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (validityPeriod != null) 'validity_period': validityPeriod,
      if (hcp != null) 'hcp': hcp,
      if (hcpName != null) 'hcp_name': hcpName,
      if (specialties.isNotEmpty) 'specialization': specialties.map((e) => e.toJson()).toList(),
      if (workplaces.isNotEmpty) 'workplace_info': workplaces.map((e) => e.toJson()).toList(),
      if (contacts.isNotEmpty) 'contact_info': contacts.map((e) => e.toJson()).toList(),
    };
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
  }) : this.hcpSpecialty = (hcpSpecialty != null && hcpSpecialty.isNotEmpty) ? hcpSpecialty : (specialty ?? ''),
       this.preferred = preferred ?? isPrimary;

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
      subSpecialty: subName ?? (rawSub != null ? rawSub.toString() : null),
      isPrimary: pref,
      preferred: pref,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
  }) : this.hcpWorkplace = (hcpWorkplace != null && hcpWorkplace.isNotEmpty) ? hcpWorkplace : (workplace ?? ''),
       this.cityMunicipality = cityMunicipality ?? city,
       this.provinceName = provinceName ?? province,
       this.preferred = preferred ?? isPrimary;

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
      'hcp_workplace': hcpWorkplace,
      'workplace': hcpWorkplace, // for backwards compatibility with legacy schemas
      if (cityMunicipality != null) 'city_municipality': cityMunicipality,
      if (provinceName != null) 'province_name': provinceName,
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
  }) : this.contactNumber = contactNumber ?? (contactType == 'Email' ? null : contactValue),
       this.emailAddress = emailAddress ?? (contactType == 'Email' ? contactValue : null),
       this.preferred = preferred ?? isPrimary;

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
      if (contactNumber != null) 'contact_number': contactNumber,
      if (emailAddress != null) 'email_address': emailAddress,
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
