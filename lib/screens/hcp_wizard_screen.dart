import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/hcp.dart';
import '../models/hcp_account.dart';
import '../models/submission.dart';
import '../models/lookup_models.dart';
import '../services/api_service.dart';
import 'hcp_dashboard_screen.dart';

class HcpWizardScreen extends StatefulWidget {
  final Hcp? doctor;

  const HcpWizardScreen({Key? key, this.doctor}) : super(key: key);

  @override
  State<HcpWizardScreen> createState() => _HcpWizardScreenState();
}

class _HcpWizardScreenState extends State<HcpWizardScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Consent State
  bool _consentGiven = false;
  final ValueNotifier<List<Offset>> _signaturePoints = ValueNotifier<List<Offset>>([]);
  XFile? _consentPhotoFile;
  Uint8List? _consentPhotoBytes;

  // Step 2: Doctor Info & Selection State
  Hcp? _selectedDoctor;
  String? _doctorPhotoUrl;
  Uint8List? _doctorPhotoBytes;
  XFile? _doctorPhotoFile;
  late TextEditingController _hcpFullNameController;
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _birthDateController;
  
  String? _selectedHcpType;
  String _selectedPractice = 'Both';
  
  final List<SubmissionSpecialty> _selectedSpecialties = [];
  final List<SubmissionWorkplace> _selectedWorkplaces = [];
  final List<SubmissionContact> _contacts = [];

  // Step 3: Survey State
  final Map<String, String> _surveyAnswers = {};
  String _selectedProgram = 'Abbott Diabetes Care';
  List<String> _programs = [];

  // Others Tab State
  late TextEditingController _territoryManagerController;
  String _selectedTerritory = 'AD0110';
  List<String> _territories = [];
  DateTime _submissionDate = DateTime.now();
  String _applicationStatus = 'Not Applied';

  // Lookups
  List<Hcp> _allDoctors = [];
  List<Institution> _institutions = [];
  List<Specialization> _specializations = [];
  List<HcpType> _hcpTypes = [];
  List<HcpSurveyTemplate> _allSurveyTemplates = [];
  HcpSurveyTemplate? _activeSurvey;

  @override
  void initState() {
    super.initState();
    _selectedDoctor = widget.doctor;
    _territoryManagerController = TextEditingController(text: 'Jorge Mengorio');
    _hcpFullNameController = TextEditingController(
      text: widget.doctor != null ? '${widget.doctor!.firstName} ${widget.doctor!.middleName != null && widget.doctor!.middleName != '-' ? widget.doctor!.middleName! + ' ' : ''}${widget.doctor!.lastName}' : '',
    );
    _firstNameController = TextEditingController(text: widget.doctor?.firstName ?? '');
    _middleNameController = TextEditingController(text: widget.doctor?.middleName ?? '');
    _lastNameController = TextEditingController(text: widget.doctor?.lastName ?? '');
    _birthDateController = TextEditingController(text: widget.doctor?.birthDate ?? '');
    _selectedHcpType = widget.doctor?.hcpType;
    _selectedPractice = widget.doctor?.hcpPractice ?? 'Both';

    if (widget.doctor != null) {
      _prepopulateDoctorData(widget.doctor!);
    }

    _loadLookups();
  }

  Future<void> _prepopulateDoctorData(Hcp doctor) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    Hcp fullDoctor = doctor;
    if (doctor.name != null) {
      try {
        fullDoctor = await apiService.fetchDoctorDetail(doctor.name!);
      } catch (e) {
        print('Error fetching doctor detail: $e');
      }
    }

    final Map<String, String> specLookup = {};
    for (var s in _specializations) {
      specLookup[s.name] = s.specialty;
    }

    final Map<String, String> instLookup = {};
    for (var inst in _institutions) {
      instLookup[inst.name] = inst.institutionName;
    }

    setState(() {
      _selectedSpecialties.clear();
      _selectedWorkplaces.clear();
      _contacts.clear();

      _doctorPhotoUrl = fullDoctor.hcpPhoto;
      _doctorPhotoBytes = null;
      _doctorPhotoFile = null;

      _hcpFullNameController.text = '${fullDoctor.firstName} ${fullDoctor.middleName != null && fullDoctor.middleName != '-' ? fullDoctor.middleName! + ' ' : ''}${fullDoctor.lastName}'.trim();
      _firstNameController.text = fullDoctor.firstName;
      _middleNameController.text = (fullDoctor.middleName != null && fullDoctor.middleName != '-') ? fullDoctor.middleName! : '';
      _lastNameController.text = fullDoctor.lastName;
      _birthDateController.text = fullDoctor.birthDate ?? '';
      _selectedHcpType = fullDoctor.hcpType.isNotEmpty ? fullDoctor.hcpType : 'Resident';
      _selectedPractice = fullDoctor.hcpPractice.isNotEmpty ? fullDoctor.hcpPractice : 'Dispensing';

      if (fullDoctor.specialties.isNotEmpty) {
        for (int i = 0; i < fullDoctor.specialties.length; i++) {
          final spec = fullDoctor.specialties[i];
          final specTitle = specLookup[spec.hcpSpecialty] ?? spec.hcpSpecialty;
          final subSpecTitle = spec.subSpecialty != null ? (specLookup[spec.subSpecialty!] ?? spec.subSpecialty!) : null;
          final isPref = spec.isPrimary;
          _selectedSpecialties.add(SubmissionSpecialty(
            preferred: isPref,
            hcpSpecialty: spec.hcpSpecialty,
            specialtyName: specTitle.isNotEmpty ? specTitle : 'Family Medicine',
            subSpecialty: spec.subSpecialty,
            subSpecialtyName: subSpecTitle ?? 'Sports Medicine',
          ));
        }
      } else {
        _selectedSpecialties.add(SubmissionSpecialty(
          preferred: true,
          hcpSpecialty: 'Family Medicine',
          specialtyName: 'Family Medicine',
          subSpecialty: 'Sports Medicine',
          subSpecialtyName: 'Sports Medicine',
        ));
      }

      if (fullDoctor.workplaces.isNotEmpty) {
        for (int i = 0; i < fullDoctor.workplaces.length; i++) {
          final work = fullDoctor.workplaces[i];
          final instTitle = instLookup[work.workplace] ?? work.address ?? work.workplace;
          final isPref = work.isPrimary;
          _selectedWorkplaces.add(SubmissionWorkplace(
            preferred: isPref,
            hcpWorkplace: work.workplace,
            workplaceName: instTitle.isNotEmpty ? instTitle : 'Manila Doctors Hospital',
            cityTitle: (fullDoctor.cityMunicipality != null && fullDoctor.cityMunicipality!.isNotEmpty) ? fullDoctor.cityMunicipality! : 'Ermita',
            provinceTitle: (fullDoctor.provinceName != null && fullDoctor.provinceName!.isNotEmpty) ? fullDoctor.provinceName! : 'Metro Manila-Manila',
          ));
        }
      } else {
        _selectedWorkplaces.add(SubmissionWorkplace(
          preferred: true,
          hcpWorkplace: 'Manila Doctors Hospital',
          workplaceName: 'Manila Doctors Hospital',
          cityTitle: 'Ermita',
          provinceTitle: 'Metro Manila-Manila',
        ));
      }

      if (fullDoctor.contacts.isNotEmpty) {
        for (int i = 0; i < fullDoctor.contacts.length; i++) {
          final contact = fullDoctor.contacts[i];
          final isPref = contact.isPrimary;
          _contacts.add(SubmissionContact(
            preferred: isPref,
            contactNumber: contact.contactValue.isNotEmpty ? contact.contactValue : '123435',
            emailAddress: contact.contactType,
          ));
        }
      } else {
        _contacts.add(SubmissionContact(
          preferred: true,
          contactNumber: '123435',
          emailAddress: '',
        ));
      }
    });
  }

  void _updateActiveSurveyForProgram(String program) {
    if (_allSurveyTemplates.isNotEmpty) {
      final matched = _allSurveyTemplates.firstWhere(
        (t) => t.isActive && (t.accountOrProgram == program || t.templateName.contains(program)),
        orElse: () => _allSurveyTemplates.firstWhere((t) => t.isActive, orElse: () => _allSurveyTemplates.first),
      );
      setState(() {
        _activeSurvey = matched;
        _surveyAnswers.clear();
        for (var q in matched.questions) {
          _surveyAnswers[q.question] = '';
        }
      });
    }
  }

  Future<void> _loadLookups() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final doctors = await apiService.fetchDoctors().catchError((_) => <Hcp>[]);
      final insts = await apiService.fetchInstitutions().catchError((_) => <Institution>[]);
      final specs = await apiService.fetchSpecializations().catchError((_) => <Specialization>[]);
      final types = await apiService.fetchHcpTypes().catchError((_) => <HcpType>[]);
      final templates = await apiService.fetchSurveyTemplates().catchError((_) => <HcpSurveyTemplate>[]);
      final territories = await apiService.fetchTerritories().catchError((_) => <String>[]);
      final programs = await apiService.fetchPrograms().catchError((_) => <String>[]);

      setState(() {
        _allDoctors = doctors;
        _institutions = insts;
        _specializations = specs;
        _hcpTypes = types;
        _allSurveyTemplates = templates;
        _territories = territories;
        _programs = programs;

        if (_programs.isNotEmpty && !_programs.contains(_selectedProgram)) {
          _selectedProgram = _programs.first;
        }

        if (_territories.isNotEmpty && !_territories.contains(_selectedTerritory)) {
          _selectedTerritory = _territories.first;
        }

        _territoryManagerController.text = apiService.getTerritoryManagerForTerritory(_selectedTerritory);

        if (_hcpTypes.isNotEmpty && (_selectedHcpType == null || _selectedHcpType!.isEmpty)) {
          _selectedHcpType = _hcpTypes.first.name;
        }

        _updateActiveSurveyForProgram(_selectedProgram);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Capture Consent Photo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0066FF)),
              title: const Text('Take Photo with Camera', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF0066FF)),
              title: const Text('Choose from Photo Gallery', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      try {
        final file = await picker.pickImage(source: source, imageQuality: 70);
        if (file != null) {
          final bytes = await file.readAsBytes();
          setState(() {
            _consentPhotoFile = file;
            _consentPhotoBytes = bytes;
          });
        }
      } catch (e) {
        debugPrint('Error picking image: $e');
      }
    }
  }

  void _showPhotoPreviewDialog() {
    if (_consentPhotoBytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF0B192C),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Consent Photo Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.65,
                  ),
                  color: const Color(0xFF0F172A),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Image.memory(
                      _consentPhotoBytes!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 16),
                      label: const Text('Remove Photo', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _consentPhotoFile = null;
                          _consentPhotoBytes = null;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0066FF)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF0066FF), size: 16),
                          label: const Text('Retake', style: TextStyle(color: Color(0xFF0066FF), fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _capturePhoto();
                          },
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B192C),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onDoctorRejectsProfiling() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Doctor Rejects Profiling', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Are you sure the doctor rejects undergoing profiling? The profiling form will exit and redirect you to the Homepage.',
          style: TextStyle(color: Color(0xFF475569), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HcpDashboardScreen()),
                (route) => false,
              );
            },
            child: const Text('Confirm & Exit to Homepage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _pointsToSvgDataUri(List<Offset> points, Size canvasSize) {
    if (points.isEmpty) return '';
    StringBuffer svg = StringBuffer();
    svg.write('<svg xmlns="http://www.w3.org/2000/svg" width="${canvasSize.width}" height="${canvasSize.height}" viewBox="0 0 ${canvasSize.width} ${canvasSize.height}">');
    svg.write('<path d="');
    bool newPath = true;
    for (var point in points) {
      if (point == Offset.infinite) {
        newPath = true;
      } else {
        if (newPath) {
          svg.write('M ${point.dx} ${point.dy} ');
          newPath = false;
        } else {
          svg.write('L ${point.dx} ${point.dy} ');
        }
      }
    }
    svg.write('" fill="none" stroke="black" stroke-width="3" stroke-linecap="round"/>');
    svg.write('</svg>');
    final bytes = utf8.encode(svg.toString());
    return 'data:image/svg+xml;base64,${base64Encode(bytes)}';
  }

  Future<void> _submitForm() async {
    if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First Name and Last Name are required.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);

    final sigUri = _pointsToSvgDataUri(_signaturePoints.value, const Size(300, 150));
    String? uploadedConsentPhotoUrl;
    if (_consentPhotoBytes != null || _consentPhotoFile != null) {
      try {
        final bytes = _consentPhotoBytes ?? await _consentPhotoFile!.readAsBytes();
        uploadedConsentPhotoUrl = await apiService.uploadFile(
          bytes: bytes,
          filename: 'consent_${DateTime.now().millisecondsSinceEpoch}.jpg',
          doctype: 'HCP Profile Submission',
        );
      } catch (e) {
        debugPrint('Upload consent photo error: $e');
      }
    }

    String? uploadedDoctorPhotoUrl = _doctorPhotoUrl;
    if (_doctorPhotoBytes != null) {
      try {
        final docUrl = await apiService.uploadFile(
          bytes: _doctorPhotoBytes!,
          filename: 'hcp_${DateTime.now().millisecondsSinceEpoch}.jpg',
          doctype: 'HCP',
        );
        if (docUrl != null && docUrl.isNotEmpty) {
          uploadedDoctorPhotoUrl = docUrl;
        }
      } catch (e) {
        debugPrint('Upload doctor photo error: $e');
      }
    }

    final List<SubmissionAnswer> answersList = [];
    if (_activeSurvey != null && _activeSurvey!.questions.isNotEmpty) {
      for (var q in _activeSurvey!.questions) {
        final val = _surveyAnswers[q.question]?.trim();
        final ansVal = (val != null && val.isNotEmpty) ? val : 'N/A';
        answersList.add(SubmissionAnswer(
          surveyQuestion: q.question,
          questionText: q.question,
          answer: ansVal,
        ));
      }
    } else if (_surveyAnswers.isNotEmpty) {
      _surveyAnswers.forEach((qText, ansText) {
        if (qText.trim().isNotEmpty) {
          final validAns = ansText.trim().isNotEmpty ? ansText.trim() : 'N/A';
          answersList.add(SubmissionAnswer(
            surveyQuestion: qText.trim(),
            questionText: qText.trim(),
            answer: validAns,
          ));
        }
      });
    }

    // Compute complete doctor full name preserving middle name
    final fn = _firstNameController.text.trim();
    final mn = _middleNameController.text.trim();
    final ln = _lastNameController.text.trim();
    final parts = [
      if (fn.isNotEmpty) fn,
      if (mn.isNotEmpty && mn != '-') mn,
      if (ln.isNotEmpty) ln,
    ];
    final fullDoctorName = parts.where((p) => p.isNotEmpty).join(' ');

    // Compute structured ERPNext v15 changes JSON and HTML summary
    final List<Map<String, dynamic>> basicInfoChanges = [];
    if (_selectedDoctor != null) {
      if (fn != _selectedDoctor!.firstName) {
        basicInfoChanges.add({
          'field': 'first_name',
          'label': 'First Name',
          'operation': 'modified',
          'old': _selectedDoctor!.firstName,
          'new': fn,
        });
      }
      if (mn != (_selectedDoctor!.middleName ?? '')) {
        basicInfoChanges.add({
          'field': 'middle_name',
          'label': 'Middle Name',
          'operation': 'modified',
          'old': _selectedDoctor!.middleName ?? '',
          'new': mn,
        });
      }
      if (ln != _selectedDoctor!.lastName) {
        basicInfoChanges.add({
          'field': 'last_name',
          'label': 'Last Name',
          'operation': 'modified',
          'old': _selectedDoctor!.lastName,
          'new': ln,
        });
      }
      if (_birthDateController.text.trim().isNotEmpty &&
          _birthDateController.text.trim() != (_selectedDoctor!.birthDate ?? '')) {
        basicInfoChanges.add({
          'field': 'birth_date',
          'label': 'Birth Date',
          'operation': 'modified',
          'old': _selectedDoctor!.birthDate ?? '',
          'new': _birthDateController.text.trim(),
        });
      }
      if (_selectedHcpType != null && _selectedHcpType != _selectedDoctor!.hcpType) {
        basicInfoChanges.add({
          'field': 'hcp_type',
          'label': 'HCP Type',
          'operation': 'modified',
          'old': _selectedDoctor!.hcpType,
          'new': _selectedHcpType,
        });
      }
      if (_selectedPractice != _selectedDoctor!.hcpPractice) {
        basicInfoChanges.add({
          'field': 'hcp_practice',
          'label': 'Practice',
          'operation': 'modified',
          'old': _selectedDoctor!.hcpPractice,
          'new': _selectedPractice,
        });
      }
    }

    final List<Map<String, dynamic>> specAdded = [];
    final List<Map<String, dynamic>> specRemoved = [];
    if (_selectedDoctor != null) {
      final oldSpecs = _selectedDoctor!.specialties.map((s) => s.hcpSpecialty).toSet();
      final newSpecs = _selectedSpecialties.where((s) => s.hcpSpecialty != null).map((s) => s.hcpSpecialty!).toSet();
      for (var s in _selectedSpecialties) {
        if (s.hcpSpecialty != null && !oldSpecs.contains(s.hcpSpecialty)) {
          specAdded.add({
            'hcp_specialty': s.hcpSpecialty,
            if (s.subSpecialty != null) 'sub_specialty': s.subSpecialty,
            if (s.specialtyName != null) 'specialty_name': s.specialtyName,
          });
        }
      }
      for (var s in _selectedDoctor!.specialties) {
        if (!newSpecs.contains(s.hcpSpecialty)) {
          specRemoved.add({
            'hcp_specialty': s.hcpSpecialty,
            if (s.subSpecialty != null) 'sub_specialty': s.subSpecialty,
          });
        }
      }
    } else {
      for (var s in _selectedSpecialties) {
        if (s.hcpSpecialty != null) {
          specAdded.add({
            'hcp_specialty': s.hcpSpecialty,
            if (s.subSpecialty != null) 'sub_specialty': s.subSpecialty,
            if (s.specialtyName != null) 'specialty_name': s.specialtyName,
          });
        }
      }
    }

    final List<Map<String, dynamic>> wpAdded = [];
    final List<Map<String, dynamic>> wpRemoved = [];
    if (_selectedDoctor != null) {
      final oldWps = _selectedDoctor!.workplaces.map((w) => w.workplace).toSet();
      final newWps = _selectedWorkplaces.where((w) => w.hcpWorkplace != null).map((w) => w.hcpWorkplace!).toSet();
      for (var w in _selectedWorkplaces) {
        if (w.hcpWorkplace != null && !oldWps.contains(w.hcpWorkplace)) {
          wpAdded.add({
            'hcp_workplace': w.hcpWorkplace,
            if (w.workplaceName != null) 'workplace_name': w.workplaceName,
          });
        }
      }
      for (var w in _selectedDoctor!.workplaces) {
        if (!newWps.contains(w.workplace)) {
          wpRemoved.add({
            'hcp_workplace': w.workplace,
          });
        }
      }
    } else {
      for (var w in _selectedWorkplaces) {
        if (w.hcpWorkplace != null) {
          wpAdded.add({
            'hcp_workplace': w.hcpWorkplace,
            if (w.workplaceName != null) 'workplace_name': w.workplaceName,
          });
        }
      }
    }

    final List<Map<String, dynamic>> contactAdded = [];
    final List<Map<String, dynamic>> contactRemoved = [];
    if (_selectedDoctor != null) {
      final oldNums = _selectedDoctor!.contacts.map((c) => (c.contactNumber ?? '').trim()).where((n) => n.isNotEmpty).toSet();
      final oldEmails = _selectedDoctor!.contacts.map((c) => (c.emailAddress ?? '').trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();

      for (var c in _contacts) {
        final cNum = (c.contactNumber ?? '').trim();
        final cEmail = (c.emailAddress ?? '').trim().toLowerCase();
        final isNumNew = cNum.isNotEmpty && !oldNums.contains(cNum);
        final isEmailNew = cEmail.isNotEmpty && !oldEmails.contains(cEmail);
        if (isNumNew || isEmailNew) {
          contactAdded.add({
            if (c.contactNumber != null && c.contactNumber!.isNotEmpty) 'contact_number': c.contactNumber,
            if (c.emailAddress != null && c.emailAddress!.isNotEmpty) 'email_address': c.emailAddress,
          });
        }
      }
      for (var oc in _selectedDoctor!.contacts) {
        final ocNum = (oc.contactNumber ?? '').trim();
        final ocEmail = (oc.emailAddress ?? '').trim().toLowerCase();
        final match = _contacts.any((c) =>
            (ocNum.isNotEmpty && (c.contactNumber ?? '').trim() == ocNum) ||
            (ocEmail.isNotEmpty && (c.emailAddress ?? '').trim().toLowerCase() == ocEmail));
        if (!match && (ocNum.isNotEmpty || ocEmail.isNotEmpty)) {
          contactRemoved.add({
            if (oc.contactNumber != null) 'contact_number': oc.contactNumber,
            if (oc.emailAddress != null) 'email_address': oc.emailAddress,
          });
        }
      }
    } else {
      for (var c in _contacts) {
        if ((c.contactNumber != null && c.contactNumber!.isNotEmpty) || (c.emailAddress != null && c.emailAddress!.isNotEmpty)) {
          contactAdded.add({
            if (c.contactNumber != null) 'contact_number': c.contactNumber,
            if (c.emailAddress != null) 'email_address': c.emailAddress,
          });
        }
      }
    }

    final structuredChanges = {
      'submission': '',
      'hcp': _selectedDoctor?.name ?? '',
      'generated_on': DateTime.now().toIso8601String(),
      'generated_by': apiService.loggedInEmail ?? 'jptan@profinsights.biz',
      'version': 1,
      'changes': {
        'basic_information': basicInfoChanges,
        'specializations': {
          'added': specAdded,
          'removed': specRemoved,
        },
        'workplaces': {
          'added': wpAdded,
          'removed': wpRemoved,
        },
        'contact_information': {
          'added': contactAdded,
          'removed': contactRemoved,
        },
      }
    };
    final changesJsonStr = jsonEncode(structuredChanges);

    // Build HTML Summary matching ERPNext v15 (clean/blank if no changes)
    final sb = StringBuffer();
    final bool hasAnyChanges = basicInfoChanges.isNotEmpty ||
        specAdded.isNotEmpty ||
        specRemoved.isNotEmpty ||
        wpAdded.isNotEmpty ||
        wpRemoved.isNotEmpty ||
        contactAdded.isNotEmpty ||
        contactRemoved.isNotEmpty;

    if (hasAnyChanges) {
      sb.write('<h3>Summary of Changes</h3><br><hr><br>');
      if (basicInfoChanges.isNotEmpty) {
        sb.write('<h4>Basic Information</h4>');
        for (var b in basicInfoChanges) {
          sb.write('<b>${b['label']}</b>: From "${b['old']}" → To "${b['new']}"<br>');
        }
        sb.write('<br>');
      }
      if (specAdded.isNotEmpty) {
        sb.write('<h4>Specializations</h4><b>✓ Added</b><div style="margin-left:20px; margin-bottom:10px;">');
        for (var s in specAdded) {
          sb.write('${s['specialty_name'] ?? s['hcp_specialty']}<br>');
        }
        sb.write('</div>');
      }
      if (specRemoved.isNotEmpty) {
        sb.write('<h4>Specializations</h4><b>✗ Removed</b><div style="margin-left:20px; margin-bottom:10px; color:#EF4444;">');
        for (var s in specRemoved) {
          sb.write('${s['specialty_name'] ?? s['hcp_specialty']}<br>');
        }
        sb.write('</div>');
      }
      if (wpAdded.isNotEmpty) {
        sb.write('<h4>Workplaces</h4><b>✓ Added</b><div style="margin-left:20px; margin-bottom:10px;">');
        for (var w in wpAdded) {
          sb.write('${w['workplace_name'] ?? w['hcp_workplace']}<br>');
        }
        sb.write('</div>');
      }
      if (wpRemoved.isNotEmpty) {
        sb.write('<h4>Workplaces</h4><b>✗ Removed</b><div style="margin-left:20px; margin-bottom:10px; color:#EF4444;">');
        for (var w in wpRemoved) {
          sb.write('${w['workplace_name'] ?? w['hcp_workplace']}<br>');
        }
        sb.write('</div>');
      }
      if (contactAdded.isNotEmpty) {
        sb.write('<h4>Contact Information</h4><b>✓ Added</b><div style="margin-left:20px; margin-bottom:10px;">');
        for (var c in contactAdded) {
          sb.write('Contact No.: ${c['contact_number'] ?? 'N/A'}, Email: ${c['email_address'] ?? 'None'}<br>');
        }
        sb.write('</div>');
      }
      if (contactRemoved.isNotEmpty) {
        sb.write('<h4>Contact Information</h4><b>✗ Removed</b><div style="margin-left:20px; margin-bottom:10px; color:#EF4444;">');
        for (var c in contactRemoved) {
          sb.write('Contact No.: ${c['contact_number'] ?? 'N/A'}, Email: ${c['email_address'] ?? 'None'}<br>');
        }
        sb.write('</div>');
      }
    }
    final changeSummaryHtmlStr = sb.toString();

    final bool isExistingDoctor = _selectedDoctor != null && (_selectedDoctor!.name?.isNotEmpty ?? false);

    // Determine approval requirement:
    // - MedRep account: ALL submissions (adding new doctor or updating doctor info) MUST go to HCP Profile Submission for Manager Approval.
    // - Existing doctor with changes: Requires Manager/Admin validation & approval.
    // - Admin / Manager with existing doctor without changes: Auto-confirmed.
    final bool requiresApproval = apiService.isMedRep || (isExistingDoctor && hasAnyChanges);
    final String targetWorkflow = requiresApproval ? 'Pending Approval' : 'Approved';
    final String targetAppStatus = requiresApproval ? 'Not Applied' : 'Applied';
    final int targetDocstatus = requiresApproval ? 0 : 1;

    try {
      String effectiveHcpId = isExistingDoctor ? _selectedDoctor!.name! : '';

      // If New Doctor AND logged in as Admin / Manager, can directly register into HCP master
      if (!isExistingDoctor && !apiService.isMedRep) {
        try {
          final newDoctor = Hcp(
            hcpFullName: fullDoctorName,
            firstName: fn,
            middleName: mn,
            lastName: ln,
            birthDate: _birthDateController.text.trim(),
            hcpPhoto: uploadedDoctorPhotoUrl,
            hcpType: _selectedHcpType ?? 'Resident',
            hcpPractice: _selectedPractice,
            specialties: _selectedSpecialties.where((e) => e.hcpSpecialty != null).map((e) => HcpSpecialty(hcpSpecialty: e.hcpSpecialty!, subSpecialty: e.subSpecialty, isPrimary: e.preferred)).toList(),
            workplaces: _selectedWorkplaces.where((e) => e.hcpWorkplace != null).map((e) => HcpWorkplace(workplace: e.hcpWorkplace!, provinceName: e.provinceName, cityMunicipality: e.cityMunicipality, address: e.workplaceName, isPrimary: e.preferred)).toList(),
            contacts: _contacts.where((e) => (e.contactNumber != null && e.contactNumber!.isNotEmpty) || (e.emailAddress != null && e.emailAddress!.isNotEmpty)).map((e) => HcpContact(contactNumber: e.contactNumber, emailAddress: e.emailAddress, isPrimary: e.preferred)).toList(),
            profileLastUpdated: DateTime.now().toIso8601String().split('.').first,
          );
          final createdDoc = await apiService.createDoctor(newDoctor);
          effectiveHcpId = createdDoc.name ?? '';
        } catch (e) {
          print('Error registering new doctor into master universe: $e');
        }
      }

      final submission = HcpProfileSubmission(
        hcpName: effectiveHcpId,
        hcpFullName: fullDoctorName,
        firstName: fn,
        middleName: mn,
        lastName: ln,
        birthDate: _birthDateController.text.trim(),
        hcpType: _selectedHcpType,
        hcpPractice: _selectedPractice,
        consentPrivacyUnderstood: _consentGiven,
        consentSignature: sigUri.isNotEmpty ? sigUri : null,
        consentPhoto: uploadedConsentPhotoUrl,
        hcpPhoto: uploadedDoctorPhotoUrl,
        specialties: _selectedSpecialties,
        workplaces: _selectedWorkplaces,
        contacts: _contacts,
        accountOrProgram: _selectedProgram,
        territory: _selectedTerritory,
        salesPerson: _territoryManagerController.text.trim().isNotEmpty
            ? _territoryManagerController.text.trim()
            : apiService.getTerritoryManagerForTerritory(_selectedTerritory),
        userId: apiService.loggedInEmail ?? 'jptan@profinsights.biz',
        surveyTemplate: _activeSurvey?.name,
        surveyTemplateTitle: _activeSurvey?.templateName,
        answers: answersList,
        medrepEmail: apiService.loggedInEmail ?? 'jptan@profinsights.biz',
        submissionDate: _submissionDate.toString().split('.').first,
        validFrom: HcpAccount.calculateMonthValidFrom(_submissionDate),
        validTo: HcpAccount.calculateMonthValidTo(_submissionDate),
        validityPeriod: HcpAccount.calculateMonthLabel(_submissionDate),
        workflowState: targetWorkflow,
        applicationStatus: targetAppStatus,
        changeSummaryHtml: changeSummaryHtmlStr,
        changesJson: changesJsonStr,
        docstatus: targetDocstatus,
      );

      await apiService.createSubmission(submission);

      if (!requiresApproval) {
        // Auto-sync active HCP Account for this program (for Admin/Manager direct actions)
        await apiService.syncHcpAccount(
          hcpId: effectiveHcpId.isNotEmpty ? effectiveHcpId : 'NEW-HCP',
          hcpFullName: fullDoctorName,
          program: _selectedProgram,
          territory: _selectedTerritory,
          salesPerson: _territoryManagerController.text.trim().isNotEmpty
              ? _territoryManagerController.text.trim()
              : apiService.getTerritoryManagerForTerritory(_selectedTerritory),
          userId: apiService.loggedInEmail,
          specialties: _selectedSpecialties.where((e) => e.hcpSpecialty != null).map((e) => HcpAccountSpecialization(hcpSpecialty: e.hcpSpecialty!, subSpecialty: e.subSpecialty, isPrimary: e.preferred, preferred: e.preferred)).toList(),
          workplaces: _selectedWorkplaces.where((e) => e.hcpWorkplace != null).map((e) => HcpAccountWorkplace(hcpWorkplace: e.hcpWorkplace!, cityMunicipality: e.cityMunicipality, provinceName: e.provinceName, address: e.workplaceName, isPrimary: e.preferred, preferred: e.preferred)).toList(),
          contacts: _contacts.where((e) => (e.contactNumber != null && e.contactNumber!.isNotEmpty) || (e.emailAddress != null && e.emailAddress!.isNotEmpty)).map((e) => HcpAccountContact(contactNumber: e.contactNumber, emailAddress: e.emailAddress, isPrimary: e.preferred, preferred: e.preferred)).toList(),
        );
      }

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: requiresApproval ? const Color(0xFF0066FF) : const Color(0xFF10B981),
            content: Text(
              requiresApproval
                  ? (isExistingDoctor
                      ? 'Doctor profile update submitted (Pending Managerial Approval).'
                      : 'New doctor submitted to HCP Profile Submission (Pending Managerial Approval).')
                  : (isExistingDoctor
                      ? 'Doctor account confirmed for $_selectedProgram!'
                      : 'New doctor registered directly to HCP universe and $_selectedProgram Account!'),
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    }
  }

  Future<Specialization?> _showSpecializationSearchDialog({
    required BuildContext context,
    String? currentSelectedName,
    List<Specialization>? customList,
    String title = 'Select Specialization',
  }) async {
    final list = customList ?? _specializations;
    final searchCtrl = TextEditingController();
    List<Specialization> filtered = List.from(list);

    return showDialog<Specialization>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
                maxWidth: 480,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0B192C),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.medical_services_outlined, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${filtered.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search specialty name or group...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF0066FF), size: 20),
                        suffixIcon: searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  searchCtrl.clear();
                                  setDlgState(() {
                                    filtered = List.from(list);
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5)),
                      ),
                      onChanged: (val) {
                        final q = val.trim().toLowerCase();
                        setDlgState(() {
                          if (q.isEmpty) {
                            filtered = List.from(list);
                          } else {
                            filtered = list.where((s) =>
                              s.specialty.toLowerCase().contains(q) ||
                              s.specialtyGroup.toLowerCase().contains(q) ||
                              s.name.toLowerCase().contains(q)
                            ).toList();
                          }
                        });
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                                SizedBox(height: 8),
                                Text('No specializations found', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                            itemBuilder: (ctx, idx) {
                              final item = filtered[idx];
                              final isSelected = item.name == currentSelectedName || item.specialty == currentSelectedName;
                              return ListTile(
                                dense: true,
                                tileColor: isSelected ? const Color(0xFFEFF6FF) : null,
                                title: Text(
                                  item.specialty,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF0F172A),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: item.specialtyGroup.isNotEmpty
                                    ? Text(item.specialtyGroup, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11))
                                    : null,
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0066FF), size: 18)
                                    : null,
                                onTap: () => Navigator.pop(dialogCtx, item),
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<Institution?> _showInstitutionSearchDialog({
    required BuildContext context,
    String? currentSelectedName,
    String title = 'Select Workplace / Hospital',
  }) async {
    final list = _institutions;
    final searchCtrl = TextEditingController();
    List<Institution> filtered = List.from(list);

    return showDialog<Institution>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
                maxWidth: 480,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0B192C),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_hospital_outlined, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${filtered.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search hospital name, city, province...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF0066FF), size: 20),
                        suffixIcon: searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  searchCtrl.clear();
                                  setDlgState(() {
                                    filtered = List.from(list);
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5)),
                      ),
                      onChanged: (val) {
                        final q = val.trim().toLowerCase();
                        setDlgState(() {
                          if (q.isEmpty) {
                            filtered = List.from(list);
                          } else {
                            filtered = list.where((i) =>
                              i.institutionName.toLowerCase().contains(q) ||
                              (i.cityMunicipality?.toLowerCase().contains(q) ?? false) ||
                              (i.provinceName?.toLowerCase().contains(q) ?? false) ||
                              (i.streetAddress?.toLowerCase().contains(q) ?? false) ||
                              i.name.toLowerCase().contains(q)
                            ).toList();
                          }
                        });
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                                SizedBox(height: 8),
                                Text('No workplaces found', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                            itemBuilder: (ctx, idx) {
                              final item = filtered[idx];
                              final isSelected = item.name == currentSelectedName || item.institutionName == currentSelectedName;
                              final locationParts = [
                                if (item.streetAddress != null && item.streetAddress!.isNotEmpty) item.streetAddress!,
                                if (item.cityMunicipality != null && item.cityMunicipality!.isNotEmpty) item.cityMunicipality!,
                                if (item.provinceName != null && item.provinceName!.isNotEmpty) item.provinceName!,
                              ];
                              return ListTile(
                                dense: true,
                                tileColor: isSelected ? const Color(0xFFEFF6FF) : null,
                                title: Text(
                                  item.institutionName,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF0F172A),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: locationParts.isNotEmpty
                                    ? Text(locationParts.join(', '), style: const TextStyle(color: Color(0xFF64748B), fontSize: 11))
                                    : null,
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0066FF), size: 18)
                                    : null,
                                onTap: () => Navigator.pop(dialogCtx, item),
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddSpecialtySelector() {
    String? selectedSpec = _specializations.isNotEmpty ? _specializations.first.name : null;
    String? selectedSubSpec;
    bool isPreferred = _selectedSpecialties.isEmpty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final currentSpecObj = _specializations.firstWhere(
            (s) => s.name == selectedSpec,
            orElse: () => _specializations.isNotEmpty ? _specializations.first : Specialization(name: '', specialty: '', specialtyGroup: ''),
          );
          final currentSubSpecObj = selectedSubSpec != null
              ? _specializations.firstWhere(
                  (s) => s.name == selectedSubSpec,
                  orElse: () => Specialization(name: selectedSubSpec!, specialty: selectedSubSpec!, specialtyGroup: ''),
                )
              : null;

          final subSpecs = _specializations.where((s) =>
              (s.parentSpecialization != null &&
                  (s.parentSpecialization == selectedSpec ||
                   s.parentSpecialization == currentSpecObj.specialty ||
                   s.parentSpecialization == currentSpecObj.name)) ||
              (s.specialtyGroup.isNotEmpty && s.specialtyGroup == currentSpecObj.specialty)
          ).toList();

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Add Specialty', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Specialty Name *', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await _showSpecializationSearchDialog(
                        context: context,
                        currentSelectedName: selectedSpec,
                      );
                      if (picked != null) {
                        setDlgState(() {
                          selectedSpec = picked.name;
                          selectedSubSpec = null;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.medical_services_outlined, color: Color(0xFF0066FF), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              currentSpecObj.specialty.isNotEmpty ? currentSpecObj.specialty : 'Tap to search specialty...',
                              style: TextStyle(
                                color: currentSpecObj.specialty.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Icon(Icons.search_rounded, color: Color(0xFF0066FF), size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Sub-Specialty Name (Optional)', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await _showSpecializationSearchDialog(
                        context: context,
                        currentSelectedName: selectedSubSpec,
                        customList: subSpecs.isNotEmpty ? subSpecs : _specializations.where((s) => !s.isGroup).toList(),
                        title: 'Select Sub-Specialty',
                      );
                      if (picked != null) {
                        setDlgState(() {
                          selectedSubSpec = picked.name;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.subdirectory_arrow_right_rounded, color: Color(0xFF0066FF), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              currentSubSpecObj?.specialty ?? 'None (Tap to search sub-specialty)',
                              style: TextStyle(
                                color: currentSubSpecObj != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (selectedSubSpec != null)
                            GestureDetector(
                              onTap: () => setDlgState(() => selectedSubSpec = null),
                              child: const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          const Icon(Icons.search_rounded, color: Color(0xFF0066FF), size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Set as Preferred Specialization', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Designates primary specialty for this doctor', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    activeColor: const Color(0xFF0066FF),
                    checkColor: Colors.white,
                    value: isPreferred,
                    onChanged: (val) => setDlgState(() => isPreferred = val ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
                onPressed: () {
                  if (selectedSpec != null) {
                    setState(() {
                      _selectedSpecialties.add(SubmissionSpecialty(
                        preferred: isPreferred,
                        hcpSpecialty: selectedSpec!,
                        specialtyName: currentSpecObj.specialty,
                        subSpecialty: selectedSubSpec,
                        subSpecialtyName: currentSubSpecObj?.specialty ?? selectedSubSpec,
                      ));
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Add Row', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddWorkplaceSelector() {
    String? selectedInst = _institutions.isNotEmpty ? _institutions.first.name : null;
    bool isPreferred = _selectedWorkplaces.isEmpty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final currentInstObj = selectedInst != null
              ? _institutions.firstWhere(
                  (i) => i.name == selectedInst,
                  orElse: () => Institution(name: selectedInst!, institutionName: selectedInst!),
                )
              : (_institutions.isNotEmpty ? _institutions.first : null);

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Add Workplace', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Workplace / Hospital *', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await _showInstitutionSearchDialog(
                        context: context,
                        currentSelectedName: selectedInst,
                      );
                      if (picked != null) {
                        setDlgState(() => selectedInst = picked.name);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_hospital_outlined, color: Color(0xFF0066FF), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              currentInstObj?.institutionName ?? 'Tap to search hospital / clinic...',
                              style: TextStyle(
                                color: currentInstObj != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Icon(Icons.search_rounded, color: Color(0xFF0066FF), size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Set as Preferred Workplace', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Designates primary clinic or hospital for this program', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    activeColor: const Color(0xFF0066FF),
                    checkColor: Colors.white,
                    value: isPreferred,
                    onChanged: (val) => setDlgState(() => isPreferred = val ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
                onPressed: () {
                  if (selectedInst != null) {
                    final match = _institutions.firstWhere((i) => i.name == selectedInst, orElse: () => Institution(name: selectedInst!, institutionName: selectedInst!));
                    setState(() {
                      _selectedWorkplaces.add(SubmissionWorkplace(
                        preferred: isPreferred,
                        hcpWorkplace: selectedInst!,
                        workplaceName: match.institutionName,
                        cityMunicipality: match.cityMunicipality,
                        cityTitle: match.cityMunicipality,
                        provinceName: match.provinceName,
                        provinceTitle: match.provinceName,
                      ));
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Add Row', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddContactSelector() {
    String phone = '';
    String email = '';
    bool isPreferred = _contacts.isEmpty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Contact Info', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    labelText: 'Mobile/Phone Number',
                    labelStyle: TextStyle(color: Color(0xFF64748B)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                  onChanged: (val) => phone = val,
                ),
                TextFormField(
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    labelText: 'Email Address / Type',
                    labelStyle: TextStyle(color: Color(0xFF64748B)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                  onChanged: (val) => email = val,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Set as Preferred Contact Info', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Designates primary contact number or email', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  activeColor: const Color(0xFF0066FF),
                  checkColor: Colors.white,
                  value: isPreferred,
                  onChanged: (val) => setDlgState(() => isPreferred = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
              onPressed: () {
                if (phone.isNotEmpty || email.isNotEmpty) {
                  setState(() {
                    _contacts.add(SubmissionContact(
                      preferred: isPreferred,
                      contactNumber: phone.isNotEmpty ? phone : null,
                      emailAddress: email.isNotEmpty ? email : null,
                    ));
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add Row', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSpecialtyDialog(int index) {
    final s = _selectedSpecialties[index];
    String? selSpec = s.hcpSpecialty;
    String? selSub = s.subSpecialty;
    bool isPreferred = s.preferred;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final currentSpecObj = _specializations.firstWhere(
            (sp) => sp.name == selSpec,
            orElse: () => _specializations.isNotEmpty ? _specializations.first : Specialization(name: '', specialty: '', specialtyGroup: ''),
          );
          final currentSubSpecObj = selSub != null
              ? _specializations.firstWhere(
                  (sp) => sp.name == selSub,
                  orElse: () => Specialization(name: selSub!, specialty: selSub!, specialtyGroup: ''),
                )
              : null;

          final subSpecs = _specializations.where((sp) =>
              (sp.parentSpecialization != null &&
                  (sp.parentSpecialization == selSpec ||
                   sp.parentSpecialization == currentSpecObj.specialty ||
                   sp.parentSpecialization == currentSpecObj.name)) ||
              (sp.specialtyGroup.isNotEmpty && sp.specialtyGroup == currentSpecObj.specialty)
          ).toList();

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Edit Specialization', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Specialty Name *', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await _showSpecializationSearchDialog(
                        context: context,
                        currentSelectedName: selSpec,
                      );
                      if (picked != null) {
                        setDlgState(() {
                          selSpec = picked.name;
                          selSub = null;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.medical_services_outlined, color: Color(0xFF0066FF), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              currentSpecObj.specialty.isNotEmpty ? currentSpecObj.specialty : 'Tap to search specialty...',
                              style: TextStyle(
                                color: currentSpecObj.specialty.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Icon(Icons.search_rounded, color: Color(0xFF0066FF), size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Sub Specialty Name (Optional)', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await _showSpecializationSearchDialog(
                        context: context,
                        currentSelectedName: selSub,
                        customList: subSpecs.isNotEmpty ? subSpecs : _specializations.where((sp) => !sp.isGroup).toList(),
                        title: 'Select Sub-Specialty',
                      );
                      if (picked != null) {
                        setDlgState(() {
                          selSub = picked.name;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.subdirectory_arrow_right_rounded, color: Color(0xFF0066FF), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              currentSubSpecObj?.specialty ?? 'None (Tap to search sub-specialty)',
                              style: TextStyle(
                                color: currentSubSpecObj != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (selSub != null)
                            GestureDetector(
                              onTap: () => setDlgState(() => selSub = null),
                              child: const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          const Icon(Icons.search_rounded, color: Color(0xFF0066FF), size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Set as Preferred Specialization', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Designates primary specialty for this doctor', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    activeColor: const Color(0xFF0066FF),
                    checkColor: Colors.white,
                    value: isPreferred,
                    onChanged: (val) => setDlgState(() => isPreferred = val ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
                onPressed: () {
                  if (selSpec != null) {
                    final specLookup = {for (var sp in _specializations) sp.name: sp.specialty};
                    setState(() {
                      _selectedSpecialties[index] = SubmissionSpecialty(
                        preferred: isPreferred,
                        hcpSpecialty: selSpec,
                        specialtyName: specLookup[selSpec] ?? selSpec,
                        subSpecialty: selSub,
                        subSpecialtyName: selSub != null ? (specLookup[selSub] ?? selSub) : null,
                      );
                    });
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditWorkplaceDialog(int index) {
    final w = _selectedWorkplaces[index];
    String? selectedInst = w.hcpWorkplace;
    final addrCtrl = TextEditingController(text: w.workplaceName ?? '');
    bool isPreferred = w.preferred;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final currentInstObj = selectedInst != null
              ? _institutions.firstWhere(
                  (i) => i.name == selectedInst,
                  orElse: () => Institution(name: selectedInst!, institutionName: selectedInst!),
                )
              : (_institutions.isNotEmpty ? _institutions.first : null);

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Edit Workplace', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Workplace Institution *', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await _showInstitutionSearchDialog(
                        context: context,
                        currentSelectedName: selectedInst,
                      );
                      if (picked != null) {
                        setDlgState(() {
                          selectedInst = picked.name;
                          addrCtrl.text = picked.institutionName;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_hospital_outlined, color: Color(0xFF0066FF), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              currentInstObj?.institutionName ?? 'Tap to search hospital / clinic...',
                              style: TextStyle(
                                color: currentInstObj != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Icon(Icons.search_rounded, color: Color(0xFF0066FF), size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addrCtrl,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Address / Workplace Name',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Set as Preferred Workplace', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Designates primary clinic or hospital for this program', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    activeColor: const Color(0xFF0066FF),
                    checkColor: Colors.white,
                    value: isPreferred,
                    onChanged: (val) => setDlgState(() => isPreferred = val ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
                onPressed: () {
                  if (selectedInst != null) {
                    final instObj = _institutions.firstWhere((i) => i.name == selectedInst, orElse: () => _institutions.first);
                    setState(() {
                      _selectedWorkplaces[index] = SubmissionWorkplace(
                        preferred: isPreferred,
                        hcpWorkplace: selectedInst,
                        workplaceName: addrCtrl.text.isNotEmpty ? addrCtrl.text : instObj.institutionName,
                        cityMunicipality: instObj.cityMunicipality,
                        cityTitle: instObj.cityMunicipality,
                        provinceName: instObj.provinceName,
                        provinceTitle: instObj.provinceName,
                      );
                    });
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditContactDialog(int index) {
    final c = _contacts[index];
    final numCtrl = TextEditingController(text: c.contactNumber ?? '');
    String contactType = c.emailAddress ?? 'Mobile';
    bool isPreferred = c.preferred;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Edit Contact Info', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: numCtrl,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Contact Value / Phone Number',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: contactType,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Type / Email',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Mobile', child: Text('Mobile')),
                      DropdownMenuItem(value: 'Phone', child: Text('Phone')),
                      DropdownMenuItem(value: 'Email', child: Text('Email')),
                    ],
                    onChanged: (val) => setDlgState(() => contactType = val!),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Set as Preferred Contact Info', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Designates primary contact number or email', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    activeColor: const Color(0xFF0066FF),
                    checkColor: Colors.white,
                    value: isPreferred,
                    onChanged: (val) => setDlgState(() => isPreferred = val ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
                onPressed: () {
                  if (numCtrl.text.isNotEmpty) {
                    setState(() {
                      _contacts[index] = SubmissionContact(
                        preferred: isPreferred,
                        contactNumber: numCtrl.text.trim(),
                        emailAddress: contactType,
                      );
                    });
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDateTimePicker() {
    DateTime tempDate = _submissionDate;
    double tempHour = _submissionDate.hour.toDouble();
    double tempMinute = _submissionDate.minute.toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Submission Date & Time', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9)),
                  icon: const Icon(Icons.calendar_today, color: Color(0xFF0066FF)),
                  label: Text(
                    'Date: ${tempDate.year}-${tempDate.month.toString().padLeft(2, '0')}-${tempDate.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: tempDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setModalState(() {
                        tempDate = DateTime(picked.year, picked.month, picked.day, tempHour.toInt(), tempMinute.toInt());
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text('Hour: ${tempHour.toInt().toString().padLeft(2, '0')}', style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                Slider(
                  value: tempHour,
                  min: 0,
                  max: 23,
                  divisions: 23,
                  activeColor: const Color(0xFF0066FF),
                  onChanged: (val) {
                    setModalState(() {
                      tempHour = val;
                      tempDate = DateTime(tempDate.year, tempDate.month, tempDate.day, tempHour.toInt(), tempMinute.toInt());
                    });
                  },
                ),
                Text('Minute: ${tempMinute.toInt().toString().padLeft(2, '0')}', style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                Slider(
                  value: tempMinute,
                  min: 0,
                  max: 59,
                  divisions: 59,
                  activeColor: const Color(0xFF0066FF),
                  onChanged: (val) {
                    setModalState(() {
                      tempMinute = val;
                      tempDate = DateTime(tempDate.year, tempDate.month, tempDate.day, tempHour.toInt(), tempMinute.toInt());
                    });
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
                    onPressed: () {
                      setState(() {
                        _submissionDate = tempDate;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Confirm Date & Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<String> _getTabTitles() {
    return [
      'Step 1',
      if (_consentGiven) 'Step 2',
      if (_consentGiven) 'Step 3',
      if (_consentGiven) 'Others',
      if (_consentGiven) 'Changes',
    ];
  }

  Widget _buildStepHeader() {
    final titles = _getTabTitles();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(titles.length, (idx) {
            final isSelected = _currentStep == idx;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentStep = idx;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0B192C) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  titles[idx],
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _selectedDoctor != null
              ? 'New HCP Profile Submission (Dr. ${_selectedDoctor!.firstName} ${_selectedDoctor!.lastName})'
              : 'New HCP Profile Submission',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        backgroundColor: const Color(0xFF0B192C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B192C))),
            )
          : Column(
              children: [
                _buildStepHeader(),
                Expanded(child: _buildStepBody()),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStepBody() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Consent();
      case 1:
        return _consentGiven ? _buildStep2DoctorInfo() : const SizedBox();
      case 2:
        return _consentGiven ? _buildStep3Survey() : const SizedBox();
      case 3:
        return _consentGiven ? _buildOthersStep() : const SizedBox();
      case 4:
        return _consentGiven ? _buildChangesStep() : const SizedBox();
      default:
        return const SizedBox();
    }
  }

  // --- STEP 1: PRIVACY NOTICE AND CONSENT ---
  Widget _buildStep1Consent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PRIVACY NOTICE AND CONSENT', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Please read the agreement carefully and then sign or take a group photo as proof of consent.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: const Text(
              'I agree that PROFESSIONAL INSIGHTS MARKETING SERVICES (PIMS), including its contracted third parties to contact me through the Contact Details that I provided to PIMS and/or its authorized representative(s) and to collect, store, process and share with PIMS contracted third parties, my Contact Details and my Professional Details for any of the following purposes:\n\n'
              'a. to communicate with me in the manner preferred by PIMS, including through PIMS PROFESSIONAL HEALTH SPECIALISTS REPRESENTATIVES, websites, email, call centers, postal mail, webcasts, and other channels\n\n'
              'b. to provide me with information that I have requested, including scientific data, promotional and marketing communications and/or other information about PIMS products, services and activities\n\n'
              'c. to plan and implement PIMS promotional activities directed to me, including identifying topics and activities that may be of interest to me\n\n'
              'd. to respond to my requests or queries or to seek my views, on PIMS products, services, and activities\n\n'
              'e. to improve PIMS level of service and the content of its communications\n\n'
              'f. for PIMS own administrative and quality assurance purposes\n\n'
              'g. any other purpose that is related to the above list of purposes.\n\n'
              'I further acknowledge that I may obtain more information on the processing by PIMS of my Contact Details and Professional Details by accessing PIMS Privacy Statement at http://pims-marketing.com/privacy\n\n'
              '1. Contact Details: my name, contact number, email address, office address, and office number\n'
              '2. Professional Details: such as my PRC number, professional associations, and medical specialties\n\n'
              'Note: PIMS is registered with the National Privacy Commission. All Data and Personal Details voluntarily provided by data subject are protected under the Data Privacy Act.',
              style: TextStyle(color: Color(0xFF334155), fontSize: 12, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),

          // CONFIRMATION CHECKBOX
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _consentGiven,
                activeColor: const Color(0xFF0066FF),
                checkColor: Colors.white,
                onChanged: (val) {
                  setState(() {
                    _consentGiven = val ?? false;
                  });
                },
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Text(
                    '(Please check the box on the left as confirmation) *',
                    style: TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 12.0, top: 4.0),
            child: Text(
              'I have read and understood the Privacy Policy and this Privacy Notice and Consent Form, and I consent to the processing of my personal data to receive personalized commercial and medical communications from PIMS, as described in the Privacy Policy.',
              style: TextStyle(color: Color(0xFF475569), fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 20),

          // DYNAMIC VISIBILITY: Legal Notice, Signature, & Photo appear ONLY when confirmation box is CHECKED!
          if (_consentGiven) ...[
            const Text('LEGAL NOTICE', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              'By signing or taking a photo, you accept and agree to Company\'s Terms of Use and Privacy Policy. Specifically, you provide your clear consent to: (i) Company\'s collection, use, transfer, and/or processing of any of your personal information provided hereunder, for the purposes of this and/or future engagement(s) with the Professional Healthcare Specialist Representative of PMI; (ii) Company\'s recording of coverage, including its perpetual right to store, transmit and use such recordings for any internal or external purpose(s). You agree to be contacted, including via phone, email messages and text messages, by Company, its affiliates, contractors/sub-contractors in relation to the marketing of Company\'s products and/or services.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 20),

            const Text('Affix signature and/or take a group photo', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SIGNATURE COLUMN
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Signature', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                          ValueListenableBuilder<List<Offset>>(
                            valueListenable: _signaturePoints,
                            builder: (context, points, _) {
                              if (points.isEmpty) return const SizedBox.shrink();
                              return InkWell(
                                onTap: () => setState(() => _signaturePoints.value = []),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text('Clear', style: TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SignatureCanvas(pointsNotifier: _signaturePoints),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sign inside the box', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                          InkWell(
                            onTap: () => setState(() => _signaturePoints.value = []),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.clear_rounded, size: 14, color: Color(0xFFDC2626)),
                                SizedBox(width: 2),
                                Text('Clear', style: TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // PHOTO COLUMN
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Photo', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                          if (_consentPhotoBytes != null)
                            InkWell(
                              onTap: _showPhotoPreviewDialog,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Text('View Full', style: TextStyle(color: Color(0xFF0066FF), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _consentPhotoBytes != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(
                                      _consentPhotoBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned.fill(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _showPhotoPreviewDialog,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.65),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text('Tap to preview', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : InkWell(
                                  onTap: _capturePhoto,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.camera_alt_rounded, color: Color(0xFF0066FF), size: 28),
                                        SizedBox(height: 6),
                                        Text('Take Photo', style: TextStyle(color: Color(0xFF0066FF), fontSize: 13, fontWeight: FontWeight.w600)),
                                        SizedBox(height: 2),
                                        Text('Tap to capture group / consent photo', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _consentPhotoBytes != null ? 'Photo captured' : 'No photo captured',
                            style: TextStyle(
                              color: _consentPhotoBytes != null ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: _consentPhotoBytes != null ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          if (_consentPhotoBytes != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: _capturePhoto,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.camera_alt_outlined, size: 13, color: Color(0xFF0066FF)),
                                      SizedBox(width: 2),
                                      Text('Retake', style: TextStyle(color: Color(0xFF0066FF), fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _consentPhotoFile = null;
                                      _consentPhotoBytes = null;
                                    });
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.delete_outline_rounded, size: 13, color: Color(0xFFDC2626)),
                                      SizedBox(width: 2),
                                      Text('Remove', style: TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            InkWell(
                              onTap: _capturePhoto,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.camera_alt_rounded, size: 13, color: Color(0xFF0066FF)),
                                  SizedBox(width: 2),
                                  Text('Capture', style: TextStyle(color: Color(0xFF0066FF), fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDC2626)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
              label: const Text('Doctor Rejects Profiling (Exit to Homepage)', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
              onPressed: _onDoctorRejectsProfiling,
            ),
          ),
        ],
      ),
    );
  }

  void _showHcpSelectorModal() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = _allDoctors.where((d) {
            final name = '${d.firstName} ${d.lastName}'.toLowerCase();
            final id = (d.name ?? '').toLowerCase();
            final q = searchQuery.toLowerCase().trim();
            return q.isEmpty || name.contains(q) || id.contains(q);
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onChanged: (val) => setModalState(() => searchQuery = val),
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search doctor by surname, firstname, or HCP ID...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final doc = filtered[idx];
                      final computedParts = [
                        if (doc.firstName.trim().isNotEmpty) doc.firstName.trim(),
                        if (doc.middleName != null && doc.middleName!.trim().isNotEmpty && doc.middleName!.trim() != '-') doc.middleName!.trim(),
                        if (doc.lastName.trim().isNotEmpty) doc.lastName.trim(),
                      ].join(' ');

                      final docFullName = (doc.hcpFullName != null && doc.hcpFullName!.trim().isNotEmpty && !doc.hcpFullName!.startsWith('HCP-'))
                          ? doc.hcpFullName!.trim()
                          : (computedParts.isNotEmpty ? computedParts : (doc.name ?? 'Unknown Doctor'));
                      final isSelected = _selectedDoctor?.name == doc.name;

                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _selectedDoctor = doc;
                            _prepopulateDoctorData(doc);
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSelected ? const Color(0xFF0066FF) : const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                docFullName,
                                style: const TextStyle(color: Color(0xFF0B192C), fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFCBD5E1), width: 0.5),
                                    ),
                                    child: Text(
                                      doc.name ?? 'HCP-0000000',
                                      style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                                    ),
                                  ),
                                  if (doc.hcpType.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text('• ${doc.hcpType}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                  ],
                                  if (doc.hcpPractice.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text('• ${doc.hcpPractice}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_alt_outlined, color: Color(0xFF64748B), size: 14),
                          SizedBox(width: 4),
                          Text('Filters applied for Is Active = Yes', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B192C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('+ Create a new HCP', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showNewHcpModal();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showNewHcpModal() {
    final newFirstNameCtrl = TextEditingController();
    final newMiddleNameCtrl = TextEditingController();
    final newLastNameCtrl = TextEditingController();
    final newBirthDateCtrl = TextEditingController();
    String newHcpType = _hcpTypes.isNotEmpty ? _hcpTypes.first.name : 'Resident';
    String newPractice = 'Dispensing';
    bool newIsActive = true;
    bool isSavingModal = false;
    Uint8List? newDoctorPhotoBytes;
    XFile? newDoctorPhotoFile;

    final List<HcpSpecialty> newSpecialtiesList = [];
    final List<HcpWorkplace> newWorkplacesList = [];
    final List<HcpContact> newContactsList = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (ctx, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0B192C),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('New HCP', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFD97706), borderRadius: BorderRadius.circular(4)),
                              child: const Text('Not Saved', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0066FF),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isSavingModal ? null : () async {
                            if (newFirstNameCtrl.text.trim().isEmpty || newLastNameCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('First Name and Last Name are required.')),
                              );
                              return;
                            }

                            setModalState(() => isSavingModal = true);
                            final apiService = Provider.of<ApiService>(context, listen: false);

                            String? uploadedPhotoUrl;
                            if (newDoctorPhotoBytes != null) {
                              try {
                                uploadedPhotoUrl = await apiService.uploadFile(
                                  bytes: newDoctorPhotoBytes!,
                                  filename: 'hcp_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                  doctype: 'HCP',
                                );
                              } catch (e) {
                                debugPrint('Upload photo error: $e');
                              }
                            }

                            final fName = newFirstNameCtrl.text.trim();
                            final mName = newMiddleNameCtrl.text.trim();
                            final lName = newLastNameCtrl.text.trim();
                            final computedFullName = [
                              fName,
                              if (mName.isNotEmpty && mName != '-') mName,
                              lName,
                            ].join(' ');

                            final newDoctorPayload = Hcp(
                              firstName: fName,
                              middleName: mName.isNotEmpty ? mName : null,
                              lastName: lName,
                              hcpFullName: computedFullName,
                              birthDate: newBirthDateCtrl.text.trim().isNotEmpty ? newBirthDateCtrl.text.trim() : null,
                              hcpPhoto: uploadedPhotoUrl,
                              hcpType: newHcpType,
                              hcpPractice: newPractice,
                              isActive: newIsActive,
                              specialties: newSpecialtiesList,
                              workplaces: newWorkplacesList,
                              contacts: newContactsList,
                              profileLastUpdated: DateTime.now().toIso8601String().split('.').first,
                            );

                            Hcp createdDoctor;
                            try {
                              createdDoctor = await apiService.createDoctor(newDoctorPayload);
                            } catch (e) {
                              debugPrint('Create doctor online exception, fallback to registered object: $e');
                              final tempId = 'HCP-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
                              createdDoctor = Hcp(
                                name: tempId,
                                firstName: fName,
                                middleName: mName.isNotEmpty ? mName : null,
                                lastName: lName,
                                hcpFullName: computedFullName,
                                birthDate: newBirthDateCtrl.text.trim().isNotEmpty ? newBirthDateCtrl.text.trim() : null,
                                hcpPhoto: uploadedPhotoUrl,
                                hcpType: newHcpType,
                                hcpPractice: newPractice,
                                isActive: newIsActive,
                                specialties: newSpecialtiesList,
                                workplaces: newWorkplacesList,
                                contacts: newContactsList,
                                profileLastUpdated: DateTime.now().toIso8601String().split('.').first,
                              );
                            }

                            setState(() {
                              if (!_allDoctors.any((d) => d.name == createdDoctor.name || (d.firstName == createdDoctor.firstName && d.lastName == createdDoctor.lastName))) {
                                _allDoctors.insert(0, createdDoctor);
                              }
                              _selectedDoctor = createdDoctor;
                              _doctorPhotoUrl = createdDoctor.hcpPhoto;
                              _doctorPhotoBytes = newDoctorPhotoBytes;
                              _doctorPhotoFile = newDoctorPhotoFile;
                              _prepopulateDoctorData(createdDoctor);
                            });

                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF0066FF),
                                content: Text('Doctor "${createdDoctor.firstName} ${createdDoctor.lastName}" created and selected in profiling wizard.'),
                              ),
                            );
                          },
                          child: isSavingModal
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DOCTOR\'S INFORMATION SHEET', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              InkWell(
                                onTap: () async {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.white,
                                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                                    builder: (bCtx) => SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: Text('Doctor Profile Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0066FF)),
                                            title: const Text('Take Photo with Camera'),
                                            onTap: () async {
                                              Navigator.pop(bCtx);
                                              final picker = ImagePicker();
                                              final img = await picker.pickImage(source: ImageSource.camera, maxWidth: 800, maxHeight: 800, imageQuality: 85);
                                              if (img != null) {
                                                final bytes = await img.readAsBytes();
                                                setModalState(() {
                                                  newDoctorPhotoFile = img;
                                                  newDoctorPhotoBytes = bytes;
                                                });
                                              }
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF0066FF)),
                                            title: const Text('Upload from Gallery'),
                                            onTap: () async {
                                              Navigator.pop(bCtx);
                                              final picker = ImagePicker();
                                              final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
                                              if (img != null) {
                                                final bytes = await img.readAsBytes();
                                                setModalState(() {
                                                  newDoctorPhotoFile = img;
                                                  newDoctorPhotoBytes = bytes;
                                                });
                                              }
                                            },
                                          ),
                                          if (newDoctorPhotoBytes != null)
                                            ListTile(
                                              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                                              title: const Text('Remove Photo', style: TextStyle(color: Color(0xFFDC2626))),
                                              onTap: () {
                                                Navigator.pop(bCtx);
                                                setModalState(() {
                                                  newDoctorPhotoFile = null;
                                                  newDoctorPhotoBytes = null;
                                                });
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: newDoctorPhotoBytes != null ? const Color(0xFF0066FF) : const Color(0xFFCBD5E1),
                                      width: newDoctorPhotoBytes != null ? 2 : 1,
                                    ),
                                  ),
                                  child: newDoctorPhotoBytes != null
                                      ? Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: Image.memory(
                                                newDoctorPhotoBytes!,
                                                width: 76,
                                                height: 76,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              right: 2,
                                              bottom: 2,
                                              child: Container(
                                                padding: const EdgeInsets.all(3),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF0066FF),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.edit, size: 10, color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.add_a_photo_rounded, color: Color(0xFF0066FF), size: 22),
                                            SizedBox(height: 4),
                                            Text('Add Photo', style: TextStyle(color: Color(0xFF0066FF), fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Row(
                                children: [
                                  Checkbox(
                                    value: newIsActive,
                                    activeColor: const Color(0xFF0066FF),
                                    checkColor: Colors.white,
                                    onChanged: (val) => setModalState(() => newIsActive = val ?? true),
                                  ),
                                  const Text('Is Active', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          const Text('PERSONAL', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: newFirstNameCtrl,
                                  style: const TextStyle(color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    labelText: 'First Name *',
                                    labelStyle: const TextStyle(color: Color(0xFFDC2626)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: newMiddleNameCtrl,
                                  style: const TextStyle(color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    labelText: 'Middle Name *',
                                    labelStyle: const TextStyle(color: Color(0xFFDC2626)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: newLastNameCtrl,
                                  style: const TextStyle(color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    labelText: 'Last Name *',
                                    labelStyle: const TextStyle(color: Color(0xFFDC2626)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () async {
                              DateTime initial = DateTime(1985, 1, 1);
                              if (newBirthDateCtrl.text.isNotEmpty) {
                                try {
                                  initial = DateTime.parse(newBirthDateCtrl.text);
                                } catch (_) {}
                              }
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: initial,
                                firstDate: DateTime(1920),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                final formatted = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                setModalState(() {
                                  newBirthDateCtrl.text = formatted;
                                });
                              }
                            },
                            child: IgnorePointer(
                              child: TextField(
                                controller: newBirthDateCtrl,
                                readOnly: true,
                                style: const TextStyle(color: Color(0xFF0F172A)),
                                decoration: InputDecoration(
                                  labelText: 'Birth Date',
                                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                                  suffixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF0066FF), size: 20),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          const Text('SPECIALIZATION / TYPE / PRACTICE', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            color: const Color(0xFFF1F5F9),
                                            child: Row(
                                              children: const [
                                                SizedBox(width: 24, child: Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14)),
                                                Expanded(child: Text('Specialty', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold))),
                                                Text('Sub Specialty', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold)),
                                                SizedBox(width: 24),
                                              ],
                                            ),
                                          ),
                                          if (newSpecialtiesList.isEmpty)
                                            const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: Text('No specialty added', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                            )
                                          else
                                            ...newSpecialtiesList.asMap().entries.map((entry) {
                                              final idx = entry.key;
                                              final s = entry.value;
                                              final specObj = _specializations.firstWhere(
                                                (sp) => sp.name == s.hcpSpecialty,
                                                orElse: () => Specialization(name: s.hcpSpecialty, specialty: s.hcpSpecialty, specialtyGroup: '', isGroup: false),
                                              );
                                              final subObj = s.subSpecialty != null
                                                  ? _specializations.firstWhere(
                                                      (sp) => sp.name == s.subSpecialty,
                                                      orElse: () => Specialization(name: s.subSpecialty!, specialty: s.subSpecialty!, specialtyGroup: '', isGroup: false),
                                                    )
                                                  : null;
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                child: Row(
                                                  children: [
                                                    InkWell(
                                                      onTap: () {
                                                        setModalState(() {
                                                          final old = newSpecialtiesList[idx];
                                                          newSpecialtiesList[idx] = HcpSpecialty(
                                                            hcpSpecialty: old.hcpSpecialty,
                                                            subSpecialty: old.subSpecialty,
                                                            isPrimary: !old.isPrimary,
                                                          );
                                                        });
                                                      },
                                                      child: SizedBox(
                                                        width: 24,
                                                        child: Icon(
                                                          s.isPrimary ? Icons.star_rounded : Icons.star_border_rounded,
                                                          size: 18,
                                                          color: s.isPrimary ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          Expanded(child: Text(specObj.specialty, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12), overflow: TextOverflow.ellipsis)),
                                                          if (s.isPrimary) ...[
                                                            const SizedBox(width: 4),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFFEF3C7),
                                                                borderRadius: BorderRadius.circular(4),
                                                                border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                                                              ),
                                                              child: const Text('Preferred', style: TextStyle(color: Color(0xFFB45309), fontSize: 9, fontWeight: FontWeight.bold)),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(subObj?.specialty ?? '-', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                                    const SizedBox(width: 4),
                                                    GestureDetector(
                                                      onTap: () {
                                                        setModalState(() {
                                                          newSpecialtiesList.removeAt(idx);
                                                        });
                                                      },
                                                      child: const Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B192C)),
                                        icon: const Icon(Icons.add, size: 14, color: Colors.white),
                                        label: const Text('+ Add Row', style: TextStyle(color: Colors.white, fontSize: 12)),
                                        onPressed: () {
                                          String? selSpec = _specializations.isNotEmpty ? _specializations.first.name : null;
                                          String? selSub;
                                          bool isPreferred = newSpecialtiesList.isEmpty;
                                          showDialog(
                                            context: context,
                                            builder: (dialogCtx) => StatefulBuilder(
                                              builder: (ctx, setDlgState) {
                                                final currentSpecObj = _specializations.firstWhere(
                                                  (s) => s.name == selSpec,
                                                  orElse: () => _specializations.isNotEmpty ? _specializations.first : Specialization(name: '', specialty: '', specialtyGroup: ''),
                                                );
                                                final currentSubSpecObj = selSub != null
                                                    ? _specializations.firstWhere(
                                                        (s) => s.name == selSub,
                                                        orElse: () => Specialization(name: selSub!, specialty: selSub!, specialtyGroup: ''),
                                                      )
                                                    : null;

                                                final subSpecs = _specializations.where((s) =>
                                                    (s.parentSpecialization != null &&
                                                        (s.parentSpecialization == selSpec ||
                                                         s.parentSpecialization == currentSpecObj.specialty ||
                                                         s.parentSpecialization == currentSpecObj.name)) ||
                                                    (s.specialtyGroup.isNotEmpty && s.specialtyGroup == currentSpecObj.specialty)
                                                ).toList();

                                                return AlertDialog(
                                                  backgroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  title: const Text('Add Specialty', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                                                  content: SingleChildScrollView(
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Text('Specialty Name *', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                                                        const SizedBox(height: 6),
                                                        InkWell(
                                                          onTap: () async {
                                                            final picked = await _showSpecializationSearchDialog(
                                                              context: context,
                                                              currentSelectedName: selSpec,
                                                            );
                                                            if (picked != null) {
                                                              setDlgState(() {
                                                                selSpec = picked.name;
                                                                selSub = null;
                                                              });
                                                            }
                                                          },
                                                          borderRadius: BorderRadius.circular(8),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFF8FAFC),
                                                              borderRadius: BorderRadius.circular(8),
                                                              border: Border.all(color: const Color(0xFFCBD5E1)),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                const Icon(Icons.medical_services_outlined, color: Color(0xFF0066FF), size: 18),
                                                                const SizedBox(width: 10),
                                                                Expanded(
                                                                  child: Text(
                                                                    currentSpecObj.specialty.isNotEmpty ? currentSpecObj.specialty : 'Tap to search specialty...',
                                                                    style: TextStyle(
                                                                      color: currentSpecObj.specialty.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                                                      fontSize: 13,
                                                                      fontWeight: FontWeight.w500,
                                                                    ),
                                                                  ),
                                                                ),
                                                                const Icon(Icons.search_rounded, color: Color(0xFF0066FF), size: 18),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 14),
                                                        const Text('Sub-Specialty Name (Optional)', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                                                        const SizedBox(height: 6),
                                                        InkWell(
                                                          onTap: () async {
                                                            final picked = await _showSpecializationSearchDialog(
                                                              context: context,
                                                              currentSelectedName: selSub,
                                                              customList: subSpecs.isNotEmpty ? subSpecs : _specializations.where((s) => !s.isGroup).toList(),
                                                              title: 'Select Sub-Specialty',
                                                            );
                                                            if (picked != null) {
                                                              setDlgState(() {
                                                                selSub = picked.name;
                                                              });
                                                            }
                                                          },
                                                          borderRadius: BorderRadius.circular(8),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFF8FAFC),
                                                              borderRadius: BorderRadius.circular(8),
                                                              border: Border.all(color: const Color(0xFFCBD5E1)),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                const Icon(Icons.subdirectory_arrow_right_rounded, color: Color(0xFF0066FF), size: 18),
                                                                const SizedBox(width: 10),
                                                                Expanded(
                                                                  child: Text(
                                                                    currentSubSpecObj?.specialty ?? 'None (Tap to search sub-specialty)',
                                                                    style: TextStyle(
                                                                      color: currentSubSpecObj != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                                                      fontSize: 13,
                                                                      fontWeight: FontWeight.w500,
                                                                    ),
                                                                  ),
                                                                ),
                                                                if (selSub != null)
                                                                  GestureDetector(
                                                                    onTap: () => setDlgState(() => selSub = null),
                                                                    child: const Padding(
                                                                      padding: EdgeInsets.only(right: 6),
                                                                      child: Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                                                    ),
                                                                  ),
                                                                const Icon(Icons.search_rounded, color: Color(0xFF0066FF), size: 18),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 12),
                                                        CheckboxListTile(
                                                          contentPadding: EdgeInsets.zero,
                                                          title: const Text('Set as Preferred Specialization', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                                                          subtitle: const Text('Designates primary specialty for this doctor', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                                          activeColor: const Color(0xFF0066FF),
                                                          checkColor: Colors.white,
                                                          value: isPreferred,
                                                          onChanged: (val) => setDlgState(() => isPreferred = val ?? false),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(dialogCtx),
                                                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
                                                      onPressed: () {
                                                        if (selSpec != null) {
                                                          final specMatch = _specializations.firstWhere((s) => s.name == selSpec, orElse: () => _specializations.first);
                                                          final subMatch = selSub != null ? _specializations.firstWhere((s) => s.name == selSub, orElse: () => _specializations.first) : null;
                                                          setModalState(() {
                                                            newSpecialtiesList.add(HcpSpecialty(
                                                              hcpSpecialty: specMatch.name,
                                                              subSpecialty: subMatch?.name,
                                                              isPrimary: isPreferred,
                                                            ));
                                                          });
                                                          Navigator.pop(dialogCtx);
                                                        }
                                                      },
                                                      child: const Text('Add Row', style: TextStyle(color: Colors.white)),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    DropdownButtonFormField<String>(
                                      value: newHcpType,
                                      dropdownColor: Colors.white,
                                      style: const TextStyle(color: Color(0xFF0F172A)),
                                      decoration: InputDecoration(
                                        labelText: 'Type *',
                                        labelStyle: const TextStyle(color: Color(0xFFDC2626)),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                                      ),
                                      items: _hcpTypes.map((t) => DropdownMenuItem(value: t.name, child: Text(t.typeName))).toList(),
                                      onChanged: (val) => setModalState(() => newHcpType = val!),
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      value: newPractice,
                                      dropdownColor: Colors.white,
                                      style: const TextStyle(color: Color(0xFF0F172A)),
                                      decoration: InputDecoration(
                                        labelText: 'Practice *',
                                        labelStyle: const TextStyle(color: Color(0xFFDC2626)),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'Prescribing', child: Text('Prescribing')),
                                        DropdownMenuItem(value: 'Dispensing', child: Text('Dispensing')),
                                        DropdownMenuItem(value: 'Both', child: Text('Both')),
                                      ],
                                      onChanged: (val) => setModalState(() => newPractice = val!),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          const Text('WORKPLACES / CONTACT INFO', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            color: const Color(0xFFF1F5F9),
                                            child: Row(
                                              children: const [
                                                SizedBox(width: 24, child: Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14)),
                                                Expanded(child: Text('Workplace', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold))),
                                                Text('City', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold)),
                                                SizedBox(width: 24),
                                              ],
                                            ),
                                          ),
                                          if (newWorkplacesList.isEmpty)
                                            const Padding(
                                              padding: EdgeInsets.all(10),
                                              child: Text('No workplace added', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                            )
                                          else
                                            ...newWorkplacesList.asMap().entries.map((entry) {
                                              final idx = entry.key;
                                              final w = entry.value;
                                              final instObj = _institutions.firstWhere(
                                                (i) => i.name == w.workplace,
                                                orElse: () => Institution(name: w.workplace, institutionName: w.address ?? w.workplace),
                                              );
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                child: Row(
                                                  children: [
                                                    InkWell(
                                                      onTap: () {
                                                        setModalState(() {
                                                          final old = newWorkplacesList[idx];
                                                          newWorkplacesList[idx] = HcpWorkplace(
                                                            workplace: old.workplace,
                                                            address: old.address,
                                                            cityMunicipality: old.cityMunicipality,
                                                            provinceName: old.provinceName,
                                                            isPrimary: !old.isPrimary,
                                                          );
                                                        });
                                                      },
                                                      child: SizedBox(
                                                        width: 24,
                                                        child: Icon(
                                                          w.isPrimary ? Icons.star_rounded : Icons.star_border_rounded,
                                                          size: 18,
                                                          color: w.isPrimary ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          Expanded(child: Text(instObj.institutionName, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12), overflow: TextOverflow.ellipsis)),
                                                          if (w.isPrimary) ...[
                                                            const SizedBox(width: 4),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFFEF3C7),
                                                                borderRadius: BorderRadius.circular(4),
                                                                border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                                                              ),
                                                              child: const Text('Preferred', style: TextStyle(color: Color(0xFFB45309), fontSize: 9, fontWeight: FontWeight.bold)),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(instObj.cityMunicipality ?? w.cityMunicipality ?? 'Ermita', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                                    const SizedBox(width: 4),
                                                    GestureDetector(
                                                      onTap: () {
                                                        setModalState(() {
                                                          newWorkplacesList.removeAt(idx);
                                                        });
                                                      },
                                                      child: const Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B192C)),
                                      icon: const Icon(Icons.add, size: 14, color: Colors.white),
                                      label: const Text('+ Add Row', style: TextStyle(color: Colors.white, fontSize: 12)),
                                      onPressed: () {
                                        String? selInst = _institutions.isNotEmpty ? _institutions.first.name : null;
                                        bool isPreferred = newWorkplacesList.isEmpty;
                                        showDialog(
                                          context: context,
                                          builder: (dialogCtx) => StatefulBuilder(
                                            builder: (ctx, setDlgState) {
                                              final currentInstObj = selInst != null
                                                  ? _institutions.firstWhere(
                                                      (i) => i.name == selInst,
                                                      orElse: () => Institution(name: selInst!, institutionName: selInst!),
                                                    )
                                                  : (_institutions.isNotEmpty ? _institutions.first : null);

                                              return AlertDialog(
                                                backgroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                title: const Text('Add Workplace', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                                                content: SingleChildScrollView(
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('Workplace / Hospital *', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                                                      const SizedBox(height: 6),
                                                      InkWell(
                                                        onTap: () async {
                                                          final picked = await _showInstitutionSearchDialog(
                                                            context: context,
                                                            currentSelectedName: selInst,
                                                          );
                                                          if (picked != null) {
                                                            setDlgState(() => selInst = picked.name);
                                                          }
                                                        },
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFF8FAFC),
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              const Icon(Icons.local_hospital_outlined, color: Color(0xFF0066FF), size: 18),
                                                              const SizedBox(width: 10),
                                                              Expanded(
                                                                child: Text(
                                                                  currentInstObj?.institutionName ?? 'Tap to search hospital / clinic...',
                                                                  style: TextStyle(
                                                                    color: currentInstObj != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                                                    fontSize: 13,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                ),
                                                              ),
                                                              const Icon(Icons.search_rounded, color: Color(0xFF0066FF), size: 18),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 12),
                                                      CheckboxListTile(
                                                        contentPadding: EdgeInsets.zero,
                                                        title: const Text('Set as Preferred Workplace', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                                                        subtitle: const Text('Designates primary clinic or hospital for this program', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                                        activeColor: const Color(0xFF0066FF),
                                                        checkColor: Colors.white,
                                                        value: isPreferred,
                                                        onChanged: (val) => setDlgState(() => isPreferred = val ?? false),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(dialogCtx),
                                                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
                                                    onPressed: () {
                                                      if (selInst != null) {
                                                        final instMatch = _institutions.firstWhere((i) => i.name == selInst, orElse: () => _institutions.first);
                                                        setModalState(() {
                                                          newWorkplacesList.add(HcpWorkplace(
                                                            workplace: instMatch.name,
                                                            address: instMatch.institutionName,
                                                            cityMunicipality: instMatch.cityMunicipality,
                                                            provinceName: instMatch.provinceName,
                                                            isPrimary: isPreferred,
                                                          ));
                                                        });
                                                        Navigator.pop(dialogCtx);
                                                      }
                                                    },
                                                    child: const Text('Add Row', style: TextStyle(color: Colors.white)),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            color: const Color(0xFFF1F5F9),
                                            child: Row(
                                              children: const [
                                                SizedBox(width: 24, child: Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14)),
                                                Expanded(child: Text('Mobile/Phone', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold))),
                                                Text('Email', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold)),
                                                SizedBox(width: 24),
                                              ],
                                            ),
                                          ),
                                          if (newContactsList.isEmpty)
                                            const Padding(
                                              padding: EdgeInsets.all(10),
                                              child: Text('No contact added', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                            )
                                          else
                                            ...newContactsList.asMap().entries.map((entry) {
                                              final idx = entry.key;
                                              final c = entry.value;
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                child: Row(
                                                  children: [
                                                    InkWell(
                                                      onTap: () {
                                                        setModalState(() {
                                                          final old = newContactsList[idx];
                                                          newContactsList[idx] = HcpContact(
                                                            contactNumber: old.contactNumber,
                                                            emailAddress: old.emailAddress,
                                                            isPrimary: !old.isPrimary,
                                                          );
                                                        });
                                                      },
                                                      child: SizedBox(
                                                        width: 24,
                                                        child: Icon(
                                                          c.isPrimary ? Icons.star_rounded : Icons.star_border_rounded,
                                                          size: 18,
                                                          color: c.isPrimary ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          Expanded(child: Text(c.contactNumber ?? 'N/A', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12), overflow: TextOverflow.ellipsis)),
                                                          if (c.isPrimary) ...[
                                                            const SizedBox(width: 4),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFFEF3C7),
                                                                borderRadius: BorderRadius.circular(4),
                                                                border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                                                              ),
                                                              child: const Text('Preferred', style: TextStyle(color: Color(0xFFB45309), fontSize: 9, fontWeight: FontWeight.bold)),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(c.emailAddress ?? 'None', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                                    const SizedBox(width: 4),
                                                    GestureDetector(
                                                      onTap: () {
                                                        setModalState(() {
                                                          newContactsList.removeAt(idx);
                                                        });
                                                      },
                                                      child: const Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B192C)),
                                      icon: const Icon(Icons.add, size: 14, color: Colors.white),
                                      label: const Text('+ Add Row', style: TextStyle(color: Colors.white, fontSize: 12)),
                                      onPressed: () {
                                        String phone = '';
                                        String email = '';
                                        bool isPreferred = newContactsList.isEmpty;
                                        showDialog(
                                          context: context,
                                          builder: (dialogCtx) => StatefulBuilder(
                                            builder: (ctx, setDlgState) => AlertDialog(
                                              backgroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              title: const Text('Add Contact Info', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                                              content: SingleChildScrollView(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    TextFormField(
                                                      style: const TextStyle(color: Color(0xFF0F172A)),
                                                      decoration: const InputDecoration(labelText: 'Mobile/Phone Number', labelStyle: TextStyle(color: Color(0xFF64748B))),
                                                      onChanged: (val) => phone = val,
                                                    ),
                                                    TextFormField(
                                                      style: const TextStyle(color: Color(0xFF0F172A)),
                                                      decoration: const InputDecoration(labelText: 'Email Address', labelStyle: TextStyle(color: Color(0xFF64748B))),
                                                      onChanged: (val) => email = val,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    CheckboxListTile(
                                                      contentPadding: EdgeInsets.zero,
                                                      title: const Text('Set as Preferred Contact Info', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                                                      subtitle: const Text('Designates primary contact number or email', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                                      activeColor: const Color(0xFF0066FF),
                                                      checkColor: Colors.white,
                                                      value: isPreferred,
                                                      onChanged: (val) => setDlgState(() => isPreferred = val ?? false),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(dialogCtx),
                                                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
                                                  onPressed: () {
                                                    if (phone.isNotEmpty || email.isNotEmpty) {
                                                      setModalState(() {
                                                        newContactsList.add(HcpContact(
                                                          contactNumber: phone.isNotEmpty ? phone : null,
                                                          emailAddress: email.isNotEmpty ? email : null,
                                                          isPrimary: isPreferred,
                                                        ));
                                                      });
                                                      Navigator.pop(dialogCtx);
                                                    }
                                                  },
                                                  child: const Text('Add Row', style: TextStyle(color: Colors.white)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- STEP 2: DOCTOR'S INFORMATION ---
  Widget _buildStep2DoctorInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DOCTOR\'S INFORMATION', style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          // Image 1 Header Section Layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Profile Photo (Display-Only / Non-Editable for Security)
              Container(
                width: 110,
                height: 130,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (_doctorPhotoBytes != null || (_doctorPhotoUrl != null && _doctorPhotoUrl!.isNotEmpty))
                        ? const Color(0xFF0066FF).withOpacity(0.5)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: _doctorPhotoBytes != null
                      ? Image.memory(_doctorPhotoBytes!, fit: BoxFit.cover)
                      : (_doctorPhotoUrl != null && _doctorPhotoUrl!.isNotEmpty
                          ? Image.network(
                              Provider.of<ApiService>(context, listen: false).formatFileUrl(_doctorPhotoUrl),
                              headers: Provider.of<ApiService>(context, listen: false).authHeaders,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFF64748B), size: 64),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.account_box_rounded, color: Color(0xFF94A3B8), size: 48),
                                SizedBox(height: 4),
                                Text('HCP Photo', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                                Text('(HCP Record)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9)),
                              ],
                            )),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _hcpFullNameController,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'HCP Full Name',
                        labelStyle: const TextStyle(color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _showHcpSelectorModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0066FF)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDoctor != null ? '${_selectedDoctor!.name}' : 'Select HCP *',
                              style: const TextStyle(color: Color(0xFF0B192C), fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace'),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF0066FF), size: 14),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'To begin, search for your doctor by typing the surname, the firstname, or both in the box provided.\nIf you could not find your doctor, create a new doctor profile instead.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text('BASIC INFO', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'First Name *',
                    labelStyle: const TextStyle(color: Color(0xFFDC2626)),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFDC2626)), borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF0066FF), width: 2), borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _middleNameController,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Middle Name *',
                    labelStyle: const TextStyle(color: Color(0xFFDC2626)),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFDC2626)), borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF0066FF), width: 2), borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Last Name *',
                    labelStyle: const TextStyle(color: Color(0xFFDC2626)),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFDC2626)), borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF0066FF), width: 2), borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    DateTime initial = DateTime(1985, 1, 1);
                    if (_birthDateController.text.isNotEmpty) {
                      try {
                        initial = DateTime.parse(_birthDateController.text);
                      } catch (_) {}
                    }
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      final formatted = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      setState(() {
                        _birthDateController.text = formatted;
                      });
                    }
                  },
                  child: IgnorePointer(
                    child: TextFormField(
                      controller: _birthDateController,
                      readOnly: true,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'Birth Date',
                        labelStyle: const TextStyle(color: Color(0xFF64748B)),
                        suffixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF0066FF), size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF0066FF), width: 2), borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text('SPECIALIZATION / TYPE / PRACTICE', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            color: const Color(0xFFF1F5F9),
                            child: Row(
                              children: const [
                                SizedBox(width: 24, child: Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14)),
                                Expanded(child: Text('Specialty Name', style: TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.bold))),
                                Text('Sub Specialty Name', style: TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.bold)),
                                SizedBox(width: 44),
                              ],
                            ),
                          ),
                          ..._selectedSpecialties.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final s = entry.value;

                            final specLookup = {for (var sp in _specializations) sp.name: sp.specialty};
                            final rawSpec = (s.specialtyName != null && s.specialtyName!.isNotEmpty) ? s.specialtyName! : (s.hcpSpecialty ?? '');
                            final specName = specLookup[rawSpec] ?? rawSpec;
                            final rawSub = (s.subSpecialtyName != null && s.subSpecialtyName!.isNotEmpty && s.subSpecialtyName != '-') ? s.subSpecialtyName! : (s.subSpecialty ?? '-');
                            final subName = specLookup[rawSub] ?? rawSub;

                            return InkWell(
                              onTap: () => _showEditSpecialtyDialog(idx),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          final old = _selectedSpecialties[idx];
                                          _selectedSpecialties[idx] = SubmissionSpecialty(
                                            preferred: !old.preferred,
                                            hcpSpecialty: old.hcpSpecialty,
                                            specialtyName: old.specialtyName,
                                            subSpecialty: old.subSpecialty,
                                            subSpecialtyName: old.subSpecialtyName,
                                          );
                                        });
                                      },
                                      child: SizedBox(
                                        width: 24,
                                        child: Icon(
                                          s.preferred ? Icons.star_rounded : Icons.star_border_rounded,
                                          size: 18,
                                          color: s.preferred ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              specName,
                                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (s.preferred) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                                              ),
                                              child: const Text('Preferred', style: TextStyle(color: Color(0xFFB45309), fontSize: 9, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(subName, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _showEditSpecialtyDialog(idx),
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(Icons.edit_outlined, size: 14, color: Color(0xFF0066FF)),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedSpecialties.removeAt(idx);
                                        });
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B192C)),
                        icon: const Icon(Icons.add, size: 14, color: Colors.white),
                        label: const Text('Add Row', style: TextStyle(color: Colors.white, fontSize: 12)),
                        onPressed: _showAddSpecialtySelector,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedHcpType,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'Type *',
                        labelStyle: const TextStyle(color: Color(0xFFDC2626)),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFDC2626)), borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF0066FF), width: 2), borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _hcpTypes.map((t) => DropdownMenuItem(value: t.name, child: Text(t.typeName))).toList(),
                      onChanged: (val) => setState(() => _selectedHcpType = val),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedPractice,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'Practice *',
                        labelStyle: const TextStyle(color: Color(0xFFDC2626)),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFDC2626)), borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF0066FF), width: 2), borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Prescribing', child: Text('Prescribing')),
                        DropdownMenuItem(value: 'Dispensing', child: Text('Dispensing')),
                        DropdownMenuItem(value: 'Both', child: Text('Both')),
                      ],
                      onChanged: (val) => setState(() => _selectedPractice = val!),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text('WORKPLACES / CONTACT INFO', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            color: const Color(0xFFF1F5F9),
                            child: Row(
                              children: const [
                                SizedBox(width: 24, child: Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14)),
                                Expanded(child: Text('Workplace Name', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold))),
                                Text('City Name', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold)),
                                SizedBox(width: 8),
                                Text('Province Name', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold)),
                                SizedBox(width: 44),
                              ],
                            ),
                          ),
                          ..._selectedWorkplaces.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final w = entry.value;
                            return InkWell(
                              onTap: () => _showEditWorkplaceDialog(idx),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          final old = _selectedWorkplaces[idx];
                                          _selectedWorkplaces[idx] = SubmissionWorkplace(
                                            preferred: !old.preferred,
                                            hcpWorkplace: old.hcpWorkplace,
                                            workplaceName: old.workplaceName,
                                            cityMunicipality: old.cityMunicipality,
                                            cityTitle: old.cityTitle,
                                            provinceName: old.provinceName,
                                            provinceTitle: old.provinceTitle,
                                          );
                                        });
                                      },
                                      child: SizedBox(
                                        width: 24,
                                        child: Icon(
                                          w.preferred ? Icons.star_rounded : Icons.star_border_rounded,
                                          size: 18,
                                          color: w.preferred ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              w.workplaceName ?? 'Manila Doctors Hospital',
                                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (w.preferred) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                                              ),
                                              child: const Text('Preferred', style: TextStyle(color: Color(0xFFB45309), fontSize: 9, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(w.cityTitle ?? 'Ermita', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                    const SizedBox(width: 8),
                                    Text(w.provinceTitle ?? 'Metro Manila-Manila', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _showEditWorkplaceDialog(idx),
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(Icons.edit_outlined, size: 14, color: Color(0xFF0066FF)),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedWorkplaces.removeAt(idx);
                                        });
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 6),
                                        child: Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B192C)),
                      icon: const Icon(Icons.add, size: 14, color: Colors.white),
                      label: const Text('Add Row', style: TextStyle(color: Colors.white, fontSize: 12)),
                      onPressed: _showAddWorkplaceSelector,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            color: const Color(0xFFF1F5F9),
                            child: Row(
                              children: const [
                                SizedBox(width: 24, child: Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14)),
                                Expanded(child: Text('Mobile/Phone Number', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold))),
                                Text('Email Address', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold)),
                                SizedBox(width: 44),
                              ],
                            ),
                          ),
                          ..._contacts.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final c = entry.value;
                            return InkWell(
                              onTap: () => _showEditContactDialog(idx),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          final old = _contacts[idx];
                                          _contacts[idx] = SubmissionContact(
                                            preferred: !old.preferred,
                                            contactNumber: old.contactNumber,
                                            emailAddress: old.emailAddress,
                                          );
                                        });
                                      },
                                      child: SizedBox(
                                        width: 24,
                                        child: Icon(
                                          c.preferred ? Icons.star_rounded : Icons.star_border_rounded,
                                          size: 18,
                                          color: c.preferred ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              c.contactNumber ?? 'N/A',
                                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (c.preferred) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                                              ),
                                              child: const Text('Preferred', style: TextStyle(color: Color(0xFFB45309), fontSize: 9, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(c.emailAddress ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _showEditContactDialog(idx),
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(Icons.edit_outlined, size: 14, color: Color(0xFF0066FF)),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _contacts.removeAt(idx);
                                        });
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 6),
                                        child: Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B192C)),
                      icon: const Icon(Icons.add, size: 14, color: Colors.white),
                      label: const Text('Add Row', style: TextStyle(color: Colors.white, fontSize: 12)),
                      onPressed: _showAddContactSelector,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- STEP 3: SURVEY QUESTIONNAIRE ---
  Widget _buildStep3Survey() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final progList = _programs.isNotEmpty ? _programs : apiService.availablePrograms;
    final currentVal = progList.contains(_selectedProgram) ? _selectedProgram : (progList.isNotEmpty ? progList.first : 'Abbott Diabetes Care');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SURVEY QUESTIONNAIRE', style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: currentVal,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: 'Account/Program',
              labelStyle: const TextStyle(color: Color(0xFF64748B)),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF0066FF), width: 2), borderRadius: BorderRadius.circular(8)),
            ),
            items: progList.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedProgram = val;
                });
                apiService.setProgram(val);
                _updateActiveSurveyForProgram(val);
              }
            },
          ),
          const SizedBox(height: 20),
          if (_activeSurvey == null || _activeSurvey!.questions.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No survey questionnaire is currently configured for "$currentVal". You can proceed directly to the next step.',
                      style: const TextStyle(color: Color(0xFF0369A1), fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._activeSurvey!.questions.map((q) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.question, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF0066FF), width: 2), borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => _surveyAnswers[q.question] = val,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // --- OTHERS STEP ---
  Widget _buildOthersStep() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final monthStr = _submissionDate.month.toString().padLeft(2, '0');
    final dayStr = _submissionDate.day.toString().padLeft(2, '0');
    final yearStr = _submissionDate.year.toString();
    final hourStr = _submissionDate.hour.toString().padLeft(2, '0');
    final minuteStr = _submissionDate.minute.toString().padLeft(2, '0');
    final secondStr = _submissionDate.second.toString().padLeft(2, '0');
    final formattedDateStr = '$monthStr-$dayStr-$yearStr $hourStr:$minuteStr:$secondStr';

    final territoryList = _territories.isNotEmpty ? _territories : ['AD0110', 'AD0120', 'AD0130', 'AD0140', 'AD0150', 'CORE01', 'CORE02', 'NCR-01', 'NCR-02', 'All Territories'];
    final currentTerritory = territoryList.contains(_selectedTerritory) ? _selectedTerritory : territoryList.first;

    final progList = _programs.isNotEmpty ? _programs : apiService.availablePrograms;
    final currentProgram = progList.contains(_selectedProgram) ? _selectedProgram : (progList.isNotEmpty ? progList.first : 'Abbott Diabetes Care');

    Widget buildLeftFields() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: currentTerritory,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: 'Territory Code *',
              labelStyle: const TextStyle(color: Color(0xFF64748B)),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF0066FF), width: 2), borderRadius: BorderRadius.circular(8)),
            ),
            items: territoryList.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedTerritory = val;
                  _territoryManagerController.text = apiService.getTerritoryManagerForTerritory(val);
                });
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _territoryManagerController,
            readOnly: true,
            style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Territory Manager (Read-Only)',
              labelStyle: const TextStyle(color: Color(0xFF64748B)),
              prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF64748B), size: 18),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              helperText: 'Automatically assigned based on the selected Territory Code',
              helperStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF0066FF), width: 2), borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: currentProgram,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: 'Account/Program *',
              labelStyle: const TextStyle(color: Color(0xFF64748B)),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF0066FF), width: 2), borderRadius: BorderRadius.circular(8)),
            ),
            items: progList.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedProgram = val;
                });
                apiService.setProgram(val);
                _updateActiveSurveyForProgram(val);
              }
            },
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 4.0),
            child: Text(
              'This should be automatically populated depending on the user\'s account affiliation.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      );
    }

    Widget buildRightFields() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _showDateTimePicker,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Submission Date', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          formattedDateStr,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Asia/Manila',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.calendar_month_rounded, color: Color(0xFF0066FF), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: apiService.loggedInEmail ?? 'jptan@profinsights.biz',
            readOnly: true,
            style: const TextStyle(color: Color(0xFF64748B)),
            decoration: InputDecoration(
              labelText: 'Medrep Email Address',
              labelStyle: const TextStyle(color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 650;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: buildLeftFields()),
                const SizedBox(width: 24),
                Expanded(child: buildRightFields()),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildLeftFields(),
              const SizedBox(height: 16),
              buildRightFields(),
            ],
          );
        },
      ),
    );
  }

  // --- CHANGES STEP ---
  Widget _buildChangesStep() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final specLookup = {for (var s in _specializations) s.name: s.specialty};

    final currentDoctor = _selectedDoctor ?? widget.doctor;
    final bool isExistingDoctor = currentDoctor != null && (currentDoctor.name?.isNotEmpty ?? false);

    final fn = _firstNameController.text.trim();
    final mn = _middleNameController.text.trim();
    final ln = _lastNameController.text.trim();
    final parts = [
      if (fn.isNotEmpty) fn,
      if (mn.isNotEmpty && mn != '-') mn,
      if (ln.isNotEmpty) ln,
    ];
    final fullDoctorName = parts.where((p) => p.isNotEmpty).join(' ');

    final List<Map<String, String>> basicChanges = [];
    final List<Map<String, dynamic>> specAdded = [];
    final List<Map<String, dynamic>> specRemoved = [];
    final List<Map<String, dynamic>> wpAdded = [];
    final List<Map<String, dynamic>> wpRemoved = [];
    final List<Map<String, dynamic>> contactAdded = [];
    final List<Map<String, dynamic>> contactRemoved = [];

    if (isExistingDoctor) {
      if (ln != currentDoctor.lastName) {
        basicChanges.add({
          'field': 'last_name',
          'label': 'Last Name',
          'old': currentDoctor.lastName,
          'new': ln,
        });
      }
      if (fn != currentDoctor.firstName) {
        basicChanges.add({
          'field': 'first_name',
          'label': 'First Name',
          'old': currentDoctor.firstName,
          'new': fn,
        });
      }
      if (mn != (currentDoctor.middleName ?? '')) {
        basicChanges.add({
          'field': 'middle_name',
          'label': 'Middle Name',
          'old': currentDoctor.middleName ?? '-',
          'new': mn,
        });
      }
      if (_birthDateController.text.trim().isNotEmpty &&
          _birthDateController.text.trim() != (currentDoctor.birthDate ?? '')) {
        basicChanges.add({
          'field': 'birth_date',
          'label': 'Birth Date',
          'old': currentDoctor.birthDate ?? '-',
          'new': _birthDateController.text.trim(),
        });
      }
      if (_selectedHcpType != null && _selectedHcpType != currentDoctor.hcpType) {
        basicChanges.add({
          'field': 'hcp_type',
          'label': 'HCP Type',
          'old': currentDoctor.hcpType,
          'new': _selectedHcpType ?? '-',
        });
      }
      if (_selectedPractice != currentDoctor.hcpPractice) {
        basicChanges.add({
          'field': 'hcp_practice',
          'label': 'HCP Practice',
          'old': currentDoctor.hcpPractice,
          'new': _selectedPractice,
        });
      }

      final oldSpecs = currentDoctor.specialties.map((s) => s.hcpSpecialty).toSet();
      final newSpecs = _selectedSpecialties.where((s) => s.hcpSpecialty != null).map((s) => s.hcpSpecialty!).toSet();
      for (var s in _selectedSpecialties) {
        if (s.hcpSpecialty != null && !oldSpecs.contains(s.hcpSpecialty)) {
          specAdded.add({
            'hcp_specialty': s.hcpSpecialty,
            if (s.subSpecialty != null) 'sub_specialty': s.subSpecialty,
            if (s.specialtyName != null) 'specialty_name': s.specialtyName,
          });
        }
      }
      for (var s in currentDoctor.specialties) {
        if (!newSpecs.contains(s.hcpSpecialty)) {
          specRemoved.add({
            'hcp_specialty': s.hcpSpecialty,
            if (s.subSpecialty != null) 'sub_specialty': s.subSpecialty,
          });
        }
      }

      final oldWps = currentDoctor.workplaces.map((w) => w.workplace).toSet();
      final newWps = _selectedWorkplaces.where((w) => w.hcpWorkplace != null).map((w) => w.hcpWorkplace!).toSet();
      for (var w in _selectedWorkplaces) {
        if (w.hcpWorkplace != null && !oldWps.contains(w.hcpWorkplace)) {
          wpAdded.add({
            'hcp_workplace': w.hcpWorkplace,
            if (w.workplaceName != null) 'workplace_name': w.workplaceName,
          });
        }
      }
      for (var w in currentDoctor.workplaces) {
        if (!newWps.contains(w.workplace)) {
          wpRemoved.add({
            'hcp_workplace': w.workplace,
          });
        }
      }

      final oldNums = currentDoctor.contacts.map((c) => (c.contactNumber ?? '').trim()).where((n) => n.isNotEmpty).toSet();
      final oldEmails = currentDoctor.contacts.map((c) => (c.emailAddress ?? '').trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();

      for (var c in _contacts) {
        final cNum = (c.contactNumber ?? '').trim();
        final cEmail = (c.emailAddress ?? '').trim().toLowerCase();
        final isNumNew = cNum.isNotEmpty && !oldNums.contains(cNum);
        final isEmailNew = cEmail.isNotEmpty && !oldEmails.contains(cEmail);
        if (isNumNew || isEmailNew) {
          contactAdded.add({
            if (c.contactNumber != null && c.contactNumber!.isNotEmpty) 'contact_number': c.contactNumber,
            if (c.emailAddress != null && c.emailAddress!.isNotEmpty) 'email_address': c.emailAddress,
          });
        }
      }
      for (var oc in currentDoctor.contacts) {
        final ocNum = (oc.contactNumber ?? '').trim();
        final ocEmail = (oc.emailAddress ?? '').trim().toLowerCase();
        final match = _contacts.any((c) =>
            (ocNum.isNotEmpty && (c.contactNumber ?? '').trim() == ocNum) ||
            (ocEmail.isNotEmpty && (c.emailAddress ?? '').trim().toLowerCase() == ocEmail));
        if (!match && (ocNum.isNotEmpty || ocEmail.isNotEmpty)) {
          contactRemoved.add({
            if (oc.contactNumber != null) 'contact_number': oc.contactNumber,
            if (oc.emailAddress != null) 'email_address': oc.emailAddress,
          });
        }
      }
    } else {
      // New Doctor Registration: initial assignments
      for (var s in _selectedSpecialties) {
        if (s.hcpSpecialty != null) {
          specAdded.add({
            'hcp_specialty': s.hcpSpecialty,
            if (s.subSpecialty != null) 'sub_specialty': s.subSpecialty,
            if (s.specialtyName != null) 'specialty_name': s.specialtyName,
          });
        }
      }
      for (var w in _selectedWorkplaces) {
        if (w.hcpWorkplace != null) {
          wpAdded.add({
            'hcp_workplace': w.hcpWorkplace,
            if (w.workplaceName != null) 'workplace_name': w.workplaceName,
          });
        }
      }
      for (var c in _contacts) {
        if ((c.contactNumber != null && c.contactNumber!.isNotEmpty) || (c.emailAddress != null && c.emailAddress!.isNotEmpty)) {
          contactAdded.add({
            if (c.contactNumber != null) 'contact_number': c.contactNumber,
            if (c.emailAddress != null) 'email_address': c.emailAddress,
          });
        }
      }
    }

    final bool hasAnyChanges = basicChanges.isNotEmpty ||
        specAdded.isNotEmpty ||
        specRemoved.isNotEmpty ||
        wpAdded.isNotEmpty ||
        wpRemoved.isNotEmpty ||
        contactAdded.isNotEmpty ||
        contactRemoved.isNotEmpty;

    final changesMap = {
      'submission': currentDoctor?.name ?? '',
      'hcp': currentDoctor?.name ?? '',
      'generated_on': DateTime.now().toString().split('.').first,
      'generated_by': apiService.loggedInEmail ?? 'jptan@profinsights.biz',
      'version': 1,
      'changes': {
        'basic_information': basicChanges.map((c) => {
          'field': c['field'],
          'label': c['label'],
          'operation': 'modified',
          'old': c['old'],
          'new': c['new'],
        }).toList(),
        'specializations': {
          'added': specAdded,
          'removed': specRemoved,
        },
        'workplaces': {
          'added': wpAdded,
          'removed': wpRemoved,
        },
        'contact_information': {
          'added': contactAdded,
          'removed': contactRemoved,
        },
      },
    };

    final jsonPrettyStr = const JsonEncoder.withIndent('  ').convert(changesMap);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Summary of Changes', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isExistingDoctor ? const Color(0xFF0066FF).withOpacity(0.1) : const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isExistingDoctor ? const Color(0xFF0066FF).withOpacity(0.3) : const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Text(
                  isExistingDoctor ? 'EXISTING DOCTOR' : 'NEW DOCTOR REGISTRATION',
                  style: TextStyle(
                    color: isExistingDoctor ? const Color(0xFF0066FF) : const Color(0xFF059669),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (isExistingDoctor && !hasAnyChanges) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('No Changes Detected', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          'Profile for $fullDoctorName matches the master record. No field alterations detected.',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (basicChanges.isNotEmpty) ...[
            const Text('Basic Information', style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...basicChanges.map((c) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['label']!, style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('From: ${c['old']} → To: ${c['new']}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 14),
          ],

          if (!isExistingDoctor) ...[
            const Text('New Doctor Details', style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Full Name: $fullDoctorName', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Classification: ${_selectedHcpType ?? "Physician"} • Practice: $_selectedPractice', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                  if (_birthDateController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Birth Date: ${_birthDateController.text.trim()}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (specAdded.isNotEmpty || specRemoved.isNotEmpty || (!isExistingDoctor && _selectedSpecialties.isNotEmpty)) ...[
            const Text('Specializations', style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (specAdded.isNotEmpty) ...[
              Row(
                children: const [
                  Icon(Icons.check, color: Color(0xFF0066FF), size: 16),
                  SizedBox(width: 6),
                  Text('Added', style: TextStyle(color: Color(0xFF0066FF), fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              ...specAdded.map((s) {
                final rawSpec = (s['specialty_name'] != null && s['specialty_name'].toString().isNotEmpty) ? s['specialty_name'].toString() : (s['hcp_specialty']?.toString() ?? '');
                final specName = specLookup[rawSpec] ?? rawSpec;
                final rawSub = (s['sub_specialty'] != null && s['sub_specialty'].toString().isNotEmpty && s['sub_specialty'] != '-') ? s['sub_specialty'].toString() : '';
                final subName = specLookup[rawSub] ?? rawSub;
                return Padding(
                  padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                  child: Text('Specialty: ${s['hcp_specialty'] ?? specName}${subName.isNotEmpty ? ", Sub: ${s['sub_specialty'] ?? subName}" : ""}', style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                );
              }),
            ],
            if (specRemoved.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: const [
                  Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 16),
                  SizedBox(width: 6),
                  Text('Removed', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              ...specRemoved.map((s) {
                final specName = specLookup[s['hcp_specialty']] ?? s['hcp_specialty'] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                  child: Text('Specialty: $specName', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                );
              }),
            ],
            const SizedBox(height: 14),
          ],

          if (wpAdded.isNotEmpty || wpRemoved.isNotEmpty || (!isExistingDoctor && _selectedWorkplaces.isNotEmpty)) ...[
            const Text('Workplaces', style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (wpAdded.isNotEmpty) ...[
              Row(
                children: const [
                  Icon(Icons.check, color: Color(0xFF0066FF), size: 16),
                  SizedBox(width: 6),
                  Text('Added', style: TextStyle(color: Color(0xFF0066FF), fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              ...wpAdded.map((w) {
                return Padding(
                  padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                  child: Text('${w['workplace_name'] ?? w['hcp_workplace'] ?? "INST-00005"}', style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                );
              }),
            ],
            if (wpRemoved.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: const [
                  Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 16),
                  SizedBox(width: 6),
                  Text('Removed', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              ...wpRemoved.map((w) {
                return Padding(
                  padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                  child: Text('${w['workplace_name'] ?? w['hcp_workplace'] ?? ""}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                );
              }),
            ],
            const SizedBox(height: 14),
          ],

          if (contactAdded.isNotEmpty || contactRemoved.isNotEmpty || (!isExistingDoctor && _contacts.isNotEmpty)) ...[
            const Text('Contact Information', style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (contactAdded.isNotEmpty) ...[
              Row(
                children: const [
                  Icon(Icons.check, color: Color(0xFF0066FF), size: 16),
                  SizedBox(width: 6),
                  Text('Added', style: TextStyle(color: Color(0xFF0066FF), fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              ...contactAdded.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                  child: Text('Contact No.: ${c['contact_number'] ?? "None"}, Email: ${c['email_address'] ?? "None"}', style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
                );
              }),
            ],
            if (contactRemoved.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: const [
                  Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 16),
                  SizedBox(width: 6),
                  Text('Removed', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              ...contactRemoved.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                  child: Text('Contact No.: ${c['contact_number'] ?? "None"}, Email: ${c['email_address'] ?? "None"}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                );
              }),
            ],
            const SizedBox(height: 14),
          ],

          const SizedBox(height: 10),
          const Text('Changes JSON', style: TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                jsonPrettyStr,
                style: const TextStyle(color: Color(0xFF38BDF8), fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 20),

          DropdownButtonFormField<String>(
            value: _applicationStatus,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: 'Application Status',
              labelStyle: const TextStyle(color: Color(0xFF64748B)),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF0066FF), width: 2), borderRadius: BorderRadius.circular(8)),
            ),
            items: const [
              DropdownMenuItem(value: 'Not Applied', child: Text('Not Applied')),
              DropdownMenuItem(value: 'Applying', child: Text('Applying')),
              DropdownMenuItem(value: 'Applied', child: Text('Applied')),
              DropdownMenuItem(value: 'Failed', child: Text('Failed')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _applicationStatus = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final titles = _getTabTitles();
    final isLast = _currentStep == titles.length - 1;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () => setState(() => _currentStep--),
              child: const Text('Previous', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            )
          else
            const SizedBox(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B192C),
              disabledBackgroundColor: const Color(0xFF0B192C).withOpacity(0.4),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _currentStep == 0 && !_consentGiven
                ? null
                : () {
                    if (isLast) {
                      _submitForm();
                    } else {
                      setState(() => _currentStep++);
                    }
                  },
            child: Text(isLast ? 'Submit' : 'Next', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class SignatureCanvas extends StatefulWidget {
  final ValueNotifier<List<Offset>> pointsNotifier;
  const SignatureCanvas({Key? key, required this.pointsNotifier}) : super(key: key);

  @override
  State<SignatureCanvas> createState() => _SignatureCanvasState();
}

class _SignatureCanvasState extends State<SignatureCanvas> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        RenderBox renderBox = context.findRenderObject() as RenderBox;
        Offset localPosition = renderBox.globalToLocal(details.globalPosition);
        widget.pointsNotifier.value = List.from(widget.pointsNotifier.value)..add(localPosition);
      },
      onPanEnd: (details) {
        widget.pointsNotifier.value = List.from(widget.pointsNotifier.value)..add(Offset.infinite);
      },
      child: ValueListenableBuilder<List<Offset>>(
        valueListenable: widget.pointsNotifier,
        builder: (context, points, child) {
          return CustomPaint(
            painter: SignaturePainter(points: points),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset> points;
  SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.infinite && points[i + 1] != Offset.infinite) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
