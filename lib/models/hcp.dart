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
    return Hcp(
      name: json['name'],
      hcpFullName: json['hcp_full_name'] ?? json['full_name'],
      firstName: json['first_name'] ?? '',
      middleName: json['middle_name'],
      lastName: json['last_name'] ?? '',
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
      regionName: json['region_name'],
      provinceName: json['province_name'],
      cityMunicipality: json['city_municipality'],
      barangayName: json['barangay_name'],
      institution: json['institution'],
      profileLastUpdated: json['profile_last_updated'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'first_name': firstName,
      if (middleName != null) 'middle_name': middleName,
      'last_name': lastName,
      if (hcpFullName != null) 'hcp_full_name': hcpFullName,
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

  HcpSpecialty({
    required this.hcpSpecialty,
    this.subSpecialty,
  });

  factory HcpSpecialty.fromJson(Map<String, dynamic> json) {
    return HcpSpecialty(
      hcpSpecialty: json['hcp_specialty'] ?? json['specialty'] ?? json['specialty_name'] ?? '',
      subSpecialty: json['sub_specialty'] ?? json['sub_specialty_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hcp_specialty': hcpSpecialty,
      if (subSpecialty != null) 'sub_specialty': subSpecialty,
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
    return HcpWorkplace(
      workplace: json['hcp_workplace'] ?? json['workplace'] ?? json['workplace_name'] ?? '',
      provinceName: json['province_name'] ?? json['province'],
      cityMunicipality: json['city_municipality'] ?? json['city'],
      address: json['address'] ?? json['workplace_name'],
      isPrimary: json['is_primary'] == 1 || json['is_primary'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hcp_workplace': workplace,
      if (provinceName != null) 'province_name': provinceName,
      if (cityMunicipality != null) 'city_municipality': cityMunicipality,
      if (address != null) 'address': address,
      'is_primary': isPrimary ? 1 : 0,
    };
  }
}

class HcpContact {
  final String? contactNumber;
  final String? emailAddress;

  // Compatibility getters for legacy references
  String get contactValue => contactNumber ?? emailAddress ?? '';
  String get contactType => (emailAddress != null && emailAddress!.isNotEmpty) ? 'Email' : 'Mobile';

  HcpContact({
    this.contactNumber,
    this.emailAddress,
    String? contactType,
    String? contactValue,
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

    return HcpContact(
      contactNumber: num,
      emailAddress: email,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (contactNumber != null) 'contact_number': contactNumber,
      if (emailAddress != null) 'email_address': emailAddress,
    };
  }
}
