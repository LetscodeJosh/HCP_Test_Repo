import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/submission.dart';
import '../services/api_service.dart';

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
      final allSubmissions = await apiService.fetchSubmissions();
      final myEmail = apiService.loggedInEmail;
      setState(() {
        _submissions = myEmail != null
            ? allSubmissions.where((s) => s.medrepEmail == myEmail || s.medrepEmail == null).toList()
            : allSubmissions;
        _submissions.sort((a, b) => (b.name ?? '').compareTo(a.name ?? ''));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading submissions: $e')),
      );
    }
  }

  String _statusLabel(int docstatus, String? appStatus) {
    if (appStatus != null && appStatus.isNotEmpty) {
      return appStatus;
    }
    switch (docstatus) {
      case 0:
        return 'Draft';
      case 1:
        return 'Submitted';
      case 2:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color _statusColor(int docstatus, String? appStatus) {
    if (appStatus == 'Applied') return const Color(0xFF30D158);
    if (appStatus == 'Applying') return const Color(0xFF007AFF);
    if (appStatus == 'Failed') return const Color(0xFFFF453A);
    switch (docstatus) {
      case 0:
        return const Color(0xFFFF9F0A);
      case 1:
        return const Color(0xFF30D158);
      case 2:
        return const Color(0xFFFF453A);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  void _showSubmissionDetail(HcpProfileSubmission submission) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(submission.docstatus, submission.applicationStatus).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel(submission.docstatus, submission.applicationStatus),
                      style: TextStyle(
                        color: _statusColor(submission.docstatus, submission.applicationStatus),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    submission.name ?? '',
                    style: const TextStyle(color: Color(0xFF8E8E93), fontFamily: 'monospace', fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                submission.hcpFullName ?? submission.hcpName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
              ),
              const SizedBox(height: 16),
              _buildSectionTitle('General Information'),
              _detailRow('Doctor ID (HCP)', submission.hcpName),
              _detailRow('First Name', submission.firstName ?? 'N/A'),
              _detailRow('Middle Name', submission.middleName ?? 'N/A'),
              _detailRow('Last Name', submission.lastName ?? 'N/A'),
              _detailRow('HCP Type', submission.hcpType ?? 'N/A'),
              _detailRow('Practice Mode', submission.hcpPractice ?? 'N/A'),
              _detailRow('Submission Date', submission.submissionDate ?? 'N/A'),
              _detailRow('MedRep Email', submission.medrepEmail ?? 'N/A'),

              // Changes View Section (IT Manager updates from ERPNext)
              if (submission.changeSummaryHtml != null || submission.changesJson != null) ...[
                const SizedBox(height: 20),
                _buildSectionTitle('🔍 Record Changes History'),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFD54F)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (submission.changeSummaryHtml != null)
                        Text(
                          submission.changeSummaryHtml!.replaceAll(RegExp(r'<[^>]*>'), ''),
                          style: const TextStyle(color: Color(0xFF5D4037), fontSize: 13, height: 1.4),
                        ),
                      if (submission.changesJson != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _formatChangesJson(submission.changesJson!),
                          style: const TextStyle(color: Color(0xFF37474F), fontFamily: 'monospace', fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              if (submission.specialties.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildSectionTitle('Specialties'),
                ...submission.specialties.map((s) => _bulletItem('${s.specialtyName ?? s.hcpSpecialty ?? ""} ${s.subSpecialtyName != null ? "(${s.subSpecialtyName})" : ""}')),
              ],

              if (submission.workplaces.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildSectionTitle('Workplaces'),
                ...submission.workplaces.map((w) => _bulletItem('${w.workplaceName ?? w.hcpWorkplace ?? ""} ${w.cityTitle != null ? "• ${w.cityTitle}" : ""}')),
              ],

              if (submission.answers.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildSectionTitle('Survey Responses'),
                ...submission.answers.map((a) => _bulletItem('${a.questionText}: ${a.answer}')),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056B3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFF0056B3), fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _bulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF0056B3), fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 14))),
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
          Text(label, style: const TextStyle(color: Color(0xFF636366), fontSize: 13)),
          Text(value, style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('HCP Profile Submissions'),
        backgroundColor: const Color(0xFF0056B3),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSubmissions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0056B3))),
            )
          : _submissions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: const Color(0xFF0056B3).withOpacity(0.2)),
                      const SizedBox(height: 16),
                      const Text(
                        'No HCP Profile Submissions found.',
                        style: TextStyle(color: Color(0xFF1C1C1E), fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSubmissions,
                  color: const Color(0xFF0056B3),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _submissions.length,
                    itemBuilder: (ctx, idx) {
                      final item = _submissions[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1.5,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF0056B3).withOpacity(0.08),
                            child: const Icon(Icons.assignment, color: Color(0xFF0056B3)),
                          ),
                          title: Text(
                            item.hcpFullName ?? item.hcpName,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('${item.hcpType ?? "HCP"} • ${item.submissionDate ?? "No date"}',
                                  style: const TextStyle(color: Color(0xFF636366), fontSize: 12)),
                              if (item.changeSummaryHtml != null || item.changesJson != null) ...[
                                const SizedBox(height: 4),
                                const Text('🔍 Has ERPNext IT Changes',
                                    style: TextStyle(color: Color(0xFFFF9500), fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ],
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                          onTap: () => _showSubmissionDetail(item),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
