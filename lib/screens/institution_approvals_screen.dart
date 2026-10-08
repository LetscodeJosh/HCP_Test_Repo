import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lookup_models.dart';
import '../services/api_service.dart';
import 'components/app_drawer.dart';
import 'components/institution_audit_trail_dialog.dart';
import 'components/propose_institution_dialog.dart';
import 'components/remap_institution_dialog.dart';
import 'sfe_institution_dashboard_screen.dart';

class InstitutionApprovalsScreen extends StatefulWidget {
  const InstitutionApprovalsScreen({Key? key}) : super(key: key);

  @override
  State<InstitutionApprovalsScreen> createState() => _InstitutionApprovalsScreenState();
}

class _InstitutionApprovalsScreenState extends State<InstitutionApprovalsScreen> {
  bool _isLoading = true;
  String _selectedFilter = 'All'; // 'All', 'Pending Approval', 'Pending DSM Approval', 'Approved', 'Rejected'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final api = Provider.of<ApiService>(context, listen: false);
        if (api.cachedInstitutions.any((i) => i.isCooldownActive)) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _searchController.dispose();
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

  List<Institution> _getFilteredInstitutions(List<Institution> source) {
    return source.where((inst) {
      // 1. Status Tab Filter
      if (_selectedFilter == 'Pending Approval') {
        if (!inst.isPendingApproval && inst.workflowState != 'Pending Approval') return false;
      } else if (_selectedFilter == 'Pending DSM Approval') {
        if (inst.workflowState != 'Pending DSM Approval') return false;
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
      return name.contains(q) || id.contains(q) || city.contains(q) || prov.contains(q);
    }).toList();
  }

  Future<void> _openEditAndResubmitDialog(Institution inst) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final currentUser = apiService.loggedInFullName ?? apiService.loggedInEmail ?? 'User';

    if (inst.isCooldownActive &&
        inst.editingUser != null &&
        inst.editingUser != currentUser &&
        inst.editingUser != apiService.loggedInEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Facility is currently being edited by ${inst.editingUser} (${inst.cooldownRemainingSeconds}s remaining). Please wait to prevent concurrent conflict.'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (inst.resubmissionCount >= 2) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.report_problem_rounded, color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 8),
              Text('Resubmission Limit Reached', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Facility "${inst.institutionName}" has reached the maximum allowed resubmissions (2/2).',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.phone_in_talk_rounded, color: Color(0xFFDC2626), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Recommendation: Please call or contact your SFE Specialist directly to review and normalize this facility in the database.',
                        style: TextStyle(color: Color(0xFF991B1B), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final workplaceCtrl = TextEditingController(text: inst.institutionName);
    final resolvedReg = LocationResolver.resolveRegionName(inst.regionName ?? inst.rawRegionName);
    final resolvedProv = LocationResolver.resolveProvinceName(inst.provinceName ?? inst.rawProvinceName);
    final resolvedCity = LocationResolver.resolveCityName(inst.cityMunicipality ?? inst.rawCityMunicipality);
    String? selectedRegion = resolvedReg.isNotEmpty ? resolvedReg : null;
    String? selectedProvince = resolvedProv.isNotEmpty ? resolvedProv : null;
    String? selectedCity = resolvedCity.isNotEmpty ? resolvedCity : null;
    if (selectedRegion == null && selectedProvince != null) {
      final auto = LocationResolver.resolveRegionFromProvince(selectedProvince);
      if (auto.isNotEmpty) selectedRegion = auto;
    }
    String? selectedOwnership = inst.ownership ?? 'Private';
    String? selectedType = (inst.institutionType == 'Clinic' || inst.institutionType == 'Hospital')
        ? inst.institutionType
        : 'Hospital';
    String? selectedCapability = inst.serviceCapability ??
        (selectedType == 'Hospital'
            ? InstitutionClassification.hospitalCapabilities.first
            : InstitutionClassification.clinicCapabilities.first);
    bool isSaving = false;
    String? validationErr;

    // Immediately trigger 60s cooldown lock when Edit icon is pressed
    apiService.startEditingCooldown(inst.name, user: currentUser);

    Timer? debounceTimer;
    List<InstitutionSearchResult> detectedMatches = [];
    Institution? selectedExistingInstitution;
    final allDirectory = apiService.cachedInstitutions;

    final updated = await showDialog<Institution>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final capabilities = InstitutionClassification.getCapabilitiesForType(selectedType ?? 'Hospital');

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
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
                          const Icon(Icons.edit_location_alt_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            inst.isRejected ? 'Modify & Resubmit Facility (${inst.resubmissionCount + 1}/2)' : 'Edit Facility Request',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                    ),

                    if (inst.isRejected && inst.rejectionReason != null && inst.rejectionReason!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 16),
                                SizedBox(width: 6),
                                Text('SFE Rejection Reason:', style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              inst.rejectionReason!,
                              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Please correct the workplace name or address below and tap "Submit for Approval" to resubmit to SFE.',
                              style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 11, fontStyle: FontStyle.italic),
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

                          // Classification (Ownership, Type, Capability)
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
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Ownership *', style: TextStyle(color: Color(0xFF475569), fontSize: 11.5, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          DropdownButtonFormField<String>(
                                            value: selectedOwnership,
                                            isDense: true,
                                            decoration: InputDecoration(
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              filled: true,
                                              fillColor: Colors.white,
                                            ),
                                            items: InstitutionClassification.ownershipOptions.map((o) {
                                              return DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 12.5)));
                                            }).toList(),
                                            onChanged: (val) => setDlgState(() => selectedOwnership = val),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Institution Type *', style: TextStyle(color: Color(0xFF475569), fontSize: 11.5, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          DropdownButtonFormField<String>(
                                            value: selectedType,
                                            isDense: true,
                                            decoration: InputDecoration(
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              filled: true,
                                              fillColor: Colors.white,
                                            ),
                                            items: InstitutionClassification.institutionTypeOptions.map((t) {
                                              return DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5)));
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
                                const SizedBox(height: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedType == 'Hospital'
                                          ? 'Service Capability (Hospital - 3 Levels) *'
                                          : 'Service Capability (Clinic - 5 Types) *',
                                      style: const TextStyle(color: Color(0xFF475569), fontSize: 11.5, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    DropdownButtonFormField<String>(
                                      value: capabilities.contains(selectedCapability) ? selectedCapability : (capabilities.isNotEmpty ? capabilities.first : null),
                                      isDense: true,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      items: capabilities.map((c) {
                                        return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12.5)));
                                      }).toList(),
                                      onChanged: (val) => setDlgState(() => selectedCapability = val),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text('Workplace Name *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: workplaceCtrl,
                            textCapitalization: TextCapitalization.words,
                            inputFormatters: [
                              TitleCaseTextInputFormatter(),
                            ],
                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                            onChanged: (val) {
                              debounceTimer?.cancel();
                              debounceTimer = Timer(const Duration(milliseconds: 300), () {
                                final query = val.trim();
                                if (query.length >= 2) {
                                  final matches = LocationResolver.searchDirectoryWithDuplicateDetection(
                                    query,
                                    allDirectory,
                                    limit: 50,
                                  );
                                  setDlgState(() {
                                    detectedMatches = matches;
                                    if (selectedExistingInstitution != null &&
                                        selectedExistingInstitution!.institutionName.trim().toLowerCase() != query.toLowerCase()) {
                                      selectedExistingInstitution = null;
                                    }
                                  });
                                } else {
                                  setDlgState(() {
                                    detectedMatches = [];
                                    selectedExistingInstitution = null;
                                  });
                                }
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Hospital / Clinic / Center Name',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                              prefixIcon: const Icon(Icons.local_hospital_outlined, color: Color(0xFF0B192C), size: 18),
                              suffixIcon: workplaceCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                                      onPressed: () {
                                        workplaceCtrl.clear();
                                        setDlgState(() {
                                          detectedMatches = [];
                                          selectedExistingInstitution = null;
                                        });
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                          ),

                          // SMART DETECTOR SUGGESTIONS BANNER & DROPDOWN LIST
                          if (detectedMatches.isNotEmpty && selectedExistingInstitution == null) ...[
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
                                  const Icon(Icons.psychology_outlined, color: Color(0xFF16A34A), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Smart Detector: Found ${detectedMatches.length} Matching Facilit${detectedMatches.length > 1 ? 'ies' : 'y'}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534), fontSize: 11.5),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Found ${detectedMatches.length} existing facilities matching this name or acronym. Tap a facility below to adopt its standardized details or distinguish the name.',
                                          style: const TextStyle(color: Color(0xFF15803D), fontSize: 11, height: 1.3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: detectedMatches.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                  itemBuilder: (_, i) {
                                    final m = detectedMatches[i];
                                    final itemCity = LocationResolver.resolveCityName(m.institution.cityMunicipality ?? m.institution.rawCityMunicipality);
                                    final itemProv = LocationResolver.resolveProvinceName(m.institution.provinceName ?? m.institution.rawProvinceName);
                                    return ListTile(
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      leading: const Icon(Icons.apartment_rounded, color: Color(0xFF0066FF), size: 18),
                                      title: Text(
                                        m.institution.institutionName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF0F172A)),
                                      ),
                                      subtitle: Text(
                                        [
                                          if (itemCity.isNotEmpty) itemCity,
                                          if (itemProv.isNotEmpty) itemProv,
                                        ].join(' • '),
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                      ),
                                      trailing: m.isExactOrHighConfidenceDuplicate
                                          ? const Text('DUPLICATE', style: TextStyle(color: Color(0xFFDC2626), fontSize: 9.5, fontWeight: FontWeight.bold))
                                          : const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                                      onTap: () {
                                        setDlgState(() {
                                          workplaceCtrl.text = m.institution.institutionName;
                                          selectedExistingInstitution = m.institution;
                                          selectedRegion = LocationResolver.resolveRegionName(m.institution.regionName ?? m.institution.rawRegionName);
                                          selectedProvince = LocationResolver.resolveProvinceName(m.institution.provinceName ?? m.institution.rawProvinceName);
                                          selectedCity = LocationResolver.resolveCityName(m.institution.cityMunicipality ?? m.institution.rawCityMunicipality);
                                          if (m.institution.ownership != null && m.institution.ownership!.isNotEmpty) {
                                            selectedOwnership = m.institution.ownership;
                                          }
                                          if (m.institution.institutionType != null && m.institution.institutionType!.isNotEmpty) {
                                            selectedType = m.institution.institutionType;
                                          }
                                          if (m.institution.serviceCapability != null && m.institution.serviceCapability!.isNotEmpty) {
                                            selectedCapability = m.institution.serviceCapability;
                                          }
                                          detectedMatches = [];
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],

                          // SELECTED EXISTING FACILITY BANNER
                          if (selectedExistingInstitution != null) ...[
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
                                          'Selected DOH Facility: ${selectedExistingInstitution!.institutionName}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8), fontSize: 11.5),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Using verified location: ${[LocationResolver.resolveCityName(selectedCity), LocationResolver.resolveProvinceName(selectedProvince)].where((s) => s.isNotEmpty).join(", ")}',
                                          style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 11),
                                        ),
                                      ],
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
                                setDlgState(() => selectedRegion = LocationResolver.resolveRegionName(picked));
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
                                      (selectedRegion != null && selectedRegion!.isNotEmpty)
                                          ? LocationResolver.resolveRegionName(selectedRegion)
                                          : 'Select Region...',
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
                                final cleanProv = LocationResolver.resolveProvinceName(picked);
                                setDlgState(() {
                                  selectedProvince = cleanProv;
                                  selectedCity = null;
                                  final autoReg = LocationResolver.resolveRegionFromProvince(cleanProv);
                                  if (autoReg.isNotEmpty) selectedRegion = LocationResolver.resolveRegionName(autoReg);
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
                                      (selectedProvince != null && selectedProvince!.isNotEmpty)
                                          ? LocationResolver.resolveProvinceName(selectedProvince)
                                          : 'Select Province...',
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

                          const Text('City *', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final picked = await _showCityPicker(context, selectedCity, provinceFilter: selectedProvince);
                              if (picked != null) {
                                setDlgState(() => selectedCity = LocationResolver.resolveCityName(picked));
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
                                      (selectedCity != null && selectedCity!.isNotEmpty)
                                          ? LocationResolver.resolveCityName(selectedCity)
                                          : 'Select City / Municipality...',
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
                            onPressed: isSaving ? null : () => Navigator.pop(dialogCtx, null),
                            child: Text(
                              inst.isRejected ? 'Leave as Rejected' : 'Cancel',
                              style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (detectedMatches.isNotEmpty && selectedExistingInstitution == null)
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF0B192C),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final wp = workplaceCtrl.text.trim();
                                    final reg = selectedRegion?.trim() ?? '';
                                    final prov = selectedProvince?.trim() ?? '';
                                    final city = selectedCity?.trim() ?? '';

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

                                    // Block submission if active suggestions exist in Smart Detector without user selection
                                    if (detectedMatches.isNotEmpty && selectedExistingInstitution == null) {
                                      setDlgState(() => validationErr = 'Smart Detector: Active potential duplicates detected above. Please tap an existing facility to select it or distinguish the workplace name before submitting.');
                                      return;
                                    }

                                    setDlgState(() {
                                      isSaving = true;
                                      validationErr = null;
                                    });

                                    try {
                                      final api = Provider.of<ApiService>(context, listen: false);
                                      final res = await api.resubmitInstitutionRequest(
                                        name: inst.name,
                                        workplaceName: wp,
                                        region: reg.isNotEmpty ? reg : null,
                                        city: city,
                                        province: prov,
                                        ownership: selectedOwnership,
                                        institutionType: selectedType,
                                        serviceCapability: selectedCapability,
                                        requiresDsmApproval: inst.requiresDsmApproval,
                                      );
                                      Navigator.pop(dialogCtx, res);
                                    } catch (err) {
                                      setDlgState(() {
                                        isSaving = false;
                                        validationErr = 'Failed to submit: $err';
                                      });
                                    }
                                  },
                            child: isSaving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    (detectedMatches.isNotEmpty && selectedExistingInstitution == null)
                                        ? 'Select from Suggestions Above'
                                        : (selectedExistingInstitution != null ? 'Use Selected Institution' : 'Submit for Approval'),
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

    if (updated != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('${updated.institutionName} resubmitted for SFE Specialist approval!')),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    } else {
      // User cancelled editing dialog, clear active edit lock
      apiService.clearEditingCooldown(inst.name);
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

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);

    // If SFE user, immediately render dedicated SFE Approval Hub
    if (apiService.isSfe) {
      return const SfeInstitutionDashboardScreen();
    }

    // For MedRep / Sales User / Manager
    final isManager = apiService.isManager || apiService.isAdmin;
    final requests = isManager
        ? apiService.cachedInstitutions
        : (apiService.mySubmittedInstitutions.isNotEmpty
            ? apiService.mySubmittedInstitutions
            : apiService.cachedInstitutions);
    final pendingCount = requests.where((i) => i.isPendingApproval && i.workflowState != 'Pending DSM Approval').length;
    final dsmPendingCount = requests.where((i) => i.workflowState == 'Pending DSM Approval').length;
    final approvedCount = requests.where((i) => i.isApproved).length;
    final rejectedCount = requests.where((i) => i.isRejected).length;
    final filteredList = _getFilteredInstitutions(requests);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppDrawer(currentItem: DrawerItem.institutionApprovals),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B192C),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Institution Submission',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              isManager ? 'DSM / SFE Facility Review & Approvals' : 'Request Status & Resubmissions',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          ],
        ),
        actions: [
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
            // KPI Cards Overview
            _buildMedRepKpiSection(pendingCount, dsmPendingCount, approvedCount, rejectedCount, requests.length, isManager),

            // Notification Banner for Rejected or Newly Approved
            if (rejectedCount > 0)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$rejectedCount facility request${rejectedCount > 1 ? 's were' : ' was'} rejected by SFE. Tap "Modify & Resubmit" to correct and resubmit for approval.',
                        style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Search Bar & Filter Tabs
            _buildSearchAndFilters(pendingCount, dsmPendingCount, approvedCount, rejectedCount, isManager),

            // Requests List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0066FF)))
                  : filteredList.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: filteredList.length,
                          itemBuilder: (ctx, idx) => _buildInstitutionCard(filteredList[idx], isManager),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedRepKpiSection(int pending, int dsmPending, int approved, int rejected, int total, bool isManager) {
    return Container(
      color: const Color(0xFF0B192C),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          _buildKpiCard('Awaiting SFE', pending.toString(), Icons.hourglass_top_rounded, const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          if (isManager || dsmPending > 0) ...[
            _buildKpiCard('Pending DSM', dsmPending.toString(), Icons.admin_panel_settings_rounded, const Color(0xFFC084FC)),
            const SizedBox(width: 8),
          ],
          _buildKpiCard('Approved', approved.toString(), Icons.check_circle_rounded, const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _buildKpiCard('Action Req.', rejected.toString(), Icons.cancel_rounded, const Color(0xFFEF4444)),
          const SizedBox(width: 8),
          _buildKpiCard('Total Sent', total.toString(), Icons.domain_rounded, const Color(0xFF38BDF8)),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(int pending, int dsmPending, int approved, int rejected, bool isManager) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Search box
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: isManager ? 'Search all submitted facilities...' : 'Search my submitted facilities...',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Status Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', null),
                const SizedBox(width: 8),
                _buildFilterChip('Pending Approval', pending),
                if (isManager || dsmPending > 0) ...[
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending DSM Approval', dsmPending),
                ],
                const SizedBox(width: 8),
                _buildFilterChip('Approved', approved),
                const SizedBox(width: 8),
                _buildFilterChip('Rejected', rejected),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int? count) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0066FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0066FF) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF334155),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.25) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleDsmApprove(Institution inst) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
            SizedBox(width: 8),
            Text('DSM Facility Approval', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approve facility "${inst.institutionName}" into the program masterlist?',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            const Text(
              'This facility was validated by SFE. Confirming DSM approval commits it as fully approved.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve Facility', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final api = Provider.of<ApiService>(context, listen: false);
      final ok = await api.dsmApproveInstitution(inst.name);
      if (ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${inst.institutionName}" approved by DSM!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        _loadData();
      }
    }
  }

  Future<void> _handleDsmReject(Institution inst) async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Text('Reject Facility Proposal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Specify reason for rejecting "${inst.institutionName}":', style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 8),
              TextFormField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g. Duplicate facility or incorrect institution classification...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(10),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Rejection reason required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Confirm Rejection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final api = Provider.of<ApiService>(context, listen: false);
      final ok = await api.rejectInstitution(inst.name, reasonCtrl.text.trim());
      if (ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Facility "${inst.institutionName}" rejected.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        _loadData();
      }
    }
  }

  Widget _buildInstitutionCard(Institution inst, bool isManager) {
    final api = Provider.of<ApiService>(context, listen: false);
    Color badgeBg;
    Color badgeBorder;
    Color badgeText;
    String badgeLabel;
    IconData badgeIcon;

    if (inst.workflowState == 'Pending DSM Approval') {
      badgeBg = const Color(0xFFF3E8FF);
      badgeBorder = const Color(0xFFD8B4FE);
      badgeText = const Color(0xFF7E22CE);
      badgeLabel = 'Pending DSM Approval';
      badgeIcon = Icons.admin_panel_settings_rounded;
    } else if (inst.isApproved) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeBorder = const Color(0xFF86EFAC);
      badgeText = const Color(0xFF15803D);
      badgeLabel = 'Approved by SFE';
      badgeIcon = Icons.check_circle_rounded;
    } else if (inst.isRejected) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeBorder = const Color(0xFFFCA5A5);
      badgeText = const Color(0xFFB91C1C);
      badgeLabel = 'Rejected by SFE';
      badgeIcon = Icons.cancel_rounded;
    } else {
      badgeBg = const Color(0xFFFEF3C7);
      badgeBorder = const Color(0xFFFCD34D);
      badgeText = const Color(0xFFB45309);
      badgeLabel = 'Awaiting SFE Review';
      badgeIcon = Icons.hourglass_top_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inst.isRejected
                ? const Color(0xFFEF4444)
                : (inst.workflowState == 'Pending DSM Approval' ? const Color(0xFFC084FC) : const Color(0xFFE2E8F0)),
            width: inst.isRejected ? 1.5 : (inst.workflowState == 'Pending DSM Approval' ? 1.2 : 1),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name & Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    inst.institutionName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 12, color: badgeText),
                      const SizedBox(width: 4),
                      Text(badgeLabel, style: TextStyle(color: badgeText, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Location
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    [
                      if (inst.cityMunicipality != null && inst.cityMunicipality!.isNotEmpty) inst.cityMunicipality!,
                      if (inst.provinceName != null && inst.provinceName!.isNotEmpty) inst.provinceName!,
                      if (inst.regionName != null && inst.regionName!.isNotEmpty) inst.regionName!,
                    ].join(', '),
                    style: const TextStyle(color: Color(0xFF475569), fontSize: 12.5),
                  ),
                ),
              ],
            ),

