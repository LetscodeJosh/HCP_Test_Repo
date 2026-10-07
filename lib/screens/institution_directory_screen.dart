import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/lookup_models.dart';
import '../services/api_service.dart';
import 'components/app_drawer.dart';
import 'institution_approvals_screen.dart';
import 'sfe_institution_dashboard_screen.dart';

class InstitutionDirectoryScreen extends StatefulWidget {
  const InstitutionDirectoryScreen({Key? key}) : super(key: key);

  @override
  State<InstitutionDirectoryScreen> createState() => _InstitutionDirectoryScreenState();
}

class _InstitutionDirectoryScreenState extends State<InstitutionDirectoryScreen> {
  bool _isLoading = true;

  // Filter & Sort State (matching HCP Profile Submission exactly)
  bool _showFilters = true;
  bool _isAscending = false;
  String _sortBy = 'ID';

  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _regionCtrl = TextEditingController();
  final TextEditingController _provinceCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _regionCtrl.dispose();
    _provinceCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      await apiService.fetchInstitutions();
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _clearFilters() {
    setState(() {
      _idCtrl.clear();
      _nameCtrl.clear();
      _regionCtrl.clear();
      _provinceCtrl.clear();
      _cityCtrl.clear();
      _statusFilter = 'All';
    });
  }

  bool get _hasActiveFilters {
    return _idCtrl.text.trim().isNotEmpty ||
        _nameCtrl.text.trim().isNotEmpty ||
        _statusFilter != 'All' ||
        _regionCtrl.text.trim().isNotEmpty ||
        _provinceCtrl.text.trim().isNotEmpty ||
        _cityCtrl.text.trim().isNotEmpty;
  }

