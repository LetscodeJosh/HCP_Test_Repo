import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/hcp.dart';
import '../models/lookup_models.dart';
import '../models/hcp_account.dart';
import '../services/api_service.dart';
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
  String _searchQuery = '';
  
  // ERPNext Matching Filters
  String? _selectedTypeFilter;
  String? _selectedPracticeFilter;
  bool _onlyIsActive = false;
  bool _onlyIsPendingApproval = false;

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

      final hcpAccounts = await apiService.hcpAccounts.list(
        filters: [['account_or_program', '=', apiService.selectedProgram]],
        fields: ['hcp'],
        limit: 1000,
      );
      final allowedHcpIds = hcpAccounts.map((a) => a.hcp).whereType<String>().toSet();

      setState(() {
        _allDoctors = doctors.where((d) => allowedHcpIds.contains(d.name)).toList();
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
        final queryLower = _searchQuery.toLowerCase().trim();
        final matchesSearch = queryLower.isEmpty || nameStr.contains(queryLower) || idStr.contains(queryLower);

        final matchesType = _selectedTypeFilter == null || doctor.hcpType == _selectedTypeFilter;
        final matchesPractice = _selectedPracticeFilter == null || doctor.hcpPractice == _selectedPracticeFilter;
        final matchesIsActive = !_onlyIsActive || doctor.isActive;
        final matchesIsPending = !_onlyIsPendingApproval || doctor.isPendingApproval;

        return matchesSearch && matchesType && matchesPractice && matchesIsActive && matchesIsPending;
      }).toList();
    });
  }

  void _openDoctorProfile(Hcp doctor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF0056B3).withOpacity(0.1),
                    child: const Icon(Icons.person, color: Color(0xFF0056B3), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${doctor.firstName} ${doctor.middleName != null && doctor.middleName != '-' ? doctor.middleName! + ' ' : ''}${doctor.lastName}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
                        ),
                        Text(
                          doctor.name ?? '',
                          style: const TextStyle(color: Color(0xFF8E8E93), fontFamily: 'monospace', fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Registered Doctor Details', style: TextStyle(color: Color(0xFF0056B3), fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _detailRowItem('First Name', doctor.firstName),
              if (doctor.middleName != null && doctor.middleName!.isNotEmpty)
                _detailRowItem('Middle Name', doctor.middleName!),
              _detailRowItem('Last Name', doctor.lastName),
              if (doctor.birthDate != null)
                _detailRowItem('Birth Date', doctor.birthDate!),
              _detailRowItem('HCP Type', doctor.hcpType),
              _detailRowItem('Practice Mode', doctor.hcpPractice),
              _detailRowItem('Status', doctor.isActive ? 'Active' : 'Inactive'),
              if (doctor.regionName != null)
                _detailRowItem('Region', doctor.regionName!),
              if (doctor.provinceName != null)
                _detailRowItem('Province', doctor.provinceName!),
              if (doctor.cityMunicipality != null)
                _detailRowItem('City', doctor.cityMunicipality!),
              
              if (doctor.specialties.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Declared Specialties', style: TextStyle(color: Color(0xFF0056B3), fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...doctor.specialties.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text('• ${s.hcpSpecialty} ${s.subSpecialty != null ? "(${s.subSpecialty})" : ""}', style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 14)),
                )),
              ],

              if (doctor.workplaces.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Workplaces', style: TextStyle(color: Color(0xFF0056B3), fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...doctor.workplaces.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text('• ${w.workplace}', style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 14)),
                )),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056B3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRowItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF636366), fontSize: 13)),
          Text(value, style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
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
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Color(0xFF1C1C1E)),
                  decoration: const InputDecoration(
                    labelText: 'HCP Type *',
                    labelStyle: TextStyle(color: Color(0xFF636366)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD1D1D6))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0056B3), width: 2)),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Please select an HCP Type' : null,
                  items: _hcpTypes.map((t) => DropdownMenuItem(
                    value: t.name,
                    child: Text(t.typeName, style: const TextStyle(color: Color(0xFF1C1C1E))),
                  )).toList(),
                  onChanged: (val) => selectedType = val,
                ),
                DropdownButtonFormField<String>(
                  value: selectedSpecialty,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Color(0xFF1C1C1E)),
                  decoration: const InputDecoration(
                    labelText: 'Primary Specialty *',
                    labelStyle: TextStyle(color: Color(0xFF636366)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD1D1D6))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0056B3), width: 2)),
                  ),
                  items: _specializations.map((s) => DropdownMenuItem(
                    value: s.name,
                    child: Text(s.specialty, style: const TextStyle(color: Color(0xFF1C1C1E))),
                  )).toList(),
                  onChanged: (val) => selectedSpecialty = val,
                ),
                DropdownButtonFormField<String>(
                  value: selectedWorkplace,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Color(0xFF1C1C1E)),
                  decoration: const InputDecoration(
                    labelText: 'Workplace / Institution *',
                    labelStyle: TextStyle(color: Color(0xFF636366)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD1D1D6))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0056B3), width: 2)),
                  ),
                  items: _institutions.map((i) => DropdownMenuItem(
                    value: i.name,
                    child: Text(i.institutionName, style: const TextStyle(color: Color(0xFF1C1C1E))),
                  )).toList(),
                  onChanged: (val) => selectedWorkplace = val,
                ),
                DropdownButtonFormField<String>(
                  value: selectedPractice,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Color(0xFF1C1C1E)),
                  decoration: const InputDecoration(
                    labelText: 'Practice Mode *',
                    labelStyle: TextStyle(color: Color(0xFF636366)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD1D1D6))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0056B3), width: 2)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Dispensing', child: Text('Dispensing', style: TextStyle(color: Color(0xFF1C1C1E)))),
                    DropdownMenuItem(value: 'Prescribing', child: Text('Prescribing', style: TextStyle(color: Color(0xFF1C1C1E)))),
                    DropdownMenuItem(value: 'Both', child: Text('Both', style: TextStyle(color: Color(0xFF1C1C1E)))),
                  ],
                  onChanged: (val) => selectedPractice = val!,
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
                setState(() => _isLoading = true);

                final apiService = Provider.of<ApiService>(context, listen: false);
                try {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('HCP'),
        backgroundColor: const Color(0xFF0056B3),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDoctorDialog,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/medical_bg.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: const Icon(Icons.donut_large, color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'PIMS HCP',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Provider.of<ApiService>(context, listen: false).loggedInEmail ?? '',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Consumer<ApiService>(
                  builder: (context, api, child) {
                    return DropdownButtonFormField<String>(
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF1C1C1E)),
                      value: api.selectedProgram,
                      decoration: const InputDecoration(
                        labelText: 'Active Program',
                        labelStyle: TextStyle(color: Color(0xFF0056B3), fontWeight: FontWeight.bold),
                        prefixIcon: Icon(Icons.business_center, color: Color(0xFF0056B3)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFD1D1D6)),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF0056B3), width: 2),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      items: api.availablePrograms.map((prog) {
                        return DropdownMenuItem<String>(
                          value: prog,
                          child: Text(prog),
                        );
                      }).toList(),
                      onChanged: (newProg) {
                        if (newProg != null) {
                          api.setProgram(newProg);
                          _loadData();
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.people_alt, color: Color(0xFF0056B3)),
                title: const Text('HCP', style: TextStyle(color: Color(0xFF0056B3), fontWeight: FontWeight.bold)),
                selected: true,
                selectedTileColor: const Color(0xFF0056B3).withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.assignment_turned_in, color: Color(0xFFFF9500)),
                title: const Text('HCP Profile Submissions', style: TextStyle(color: Color(0xFF1C1C1E))),
                subtitle: const Text('View IT Manager changes from ERPNext', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SubmissionHistoryScreen()));
                },
              ),
              const Spacer(),
              const Divider(color: Color(0xFFD1D1D6)),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFFF3B30)),
                title: const Text('Logout', style: TextStyle(color: Color(0xFFFF3B30))),
                onTap: () {
                  Provider.of<ApiService>(context, listen: false).logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0056B3)),
              ),
            )
          : Column(
              children: [
                // ERPNext Filter Bar Matching Screenshot
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA))),
                  ),
                  child: Column(
                    children: [
                      // Search ID / Name of Doctor
                      TextField(
                        onChanged: (val) {
                          _searchQuery = val;
                          _applyFilters();
                        },
                        style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search by ID or Name of Doctor...',
                          hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF8E8E93)),
                          filled: true,
                          fillColor: const Color(0xFFF4F6F9),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFD1D1D6)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFD1D1D6)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Dropdown Filters: Type & Practice
                      Row(
                        children: [
                          // Type Filter
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFD1D1D6)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedTypeFilter,
                                  dropdownColor: Colors.white,
                                  hint: const Text('Type', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8E8E93)),
                                  style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 12),
                                  onChanged: (val) {
                                    _selectedTypeFilter = val;
                                    _applyFilters();
                                  },
                                  items: [
                                    const DropdownMenuItem<String>(value: null, child: Text('All Types')),
                                    ..._hcpTypes.map((t) => DropdownMenuItem(
                                          value: t.name,
                                          child: Text(t.typeName, style: const TextStyle(color: Color(0xFF1C1C1E))),
                                        )),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Practice Filter
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFD1D1D6)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedPracticeFilter,
                                  dropdownColor: Colors.white,
                                  hint: const Text('Practice', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8E8E93)),
                                  style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 12),
                                  onChanged: (val) {
                                    _selectedPracticeFilter = val;
                                    _applyFilters();
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Checkbox Filter Chips: Is Active & Is Pending Approval
                      Row(
                        children: [
                          FilterChip(
                            label: const Text('Is Active', style: TextStyle(fontSize: 12)),
                            selected: _onlyIsActive,
                            selectedColor: const Color(0xFF0056B3).withOpacity(0.15),
                            checkmarkColor: const Color(0xFF0056B3),
                            onSelected: (val) {
                              _onlyIsActive = val;
                              _applyFilters();
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Is Pending Approval', style: TextStyle(fontSize: 12)),
                            selected: _onlyIsPendingApproval,
                            selectedColor: const Color(0xFFFF9500).withOpacity(0.15),
                            checkmarkColor: const Color(0xFFFF9500),
                            onSelected: (val) {
                              _onlyIsPendingApproval = val;
                              _applyFilters();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Doctor List Table View (Matching ERPNext columns)
                Expanded(
                  child: _filteredDoctors.isEmpty
                      ? const Center(
                          child: Text('No doctors match your criteria.', style: TextStyle(color: Color(0xFF8E8E93))),
                        )
                      : ListView.builder(
                          itemCount: _filteredDoctors.length,
                          itemBuilder: (ctx, index) {
                            final doctor = _filteredDoctors[index];
                            final fullName = '${doctor.firstName} ${doctor.middleName != null && doctor.middleName != '-' ? doctor.middleName! + ' ' : ''}${doctor.lastName}';
                            final typeLabel = _hcpTypes.firstWhere((t) => t.name == doctor.hcpType, orElse: () => HcpType(name: doctor.hcpType, typeName: doctor.hcpType)).typeName;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: Icon(
                                  doctor.isActive ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: doctor.isActive ? const Color(0xFF34C759) : const Color(0xFFC7C7CC),
                                  size: 22,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        fullName,
                                        style: const TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE5E5EA),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        doctor.hcpPractice,
                                        style: const TextStyle(color: Color(0xFF3A3A3C), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$typeLabel • ${doctor.institution ?? "No Institution"}',
                                        style: const TextStyle(color: Color(0xFF636366), fontSize: 12),
                                      ),
                                      Text(
                                        doctor.name ?? '',
                                        style: const TextStyle(color: Color(0xFF8E8E93), fontFamily: 'monospace', fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                onTap: () => _openDoctorProfile(doctor),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0056B3),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add HCP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddDoctorDialog,
      ),
    );
  }
}
