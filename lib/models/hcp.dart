import 'lookup_models.dart';

class Hcp {
  final String? name;
  final String? hcpFullName;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? birthDate;
  final String? hcpPhoto;
  final String hcpType;
  final String hcpPractice;
  final bool isActive;
  final bool isPendingApproval;
  final List<HcpSpecialty> specialties;
  final List<HcpWorkplace> workplaces;
  final List<HcpContact> contacts;
  final String? regionName;
  final String? provinceName;
  final String? cityMunicipality;
  final String? barangayName;
  final String? institution;
  final String? profileLastUpdated;

  Hcp({
    this.name,
    this.hcpFullName,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.birthDate,
    this.hcpPhoto,
    required this.hcpType,
    required this.hcpPractice,
    this.isActive = true,
    this.isPendingApproval = false,
    this.specialties = const [],
    this.workplaces = const [],
    this.contacts = const [],
    this.regionName,
    this.provinceName,
    this.cityMunicipality,
    this.barangayName,
    this.institution,
    this.profileLastUpdated,
  });

  factory Hcp.fromJson(Map<String, dynamic> json) {
    final fn = (json['first_name'] ?? '').toString().trim();
    final mn = json['middle_name'];
    final ln = (json['last_name'] ?? '').toString().trim();

    final parts = [
      if (fn.isNotEmpty) fn,
      if (mn != null && mn.toString().trim().isNotEmpty && mn.toString().trim() != '-') mn.toString().trim(),
      if (ln.isNotEmpty) ln,
    ];
    final computedFromParts = parts.join(' ');

    final rawName = json['name_of_doctor'] ?? json['doctor_name'] ?? json['hcp_full_name'] ?? json['full_name'] ?? json['hcp_name'];
    String finalFullName = '';
    if (rawName != null && rawName.toString().trim().isNotEmpty && !rawName.toString().trim().startsWith('HCP-')) {
      finalFullName = rawName.toString().trim();
    } else if (computedFromParts.isNotEmpty) {
      finalFullName = computedFromParts;
    } else {
      finalFullName = (json['name'] ?? '').toString();
    }

    String effectiveFn = fn;
    String effectiveLn = ln;
    if (effectiveFn.isEmpty && effectiveLn.isEmpty && finalFullName.isNotEmpty && !finalFullName.startsWith('HCP-')) {
      final split = finalFullName.split(' ');
      if (split.length == 1) {
        effectiveFn = split.first;
      } else {
        effectiveFn = split.first;
        effectiveLn = split.sublist(1).join(' ');
      }
    }

    return Hcp(
      name: json['name'],
      hcpFullName: finalFullName,
      firstName: effectiveFn,
      middleName: mn,
      lastName: effectiveLn,
      birthDate: json['birth_date'],
      hcpPhoto: json['hcp_photo'],
      hcpType: json['hcp_type'] ?? '',
      hcpPractice: json['hcp_practice'] ?? 'Both',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      isPendingApproval: json['is_pending_approval'] == 1 || json['is_pending_approval'] == true,
      specialties: (json['hcp_specialty'] as List? ?? json['specialties'] as List?)
              ?.map((e) => HcpSpecialty.fromJson(e))
              .toList() ?? [],
      workplaces: (json['hcp_workplace'] as List? ?? json['workplaces'] as List?)
              ?.map((e) => HcpWorkplace.fromJson(e))
              .toList() ?? [],
      contacts: (json['hcp_contact_info'] as List? ?? json['contacts'] as List? ?? json['hcp_contact'] as List?)
              ?.map((e) => HcpContact.fromJson(e))
              .toList() ?? [],
      regionName: json['region_name'] != null ? LocationResolver.resolveRegionName(json['region_name'].toString()) : null,
      provinceName: json['province_name'] != null ? LocationResolver.resolveProvinceName(json['province_name'].toString()) : null,
      cityMunicipality: json['city_municipality'] != null ? LocationResolver.resolveCityName(json['city_municipality'].toString()) : null,
      barangayName: json['barangay_name'],
      institution: json['institution'] != null ? LocationResolver.resolveInstitutionName(json['institution'].toString()) : null,
      profileLastUpdated: json['profile_last_updated'],
    );
  }

  Map<String, dynamic> toJson() {
    final computedParts = [
      if (firstName.trim().isNotEmpty) firstName.trim(),
      if (middleName != null && middleName!.trim().isNotEmpty && middleName!.trim() != '-') middleName!.trim(),
      if (lastName.trim().isNotEmpty) lastName.trim(),
    ].join(' ');

    final computedFullName = (hcpFullName != null && hcpFullName!.trim().isNotEmpty && !hcpFullName!.trim().startsWith('HCP-'))
        ? hcpFullName!.trim()
        : (computedParts.isNotEmpty ? computedParts : '${firstName.trim()} ${lastName.trim()}'.trim());

    return {
      if (name != null) 'name': name,
      'first_name': firstName.trim(),
      if (middleName != null && middleName!.trim().isNotEmpty) 'middle_name': middleName!.trim(),
      'last_name': lastName.trim(),
      'hcp_full_name': computedFullName,
      'full_name': computedFullName,
      'doctor_name': computedFullName,
      'hcp_name': computedFullName,
      'name_of_doctor': computedFullName,
      if (birthDate != null) 'birth_date': birthDate,
      if (hcpPhoto != null) 'hcp_photo': hcpPhoto,
      'hcp_type': hcpType,
      'hcp_practice': hcpPractice,
      'is_active': isActive ? 1 : 0,
      'is_pending_approval': isPendingApproval ? 1 : 0,
      'hcp_specialty': specialties.map((e) => e.toJson()).toList(),
      'hcp_workplace': workplaces.map((e) => e.toJson()).toList(),
      'hcp_contact_info': contacts.map((e) => e.toJson()).toList(),
      if (regionName != null) 'region_name': regionName,
      if (provinceName != null) 'province_name': provinceName,
      if (cityMunicipality != null) 'city_municipality': cityMunicipality,
      if (barangayName != null) 'barangay_name': barangayName,
      if (institution != null) 'institution': institution,
      if (profileLastUpdated != null) 'profile_last_updated': profileLastUpdated,
    };
  }
}

