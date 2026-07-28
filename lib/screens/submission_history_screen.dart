import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/submission.dart';
import '../models/hcp.dart';
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

  void _startNewSubmission() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HcpWizardScreen()),
    ).then((_) => _loadSubmissions());
  }

  void _showSubmissionDetail(HcpProfileSubmission submission) {
    int activeDetailTab = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final tabTitles = ['Step 1', 'Step 2', 'Step 3', 'Others', 'Changes'];

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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(tabTitles.length, (idx) {
                      final isSelected = activeDetailTab == idx;
                      return GestureDetector(
                        onTap: () => setModalState(() => activeDetailTab = idx),
                        child: Container(
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

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildDetailTabContent(activeDetailTab, submission),
                  ),
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
      case 0: // Step 1 View (Matching Screenshot 1)
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

      case 1: // Step 2 View (Matching Screenshot 2)
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
                          Text(w.workplaceName ?? w.hcpWorkplace ?? 'Hospital', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          Text(w.cityTitle ?? 'Manila', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          ],
        );

      case 2: // Step 3 View (Matching Screenshot 3)
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

      case 3: // Others View (Matching Screenshot 4)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReadonlyField('Submission Date', submission.submissionDate ?? '07-24-2026 10:41:54'),
            const SizedBox(height: 6),
            const Text('Asia/Manila', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
            const SizedBox(height: 16),
            _buildReadonlyField('Territory Code', 'AD0110'),
            const SizedBox(height: 12),
            _buildReadonlyField('Medrep Email Address', submission.medrepEmail ?? 'jptan@profinsights.biz'),
          ],
        );

      case 4: // Changes View (Matching Screenshot 5)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Summary of Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Contact Information', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: const [
                Icon(Icons.check, color: Color(0xFF38BDF8), size: 18),
                SizedBox(width: 6),
                Text('Added', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 24.0, top: 4.0),
              child: Text('Contact No.: 123435, Email: None', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            const SizedBox(height: 20),

            const Text('Changes JSON', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF27272A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                submission.changesJson ?? '{"submission": "${submission.name ?? 'HCP-PROF-2026-00030'}", "hcp": "${submission.hcpName}"}',
                style: const TextStyle(color: Color(0xFF38BDF8), fontFamily: 'monospace', fontSize: 11),
              ),
            ),
            const SizedBox(height: 16),
            _buildReadonlyField('Application Status', submission.applicationStatus ?? 'Applied'),
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
    final rawStatus = item.status ?? item.workflowState ?? item.applicationStatus ?? (item.docstatus == 1 ? 'Approved' : (item.docstatus == 2 ? 'Rejected' : 'Pending Approval'));

    Color bg;
    Color fg = Colors.white;
    String label;

    final sLower = rawStatus.toLowerCase().trim();
    if (sLower.contains('reject') || sLower.contains('cancel') || item.docstatus == 2) {
      bg = const Color(0xFFDC2626);
      label = 'Rejected';
    } else if (sLower.contains('pend') || sLower.contains('draft') || item.docstatus == 0) {
      bg = const Color(0xFF6B7280);
      label = 'Pending Approval';
    } else if (sLower.contains('approved') || sLower.contains('applied') || item.docstatus == 1) {
      bg = const Color(0xFF16A34A);
      label = 'Approved';
    } else {
      bg = const Color(0xFF6B7280);
      label = rawStatus.isNotEmpty ? rawStatus : 'Pending Approval';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('HCP Profile Submissions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0B192C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadSubmissions,
          ),
        ],
      ),
      drawer: const AppDrawer(currentItem: DrawerItem.submissionsFact),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0B192C)))
          : _submissions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_rounded, size: 64, color: const Color(0xFF0066FF).withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text(
                        'No HCP Profile Submissions found.',
                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSubmissions,
                  color: const Color(0xFF0B192C),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _submissions.length,
                    itemBuilder: (ctx, idx) {
                      final item = _submissions[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF0066FF).withOpacity(0.1),
                            child: const Icon(Icons.assignment_rounded, color: Color(0xFF0066FF)),
                          ),
                          title: Text(
                            item.name ?? 'HCP-PROF-2026-00030',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF0F172A), fontSize: 14),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(item.hcpFullName ?? item.hcpName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('${item.hcpType ?? "HCP"} • ${item.submissionDate ?? "No date"}',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildStatusBadge(item),
                            ],
                          ),
                          onTap: () => _showSubmissionDetail(item),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0066FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add HCP Profile Submission', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _startNewSubmission,
      ),
    );
  }
}
