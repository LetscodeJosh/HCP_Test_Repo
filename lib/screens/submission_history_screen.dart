import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/submission.dart';
import '../models/hcp.dart';
import '../services/api_service.dart';
import 'hcp_wizard_screen.dart';
import 'doctor_masterlist_screen.dart';
import 'login_screen.dart';

class SubmissionHistoryScreen extends StatefulWidget {
  const SubmissionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<SubmissionHistoryScreen> createState() => _SubmissionHistoryScreenState();
}

class _SubmissionHistoryScreenState extends State<SubmissionHistoryScreen> {
  List<HcpProfileSubmission> _submissions = [];
  List<Hcp> _doctors = [];
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
      final doctors = await apiService.fetchDoctors();
      setState(() {
        _submissions = items;
        _doctors = doctors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load submissions: $e')),
        );
      }
    }
  }

  void _startNewSubmission() {
    if (_doctors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No doctors available. Please register a doctor first.')),
      );
      return;
    }

    Hcp selectedDoc = _doctors.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New HCP Profile Submission', style: TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Target Doctor (HCP) for Profiling Submission:', style: TextStyle(color: Color(0xFF636366), fontSize: 13)),
            const SizedBox(height: 12),
            DropdownButtonFormField<Hcp>(
              value: selectedDoc,
              dropdownColor: Colors.white,
              style: const TextStyle(color: Color(0xFF1C1C1E)),
              decoration: const InputDecoration(
                labelText: 'Doctor (HCP)',
                labelStyle: TextStyle(color: Color(0xFF0056B3)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFD1D1D6))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0056B3), width: 2)),
              ),
              items: _doctors.map((d) {
                return DropdownMenuItem<Hcp>(
                  value: d,
                  child: Text('Dr. ${d.firstName} ${d.lastName} (${d.name})'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) selectedDoc = val;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF636366))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0056B3)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HcpWizardScreen(doctor: selectedDoc)),
              ).then((_) => _loadSubmissions());
            },
            child: const Text('Start Wizard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSubmissionDetail(HcpProfileSubmission submission) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
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
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF0056B3).withOpacity(0.1),
                    child: const Icon(Icons.assignment, color: Color(0xFF0056B3), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission.hcpFullName ?? submission.hcpName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
                        ),
                        Text(
                          submission.name ?? 'Submission Detail',
                          style: const TextStyle(color: Color(0xFF8E8E93), fontFamily: 'monospace', fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Basic Info'),
              _detailRow('Doctor Name', submission.hcpFullName ?? submission.hcpName),
              _detailRow('HCP Type', submission.hcpType ?? 'N/A'),
              _detailRow('Practice', submission.hcpPractice ?? 'N/A'),
              _detailRow('Submission Date', submission.submissionDate ?? 'N/A'),
              _detailRow('Privacy Consent', submission.consentPrivacyUnderstood ? 'Agreed' : 'Refused'),
              if (submission.applicationStatus != null)
                _detailRow('Application Status', submission.applicationStatus!),

              if (submission.changeSummaryHtml != null || submission.changesJson != null) ...[
                const SizedBox(height: 20),
                _buildSectionTitle('Record Changes History (ERPNext v15)'),
                if (submission.changeSummaryHtml != null && submission.changeSummaryHtml!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBE6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFD591)),
                    ),
                    child: Text(
                      submission.changeSummaryHtml!.replaceAll(RegExp(r'<[^>]*>'), ' '),
                      style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 13),
                    ),
                  ),
                if (submission.changesJson != null && submission.changesJson!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _formatChangesJson(submission.changesJson!),
                      style: const TextStyle(color: Color(0xFF30D158), fontFamily: 'monospace', fontSize: 12),
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
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/medical_bg.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: const Icon(Icons.donut_large, color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'PIMS HCP',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Provider.of<ApiService>(context, listen: false).loggedInEmail ?? '',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Consumer<ApiService>(
                  builder: (context, api, child) {
                    return DropdownButtonFormField<String>(
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xFF1C1C1E)),
                      value: api.selectedProgram,
                      decoration: const InputDecoration(
                        labelText: 'Active Program',
                        labelStyle: TextStyle(color: Color(0xFF0056B3), fontWeight: FontWeight.bold),
                        prefixIcon: Icon(Icons.business_center, color: Color(0xFF0056B3)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFD1D1D6)),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF0056B3), width: 2),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      items: api.availablePrograms.map((prog) {
                        return DropdownMenuItem<String>(
                          value: prog,
                          child: Text(prog),
                        );
                      }).toList(),
                      onChanged: (newProg) {
                        if (newProg != null) {
                          api.setProgram(newProg);
                          _loadSubmissions();
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.assignment_turned_in, color: Color(0xFF0056B3)),
                title: const Text('HCP Profile Submissions', style: TextStyle(color: Color(0xFF0056B3), fontWeight: FontWeight.bold)),
                selected: true,
                selectedTileColor: const Color(0xFF0056B3).withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.people_alt, color: Color(0xFF1C1C1E)),
                title: const Text('HCP Masterlist', style: TextStyle(color: Color(0xFF1C1C1E))),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorMasterlistScreen()));
                },
              ),
              const Spacer(),
              const Divider(color: Color(0xFFD1D1D6)),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFFF3B30)),
                title: const Text('Logout', style: TextStyle(color: Color(0xFFFF3B30))),
                onTap: () {
                  Provider.of<ApiService>(context, listen: false).logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0056B3),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add HCP Profile Submission', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _startNewSubmission,
      ),
    );
  }
}
