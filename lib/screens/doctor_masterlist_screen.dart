import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/hcp.dart';
import '../models/lookup_models.dart';
import '../models/hcp_account.dart';
import '../services/api_service.dart';
import 'components/app_drawer.dart';

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
      final doctors = await apiService.fetchDoctors().catchError((e) {
        print('Fetch doctors caught error: $e');
        return <Hcp>[];
      });
      final institutions = await apiService.fetchInstitutions().catchError((_) => <Institution>[]);
      final specializations = await apiService.fetchSpecializations().catchError((_) => <Specialization>[]);
      final psgc = await apiService.fetchPsgcLocations().catchError((_) => <PsgcLocation>[]);
      final types = await apiService.fetchHcpTypes().catchError((_) => <HcpType>[]);

      if (mounted) {
        setState(() {
          _allDoctors = doctors;
          _institutions = institutions;
          _specializations = specializations.where((s) => !s.isGroup).toList();
          _psgcLocations = psgc;
          _hcpTypes = types;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading doctor list: $e')),
        );
      }
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

  // --- DOCTOR'S INFORMATION SHEET (Complete Read-Only View) ---
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
    final specLookup = {for (var s in _specializations) s.name: s.specialty};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: const BoxDecoration(
          color: Color(0xFF0B192C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
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
                    // Title Header (Read-only Document View)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            "DOCTOR'S INFORMATION SHEET",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Doctor Name Box & Active Status Badge
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
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: fullDoctor.isActive ? const Color(0xFF0066FF).withOpacity(0.2) : const Color(0xFF64748B).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: fullDoctor.isActive ? const Color(0xFF0066FF) : const Color(0xFF64748B)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                fullDoctor.isActive ? Icons.check_circle : Icons.cancel,
                                color: fullDoctor.isActive ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                fullDoctor.isActive ? 'Is Active' : 'Inactive',
                                style: TextStyle(
                                  color: fullDoctor.isActive ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Doctor Portrait Image Preview Container
                    Container(
                      width: 160,
                      height: 180,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          (fullDoctor.hcpPhoto != null && fullDoctor.hcpPhoto!.isNotEmpty)
                              ? fullDoctor.hcpPhoto!
                              : 'https://pngimg.com/uploads/doctor/doctor_PNG16003.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.person, size: 70, color: Colors.white38),
                          ),
                        ),
                      ),
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

                    // SPECIALIZATION / TYPE & PRACTICE (Responsive Layout)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final specWidget = Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                color: const Color(0xFF0F172A),
                                child: Row(
                                  children: const [
                                    Expanded(child: Text('Specialty', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                    Expanded(child: Text('Sub Specialty', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(specName, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                        Expanded(child: Text(subName.isNotEmpty ? subName : 'General Practice', style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  );
                                })
                              else
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: const [
                                      Expanded(child: Text('Family Medicine', style: TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                      Expanded(child: Text('General Practice', style: TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );

                        final typePracticeWidget = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildReadonlyField('Type *', fullDoctor.hcpType.isNotEmpty ? fullDoctor.hcpType : 'Resident', isMandatory: true),
                            const SizedBox(height: 12),
                            _buildReadonlyField('Practice *', fullDoctor.hcpPractice.isNotEmpty ? fullDoctor.hcpPractice : 'Prescribing', isMandatory: true),
                          ],
                        );

                        if (constraints.maxWidth < 600) {
                          return Column(
                            children: [
                              specWidget,
                              const SizedBox(height: 16),
                              typePracticeWidget,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: specWidget),
                            const SizedBox(width: 16),
                            Expanded(child: typePracticeWidget),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 12),

                    // WORKPLACES / CONTACT INFO Section (Responsive Layout)
                    const Text('WORKPLACES / CONTACT INFO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final apiService = Provider.of<ApiService>(context, listen: false);
                        final isMedRep = apiService.isMedRep;

                        final prefWorkplaces = fullDoctor.workplaces.where((w) => w.isPrimary).toList();
                        final displayWorkplaces = (isMedRep && prefWorkplaces.isNotEmpty) ? prefWorkplaces : fullDoctor.workplaces;

                        final prefContacts = fullDoctor.contacts.where((c) => c.isPrimary).toList();
                        final displayContacts = (isMedRep && prefContacts.isNotEmpty) ? prefContacts : fullDoctor.contacts;

                        final workplacesWidget = Container(
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
                                  children: [
                                    const Expanded(flex: 2, child: Text('Workplace', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                    const Expanded(child: Text('City / Address', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                    if (isMedRep)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0066FF).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Preferred', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                              ),
                              if (displayWorkplaces.isNotEmpty)
                                ...displayWorkplaces.map((w) {
                                  final isPref = w.isPrimary;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Row(
                                      children: [
                                        if (isPref) ...[
                                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            w.workplace,
                                            style: TextStyle(
                                              color: isPref ? const Color(0xFFFCD34D) : Colors.white,
                                              fontWeight: isPref ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 11,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Expanded(child: Text(w.address ?? '', style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis)),
                                        if (isPref && !isMedRep) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                                            ),
                                            child: const Text('Preferred', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 8.5, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                })
                              else
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 2, child: Text('No workplace assigned', style: TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis)),
                                      Expanded(child: Text('-', style: TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );

                        final contactWidget = Container(
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
                                  children: [
                                    const Expanded(child: Text('Contact Value', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                    const Expanded(child: Text('Type', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                    if (isMedRep)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0066FF).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Preferred', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                              ),
                              if (displayContacts.isNotEmpty)
                                ...displayContacts.map((c) {
                                  final isPref = c.isPrimary;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Row(
                                      children: [
                                        if (isPref) ...[
                                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            c.contactValue,
                                            style: TextStyle(
                                              color: isPref ? const Color(0xFFFCD34D) : Colors.white,
                                              fontWeight: isPref ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 11,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Expanded(child: Text(c.contactType, style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis)),
                                        if (isPref && !isMedRep) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                                            ),
                                            child: const Text('Preferred', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 8.5, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                })
                              else
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text('-', style: TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis)),
                                      Expanded(child: Text('-', style: TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );

                        if (constraints.maxWidth < 600) {
                          return Column(
                            children: [
                              workplacesWidget,
                              const SizedBox(height: 16),
                              contactWidget,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: workplacesWidget),
                            const SizedBox(width: 16),
                            Expanded(child: contactWidget),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: const BorderSide(color: Color(0xFF334155)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    Uint8List? docPhotoBytes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Register New Doctor (HCP)', style: TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Photo Box
                  Center(
                    child: InkWell(
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
                                  leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0056B3)),
                                  title: const Text('Take Photo with Camera'),
                                  onTap: () async {
                                    Navigator.pop(bCtx);
                                    final picker = ImagePicker();
                                    final img = await picker.pickImage(source: ImageSource.camera, maxWidth: 800, maxHeight: 800, imageQuality: 85);
                                    if (img != null) {
                                      final bytes = await img.readAsBytes();
                                      setDialogState(() => docPhotoBytes = bytes);
                                    }
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF0056B3)),
                                  title: const Text('Upload from Gallery'),
                                  onTap: () async {
                                    Navigator.pop(bCtx);
                                    final picker = ImagePicker();
                                    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
                                    if (img != null) {
                                      final bytes = await img.readAsBytes();
                                      setDialogState(() => docPhotoBytes = bytes);
                                    }
                                  },
                                ),
                                if (docPhotoBytes != null)
                                  ListTile(
                                    leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                                    title: const Text('Remove Photo', style: TextStyle(color: Color(0xFFDC2626))),
                                    onTap: () {
                                      Navigator.pop(bCtx);
                                      setDialogState(() => docPhotoBytes = null);
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
                          border: Border.all(color: docPhotoBytes != null ? const Color(0xFF0056B3) : const Color(0xFFCBD5E1), width: docPhotoBytes != null ? 2 : 1),
                        ),
                        child: docPhotoBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(docPhotoBytes!, width: 76, height: 76, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo_rounded, color: Color(0xFF0056B3), size: 22),
                                  SizedBox(height: 4),
                                  Text('Add Photo', style: TextStyle(color: Color(0xFF0056B3), fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                      DropdownMenuItem(value: 'Prescribing', child: Text('Prescribing')),
                      DropdownMenuItem(value: 'Dispensing', child: Text('Dispensing')),
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
                    final computedFullName = [
                      firstName.trim(),
                      if (reqMiddleName.isNotEmpty && reqMiddleName != '-') reqMiddleName,
                      lastName.trim(),
                    ].join(' ');

                    String? uploadedPhotoUrl;
                    if (docPhotoBytes != null) {
                      try {
                        uploadedPhotoUrl = await apiService.uploadFile(
                          bytes: docPhotoBytes!,
                          filename: 'hcp_${DateTime.now().millisecondsSinceEpoch}.jpg',
                          doctype: 'HCP',
                        );
                      } catch (e) {
                        debugPrint('Photo upload error: $e');
                      }
                    }

                    final newDoctor = Hcp(
                      firstName: firstName.trim(),
                      middleName: reqMiddleName,
                      lastName: lastName.trim(),
                      hcpFullName: computedFullName,
                      hcpPhoto: uploadedPhotoUrl,
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
                        DropdownMenuItem(value: 'Prescribing', child: Text('Prescribing')),
                        DropdownMenuItem(value: 'Dispensing', child: Text('Dispensing')),
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
    final apiService = Provider.of<ApiService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9), // Soft Light Background for Darkish Blue & White combination
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Doctor Listing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0B192C),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.white.withOpacity(0.3),
            height: 1.0,
          ),
        ),
        actions: [
          // Role Badge
          Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: apiService.isAdmin
                  ? const Color(0xFFEF4444).withOpacity(0.25)
                  : (apiService.isManager
                      ? const Color(0xFFF59E0B).withOpacity(0.25)
                      : const Color(0xFF0066FF).withOpacity(0.25)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: apiService.isAdmin
                    ? const Color(0xFFEF4444)
                    : (apiService.isManager
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF38BDF8)),
                width: 0.8,
              ),
            ),
            child: Text(
              apiService.userPositionTitle,
              style: TextStyle(
                color: apiService.isAdmin
                    ? const Color(0xFFFCA5A5)
                    : (apiService.isManager
                        ? const Color(0xFFFCD34D)
                        : const Color(0xFF93C5FD)),
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
          const SizedBox(width: 4),
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

                  if (apiService.isMedRep)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: const Color(0xFF1E293B),
                      child: Row(
                        children: const [
                          Icon(Icons.lock_outline_rounded, color: Color(0xFF38BDF8), size: 14),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'View-Only Mode (MedRep): To add or update HCP records, submit an HCP Profile Submission.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Darkish Blue Table Header Strip with Top Border & Vertical Column Separators
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0B192C),
                      border: Border(
                        top: BorderSide(color: Colors.white38, width: 1.0),
                        bottom: BorderSide(color: Colors.white12, width: 1.0),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          const Expanded(
                            flex: 4,
                            child: Text('Name of Doctor', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                          const SizedBox(
                            width: 75,
                            child: Text('Is Active', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                          const Expanded(
                            flex: 3,
                            child: Text('Institution', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                          const Expanded(
                            flex: 3,
                            child: Text('Practice', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                          const Expanded(
                            flex: 2,
                            child: Text('Type', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                          const Expanded(
                            flex: 2,
                            child: Text('ID', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                          SizedBox(
                            width: 45,
                            child: Text(
                              '${_filteredDoctors.length} of ${_allDoctors.length}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
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
                              final computedParts = [
                                if (doctor.firstName.trim().isNotEmpty) doctor.firstName.trim(),
                                if (doctor.middleName != null && doctor.middleName!.trim().isNotEmpty && doctor.middleName!.trim() != '-') doctor.middleName!.trim(),
                                if (doctor.lastName.trim().isNotEmpty) doctor.lastName.trim(),
                              ].join(' ');
                              final fullName = (doctor.hcpFullName != null && doctor.hcpFullName!.trim().isNotEmpty && !doctor.hcpFullName!.startsWith('HCP-'))
                                  ? doctor.hcpFullName!.trim()
                                  : (computedParts.isNotEmpty ? computedParts : (doctor.name ?? 'Unknown Doctor'));
                              final typeLabel = _hcpTypes.firstWhere((t) => t.name == doctor.hcpType, orElse: () => HcpType(name: doctor.hcpType, typeName: doctor.hcpType)).typeName;

                              final prefDocWorkplaces = doctor.workplaces.where((w) => w.isPrimary).toList();
                              final String instDisplay = prefDocWorkplaces.isNotEmpty
                                  ? prefDocWorkplaces.map((w) => (w.address != null && w.address!.isNotEmpty) ? w.address! : w.workplace).join(', ')
                                  : (doctor.workplaces.isNotEmpty
                                      ? ((doctor.workplaces.first.address != null && doctor.workplaces.first.address!.isNotEmpty)
                                          ? doctor.workplaces.first.address!
                                          : doctor.workplaces.first.workplace)
                                      : ((doctor.institution != null && doctor.institution!.isNotEmpty) ? doctor.institution! : '-'));

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
                                            instDisplay,
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
      floatingActionButton: apiService.canCreateOrEditDoctor
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF0B192C),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add HCP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _showAddDoctorDialog,
            )
          : null,
    );
  }
}
