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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final tabTitles = ['Step 1', 'Step 2', 'Step 3', 'Others', 'Changes'];

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (ctx, scrollController) => Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF0066FF).withOpacity(0.1),
                        child: const Icon(Icons.assignment_rounded, color: Color(0xFF0066FF), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              submission.hcpFullName ?? submission.hcpName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              submission.name ?? 'Submission Detail',
                              style: const TextStyle(color: Color(0xFF64748B), fontFamily: 'monospace', fontSize: 12),
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
                ),

                // Tab Bar
                Container(
                  color: const Color(0xFF0B192C),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(tabTitles.length, (idx) {
                      final isSelected = activeDetailTab == idx;
                      return GestureDetector(
                        onTap: () => setModalState(() => activeDetailTab = idx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF0066FF) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tabTitles[idx],
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
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
      case 0: // Step 1
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Privacy Notice & Consent Status'),
            _detailRow('Consent Confirmed', submission.consentPrivacyUnderstood ? 'Agreed & Confirmed' : 'Refused / Pending'),
            if (submission.consentSignature != null) ...[
              const SizedBox(height: 12),
              _buildSectionTitle('Doctor Signature'),
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Icon(Icons.gesture_rounded, color: Color(0xFF0066FF), size: 36)),
              ),
            ],
            if (submission.consentPhoto != null) ...[
              const SizedBox(height: 12),
              _buildSectionTitle('Proof Photo'),
              const Icon(Icons.camera_alt_rounded, color: Color(0xFF64748B), size: 36),
            ],
          ],
        );
      case 1: // Step 2
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Doctor Information'),
            _detailRow('Doctor Full Name', submission.hcpFullName ?? submission.hcpName),
            _detailRow('First Name', submission.firstName ?? 'N/A'),
            _detailRow('Middle Name', submission.middleName ?? 'N/A'),
            _detailRow('Last Name', submission.lastName ?? 'N/A'),
            _detailRow('Birth Date', submission.birthDate ?? 'N/A'),
            _detailRow('HCP Type', submission.hcpType ?? 'N/A'),
            _detailRow('Practice Mode', submission.hcpPractice ?? 'N/A'),

            if (submission.specialties.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionTitle('Specialties'),
              ...submission.specialties.map((s) => _bulletItem('${s.specialtyName ?? s.hcpSpecialty ?? ""} ${s.subSpecialtyName != null ? "(${s.subSpecialtyName})" : ""}')),
            ],

            if (submission.workplaces.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionTitle('Workplaces'),
              ...submission.workplaces.map((w) => _bulletItem('${w.workplaceName ?? w.hcpWorkplace ?? ""} ${w.cityTitle != null ? "• ${w.cityTitle}" : ""}')),
            ],

            if (submission.contacts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionTitle('Contacts'),
              ...submission.contacts.map((c) => _bulletItem('${c.contactNumber ?? "No Phone"} • ${c.emailAddress ?? "No Email"}')),
            ],
          ],
        );
      case 2: // Step 3
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Survey Responses'),
            _detailRow('Account / Program', submission.accountOrProgram ?? 'COREnergy'),
            _detailRow('Survey Template', submission.surveyTemplateTitle ?? submission.surveyTemplate ?? 'Standard Survey'),
            const SizedBox(height: 12),
            if (submission.answers.isEmpty)
              const Text('No survey questions recorded.', style: TextStyle(color: Color(0xFF64748B)))
            else
              ...submission.answers.map((a) => _bulletItem('${a.questionText}: ${a.answer}')),
          ],
        );
      case 3: // Others
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Territory & Tracking Details'),
            _detailRow('Territory Code', 'AD0110'),
            _detailRow('MedRep Email', submission.medrepEmail ?? 'N/A'),
            _detailRow('Submission Date', submission.submissionDate ?? 'N/A'),
            _detailRow('Application Status', submission.applicationStatus ?? 'Not Applied'),
          ],
        );
      case 4: // Changes
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Summary of Record Changes'),
            _detailRow('Application Status', submission.applicationStatus ?? 'Not Applied'),
            const SizedBox(height: 12),
            if (submission.changeSummaryHtml != null && submission.changeSummaryHtml!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBE6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFD591)),
                ),
                child: Text(
                  submission.changeSummaryHtml!.replaceAll(RegExp(r'<[^>]*>'), ' '),
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                ),
              ),
            if (submission.changesJson != null && submission.changesJson!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B192C),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _formatChangesJson(submission.changesJson!),
                  style: const TextStyle(color: Color(0xFF38BDF8), fontFamily: 'monospace', fontSize: 12),
                ),
              ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFF0066FF), fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _bulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF0066FF), fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13))),
        ],
      ),
    );
  }

  String _formatChangesJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return jsonStr;
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
        ],
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
                            item.hcpFullName ?? item.hcpName,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('${item.hcpType ?? "HCP"} • ${item.submissionDate ?? "No date"}',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                              if (item.changeSummaryHtml != null || item.changesJson != null) ...[
                                const SizedBox(height: 4),
                                const Text('🔍 Has ERPNext IT Changes',
                                    style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
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
