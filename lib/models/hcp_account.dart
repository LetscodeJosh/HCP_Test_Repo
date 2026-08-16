class HcpAccount {
  final String? name;
  final String accountName; // Map to account_or_program
  final String? territory;
  final String? salesPerson;
  final String? accountType;
  final String? userId;
  final bool isActive;
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
    this.hcp,
    this.hcpName,
    this.specialties = const [],
    this.workplaces = const [],
    this.contacts = const [],
  });

  factory HcpAccount.fromJson(Map<String, dynamic> json) {
    return HcpAccount(
      name: json['name'],
      accountName: json['account_or_program'] ?? json['account_name'] ?? '',
      territory: json['territory'] ?? json['territory_mr_code'],
      salesPerson: json['sales_person'] ?? json['territory_manager'],
      accountType: json['account_type'],
      userId: json['user_id'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
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
      if (salesPerson != null) 'sales_person': salesPerson,
      if (accountType != null) 'account_type': accountType,
      if (userId != null) 'user_id': userId,
      'is_active': isActive ? 1 : 0,
      if (hcp != null) 'hcp': hcp,
      if (hcpName != null) 'hcp_name': hcpName,
      if (specialties.isNotEmpty) 'specialization': specialties.map((e) => e.toJson()).toList(),
      if (workplaces.isNotEmpty) 'workplace_info': workplaces.map((e) => e.toJson()).toList(),
      if (contacts.isNotEmpty) 'contact_info': contacts.map((e) => e.toJson()).toList(),
    };
  }
}

class HcpAccountSpecialization {
  final String specialty;
  final String? subSpecialty;

  HcpAccountSpecialization({
    required this.specialty,
    this.subSpecialty,
  });

  factory HcpAccountSpecialization.fromJson(Map<String, dynamic> json) {
    return HcpAccountSpecialization(
      specialty: json['specialty'] ?? '',
      subSpecialty: json['sub_specialty'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'specialty': specialty,
      if (subSpecialty != null) 'sub_specialty': subSpecialty,
    };
  }
}

class HcpAccountWorkplace {
  final String workplace;
  final String? cityMunicipality;
  final String? provinceName;
  final String? address;
  final bool isPrimary;

  // Compatibility getters
  String? get city => cityMunicipality;
  String? get province => provinceName;

  HcpAccountWorkplace({
    required this.workplace,
    this.cityMunicipality,
    this.provinceName,
    String? city,
    String? province,
    this.address,
    this.isPrimary = false,
  }) : this.cityMunicipality = cityMunicipality ?? city,
       this.provinceName = provinceName ?? province;

  factory HcpAccountWorkplace.fromJson(Map<String, dynamic> json) {
    return HcpAccountWorkplace(
      workplace: json['workplace'] ?? json['workplace_name'] ?? '',
      cityMunicipality: json['city_municipality'] ?? json['city'] ?? json['city_title'],
      provinceName: json['province_name'] ?? json['province'] ?? json['province_title'],
      address: json['address'],
      isPrimary: json['is_primary'] == 1 || json['is_primary'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workplace': workplace,
      if (cityMunicipality != null) 'city_municipality': cityMunicipality,
      if (provinceName != null) 'province_name': provinceName,
      if (address != null) 'address': address,
      'is_primary': isPrimary ? 1 : 0,
    };
  }
}

class HcpAccountContact {
  final String? contactNumber;
  final String? emailAddress;

  // Compatibility getters
  String get contactValue => contactNumber ?? emailAddress ?? '';
  String get contactType => (emailAddress != null && emailAddress!.isNotEmpty) ? 'Email' : 'Mobile';

  HcpAccountContact({
    this.contactNumber,
    this.emailAddress,
    String? contactType,
    String? contactValue,
  }) : this.contactNumber = contactNumber ?? (contactType == 'Email' ? null : contactValue),
       this.emailAddress = emailAddress ?? (contactType == 'Email' ? contactValue : null);

  factory HcpAccountContact.fromJson(Map<String, dynamic> json) {
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (contactNumber != null) 'contact_number': contactNumber,
      if (emailAddress != null) 'email_address': emailAddress,
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
