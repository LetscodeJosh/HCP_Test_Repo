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

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text('Dr. ${doctor.firstName} ${doctor.lastName}'),
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
              child: const Icon(Icons.person, color: Colors.white, size: 36),
            ),
            const SizedBox(width: 16),
            // Doctor Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dr. ${doctor.firstName} ${doctor.lastName}',
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
    if (doctor.specialties.isEmpty) {
      return const Text(
        'No specialties declared.',
        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
      );
    }
    return Column(
      children: doctor.specialties.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.circle, size: 8, color: Color(0xFF5856D6)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.hcpSpecialty,
                      style: const TextStyle(
                        color: Color(0xFF1C1C1E),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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
      }).toList(),
    );
  }

  Widget _buildWorkplacesTable(Hcp doctor) {
    if (doctor.workplaces.isEmpty) {
      return const Text(
        'No workplaces linked.',
        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
      );
    }
    return Column(
      children: doctor.workplaces.map((w) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.local_hospital,
                color: w.isPrimary ? const Color(0xFF34C759) : const Color(0xFF8E8E93),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.workplace,
                      style: const TextStyle(
                        color: Color(0xFF1C1C1E),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (w.address != null && w.address!.isNotEmpty)
                      Text(
                        w.address!,
                        style: const TextStyle(color: Color(0xFF636366), fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (w.isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Primary',
                    style: TextStyle(
                      color: Color(0xFF34C759),
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

  Widget _buildContactsTable(Hcp doctor) {
    if (doctor.contacts.isEmpty) {
      return const Text(
        'No contact information listed.',
        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
      );
    }
    return Column(
      children: doctor.contacts.map((c) {
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
              Icon(contactIcon, color: const Color(0xFFFF9500), size: 18),
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
                  style: const TextStyle(
                    color: Color(0xFF1C1C1E),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
        switch (sub.docstatus) {
          case 0:
            statusColor = const Color(0xFFFF9F0A);
            statusLabel = 'Draft';
            statusIcon = Icons.edit_note;
            break;
          case 1:
            statusColor = const Color(0xFF30D158);
            statusLabel = 'Submitted';
            statusIcon = Icons.check_circle;
            break;
          case 2:
            statusColor = const Color(0xFFFF453A);
            statusLabel = 'Cancelled';
            statusIcon = Icons.cancel;
            break;
          default:
            statusColor = const Color(0xFF8E8E93);
            statusLabel = 'Unknown';
            statusIcon = Icons.help;
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
