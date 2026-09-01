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
  });

  factory Institution.fromJson(Map<String, dynamic> json) {
    final rawCity = (json['city_municipality'] ?? json['city'] ?? json['city_title'])?.toString();
    final rawProv = (json['province_name'] ?? json['province'] ?? json['province_title'])?.toString();
    final rawReg = (json['region_name'] ?? json['region'] ?? json['region_title'])?.toString();
    final rawInstName = json['institution_name'] ?? json['institution'] ?? json['name'] ?? '';
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
  final String name; // e.g. "AD0110"
  final String territoryName; // e.g. "AD0110 - Manila North"
  final String territoryManager; // e.g. "Jorge Mengorio"
  final String? program;

  TerritoryInfo({
    required this.name,
    required this.territoryName,
    required this.territoryManager,
    this.program,
  });

  factory TerritoryInfo.fromJson(Map<String, dynamic> json) {
    final tName = (json['territory_name'] ?? json['name'] ?? '').toString().trim();
    final manager = (json['territory_manager'] ?? json['sales_person'] ?? json['manager'] ?? json['custom_territory_manager'] ?? '').toString().trim();
    return TerritoryInfo(
      name: json['name'] ?? '',
      territoryName: tName.isNotEmpty ? tName : (json['name'] ?? ''),
      territoryManager: manager.isNotEmpty ? manager : 'Jorge Mengorio',
      program: json['program'] ?? json['account_or_program'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'territory_name': territoryName,
      'territory_manager': territoryManager,
      if (program != null) 'program': program,
    };
  }
}

class GeographicUnit {
  final String name;
  final String code;

  const GeographicUnit(this.name, this.code);
}

/// Centralized resolver that translates ERPNext IDs (SPEC-XXXX, INST-XXXX) and
/// PSGC numeric location codes (e.g. 0301400000 -> Bulacan) to human-readable names.
class LocationResolver {
  // In-memory dynamic registries populated from API fetches
  static final Map<String, String> _dynamicSpecialties = {};
  static final Map<String, String> _dynamicInstitutions = {};
  static final Map<String, String> _dynamicPsgcLocations = {};
  static final Map<String, String> _dynamicHcpTypes = {};

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
    GeographicUnit('Metro Manila-Manila', '1376000000'),
    GeographicUnit('Metro Manila-Makati', '1376020000'),
    GeographicUnit('Metro Manila-Pasig', '1376030000'),
    GeographicUnit('Metro Manila-Quezon City', '1374040000'),
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
    GeographicUnit('Quiapo / Sampaloc, Manila', '1380602000'),
    GeographicUnit('Binondo, Manila', '1380601000'),
    GeographicUnit('San Nicolas, Manila', '1380603000'),
    GeographicUnit('Santa Cruz, Manila', '1380604000'),
    GeographicUnit('Tondo, Manila', '1380605000'),
    GeographicUnit('Ermita, Manila', '1380606000'),
    GeographicUnit('Intramuros, Manila', '1380607000'),
    GeographicUnit('Paco, Manila', '1380609000'),
    GeographicUnit('Pandacan, Manila', '1380610000'),
    GeographicUnit('Port Area, Manila', '1380611000'),
    GeographicUnit('Santa Ana, Manila', '1380612000'),
    GeographicUnit('Santa Mesa, Manila', '1380613000'),
    GeographicUnit('Sampaloc, Manila', '1380614000'),
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
    GeographicUnit('Pateros', '1381300000'),
    GeographicUnit('Quezon City', '1381400000'),
    GeographicUnit('San Juan City', '1381500000'),
    GeographicUnit('Taguig City', '1381600000'),
    GeographicUnit('Valenzuela City', '1381700000'),
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
      if (i.name.isNotEmpty && i.institutionName.isNotEmpty) {
        _dynamicInstitutions[i.name] = i.institutionName;
        _dynamicInstitutions[i.name.toLowerCase()] = i.institutionName;
      }
    }
  }

  static void registerPsgcLocations(Iterable<PsgcLocation> list) {
    for (var p in list) {
      if (p.name.isNotEmpty && p.locationLabel.isNotEmpty) {
        _dynamicPsgcLocations[p.name] = p.locationLabel;
        _dynamicPsgcLocations[p.name.toLowerCase()] = p.locationLabel;
        if (p.psgcCode != null && p.psgcCode!.isNotEmpty) {
          _dynamicPsgcLocations[p.psgcCode!] = p.locationLabel;
          _dynamicPsgcLocations[p.psgcCode!.toLowerCase()] = p.locationLabel;
        }
      }
    }
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
    if (digitsOnly.startsWith('13812') || digitsOnly.startsWith('137603')) return 'Pasig City';
    if (digitsOnly.startsWith('13803') || digitsOnly.startsWith('137602')) return 'Makati City';
    if (digitsOnly.startsWith('13814') || digitsOnly.startsWith('1374')) return 'Quezon City';
    if (digitsOnly.startsWith('13811')) return 'Pasay City';
    if (digitsOnly.startsWith('13810')) return 'Parañaque City';
    if (digitsOnly.startsWith('13808')) return 'Muntinlupa City';
    if (digitsOnly.startsWith('13807')) return 'Marikina City';
    if (digitsOnly.startsWith('13805')) return 'Mandaluyong City';
    if (digitsOnly.startsWith('13816')) return 'Taguig City';
    if (digitsOnly.startsWith('13801')) return 'Caloocan City';
    if (digitsOnly.startsWith('13804')) return 'Malabon City';
    if (digitsOnly.startsWith('13809')) return 'Navotas City';
    if (digitsOnly.startsWith('13817')) return 'Valenzuela City';
    if (digitsOnly.startsWith('13815')) return 'San Juan City';
    if (digitsOnly.startsWith('13802')) return 'Las Piñas City';
    if (digitsOnly.startsWith('13813')) return 'Pateros';
    if (digitsOnly.startsWith('137601')) return 'City of Manila';

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
      if (found.name.isNotEmpty) return found.name;
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

    // If it already starts with INST-, return it
    if (trimmed.toUpperCase().startsWith('INST-')) {
      return trimmed.toUpperCase();
    }

    return trimmed;
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
      return '1376000000';
    }
    if (lower == 'metro manila-makati' || lower == 'makati') {
      return '1376020000';
    }
    if (lower == 'metro manila-pasig' || lower == 'pasig') {
      return '1376030000';
    }
    if (lower == 'metro manila-quezon city' || lower == 'quezon city' || lower == 'qc') {
      return '1374040000';
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
    if (lower == 'ermita' || lower == 'malate' || lower == 'tondo' || lower == 'binondo' ||
        lower == 'intramuros' || lower == 'sampaloc' || lower == 'santa cruz' || lower == 'sta cruz' ||
        lower == 'paco' || lower == 'pandacan' || lower == 'san miguel' || lower == 'san nicolas' ||
        lower == 'port area' || lower == 'santa ana' || lower == 'sta ana' || lower == 'city of manila' ||
        lower == 'manila city' || lower == 'manila') {
      return '133900000'; // City of Manila PSGC Code
    }
    if (lower == 'makati' || lower == 'makati city') {
      return '1376020000';
    }
    if (lower == 'quezon city' || lower == 'qc') {
      return '1374040000';
    }
    if (lower == 'pasig' || lower == 'pasig city') {
      return '1376030000';
    }
    if (lower == 'taguig' || lower == 'taguig city' || lower == 'bgc' || lower == 'bonifacio global city') {
      return '1376070000';
    }
    if (lower == 'mandaluyong' || lower == 'mandaluyong city') {
      return '1374010000';
    }
    if (lower == 'marikina' || lower == 'marikina city') {
      return '1374020000';
    }
    if (lower == 'pasay' || lower == 'pasay city') {
      return '1376050000';
    }
    if (lower == 'paranaque' || lower == 'parañaque' || lower == 'paranaque city') {
      return '1376040000';
    }
    if (lower == 'las pinas' || lower == 'las piñas' || lower == 'las pinas city') {
      return '1376010000';
    }
    if (lower == 'muntinlupa' || lower == 'muntinlupa city') {
      return '1376030000';
    }
    if (lower == 'caloocan' || lower == 'caloocan city') {
      return '1375010000';
    }
    if (lower == 'malabon' || lower == 'malabon city') {
      return '1375020000';
    }
    if (lower == 'navotas' || lower == 'navotas city') {
      return '1375030000';
    }
    if (lower == 'valenzuela' || lower == 'valenzuela city') {
      return '1375040000';
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
    }

    return trimmed;
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
      return 'Bayer Consumer Health - Team 1';
    }
    if (lower.contains('fonterra anlene')) {
      return 'FONTERRA ANLENE';
    }
    if (lower.contains('fonterra anmum')) {
      return 'FONTERRA ANMUM';
    }
    if (lower.contains('gsk')) {
      return 'GSK HCP Profiling';
    }
    return trimmed;
  }
}
