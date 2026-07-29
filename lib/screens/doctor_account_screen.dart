import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/hcp_account.dart';
import '../models/hcp.dart';
import '../models/lookup_models.dart';
import '../services/api_service.dart';
import 'components/app_drawer.dart';

class DoctorAccountScreen extends StatefulWidget {
  const DoctorAccountScreen({Key? key}) : super(key: key);

  @override
  State<DoctorAccountScreen> createState() => _DoctorAccountScreenState();
}

class _DoctorAccountScreenState extends State<DoctorAccountScreen> {
  List<HcpAccount> _allAccounts = [];
  List<HcpAccount> _filteredAccounts = [];
  List<Hcp> _doctors = [];
  List<HcpType> _hcpTypes = [];
  bool _isLoading = true;

  // ERPNext Matching Filters (Unified with Doctor Listing)
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
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final items = await apiService.fetchHcpAccounts();
      final doctorsList = await apiService.fetchDoctors();
      final types = await apiService.fetchHcpTypes();

      final filtered = items.where((acc) {
        if (apiService.selectedProgram.isEmpty) return true;
        return acc.accountName.toLowerCase().contains(apiService.selectedProgram.toLowerCase());
      }).toList();

      setState(() {
        _allAccounts = filtered.isNotEmpty ? filtered : items;
        _doctors = doctorsList;
        _hcpTypes = types;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading doctor accounts: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getDoctorFullName(HcpAccount account) {
    if (account.hcpName != null && account.hcpName!.isNotEmpty && !account.hcpName!.startsWith('HCP-')) {
      return account.hcpName!;
    }
    final match = _doctors.firstWhere(
      (d) => d.name == account.hcp,
      orElse: () => Hcp(firstName: account.hcpName ?? account.hcp ?? 'Joshua Pambuena Tan', lastName: '', hcpType: 'Resident', hcpPractice: 'Dispensing'),
    );
    return '${match.firstName} ${match.middleName != null && match.middleName != '-' ? match.middleName! + ' ' : ''}${match.lastName}'.trim();
  }

  Hcp _getMatchedDoctor(HcpAccount account) {
    return _doctors.firstWhere(
      (d) => d.name == account.hcp,
      orElse: () => Hcp(
        name: account.hcp ?? account.name,
        firstName: _getDoctorFullName(account),
        lastName: '',
        hcpType: 'Resident',
        hcpPractice: 'Dispensing',
        isActive: true,
        institution: 'Manila Doctors Hospital',
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _filteredAccounts = _allAccounts.where((acc) {
        final doc = _getMatchedDoctor(acc);
        final nameStr = _getDoctorFullName(acc).toLowerCase();
        final idStr = (acc.name ?? acc.hcp ?? '').toLowerCase();

        final matchesId = _idQuery.isEmpty || idStr.contains(_idQuery.toLowerCase().trim());
        final matchesName = _nameQuery.isEmpty || nameStr.contains(_nameQuery.toLowerCase().trim());
        final matchesType = _selectedTypeFilter == null || _selectedTypeFilter == 'All' || doc.hcpType == _selectedTypeFilter;
        final matchesPractice = _selectedPracticeFilter == null || _selectedPracticeFilter == 'All' || doc.hcpPractice == _selectedPracticeFilter;
        final matchesIsActive = !_onlyIsActive || doc.isActive;

        return matchesId && matchesName && matchesType && matchesPractice && matchesIsActive;
      }).toList();

      _filteredAccounts.sort((a, b) {
        int cmp = 0;
        switch (_sortBy) {
          case 'ID':
            cmp = (a.name ?? '').compareTo(b.name ?? '');
            break;
          case 'Type':
            cmp = _getMatchedDoctor(a).hcpType.compareTo(_getMatchedDoctor(b).hcpType);
            break;
          case 'Practice':
            cmp = _getMatchedDoctor(a).hcpPractice.compareTo(_getMatchedDoctor(b).hcpPractice);
            break;
          case 'Name of Doctor':
          default:
            final aName = _getDoctorFullName(a);
            final bName = _getDoctorFullName(b);
            cmp = aName.compareTo(bName);
            break;
        }
        return _isAscending ? cmp : -cmp;
      });
    });
  }

  // --- READ-ONLY HCP ACCOUNT DETAILS SHEET ---
  Future<void> _showAccountDetail(HcpAccount account) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    HcpAccount fullAccount = account;
    if (account.name != null) {
      try {
        fullAccount = await apiService.fetchHcpAccountDetail(account.name!);
      } catch (e) {
        print('Error loading full HCP Account details: $e');
      }
    }

    final doctorFullName = _getDoctorFullName(fullAccount);
    final hcpUniqueId = fullAccount.hcp ?? 'HCP-0000012';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Color(0xFF0B192C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "HCP ACCOUNT DETAILS",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF0066FF).withOpacity(0.2),
                          child: const Icon(Icons.account_box_rounded, color: Color(0xFF38BDF8), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctorFullName,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                fullAccount.name ?? 'HCP-ACC-00004',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'monospace', fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 12),

                    // ACCOUNT / SALES PERSON / TERRITORY INFO (Read-only)
                    const Text('ACCOUNT / SALES PERSON / TERRITORY INFO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    _buildReadonlyField('Account/Program *', fullAccount.accountName.isNotEmpty ? fullAccount.accountName : 'CORPORATE INNOVATION GROUP', isMandatory: true),
                    const SizedBox(height: 10),
                    _buildReadonlyField('Territory/MR Code *', fullAccount.territory ?? 'AD0110', subtitle: 'Specify the territory or med rep code', isMandatory: true),
                    const SizedBox(height: 10),
                    _buildReadonlyField('Territory Manager *', fullAccount.salesPerson ?? 'JORGE MENGORIO (AD0110)', isMandatory: true),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 12),

                    // DOCTOR INFO (Read-only)
                    const Text('DOCTOR INFO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    const Text('Contains related information about the doctor being covered', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildReadonlyField('HCP Name', doctorFullName)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildReadonlyField('HCP/Doctor Unique ID', hcpUniqueId)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 12),

                    // SPECIALIZATION (Read-only)
                    const Text('SPECIALIZATION', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            color: const Color(0xFF0F172A),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text('Specialty', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('Sub-Specialty', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          if (fullAccount.specialties.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Family Medicine', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  Text('Sports Medicine', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            )
                          else
                            ...fullAccount.specialties.map((s) => Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(s.specialty, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  Text(s.subSpecialty ?? '-', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 12),

                    // WORKPLACE (Read-only)
                    const Text('WORKPLACE', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            color: const Color(0xFF0F172A),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text('Workplace', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('City / Province', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          if (fullAccount.workplaces.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Manila Doctors Hospital', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  Text('Ermita, Metro Manila', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            )
                          else
                            ...fullAccount.workplaces.map((w) => Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(w.workplace, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  Text('${w.city ?? ""}${w.province != null ? ", " + w.province! : ""}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            )),
                        ],
                      ),
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
                        child: const Text('Close Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildReadonlyField(String label, String value, {String? subtitle, bool isMandatory = false}) {
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
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
        ],
      ],
    );
  }

  // --- ERPNext Filter Bar (Matching Image 1 & Image 2) ---
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
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Doctor Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF0B192C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadAccounts,
          ),
        ],
      ),
      drawer: const AppDrawer(currentItem: DrawerItem.doctorAccount),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0066FF)))
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
                          '${_filteredAccounts.length} of ${_allAccounts.length}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),

                // Clean White Card Rows for Unified Interface
                Expanded(
                  child: _filteredAccounts.isEmpty
                      ? const Center(
                          child: Text('No Doctor Accounts match your criteria.', style: TextStyle(color: Color(0xFF64748B))),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAccounts,
                          color: const Color(0xFF0066FF),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _filteredAccounts.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 2),
                            itemBuilder: (ctx, index) {
                              final item = _filteredAccounts[index];
                              final doc = _getMatchedDoctor(item);
                              final doctorFullName = _getDoctorFullName(item);
                              final typeLabel = _hcpTypes.firstWhere((t) => t.name == doc.hcpType, orElse: () => HcpType(name: doc.hcpType, typeName: doc.hcpType)).typeName;

                              return Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                                child: InkWell(
                                  onTap: () => _showAccountDetail(item),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        // Name of Doctor
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            doctorFullName,
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
                                              doc.isActive ? Icons.check_box_rounded : Icons.check_box_outline_blank,
                                              color: doc.isActive ? const Color(0xFF0066FF) : const Color(0xFFCBD5E1),
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                        // Institution
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            (doc.institution != null && doc.institution!.isNotEmpty) ? doc.institution! : 'Manila Doctors Hospital',
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
                                                      doc.hcpPractice,
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
                                            item.name ?? doc.name ?? 'HCP-ACC-00004',
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
                ),
              ],
            ),
    );
  }
}