class HcpSpecialty {
  final String hcpSpecialty; // Link -> Specialization
  final String? subSpecialty; // Link -> Specialization
  final bool isPrimary;

  HcpSpecialty({
    required this.hcpSpecialty,
    this.subSpecialty,
    this.isPrimary = false,
  });

  factory HcpSpecialty.fromJson(Map<String, dynamic> json) {
    final rawSpec = json['specialty_name'] ?? json['specialty'] ?? json['hcp_specialty'] ?? '';
    final specName = LocationResolver.resolveSpecialtyName(rawSpec.toString());
    final rawSub = json['sub_specialty_name'] ?? json['sub_specialty'];
    final subName = (rawSub != null && rawSub.toString().isNotEmpty && rawSub != '-') ? LocationResolver.resolveSpecialtyName(rawSub.toString()) : null;
    return HcpSpecialty(
      hcpSpecialty: specName.isNotEmpty ? specName : rawSpec.toString(),
      subSpecialty: subName ?? (rawSub != null ? rawSub.toString() : null),
      isPrimary: json['is_primary'] == 1 || json['is_primary'] == true || json['preferred'] == 1 || json['preferred'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hcp_specialty': hcpSpecialty,
      if (subSpecialty != null) 'sub_specialty': subSpecialty,
      'is_primary': isPrimary ? 1 : 0,
      'preferred': isPrimary ? 1 : 0,
    };
  }
}

class HcpWorkplace {
  final String workplace; // Link -> Institution
  final String? provinceName;
  final String? cityMunicipality;
  final String? address; // Street address / details
  final bool isPrimary;

  HcpWorkplace({
    required this.workplace,
    this.provinceName,
    this.cityMunicipality,
    this.address,
    this.isPrimary = false,
  });

  factory HcpWorkplace.fromJson(Map<String, dynamic> json) {
    final rawWp = json['workplace_name'] ?? json['workplace'] ?? json['hcp_workplace'] ?? '';
    final wpName = LocationResolver.resolveInstitutionName(rawWp.toString());
    final rawProv = json['province_name'] ?? json['province'];
    final rawCity = json['city_municipality'] ?? json['city'];
    return HcpWorkplace(
      workplace: wpName.isNotEmpty ? wpName : rawWp.toString(),
      provinceName: rawProv != null ? LocationResolver.resolveProvinceName(rawProv.toString()) : null,
      cityMunicipality: rawCity != null ? LocationResolver.resolveCityName(rawCity.toString()) : null,
      address: json['address'] ?? json['workplace_name'],
      isPrimary: json['is_primary'] == 1 || json['is_primary'] == true || json['preferred'] == 1 || json['preferred'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hcp_workplace': workplace,
      if (provinceName != null) 'province_name': provinceName,
      if (cityMunicipality != null) 'city_municipality': cityMunicipality,
      if (address != null) 'address': address,
      'is_primary': isPrimary ? 1 : 0,
      'preferred': isPrimary ? 1 : 0,
    };
  }
}

class HcpContact {
  final String? contactNumber;
  final String? emailAddress;
  final bool isPrimary;

  // Compatibility getters for legacy references
  String get contactValue => contactNumber ?? emailAddress ?? '';
  String get contactType => (emailAddress != null && emailAddress!.isNotEmpty) ? 'Email' : 'Mobile';

  HcpContact({
    String? contactNumber,
    String? emailAddress,
    String? contactType,
    String? contactValue,
    this.isPrimary = false,
  }) : this.contactNumber = contactNumber ?? (contactType == 'Email' ? null : contactValue),
       this.emailAddress = emailAddress ?? (contactType == 'Email' ? contactValue : null);

  factory HcpContact.fromJson(Map<String, dynamic> json) {
    String? num = json['contact_number'] ?? json['mobile_number'] ?? json['phone_number'];
    String? email = json['email_address'] ?? json['email'];
    
    // Legacy fallback if contact_type / contact_value was stored
    if (num == null && email == null && json['contact_value'] != null) {
      final val = '${json['contact_value']}';
      if (val.contains('@')) {
        email = val;
      } else {
        num = val;
      }
    }

    final pref = json['is_primary'] == 1 || json['is_primary'] == true || json['preferred'] == 1 || json['preferred'] == true;

    return HcpContact(
      contactNumber: num,
      emailAddress: email,
      isPrimary: pref,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (contactNumber != null) 'contact_number': contactNumber,
      if (emailAddress != null) 'email_address': emailAddress,
      'is_primary': isPrimary ? 1 : 0,
      'preferred': isPrimary ? 1 : 0,
    };
  }
}
