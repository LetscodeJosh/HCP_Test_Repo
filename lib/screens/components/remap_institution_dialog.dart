import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lookup_models.dart';
import '../../services/api_service.dart';
import '../../services/app_logger.dart';

/// Modal dialog allowing SFE Specialists to reassign / remap a rejected institution
/// to an approved masterlist facility, unblocking the MedRep to continue HCP profiling.
class RemapInstitutionDialog extends StatefulWidget {
  final Institution rejectedInstitution;

  const RemapInstitutionDialog({
    Key? key,
    required this.rejectedInstitution,
  }) : super(key: key);

  static Future<bool?> show(BuildContext context, Institution rejectedInstitution) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RemapInstitutionDialog(rejectedInstitution: rejectedInstitution),
    );
  }

  @override
  State<RemapInstitutionDialog> createState() => _RemapInstitutionDialogState();
}

class _RemapInstitutionDialogState extends State<RemapInstitutionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();

  Institution? _selectedReplacement;
  bool _isSubmitting = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final reason = widget.rejectedInstitution.rejectionReason ?? '';
    _noteController.text = reason.isNotEmpty
        ? 'Remapped by SFE Specialist ($reason)'
        : 'Remapped duplicate/unprofiled institution to approved facility by SFE';
  }

  @override
  void dispose() {
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openReplacementSearchDialog(List<Institution> approvedList) async {
    final picked = await showDialog<Institution>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) {
          final q = _searchQuery.toLowerCase().trim();
          final filtered = approvedList.where((i) {
            if (i.name == widget.rejectedInstitution.name ||
                i.institutionName.toLowerCase() == widget.rejectedInstitution.institutionName.toLowerCase()) {
              return false; // Cannot select itself
            }
            if (q.isEmpty) return true;
            return i.institutionName.toLowerCase().contains(q) ||
                i.name.toLowerCase().contains(q) ||
                (i.cityMunicipality ?? '').toLowerCase().contains(q) ||
                (i.provinceName ?? '').toLowerCase().contains(q);
          }).toList();

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
                maxWidth: 480,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.apartment_rounded, color: Color(0xFF0066FF), size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Select Approved Replacement Facility',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search approved hospital or clinic...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) {
                      setDlgState(() => _searchQuery = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Approved Facilities (${filtered.length} found)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching approved facility found.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (ctx, idx) {
                              final item = filtered[idx];
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                                ),
                                title: Text(
                                  item.institutionName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF0F172A)),
                                ),
                                subtitle: Text(
                                  [
                                    if (item.cityMunicipality != null && item.cityMunicipality!.isNotEmpty) item.cityMunicipality,
                                    if (item.provinceName != null && item.provinceName!.isNotEmpty) item.provinceName,
                                  ].join(', '),
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                                onTap: () => Navigator.pop(dialogCtx, item),
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

    if (picked != null) {
      setState(() {
        _selectedReplacement = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedReplacement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an approved replacement facility from the masterlist.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final success = await apiService.remapRejectedInstitution(
        rejectedInstitutionNameOrId: widget.rejectedInstitution.name,
        replacementInstitution: _selectedReplacement!,
        resolutionNote: _noteController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Remapped to "${_selectedReplacement!.institutionName}". MedRep notified to continue profiling.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remap institution. Please check permissions or network.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } catch (e, st) {
      AppLogger.e('RemapInstitutionDialog', 'Error submitting remap: $e', e, st);
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);
    final approvedList = apiService.actualInstitutions;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0066FF), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Remap Rejected Facility',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Assign approved facility so MedRep can profile',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Rejected Facility Summary Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'CURRENTLY REJECTED FACILITY',
                            style: TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.rejectedInstitution.institutionName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                      ),
                      if (widget.rejectedInstitution.rejectionReason != null &&
                          widget.rejectedInstitution.rejectionReason!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Cause: ${widget.rejectedInstitution.rejectionReason!}',
                          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                        ),
                      ],
                      if (widget.rejectedInstitution.owner != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Submitted by: ${widget.rejectedInstitution.owner}',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Replacement Facility Selector
                const Text(
                  'Select Approved Replacement Facility *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _openReplacementSearchDialog(approvedList),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedReplacement != null ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                        width: _selectedReplacement != null ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedReplacement != null ? Icons.verified_rounded : Icons.search_rounded,
                          color: _selectedReplacement != null ? const Color(0xFF10B981) : const Color(0xFF0066FF),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedReplacement?.institutionName ?? 'Tap to select approved facility...',
                                style: TextStyle(
                                  fontWeight: _selectedReplacement != null ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13.5,
                                  color: _selectedReplacement != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                ),
                              ),
                              if (_selectedReplacement != null)
                                Text(
                                  [
                                    if (_selectedReplacement!.cityMunicipality != null) _selectedReplacement!.cityMunicipality,
                                    if (_selectedReplacement!.provinceName != null) _selectedReplacement!.provinceName,
                                  ].join(', '),
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Remediation / Resolution Note
                const Text(
                  'SFE Resolution & Audit Note',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Explanation for remapping (reflects in HCP, HCP Account, & Submissions)...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please provide an SFE resolution note';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Explanation Banner
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF0066FF), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Remapping replaces this rejected institution across linked HCP profiles, HCP Accounts, and pending submissions, and notifies the MedRep on their lockscreen/homescreen that profiling is unblocked.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0066FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        _isSubmitting ? 'Remapping...' : 'Remap & Notify MedRep',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
