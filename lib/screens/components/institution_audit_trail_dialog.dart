import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/lookup_models.dart';

/// Read-only Audit Trail dialog displaying the complete chronological submission,
/// rejection, resubmission, and approval history for an Institution.
/// Accessible in view-only mode for SFE/Admin, DSM, and MedRep.
class InstitutionAuditTrailDialog extends StatelessWidget {
  final Institution institution;

  const InstitutionAuditTrailDialog({
    Key? key,
    required this.institution,
  }) : super(key: key);

  static Future<void> show(BuildContext context, Institution institution) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => InstitutionAuditTrailDialog(institution: institution),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    // Build timeline items, synthesizing initial proposal if empty
    final List<InstitutionAuditLogEntry> entries = institution.auditTrail.isNotEmpty
        ? institution.auditTrail
        : [
            InstitutionAuditLogEntry(
              timestamp: institution.creation != null
                  ? DateTime.tryParse(institution.creation!) ?? DateTime.now()
                  : DateTime.now(),
              user: institution.owner ?? 'MedRep',
              role: 'MedRep',
              action: 'Initial Proposal',
              details:
                  'Proposed ${institution.institutionName} (${institution.institutionType ?? "Facility"}, ${institution.ownership ?? "Private"}) at ${institution.cityMunicipality ?? ""}, ${institution.provinceName ?? ""}',
              snapshot: {
                'institution_name': institution.institutionName,
                'ownership': institution.ownership,
                'institution_type': institution.institutionType,
                'service_capability': institution.serviceCapability,
                'location': '${institution.cityMunicipality ?? ""}, ${institution.provinceName ?? ""}',
              },
            ),
          ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history_edu_rounded, color: Color(0xFF38BDF8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Institution Audit Trail',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          institution.institutionName,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, color: Color(0xFF38BDF8), size: 12),
                        SizedBox(width: 4),
                        Text(
                          'READ-ONLY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Read-Only Security Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF1F5F9),
              child: Row(
                children: const [
                  Icon(Icons.shield_outlined, color: Color(0xFF475569), size: 15),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Official immutable audit log visible to SFE/Admin, DSM, and MedRep.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            // Timeline Entries
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  // Reverse chronological order: newest on top
                  final entry = entries[entries.length - 1 - index];
                  final isLatest = index == 0;

                  Color actionColor;
                  IconData actionIcon;
                  final actLower = entry.action.toLowerCase();
                  if (actLower.contains('initial') || actLower.contains('propose')) {
                    actionColor = const Color(0xFF2563EB);
                    actionIcon = Icons.add_business_rounded;
                  } else if (actLower.contains('resubmit') || actLower.contains('modify')) {
                    actionColor = const Color(0xFFD97706);
                    actionIcon = Icons.edit_note_rounded;
                  } else if (actLower.contains('normalize') || actLower.contains('standardize')) {
                    actionColor = const Color(0xFF0D9488);
                    actionIcon = Icons.auto_fix_high_rounded;
                  } else if (actLower.contains('approve') || actLower.contains('route')) {
                    actionColor = const Color(0xFF16A34A);
                    actionIcon = Icons.check_circle_rounded;
                  } else if (actLower.contains('reject')) {
                    actionColor = const Color(0xFFDC2626);
                    actionIcon = Icons.cancel_rounded;
                  } else {
                    actionColor = const Color(0xFF475569);
                    actionIcon = Icons.event_note_rounded;
                  }

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Node with line
                        Column(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: actionColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: actionColor, width: 2),
                              ),
                              child: Icon(actionIcon, size: 15, color: actionColor),
                            ),
                            if (index < entries.length - 1)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: const Color(0xFFE2E8F0),
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // Card Content
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isLatest ? const Color(0xFFF8FAFC) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isLatest ? actionColor.withOpacity(0.3) : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: isLatest
                                  ? [
                                      BoxShadow(
                                        color: actionColor.withOpacity(0.06),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Action & Role Badges
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: actionColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        entry.action,
                                        style: TextStyle(
                                          color: actionColor,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        entry.role,
                                        style: const TextStyle(
                                          color: Color(0xFF475569),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      dateFormat.format(entry.timestamp),
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Performed By
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Recorded By: ${entry.user}',
                                      style: const TextStyle(
                                        color: Color(0xFF334155),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Details Message
                                if (entry.details != null && entry.details!.isNotEmpty)
                                  Text(
                                    entry.details!,
                                    style: const TextStyle(
                                      color: Color(0xFF1E293B),
                                      fontSize: 12,
                                    ),
                                  ),

                                // Snapshot metadata chips if present
                                if (entry.snapshot != null && entry.snapshot!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: entry.snapshot!.entries.map((e) {
                                      if (e.value == null || e.value.toString().isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      final label = e.key.replaceAll('_', ' ').toUpperCase();
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          '$label: ${e.value}',
                                          style: const TextStyle(
                                            color: Color(0xFF475569),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 14),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Total audit entries: ',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ),
                  Text(
                    '${entries.length} log${entries.length > 1 ? "s" : ""}',
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B192C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
