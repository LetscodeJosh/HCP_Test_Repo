import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hcp.dart';
import '../../services/api_service.dart';
import '../hcp_dashboard_screen.dart';
import '../doctor_masterlist_screen.dart';
import '../submission_history_screen.dart';
import '../self_service_qr_screen.dart';
import '../login_screen.dart';

enum DrawerItem {
  dashboard,
  doctorManagement,
  submissionsFact,
  institutions,
  selfServiceQr,
}

class AppDrawer extends StatelessWidget {
  final DrawerItem currentItem;

  const AppDrawer({
    Key? key,
    required this.currentItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final userEmail = apiService.loggedInEmail ?? 'medrep@pims-marketing.com';

    return Drawer(
      backgroundColor: const Color(0xFF0B192C),
      child: Column(
        children: [
          // Header Container with Deep Blue gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 50, bottom: 24, left: 20, right: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B192C), Color(0xFF1E3E62)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0066FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF0066FF).withOpacity(0.5), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.medical_services_rounded,
                        color: Color(0xFF38BDF8),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'PIMS HCP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Profile Management Platform',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_pin_rounded, color: Color(0xFF38BDF8), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          userEmail,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu Category Title
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 20, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'DATA VIEWS & PROCESSES',
                style: TextStyle(
                  color: const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),

          // Menu Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.analytics_rounded,
                  title: 'HCP Dashboard',
                  isSelected: currentItem == DrawerItem.dashboard,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (currentItem != DrawerItem.dashboard) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const HcpDashboardScreen()),
                      );
                    }
                  },
                ),
                const SizedBox(height: 4),
                _buildMenuItem(
                  context,
                  icon: Icons.people_alt_rounded,
                  title: 'Doctor Management',
                  isSelected: currentItem == DrawerItem.doctorManagement,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (currentItem != DrawerItem.doctorManagement) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const DoctorMasterlistScreen()),
                      );
                    }
                  },
                ),
                const SizedBox(height: 4),
                _buildMenuItem(
                  context,
                  icon: Icons.assignment_turned_in_rounded,
                  title: 'HCP Profile Submissions',
                  isSelected: currentItem == DrawerItem.submissionsFact,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (currentItem != DrawerItem.submissionsFact) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const SubmissionHistoryScreen()),
                      );
                    }
                  },
                ),
                const SizedBox(height: 4),
                _buildMenuItem(
                  context,
                  icon: Icons.business_rounded,
                  title: 'Institutions',
                  isSelected: currentItem == DrawerItem.institutions,
                  onTap: () {
                    Navigator.of(context).pop();
                    _showInstitutionsModal(context);
                  },
                ),
                const SizedBox(height: 4),
                _buildMenuItem(
                  context,
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Self-Service QR & Sync',
                  isSelected: currentItem == DrawerItem.selfServiceQr,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (currentItem != DrawerItem.selfServiceQr) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SelfServiceQrScreen(
                            doctor: Hcp(
                              firstName: 'Medrep',
                              lastName: 'Self-Service',
                              hcpType: 'Medical Doctor',
                              hcpPractice: 'Prescribing',
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF1E293B), height: 1),

          // Logout Item
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: const Color(0xFF1E293B).withOpacity(0.5),
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFF87171)),
              title: const Text(
                'Log Out',
                style: TextStyle(
                  color: Color(0xFFF87171),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              onTap: () {
                apiService.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0066FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18)
            : null,
        onTap: onTap,
      ),
    );
  }

  void _showInstitutionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _InstitutionsListModal(),
    );
  }
}

class _InstitutionsListModal extends StatefulWidget {
  const _InstitutionsListModal({Key? key}) : super(key: key);

  @override
  State<_InstitutionsListModal> createState() => _InstitutionsListModalState();
}

class _InstitutionsListModalState extends State<_InstitutionsListModal> {
  bool _isLoading = true;
  List<dynamic> _institutions = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final list = await apiService.fetchInstitutions();
      if (mounted) {
        setState(() {
          _institutions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _institutions.where((inst) {
      final name = (inst.institutionName ?? inst.name ?? '').toString().toLowerCase();
      final region = (inst.regionName ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase().trim();
      return query.isEmpty || name.contains(query) || region.contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B192C).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business_rounded, color: Color(0xFF0B192C), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Affiliated Institutions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Total ${filtered.length} Hospitals, Clinics & Centers',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search hospital or city...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0B192C)))
                : filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No institutions found',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final item = filtered[idx];
                          final name = item.institutionName ?? item.name ?? 'Unnamed Institution';
                          final location = [item.cityMunicipality, item.provinceName, item.regionName]
                              .where((s) => s != null && s.toString().isNotEmpty)
                              .join(', ');

                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF0066FF).withOpacity(0.1),
                                child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF0066FF), size: 20),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: Text(
                                location.isEmpty ? 'Location details pending' : location,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
