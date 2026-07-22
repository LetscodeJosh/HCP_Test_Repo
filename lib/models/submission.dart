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
  final String? surveyTemplate; // Link -> HCP Survey Template
  final String? surveyTemplateTitle;
  final String? medrepEmail; // Link -> User
  final String? submissionDate;
  final String? surveyResponse; // Link -> HCP Survey Response
  final List<SubmissionAnswer> answers; // Table -> HCP Profile Submission Answer
  final String? applicationStatus; // Not Applied, Applying, Applied, Failed
  final String? changeSummaryHtml;
  final String? changesJson;
  final int docstatus; // 0: Draft, 1: Submitted, 2: Cancelled

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
    this.surveyTemplate,
    this.surveyTemplateTitle,
    this.medrepEmail,
    this.submissionDate,
    this.surveyResponse,
    this.answers = const [],
    this.applicationStatus,
    this.changeSummaryHtml,
    this.changesJson,
    this.docstatus = 0,
  });

  factory HcpProfileSubmission.fromJson(Map<String, dynamic> json) {
    return HcpProfileSubmission(
      name: json['name'],
      hcpName: json['hcp_name'] ?? '',
      hcpFullName: json['hcp_full_name'],
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
      specialties: (json['table_specialties'] as List?)
              ?.map((e) => SubmissionSpecialty.fromJson(e))
              .toList() ?? [],
      workplaces: (json['table_workplaces'] as List?)
              ?.map((e) => SubmissionWorkplace.fromJson(e))
              .toList() ?? [],
      contacts: (json['table_contact_info'] as List?)
              ?.map((e) => SubmissionContact.fromJson(e))
              .toList() ?? [],
      regionName: json['region_name'],
      provinceName: json['province_name'],
      cityMunicipality: json['city_municipality'],
      barangayName: json['barangay_name'],
      institution: json['institution'],
      accountOrProgram: json['account_or_program'],
      surveyTemplate: json['survey_template'],
      surveyTemplateTitle: json['survey_template_title'],
      medrepEmail: json['medrep_email'],
      submissionDate: json['submission_date'],
      surveyResponse: json['survey_response'],
      answers: (json['answers'] as List?)
              ?.map((e) => SubmissionAnswer.fromJson(e))
              .toList() ?? [],
      applicationStatus: json['application_status'],
      changeSummaryHtml: json['change_summary_html'],
      changesJson: json['changes_json'],
      docstatus: json['docstatus'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      'hcp_name': hcpName,
      if (hcpFullName != null) 'hcp_full_name': hcpFullName,
      if (firstName != null) 'first_name': firstName,
      if (middleName != null) 'middle_name': middleName,
      if (lastName != null) 'last_name': lastName,
      if (birthDate != null) 'birth_date': birthDate,
      'consent_privacy_understood': consentPrivacyUnderstood ? 1 : 0,
      if (consentSignature != null) 'consent_signature': consentSignature,
      if (consentPhoto != null) 'consent_photo': consentPhoto,
      if (hcpPhoto != null) 'hcp_photo': hcpPhoto,
      if (hcpType != null) 'hcp_type': hcpType,
      if (hcpPractice != null) 'hcp_practice': hcpPractice,
      'table_specialties': specialties.map((e) => e.toJson()).toList(),
      'table_workplaces': workplaces.map((e) => e.toJson()).toList(),
      'table_contact_info': contacts.map((e) => e.toJson()).toList(),
      if (regionName != null) 'region_name': regionName,
      if (provinceName != null) 'province_name': provinceName,
      if (cityMunicipality != null) 'city_municipality': cityMunicipality,
      if (barangayName != null) 'barangay_name': barangayName,
      if (institution != null) 'institution': institution,
      if (accountOrProgram != null) 'account_or_program': accountOrProgram,
      if (surveyTemplate != null) 'survey_template': surveyTemplate,
      if (surveyTemplateTitle != null) 'survey_template_title': surveyTemplateTitle,
      if (medrepEmail != null) 'medrep_email': medrepEmail,
      if (submissionDate != null) 'submission_date': submissionDate,
      if (surveyResponse != null) 'survey_response': surveyResponse,
      'answers': answers.map((e) => e.toJson()).toList(),
      if (applicationStatus != null) 'application_status': applicationStatus,
      if (changeSummaryHtml != null) 'change_summary_html': changeSummaryHtml,
      if (changesJson != null) 'changes_json': changesJson,
      'docstatus': docstatus,
    };
  }
}

class SubmissionSpecialty {
  final String? hcpSpecialty; // Link -> Specialization
  final String? specialtyName;
  final String? subSpecialty; // Link -> Specialization
  final String? subSpecialtyName;

  SubmissionSpecialty({
    this.hcpSpecialty,
    this.specialtyName,
    this.subSpecialty,
    this.subSpecialtyName,
  });

  factory SubmissionSpecialty.fromJson(Map<String, dynamic> json) {
    return SubmissionSpecialty(
      hcpSpecialty: json['hcp_specialty'],
      specialtyName: json['specialty_name'],
      subSpecialty: json['sub_specialty'],
      subSpecialtyName: json['sub_specialty_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (hcpSpecialty != null) 'hcp_specialty': hcpSpecialty,
      if (specialtyName != null) 'specialty_name': specialtyName,
      if (subSpecialty != null) 'sub_specialty': subSpecialty,
      if (subSpecialtyName != null) 'sub_specialty_name': subSpecialtyName,
    };
  }
}

class SubmissionWorkplace {
  final String? hcpWorkplace; // Link -> Institution
  final String? workplaceName;
  final String? cityMunicipality;
  final String? cityTitle;
  final String? provinceName;
  final String? provinceTitle;

  SubmissionWorkplace({
    this.hcpWorkplace,
    this.workplaceName,
    this.cityMunicipality,
    this.cityTitle,
    this.provinceName,
    this.provinceTitle,
  });

  factory SubmissionWorkplace.fromJson(Map<String, dynamic> json) {
    return SubmissionWorkplace(
      hcpWorkplace: json['hcp_workplace'] ?? json['workplace'],
      workplaceName: json['workplace_name'] ?? json['address'],
      cityMunicipality: json['city_municipality'],
      cityTitle: json['city_title'],
      provinceName: json['province_name'],
      provinceTitle: json['province_title'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (hcpWorkplace != null) 'hcp_workplace': hcpWorkplace,
      if (workplaceName != null) 'workplace_name': workplaceName,
      if (cityMunicipality != null) 'city_municipality': cityMunicipality,
      if (cityTitle != null) 'city_title': cityTitle,
      if (provinceName != null) 'province_name': provinceName,
      if (provinceTitle != null) 'province_title': provinceTitle,
    };
  }
}

class SubmissionContact {
  final String? contactNumber;
  final String? emailAddress;

  SubmissionContact({
    this.contactNumber,
    this.emailAddress,
  });

  factory SubmissionContact.fromJson(Map<String, dynamic> json) {
    return SubmissionContact(
      contactNumber: json['contact_number'] ?? json['contact_value'],
      emailAddress: json['email_address'] ?? json['contact_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
    return {
      'survey_question': surveyQuestion,
      'question_text': questionText,
      'answer': answer,
    };
  }
}
