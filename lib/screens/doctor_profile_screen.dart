import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/hcp.dart';
import '../models/submission.dart';
import '../models/lookup_models.dart';
import '../services/api_service.dart';
import 'hcp_wizard_screen.dart';
import 'self_service_qr_screen.dart';

class DoctorProfileScreen extends StatefulWidget {
  final Hcp doctor;

  const DoctorProfileScreen({Key? key, required this.doctor}) : super(key: key);

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  Hcp? _fullDoctor;
  List<HcpProfileSubmission> _profilingHistory = [];
  List<HcpType> _hcpTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFullDetails();
  }

  Future<void> _loadFullDetails() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      // Fetch full doctor details including all child tables
      final fullDoc = await apiService.fetchDoctorDetail(widget.doctor.name!);
      // Fetch HCP Types for label resolution
      final types = await apiService.fetchHcpTypes();
      // Fetch profiling history for this doctor
      final allSubmissions = await apiService.fetchSubmissions();
      final history = allSubmissions
          .where((s) => s.hcpName == widget.doctor.name)
          .toList()
        ..sort((a, b) => (b.name ?? '').compareTo(a.name ?? ''));

      setState(() {
        _fullDoctor = fullDoc;
        _hcpTypes = types;
        _profilingHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading doctor details: $e')),
        );
      }
    }
  }

  String _resolveHcpTypeLabel(String typeId) {
    final match = _hcpTypes.where((t) => t.name == typeId);
    if (match.isNotEmpty) {
      return match.first.typeName;
    }
    return typeId; // Fallback to the raw ID
  }

  @override
  Widget build(BuildContext context) {
    final doctor = _fullDoctor ?? widget.doctor;
    final nameParts = [
      if (doctor.firstName.trim().isNotEmpty) doctor.firstName.trim(),
      if (doctor.middleName != null && doctor.middleName!.trim().isNotEmpty && doctor.middleName!.trim() != '-') doctor.middleName!.trim(),
      if (doctor.lastName.trim().isNotEmpty) doctor.lastName.trim(),
    ].join(' ');
    final displayDocName = (doctor.hcpFullName != null && doctor.hcpFullName!.trim().isNotEmpty && !doctor.hcpFullName!.startsWith('HCP-'))
        ? doctor.hcpFullName!.trim()
        : (nameParts.isNotEmpty ? nameParts : (doctor.name ?? 'Doctor'));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(displayDocName.startsWith('Dr.') ? displayDocName : 'Dr. $displayDocName'),
        backgroundColor: const Color(0xFF0056B3),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFullDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0056B3)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  _buildHeaderCard(doctor),
                  const SizedBox(height: 16),
                  // Specialties Section
                  _buildSectionCard(
                    title: 'Specialties',
                    icon: Icons.medical_services,
                    iconColor: const Color(0xFF5856D6),
                    child: _buildSpecialtiesTable(doctor),
                  ),
                  const SizedBox(height: 12),
                  // Workplaces Section
                  _buildSectionCard(
                    title: 'Workplaces',
                    icon: Icons.local_hospital,
                    iconColor: const Color(0xFF34C759),
                    child: _buildWorkplacesTable(doctor),
                  ),
                  const SizedBox(height: 12),
                  // Contact Information Section
                  _buildSectionCard(
                    title: 'Contact Information',
                    icon: Icons.contact_phone,
                    iconColor: const Color(0xFFFF9500),
                    child: _buildContactsTable(doctor),
                  ),
                  const SizedBox(height: 12),
                  // Location Section
                  _buildSectionCard(
                    title: 'Location',
                    icon: Icons.location_on,
                    iconColor: const Color(0xFFFF3B30),
                    child: _buildLocationInfo(doctor),
                  ),
                  const SizedBox(height: 12),
                  // Profiling History Section
                  _buildSectionCard(
                    title: 'Profiling History',
                    icon: Icons.history,
                    iconColor: const Color(0xFF007AFF),
                    child: _buildProfilingHistory(),
                  ),
                  const SizedBox(height: 24),
                  // Action Buttons
                  _buildActionButtons(doctor),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(Hcp doctor) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final nameParts = [
      if (doctor.firstName.trim().isNotEmpty) doctor.firstName.trim(),
      if (doctor.middleName != null && doctor.middleName!.trim().isNotEmpty && doctor.middleName!.trim() != '-') doctor.middleName!.trim(),
      if (doctor.lastName.trim().isNotEmpty) doctor.lastName.trim(),
    ].join(' ');
    final displayDocName = (doctor.hcpFullName != null && doctor.hcpFullName!.trim().isNotEmpty && !doctor.hcpFullName!.startsWith('HCP-'))
        ? doctor.hcpFullName!.trim()
        : (nameParts.isNotEmpty ? nameParts : (doctor.name ?? 'Doctor'));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/medical_bg.jpg'),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0056B3).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Container(
        color: Colors.transparent,
        child: Row(
          children: [
            // Avatar
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: (doctor.hcpPhoto != null && doctor.hcpPhoto!.isNotEmpty)
                    ? Image.network(
                        apiService.formatFileUrl(doctor.hcpPhoto),
                        headers: apiService.authHeaders,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 36),
                      )
                    : const Icon(Icons.person, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(width: 16),
            // Doctor Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayDocName.startsWith('Dr.') ? displayDocName : 'Dr. $displayDocName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Type: ${_resolveHcpTypeLabel(doctor.hcpType)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Practice: ${doctor.hcpPractice}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${doctor.name ?? "New"}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: doctor.isActive
                    ? const Color(0xFF34C759).withOpacity(0.25)
                    : const Color(0xFFFF3B30).withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: doctor.isActive ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                  width: 1,
                ),
              ),
              child: Text(
                doctor.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: doctor.isActive ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1C1C1E),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E5EA)),
          // Section Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialtiesTable(Hcp doctor) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final isMedRep = apiService.isMedRep;
    final preferredList = doctor.specialties.where((s) => s.isPrimary).toList();
    final displayList = (isMedRep && preferredList.isNotEmpty) ? preferredList : doctor.specialties;

    if (displayList.isEmpty) {
      return const Text(
        'No specialties declared.',
        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMedRep && preferredList.isNotEmpty && preferredList.length < doctor.specialties.length)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                const SizedBox(width: 4),
                Text(
                  'Showing ${preferredList.length} preferred specialization(s) for your account',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ...displayList.map((s) {
          final isPref = s.isPrimary;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(isPref ? Icons.star_rounded : Icons.circle, size: isPref ? 16 : 8, color: isPref ? const Color(0xFFF59E0B) : const Color(0xFF5856D6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.hcpSpecialty,
                              style: TextStyle(
                                color: const Color(0xFF1C1C1E),
                                fontSize: 14,
                                fontWeight: isPref ? FontWeight.bold : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isPref && !isMedRep)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('Preferred', style: TextStyle(color: Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      if (s.subSpecialty != null && s.subSpecialty!.isNotEmpty)
                        Text(
                          'Sub-specialty: ${s.subSpecialty}',
                          style: const TextStyle(color: Color(0xFF636366), fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWorkplacesTable(Hcp doctor) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final isMedRep = apiService.isMedRep;
    final preferredList = doctor.workplaces.where((w) => w.isPrimary).toList();
    final displayList = (isMedRep && preferredList.isNotEmpty) ? preferredList : doctor.workplaces;

    if (displayList.isEmpty) {
      return const Text(
        'No workplaces linked.',
        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMedRep && preferredList.isNotEmpty && preferredList.length < doctor.workplaces.length)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                const SizedBox(width: 4),
                Text(
                  'Showing ${preferredList.length} preferred hospital(s)/clinic(s) for your account',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ...displayList.map((w) {
          final isPref = w.isPrimary;
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPref ? const Color(0xFFF0FDF4) : const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isPref ? const Color(0xFF86EFAC) : const Color(0xFFE5E5EA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.local_hospital,
                  color: isPref ? const Color(0xFF16A34A) : const Color(0xFF8E8E93),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.workplace,
                        style: TextStyle(
                          color: const Color(0xFF1C1C1E),
                          fontSize: 14,
                          fontWeight: isPref ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      final locInfo = [
                        if (w.address != null && w.address!.isNotEmpty && w.address != w.workplace) w.address!,
                        if (w.cityMunicipality != null && w.cityMunicipality!.isNotEmpty) w.cityMunicipality!,
                        if (w.provinceName != null && w.provinceName!.isNotEmpty) w.provinceName!,
                      ].join(', ');
                      if (locInfo.isNotEmpty)
                        Text(
                          locInfo,
                          style: const TextStyle(color: Color(0xFF636366), fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (isPref)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Preferred',
                      style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildContactsTable(Hcp doctor) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final isMedRep = apiService.isMedRep;
    final preferredList = doctor.contacts.where((c) => c.isPrimary).toList();
    final displayList = (isMedRep && preferredList.isNotEmpty) ? preferredList : doctor.contacts;

    if (displayList.isEmpty) {
      return const Text(
        'No contact information listed.',
        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMedRep && preferredList.isNotEmpty && preferredList.length < doctor.contacts.length)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                const SizedBox(width: 4),
                Text(
                  'Showing ${preferredList.length} preferred contact(s) for your account',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ...displayList.map((c) {
          final isPref = c.isPrimary;
          IconData contactIcon;
          switch (c.contactType.toLowerCase()) {
            case 'mobile':
            case 'cell':
              contactIcon = Icons.phone_android;
              break;
            case 'email':
              contactIcon = Icons.email;
              break;
            case 'telephone':
            case 'phone':
              contactIcon = Icons.phone;
              break;
            default:
              contactIcon = Icons.contact_page;
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(contactIcon, color: isPref ? const Color(0xFFD97706) : const Color(0xFFFF9500), size: 18),
                const SizedBox(width: 10),
                Text(
                  '${c.contactType}: ',
                  style: const TextStyle(
                    color: Color(0xFF636366),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    c.contactValue,
                    style: TextStyle(
                      color: const Color(0xFF1C1C1E),
                      fontSize: 14,
                      fontWeight: isPref ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isPref)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Preferred', style: TextStyle(color: Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLocationInfo(Hcp doctor) {
    final fields = [
      {'label': 'Region', 'value': doctor.regionName},
      {'label': 'Province', 'value': doctor.provinceName},
      {'label': 'City/Municipality', 'value': doctor.cityMunicipality},
      {'label': 'Barangay', 'value': doctor.barangayName},
      {'label': 'Institution', 'value': doctor.institution},
    ];

    final hasLocation = fields.any((f) => f['value'] != null && f['value']!.isNotEmpty);
    if (!hasLocation) {
      return const Text(
        'No location data recorded.',
        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
      );
    }

    return Column(
      children: fields.where((f) => f['value'] != null && f['value']!.isNotEmpty).map((f) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  '${f['label']}:',
                  style: const TextStyle(
                    color: Color(0xFF636366),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  f['value']!,
                  style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProfilingHistory() {
    if (_profilingHistory.isEmpty) {
      return const Text(
        'No profiling submissions recorded for this doctor.',
        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
      );
    }
    return Column(
      children: _profilingHistory.map((sub) {
        Color statusColor;
        String statusLabel;
        IconData statusIcon;
        final workflow = sub.workflowState ?? sub.status ?? (sub.docstatus == 1 ? 'Approved' : (sub.docstatus == 2 ? 'Cancelled' : 'Draft'));
        final wLower = workflow.toLowerCase();
        if (wLower.contains('reject')) {
          statusColor = const Color(0xFFFF453A);
          statusLabel = 'Rejected';
          statusIcon = Icons.cancel;
        } else if (wLower.contains('cancel')) {
          statusColor = const Color(0xFFFF453A);
          statusLabel = 'Cancelled';
          statusIcon = Icons.block;
        } else if (wLower.contains('appr')) {
          statusColor = const Color(0xFF30D158);
          statusLabel = 'Approved';
          statusIcon = Icons.check_circle;
        } else if (wLower.contains('pend')) {
          statusColor = const Color(0xFFFF9F0A);
          statusLabel = 'Pending Approval';
          statusIcon = Icons.schedule;
        } else {
          statusColor = const Color(0xFF8E8E93);
          statusLabel = workflow;
          statusIcon = Icons.edit_note;
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.name ?? 'Submission',
                      style: const TextStyle(
                        color: Color(0xFF1C1C1E),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (sub.accountOrProgram != null)
                      Text(
                        'Program: ${sub.accountOrProgram}',
                        style: const TextStyle(color: Color(0xFF636366), fontSize: 12),
                      ),
                    if (sub.submissionDate != null)
                      Text(
                        'Date: ${sub.submissionDate}',
                        style: const TextStyle(color: Color(0xFF636366), fontSize: 12),
                      ),
                    if (sub.medrepEmail != null)
                      Text(
                        'MedRep: ${sub.medrepEmail}',
                        style: const TextStyle(color: Color(0xFF636366), fontSize: 12),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons(Hcp doctor) {
    return Row(
      children: [
        // Self-Service QR Button
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF5856D6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.qr_code, color: Color(0xFF5856D6)),
            label: const Text('Self-Service QR', style: TextStyle(color: Color(0xFF5856D6), fontWeight: FontWeight.w600)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SelfServiceQrScreen(doctor: doctor),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        // Profile Doctor Button
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF34C759),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.assignment_ind, color: Colors.white),
            label: const Text('Profile Doctor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HcpWizardScreen(doctor: doctor),
                ),
              );
              if (result == true) {
                _loadFullDetails(); // Reload after profiling
              }
            },
          ),
        ),
      ],
    );
  }
}
