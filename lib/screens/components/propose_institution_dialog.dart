import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/lookup_models.dart';
import '../../services/api_service.dart';

/// Automatically capitalizes the initial letter of each word as the user types
class TitleCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final StringBuffer sb = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < newValue.text.length; i++) {
      final String char = newValue.text[i];
      if (RegExp(r'[\s\-_/.,&()]').hasMatch(char)) {
        capitalizeNext = true;
        sb.write(char);
      } else if (capitalizeNext) {
        sb.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        sb.write(char);
      }
    }

    final String capitalized = sb.toString();
    return newValue.copyWith(
      text: capitalized,
      selection: newValue.selection,
    );
  }
}

/// Interactive dialog for proposing a new Institution following the 3-tier
/// classification-first flow:
/// 1. Ownership (Government, Private)
/// 2. Institution Type (Hospital, Clinic)
/// 3. Service Capability (Hospital: 3 options, Clinic: 5 options)
/// 4. Workplace Name (Locked from submitting if duplicate matches exist in auto-fill dropdown)
/// 5. Location Details (Region, Province, City)
class ProposeInstitutionDialog extends StatefulWidget {
  final bool requiresDsmApproval;
  final String? linkedDoctorName;

  const ProposeInstitutionDialog({
    Key? key,
    this.requiresDsmApproval = false,
    this.linkedDoctorName,
  }) : super(key: key);

  static Future<Institution?> show(
    BuildContext context, {
    bool requiresDsmApproval = false,
    String? linkedDoctorName,
  }) {
    return showDialog<Institution>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProposeInstitutionDialog(
        requiresDsmApproval: requiresDsmApproval,
        linkedDoctorName: linkedDoctorName,
      ),
    );
  }

  @override
  State<ProposeInstitutionDialog> createState() => _ProposeInstitutionDialogState();
}

class _ProposeInstitutionDialogState extends State<ProposeInstitutionDialog> {
  final TextEditingController _workplaceCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  Timer? _debounceTimer;

  // Tier 1 & 2: Classification State
  String? _selectedOwnership = 'Private';
  String? _selectedType = 'Hospital';
  late String? _selectedCapability;

  // Location State
  String? _selectedRegion;
  String? _selectedProvince;
  String? _selectedCity;

  // Smart suggestions & auto-fill detection (Non-blocking)
  List<InstitutionSearchResult> _detectedMatches = [];
  bool _showDropdown = false;
  Institution? _selectedExistingInstitution;
  bool _isSaving = false;
  String? _validationErr;

