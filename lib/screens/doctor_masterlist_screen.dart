import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/hcp.dart';
import '../models/lookup_models.dart';
import '../models/hcp_account.dart';
import '../services/api_service.dart';
import 'components/app_drawer.dart';
import 'doctor_profile_screen.dart';
import 'hcp_wizard_screen.dart';
import 'self_service_qr_screen.dart';
import 'submission_history_screen.dart';
import 'login_screen.dart';

class DoctorMasterlistScreen extends StatefulWidget {
  const DoctorMasterlistScreen({Key? key}) : super(key: key);

  @override
  State<DoctorMasterlistScreen> createState() => _DoctorMasterlistScreenState();
}

class _DoctorMasterlistScreenState extends State<DoctorMasterlistScreen> {
  List<Hcp> _allDoctors = [];
  List<Hcp> _filteredDoctors = [];
  List<Institution> _institutions = [];
  List<Specialization> _specializations = [];
  List<PsgcLocation> _psgcLocations = [];
  List<HcpType> _hcpTypes = [];

  bool _isLoading = true;

  // ERPNext Matching Filters (Darkish Blue Theme)
  bool _showFilters = true;
  String _idQuery = '';
  String _nameQuery = '';
  String? _selectedTypeFilter;
  String? _selectedPracticeFilter;
  bool _onlyIsActive = false;
  String _sortBy = 'Name of Doctor';
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final doctors = await apiService.fetchDoctors();
      final institutions = await apiService.fetchInstitutions();
      final specializations = await apiService.fetchSpecializations();
      final psgc = await apiService.fetchPsgcLocations();
      final types = await apiService.fetchHcpTypes();

