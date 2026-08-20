import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/submission.dart';
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
  bool _onlyMySubmissions = true;

  @override
  void initState() {
    super.initState();
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

  List<HcpProfileSubmission> _getFilteredAndSortedSubmissions(ApiService apiService) {
    List<HcpProfileSubmission> list = List.from(_submissions);

    // Program-level isolation (Manager / Rep only views their assigned program)
    if (apiService.selectedProgram.isNotEmpty && apiService.selectedProgram != 'All') {
      final prog = apiService.selectedProgram.toLowerCase().trim();
      list = list.where((item) {
        final subProg = (item.accountOrProgram ?? '').toLowerCase().trim();
        if (subProg.isEmpty) return true;
        return subProg.contains(prog) || prog.contains(subProg);
      }).toList();
    }

    if (apiService.isMedRep && _onlyMySubmissions) {
      final email = (apiService.loggedInEmail ?? '').toLowerCase().trim();
      final fullName = (apiService.loggedInFullName ?? '').toLowerCase().trim();
      final mySubs = list.where((item) {
        final sEmail = (item.medrepEmail ?? item.userId ?? '').toLowerCase().trim();
        final sSales = (item.salesPerson ?? '').toLowerCase().trim();
        if (sEmail.isNotEmpty && email.isNotEmpty && (sEmail == email || email.contains(sEmail) || sEmail.contains(email))) return true;
        if (sSales.isNotEmpty && fullName.isNotEmpty && (sSales.contains(fullName) || fullName.contains(sSales))) return true;
        return false;
      }).toList();

      if (mySubs.isNotEmpty) {
        list = mySubs;
      }
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
        final wf = (item.workflowState ?? item.status ?? '').toLowerCase();
        final isPending = wf.contains('pend') || wf.contains('draft') || item.docstatus == 0;

        if (_statusFilter == 'Pending Approval') {
          return isPending;
        } else if (_statusFilter == 'Approved') {
          return !isPending || wf.contains('appr') || item.docstatus == 1;
        }
        return true;
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
          final tabTitles = ['Step 1', 'Step 2', 'Step 3', 'Others', 'Changes'];

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
                // ERPNext Blue Workflow Notification Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0284C7),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'This form is not editable due to a Workflow.',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),

                // Dark Workflow Tab Bar
                Container(
                  color: const Color(0xFF09090B),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(tabTitles.length, (idx) {
                        final isSelected = activeDetailTab == idx;
                        return GestureDetector(
                          onTap: () => setModalState(() => activeDetailTab = idx),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF27272A) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected ? Border.all(color: const Color(0xFF3F3F46)) : null,
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

                // Manager / Admin Approval Action Footer Bar
                Builder(
                  builder: (footerCtx) {
                    final apiService = Provider.of<ApiService>(context, listen: false);
                    final isPending = (currentSub.workflowState?.toLowerCase().contains('pend') ?? false) || currentSub.docstatus == 0;
                    if (!(apiService.isAdmin || apiService.isManager) || !isPending) {
                      return const SizedBox();
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF18181B),
                        border: Border(top: BorderSide(color: Color(0xFF27272A))),
                      ),
                      child: Row(
                        children: [
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
                                if (confirm == true && currentSub.name != null) {
                                  try {
                                    await apiService.rejectSubmission(currentSub.name!);
                                    if (mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          backgroundColor: Color(0xFFDC2626),
                                          content: Text('HCP Profile Submission rejected.'),
                                        ),
                                      );
                                      _loadSubmissions();
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to reject: $e')),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              onPressed: () async {
                                try {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (loadingCtx) => const Center(
                                      child: CircularProgressIndicator(color: Color(0xFF16A34A)),
                                    ),
                                  );
                                  await apiService.approveSubmission(currentSub);
                                  if (mounted) {
                                    Navigator.pop(context); // Close loading indicator
                                    Navigator.pop(ctx); // Close detail modal
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Color(0xFF16A34A),
                                        content: Text('Submission Approved! Doctor registered in Masterlist and synced to HCP Account.'),
                                      ),
                                    );
                                    _loadSubmissions();
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    Navigator.pop(context); // Close loading indicator
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to approve: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
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
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF27272A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.gesture_rounded, color: Color(0xFF38BDF8), size: 36),
                    SizedBox(height: 6),
                    Text('Doctor Consent Signature Attached', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        );

      case 1: // Step 2 View
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DOCTOR\'S INFORMATION', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 110,
                    height: 140,
                    color: const Color(0xFF27272A),
                    child: const Icon(Icons.person_rounded, color: Color(0xFF38BDF8), size: 64),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReadonlyField('HCP Full Name', submission.hcpFullName ?? submission.hcpName),
                      const SizedBox(height: 10),
                      _buildReadonlyField('HCP *', submission.hcpName, isMandatory: true),
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
                Expanded(child: _buildReadonlyField('Type *', submission.hcpType ?? 'Resident', isMandatory: true)),
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
                          Text(s.specialtyName ?? s.hcpSpecialty ?? 'General Practice', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          Text(s.subSpecialtyName ?? s.subSpecialty ?? '-', style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                          Text(w.workplaceName ?? w.hcpWorkplace ?? 'Institution', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          Text('${w.cityMunicipality ?? w.cityTitle ?? ''} ${w.provinceName ?? w.provinceTitle ?? ''}'.trim(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
            _buildReadonlyField('Submission Date', submission.submissionDate ?? 'N/A'),
            const SizedBox(height: 6),
            const Text('Asia/Manila', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
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
        final bool isExistingDoc = submission.hcpName.isNotEmpty;
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
            ] else if (!isExistingDoc) ...[
              const Text('New Doctor Registration', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('Doctor: $doctorDisplay (${submission.hcpType ?? 'HCP Type'})', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
              const SizedBox(height: 16),
            ],

            // Specializations Changes
            if (specAdded.isNotEmpty || specRemoved.isNotEmpty || (!isExistingDoc && submission.specialties.isNotEmpty)) ...[
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
                ...specAdded.map((s) => Padding(
                  padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                  child: Text('Specialty: ${s['specialty_name'] ?? s['hcp_specialty'] ?? ''}${s['sub_specialty'] != null ? ', Sub: ${s['sub_specialty']}' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                )),
              ] else if (!isExistingDoc && submission.specialties.isNotEmpty) ...[
                Row(
                  children: const [
                    Icon(Icons.check, color: Color(0xFF38BDF8), size: 16),
                    SizedBox(width: 6),
                    Text('Specialties Linked', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                ...submission.specialties.map((s) => Padding(
                  padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                  child: Text('Specialty: ${s.specialtyName ?? s.hcpSpecialty ?? 'SPEC-00003'}${s.subSpecialty != null ? ', Sub: ${s.subSpecialty}' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                )),
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
                ...specRemoved.map((s) => Padding(
                  padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                  child: Text('Specialty: ${s['specialty_name'] ?? s['hcp_specialty'] ?? ''}', style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
                )),
              ],
              const SizedBox(height: 16),
            ],

            // Workplaces Changes
            if (wpAdded.isNotEmpty || wpRemoved.isNotEmpty || (!isExistingDoc && submission.workplaces.isNotEmpty)) ...[
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
                ...wpAdded.map((w) => Padding(
                  padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                  child: Text('${w['workplace_name'] ?? w['hcp_workplace'] ?? 'INST-00001'}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                )),
              ] else if (!isExistingDoc && submission.workplaces.isNotEmpty) ...[
                Row(
                  children: const [
                    Icon(Icons.check, color: Color(0xFF38BDF8), size: 16),
                    SizedBox(width: 6),
                    Text('Workplaces Linked', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                ...submission.workplaces.map((w) => Padding(
                  padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                  child: Text('${w.workplaceName ?? w.hcpWorkplace ?? 'INST-00001'}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                )),
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
                ...wpRemoved.map((w) => Padding(
                  padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                  child: Text('${w['workplace_name'] ?? w['hcp_workplace'] ?? ''}', style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
                )),
              ],
              const SizedBox(height: 16),
            ],

            // Contact Information Changes
            if (contactAdded.isNotEmpty || contactRemoved.isNotEmpty || (!isExistingDoc && submission.contacts.isNotEmpty)) ...[
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
              ] else if (!isExistingDoc && submission.contacts.isNotEmpty) ...[
                Row(
                  children: const [
                    Icon(Icons.check, color: Color(0xFF38BDF8), size: 16),
                    SizedBox(width: 6),
                    Text('Contacts Linked', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                ...submission.contacts.map((c) => Padding(
                  padding: const EdgeInsets.only(left: 22.0, bottom: 4.0),
                  child: Text('Contact No.: ${c.contactNumber ?? "N/A"}, Email: ${c.emailAddress ?? "None"}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
    final bool isPending = wf.contains('pend') || wf.contains('draft') || item.docstatus == 0;

    final String displayStatus = isPending ? 'Pending Approval' : 'Approved';
    final Color bgColor = isPending ? const Color(0xFF6B7280) : const Color(0xFF10B981); // (color gray) pending approval, (color green) approved

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        displayStatus,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
              if (apiService.isMedRep) ...[
                const SizedBox(width: 8),
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
                          _onlyMySubmissions ? 'My Submissions' : 'All Scope',
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
                          DropdownMenuItem(value: 'Pending Approval', child: Text('Pending Approval')),
                          DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _statusFilter = val);
                        },
                      ),
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
                    flex: 3,
                    child: Text('ID', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                  const Expanded(
                    flex: 4,
                    child: Text('Name of Doctor', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                  const Expanded(
                    flex: 2,
                    child: Text('Type', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                  const Expanded(
                    flex: 3,
                    child: Text('Submission Date', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                  const Expanded(
                    flex: 3,
                    child: Text('Status', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                  SizedBox(
                    width: 45,
                    child: Text(
                      '${filteredList.length} of ${_submissions.length}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),

          // Clean White Card Rows for Unified Interface
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
                                      // ID
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          item.name ?? 'HCP-PROF-2026-00030',
                                          style: const TextStyle(color: Color(0xFF64748B), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // Name of Doctor
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          item.hcpFullName ?? item.hcpName,
                                          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // Type
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item.hcpType ?? 'HCP',
                                          style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // Submission Date
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          item.submissionDate ?? 'No date',
                                          style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // Status Badge
                                      Expanded(
                                        flex: 3,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: _buildStatusBadge(item),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0B192C),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add HCP Profile Submission', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _startNewSubmission,
      ),
    );
  }
}
