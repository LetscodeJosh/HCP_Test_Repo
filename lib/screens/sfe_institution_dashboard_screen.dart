import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lookup_models.dart';
import '../services/api_service.dart';
import 'components/app_drawer.dart';
import 'components/institution_audit_trail_dialog.dart';
import 'components/propose_institution_dialog.dart';
import 'components/remap_institution_dialog.dart';
import '../services/notification_service.dart';

class SfeInstitutionDashboardScreen extends StatefulWidget {
  const SfeInstitutionDashboardScreen({Key? key}) : super(key: key);

  @override
  State<SfeInstitutionDashboardScreen> createState() => _SfeInstitutionDashboardScreenState();
}

class _SfeInstitutionDashboardScreenState extends State<SfeInstitutionDashboardScreen> {
  bool _isLoading = true;
  String _selectedFilter = 'Pending Approval'; // 'Pending Approval', 'Approved', 'Rejected', 'All'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Institution> _allInstitutions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final list = await apiService.fetchInstitutions();
      if (mounted) {
        setState(() {
          _allInstitutions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Institution> get _filteredInstitutions {
    return _allInstitutions.where((inst) {
      // 1. Status Filter
      if (_selectedFilter == 'Pending Approval') {
        if (!inst.isPendingApproval) return false;
      } else if (_selectedFilter == 'Approved') {
        if (!inst.isApproved) return false;
      } else if (_selectedFilter == 'Rejected') {
        if (!inst.isRejected) return false;
      }

      // 2. Search Query Filter
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      final name = inst.institutionName.toLowerCase();
      final id = inst.name.toLowerCase();
      final city = (inst.cityMunicipality ?? '').toLowerCase();
      final prov = (inst.provinceName ?? '').toLowerCase();
      final owner = (inst.owner ?? '').toLowerCase();
      return name.contains(q) || id.contains(q) || city.contains(q) || prov.contains(q) || owner.contains(q);
    }).toList();
  }

  int get _pendingCount => _allInstitutions.where((i) => i.isPendingApproval).length;
  int get _approvedCount => _allInstitutions.where((i) => i.isApproved).length;
  int get _rejectedCount => _allInstitutions.where((i) => i.isRejected).length;
  int get _totalCount => _allInstitutions.length;

  Future<void> _handleApprove(Institution inst) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 26),
            SizedBox(width: 10),
            Text('Approve Institution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to approve this new facility?',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inst.institutionName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (inst.cityMunicipality != null && inst.cityMunicipality!.isNotEmpty) inst.cityMunicipality!,
                      if (inst.provinceName != null && inst.provinceName!.isNotEmpty) inst.provinceName!,
                      if (inst.regionName != null && inst.regionName!.isNotEmpty) inst.regionName!,
                    ].join(', '),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  if (inst.name.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Record ID: ${inst.name}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              inst.requiresDsmApproval
                  ? 'This facility is part of a combined Doctor + Workplace proposal. Approving will validate the facility and advance the request to DSM Approval.'
                  : 'This will submit the document to the national masterlist and make it active for all MedReps.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Approve Facility'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Processing SFE approval...'), duration: Duration(seconds: 1)),
    );

    final success = await apiService.approveInstitution(inst.name);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  inst.requiresDsmApproval
                      ? '${inst.institutionName} approved by SFE! Advanced to DSM Final Approval.'
                      : '${inst.institutionName} approved and merged into masterlist!',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve "${inst.institutionName}". Please check SFE permissions or server state.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRemap(Institution inst) async {
    final changed = await RemapInstitutionDialog.show(context, inst);
    if (changed == true) {
      _loadData();
    }
  }

  Future<void> _handleReject(Institution inst) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 26),
            SizedBox(width: 10),
            Text('Reject Institution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rejecting: "${inst.institutionName}"',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please specify the reason for rejection so the MedRep can modify and resubmit:',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g., Facility already exists under name "...", or invalid address details.',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Rejection reason is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final reason = reasonController.text.trim();

    final apiService = Provider.of<ApiService>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Processing SFE rejection...'), duration: Duration(seconds: 1)),
    );

    final success = await apiService.rejectInstitution(inst.name, reason);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${inst.institutionName} marked as Rejected.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process rejection for "${inst.institutionName}". Please check SFE permissions or server state.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleNormalize(Institution inst) async {
    final nameCtrl = TextEditingController(text: inst.institutionName);
    String? selectedRegion = inst.regionName;
    String? selectedProvince = inst.provinceName;
    String? selectedCity = inst.cityMunicipality;
    String? selectedOwnership = inst.ownership ?? 'Private';
    String? selectedType = inst.institutionType ?? 'Hospital';
    String? selectedCapability = inst.serviceCapability;
    bool autoApprove = true;
    String? validationErr;
    bool isSaving = false;

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0B192C),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0066FF).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tune_rounded, color: Color(0xFF60A5FA), size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Normalize Facility Information',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                            onPressed: isSaving ? null : () => Navigator.pop(dialogCtx, false),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (validationErr != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(validationErr!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          const Text('Official Institution Name *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            inputFormatters: [
                              TitleCaseTextInputFormatter(),
                            ],
                            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Standard facility name...',
                              prefixIcon: const Icon(Icons.business_outlined, color: Color(0xFF0066FF), size: 18),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Region
                          const Text('Region', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final picked = await _showRegionPicker(context, selectedRegion);
                              if (picked != null) {
                                setDlgState(() {
                                  selectedRegion = picked;
                                  selectedProvince = null;
                                  selectedCity = null;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.public, color: Color(0xFF0066FF), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      (selectedRegion != null && selectedRegion!.isNotEmpty) ? selectedRegion! : 'Select Region...',
                                      style: TextStyle(
                                        color: (selectedRegion != null && selectedRegion!.isNotEmpty) ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Province
                          const Text('Province *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final picked = await _showProvincePicker(context, selectedProvince, regionFilter: selectedRegion);
                              if (picked != null) {
                                setDlgState(() {
                                  selectedProvince = picked;
                                  selectedCity = null;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.map_outlined, color: Color(0xFF0066FF), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      (selectedProvince != null && selectedProvince!.isNotEmpty) ? selectedProvince! : 'Select Province...',
                                      style: TextStyle(
                                        color: (selectedProvince != null && selectedProvince!.isNotEmpty) ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // City
                          const Text('City / Municipality *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final picked = await _showCityPicker(context, selectedCity, provinceFilter: selectedProvince);
                              if (picked != null) {
                                setDlgState(() => selectedCity = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_city_outlined, color: Color(0xFF0066FF), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      (selectedCity != null && selectedCity!.isNotEmpty) ? selectedCity! : 'Select City...',
                                      style: TextStyle(
                                        color: (selectedCity != null && selectedCity!.isNotEmpty) ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Ownership and Type row
                          // Ownership and Type row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Ownership', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    DropdownButtonFormField<String>(
                                      value: selectedOwnership,
                                      isDense: true,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      items: InstitutionClassification.ownershipOptions.map((opt) {
                                        return DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 12.5)));
                                      }).toList(),
                                      onChanged: (val) => setDlgState(() => selectedOwnership = val),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Facility Type', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    DropdownButtonFormField<String>(
                                      value: (selectedType == 'Clinic' || selectedType == 'Hospital') ? selectedType : 'Hospital',
                                      isDense: true,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      items: InstitutionClassification.typeOptions.map((opt) {
                                        return DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 12.5)));
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDlgState(() {
                                            selectedType = val;
                                            final caps = InstitutionClassification.getCapabilitiesForType(val);
                                            selectedCapability = caps.isNotEmpty ? caps.first : null;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Dynamic Service Capability Dropdown
                          Builder(
                            builder: (context) {
                              final caps = InstitutionClassification.getCapabilitiesForType(selectedType ?? 'Hospital');
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedType == 'Hospital'
                                        ? 'Service Capability (Hospital - 3 Levels) *'
                                        : 'Service Capability (Clinic - 5 Types) *',
                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    value: caps.contains(selectedCapability) ? selectedCapability : (caps.isNotEmpty ? caps.first : null),
                                    isDense: true,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    items: caps.map((opt) {
                                      return DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 12.5)));
                                    }).toList(),
                                    onChanged: (val) => setDlgState(() => selectedCapability = val),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),

                          // Auto-Approve switch
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Auto-Approve after Normalizing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                                      Text(
                                        inst.requiresDsmApproval
                                            ? 'Advances directly to DSM Final Approval (Doctor + Workplace)'
                                            : 'Immediately marks normalized facility as Approved in the masterlist',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: autoApprove,
                                  activeColor: const Color(0xFF10B981),
                                  onChanged: (val) => setDlgState(() => autoApprove = val),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
                            onPressed: isSaving ? null : () => Navigator.pop(dialogCtx, false),
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: autoApprove ? const Color(0xFF10B981) : const Color(0xFF0066FF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final wp = nameCtrl.text.trim();
                                    final prov = selectedProvince?.trim() ?? '';
                                    final city = selectedCity?.trim() ?? '';
                                    final reg = selectedRegion?.trim() ?? '';

                                    if (wp.isEmpty) {
                                      setDlgState(() => validationErr = 'Workplace name is required');
                                      return;
                                    }
                                    if (prov.isEmpty) {
                                      setDlgState(() => validationErr = 'Province is required');
                                      return;
                                    }
                                    if (city.isEmpty) {
                                      setDlgState(() => validationErr = 'City is required');
                                      return;
                                    }

                                    setDlgState(() {
                                      isSaving = true;
                                      validationErr = null;
                                    });

                                    try {
                                      final api = Provider.of<ApiService>(context, listen: false);
                                      await api.normalizeInstitution(
                                        name: inst.name,
                                        workplaceName: wp,
                                        region: reg.isNotEmpty ? reg : null,
                                        province: prov,
                                        city: city,
                                        ownership: selectedOwnership,
                                        institutionType: selectedType,
                                        serviceCapability: selectedCapability,
                                        autoApprove: autoApprove,
                                      );
                                      Navigator.pop(dialogCtx, true);
                                    } catch (err) {
                                      setDlgState(() {
                                        isSaving = false;
                                        validationErr = 'Failed to normalize: $err';
                                      });
                                    }
                                  },
                            child: isSaving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    autoApprove ? 'Save & Approve' : 'Save Changes',
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
        },
      ),
    );

    if (updated == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Facility normalized successfully!')),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    }
  }

  Future<String?> _showRegionPicker(BuildContext context, String? current) async {
    final searchCtrl = TextEditingController();
    final allRegions = LocationResolver.standardRegions.map((r) => r.name).toList();
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
    List<String> allProvinces = LocationResolver.standardProvinces.map((p) => p.name).toList();
    if (regionFilter != null && regionFilter.isNotEmpty) {
      final regId = LocationResolver.resolveRegionId(regionFilter);
      if (regId.length >= 2) {
        final prefix = regId.substring(0, 2);
        final inRegion = LocationResolver.standardProvinces.where((p) => p.code.startsWith(prefix)).map((p) => p.name).toList();
        final others = LocationResolver.standardProvinces.where((p) => !p.code.startsWith(prefix)).map((p) => p.name).toList();
        allProvinces = [...inRegion, ...others];
      }
    }
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) {
          final q = searchCtrl.text.toLowerCase().trim();
          final filtered = q.isEmpty ? allProvinces : allProvinces.where((p) => p.toLowerCase().contains(q)).toList();
          return AlertDialog(
            title: const Text('Select Province', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
    final allCities = LocationResolver.standardCities.map((c) => c.name).toSet().toList();
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) {
          final q = searchCtrl.text.toLowerCase().trim();
          final filtered = q.isEmpty ? allCities : allCities.where((c) => c.toLowerCase().contains(q)).toList();
          return AlertDialog(
            title: Text(
              provinceFilter != null ? 'Select City ($provinceFilter)' : 'Select City / Municipality',
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
                      hintText: 'Search city/municipality...',
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

  Future<void> _openCreateInstitutionDialog(BuildContext context) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final allDirectoryInstitutions = apiService.cachedInstitutions.isNotEmpty
        ? apiService.cachedInstitutions
        : _allInstitutions;

    final workplaceCtrl = TextEditingController();
    String? selectedRegion;
    String? selectedProvince;
    String? selectedCity;
    bool isSaving = false;
    String? validationErr;
    List<InstitutionSearchResult> detectedMatches = [];
    bool showDropdown = false;
    InstitutionSearchResult? duplicateAlert;

    Future<void> submitInstitution({
      required BuildContext dialogCtx,
      required void Function(void Function()) setDlgState,
      required bool autoApprove,
    }) async {
      final wp = workplaceCtrl.text.trim();
      final reg = (selectedRegion ?? '').trim();
      final prov = (selectedProvince ?? '').trim();
      final cty = (selectedCity ?? '').trim();

      if (wp.isEmpty) {
        setDlgState(() => validationErr = 'Workplace / Institution Name is required');
        return;
      }

      final exactApproved = allDirectoryInstitutions.firstWhere(
        (i) => i.isApproved &&
            (i.institutionName.trim().toLowerCase() == wp.toLowerCase() ||
                i.name.trim().toLowerCase() == wp.toLowerCase()),
        orElse: () => Institution(name: '', institutionName: ''),
      );
      if (exactApproved.name.isNotEmpty) {
        setDlgState(() => validationErr = 'Facility "${exactApproved.institutionName}" is already approved and available in the directory.');
        return;
      }

      if (prov.isEmpty) {
        setDlgState(() => validationErr = 'Province is required');
        return;
      }
      if (cty.isEmpty) {
        setDlgState(() => validationErr = 'City is required');
        return;
      }

      setDlgState(() {
        isSaving = true;
        validationErr = null;
      });

      try {
        final api = Provider.of<ApiService>(context, listen: false);
        final res = await api.createInstitutionRequest(
          workplaceName: wp,
          region: reg.isNotEmpty ? reg : null,
          city: cty,
          province: prov,
        );

        if (autoApprove && res.name.isNotEmpty) {
          await api.approveInstitution(res.name);
        }

        Navigator.pop(dialogCtx, {
          'institution': res,
          'approved': autoApprove,
        });
      } catch (err) {
        setDlgState(() {
          isSaving = false;
          validationErr = 'Failed to submit: $err';
        });
      }
    }

    Timer? sfeDebounce;
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0B192C),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.add_business_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Add / Propose New Institution',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF1D4ED8), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'As an SFE Specialist / Admin, you can propose a new institution for review, or directly submit & approve it immediately into the universal masterlist.',
                              style: TextStyle(color: Color(0xFF1E40AF), fontSize: 11.5, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (validationErr != null) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                              child: Text(validationErr!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11.5)),
                            ),
                            const SizedBox(height: 10),
                          ],
                          const Text('Workplace / Institution Name *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: workplaceCtrl,
                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                            onChanged: (val) {
                              sfeDebounce?.cancel();
                              final text = val.trim();
                              if (text.length >= 2) {
                                sfeDebounce = Timer(const Duration(milliseconds: 200), () {
                                  final matches = LocationResolver.searchDirectoryWithDuplicateDetection(
                                    text,
                                    allDirectoryInstitutions,
                                    limit: 6,
                                  );
                                  InstitutionSearchResult? dup;
                                  for (var m in matches) {
                                    if (m.isExactOrHighConfidenceDuplicate) {
                                      dup = m;
                                      break;
                                    }
                                  }
                                  setDlgState(() {
                                    detectedMatches = matches;
                                    showDropdown = matches.isNotEmpty;
                                    duplicateAlert = dup;
                                    validationErr = null;
                                  });
                                });
                              } else {
                                setDlgState(() {
                                  detectedMatches = [];
                                  showDropdown = false;
                                  duplicateAlert = null;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'e.g. St. Luke\'s Medical Center - BGC',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                              prefixIcon: const Icon(Icons.local_hospital_outlined, color: Color(0xFF0066FF), size: 18),
                              suffixIcon: workplaceCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                      onPressed: () {
                                        workplaceCtrl.clear();
                                        setDlgState(() {
                                          detectedMatches = [];
                                          showDropdown = false;
                                          duplicateAlert = null;
                                        });
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5)),
                            ),
                          ),
                          if (duplicateAlert != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFF59E0B)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(color: Color(0xFF78350F), fontSize: 11),
                                        children: [
                                          const TextSpan(text: 'Duplicate Detected: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                                          TextSpan(text: '"${duplicateAlert!.institution.institutionName}"'),
                                          if (duplicateAlert!.formattedLocation.isNotEmpty)
                                            TextSpan(text: ' in ${duplicateAlert!.formattedLocation}'),
                                          const TextSpan(text: ' already exists in the directory. Tap below to use it instead.'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (showDropdown && detectedMatches.isNotEmpty) ...[
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
                                          'Directory Facilities (Tap to Auto-fill):',
                                          style: TextStyle(color: Color(0xFF1E40AF), fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        const Spacer(),
                                        InkWell(
                                          onTap: () => setDlgState(() => showDropdown = false),
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
                                      itemCount: detectedMatches.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      itemBuilder: (ctx, idx) {
                                        final item = detectedMatches[idx];
                                        final inst = item.institution;
                                        final isApproved = inst.isApproved;

                                        return InkWell(
                                          onTap: () {
                                            setDlgState(() {
                                              workplaceCtrl.text = inst.institutionName.isNotEmpty ? inst.institutionName : inst.name;
                                              if (inst.regionName != null && inst.regionName!.isNotEmpty) selectedRegion = inst.regionName;
                                              if (inst.provinceName != null && inst.provinceName!.isNotEmpty) selectedProvince = inst.provinceName;
                                              if (inst.cityMunicipality != null && inst.cityMunicipality!.isNotEmpty) selectedCity = inst.cityMunicipality;
                                              showDropdown = false;
                                              duplicateAlert = null;
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Selected "${inst.institutionName}". Already available in directory!'),
                                                duration: const Duration(seconds: 3),
                                                backgroundColor: const Color(0xFF0066FF),
                                              ),
                                            );
                                          },
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
                          ] else if (workplaceCtrl.text.trim().length >= 3 && detectedMatches.isEmpty) ...[
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
                                      '✓ No duplicate found in directory. New institution will be created.',
                                      style: TextStyle(color: Color(0xFF166534), fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),

                          const Text('Region *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final picked = await _showRegionPicker(context, selectedRegion);
                              if (picked != null) {
                                setDlgState(() {
                                  selectedRegion = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.public_outlined, color: Color(0xFF0066FF), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      (selectedRegion != null && selectedRegion!.isNotEmpty) ? selectedRegion! : 'Select Region (or choose Province below)',
                                      style: TextStyle(
                                        color: (selectedRegion != null && selectedRegion!.isNotEmpty) ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text('Province *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final picked = await _showProvincePicker(context, selectedProvince, regionFilter: selectedRegion);
                              if (picked != null) {
                                setDlgState(() {
                                  selectedProvince = picked;
                                  selectedCity = null;
                                  final autoReg = LocationResolver.resolveRegionFromProvince(picked);
                                  if (autoReg.isNotEmpty) {
                                    selectedRegion = autoReg;
                                  }
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.map_outlined, color: Color(0xFF0066FF), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      (selectedProvince != null && selectedProvince!.isNotEmpty) ? selectedProvince! : 'Select Province...',
                                      style: TextStyle(
                                        color: (selectedProvince != null && selectedProvince!.isNotEmpty) ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text('City / Municipality *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final picked = await _showCityPicker(context, selectedCity, provinceFilter: selectedProvince);
                              if (picked != null) {
                                setDlgState(() => selectedCity = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_city_outlined, color: Color(0xFF0066FF), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      (selectedCity != null && selectedCity!.isNotEmpty) ? selectedCity! : 'Select City...',
                                      style: TextStyle(
                                        color: (selectedCity != null && selectedCity!.isNotEmpty) ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          // Option 1: Propose as Pending Approval
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0066FF),
                              side: const BorderSide(color: Color(0xFF93C5FD)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onPressed: isSaving
                                ? null
                                : () => submitInstitution(
                                      dialogCtx: dialogCtx,
                                      setDlgState: setDlgState,
                                      autoApprove: false,
                                    ),
                            child: const Text('Submit for Approval', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          // Option 2: SFE Direct Add & Approve
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            onPressed: isSaving
                                ? null
                                : () => submitInstitution(
                                      dialogCtx: dialogCtx,
                                      setDlgState: setDlgState,
                                      autoApprove: true,
                                    ),
                            child: isSaving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                                      SizedBox(width: 6),
                                      Text('Submit & Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
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
        },
      ),
    );

    if (created != null) {
      if (!mounted) return;
      final bool wasApproved = created['approved'] == true;
      final Institution inst = created['institution'] as Institution;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  wasApproved
                      ? 'Institution "${inst.institutionName}" created and approved into masterlist!'
                      : 'Institution "${inst.institutionName}" proposed and submitted for review.',
                ),
              ),
            ],
          ),
          backgroundColor: wasApproved ? const Color(0xFF059669) : const Color(0xFF0066FF),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(currentItem: DrawerItem.dashboard),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B192C),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.domain_verification_rounded, color: Color(0xFF38BDF8), size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Institution Submission',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Sales Force Effectiveness Hub',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (apiService.sfeModeOverride)
            TextButton.icon(
              onPressed: () => apiService.toggleSfeMode(),
              icon: const Icon(Icons.exit_to_app, color: Color(0xFFFCD34D), size: 16),
              label: const Text('Exit SFE Preview', style: TextStyle(color: Color(0xFFFCD34D), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined, color: Color(0xFFFBBF24)),
            tooltip: 'Simulate Lockscreen Rejection Alert',
            onPressed: () async {
              await NotificationService.simulateRejectionNotification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Simulated rejection pop-up alert dispatched to lockscreen/homescreen!'),
                    backgroundColor: Color(0xFFD97706),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_business_rounded, color: Colors.white),
            tooltip: 'Add / Propose New Institution',
            onPressed: () => _openCreateInstitutionDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF0066FF),
        child: Column(
          children: [
            // KPI Overview Section
            _buildKpiSection(),

            // Search and Status Filter Tabs
            _buildSearchAndFilters(),

            // List of Institutions
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF0066FF)),
                    )
                  : _filteredInstitutions.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _filteredInstitutions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, idx) {
                            final inst = _filteredInstitutions[idx];
                            return _buildInstitutionCard(inst);
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateInstitutionDialog(context),
        backgroundColor: const Color(0xFF0066FF),
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: const Text(
          '+ Propose Institution',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildKpiSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0B192C),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildKpiCard(
              title: 'Pending',
              count: _pendingCount,
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFFF59E0B),
              isSelected: _selectedFilter == 'Pending Approval',
              onTap: () => setState(() => _selectedFilter = 'Pending Approval'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildKpiCard(
              title: 'Approved',
              count: _approvedCount,
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF10B981),
              isSelected: _selectedFilter == 'Approved',
              onTap: () => setState(() => _selectedFilter = 'Approved'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildKpiCard(
              title: 'Rejected',
              count: _rejectedCount,
              icon: Icons.cancel_rounded,
              color: const Color(0xFFEF4444),
              isSelected: _selectedFilter == 'Rejected',
              onTap: () => setState(() => _selectedFilter = 'Rejected'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildKpiCard(
              title: 'Total',
              count: _totalCount,
              icon: Icons.domain_rounded,
              color: const Color(0xFF38BDF8),
              isSelected: _selectedFilter == 'All',
              onTap: () => setState(() => _selectedFilter = 'All'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF334155),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by facility, province, city, ID, or MedRep...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Pending Approval', 'Pending Review ($_pendingCount)', const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                _buildFilterChip('Approved', 'Approved ($_approvedCount)', const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _buildFilterChip('Rejected', 'Rejected ($_rejectedCount)', const Color(0xFFEF4444)),
                const SizedBox(width: 8),
                _buildFilterChip('All', 'All Institutions ($_totalCount)', const Color(0xFF0066FF)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, Color accentColor) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentColor : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInstitutionCard(Institution inst) {
    final state = (inst.workflowState ?? '').trim();
    final isPending = state == 'Pending Approval' || state == 'Pending SFE Approval' || inst.isCustom;
    final isApproved = state == 'Approved' || inst.docstatus == 1;
    final isRejected = state == 'Rejected';

    Color statusColor = const Color(0xFF64748B);
    String statusText = state.isNotEmpty ? state : 'Master Active';
    IconData statusIcon = Icons.info_outline;

    if (isPending) {
      statusColor = const Color(0xFFF59E0B);
      statusText = 'Pending Approval';
      statusIcon = Icons.hourglass_top_rounded;
    } else if (isApproved) {
      statusColor = const Color(0xFF10B981);
      statusText = 'Approved';
      statusIcon = Icons.check_circle_rounded;
    } else if (isRejected) {
      statusColor = const Color(0xFFEF4444);
      statusText = 'Rejected';
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isPending ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
          width: isPending ? 1.2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_hospital_rounded, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inst.institutionName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (inst.name.isNotEmpty)
                      Text(
                        inst.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                  ],
                ),
              ),
              if (inst.isResubmission)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF93C5FD)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.replay_rounded, size: 12, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text('Resubmission', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.4), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => InstitutionAuditTrailDialog.show(context, inst),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.history_edu_rounded, size: 13, color: Color(0xFF0B192C)),
                      SizedBox(width: 4),
                      Text('Audit', style: TextStyle(color: Color(0xFF0B192C), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Location details
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [
                    if (inst.cityMunicipality != null && inst.cityMunicipality!.isNotEmpty) inst.cityMunicipality!,
                    if (inst.provinceName != null && inst.provinceName!.isNotEmpty) inst.provinceName!,
                    if (inst.regionName != null && inst.regionName!.isNotEmpty) inst.regionName!,
                  ].isNotEmpty
                      ? [
                          if (inst.cityMunicipality != null && inst.cityMunicipality!.isNotEmpty) inst.cityMunicipality!,
                          if (inst.provinceName != null && inst.provinceName!.isNotEmpty) inst.provinceName!,
                          if (inst.regionName != null && inst.regionName!.isNotEmpty) inst.regionName!,
                        ].join(', ')
                      : 'Location unassigned',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),

          // Submitter details if present
          if (inst.owner != null && inst.owner!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Submitted by: ${inst.owner!}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (inst.creation != null && inst.creation!.isNotEmpty)
                  Text(
                    inst.creation!.split(' ').first,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ],

          // Facility Classification pills
          if ((inst.ownership != null && inst.ownership!.isNotEmpty) ||
              (inst.institutionType != null && inst.institutionType!.isNotEmpty)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (inst.ownership != null && inst.ownership!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      inst.ownership!,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ),
                if (inst.institutionType != null && inst.institutionType!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      inst.institutionType!,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                    ),
                  ),
                if (inst.serviceCapability != null && inst.serviceCapability!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Text(
                      inst.serviceCapability!,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                    ),
                  ),
              ],
            ),
          ],

          // Linked Doctor indicator if facility proposed alongside a doctor
          if (inst.linkedDoctorName != null && inst.linkedDoctorName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE9D5FF)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_pin_circle_outlined, size: 14, color: Color(0xFF7E22CE)),
                  const SizedBox(width: 5),
                  Text(
                    'Linked Doctor: ${inst.linkedDoctorName!}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE)),
                  ),
                  if (inst.requiresDsmApproval) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF2F8),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFBCFE8)),
                      ),
                      child: const Text('Routes to DSM', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFBE185D))),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Rejection reason banner if rejected
          if (isRejected && inst.rejectionReason != null && inst.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SFE Rejection Reason:',
                          style: TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          inst.rejectionReason!,
                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action Buttons for SFE
          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _handleReject(inst),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0066FF),
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _handleNormalize(inst),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Normalize', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _handleApprove(inst),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ] else if (isRejected) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _handleRemap(inst),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('Change / Remap for MedRep', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0066FF),
                      side: const BorderSide(color: Color(0xFF93C5FD), width: 1.2),
                      backgroundColor: const Color(0xFFEFF6FF),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _handleNormalize(inst),
                    icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF0066FF)),
                    label: const Text('Normalize Master Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0066FF))),
                  ),
                ),
              ],
            ),
          ] else if (isApproved) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _handleNormalize(inst),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit / Normalize Master Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.domain_verification_rounded, size: 48, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'Pending Approval'
                  ? 'No Pending Approvals'
                  : 'No Institutions Found',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedFilter == 'Pending Approval'
                  ? 'All newly added institutions have been reviewed by SFE.'
                  : 'Try adjusting your search query or status filter.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
              ),
              onPressed: () => _openCreateInstitutionDialog(context),
              icon: const Icon(Icons.add_business_rounded, size: 18),
              label: const Text('Add / Propose Institution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
