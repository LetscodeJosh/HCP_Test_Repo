import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/submission.dart';
import '../models/lookup_models.dart';
import '../models/hcp.dart';
import '../models/hcp_account.dart';
import '../services/api_service.dart';
import 'components/app_drawer.dart';
import 'hcp_wizard_screen.dart';

class SubmissionHistoryScreen extends StatefulWidget {
  const SubmissionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<SubmissionHistoryScreen> createState() => _SubmissionHistoryScreenState();
}

class _SubmissionHistoryScreenState extends State<SubmissionHistoryScreen> {
  List<HcpProfileSubmission> _submissions = [];
  bool _isLoading = true;

  // Filter & Sort State
  bool _showFilters = true;
  bool _isAscending = false;
  String _sortField = 'Created On';

  final TextEditingController _idFilterCtrl = TextEditingController();
  final TextEditingController _doctorNameFilterCtrl = TextEditingController();
  final TextEditingController _typeFilterCtrl = TextEditingController();
  String _practiceFilter = 'All';
  String _statusFilter = 'All';
  String _programFilter = 'All';
  bool _onlyMySubmissions = false;

  @override
  void initState() {
    super.initState();
    final apiService = Provider.of<ApiService>(context, listen: false);
    if (apiService.isMedRep) {
      _onlyMySubmissions = true;
    }
    if (apiService.isAdmin) {
      _programFilter = 'All';
    } else if (apiService.selectedProgram.isNotEmpty && apiService.selectedProgram != 'All') {
      _programFilter = apiService.selectedProgram;
    }
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final items = await apiService.fetchSubmissions();
      setState(() {
        _submissions = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleApplyWorkflowAction(BuildContext modalCtx, HcpProfileSubmission submission, String action, {String remarks = ''}) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (loadingCtx) => Center(
          child: CircularProgressIndicator(
            color: action == 'Approve'
                ? const Color(0xFF16A34A)
                : action == 'Reject'
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF2563EB),
          ),
        ),
      );

      await apiService.applyWorkflowAction(submission, action, remarks: remarks);
      if (action == 'Approve') {
        await apiService.fetchDoctors().catchError((_) => <Hcp>[]);
        await apiService.fetchHcpAccounts().catchError((_) => <HcpAccount>[]);
      }
      await apiService.fetchSubmissions().catchError((_) => <HcpProfileSubmission>[]);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pop(modalCtx); // Close detail modal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: action == 'Approve'
                ? const Color(0xFF16A34A)
                : action == 'Reject'
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF2563EB),
            content: Text(
              action == 'Approve'
                  ? 'Submission Approved! Doctor registered in Masterlist and synced to HCP Account.'
                  : action == 'Select for Processing'
                      ? 'Action applied: Selected for Processing (State: Processed).'
                      : action == 'Submit for Approval'
                          ? 'Action applied: Submitted for Approval (State: Pending Approval).'
                          : action == 'Reject'
                              ? 'Action applied: Submission Rejected.'
                              : 'Workflow Action "$action" applied successfully.',
            ),
          ),
        );
        _loadSubmissions();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to apply $action: $e')),
        );
      }
    }
  }

  bool _matchesProgram(HcpProfileSubmission item, String progFilter) {
    if (progFilter.isEmpty || progFilter.toLowerCase() == 'all') return true;
    final prog = progFilter.toLowerCase().trim();
    final subProg = (item.accountOrProgram ?? '').toLowerCase().trim();
    if (subProg.isEmpty) return true;
    return subProg.contains(prog) ||
        prog.contains(subProg) ||
        (prog.contains('abbott') && subProg.contains('abbott')) ||
        (prog.contains('adc') && subProg.contains('abbott')) ||
        (prog.contains('bayer') && subProg.contains('bayer')) ||
        (prog.contains('bch') && subProg.contains('bayer')) ||
        (prog.contains('corenergy') && subProg.contains('corenergy'));
  }

  int _getProgramTotalCount(ApiService apiService) {
    if (apiService.isAdmin) {
      if (_programFilter != 'All') {
        return _submissions.where((s) => _matchesProgram(s, _programFilter)).length;
      }
      return _submissions.length;
    } else {
      final userProg = apiService.selectedProgram.isNotEmpty && apiService.selectedProgram != 'All'
          ? apiService.selectedProgram
          : _programFilter;
      if (userProg.isEmpty || userProg.toLowerCase() == 'all') {
        return _submissions.length;
      }
      final matches = _submissions.where((s) => _matchesProgram(s, userProg)).length;
      return matches > 0 ? matches : _submissions.length;
    }
  }

  String _formatSubmissionDate12Hr(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty || dateStr == 'N/A' || dateStr == 'No date') {
      return 'No date';
    }
    final raw = dateStr.trim();
    if (raw.toUpperCase().contains('AM') || raw.toUpperCase().contains('PM')) {
      return raw;
    }
    try {
      DateTime? dt = DateTime.tryParse(raw);
      if (dt == null && raw.contains(' ')) {
        final parts = raw.split(' ');
        if (parts.length >= 2) {
          final datePart = parts[0];
          final timePart = parts[1];
          dt = DateTime.tryParse('${datePart}T$timePart');
          if (dt == null && datePart.contains('-')) {
            final dp = datePart.split('-');
            if (dp.length == 3) {
              if (dp[0].length == 4) {
                // yyyy-MM-dd
                dt = DateTime.tryParse('${dp[0]}-${dp[1].padLeft(2, '0')}-${dp[2].padLeft(2, '0')}T$timePart');
              } else if (dp[2].length == 4) {
                // MM-dd-yyyy
                dt = DateTime.tryParse('${dp[2]}-${dp[0].padLeft(2, '0')}-${dp[1].padLeft(2, '0')}T$timePart');
              }
            }
          }
        }
      }
      if (dt != null) {
        final local = dt.toLocal();
        final int hour12 = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
        final String period = local.hour >= 12 ? 'PM' : 'AM';
        final String month = local.month.toString().padLeft(2, '0');
        final String day = local.day.toString().padLeft(2, '0');
        final String year = local.year.toString();
        final String hour = hour12.toString().padLeft(2, '0');
        final String minute = local.minute.toString().padLeft(2, '0');
        final String second = local.second.toString().padLeft(2, '0');
        return '$month-$day-$year $hour:$minute:$second $period';
      }
    } catch (_) {}
    return raw;
  }

  List<HcpProfileSubmission> _getFilteredAndSortedSubmissions(ApiService apiService) {
    List<HcpProfileSubmission> list = List.from(_submissions);

    // 1. Role-based Program Isolation
    if (apiService.isAdmin) {
      if (_programFilter != 'All') {
        list = list.where((item) => _matchesProgram(item, _programFilter)).toList();
      }
    } else {
      final userProg = apiService.selectedProgram.isNotEmpty && apiService.selectedProgram != 'All'
          ? apiService.selectedProgram
          : _programFilter;
      if (userProg.isNotEmpty && userProg.toLowerCase() != 'all') {
        final matches = list.where((item) => _matchesProgram(item, userProg)).toList();
        if (matches.isNotEmpty) {
          list = matches;
        }
      }
    }

    // 2. Submissions Scope Filter:
    final bool enforceMySubmissions = _onlyMySubmissions;
    if (enforceMySubmissions) {
      final email = (apiService.loggedInEmail ?? '').toLowerCase().trim();
      final fullName = (apiService.loggedInFullName ?? '').toLowerCase().trim();
      final userTokens = fullName.split(RegExp(r'\s+')).where((t) => t.length > 1).toList();

      list = list.where((item) {
        final sEmail = (item.medrepEmail ?? item.userId ?? item.owner ?? '').toLowerCase().trim();
        final sSales = (item.salesPerson ?? '').toLowerCase().trim();

        // 1. Direct Email / Owner / User ID match (or prefix match before @)
        if (sEmail.isNotEmpty && email.isNotEmpty) {
          if (sEmail == email || email.contains(sEmail) || sEmail.contains(email)) return true;
          final emailPrefix = email.contains('@') ? email.split('@').first : email;
          final sEmailPrefix = sEmail.contains('@') ? sEmail.split('@').first : sEmail;
          if (emailPrefix.isNotEmpty && sEmailPrefix.isNotEmpty && (emailPrefix == sEmailPrefix || email.contains(sEmailPrefix) || sEmail.contains(emailPrefix))) return true;
        }

        // 2. Sales Person Name Match (Exact, Substring, or Multi-Token e.g. "Jorge Naag Mengorio" matches "Jorge Mengorio")
        if (sSales.isNotEmpty && fullName.isNotEmpty) {
          if (sSales == fullName || sSales.contains(fullName) || fullName.contains(sSales)) return true;
          final salesTokens = sSales.split(RegExp(r'\s+')).where((t) => t.length > 1).toList();
          final matchingTokens = salesTokens.where((t) => userTokens.contains(t)).length;
          if (matchingTokens >= 2 || (salesTokens.length == 1 && userTokens.contains(salesTokens.first))) {
            return true;
          }
        }
        return false;
      }).toList();
    }

    if (_idFilterCtrl.text.trim().isNotEmpty) {
      final q = _idFilterCtrl.text.trim().toLowerCase();
      list = list.where((item) => (item.name ?? '').toLowerCase().contains(q)).toList();
    }
    if (_doctorNameFilterCtrl.text.trim().isNotEmpty) {
      final q = _doctorNameFilterCtrl.text.trim().toLowerCase();
      list = list.where((item) {
        final name = (item.hcpFullName ?? item.hcpName).toLowerCase();
        final fn = (item.firstName ?? '').toLowerCase();
        final ln = (item.lastName ?? '').toLowerCase();
        return name.contains(q) || fn.contains(q) || ln.contains(q);
      }).toList();
    }
    if (_typeFilterCtrl.text.trim().isNotEmpty) {
      final q = _typeFilterCtrl.text.trim().toLowerCase();
      list = list.where((item) => (item.hcpType ?? '').toLowerCase().contains(q)).toList();
    }
    if (_practiceFilter != 'All') {
      list = list.where((item) => (item.hcpPractice ?? '').toLowerCase() == _practiceFilter.toLowerCase()).toList();
    }
    if (_statusFilter != 'All') {
      list = list.where((item) {
        final wf = (item.workflowState ?? item.status ?? '').toLowerCase().trim();
        switch (_statusFilter) {
          case 'Draft':
            return wf == 'draft';
          case 'Processed':
            return wf == 'processed' || wf.contains('proc');
          case 'Pending Approval':
            return (wf.contains('pend') || wf.isEmpty) && item.docstatus == 0 && wf != 'draft' && wf != 'processed';
          case 'Approved':
            return (wf == 'approved' && !wf.contains('pend')) || item.docstatus == 1;
          case 'Rejected':
            return wf == 'rejected' || wf.contains('reject') || item.docstatus == 2;
          default:
            return true;
        }
      }).toList();
    }

    list.sort((a, b) {
      int cmp = 0;
      switch (_sortField) {
        case 'Name of Doctor':
          cmp = (a.hcpFullName ?? a.hcpName).compareTo(b.hcpFullName ?? b.hcpName);
          break;
        case 'First Name':
          cmp = (a.firstName ?? '').compareTo(b.firstName ?? '');
          break;
        case 'Middle Name':
          cmp = (a.middleName ?? '').compareTo(b.middleName ?? '');
          break;
        case 'Last Name':
          cmp = (a.lastName ?? '').compareTo(b.lastName ?? '');
          break;
        case 'ID':
          cmp = (a.name ?? '').compareTo(b.name ?? '');
          break;
        case 'Type':
          cmp = (a.hcpType ?? '').compareTo(b.hcpType ?? '');
          break;
        case 'Practice':
          cmp = (a.hcpPractice ?? '').compareTo(b.hcpPractice ?? '');
          break;
        case 'Status':
          final sa = a.status ?? a.workflowState ?? a.applicationStatus ?? '';
          final sb = b.status ?? b.workflowState ?? b.applicationStatus ?? '';
          cmp = sa.compareTo(sb);
          break;
        case 'Institution':
          cmp = (a.institution ?? '').compareTo(b.institution ?? '');
          break;
        case 'Last Updated On':
        case 'Created On':
        default:
          cmp = (a.submissionDate ?? '').compareTo(b.submissionDate ?? '');
          break;
      }
      return _isAscending ? cmp : -cmp;
    });

    return list;
  }

  void _startNewSubmission() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HcpWizardScreen()),
    ).then((_) => _loadSubmissions());
  }

  void _showSubmissionDetail(HcpProfileSubmission submission) {
    int activeDetailTab = 0;
    HcpProfileSubmission currentSub = submission;
    bool isFetchingFull = submission.name != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isNewDoc = currentSub.hcpName.isEmpty ||
              currentSub.hcpName == 'NEW-HCP' ||
              (currentSub.changesJson != null && currentSub.changesJson!.contains('"is_new_doctor":true')) ||
              (currentSub.changesJson != null && currentSub.changesJson!.contains('"is_new_doctor": true'));
          final tabTitles = ['Step 1', 'Step 2', 'Step 3', 'Others', isNewDoc ? 'New Doctor Information' : 'Changes'];

          if (isFetchingFull && submission.name != null) {
            final apiService = Provider.of<ApiService>(context, listen: false);
            apiService.fetchSubmissionDetail(submission.name!).then((full) {
              setModalState(() {
                currentSub = full;
                isFetchingFull = false;
              });
            }).catchError((_) {
              setModalState(() {
                isFetchingFull = false;
              });
            });
            isFetchingFull = false;
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              color: Color(0xFF18181B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ERPNext Workflow Notification / Manager Review Banner
                Builder(
                  builder: (ctxBanner) {
                    final apiService = Provider.of<ApiService>(context, listen: false);
                    final rawWf = (currentSub.workflowState ?? currentSub.status ?? '').toLowerCase().trim();
                    final bool isPending = (rawWf.contains('pend') || rawWf.isEmpty) && currentSub.docstatus == 0 && rawWf != 'draft' && !rawWf.contains('proc');
                    final bool canApproveOrReject = (apiService.isManager || apiService.isAdmin) && isPending;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: canApproveOrReject ? const Color(0xFF1E3A8A) : const Color(0xFF0284C7),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            canApproveOrReject ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              canApproveOrReject
                                  ? 'Managerial Review — Action buttons (Approve / Reject) are available below.'
                                  : 'This form is not editable due to a Workflow.',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(currentSub),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Dark Workflow Tab Bar
                Container(
                  width: double.infinity,
                  color: const Color(0xFF09090B),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: List.generate(tabTitles.length, (idx) {
                        final isSelected = activeDetailTab == idx;
                        return GestureDetector(
                          onTap: () => setModalState(() => activeDetailTab = idx),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF27272A) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF3F3F46) : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              tabTitles[idx],
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildDetailTabContent(activeDetailTab, currentSub),
                  ),
                ),

                // Role-Aware Workflow Action Footer Bar (Aligned with ERPNext HCP Profile Submission WF)
                Builder(
                  builder: (footerCtx) {
                    final apiService = Provider.of<ApiService>(context, listen: false);
                    final rawWf = (currentSub.workflowState ?? currentSub.status ?? '').toLowerCase().trim();
                    final bool isDraft = rawWf == 'draft';
                    final bool isProcessed = rawWf == 'processed' || rawWf.contains('proc');
                    final bool isPending = (rawWf.contains('pend') || rawWf.isEmpty) && currentSub.docstatus == 0 && !isDraft && !isProcessed;
                    final bool isApproved = (rawWf == 'approved' || currentSub.docstatus == 1) && !isPending;
                    final bool isRejected = rawWf == 'rejected' || rawWf.contains('reject') || currentSub.docstatus == 2;

                    // Allowed transition rules strictly from ERPNext HCP Profile Submission WF:
                    // 1. Draft -> Submit for Processing -> Processed (Sales User, System Manager)
                    final bool canSubmitForProcessing = (apiService.isMedRep || apiService.isAdmin) && isDraft;

                    // 2. Draft / Rejected -> Submit for Approval -> Pending Approval (Sales User, Sales Manager, System Manager)
                    // Note: 'Processed' has NO transitions defined in ERPNext HCP Profile Submission WF.
                    final bool canSubmitForApproval = (apiService.isMedRep || apiService.isManager || apiService.isAdmin) && (isDraft || isRejected);

                    // 3. Pending Approval -> Approve / Reject (Sales Manager, System Manager)
                    final bool canApproveOrReject = (apiService.isManager || apiService.isAdmin) && isPending;

                    // If user is Admin, allow override testing on Approved/Processed
                    final bool showAdminOverrides = apiService.isAdmin && isApproved;

                    if (!canSubmitForProcessing && !canSubmitForApproval && !canApproveOrReject && !showAdminOverrides) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: const BoxDecoration(
                          color: Color(0xFF18181B),
                          border: Border(top: BorderSide(color: Color(0xFF27272A))),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isApproved
                                  ? Icons.check_circle_rounded
                                  : isRejected
                                      ? Icons.cancel_rounded
                                      : isProcessed
                                          ? Icons.playlist_add_check_rounded
                                          : Icons.info_outline_rounded,
                              color: isApproved
                                  ? const Color(0xFF10B981)
                                  : isRejected
                                      ? const Color(0xFFEF4444)
                                      : isProcessed
                                          ? const Color(0xFF3B82F6)
                                          : const Color(0xFFD97706),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isApproved
                                    ? 'Status: Approved & Masterlist Synced'
                                    : isRejected
                                        ? 'Status: Rejected'
                                        : isProcessed
                                            ? 'Status: Processed (Form Locked by Workflow)'
                                            : 'Status: Pending Approval (Awaiting Manager Review)',
                                style: TextStyle(
                                  color: isApproved
                                      ? const Color(0xFF10B981)
                                      : isRejected
                                          ? const Color(0xFFEF4444)
                                          : isProcessed
                                              ? const Color(0xFF3B82F6)
                                              : const Color(0xFFD97706),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF18181B),
                        border: Border(top: BorderSide(color: Color(0xFF27272A))),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Primary allowed actions row
                          Row(
                            children: [
                              // 1. Action: Submit for Processing (Draft -> Processed)
                              if (canSubmitForProcessing) ...[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                                    label: const Text(
                                      'Submit for Processing',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    onPressed: () => _handleApplyWorkflowAction(ctx, currentSub, 'Submit for Processing'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],

                              // 2. Action: Submit for Approval (Draft / Rejected -> Pending Approval)
                              if (canSubmitForApproval && !isPending && !isApproved && !isProcessed) ...[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD97706),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: Icon(isRejected ? Icons.replay_rounded : Icons.send_rounded, size: 18),
                                    label: Text(
                                      isRejected ? 'Resubmit for Approval' : 'Submit for Approval',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    onPressed: () => _handleApplyWorkflowAction(ctx, currentSub, 'Submit for Approval'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],

                              // 3. Action: Reject & Approve (Pending Approval -> Approved / Rejected)
                              if (canApproveOrReject) ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFEF4444),
                                      side: const BorderSide(color: Color(0xFFEF4444)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.close, size: 18),
                                    label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (dCtx) => AlertDialog(
                                          backgroundColor: const Color(0xFF1C1C1E),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: const Text('Reject Submission?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          content: const Text('Are you sure you want to reject this HCP Profile submission?', style: TextStyle(color: Colors.white70)),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(dCtx, false),
                                              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                              onPressed: () => Navigator.pop(dCtx, true),
                                              child: const Text('Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        _handleApplyWorkflowAction(ctx, currentSub, 'Reject');
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF16A34A),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                                    label: const Text(
                                      'Approve & Sync Masterlist',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    onPressed: () => _handleApplyWorkflowAction(ctx, currentSub, 'Approve'),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Admin QA Action Bar (Allows testing transitions from any state)
                          if (showAdminOverrides && isApproved) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'Admin Transition Test:',
                                  style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => _handleApplyWorkflowAction(ctx, currentSub, 'Submit for Processing'),
                                  child: const Text('Process', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 11)),
                                ),
                                TextButton(
                                  onPressed: () => _handleApplyWorkflowAction(ctx, currentSub, 'Submit for Approval'),
                                  child: const Text('Submit', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11)),
                                ),
                                TextButton(
                                  onPressed: () => _handleApplyWorkflowAction(ctx, currentSub, 'Approve'),
                                  child: const Text('Approve', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailTabContent(int tabIdx, HcpProfileSubmission submission) {
    switch (tabIdx) {
      case 0: // Step 1 View
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PRIVACY NOTICE AND CONSENT', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Please read the agreement carefully and then sign or take a group photo as proof of consent.',
              style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF27272A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: const Text(
                'I agree that PROFESSIONAL INSIGHTS MARKETING SERVICES (PIMS), including its contracted third parties to contact me through the Contact Details that I provided to PIMS and/or its authorized representative(s) and to collect, store, process and share with PIMS contracted third parties, my Contact Details and my Professional Details for any of the following purposes:\n\n'
                'a. to communicate with me in the manner preferred by PIMS, including through PIMS PROFESSIONAL HEALTH SPECIALISTS REPRESENTATIVES, websites, email, call centers, postal mail, webcasts, and other channels\n\n'
                'b. to provide me with information that I have requested, including scientific data, promotional and marketing communications and/or other information about PIMS products, services and activities\n\n'
                'c. to plan and implement PIMS promotional activities directed to me, including identifying topics and activities that may be of interest to me\n\n'
                'd. to respond to my requests or queries or to seek my views, on PIMS products, services, and activities\n\n'
                'e. to improve PIMS level of service and the content of its communications\n\n'
                'f. for PIMS own administrative and quality assurance purposes\n\n'
                'g. any other purpose that is related to the above list of purposes.\n\n'
                'I further acknowledge that I may obtain more information on the processing by PIMS of my Contact Details and Professional Details by accessing PIMS Privacy Statement at http://pims-marketing.com/privacy\n\n'
                '1. Contact Details: my name, contact number, email address, office address, and office number\n'
                '2. Professional Details: such as my PRC number, professional associations, and medical specialties\n\n'
                'Note: PIMS is registered with the National Privacy Commission. All Data and Personal Details voluntarily provided by data subject are protected under the Data Privacy Act.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: const [
                Icon(Icons.check_box, color: Color(0xFF38BDF8), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '(Please check the box on the left as confirmation)',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('LEGAL NOTICE', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              'By signing or taking a photo, you accept and agree to Company\'s Terms of Use and Privacy Policy. Specifically, you provide your clear consent to: (i) Company\'s collection, use, transfer, and/or processing of any of your personal information...',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 20),

            const Text('Affix signature and/or take a group photo', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Builder(
              builder: (ctx) {
                final apiService = Provider.of<ApiService>(context, listen: false);
                final photoUrl = submission.consentPhoto;
                final sig = submission.consentSignature;

                if (photoUrl != null && photoUrl.isNotEmpty) {
                  final fullUrl = photoUrl.startsWith('http') ? photoUrl : '${apiService.baseUrl}$photoUrl';
                  return Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF3F3F46)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        fullUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('Group Consent Photo Attached', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                      ),
                    ),
                  );
                } else if (sig != null && sig.isNotEmpty) {
                  if (sig.startsWith('http') || sig.startsWith('/files/')) {
                    final fullUrl = sig.startsWith('http') ? sig : '${apiService.baseUrl}$sig';
                    return Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF3F3F46)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          fullUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text('Doctor Consent Signature Attached', style: TextStyle(color: Colors.black54, fontSize: 12)),
                          ),
                        ),
                      ),
                    );
                  } else if (sig.startsWith('data:image')) {
                    try {
                      final bytes = base64Decode(sig.split(',').last.trim());
                      return Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF3F3F46)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(bytes, fit: BoxFit.contain),
                        ),
                      );
                    } catch (_) {}
                  }
                }

                return Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3F3F46)),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.draw_rounded, color: Color(0xFF38BDF8), size: 24),
                        SizedBox(width: 8),
                        Text('Doctor Consent Signature Attached', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );

      case 1: // Step 2 View
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('DOCTOR\'S INFORMATION', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                _buildProfileActionBadge(submission.profileAction),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (ctx) {
                    final apiService = Provider.of<ApiService>(context, listen: false);
                    final docPhoto = submission.hcpPhoto;
                    final fullDocPhotoUrl = (docPhoto != null && docPhoto.isNotEmpty)
                        ? (docPhoto.startsWith('http') ? docPhoto : '${apiService.baseUrl}$docPhoto')
                        : null;

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 110,
                        height: 140,
                        color: const Color(0xFF27272A),
                        child: fullDocPhotoUrl != null
                            ? Image.network(
                                fullDocPhotoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Color(0xFF38BDF8), size: 64),
                              )
                            : const Icon(Icons.person_rounded, color: Color(0xFF38BDF8), size: 64),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReadonlyField('HCP Full Name', (submission.hcpFullName != null && submission.hcpFullName!.isNotEmpty) ? submission.hcpFullName! : (submission.hcpName.isNotEmpty ? submission.hcpName : 'New Doctor')),
                      const SizedBox(height: 10),
                      _buildReadonlyField('HCP Master ID *', submission.hcpName.isNotEmpty ? submission.hcpName : 'Pending Registration (New Doctor)', isMandatory: true),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text('BASIC INFO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildReadonlyField('First Name *', submission.firstName ?? 'N/A', isMandatory: true)),
                const SizedBox(width: 8),
                Expanded(child: _buildReadonlyField('Middle Name *', submission.middleName ?? 'N/A', isMandatory: true)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildReadonlyField('Last Name *', submission.lastName ?? 'N/A', isMandatory: true)),
                const SizedBox(width: 8),
                Expanded(child: _buildReadonlyField('Birth Date', submission.birthDate ?? 'N/A')),
              ],
            ),
            const SizedBox(height: 20),

            const Text('SPECIALIZATION / TYPE / PRACTICE', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildReadonlyField('Type *', LocationResolver.resolveHcpTypeName(submission.hcpType), isMandatory: true)),
                const SizedBox(width: 8),
                Expanded(child: _buildReadonlyField('Practice *', submission.hcpPractice ?? 'Dispensing', isMandatory: true)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF27272A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    color: const Color(0xFF18181B),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Specialty Name', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Sub Specialty Name', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (submission.specialties.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Family Medicine • Sports Medicine', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    )
                  else
                    ...submission.specialties.map((s) => Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(LocationResolver.resolveSpecialtyName(s.specialtyName ?? s.hcpSpecialty).isNotEmpty ? LocationResolver.resolveSpecialtyName(s.specialtyName ?? s.hcpSpecialty) : 'General Practice', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          Text(LocationResolver.resolveSpecialtyName(s.subSpecialtyName ?? s.subSpecialty).isNotEmpty ? LocationResolver.resolveSpecialtyName(s.subSpecialtyName ?? s.subSpecialty) : '-', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    )),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('WORKPLACES / CONTACT INFO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF27272A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    color: const Color(0xFF18181B),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Workplace Name', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Location', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (submission.workplaces.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Manila Doctors Hospital • Ermita', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    )
                  else
                    ...submission.workplaces.map((w) => Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(LocationResolver.resolveInstitutionName(w.workplaceName ?? w.hcpWorkplace).isNotEmpty ? LocationResolver.resolveInstitutionName(w.workplaceName ?? w.hcpWorkplace) : 'Institution', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          Text('${LocationResolver.resolveCityName(w.cityMunicipality ?? w.cityTitle)} ${LocationResolver.resolveProvinceName(w.provinceName ?? w.provinceTitle)}'.trim(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF27272A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    color: const Color(0xFF18181B),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Mobile / Phone Number', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Email Address', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (submission.contacts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('12345 • email@email.com', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    )
                  else
                    ...submission.contacts.map((c) => Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(c.contactNumber ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          Text(c.emailAddress ?? 'None', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          ],
        );

      case 2: // Step 3 View
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SURVEY RESPONSE', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildReadonlyField('Account / Program', submission.accountOrProgram ?? 'COREnergy'),
            const SizedBox(height: 16),
            if (submission.answers.isEmpty)
              const Text('No survey response recorded.', style: TextStyle(color: Colors.white54))
            else
              ...submission.answers.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.questionText, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27272A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(a.answer, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ],
                ),
              )),
          ],
        );

      case 3: // Others View
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReadonlyField('Submission Date (12-Hour)', _formatSubmissionDate12Hr(submission.submissionDate)),
            const SizedBox(height: 6),
            const Text('Asia/Manila (12-Hour Format)', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
            const SizedBox(height: 16),
            _buildReadonlyField('Territory Code', submission.territory ?? 'AD0110'),
            const SizedBox(height: 12),
            _buildReadonlyField('Territory Manager / Medrep', submission.salesPerson ?? submission.medrepEmail ?? 'jptan@profinsights.biz'),
            const SizedBox(height: 12),
            _buildReadonlyField('User ID', submission.userId ?? submission.medrepEmail ?? 'jptan@profinsights.biz'),
            const SizedBox(height: 12),
            _buildReadonlyField('Account / Program', submission.accountOrProgram ?? 'COREnergy'),
            const SizedBox(height: 12),
            _buildReadonlyField('Workflow State', submission.workflowState ?? 'Pending Approval'),
            const SizedBox(height: 12),
            _buildReadonlyField('Application Status', submission.applicationStatus ?? 'Not Applied'),
          ],
        );

      case 4: // Changes View
        Map<String, dynamic>? parsedChanges;
        if (submission.changesJson != null && submission.changesJson!.trim().isNotEmpty) {
          try {
            parsedChanges = jsonDecode(submission.changesJson!);
          } catch (_) {}
        }

        final changesMap = parsedChanges != null && parsedChanges['changes'] is Map ? parsedChanges['changes'] as Map<String, dynamic> : null;
        final basicInfoList = changesMap != null && changesMap['basic_information'] is List ? (changesMap['basic_information'] as List) : [];
        final specAdded = changesMap != null && changesMap['specializations'] is Map && changesMap['specializations']['added'] is List ? (changesMap['specializations']['added'] as List) : [];
        final specRemoved = changesMap != null && changesMap['specializations'] is Map && changesMap['specializations']['removed'] is List ? (changesMap['specializations']['removed'] as List) : [];
        final wpAdded = changesMap != null && changesMap['workplaces'] is Map && changesMap['workplaces']['added'] is List ? (changesMap['workplaces']['added'] as List) : [];
        final wpRemoved = changesMap != null && changesMap['workplaces'] is Map && changesMap['workplaces']['removed'] is List ? (changesMap['workplaces']['removed'] as List) : [];
        final contactAdded = changesMap != null && changesMap['contact_information'] is Map && changesMap['contact_information']['added'] is List ? (changesMap['contact_information']['added'] as List) : [];
        final contactRemoved = changesMap != null && changesMap['contact_information'] is Map && changesMap['contact_information']['removed'] is List ? (changesMap['contact_information']['removed'] as List) : [];
        final bool isNewDoc = submission.hcpName.isEmpty ||
            submission.hcpName == 'NEW-HCP' ||
            (changesMap != null && changesMap['is_new_doctor'] == true) ||
            (submission.changesJson != null && submission.changesJson!.contains('"is_new_doctor":true')) ||
            (submission.changesJson != null && submission.changesJson!.contains('"is_new_doctor": true'));
        final bool isExistingDoc = !isNewDoc;
        final bool hasRecordedChanges = basicInfoList.isNotEmpty ||
            specAdded.isNotEmpty ||
            specRemoved.isNotEmpty ||
            wpAdded.isNotEmpty ||
            wpRemoved.isNotEmpty ||
            contactAdded.isNotEmpty ||
            contactRemoved.isNotEmpty;

        final doctorDisplay = (submission.hcpFullName != null && submission.hcpFullName!.isNotEmpty)
            ? submission.hcpFullName!
            : '${submission.firstName ?? ''} ${submission.lastName ?? ''}'.trim();

        if (isNewDoc) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('New Doctor Information', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: submission.applicationStatus == 'Applied' ? const Color(0xFF059669) : const Color(0xFF3F3F46),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Application: ${submission.applicationStatus ?? "Not Applied"}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Doctor Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF27272A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3F3F46)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF10B981), size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            doctorDisplay.isNotEmpty ? doctorDisplay : 'New Doctor',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: const Text('NEW DOCTOR', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Classification: ${LocationResolver.resolveHcpTypeName(submission.hcpType)} • Practice: ${submission.hcpPractice ?? "Both"}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    if (submission.birthDate != null && submission.birthDate!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Birth Date: ${submission.birthDate}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                    if (submission.accountOrProgram != null && submission.accountOrProgram!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Assigned Program: ${submission.accountOrProgram}', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Specializations List
              if (submission.specialties.isNotEmpty) ...[
                const Text('Specializations', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3F3F46)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        color: const Color(0xFF18181B),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Specialty Name', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('Sub-Specialty', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      ...submission.specialties.map((s) {
                        final rawSpec = s.specialtyName ?? s.hcpSpecialty;
                        final specName = LocationResolver.resolveSpecialtyName(rawSpec);
                        final rawSub = s.subSpecialtyName ?? s.subSpecialty;
                        final subName = LocationResolver.resolveSpecialtyName(rawSub);
                        return Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (s.preferred)
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Primary', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  Text(specName.isNotEmpty ? specName : (rawSpec ?? 'Specialty'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              ),
                              Text(subName.isNotEmpty ? subName : 'None', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Workplaces List
              if (submission.workplaces.isNotEmpty) ...[
                const Text('Workplaces & Locations', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3F3F46)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        color: const Color(0xFF18181B),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Workplace / Institution', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('City & Province', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      ...submission.workplaces.map((w) {
                        final rawWp = w.workplaceName ?? w.hcpWorkplace;
                        final wpName = LocationResolver.resolveInstitutionName(rawWp);
                        final cityName = LocationResolver.resolveCityName(w.cityMunicipality ?? w.cityTitle);
                        final provName = LocationResolver.resolveProvinceName(w.provinceName ?? w.provinceTitle);
                        final locStr = [cityName, provName].where((x) => x.isNotEmpty).join(', ');
                        return Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (w.preferred)
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Primary', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  Text(wpName.isNotEmpty ? wpName : (rawWp ?? 'Institution'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              ),
                              Text(locStr.isNotEmpty ? locStr : 'Location', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Contacts List
              if (submission.contacts.isNotEmpty) ...[
                const Text('Contact Information', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3F3F46)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        color: const Color(0xFF18181B),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Phone Number', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('Email Address', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      ...submission.contacts.map((c) => Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(c.contactNumber ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 13)),
                            Text(c.emailAddress ?? 'None', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Summary of Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: submission.applicationStatus == 'Applied' ? const Color(0xFF059669) : const Color(0xFF3F3F46),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Application: ${submission.applicationStatus ?? "Not Applied"}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (isExistingDoc && !hasRecordedChanges) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('No Changes Recorded', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            'Profile for $doctorDisplay was verified with zero field alterations against the master record.',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Basic Information Changes
            if (basicInfoList.isNotEmpty) ...[
              const Text('Basic Information', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...basicInfoList.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b['label'] ?? b['field'] ?? 'Field', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('From: "${b['old'] ?? ''}" → To: "${b['new'] ?? ''}"', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              )),
              const SizedBox(height: 16),
            ],

            // Specializations Changes
            if (specAdded.isNotEmpty || specRemoved.isNotEmpty) ...[
              const Text('Specializations', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (specAdded.isNotEmpty) ...[
                Row(
                  children: const [
                    Icon(Icons.check, color: Color(0xFF38BDF8), size: 16),
                    SizedBox(width: 6),
                    Text('Added', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                ...specAdded.map((s) {
                  final rawSpec = (s['specialty_name'] ?? s['hcp_specialty'] ?? '').toString();
                  final specName = LocationResolver.resolveSpecialtyName(rawSpec);
                  final rawSub = (s['sub_specialty_name'] ?? s['sub_specialty'] ?? '').toString();
                  final subName = (rawSub != '-' && rawSub.isNotEmpty) ? LocationResolver.resolveSpecialtyName(rawSub) : '';
                  return Padding(
                    padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                    child: Text('Specialty: ${specName.isNotEmpty ? specName : rawSpec}${subName.isNotEmpty ? ', Sub: $subName' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  );
                }),
              ],
              if (specRemoved.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 16),
                    SizedBox(width: 6),
                    Text('Removed', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                ...specRemoved.map((s) {
                  final rawSpec = (s['specialty_name'] ?? s['hcp_specialty'] ?? '').toString();
                  final specName = LocationResolver.resolveSpecialtyName(rawSpec);
                  return Padding(
                    padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                    child: Text('Specialty: ${specName.isNotEmpty ? specName : rawSpec}', style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
                  );
                }),
              ],
              const SizedBox(height: 16),
            ],

            // Workplaces Changes
            if (wpAdded.isNotEmpty || wpRemoved.isNotEmpty) ...[
              const Text('Workplaces', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (wpAdded.isNotEmpty) ...[
                Row(
                  children: const [
                    Icon(Icons.check, color: Color(0xFF38BDF8), size: 16),
                    SizedBox(width: 6),
                    Text('Added', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                ...wpAdded.map((w) {
                  final rawWp = (w['workplace_name'] ?? w['hcp_workplace'] ?? '').toString();
                  final wpName = LocationResolver.resolveInstitutionName(rawWp);
                  final rawProv = (w['province_name'] ?? w['province_title'] ?? '').toString();
                  final provName = LocationResolver.resolveProvinceName(rawProv);
                  return Padding(
                    padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                    child: Text('${wpName.isNotEmpty ? wpName : rawWp}${provName.isNotEmpty ? " ($provName)" : ""}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  );
                }),
              ],
              if (wpRemoved.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 16),
                    SizedBox(width: 6),
                    Text('Removed', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                ...wpRemoved.map((w) {
                  final rawWp = (w['workplace_name'] ?? w['hcp_workplace'] ?? '').toString();
                  final wpName = LocationResolver.resolveInstitutionName(rawWp);
                  return Padding(
                    padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                    child: Text(wpName.isNotEmpty ? wpName : rawWp, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
                  );
                }),
              ],
              const SizedBox(height: 16),
            ],

            // Contact Information Changes
            if (contactAdded.isNotEmpty || contactRemoved.isNotEmpty) ...[
              const Text('Contact Information', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (contactAdded.isNotEmpty) ...[
                Row(
                  children: const [
                    Icon(Icons.check, color: Color(0xFF38BDF8), size: 16),
                    SizedBox(width: 6),
                    Text('Added', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                ...contactAdded.map((c) => Padding(
                  padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                  child: Text('Contact No.: ${c['contact_number'] ?? "N/A"}, Email: ${c['email_address'] ?? "None"}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                )),
              ],
              if (contactRemoved.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 16),
                    SizedBox(width: 6),
                    Text('Removed', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                ...contactRemoved.map((c) => Padding(
                  padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                  child: Text('Contact No.: ${c['contact_number'] ?? "N/A"}, Email: ${c['email_address'] ?? "None"}', style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
                )),
              ],
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 8),
            const Text('Changes JSON', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(parsedChanges ?? {}),
                  style: const TextStyle(color: Color(0xFF38BDF8), fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildReadonlyField(String label, String value, {bool isMandatory = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
            if (isMandatory)
              const Text(' *', style: TextStyle(color: Color(0xFFFF453A), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF27272A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF3F3F46)),
          ),
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(HcpProfileSubmission item) {
    final wf = (item.workflowState ?? item.status ?? '').toLowerCase().trim();
    String displayStatus;
    Color bgColor;

    if (wf.contains('reject') || item.docstatus == 2) {
      displayStatus = 'Rejected';
      bgColor = const Color(0xFFEF4444);
    } else if (wf == 'pending approval' || wf.contains('pend')) {
      displayStatus = 'Pending Approval';
      bgColor = const Color(0xFFD97706);
    } else if (wf == 'approved' || (wf.contains('appr') && !wf.contains('pend')) || item.docstatus == 1) {
      displayStatus = 'Approved';
      bgColor = const Color(0xFF10B981);
    } else if (wf == 'processed' || wf.contains('proc')) {
      displayStatus = 'Processed';
      bgColor = const Color(0xFF475569);
    } else if (wf == 'draft') {
      displayStatus = 'Draft';
      bgColor = const Color(0xFF64748B);
    } else {
      displayStatus = (item.workflowState != null && item.workflowState!.isNotEmpty)
          ? item.workflowState!
          : (item.docstatus == 1 ? 'Approved' : 'Pending Approval');
      bgColor = const Color(0xFFD97706);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayStatus,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildConsentBadge(bool understood) {
    return Center(
      child: understood
          ? const Icon(Icons.check_box_rounded, color: Color(0xFF38BDF8), size: 18)
          : const Icon(Icons.check_box_outline_blank_rounded, color: Color(0xFF94A3B8), size: 18),
    );
  }

  Widget _buildProfileActionBadge(String? profileAction) {
    final raw = (profileAction ?? '').trim();
    final bool isExisting = raw.toLowerCase().contains('exist');
    final String label = isExisting ? 'Existing HCP' : 'New HCP';
    final Color dotColor = isExisting ? const Color(0xFF10B981) : Colors.white;
    const Color badgeBg = Color(0xFF334155);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationStatusBadge(String? applicationStatus) {
    final raw = (applicationStatus ?? '').trim();
    final bool isApplied = raw.toLowerCase() == 'applied' || raw.toLowerCase() == 'processed';
    final String label = raw.isNotEmpty ? raw : 'Not Applied';
    final Color dotColor = isApplied ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8);
    const Color badgeBg = Color(0xFF334155);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

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
              if (apiService.isMedRep) ...[
                InkWell(
                  onTap: () {
                    setState(() {
                      _onlyMySubmissions = !_onlyMySubmissions;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _onlyMySubmissions ? const Color(0xFF0066FF).withOpacity(0.2) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _onlyMySubmissions ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _onlyMySubmissions ? Icons.person_rounded : Icons.groups_rounded,
                          size: 14,
                          color: _onlyMySubmissions ? const Color(0xFF38BDF8) : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _onlyMySubmissions ? 'My Submissions' : 'Program Scope',
                          style: TextStyle(
                            color: _onlyMySubmissions ? const Color(0xFF38BDF8) : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                InkWell(
                  onTap: () {
                    setState(() {
                      _onlyMySubmissions = !_onlyMySubmissions;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _onlyMySubmissions ? const Color(0xFF0066FF).withOpacity(0.2) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _onlyMySubmissions ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _onlyMySubmissions ? Icons.person_rounded : Icons.groups_rounded,
                          size: 14,
                          color: _onlyMySubmissions ? const Color(0xFF38BDF8) : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _onlyMySubmissions ? 'My Submissions' : (apiService.isAdmin ? 'All Scope' : 'Program Scope'),
                          style: TextStyle(
                            color: _onlyMySubmissions ? const Color(0xFF38BDF8) : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
                    value: _sortField,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                    items: const [
                      DropdownMenuItem(value: 'Last Updated On', child: Text('Last Updated On')),
                      DropdownMenuItem(value: 'Name of Doctor', child: Text('Name of Doctor')),
                      DropdownMenuItem(value: 'ID', child: Text('ID')),
                      DropdownMenuItem(value: 'Created On', child: Text('Created On')),
                      DropdownMenuItem(value: 'Status', child: Text('Status')),
                      DropdownMenuItem(value: 'First Name', child: Text('First Name')),
                      DropdownMenuItem(value: 'Middle Name', child: Text('Middle Name')),
                      DropdownMenuItem(value: 'Last Name', child: Text('Last Name')),
                      DropdownMenuItem(value: 'Type', child: Text('Type')),
                      DropdownMenuItem(value: 'Practice', child: Text('Practice')),
                      DropdownMenuItem(value: 'Institution', child: Text('Institution')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _sortField = val;
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
                    width: 130,
                    height: 36,
                    child: TextField(
                      controller: _idFilterCtrl,
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
                    width: 160,
                    height: 36,
                    child: TextField(
                      controller: _doctorNameFilterCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Name of Doctor',
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
                    width: 120,
                    height: 36,
                    child: TextField(
                      controller: _typeFilterCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Type',
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
                        value: _practiceFilter,
                        dropdownColor: const Color(0xFF0F172A),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('Practice: All')),
                          DropdownMenuItem(value: 'Prescribing', child: Text('Prescribing')),
                          DropdownMenuItem(value: 'Dispensing', child: Text('Dispensing')),
                          DropdownMenuItem(value: 'Both', child: Text('Both')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _practiceFilter = val);
                        },
                      ),
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
                          DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                          DropdownMenuItem(value: 'Processed', child: Text('Processed')),
                          DropdownMenuItem(value: 'Pending Approval', child: Text('Pending Approval')),
                          DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                          DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _statusFilter = val);
                        },
                      ),
                    ),
                  ),
                  if (apiService.isAdmin) ...[
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
                          value: _programFilter,
                          dropdownColor: const Color(0xFF0F172A),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('Program: All')),
                            ...apiService.availablePrograms.map((p) => DropdownMenuItem(value: p, child: Text(p))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _programFilter = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);
    final filteredList = _getFilteredAndSortedSubmissions(apiService);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('HCP Profile Submissions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0B192C),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.white.withOpacity(0.3),
            height: 1.0,
          ),
        ),
        actions: [
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
              apiService.userDesignationTitle,
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
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadSubmissions,
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: const AppDrawer(currentItem: DrawerItem.submissionsFact),
      body: Column(
        children: [
          _buildFilterAndSortBar(apiService),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 650;
                return Column(
                  children: [
                    if (!isMobile)
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
                              const Icon(Icons.check_box_outline_blank_rounded, size: 16, color: Colors.white54),
                              const SizedBox(width: 10),
                              const Expanded(
                                flex: 5,
                                child: Text('HCP Full Name', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              Container(width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 6)),
                              const Expanded(
                                flex: 3,
                                child: Text('Status', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              Container(width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 6)),
                              const SizedBox(
                                width: 55,
                                child: Center(
                                  child: Text('Consent', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              Container(width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 6)),
                              const Expanded(
                                flex: 3,
                                child: Text('Profile Action', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              Container(width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 6)),
                              const Expanded(
                                flex: 3,
                                child: Text('Application Status', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              Container(width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 6)),
                              const Expanded(
                                flex: 4,
                                child: Text('Submission Date', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              Container(width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 6)),
                              const Expanded(
                                flex: 3,
                                child: Text('ID', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              Container(width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 6)),
                              SizedBox(
                                width: 55,
                                child: Text(
                                  '${filteredList.length} of ${_getProgramTotalCount(apiService)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: const Color(0xFF0B192C),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('SUBMISSIONS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(
                              apiService.isMedRep && _onlyMySubmissions
                                  ? 'Showing ${filteredList.length} (My Submissions) · Total: ${_getProgramTotalCount(apiService)}'
                                  : 'Showing ${filteredList.length} of ${_getProgramTotalCount(apiService)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0066FF)))
                          : filteredList.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inbox_rounded, size: 64, color: const Color(0xFF0066FF).withOpacity(0.3)),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No matching HCP Profile Submissions found.',
                                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadSubmissions,
                                  color: const Color(0xFF0066FF),
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    itemCount: filteredList.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                                    itemBuilder: (ctx, idx) {
                                      final item = filteredList[idx];
                                      if (isMobile) {
                                        return Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                            boxShadow: const [
                                              BoxShadow(color: Color(0x04000000), blurRadius: 3, offset: Offset(0, 1)),
                                            ],
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(10),
                                            onTap: () => _showSubmissionDetail(item),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          item.hcpFullName ?? item.hcpName,
                                                          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13.5),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      _buildStatusBadge(item),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    crossAxisAlignment: WrapCrossAlignment.center,
                                                    children: [
                                                      _buildProfileActionBadge(item.profileAction),
                                                      _buildApplicationStatusBadge(item.applicationStatus),
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Text('Consent: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                                          _buildConsentBadge(item.consentPrivacyUnderstood),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF64748B)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _formatSubmissionDate12Hr(item.submissionDate),
                                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                                                      ),
                                                      const Spacer(),
                                                      Text(
                                                        item.name ?? '',
                                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'monospace'),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      return Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                        ),
                                        child: InkWell(
                                          onTap: () => _showSubmissionDetail(item),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.check_box_outline_blank_rounded, size: 16, color: Color(0xFF94A3B8)),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  flex: 5,
                                                  child: Text(
                                                    item.hcpFullName ?? item.hcpName,
                                                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  flex: 3,
                                                  child: Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: _buildStatusBadge(item),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                SizedBox(
                                                  width: 55,
                                                  child: _buildConsentBadge(item.consentPrivacyUnderstood),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  flex: 3,
                                                  child: Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: _buildProfileActionBadge(item.profileAction),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  flex: 3,
                                                  child: Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: _buildApplicationStatusBadge(item.applicationStatus),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    _formatSubmissionDate12Hr(item.submissionDate),
                                                    style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    item.name ?? '',
                                                    style: const TextStyle(color: Color(0xFF64748B), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                const SizedBox(width: 55),
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
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0B192C),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add HCP Profile Submission', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _startNewSubmission,
      ),
    );
  }
}
