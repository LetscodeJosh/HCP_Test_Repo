import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/hcp.dart';
import '../models/submission.dart';
import '../models/lookup_models.dart';
import '../services/api_service.dart';

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

  // Step 2: Doctor Info & Selection State
  Hcp? _selectedDoctor;
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

  // Others Tab State
  String _territoryCode = 'AD0110';
  DateTime _submissionDate = DateTime.now();
  String _applicationStatus = 'Not Applied';

  // Lookups
  List<Hcp> _allDoctors = [];
  List<Institution> _institutions = [];
  List<Specialization> _specializations = [];
  List<HcpType> _hcpTypes = [];
  HcpSurveyTemplate? _activeSurvey;

  @override
  void initState() {
    super.initState();
    _selectedDoctor = widget.doctor;
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

  void _prepopulateDoctorData(Hcp doctor) {
    _selectedSpecialties.clear();
    _selectedWorkplaces.clear();
    _contacts.clear();

    _firstNameController.text = doctor.firstName;
    _middleNameController.text = doctor.middleName ?? '-';
    _lastNameController.text = doctor.lastName;
    _birthDateController.text = doctor.birthDate ?? '';
    _selectedHcpType = doctor.hcpType;
    _selectedPractice = doctor.hcpPractice;

    for (var spec in doctor.specialties) {
      _selectedSpecialties.add(SubmissionSpecialty(
        hcpSpecialty: spec.hcpSpecialty,
        specialtyName: spec.hcpSpecialty,
        subSpecialty: spec.subSpecialty,
        subSpecialtyName: spec.subSpecialty,
      ));
    }
    for (var work in doctor.workplaces) {
      _selectedWorkplaces.add(SubmissionWorkplace(
        hcpWorkplace: work.workplace,
        workplaceName: work.address ?? work.workplace,
      ));
    }
    for (var contact in doctor.contacts) {
      _contacts.add(SubmissionContact(
        contactNumber: contact.contactValue,
        emailAddress: contact.contactType,
      ));
    }
  }

  Future<void> _loadLookups() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final doctors = await apiService.fetchDoctors();
      final insts = await apiService.fetchInstitutions();
      final specs = await apiService.fetchSpecializations();
      final types = await apiService.fetchHcpTypes();
      final templates = await apiService.fetchSurveyTemplates();

      setState(() {
        _allDoctors = doctors;
        _institutions = insts;
        _specializations = specs;
        _hcpTypes = types;

        if (_hcpTypes.isNotEmpty && (_selectedHcpType == null || _selectedHcpType!.isEmpty)) {
          _selectedHcpType = _hcpTypes.first.name;
        }

        if (templates.isNotEmpty) {
          _activeSurvey = templates.firstWhere(
            (t) => t.isActive && (t.accountOrProgram == apiService.selectedProgram || t.templateName.contains(apiService.selectedProgram)),
            orElse: () => templates.firstWhere((t) => t.isActive, orElse: () => templates.first),
          );
          for (var q in _activeSurvey!.questions) {
            _surveyAnswers[q.question] = '';
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (file != null) {
      setState(() {
        _consentPhotoFile = file;
      });
    }
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
    String? photoBase64;
    if (_consentPhotoFile != null) {
      final bytes = await _consentPhotoFile!.readAsBytes();
      photoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    final answersList = _surveyAnswers.entries.map((e) {
      return SubmissionAnswer(surveyQuestion: e.key, questionText: e.key, answer: e.value);
    }).toList();

    final changesMap = {
      'first_name': _firstNameController.text.trim(),
      'middle_name': _middleNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'hcp_type': _selectedHcpType,
      'hcp_practice': _selectedPractice,
      'specialties_count': _selectedSpecialties.length,
      'workplaces_count': _selectedWorkplaces.length,
      'contacts_count': _contacts.length,
      'application_status': _applicationStatus,
    };
    final changesJsonStr = jsonEncode(changesMap);
    final changeSummaryHtmlStr = '<ul><li><b>Contact Info Updated</b> (${_contacts.length} entries)</li><li><b>Specialties Linked</b>: ${_selectedSpecialties.length}</li><li><b>Workplaces Linked</b>: ${_selectedWorkplaces.length}</li></ul>';

    final submission = HcpProfileSubmission(
      hcpName: _selectedDoctor?.name ?? '',
      hcpFullName: '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      birthDate: _birthDateController.text.trim(),
      hcpType: _selectedHcpType,
      hcpPractice: _selectedPractice,
      consentPrivacyUnderstood: _consentGiven,
      consentSignature: sigUri.isNotEmpty ? sigUri : null,
      consentPhoto: photoBase64,
      specialties: _selectedSpecialties,
      workplaces: _selectedWorkplaces,
      contacts: _contacts,
      accountOrProgram: apiService.selectedProgram,
      surveyTemplate: _activeSurvey?.name,
      surveyTemplateTitle: _activeSurvey?.templateName,
      answers: answersList,
      medrepEmail: apiService.loggedInEmail ?? 'jptan@profinsights.biz',
      submissionDate: _submissionDate.toString().split('.').first,
      applicationStatus: _applicationStatus,
      changeSummaryHtml: changeSummaryHtmlStr,
      changesJson: changesJsonStr,
      docstatus: 1,
    );

    try {
      await apiService.createSubmission(submission);

      if (_selectedDoctor?.name != null) {
        final updatedDoctor = Hcp(
          name: _selectedDoctor!.name,
          firstName: _firstNameController.text.trim(),
          middleName: _middleNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          birthDate: _birthDateController.text.trim(),
          hcpType: _selectedHcpType ?? _selectedDoctor!.hcpType,
          hcpPractice: _selectedPractice,
          specialties: _selectedSpecialties.where((e) => e.hcpSpecialty != null).map((e) => HcpSpecialty(hcpSpecialty: e.hcpSpecialty!, subSpecialty: e.subSpecialty)).toList(),
          workplaces: _selectedWorkplaces.where((e) => e.hcpWorkplace != null).map((e) => HcpWorkplace(workplace: e.hcpWorkplace!, address: e.workplaceName)).toList(),
          contacts: _contacts.where((e) => e.contactNumber != null).map((e) => HcpContact(contactType: e.emailAddress ?? 'Mobile', contactValue: e.contactNumber!)).toList(),
        );
        await apiService.updateDoctor(_selectedDoctor!.name!, updatedDoctor);
      }

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('HCP Profile Submission saved & submitted successfully!')),
        );
        Navigator.pop(context);
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

  void _showAddSpecialtySelector() {
    String? selectedSpec = _specializations.isNotEmpty ? _specializations.first.name : null;
    String? selectedSubSpec;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentSpecObj = _specializations.firstWhere(
            (s) => s.name == selectedSpec,
            orElse: () => _specializations.first,
          );

          return AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Add Specialty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedSpec,
                  dropdownColor: const Color(0xFF2C2C2E),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Specialty Name',
                    labelStyle: TextStyle(color: Color(0xFF8E8E93)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF3C3C3E))),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0066FF), width: 2)),
                  ),
                  items: _specializations.map((s) => DropdownMenuItem(
                    value: s.name,
                    child: Text(s.specialty, style: const TextStyle(color: Colors.white)),
                  )).toList(),
                  onChanged: (val) {
                    setModalState(() {
                      selectedSpec = val;
                      selectedSubSpec = null;
                    });
                  },
                ),
                Builder(
                  builder: (context) {
                    final subSpecs = _specializations.where((s) => s.parentSpecialization == selectedSpec).toList();
                    if (subSpecs.isEmpty) return const SizedBox();
                    return Column(
                      children: [
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedSubSpec,
                          dropdownColor: const Color(0xFF2C2C2E),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Sub-Specialty Name (Optional)',
                            labelStyle: TextStyle(color: Color(0xFF8E8E93)),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF3C3C3E))),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0066FF), width: 2)),
                          ),
                          items: subSpecs.map((sub) => DropdownMenuItem(
                            value: sub.name,
                            child: Text(sub.specialty, style: const TextStyle(color: Colors.white)),
                          )).toList(),
                          onChanged: (val) {
                            setModalState(() {
                              selectedSubSpec = val;
                            });
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
                onPressed: () {
                  if (selectedSpec != null) {
                    setState(() {
                      _selectedSpecialties.add(SubmissionSpecialty(
                        hcpSpecialty: selectedSpec!,
                        specialtyName: currentSpecObj.specialty,
                        subSpecialty: selectedSubSpec,
                        subSpecialtyName: selectedSubSpec,
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Workplace', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: DropdownButtonFormField<String>(
          value: selectedInst,
          dropdownColor: const Color(0xFF2C2C2E),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Workplace / Hospital',
            labelStyle: TextStyle(color: Color(0xFF8E8E93)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF3C3C3E))),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0066FF), width: 2)),
          ),
          items: _institutions.map((i) => DropdownMenuItem(
            value: i.name,
            child: Text(i.institutionName, style: const TextStyle(color: Colors.white)),
          )).toList(),
          onChanged: (val) => selectedInst = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
            onPressed: () {
              if (selectedInst != null) {
                final match = _institutions.firstWhere((i) => i.name == selectedInst);
                setState(() {
                  _selectedWorkplaces.add(SubmissionWorkplace(
                    hcpWorkplace: selectedInst!,
                    workplaceName: match.institutionName,
                  ));
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add Row', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddContactSelector() {
    String phone = '';
    String email = '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Contact Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Mobile/Phone Number',
                labelStyle: TextStyle(color: Color(0xFF8E8E93)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3C3C3E))),
              ),
              onChanged: (val) => phone = val,
            ),
            TextFormField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Email Address',
                labelStyle: TextStyle(color: Color(0xFF8E8E93)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3C3C3E))),
              ),
              onChanged: (val) => email = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
            onPressed: () {
              if (phone.isNotEmpty || email.isNotEmpty) {
                setState(() {
                  _contacts.add(SubmissionContact(
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
    );
  }

  void _showDateTimePicker() {
    DateTime tempDate = _submissionDate;
    double tempHour = _submissionDate.hour.toDouble();
    double tempMinute = _submissionDate.minute.toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Submission Date & Time', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2E)),
                  icon: const Icon(Icons.calendar_today, color: Color(0xFF0066FF)),
                  label: Text(
                    'Date: ${tempDate.year}-${tempDate.month.toString().padLeft(2, '0')}-${tempDate.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white),
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
                Text('Hour: ${tempHour.toInt().toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                Text('Minute: ${tempMinute.toInt().toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
      color: const Color(0xFF1C1C1E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0066FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  titles[idx],
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF8E8E93),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          _selectedDoctor != null
              ? 'New HCP Profile Submission (Dr. ${_selectedDoctor!.firstName} ${_selectedDoctor!.lastName})'
              : 'New HCP Profile Submission',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1C1C1E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _submitForm,
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0066FF))),
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
          const Text('PRIVACY NOTICE AND CONSENT', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Please read the agreement carefully and then sign or take a group photo as proof of consent.',
            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2C2C2E)),
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
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
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
                    style: TextStyle(color: Color(0xFFFF453A), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 12.0, top: 4.0),
            child: Text(
              'I have read and understood the Privacy Policy and this Privacy Notice and Consent Form, and I consent to the processing of my personal data to receive personalized commercial and medical communications from PIMS, as described in the Privacy Policy.',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 20),

          // DYNAMIC VISIBILITY: Legal Notice, Signature, & Photo appear ONLY when confirmation box is CHECKED!
          if (_consentGiven) ...[
            const Text('LEGAL NOTICE', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              'By signing or taking a photo, you accept and agree to Company\'s Terms of Use and Privacy Policy. Specifically, you provide your clear consent to: (i) Company\'s collection, use, transfer, and/or processing of any of your personal information provided hereunder, for the purposes of this and/or future engagement(s) with the Professional Healthcare Specialist Representative of PMI; (ii) Company\'s recording of coverage, including its perpetual right to store, transmit and use such recordings for any internal or external purpose(s). You agree to be contacted, including via phone, email messages and text messages, by Company, its affiliates, contractors/sub-contractors in relation to the marketing of Company\'s products and/or services.',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 20),

            const Text('Affix signature and/or take a group photo', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Signature', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                      const SizedBox(height: 6),
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2C2C2E)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SignatureCanvas(pointsNotifier: _signaturePoints),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _signaturePoints.value = []),
                        child: const Text('Clear', style: TextStyle(color: Color(0xFFFF453A), fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Photo', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                      const SizedBox(height: 6),
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2C2C2E)),
                        ),
                        child: _consentPhotoFile != null
                            ? Image.network('file://${_consentPhotoFile!.path}', fit: BoxFit.cover)
                            : Center(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.camera_alt, color: Colors.white54),
                                  label: const Text('Take Photo', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  onPressed: _capturePhoto,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
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
          const Text('DOCTOR\'S INFORMATION', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          DropdownButtonFormField<Hcp>(
            value: _selectedDoctor,
            dropdownColor: const Color(0xFF1C1C1E),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'HCP *',
              labelStyle: const TextStyle(color: Color(0xFFFF453A), fontWeight: FontWeight.bold),
              filled: true,
              fillColor: const Color(0xFF1C1C1E),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFF453A)), borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFF453A), width: 2), borderRadius: BorderRadius.circular(8)),
            ),
            items: _allDoctors.map((d) => DropdownMenuItem(value: d, child: Text('Dr. ${d.firstName} ${d.lastName} (${d.name})'))).toList(),
            onChanged: (doc) {
              if (doc != null) {
                setState(() {
                  _selectedDoctor = doc;
                  _prepopulateDoctorData(doc);
                });
              }
            },
          ),
          const SizedBox(height: 4),
          const Text(
            'To begin, search for your doctor by typing the surname, the firstname, or both in the box provided.\nIf you could not find your doctor, create a new doctor profile instead.',
            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11),
          ),
          const SizedBox(height: 20),

          const Text('BASIC INFO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'First Name *',
                    labelStyle: const TextStyle(color: Color(0xFFFF453A)),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1E),
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFF453A)), borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _middleNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Middle Name *',
                    labelStyle: const TextStyle(color: Color(0xFFFF453A)),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1E),
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFF453A)), borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Last Name *',
                    labelStyle: const TextStyle(color: Color(0xFFFF453A)),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1E),
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFF453A)), borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _birthDateController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Birth Date',
              labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
              filled: true,
              fillColor: const Color(0xFF1C1C1E),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF2C2C2E)), borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 20),

          const Text('SPECIALIZATION / TYPE / PRACTICE', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedHcpType,
                  dropdownColor: const Color(0xFF1C1C1E),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Type *',
                    labelStyle: const TextStyle(color: Color(0xFFFF453A)),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1E),
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFF453A)), borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _hcpTypes.map((t) => DropdownMenuItem(value: t.name, child: Text(t.typeName))).toList(),
                  onChanged: (val) => setState(() => _selectedHcpType = val),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedPractice,
                  dropdownColor: const Color(0xFF1C1C1E),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Practice *',
                    labelStyle: const TextStyle(color: Color(0xFFFF453A)),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1E),
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFF453A)), borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Dispensing', child: Text('Dispensing')),
                    DropdownMenuItem(value: 'Prescribing', child: Text('Prescribing')),
                    DropdownMenuItem(value: 'Both', child: Text('Both')),
                  ],
                  onChanged: (val) => setState(() => _selectedPractice = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Specialties Table
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Specialty Table', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2E)),
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: const Text('Add Row', style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: _showAddSpecialtySelector,
              ),
            ],
          ),
          ..._selectedSpecialties.map((s) => Card(
            color: const Color(0xFF1C1C1E),
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              title: Text(s.specialtyName ?? s.hcpSpecialty ?? 'Specialty', style: const TextStyle(color: Colors.white)),
              subtitle: s.subSpecialtyName != null ? Text(s.subSpecialtyName!, style: const TextStyle(color: Colors.white70, fontSize: 12)) : null,
            ),
          )),
          const SizedBox(height: 20),

          const Text('WORKPLACES / CONTACT INFO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Workplace Table', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2E)),
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: const Text('Add Row', style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: _showAddWorkplaceSelector,
              ),
            ],
          ),
          ..._selectedWorkplaces.map((w) => Card(
            color: const Color(0xFF1C1C1E),
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              title: Text(w.workplaceName ?? w.hcpWorkplace ?? 'Workplace', style: const TextStyle(color: Colors.white)),
            ),
          )),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Contact Info Table', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C2C2E)),
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: const Text('Add Row', style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: _showAddContactSelector,
              ),
            ],
          ),
          ..._contacts.map((c) => Card(
            color: const Color(0xFF1C1C1E),
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              title: Text(c.contactNumber ?? 'No Phone', style: const TextStyle(color: Colors.white)),
              subtitle: Text(c.emailAddress ?? 'No Email', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          )),
        ],
      ),
    );
  }

  // --- STEP 3: SURVEY QUESTIONNAIRE ---
  Widget _buildStep3Survey() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SURVEY QUESTIONNAIRE', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: apiService.selectedProgram,
            dropdownColor: const Color(0xFF1C1C1E),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Account/Program',
              labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
              filled: true,
              fillColor: const Color(0xFF1C1C1E),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF2C2C2E)), borderRadius: BorderRadius.circular(8)),
            ),
            items: apiService.availablePrograms.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (val) {
              if (val != null) apiService.setProgram(val);
            },
          ),
          const SizedBox(height: 20),
          if (_activeSurvey == null)
            const Text('No active profiling survey template found.', style: TextStyle(color: Colors.white54))
          else
            ..._activeSurvey!.questions.map((q) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.question, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF2C2C2E)), borderRadius: BorderRadius.circular(8)),
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
    final dateStr = '${_submissionDate.year}-${_submissionDate.month.toString().padLeft(2, '0')}-${_submissionDate.day.toString().padLeft(2, '0')} ${_submissionDate.hour.toString().padLeft(2, '0')}:${_submissionDate.minute.toString().padLeft(2, '0')}:${_submissionDate.second.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            initialValue: _territoryCode,
            readOnly: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Territory Code',
              labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
              filled: true,
              fillColor: const Color(0xFF1C1C1E),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF2C2C2E)), borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: apiService.loggedInEmail ?? 'jptan@profinsights.biz',
            readOnly: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Medrep Email Address',
              labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
              filled: true,
              fillColor: const Color(0xFF1C1C1E),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF2C2C2E)), borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),

          InkWell(
            onTap: _showDateTimePicker,
            child: IgnorePointer(
              child: TextFormField(
                key: ValueKey(dateStr),
                initialValue: dateStr,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Submission Date (Calendar & Time Sliders)',
                  labelStyle: const TextStyle(color: Color(0xFF0066FF), fontWeight: FontWeight.bold),
                  suffixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF0066FF)),
                  filled: true,
                  fillColor: const Color(0xFF1C1C1E),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF0066FF)), borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _applicationStatus,
            dropdownColor: const Color(0xFF1C1C1E),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Application Status',
              labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
              filled: true,
              fillColor: const Color(0xFF1C1C1E),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF2C2C2E)), borderRadius: BorderRadius.circular(8)),
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

  // --- CHANGES STEP ---
  Widget _buildChangesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Summary of Changes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            value: _applicationStatus,
            dropdownColor: const Color(0xFF1C1C1E),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Application Status',
              labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
              filled: true,
              fillColor: const Color(0xFF1C1C1E),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF2C2C2E)), borderRadius: BorderRadius.circular(8)),
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
          const SizedBox(height: 20),

          const Text('Contact Information', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759), size: 18),
              const SizedBox(width: 6),
              Text('Added (${_contacts.length} Contacts)', style: const TextStyle(color: Color(0xFF34C759), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),

          const Text('Specialties & Workplaces', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF0066FF), size: 18),
              const SizedBox(width: 6),
              Text('Linked ${_selectedSpecialties.length} Specialties, ${_selectedWorkplaces.length} Workplaces', style: const TextStyle(color: Color(0xFF0066FF), fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final titles = _getTabTitles();
    final isLast = _currentStep == titles.length - 1;
    return Container(
      color: const Color(0xFF1C1C1E),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () => setState(() => _currentStep--),
              child: const Text('Previous', style: TextStyle(color: Color(0xFF8E8E93))),
            )
          else
            const SizedBox(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066FF),
              disabledBackgroundColor: const Color(0xFF0066FF).withOpacity(0.4),
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
      ..color = Colors.white
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