  @override
  void initState() {
    super.initState();
    _selectedCapability = InstitutionClassification.hospitalCapabilities.first;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _workplaceCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  bool get _isClassificationFulfilled =>
      _selectedOwnership != null &&
      _selectedType != null &&
      _selectedCapability != null &&
      _selectedCapability!.isNotEmpty;

  bool get _hasSimilarSuggestions => _detectedMatches.isNotEmpty;

  bool get _isWorkplaceNameValid => _workplaceCtrl.text.trim().length >= 3;

  /// Location fields are unlocked as soon as classification is selected and
  /// workplace name is fulfilled (>= 3 chars), allowing the MedRep to freely
  /// enter Region, Province, and City without being locked up.
  bool get _isLocationUnlocked =>
      _isClassificationFulfilled &&
      _isWorkplaceNameValid &&
      _selectedExistingInstitution == null;

  /// Can submit whenever classification, workplace name, and mandatory location
  /// (Province & City) are provided, or when an existing facility is selected.
  /// Suggestions do NOT lock up the MedRep from submitting.
  bool get _canSubmit {
    if (_isSaving) return false;
    if (_selectedExistingInstitution != null) return true; // Can immediately use existing facility!
    if (!_isClassificationFulfilled) return false;
    if (!_isWorkplaceNameValid) return false;
    if (_selectedProvince == null || _selectedProvince!.trim().isEmpty) return false;
    if (_selectedCity == null || _selectedCity!.trim().isEmpty) return false;
    return true;
  }

  void _onTypeChanged(String? newType) {
    if (newType == null) return;
    setState(() {
      _selectedType = newType;
      final caps = InstitutionClassification.getCapabilitiesForType(newType);
      _selectedCapability = caps.isNotEmpty ? caps.first : null;
    });
  }

  void _onWorkplaceChanged(String val, List<Institution> directory) {
    _debounceTimer?.cancel();

    final text = val.trim();
    if (_selectedExistingInstitution != null) {
      setState(() {
        _selectedExistingInstitution = null;
      });
    }

    if (text.length < 2) {
      setState(() {
        _detectedMatches = [];
        _showDropdown = false;
        _validationErr = null;
      });
      return;
    }

    // Debounce to eliminate keystroke lag while typing
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final matches = LocationResolver.searchDirectoryWithDuplicateDetection(
        text,
        directory,
        limit: 6,
      );
      setState(() {
        _detectedMatches = matches;
        _showDropdown = matches.isNotEmpty;
        _validationErr = null;
      });
    });
  }

  void _selectFromDirectory(Institution inst, InstitutionSearchResult item) {
    setState(() {
      _selectedExistingInstitution = inst;
      _workplaceCtrl.text = inst.institutionName.isNotEmpty ? inst.institutionName : inst.name;
      if (inst.regionName != null && inst.regionName!.isNotEmpty) _selectedRegion = inst.regionName;
      if (inst.provinceName != null && inst.provinceName!.isNotEmpty) _selectedProvince = inst.provinceName;
      if (inst.cityMunicipality != null && inst.cityMunicipality!.isNotEmpty) _selectedCity = inst.cityMunicipality;
      if (inst.streetAddress != null && inst.streetAddress!.isNotEmpty) _addressCtrl.text = inst.streetAddress!;
      if (inst.ownership != null && inst.ownership!.isNotEmpty) _selectedOwnership = inst.ownership;
      if (inst.institutionType != null && inst.institutionType!.isNotEmpty) {
        _selectedType = inst.institutionType;
        final caps = InstitutionClassification.getCapabilitiesForType(inst.institutionType!);
        if (inst.serviceCapability != null && caps.contains(inst.serviceCapability)) {
          _selectedCapability = inst.serviceCapability;
        } else if (caps.isNotEmpty) {
          _selectedCapability = caps.first;
        }
      }
      _showDropdown = false;
      _detectedMatches = [];
      _validationErr = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected "${inst.institutionName}" from directory. Tap below to use.'),
        backgroundColor: const Color(0xFF0066FF),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedExistingInstitution != null) {
      Navigator.pop(context, _selectedExistingInstitution);
      return;
    }

    final wp = _workplaceCtrl.text.trim();
    final prov = _selectedProvince?.trim() ?? '';
    final city = _selectedCity?.trim() ?? '';
    final reg = _selectedRegion?.trim() ?? '';
    final street = _addressCtrl.text.trim();

    if (!_isClassificationFulfilled) {
      setState(() => _validationErr = 'Please select Ownership, Institution Type, and Service Capability');
      return;
    }
    if (wp.isEmpty) {
      setState(() => _validationErr = 'Workplace name is required');
      return;
    }
    if (prov.isEmpty) {
      setState(() => _validationErr = 'Province is required');
      return;
    }
    if (city.isEmpty) {
      setState(() => _validationErr = 'City is required');
      return;
    }

    final api = Provider.of<ApiService>(context, listen: false);
    final allDirectory = api.cachedInstitutions;

    // Check if an exact identical approved institution already exists in the same city
    final exactApprovedMatch = allDirectory.firstWhere(
      (i) => (i.institutionName.trim().toLowerCase() == wp.toLowerCase() ||
              i.name.trim().toLowerCase() == wp.toLowerCase()) &&
             i.isApproved &&
             (i.cityMunicipality ?? '').trim().toLowerCase() == city.toLowerCase(),
      orElse: () => Institution(name: '', institutionName: ''),
    );
    if (exactApprovedMatch.name.isNotEmpty && _selectedExistingInstitution == null) {
      setState(() => _validationErr = 'An approved facility named "$wp" in $city already exists in the masterlist. Tap it from the suggestions above to select it, or distinguish the name (e.g. branch or building).');
      return;
    }

    setState(() {
      _isSaving = true;
      _validationErr = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.createInstitutionRequest(
        workplaceName: wp,
        region: reg.isNotEmpty ? reg : null,
        city: city,
        province: prov,
        ownership: _selectedOwnership,
        institutionType: _selectedType,
        serviceCapability: _selectedCapability,
        requiresDsmApproval: widget.requiresDsmApproval,
        linkedDoctorName: widget.linkedDoctorName,
        streetAddress: street.isNotEmpty ? street : null,
      );
      if (mounted) {
        Navigator.pop(context, res);
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _validationErr = 'Failed to submit: $err';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final allDirectory = apiService.cachedInstitutions;
    final capabilities = InstitutionClassification.getCapabilitiesForType(_selectedType ?? 'Hospital');

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF0B192C),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_business_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Propose New Institution',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.5),
                          ),
                          if (widget.linkedDoctorName != null && widget.linkedDoctorName!.isNotEmpty)
                            Text(
                              'Linked to Dr. ${widget.linkedDoctorName!} (Requires DSM Approval)',
                              style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w500),
                            )
                          else
                            const Text(
                              'Step 1: Classification  •  Step 2: Facility Name  •  Step 3: Location',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Info note banner
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.requiresDsmApproval
                            ? 'This institution will undergo SFE Specialist review first, followed by DSM approval upon doctor profile submission.'
                            : 'All submitted institutions are reviewed by the SFE Specialist. You can use this facility immediately while awaiting approval.',
                        style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 11.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Form Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_validationErr != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_validationErr!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // --------------------------------------------------------
                    // TIER 1 & 2: CLASSIFICATION (Ownership, Type, Capability)
                    // --------------------------------------------------------
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.category_outlined, size: 15, color: Color(0xFF0066FF)),
                              SizedBox(width: 6),
                              Text(
                                'Step 1: Classification (Ownership & Type) *',
                                style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              // Ownership Dropdown (Government, Private)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Ownership *', style: TextStyle(color: Color(0xFF475569), fontSize: 11.5, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    DropdownButtonFormField<String>(
                                      value: _selectedOwnership,
                                      isDense: true,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      ),
                                      items: InstitutionClassification.ownershipOptions.map((opt) {
                                        return DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 12.5)));
                                      }).toList(),
                                      onChanged: (val) => setState(() => _selectedOwnership = val),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Institution Type Dropdown (Hospital, Clinic)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Institution Type *', style: TextStyle(color: Color(0xFF475569), fontSize: 11.5, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    DropdownButtonFormField<String>(
                                      value: _selectedType,
                                      isDense: true,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      ),
                                      items: InstitutionClassification.institutionTypeOptions.map((opt) {
                                        return DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 12.5)));
                                      }).toList(),
                                      onChanged: _onTypeChanged,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Service Capability Dropdown (Hospital: 3, Clinic: 5)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedType == 'Hospital'
                                    ? 'Service Capability (Hospital - 3 Levels) *'
                                    : 'Service Capability (Clinic - 5 Types) *',
                                style: const TextStyle(color: Color(0xFF475569), fontSize: 11.5, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: capabilities.contains(_selectedCapability) ? _selectedCapability : (capabilities.isNotEmpty ? capabilities.first : null),
                                isDense: true,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                ),
                                items: capabilities.map((opt) {
                                  return DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 12.5)));
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedCapability = val),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // --------------------------------------------------------
                    // STEP 2: WORKPLACE / INSTITUTION NAME
                    // --------------------------------------------------------
                    Row(
                      children: [
                        const Icon(Icons.local_hospital_outlined, size: 15, color: Color(0xFF0066FF)),
                        const SizedBox(width: 6),
                        const Text(
                          'Step 2: Workplace / Institution Name *',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        if (!_isClassificationFulfilled)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Text('(Select classification above first)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    TextFormField(
                      controller: _workplaceCtrl,
                      enabled: _isClassificationFulfilled,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        TitleCaseTextInputFormatter(),
                      ],
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                      onChanged: (val) => _onWorkplaceChanged(val, allDirectory),
                      decoration: InputDecoration(
                        hintText: _isClassificationFulfilled
                            ? 'e.g. St. Luke\'s Medical Center - BGC'
                            : 'Select Ownership & Type first...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0B192C), size: 18),
                        suffixIcon: _workplaceCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _workplaceCtrl.clear();
                                  setState(() {
                                    _detectedMatches = [];
                                    _showDropdown = false;
                                    _selectedRegion = null;
                                    _selectedProvince = null;
                                    _selectedCity = null;
                                    _addressCtrl.clear();
                                    _selectedExistingInstitution = null;
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: _isClassificationFulfilled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                        ),
                      ),
                    ),

                    // SMART SIMILARITY SUGGESTION BANNER (Informative & Non-blocking)
                    if (_detectedMatches.isNotEmpty && _selectedExistingInstitution == null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF16A34A), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Similar Facilities in Masterlist (Smart Suggestion)',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534), fontSize: 11.5),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Found ${_detectedMatches.length} existing facilit${_detectedMatches.length > 1 ? 'ies' : 'y'} with similar wording. You may tap a facility from the dropdown below to use it directly, or continue filling in the location details below to propose this new institution.',
                                    style: const TextStyle(color: Color(0xFF15803D), fontSize: 11, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // SELECTED EXISTING FACILITY BANNER
                    if (_selectedExistingInstitution != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF93C5FD)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Existing Facility Selected: "${_selectedExistingInstitution!.institutionName}"',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Status: ${_selectedExistingInstitution!.status} • Location: ${_selectedProvince ?? ''}, ${_selectedCity ?? ''}',
                                    style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'This facility is already registered in the masterlist. Tap "Use Selected Institution" below to link this doctor without submitting duplicates.',
                                    style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 11, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // AUTO-FILL DIRECTORY DROPDOWN LIST
                    if (_showDropdown && _detectedMatches.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF93C5FD)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 3)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.travel_explore_rounded, color: Color(0xFF2563EB), size: 14),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Directory Facilities (Tap to Select):',
                                    style: TextStyle(color: Color(0xFF1E40AF), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  InkWell(
                                    onTap: () => setState(() => _showDropdown = false),
                                    child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _detectedMatches.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                itemBuilder: (ctx, idx) {
                                  final item = _detectedMatches[idx];
                                  final inst = item.institution;
                                  final isApproved = inst.isApproved;

                                  return InkWell(
                                    onTap: () => _selectFromDirectory(inst, item),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.local_hospital_rounded, size: 16, color: Color(0xFF0066FF)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  inst.institutionName,
                                                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (item.formattedLocation.isNotEmpty)
                                                  Text(
                                                    item.formattedLocation,
                                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isApproved ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: isApproved ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                                            ),
                                            child: Text(
                                              isApproved ? 'Approved' : 'Pending',
                                              style: TextStyle(
                                                color: isApproved ? const Color(0xFF059669) : const Color(0xFFD97706),
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_workplaceCtrl.text.trim().length >= 3 && _selectedExistingInstitution == null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '✓ Facility name entered. Location fields below are unlocked and editable.',
                                style: TextStyle(color: Color(0xFF166534), fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // --------------------------------------------------------
                    // STEP 3: LOCATION DETAILS
                    // --------------------------------------------------------
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 15,
                          color: _isLocationUnlocked ? const Color(0xFF0B192C) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Step 3: Location Details *',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        if (_selectedExistingInstitution != null) ...[
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              '(Selected facility location)',
                              style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Region Selector
                    InkWell(
                      onTap: !_isLocationUnlocked
                          ? null
                          : () async {
                              final picked = await _showRegionPicker(context, _selectedRegion);
                              if (picked != null) {
                                setState(() {
                                  _selectedRegion = picked;
                                  if (_selectedProvince != null) {
                                    final allowed = LocationResolver.getProvincesForRegion(picked);
                                    if (!allowed.contains(_selectedProvince)) {
                                      _selectedProvince = null;
                                      _selectedCity = null;
                                    }
                                  }
                                });
                              }
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: !_isLocationUnlocked ? const Color(0xFFF8FAFC) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.public_outlined,
                              color: !_isLocationUnlocked ? const Color(0xFF94A3B8) : const Color(0xFF0B192C),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (_selectedRegion != null && _selectedRegion!.isNotEmpty)
                                    ? _selectedRegion!
                                    : 'Select Region (or select Province below)',
                                style: TextStyle(
                                  color: (_selectedRegion != null && _selectedRegion!.isNotEmpty)
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF94A3B8),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: !_isLocationUnlocked ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Province Selector
                    InkWell(
                      onTap: !_isLocationUnlocked
                          ? null
                          : () async {
                              final picked = await _showProvincePicker(context, _selectedProvince, regionFilter: _selectedRegion);
                              if (picked != null) {
                                setState(() {
                                  _selectedProvince = picked;
                                  _selectedCity = null;
                                  final autoReg = LocationResolver.resolveRegionFromProvince(picked);
                                  if (autoReg.isNotEmpty) _selectedRegion = autoReg;
                                });
                              }
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: !_isLocationUnlocked ? const Color(0xFFF8FAFC) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.map_outlined,
                              color: !_isLocationUnlocked ? const Color(0xFF94A3B8) : const Color(0xFF0B192C),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (_selectedProvince != null && _selectedProvince!.isNotEmpty)
                                    ? _selectedProvince!
                                    : 'Select Province *',
                                style: TextStyle(
                                  color: (_selectedProvince != null && _selectedProvince!.isNotEmpty)
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF94A3B8),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: !_isLocationUnlocked ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // City Selector
                    InkWell(
                      onTap: !_isLocationUnlocked
                          ? null
                          : () async {
                              final picked = await _showCityPicker(context, _selectedCity, provinceFilter: _selectedProvince);
                              if (picked != null) {
                                setState(() {
                                  _selectedCity = picked;
                                  if (_selectedProvince == null || _selectedProvince!.isEmpty) {
                                    final autoProv = LocationResolver.resolveProvinceFromCity(picked);
                                    if (autoProv != null) {
                                      _selectedProvince = autoProv;
                                      final autoReg = LocationResolver.resolveRegionFromProvince(autoProv);
                                      if (autoReg.isNotEmpty) _selectedRegion = autoReg;
                                    }
                                  }
                                });
                              }
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: !_isLocationUnlocked ? const Color(0xFFF8FAFC) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_city_outlined,
                              color: !_isLocationUnlocked ? const Color(0xFF94A3B8) : const Color(0xFF0B192C),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (_selectedCity != null && _selectedCity!.isNotEmpty)
                                    ? _selectedCity!
                                    : 'Select City / Municipality *',
                                style: TextStyle(
                                  color: (_selectedCity != null && _selectedCity!.isNotEmpty)
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF94A3B8),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: !_isLocationUnlocked ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Street Address (Optional)
                    TextFormField(
                      controller: _addressCtrl,
                      enabled: _isLocationUnlocked,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Street Address / Building (Optional)',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                        prefixIcon: Icon(
                          Icons.home_work_outlined,
                          color: _isLocationUnlocked ? const Color(0xFF0B192C) : const Color(0xFF94A3B8),
                          size: 18,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: !_isLocationUnlocked ? const Color(0xFFF8FAFC) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canSubmit
                            ? (_selectedExistingInstitution != null ? const Color(0xFF1E3E62) : const Color(0xFF0B192C))
                            : const Color(0xFF94A3B8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: _canSubmit ? _submit : null,
                      child: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              _selectedExistingInstitution != null ? 'Use Selected Institution' : 'Submit for Approval',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
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

  Future<String?> _showRegionPicker(BuildContext context, String? current) async {
    final searchCtrl = TextEditingController();
    final allRegions = LocationResolver.getRegions();
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) {
          final q = searchCtrl.text.toLowerCase().trim();
          final filtered = q.isEmpty ? allRegions : allRegions.where((r) => r.toLowerCase().contains(q)).toList();
          return AlertDialog(
            title: const Text('Select Region', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: double.maxFinite,
              height: 380,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search region...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final reg = filtered[i];
                        return ListTile(
                          dense: true,
                          title: Text(reg),
                          trailing: reg == current ? const Icon(Icons.check, color: Color(0xFF0066FF)) : null,
                          onTap: () => Navigator.pop(dialogCtx, reg),
                        );
                      },
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

  Future<String?> _showProvincePicker(BuildContext context, String? current, {String? regionFilter}) async {
    final searchCtrl = TextEditingController();
    final allProvinces = LocationResolver.getProvincesForRegion(regionFilter);
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) {
          final q = searchCtrl.text.toLowerCase().trim();
          final filtered = q.isEmpty ? allProvinces : allProvinces.where((p) => p.toLowerCase().contains(q)).toList();
          return AlertDialog(
            title: Text(
              regionFilter != null && regionFilter.isNotEmpty ? 'Select Province ($regionFilter)' : 'Select Province',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 380,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search province...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final prov = filtered[i];
                        return ListTile(
                          dense: true,
                          title: Text(prov),
                          trailing: prov == current ? const Icon(Icons.check, color: Color(0xFF0066FF)) : null,
                          onTap: () => Navigator.pop(dialogCtx, prov),
                        );
                      },
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

  Future<String?> _showCityPicker(BuildContext context, String? current, {String? provinceFilter}) async {
    final searchCtrl = TextEditingController();
    final cities = LocationResolver.getCitiesForProvince(provinceFilter);
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) {
          final q = searchCtrl.text.toLowerCase().trim();
          final filtered = q.isEmpty ? cities : cities.where((c) => c.toLowerCase().contains(q)).toList();
          return AlertDialog(
            title: Text(
              provinceFilter != null && provinceFilter.isNotEmpty ? 'Select City ($provinceFilter)' : 'Select City / Municipality',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 380,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search city or municipality...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('No matching PSGC city found in this province', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                                const SizedBox(height: 12),
                                if (searchCtrl.text.trim().isNotEmpty)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
                                    onPressed: () => Navigator.pop(dialogCtx, searchCtrl.text.trim()),
                                    child: Text('Use "${searchCtrl.text.trim()}"', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final city = filtered[i];
                              return ListTile(
                                dense: true,
                                title: Text(city),
                                trailing: city == current ? const Icon(Icons.check, color: Color(0xFF0066FF)) : null,
                                onTap: () => Navigator.pop(dialogCtx, city),
                              );
                            },
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
}
