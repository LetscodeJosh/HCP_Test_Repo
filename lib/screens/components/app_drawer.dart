import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../hcp_dashboard_screen.dart';
import '../doctor_masterlist_screen.dart';
import '../submission_history_screen.dart';
import '../login_screen.dart';
import '../doctor_account_screen.dart';
import '../institution_approvals_screen.dart';
import '../sfe_institution_dashboard_screen.dart';
import '../institution_directory_screen.dart';
import '../../constants/app_version.dart';

enum DrawerItem {
  dashboard,
  doctorManagement,
  doctorAccount,
  submissionsFact,
  institutionApprovals,
  institutions,
}

class AppDrawer extends StatelessWidget {
  final DrawerItem currentItem;

  const AppDrawer({
    Key? key,
    required this.currentItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);
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
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/app_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/icon-512.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF0066FF),
                                child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 28),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'HCP Profiling',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_pin_rounded, color: Color(0xFF38BDF8), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  apiService.loggedInFullName ?? userEmail.split('@').first.replaceAll('.', ' ').toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  userEmail,
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: apiService.isSfe
                                        ? const Color(0xFF8B5CF6).withOpacity(0.2)
                                        : (apiService.isAdmin
                                            ? const Color(0xFFEF4444).withOpacity(0.2)
                                            : (apiService.isManager
                                                ? const Color(0xFFF59E0B).withOpacity(0.2)
                                                : const Color(0xFF0066FF).withOpacity(0.2))),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: apiService.isSfe
                                          ? const Color(0xFF8B5CF6)
                                          : (apiService.isAdmin
                                              ? const Color(0xFFEF4444)
                                              : (apiService.isManager
                                                  ? const Color(0xFFF59E0B)
                                                  : const Color(0xFF38BDF8))),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    apiService.userDesignationTitle.toUpperCase(),
                                    style: TextStyle(
                                      color: apiService.isSfe
                                          ? const Color(0xFFC4B5FD)
                                          : (apiService.isAdmin
                                              ? const Color(0xFFFCA5A5)
                                              : (apiService.isManager
                                                  ? const Color(0xFFFCD34D)
                                                  : const Color(0xFF93C5FD))),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (apiService.isAdmin || apiService.isSfe)
                                  InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (dialogCtx) => AlertDialog(
                                          backgroundColor: const Color(0xFF0F172A),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: Row(
                                            children: const [
                                              Icon(Icons.swap_horiz_rounded, color: Color(0xFF38BDF8)),
                                              SizedBox(width: 8),
                                              Text('Switch Program', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          content: SizedBox(
                                            width: double.maxFinite,
                                            height: 380,
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: apiService.availablePrograms.length,
                                              itemBuilder: (ctx, idx) {
                                                final prog = apiService.availablePrograms[idx];
                                                final isSelected = prog == apiService.selectedProgram;
                                                return ListTile(
                                                  dense: true,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  tileColor: isSelected ? const Color(0xFF0066FF).withOpacity(0.2) : Colors.transparent,
                                                  title: Text(
                                                    prog,
                                                    style: TextStyle(
                                                      color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 18) : null,
                                                  onTap: () {
                                                    apiService.setProgram(prog);
                                                    Navigator.of(dialogCtx).pop();
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF0066FF).withOpacity(0.7), width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.business_center_rounded, size: 12, color: Color(0xFF38BDF8)),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              apiService.selectedProgram,
                                              style: const TextStyle(
                                                color: Color(0xFF38BDF8),
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF38BDF8)),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF334155), width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.business_center_rounded, size: 12, color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            apiService.selectedProgram,
                                            style: const TextStyle(
                                              color: Color(0xFFE2E8F0),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
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
                    if (apiService.isAdmin || apiService.isSfe) ...[
                      const SizedBox(height: 4),
                      _buildMenuItem(
                        context,
                        icon: Icons.people_alt_rounded,
                        title: 'HCP',
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
                    ],
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.badge_rounded,
                      title: 'HCP Account',
                      subtitle: (!apiService.isAdmin && !apiService.isSfe) ? 'View Only' : null,
                      isSelected: currentItem == DrawerItem.doctorAccount,
                      onTap: () {
                        Navigator.of(context).pop();
                        if (currentItem != DrawerItem.doctorAccount) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const DoctorAccountScreen()),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.assignment_turned_in_rounded,
                      title: 'HCP Profile Submissions',
                      badge: 'Active',
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
                      icon: Icons.domain_verification_rounded,
                      title: 'Institution Submission',
                      subtitle: (apiService.isSfe || apiService.isAdmin) ? 'SFE Approval Hub' : 'Track & Resubmit',
                      badge: (apiService.isSfe || apiService.isAdmin)
                          ? (apiService.pendingInstitutionApprovalsCount > 0
                              ? '${apiService.pendingInstitutionApprovalsCount} Pending'
                              : null)
                          : (apiService.myRejectedInstitutionCount > 0
                              ? '${apiService.myRejectedInstitutionCount} Action'
                              : (apiService.myPendingInstitutionCount > 0 ? '${apiService.myPendingInstitutionCount} Pending' : null)),
                      isSelected: currentItem == DrawerItem.institutionApprovals,
                      onTap: () {
                        Navigator.of(context).pop();
                        if (currentItem != DrawerItem.institutionApprovals) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => (apiService.isSfe || apiService.isAdmin)
                                  ? const SfeInstitutionDashboardScreen()
                                  : const InstitutionApprovalsScreen(),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.business_rounded,
                      title: 'Institution Directory',
                      subtitle: 'Master Reference',
                      isSelected: currentItem == DrawerItem.institutions,
                      onTap: () {
                        Navigator.of(context).pop();
                        if (currentItem != DrawerItem.institutions) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const InstitutionDirectoryScreen()),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

          if (apiService.userPosition == UserPosition.admin) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: apiService.sfeModeOverride ? const Color(0xFFA855F7).withOpacity(0.4) : const Color(0xFF334155),
                  ),
                ),
                tileColor: apiService.sfeModeOverride ? const Color(0xFFA855F7).withOpacity(0.12) : const Color(0xFF1E293B).withOpacity(0.5),
                leading: Icon(
                  apiService.sfeModeOverride ? Icons.verified_user_rounded : Icons.admin_panel_settings_rounded,
                  color: apiService.sfeModeOverride ? const Color(0xFFA855F7) : const Color(0xFF38BDF8),
                ),
                title: Text(
                  apiService.sfeModeOverride ? 'SFE View Active' : 'Switch to SFE Portal',
                  style: TextStyle(
                    color: apiService.sfeModeOverride ? const Color(0xFFA855F7) : const Color(0xFFE2E8F0),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  apiService.sfeModeOverride ? 'Tap to return to Admin View' : 'Preview SFE Institution submissions',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                trailing: Switch(
                  value: apiService.sfeModeOverride,
                  activeColor: const Color(0xFFA855F7),
                  onChanged: (val) {
                    apiService.toggleSfeMode();
                    Navigator.of(context).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HcpDashboardScreen()),
                    );
                  },
                ),
                onTap: () {
                  apiService.toggleSfeMode();
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HcpDashboardScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
          ],

          // App Version & Credits (Just above Log Out)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 14),
                const SizedBox(width: 6),
                Text(
                  AppVersion.version,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
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
    String? subtitle,
    String? badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1E3A5F) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5), width: 1) : null,
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
          size: 22,
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badge == 'Active'
                      ? const Color(0xFF10B981).withOpacity(0.2)
                      : const Color(0xFF64748B).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: badge == 'Active'
                        ? const Color(0xFF10B981)
                        : const Color(0xFF64748B),
                    width: 0.7,
                  ),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badge == 'Active'
                        ? const Color(0xFF34D399)
                        : const Color(0xFFCBD5E1),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: isSelected ? const Icon(Icons.chevron_right_rounded, color: Color(0xFF38BDF8), size: 18) : null,
        onTap: onTap,
      ),
    );
  }
}