            if (inst.name.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'ID: ${inst.name}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],

            // Facility Classification & Resubmission tags
            if ((inst.ownership != null && inst.ownership!.isNotEmpty) ||
                (inst.institutionType != null && inst.institutionType!.isNotEmpty) ||
                (inst.serviceCapability != null && inst.serviceCapability!.isNotEmpty) ||
                inst.isResubmission) ...[
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
                  if (inst.isResubmission)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.replay_rounded, size: 11, color: Color(0xFFB45309)),
                          const SizedBox(width: 3),
                          Text(
                            'Resubmission (${inst.resubmissionCount}/2)',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],

            // Linked Doctor indicator
            if (inst.linkedDoctorName != null && inst.linkedDoctorName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE9D5FF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_pin_circle_outlined, size: 13, color: Color(0xFF7E22CE)),
                    const SizedBox(width: 4),
                    Text(
                      'Linked to Doctor: ${inst.linkedDoctorName!}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE)),
                    ),
                  ],
                ),
              ),
            ],

            // Rejection reason callout
            if (inst.isRejected) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF87171), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.report_problem_rounded, color: Color(0xFFDC2626), size: 15),
                        SizedBox(width: 5),
                        Text(
                          'SFE Feedback / Rejection Notice:',
                          style: TextStyle(color: Color(0xFF991B1B), fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      inst.rejectionDisplayLabel,
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    if (inst.rejectionReason != null && inst.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        inst.rejectionReason!,
                        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Action Buttons
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 10),

            if (inst.workflowState == 'Pending DSM Approval') ...[
              if (isManager) ...[
                Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF7E22CE), size: 16),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Requires DSM Sign-off',
                        style: TextStyle(color: Color(0xFF7E22CE), fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => _handleDsmReject(inst),
                      child: const Text('Reject', style: TextStyle(fontSize: 11.5)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () => _handleDsmApprove(inst),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve Facility', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: const [
                    Icon(Icons.hourglass_bottom_rounded, color: Color(0xFF7E22CE), size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'SFE Specialist approved this facility. Awaiting DSM final approval with doctor submission.',
                        style: TextStyle(color: Color(0xFF7E22CE), fontSize: 11.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ] else if (inst.isRejected) ...[
              if (inst.resubmissionCount >= 2) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.phone_in_talk_rounded, color: Color(0xFFDC2626), size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Recommendation: Maximum resubmissions reached (2/2). Please call or contact your SFE Specialist directly.',
                          style: TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (api.isSfe || api.isAdmin) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0066FF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final changed = await RemapInstitutionDialog.show(context, inst);
                          if (changed == true) {
                            _loadData();
                          }
                        },
                        icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                        label: const Text('Change / Remap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0B192C),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => InstitutionAuditTrailDialog.show(context, inst),
                      icon: const Icon(Icons.history_edu_rounded, size: 15, color: Color(0xFF0B192C)),
                      label: const Text('Audit Trail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                    ),
                    const SizedBox(width: 8),
                    if (inst.isCooldownActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB45309)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              inst.editingUser != null
                                  ? 'Being edited by ${inst.editingUser} (${inst.cooldownRemainingSeconds}s)'
                                  : 'Active Edit in Progress (${inst.cooldownRemainingSeconds}s)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF92400E)),
                            ),
                          ],
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B192C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => _openEditAndResubmitDialog(inst),
                        icon: const Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF38BDF8)),
                        label: Text('Modify & Resubmit (${inst.resubmissionCount}/2)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                  ],
                ),
              ],
            ] else if (inst.isApproved) ...[
              Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Ready to use: Selectable in doctor profiling.',
                      style: TextStyle(color: Color(0xFF059669), fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0B192C),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => InstitutionAuditTrailDialog.show(context, inst),
                    icon: const Icon(Icons.history_edu_rounded, size: 14, color: Color(0xFF0B192C)),
                    label: const Text('Audit Trail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'For SFE Approval: Awaiting SFE Specialist review.',
                      style: TextStyle(color: Color(0xFFD97706), fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0B192C),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => InstitutionAuditTrailDialog.show(context, inst),
                    icon: const Icon(Icons.history_edu_rounded, size: 14, color: Color(0xFF0B192C)),
                    label: const Text('Audit Trail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  if (inst.isCooldownActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFB45309)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            inst.editingUser != null
                                ? 'Being edited by ${inst.editingUser} (${inst.cooldownRemainingSeconds}s)'
                                : 'Active Edit (${inst.cooldownRemainingSeconds}s)',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF92400E), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B192C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => _openEditAndResubmitDialog(inst),
                      icon: const Icon(Icons.edit, size: 13, color: Color(0xFF38BDF8)),
                      label: const Text('Edit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.domain_verification_outlined, size: 60, color: Color(0xFF94A3B8)),
            SizedBox(height: 16),
            Text(
              'No Institution Requests Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            SizedBox(height: 8),
            Text(
              'New institutions can be proposed directly from Step 2 of HCP Profile Submission. Track the review and approval status of your submitted institutions here.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

typedef InstitutionSubmissionScreen = InstitutionApprovalsScreen;