  List<Institution> _getFilteredAndSorted(List<Institution> source) {
    final idQ = _idCtrl.text.trim().toLowerCase();
    final nameQ = _nameCtrl.text.trim().toLowerCase();
    final regionQ = _regionCtrl.text.trim().toLowerCase();
    final provQ = _provinceCtrl.text.trim().toLowerCase();
    final cityQ = _cityCtrl.text.trim().toLowerCase();

    final filtered = source.where((inst) {
      // 1. Status Filter (matching ERPNext workflow_state)
      if (_statusFilter != 'All') {
        if (inst.status.toLowerCase() != _statusFilter.toLowerCase()) return false;
      }

      // 2. ID Filter
      if (idQ.isNotEmpty && !inst.name.toLowerCase().contains(idQ)) return false;

      // 3. Name Filter
      if (nameQ.isNotEmpty) {
        final displayName = inst.institutionName.isNotEmpty ? inst.institutionName : inst.name;
        if (!displayName.toLowerCase().contains(nameQ)) return false;
      }

      // 4. Region Filter
      if (regionQ.isNotEmpty) {
        final reg = (inst.regionName ?? inst.rawRegionName ?? '').toLowerCase();
        if (!reg.contains(regionQ)) return false;
      }

      // 5. Province Filter
      if (provQ.isNotEmpty) {
        final prov = (inst.provinceName ?? inst.rawProvinceName ?? '').toLowerCase();
        if (!prov.contains(provQ)) return false;
      }

      // 6. City / Municipality Filter
      if (cityQ.isNotEmpty) {
        final city = (inst.cityMunicipality ?? inst.rawCityMunicipality ?? '').toLowerCase();
        if (!city.contains(cityQ)) return false;
      }

      return true;
    }).toList();

    // Sorting
    filtered.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case 'Institution Name':
          final aName = a.institutionName.isNotEmpty ? a.institutionName : a.name;
          final bName = b.institutionName.isNotEmpty ? b.institutionName : b.name;
          cmp = aName.toLowerCase().compareTo(bName.toLowerCase());
          break;
        case 'ID':
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'Status':
          cmp = a.status.toLowerCase().compareTo(b.status.toLowerCase());
          break;
        case 'Region':
          cmp = (a.regionName ?? '').toLowerCase().compareTo((b.regionName ?? '').toLowerCase());
          break;
        case 'Province':
          cmp = (a.provinceName ?? '').toLowerCase().compareTo((b.provinceName ?? '').toLowerCase());
          break;
        case 'City/Municipality':
          cmp = (a.cityMunicipality ?? '').toLowerCase().compareTo((b.cityMunicipality ?? '').toLowerCase());
          break;
        case 'Created On':
          cmp = (a.creation ?? '').compareTo(b.creation ?? '');
          break;
        case 'Last Updated On':
        default:
          cmp = (a.modified ?? a.creation ?? '').compareTo(b.modified ?? b.creation ?? '');
          break;
      }
      return _isAscending ? cmp : -cmp;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);
    // Display all masterlist institutions from ERPNext (including Draft facilities)
    final allInstitutions = apiService.cachedInstitutions.isNotEmpty
        ? apiService.cachedInstitutions
        : apiService.actualInstitutions;
    final filteredList = _getFilteredAndSorted(allInstitutions);
    final totalCount = allInstitutions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(currentItem: DrawerItem.institutions),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B192C),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Institution Directory',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'Master Healthcare Facilities Reference',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Directory',
            onPressed: _loadData,
          ),
          if (apiService.isSfe || apiService.isAdmin)
            IconButton(
              icon: const Icon(Icons.domain_verification_rounded, color: Color(0xFF38BDF8)),
              tooltip: 'Go to SFE Approval Hub',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SfeInstitutionDashboardScreen()),
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0066FF),
        icon: const Icon(Icons.add_business_rounded, color: Colors.white, size: 20),
        label: const Text('Propose Institution', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const InstitutionApprovalsScreen()),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF0066FF),
        child: Column(
          children: [
            // 1. Search Filter & Sort Bar (Matching HCP Profile Submission UI & Behavior)
            _buildFilterAndSortBar(apiService),

            // 2. Table Column Headers
            _buildTableHeader(filteredList.length, totalCount),

            // 3. Aligned Institution Data Rows
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF0066FF)),
                    )
                  : filteredList.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.only(left: 12, right: 12, top: 6, bottom: 80),
                          itemCount: filteredList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (ctx, idx) {
                            final inst = filteredList[idx];
                            return _buildAlignedInstitutionRow(inst);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. Filter & Sort Bar matching HCP Profile Submission ---
  Widget _buildFilterAndSortBar(ApiService apiService) {
    return Container(
      color: const Color(0xFF0B192C),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: Icon(_showFilters ? Icons.filter_alt_off : Icons.filter_alt, size: 16, color: Colors.white70),
                label: Text(_showFilters ? 'Filter ×' : '= Filter', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
              ),
              const SizedBox(width: 8),
              if (_hasActiveFilters)
                InkWell(
                  onTap: _clearFilters,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.clear_all_rounded, color: Color(0xFFFCA5A5), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Clear Filters',
                          style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFF334155))),
                ),
                icon: Icon(
                  _isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                tooltip: _isAscending ? 'Sort Ascending' : 'Sort Descending',
                onPressed: () {
                  setState(() {
                    _isAscending = !_isAscending;
                  });
                },
              ),
              const SizedBox(width: 8),
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
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                    items: const [
                      DropdownMenuItem(value: 'Last Updated On', child: Text('Last Updated On')),
                      DropdownMenuItem(value: 'Institution Name', child: Text('Institution Name')),
                      DropdownMenuItem(value: 'ID', child: Text('ID')),
                      DropdownMenuItem(value: 'Created On', child: Text('Created On')),
                      DropdownMenuItem(value: 'Status', child: Text('Status')),
                      DropdownMenuItem(value: 'Region', child: Text('Region')),
                      DropdownMenuItem(value: 'Province', child: Text('Province')),
                      DropdownMenuItem(value: 'City/Municipality', child: Text('City/Municipality')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _sortBy = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          if (_showFilters) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 36,
                    child: TextField(
                      controller: _idCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'ID',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 170,
                    height: 36,
                    child: TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Institution Name',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        dropdownColor: const Color(0xFF0F172A),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('Status: All')),
                          DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                          DropdownMenuItem(value: 'Pending Approval', child: Text('Pending Approval')),
                          DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                          DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _statusFilter = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 130,
                    height: 36,
                    child: TextField(
                      controller: _regionCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Region',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 130,
                    height: 36,
                    child: TextField(
                      controller: _provinceCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Province',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 140,
                    height: 36,
                    child: TextField(
                      controller: _cityCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'City/Municipality',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Status Badge matching ERPNext Institution DocType ---
  Widget _buildStatusBadgeWidget(Institution inst) {
    Color statusBg;
    Color statusBorder;
    Color statusColor;

    if (inst.isApproved) {
      statusBg = const Color(0xFFECFDF5);
      statusBorder = const Color(0xFFA7F3D0);
      statusColor = const Color(0xFF059669);
    } else if (inst.isPendingApproval) {
      statusBg = const Color(0xFFFFFBEB);
      statusBorder = const Color(0xFFFDE68A);
      statusColor = const Color(0xFFD97706);
    } else if (inst.isDraft) {
      // Draft masterlist facility in ERPNext is displayed with a red pill
      statusBg = const Color(0xFFFEF2F2);
      statusBorder = const Color(0xFFFECACA);
      statusColor = const Color(0xFFDC2626);
    } else {
      // Rejected
      statusBg = const Color(0xFFFEF2F2);
      statusBorder = const Color(0xFFFECACA);
      statusColor = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusBorder, width: 0.8),
      ),
      child: Text(
        inst.status,
        style: TextStyle(
          color: statusColor,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --- 3. Table Column Header (Matching ERPNext Alignment) ---
  Widget _buildTableHeader(int visibleCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                const Icon(Icons.domain_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 5),
                const Text(
                  'INSTITUTION NAME',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    visibleCount < totalCount ? '$visibleCount of $totalCount' : '$totalCount',
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 75,
            child: Text(
              'STATUS',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(
            width: 85,
            child: Text(
              'ID',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Aligned Institution Row (Compatible with HCP Mobile & ERPNext Alignment) ---
  Widget _buildAlignedInstitutionRow(Institution inst) {
    final name = LocationResolver.resolveInstitutionName(inst.institutionName.isNotEmpty ? inst.institutionName : inst.name);
    final region = inst.regionName ?? inst.rawRegionName ?? '';
    final province = inst.provinceName ?? inst.rawProvinceName ?? '';
    final city = inst.cityMunicipality ?? inst.rawCityMunicipality ?? '';

    return InkWell(
      onTap: () => _showInstitutionDetailsModal(inst),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Institution Name, Status Badge, ID
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hospital Icon
                Container(
                  margin: const EdgeInsets.only(top: 1),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0066FF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF0066FF), size: 16),
                ),
                const SizedBox(width: 8),

                // Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Status Badge
                _buildStatusBadgeWidget(inst),
                const SizedBox(width: 8),

                // ID Chip (Monospaced)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: inst.name));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied ${inst.name} to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      inst.name,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF475569),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Row 2: Location Details Alignment (Region | Province | City/Municipality)
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (city.isNotEmpty)
                    _buildLocationBadge(Icons.location_city_rounded, city),
                  if (province.isNotEmpty)
                    _buildLocationBadge(Icons.location_on_rounded, province),
                  if (region.isNotEmpty)
                    _buildLocationBadge(Icons.map_rounded, region),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No institutions found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try clearing or adjusting your search filters above.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _clearFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.clear_all_rounded, size: 16, color: Colors.white),
                label: const Text('Reset All Filters', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Modal: Institution Detailed Breakdown ---
  void _showInstitutionDetailsModal(Institution inst) {
    final name = LocationResolver.resolveInstitutionName(inst.institutionName.isNotEmpty ? inst.institutionName : inst.name);
    final fullAddress = LocationResolver.formatLocation(
      streetAddress: inst.streetAddress,
      cityMunicipality: inst.cityMunicipality ?? inst.rawCityMunicipality,
      provinceName: inst.provinceName ?? inst.rawProvinceName,
      regionName: inst.regionName ?? inst.rawRegionName,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF0066FF).withOpacity(0.12),
                    child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF0066FF), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                inst.name,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadgeWidget(inst),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Rejection Reason (if rejected)
              if (inst.isRejected && (inst.rejectionReason ?? '').isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SFE Rejection Remarks:', style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(inst.rejectionReason!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Address Breakdown
              _buildDetailRow(Icons.place_rounded, 'Full Address', fullAddress.isEmpty ? 'Address pending verification' : fullAddress),
              _buildDetailRow(Icons.map_rounded, 'Region', inst.regionName ?? inst.rawRegionName ?? 'N/A'),
              _buildDetailRow(Icons.location_on_rounded, 'Province', inst.provinceName ?? inst.rawProvinceName ?? 'N/A'),
              _buildDetailRow(Icons.location_city_rounded, 'City / Municipality', inst.cityMunicipality ?? inst.rawCityMunicipality ?? 'N/A'),
              if ((inst.barangayName ?? '').isNotEmpty)
                _buildDetailRow(Icons.navigation_rounded, 'Barangay', inst.barangayName!),
              if ((inst.streetAddress ?? '').isNotEmpty)
                _buildDetailRow(Icons.signpost_rounded, 'Street', inst.streetAddress!),

              if ((inst.creation ?? '').isNotEmpty)
                _buildDetailRow(Icons.calendar_today_rounded, 'Created On', inst.creation!),
              if ((inst.modified ?? '').isNotEmpty)
                _buildDetailRow(Icons.update_rounded, 'Last Modified', inst.modified!),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
