class Institution {
  final String name; // e.g. INST-00001
  final String institutionName;
  final String? regionName;
  final String? provinceName;
  final String? cityMunicipality;
  final String? barangayName;
  final String? streetAddress;

  Institution({
    required this.name,
    required this.institutionName,
    this.regionName,
    this.provinceName,
    this.cityMunicipality,
    this.barangayName,
    this.streetAddress,
  });

  factory Institution.fromJson(Map<String, dynamic> json) {
    final rawCity = json['city_municipality'] ?? json['city'] ?? json['city_title'];
    final rawProv = json['province_name'] ?? json['province'] ?? json['province_title'];
    final rawReg = json['region_name'] ?? json['region'] ?? json['region_title'];
    final rawInstName = json['institution_name'] ?? json['institution'] ?? json['name'] ?? '';
    return Institution(
      name: json['name'] ?? '',
      institutionName: LocationResolver.resolveInstitutionName(rawInstName.toString()),
      regionName: rawReg != null ? LocationResolver.resolveRegionName(rawReg.toString()) : null,
      provinceName: rawProv != null ? LocationResolver.resolveProvinceName(rawProv.toString()) : null,
      cityMunicipality: rawCity != null ? LocationResolver.resolveCityName(rawCity.toString()) : null,
      barangayName: json['barangay_name'],
      streetAddress: json['street_address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'institution_name': institutionName,
      if (regionName != null) 'region_name': regionName,
      if (provinceName != null) 'province_name': provinceName,
      if (cityMunicipality != null) 'city_municipality': cityMunicipality,
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
    return HcpType(
      name: json['name'] ?? '',
      typeName: json['hcp_type'] ?? json['type_name'] ?? json['name'] ?? '',
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
    GeographicUnit('Ermita', '137601000'),
    GeographicUnit('Malate', '137602000'),
    GeographicUnit('Intramuros', '137603000'),
    GeographicUnit('Makati City', '137602000'),
    GeographicUnit('Quezon City', '137404000'),
    GeographicUnit('Pasig City', '137603000'),
    GeographicUnit('Laoag City', '0102812000'),
    GeographicUnit('Vigan City', '0102921000'),
    GeographicUnit('Cavite City', '0402105000'),
    GeographicUnit('Bacoor', '0402102000'),
    GeographicUnit('Imus', '0402111000'),
    GeographicUnit('Dasmariñas', '0402106000'),
    GeographicUnit('Cebu City', '0702217000'),
    GeographicUnit('Davao City', '1102404000'),
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
      if (match.locationLabel.isNotEmpty) return match.locationLabel;
    }

    // 2. Check in-memory registered PSGC locations
    if (_dynamicPsgcLocations.containsKey(trimmed)) {
      return _dynamicPsgcLocations[trimmed]!;
    }
    if (_dynamicPsgcLocations.containsKey(trimmed.toLowerCase())) {
      return _dynamicPsgcLocations[trimmed.toLowerCase()]!;
    }

    // Extract digits for numeric matching (e.g. "0301400000" or "PRV-0301400000")
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');

    // 3. Check standard provinces list
    for (var p in standardProvinces) {
      if (p.code == trimmed || p.name.toLowerCase() == trimmed.toLowerCase()) {
        return p.name;
      }
      if (digitsOnly.isNotEmpty && (p.code == digitsOnly || digitsOnly.startsWith(p.code))) {
        return p.name;
      }
      // Check prefix (first 4 or 5 digits of PSGC code)
      if (digitsOnly.length >= 4 && p.code.length >= 4 && p.code.substring(0, 4) == digitsOnly.substring(0, 4)) {
        return p.name;
      }
    }

    // If not digits only, it is likely already human readable
    final isAllDigits = RegExp(r'^\d+$').hasMatch(trimmed);
    if (!isAllDigits) {
      return trimmed;
    }

    return trimmed;
  }

  /// Resolve a City/Municipality PSGC code or name
  static String resolveCityName(String? raw, [List<PsgcLocation>? dynamicLocations]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '';
    final trimmed = raw.trim();

    if (dynamicLocations != null && dynamicLocations.isNotEmpty) {
      final match = dynamicLocations.firstWhere(
        (loc) => loc.name == trimmed || loc.psgcCode == trimmed || loc.name.toLowerCase() == trimmed.toLowerCase(),
        orElse: () => PsgcLocation(name: '', locationLabel: '', locationType: ''),
      );
      if (match.locationLabel.isNotEmpty) return match.locationLabel;
    }

    if (_dynamicPsgcLocations.containsKey(trimmed)) {
      return _dynamicPsgcLocations[trimmed]!;
    }
    if (_dynamicPsgcLocations.containsKey(trimmed.toLowerCase())) {
      return _dynamicPsgcLocations[trimmed.toLowerCase()]!;
    }

    for (var c in standardCities) {
      if (c.code == trimmed || c.name.toLowerCase() == trimmed.toLowerCase()) {
        return c.name;
      }
    }

    final isAllDigits = RegExp(r'^\d+$').hasMatch(trimmed);
    if (!isAllDigits) {
      return trimmed;
    }

    return trimmed;
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
      if (match.locationLabel.isNotEmpty) return match.locationLabel;
    }

    if (_dynamicPsgcLocations.containsKey(trimmed)) {
      return _dynamicPsgcLocations[trimmed]!;
    }
    if (_dynamicPsgcLocations.containsKey(trimmed.toLowerCase())) {
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
    if (!isAllDigits) {
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

  /// Resolve a Province name (e.g. "Bulacan") to its ERPNext Link ID / PSGC Code (e.g. "0301400000")
  static String resolveProvinceId(String? raw, [List<PsgcLocation>? dynamicLocations]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '';
    final trimmed = raw.trim();

    // 1. Check dynamic locations
    if (dynamicLocations != null && dynamicLocations.isNotEmpty) {
      final match = dynamicLocations.firstWhere(
        (loc) => loc.locationLabel.toLowerCase() == trimmed.toLowerCase() || loc.name.toLowerCase() == trimmed.toLowerCase() || (loc.psgcCode != null && loc.psgcCode == trimmed),
        orElse: () => PsgcLocation(name: '', locationLabel: '', locationType: ''),
      );
      if (match.name.isNotEmpty) return match.name;
    }

    // 2. Check in-memory registered PSGC locations
    for (var entry in _dynamicPsgcLocations.entries) {
      if (entry.value.toLowerCase() == trimmed.toLowerCase()) {
        return entry.key;
      }
    }

    // 3. Check standard provinces list
    for (var p in standardProvinces) {
      if (p.name.toLowerCase() == trimmed.toLowerCase() || p.code == trimmed) {
        return p.code;
      }
    }

    return trimmed;
  }

  /// Resolve a City/Municipality name (e.g. "Ermita") to its ERPNext Link ID / PSGC Code
  static String resolveCityId(String? raw, [List<PsgcLocation>? dynamicLocations]) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return '';
    final trimmed = raw.trim();

    if (dynamicLocations != null && dynamicLocations.isNotEmpty) {
      final match = dynamicLocations.firstWhere(
        (loc) => loc.locationLabel.toLowerCase() == trimmed.toLowerCase() || loc.name.toLowerCase() == trimmed.toLowerCase() || (loc.psgcCode != null && loc.psgcCode == trimmed),
        orElse: () => PsgcLocation(name: '', locationLabel: '', locationType: ''),
      );
      if (match.name.isNotEmpty) return match.name;
    }

    for (var entry in _dynamicPsgcLocations.entries) {
      if (entry.value.toLowerCase() == trimmed.toLowerCase()) {
        return entry.key;
      }
    }

    for (var c in standardCities) {
      if (c.name.toLowerCase() == trimmed.toLowerCase() || c.code == trimmed) {
        return c.code;
      }
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