      setState(() {
        _allDoctors = doctors;
        _institutions = institutions;
        _specializations = specializations.where((s) => !s.isGroup).toList();
        _psgcLocations = psgc;
        _hcpTypes = types;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading doctor list: $e')),
      );
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredDoctors = _allDoctors.where((doctor) {
        final nameStr = '${doctor.firstName} ${doctor.middleName ?? ''} ${doctor.lastName}'.toLowerCase();
        final idStr = (doctor.name ?? '').toLowerCase();

        final matchesId = _idQuery.isEmpty || idStr.contains(_idQuery.toLowerCase().trim());
        final matchesName = _nameQuery.isEmpty || nameStr.contains(_nameQuery.toLowerCase().trim());
        final matchesType = _selectedTypeFilter == null || _selectedTypeFilter == 'All' || doctor.hcpType == _selectedTypeFilter;
        final matchesPractice = _selectedPracticeFilter == null || _selectedPracticeFilter == 'All' || doctor.hcpPractice == _selectedPracticeFilter;
        final matchesIsActive = !_onlyIsActive || doctor.isActive;

        return matchesId && matchesName && matchesType && matchesPractice && matchesIsActive;
      }).toList();

      _filteredDoctors.sort((a, b) {
        int cmp = 0;
        switch (_sortBy) {
          case 'ID':
            cmp = (a.name ?? '').compareTo(b.name ?? '');
            break;
          case 'Type':
            cmp = a.hcpType.compareTo(b.hcpType);
            break;
          case 'Practice':
            cmp = a.hcpPractice.compareTo(b.hcpPractice);
            break;
          case 'Name of Doctor':
          default:
            final aName = '${a.firstName} ${a.lastName}';
            final bName = '${b.firstName} ${b.lastName}';
            cmp = aName.compareTo(bName);
            break;
        }
        return _isAscending ? cmp : -cmp;
      });
    });
  }

  // --- DOCTOR'S INFORMATION SHEET (Darkish Blue & White Modal) ---
  Future<void> _openDoctorProfile(Hcp doctor) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    Hcp fullDoctor = doctor;
    if (doctor.name != null) {
      try {
        fullDoctor = await apiService.fetchDoctorDetail(doctor.name!);
      } catch (e) {
        print('Error fetching doctor detail for masterlist view: $e');
      }
    }

    final doctorFullName = '${fullDoctor.firstName} ${fullDoctor.middleName != null && fullDoctor.middleName != '-' && fullDoctor.middleName!.isNotEmpty ? fullDoctor.middleName! + ' ' : ''}${fullDoctor.lastName}'.trim();
    final photoUrlCtrl = TextEditingController(text: fullDoctor.hcpPhoto ?? 'https://pngimg.com/uploads/doctor/doctor_PNG16003.png');
    bool isActive = fullDoctor.isActive;

    final specLookup = {for (var s in _specializations) s.name: s.specialty};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.92,
            decoration: const BoxDecoration(
              color: Color(0xFF0B192C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Header (Darkish Blue & White Theme)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "DOCTOR'S INFORMATION SHEET",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Name of Doctor Field & Is Active Checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Name of Doctor', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: Text(
                                      doctorFullName.isNotEmpty ? doctorFullName : (fullDoctor.name ?? 'Edward Soriano'),
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Row(
                              children: [
                                Checkbox(
                                  value: isActive,
                                  activeColor: const Color(0xFF0066FF),
                                  side: const BorderSide(color: Colors.white70),
                                  onChanged: (val) {
                                    if (val != null) setModalState(() => isActive = val);
                                  },
                                ),
                                const Text('Is Active', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Doctor Photo Container
                        Container(
                          width: 180,
                          height: 200,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              photoUrlCtrl.text.isNotEmpty
                                  ? photoUrlCtrl.text
                                  : 'https://pngimg.com/uploads/doctor/doctor_PNG16003.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.person, size: 70, color: Colors.white38),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SizedBox(
                              width: 220,
                              child: TextField(
                                controller: photoUrlCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  labelText: 'Photo',
                                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                  filled: true,
                                  fillColor: const Color(0xFF1E293B),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF334155))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                side: const BorderSide(color: Color(0xFF334155)),
                              ),
                              onPressed: () {
                                photoUrlCtrl.clear();
                                setModalState(() {});
                              },
                              child: const Text('Clear', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFF334155)),
                        const SizedBox(height: 12),

                        // PERSONAL Section
                        const Text('PERSONAL', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(width: 170, child: _buildReadonlyField('First Name *', fullDoctor.firstName, isMandatory: true)),
                            SizedBox(width: 170, child: _buildReadonlyField('Middle Name *', fullDoctor.middleName ?? '', isMandatory: true)),
                            SizedBox(width: 170, child: _buildReadonlyField('Last Name *', fullDoctor.lastName, isMandatory: true)),
                            SizedBox(width: 170, child: _buildReadonlyField('Birth Date', fullDoctor.birthDate ?? '')),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFF334155)),
                        const SizedBox(height: 12),

                        // SPECIALIZATION / TYPE / PRACTICE Section
                        const Text('SPECIALIZATION / TYPE / PRACTICE', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Specialty & Sub Specialty Table
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          color: const Color(0xFF0F172A),
                                          child: Row(
                                            children: const [
                                              Icon(Icons.check_box_outline_blank, color: Colors.white54, size: 16),
                                              SizedBox(width: 10),
                                              Expanded(child: Text('Specialty', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold))),
                                              Expanded(child: Text('Sub Specialty', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold))),
                                              Icon(Icons.settings, color: Colors.white54, size: 14),
                                            ],
                                          ),
                                        ),
                                        if (fullDoctor.specialties.isNotEmpty)
                                          ...fullDoctor.specialties.map((s) {
                                            final rawSpec = s.hcpSpecialty;
                                            final specName = specLookup[rawSpec] ?? rawSpec;
                                            final rawSub = s.subSpecialty ?? '';
                                            final subName = specLookup[rawSub] ?? rawSub;
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.check_box_outline_blank, color: Colors.white54, size: 16),
                                                  const SizedBox(width: 10),
                                                  Expanded(child: Text(specName, style: const TextStyle(color: Colors.white, fontSize: 12))),
                                                  Expanded(child: Text(subName.isNotEmpty ? subName : 'General Practice', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                                  const Icon(Icons.edit_outlined, color: Colors.white54, size: 14),
                                                ],
                                              ),
                                            );
                                          })
                                        else
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            child: Row(
                                              children: const [
                                                Icon(Icons.check_box_outline_blank, color: Colors.white54, size: 16),
                                                SizedBox(width: 10),
                                                Expanded(child: Text('Family Medicine', style: TextStyle(color: Colors.white, fontSize: 12))),
                                                Expanded(child: Text('General Practice', style: TextStyle(color: Colors.white70, fontSize: 12))),
                                                Icon(Icons.edit_outlined, color: Colors.white54, size: 14),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                                    onPressed: () {},
                                    child: const Text('Add Row', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Type * & Practice * Dropdowns
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildReadonlyField('Type *', fullDoctor.hcpType.isNotEmpty ? fullDoctor.hcpType : 'Resident', isMandatory: true),
                                  const SizedBox(height: 12),
                                  _buildReadonlyField('Practice *', fullDoctor.hcpPractice.isNotEmpty ? fullDoctor.hcpPractice : 'Prescribing', isMandatory: true),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFF334155)),
                        const SizedBox(height: 12),

                        // WORKPLACES / CONTACT INFO Section
                        const Text('WORKPLACES / CONTACT INFO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Workplaces Table
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          color: const Color(0xFF0F172A),
                                          child: Row(
                                            children: const [
                                              Icon(Icons.check_box_outline_blank, color: Colors.white54, size: 16),
                                              SizedBox(width: 6),
                                              Expanded(child: Text('Workplace', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                              Text('City', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                                              SizedBox(width: 8),
                                              Text('Province', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                                              SizedBox(width: 6),
                                              Icon(Icons.settings, color: Colors.white54, size: 14),
                                            ],
                                          ),
                                        ),
                                        if (fullDoctor.workplaces.isNotEmpty)
                                          ...fullDoctor.workplaces.map((w) => Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.check_box_outline_blank, color: Colors.white54, size: 16),
                                                    const SizedBox(width: 6),
                                                    Expanded(child: Text(w.workplace, style: const TextStyle(color: Colors.white, fontSize: 11))),
                                                    Text(w.address ?? '', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                                    const SizedBox(width: 8),
                                                    const Text('Cavite', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                                    const SizedBox(width: 6),
                                                    const Icon(Icons.edit_outlined, color: Colors.white54, size: 14),
                                                  ],
                                                ),
                                              ))
                                        else
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            child: Row(
                                              children: const [
                                                Icon(Icons.check_box_outline_blank, color: Colors.white54, size: 16),
                                                SizedBox(width: 6),
                                                Expanded(child: Text('Metro Cavite Health ...', style: TextStyle(color: Colors.white, fontSize: 11))),
                                                Text('', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                                SizedBox(width: 8),
                                                Text('Cavite', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                                SizedBox(width: 6),
                                                Icon(Icons.edit_outlined, color: Colors.white54, size: 14),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                                    onPressed: () {},
                                    child: const Text('Add Row', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Contact Info Table
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          color: const Color(0xFF0F172A),
                                          child: Row(
                                            children: const [
                                              Icon(Icons.check_box_outline_blank, color: Colors.white54, size: 16),
                                              SizedBox(width: 6),
                                              Expanded(child: Text('Mobile/Phone Number', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                              Expanded(child: Text('Email Address', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                              Icon(Icons.settings, color: Colors.white54, size: 14),
                                            ],
                                          ),
                                        ),
                                        if (fullDoctor.contacts.isNotEmpty)
                                          ...fullDoctor.contacts.map((c) => Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.check_box_outline_blank, color: Colors.white54, size: 16),
                                                    const SizedBox(width: 6),
                                                    Expanded(child: Text(c.contactValue, style: const TextStyle(color: Colors.white, fontSize: 11))),
                                                    Expanded(child: Text(c.contactType, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                                                    const Icon(Icons.edit_outlined, color: Colors.white54, size: 14),
                                                  ],
                                                ),
                                              ))
                                        else
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            child: Row(
                                              children: const [
                                                Icon(Icons.check_box_outline_blank, color: Colors.white54, size: 16),
                                                SizedBox(width: 6),
                                                Expanded(child: Text('1234567890', style: TextStyle(color: Colors.white, fontSize: 11))),
                                                Expanded(child: Text('email@email.com', style: TextStyle(color: Colors.white70, fontSize: 11))),
                                                Icon(Icons.edit_outlined, color: Colors.white54, size: 14),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                                    onPressed: () {},
                                    child: const Text('Add Row', style: TextStyle(color: Colors.white, fontSize: 12)),
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
          );
        },
      ),
    );
  }

  Widget _buildReadonlyField(String label, String value, {bool isMandatory = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            if (isMandatory)
              const Text(' *', style: TextStyle(color: Color(0xFFFF453A), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    );
  }

  void _showAddDoctorDialog() {
    final formKey = GlobalKey<FormState>();
    String firstName = '';
    String middleName = '';
    String lastName = '';
    String? selectedType = _hcpTypes.isNotEmpty ? _hcpTypes.first.name : null;
    String selectedPractice = 'Both';
    String? selectedSpecialty = _specializations.isNotEmpty ? _specializations.first.name : null;
    String? selectedWorkplace = _institutions.isNotEmpty ? _institutions.first.name : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Register New Doctor (HCP)', style: TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  style: const TextStyle(color: Color(0xFF1C1C1E)),
                  decoration: const InputDecoration(
                    labelText: 'First Name *',
                    labelStyle: TextStyle(color: Color(0xFF636366)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD1D1D6))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0056B3), width: 2)),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  onSaved: (val) => firstName = val!,
                ),
                TextFormField(
                  style: const TextStyle(color: Color(0xFF1C1C1E)),
                  decoration: const InputDecoration(
                    labelText: 'Middle Name *',
                    labelStyle: TextStyle(color: Color(0xFF636366)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD1D1D6))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0056B3), width: 2)),
                  ),
                  onSaved: (val) => middleName = val ?? '',
                ),
                TextFormField(
                  style: const TextStyle(color: Color(0xFF1C1C1E)),
                  decoration: const InputDecoration(
                    labelText: 'Last Name *',
                    labelStyle: TextStyle(color: Color(0xFF636366)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD1D1D6))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0056B3), width: 2)),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  onSaved: (val) => lastName = val!,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type *'),
                  items: _hcpTypes.map((t) => DropdownMenuItem(value: t.name, child: Text(t.typeName))).toList(),
                  onChanged: (val) => selectedType = val,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPractice,
                  decoration: const InputDecoration(labelText: 'Practice *'),
                  items: const [
                    DropdownMenuItem(value: 'Dispensing', child: Text('Dispensing')),
                    DropdownMenuItem(value: 'Prescribing', child: Text('Prescribing')),
                    DropdownMenuItem(value: 'Both', child: Text('Both')),
                  ],
                  onChanged: (val) => selectedPractice = val!,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedSpecialty,
                  decoration: const InputDecoration(labelText: 'Specialty'),
                  items: _specializations.map((s) => DropdownMenuItem(value: s.name, child: Text(s.specialty))).toList(),
                  onChanged: (val) => selectedSpecialty = val,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedWorkplace,
                  decoration: const InputDecoration(labelText: 'Workplace'),
                  items: _institutions.map((i) => DropdownMenuItem(value: i.name, child: Text(i.institutionName))).toList(),
                  onChanged: (val) => selectedWorkplace = val,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF636366))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0056B3)),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(ctx);
                final apiService = Provider.of<ApiService>(context, listen: false);

                try {
                  setState(() => _isLoading = true);
                  final reqMiddleName = middleName.trim().isNotEmpty ? middleName.trim() : '-';
                  final reqSpec = selectedSpecialty ?? (_specializations.isNotEmpty ? _specializations.first.name : '');
                  final reqWork = selectedWorkplace ?? (_institutions.isNotEmpty ? _institutions.first.name : '');

                  final newDoctor = Hcp(
                    firstName: firstName,
                    middleName: reqMiddleName,
                    lastName: lastName,
                    hcpType: selectedType!,
                    hcpPractice: selectedPractice,
                    specialties: reqSpec.isNotEmpty ? [HcpSpecialty(hcpSpecialty: reqSpec)] : [],
                    workplaces: reqWork.isNotEmpty ? [HcpWorkplace(workplace: reqWork)] : [],
                  );
                  final savedDoctor = await apiService.createDoctor(newDoctor);

                  final newHcpAccount = HcpAccount(
                    accountName: apiService.selectedProgram,
                    territory: 'All Territories',
                    salesPerson: 'JORGE MENGORIO (AD0110)',
                    hcp: savedDoctor.name,
                  );
                  await apiService.hcpAccounts.create(newHcpAccount);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Doctor registered and linked to active program successfully!')),
                    );
                  }
                  _loadData();
                } catch (e) {
                  setState(() => _isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Register', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- ERPNext Filter Bar (Darkish Blue #0B192C Theme) ---
  Widget _buildFilterAndSortBar() {
    return Container(
      color: const Color(0xFF0B192C),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Filter Toggle Button
              InkWell(
                onTap: () => setState(() => _showFilters = !_showFilters),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _showFilters ? 'Filter ✕' : 'Filter',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Sort Direction Button
              InkWell(
                onTap: () {
                  setState(() {
                    _isAscending = !_isAscending;
                    _applyFilters();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Icon(
                    _isAscending ? Icons.arrow_downward : Icons.arrow_upward,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sort Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    dropdownColor: const Color(0xFF1E293B),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'Name of Doctor', child: Text('Name of Doctor')),
                      DropdownMenuItem(value: 'ID', child: Text('ID')),
                      DropdownMenuItem(value: 'Type', child: Text('Type')),
                      DropdownMenuItem(value: 'Practice', child: Text('Practice')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _sortBy = val;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),

          if (_showFilters) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // ID Filter Box
                SizedBox(
                  width: 120,
                  child: TextField(
                    onChanged: (val) {
                      _idQuery = val;
                      _applyFilters();
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'ID',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                    ),
                  ),
                ),

                // Name of Doctor Filter Box
                SizedBox(
                  width: 160,
                  child: TextField(
                    onChanged: (val) {
                      _nameQuery = val;
                      _applyFilters();
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Name of Doctor',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                    ),
                  ),
                ),

                // Is Active Checkbox Filter
                InkWell(
                  onTap: () {
                    setState(() {
                      _onlyIsActive = !_onlyIsActive;
                      _applyFilters();
                    });
                  },
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _onlyIsActive ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _onlyIsActive ? Icons.check_box : Icons.check_box_outline_blank,
                          color: _onlyIsActive ? const Color(0xFF38BDF8) : Colors.white54,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text('Is Active', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),

                // Type Filter Dropdown
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTypeFilter,
                      dropdownColor: const Color(0xFF1E293B),
                      hint: const Text('Type', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      onChanged: (val) {
                        setState(() {
                          _selectedTypeFilter = val;
                          _applyFilters();
                        });
                      },
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Types')),
                        ..._hcpTypes.map((t) => DropdownMenuItem(value: t.name, child: Text(t.typeName))),
                      ],
                    ),
                  ),
                ),

                // Practice Filter Dropdown
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPracticeFilter,
                      dropdownColor: const Color(0xFF1E293B),
                      hint: const Text('Practice', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      onChanged: (val) {
                        setState(() {
                          _selectedPracticeFilter = val;
                          _applyFilters();
                        });
                      },
                      items: const [
                        DropdownMenuItem<String>(value: null, child: Text('All Practices')),
                        DropdownMenuItem(value: 'Dispensing', child: Text('Dispensing')),
                        DropdownMenuItem(value: 'Prescribing', child: Text('Prescribing')),
                        DropdownMenuItem(value: 'Both', child: Text('Both')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9), // Soft Light Background for Darkish Blue & White combination
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Doctor Listing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0B192C),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      drawer: const AppDrawer(currentItem: DrawerItem.doctorManagement),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0066FF)),
                ),
              )
            : Column(
                children: [
                  _buildFilterAndSortBar(),

                  // Darkish Blue Table Header Strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: const Color(0xFF0B192C),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 4,
                          child: Text('Name of Doctor', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(
                          width: 75,
                          child: Text('Is Active', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const Expanded(
                          flex: 3,
                          child: Text('Institution', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const Expanded(
                          flex: 3,
                          child: Text('Practice', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const Expanded(
                          flex: 2,
                          child: Text('Type', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const Expanded(
                          flex: 2,
                          child: Text('ID', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        SizedBox(
                          width: 45,
                          child: Text(
                            '${_filteredDoctors.length} of ${_allDoctors.length}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Clean White Card Rows with Exact Flex Alignment
                  Expanded(
                    child: _filteredDoctors.isEmpty
                        ? const Center(
                            child: Text('No doctors match your criteria.', style: TextStyle(color: Color(0xFF64748B))),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _filteredDoctors.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 2),
                            itemBuilder: (ctx, index) {
                              final doctor = _filteredDoctors[index];
                              final fullName = '${doctor.firstName} ${doctor.middleName != null && doctor.middleName != '-' && doctor.middleName!.isNotEmpty ? doctor.middleName! + ' ' : ''}${doctor.lastName}';
                              final typeLabel = _hcpTypes.firstWhere((t) => t.name == doctor.hcpType, orElse: () => HcpType(name: doctor.hcpType, typeName: doctor.hcpType)).typeName;

                              return Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                                child: InkWell(
                                  onTap: () => _openDoctorProfile(doctor),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        // Name of Doctor
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            fullName,
                                            style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Is Active Check Icon
                                        SizedBox(
                                          width: 75,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Icon(
                                              doctor.isActive ? Icons.check_box_rounded : Icons.check_box_outline_blank,
                                              color: doctor.isActive ? const Color(0xFF0066FF) : const Color(0xFFCBD5E1),
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                        // Institution
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            (doctor.institution != null && doctor.institution!.isNotEmpty) ? doctor.institution! : '-',
                                            style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Practice Tag Capsule
                                        Expanded(
                                          flex: 3,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const CircleAvatar(radius: 3, backgroundColor: Color(0xFF0B192C)),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      doctor.hcpPractice,
                                                      style: const TextStyle(color: Color(0xFF0B192C), fontSize: 11, fontWeight: FontWeight.w600),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Type
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            typeLabel,
                                            style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // ID
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            doctor.name ?? '',
                                            style: const TextStyle(color: Color(0xFF64748B), fontFamily: 'monospace', fontSize: 11),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 45),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0066FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add HCP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddDoctorDialog,
      ),
    );
  }
}
