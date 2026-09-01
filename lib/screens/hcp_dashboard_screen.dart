import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/hcp.dart';
import '../models/hcp_account.dart';
import '../models/lookup_models.dart';
import '../models/submission.dart';
import '../services/api_service.dart';
import 'components/app_drawer.dart';
import 'doctor_masterlist_screen.dart';
import 'doctor_account_screen.dart';
import 'hcp_wizard_screen.dart';

class HcpDashboardScreen extends StatefulWidget {
  const HcpDashboardScreen({Key? key}) : super(key: key);

  @override
  State<HcpDashboardScreen> createState() => _HcpDashboardScreenState();
}

class _HcpDashboardScreenState extends State<HcpDashboardScreen> {
  bool _isLoading = true;
  Timer? _autoRefreshTimer;

  List<Hcp> _doctors = [];
  List<Institution> _institutions = [];
  List<Specialization> _specializations = [];
  List<HcpProfileSubmission> _submissions = [];

  Map<String, int> _specialtyCounts = {};
  Map<String, int> _subSpecialtyCounts = {};
  int _ncrCount = 0;
  int _luzonCount = 0;
  int _visminCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadDashboardData();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  String _determineTerritoryGroup(String input) {
    if (input.isEmpty) return 'NCR';
    final str = input.toLowerCase();

    if (str.contains('ncr') ||
        str.contains('metro manila') ||
        str.contains('manila') ||
        str.contains('quezon city') ||
        str.contains('makati') ||
        str.contains('pasig') ||
        str.contains('taguig') ||
        str.contains('mandaluyong') ||
        str.contains('san juan') ||
        str.contains('marikina') ||
        str.contains('pasay') ||
        str.contains('parañaque') ||
        str.contains('las piñas') ||
        str.contains('muntinlupa') ||
        str.contains('caloocan') ||
        str.contains('malabon') ||
        str.contains('navotas') ||
        str.contains('valenzuela') ||
        str.contains('pateros') ||
        str.contains('ermita')) {
      return 'NCR';
    }

    if (str.contains('visayas') ||
        str.contains('mindanao') ||
        str.contains('cebu') ||
        str.contains('bohol') ||
        str.contains('iloilo') ||
        str.contains('negros') ||
        str.contains('aklan') ||
        str.contains('capiz') ||
        str.contains('antique') ||
        str.contains('guimaras') ||
        str.contains('siquijor') ||
        str.contains('leyte') ||
        str.contains('samar') ||
        str.contains('biliran') ||
        str.contains('davao') ||
        str.contains('zamboanga') ||
        str.contains('bukidnon') ||
        str.contains('camiguin') ||
        str.contains('misamis') ||
        str.contains('cotabato') ||
        str.contains('sarangani') ||
        str.contains('sultan kudarat') ||
        str.contains('agusan') ||
        str.contains('surigao') ||
        str.contains('dinagat') ||
        str.contains('basilan') ||
        str.contains('lanao') ||
        str.contains('maguindanao') ||
        str.contains('sulu') ||
        str.contains('tawi-tawi') ||
        str.contains('region vi') ||
        str.contains('region vii') ||
        str.contains('region viii') ||
        str.contains('region ix') ||
        str.contains('region x') ||
        str.contains('region xi') ||
        str.contains('region xii') ||
        str.contains('region xiii') ||
        str.contains('barmm')) {
      return 'VISMIN';
    }

    return 'LUZON';
  }

  Future<void> _loadDashboardData() async {
    if (_doctors.isEmpty) {
      setState(() => _isLoading = true);
    }
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final doctorsList = await apiService.fetchDoctors().catchError((_) => <Hcp>[]);
      final institutions = await apiService.fetchInstitutions().catchError((_) => <Institution>[]);
      final specializations = await apiService.fetchSpecializations().catchError((_) => <Specialization>[]);
      final submissions = await apiService.fetchSubmissions().catchError((_) => <HcpProfileSubmission>[]);
      final hcpAccounts = await apiService.fetchHcpAccounts().catchError((_) => <HcpAccount>[]);

      final List<Hcp> doctors = [];
      for (var doc in doctorsList) {
        if (doc.name != null) {
          try {
            final fullDoc = await apiService.fetchDoctorDetail(doc.name!);
            doctors.add(fullDoc);
          } catch (e) {
            print('Error fetching detail for ${doc.name}: $e');
            doctors.add(doc);
          }
        } else {
          doctors.add(doc);
        }
      }

      final Map<String, String> specLookup = {};
      for (var s in specializations) {
        specLookup[s.name] = s.specialty;
      }

      final Map<String, int> specMap = {};
      final Map<String, int> subSpecMap = {};

      for (var d in doctors) {
        if (d.specialties.isNotEmpty) {
          for (var s in d.specialties) {
            final rawSpec = s.hcpSpecialty.isNotEmpty ? s.hcpSpecialty : 'General Practice';
            final specName = specLookup[rawSpec] ?? rawSpec;
            specMap[specName] = (specMap[specName] ?? 0) + 1;

            if (s.subSpecialty != null && s.subSpecialty!.isNotEmpty && s.subSpecialty != '-') {
              final subSpecName = specLookup[s.subSpecialty!] ?? s.subSpecialty!;
              subSpecMap[subSpecName] = (subSpecMap[subSpecName] ?? 0) + 1;
            }
          }
        } else {
          specMap['General Practice'] = (specMap['General Practice'] ?? 0) + 1;
        }
      }

      final Map<String, Institution> instLookup = {};
      for (var inst in institutions) {
        instLookup[inst.name] = inst;
      }

      int ncr = 0;
      int luzon = 0;
      int vismin = 0;

      for (var d in doctors) {
        final Set<String> doctorTerritories = {};

        if (d.provinceName != null && d.provinceName!.isNotEmpty) {
          doctorTerritories.add(_determineTerritoryGroup(d.provinceName!));
        }
        if (d.regionName != null && d.regionName!.isNotEmpty) {
          doctorTerritories.add(_determineTerritoryGroup(d.regionName!));
        }

        if (d.workplaces.isNotEmpty) {
          for (var w in d.workplaces) {
            if (w.address != null && w.address!.isNotEmpty) {
              doctorTerritories.add(_determineTerritoryGroup(w.address!));
            }
            if (w.workplace.isNotEmpty) {
              doctorTerritories.add(_determineTerritoryGroup(w.workplace));
              final inst = instLookup[w.workplace];
              if (inst != null) {
                if (inst.provinceName != null && inst.provinceName!.isNotEmpty) {
                  doctorTerritories.add(_determineTerritoryGroup(inst.provinceName!));
                }
                if (inst.regionName != null && inst.regionName!.isNotEmpty) {
                  doctorTerritories.add(_determineTerritoryGroup(inst.regionName!));
                }
                if (inst.cityMunicipality != null && inst.cityMunicipality!.isNotEmpty) {
                  doctorTerritories.add(_determineTerritoryGroup(inst.cityMunicipality!));
                }
              }
            }
          }
        }

        if (doctorTerritories.isEmpty) {
          doctorTerritories.add('NCR');
        }

        if (doctorTerritories.contains('NCR')) ncr++;
        if (doctorTerritories.contains('LUZON')) luzon++;
        if (doctorTerritories.contains('VISMIN')) vismin++;
      }

      if (doctors.isEmpty && submissions.isNotEmpty) {
        for (var sub in submissions) {
          final Set<String> subTerritories = {};
          if (sub.provinceName != null && sub.provinceName!.isNotEmpty) {
            subTerritories.add(_determineTerritoryGroup(sub.provinceName!));
          }
          if (sub.workplaces.isNotEmpty) {
            for (var w in sub.workplaces) {
              if (w.workplaceName != null && w.workplaceName!.isNotEmpty) {
                subTerritories.add(_determineTerritoryGroup(w.workplaceName!));
              }
            }
          }
          if (subTerritories.isEmpty) subTerritories.add('NCR');

          if (subTerritories.contains('NCR')) ncr++;
          if (subTerritories.contains('LUZON')) luzon++;
          if (subTerritories.contains('VISMIN')) vismin++;
        }
      }

      if (mounted) {
        setState(() {
          _doctors = doctors;
          _institutions = institutions;
          _specializations = specializations.where((s) => !s.isGroup).toList();
          _submissions = submissions;
          _specialtyCounts = specMap;
          _subSpecialtyCounts = subSpecMap;
          _ncrCount = ncr;
          _luzonCount = luzon;
          _visminCount = vismin;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);

    // Scope submissions to program for MedRep and Manager; Admin sees all
    List<HcpProfileSubmission> progSubmissions = List.from(_submissions);
    if (!apiService.isAdmin) {
      final userProg = apiService.selectedProgram.toLowerCase().trim();
      if (userProg.isNotEmpty && userProg != 'all') {
        progSubmissions = progSubmissions.where((s) {
          final subProg = (s.accountOrProgram ?? '').toLowerCase().trim();
          if (subProg.isEmpty) return true;
          return subProg.contains(userProg) ||
              userProg.contains(subProg) ||
              (userProg.contains('abbott') && subProg.contains('abbott')) ||
              (userProg.contains('adc') && subProg.contains('abbott')) ||
              (userProg.contains('corenergy') && subProg.contains('corenergy'));
        }).toList();
      }
    }

    List<HcpProfileSubmission> mySubmissions = progSubmissions;
    if (apiService.isMedRep) {
      final email = (apiService.loggedInEmail ?? '').toLowerCase().trim();
      final fullName = (apiService.loggedInFullName ?? '').toLowerCase().trim();
      final userTokens = fullName.split(RegExp(r'\s+')).where((t) => t.length > 1).toList();

      mySubmissions = progSubmissions.where((item) {
        final sEmail = (item.medrepEmail ?? item.userId ?? item.owner ?? '').toLowerCase().trim();
        final sSales = (item.salesPerson ?? '').toLowerCase().trim();
        if (sEmail.isNotEmpty && email.isNotEmpty) {
          if (sEmail == email || email.contains(sEmail) || sEmail.contains(email)) return true;
        }
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

    final effectiveSubmissions = progSubmissions;

    final approvedSubmissions = effectiveSubmissions.where((s) => s.docstatus == 1 || s.applicationStatus == 'Applied').length;
    final syncRatePercent = effectiveSubmissions.isNotEmpty
        ? ((approvedSubmissions / effectiveSubmissions.length) * 100).toStringAsFixed(0)
        : '100';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B192C),
        elevation: 0,
        title: const Text(
          'HCP Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        actions: [
          // Position Role Badge
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
            tooltip: 'Refresh Dashboard',
            onPressed: _loadDashboardData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AppDrawer(currentItem: DrawerItem.dashboard),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0B192C)),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: const Color(0xFF0B192C),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Metric Summary Cards Row
                    _buildMetricsRow(syncRatePercent, apiService, effectiveSubmissions),

                    const SizedBox(height: 20),

                    // Quick Action Hub
                    _buildQuickActionHub(apiService),

                    const SizedBox(height: 20),

                    // Main Analytics Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 700) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  children: [
                                    _buildDoctorsBySpecialtyCard(),
                                    const SizedBox(height: 16),
                                    _buildDoctorsBySubSpecialtyCard(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: _buildRecentConsentLogsCard(apiService, effectiveSubmissions)),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildDoctorsBySpecialtyCard(),
                              const SizedBox(height: 16),
                              _buildDoctorsBySubSpecialtyCard(),
                              const SizedBox(height: 16),
                              _buildRecentConsentLogsCard(apiService, effectiveSubmissions),
                            ],
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // Regional / Institution Distribution
                    _buildTerritoryDistributionCard(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }



  Widget _buildMetricsRow(String syncRatePercent, ApiService apiService, List<HcpProfileSubmission> effectiveSubmissions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth > 700
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;

        final email = (apiService.loggedInEmail ?? '').toLowerCase().trim();
        final fullName = (apiService.loggedInFullName ?? '').toLowerCase().trim();
        final userTokens = fullName.split(RegExp(r'\s+')).where((t) => t.length > 1).toList();

        final mySubmissions = effectiveSubmissions.where((item) {
          final sEmail = (item.medrepEmail ?? item.userId ?? item.owner ?? '').toLowerCase().trim();
          final sSales = (item.salesPerson ?? '').toLowerCase().trim();
          if (sEmail.isNotEmpty && email.isNotEmpty) {
            if (sEmail == email || email.contains(sEmail) || sEmail.contains(email)) return true;
          }
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

        final submissionTitle = apiService.isMedRep ? 'MY SUBMISSIONS' : 'ACTIVE SUBMISSIONS';
        final submissionValue = apiService.isMedRep ? '${mySubmissions.length}' : '${effectiveSubmissions.length}';
        final submissionSubtitle = apiService.isMedRep
            ? '${mySubmissions.length} of ${effectiveSubmissions.length} Program Total'
            : 'SFE Field Force Synced';

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard(
              width: cardWidth,
              title: 'TOTAL HCP DIRECTORY',
              value: '${_doctors.length}',
              subtitle: apiService.isMedRep ? 'Directory Reference (View)' : 'Enterprise Snowflake Standard',
              icon: Icons.people_alt_rounded,
              iconColor: const Color(0xFF0066FF),
              accentColor: const Color(0xFF2563EB),
            ),
            _buildMetricCard(
              width: cardWidth,
              title: 'CONSENT SYNC RATE',
              value: '$syncRatePercent%',
              subtitle: 'Validation & Compliance',
              icon: Icons.verified_rounded,
              iconColor: const Color(0xFF10B981),
              accentColor: const Color(0xFF10B981),
              progressValue: (double.tryParse(syncRatePercent) ?? 100) / 100,
            ),
            _buildMetricCard(
              width: cardWidth,
              title: 'AFFILIATED INSTITUTIONS',
              value: '${_institutions.length}',
              subtitle: 'Hospitals, Clinics, Centers',
              icon: Icons.domain_rounded,
              iconColor: const Color(0xFF8B5CF6),
              accentColor: const Color(0xFF8B5CF6),
            ),
            _buildMetricCard(
              width: cardWidth,
              title: submissionTitle,
              value: submissionValue,
              subtitle: submissionSubtitle,
              icon: Icons.assignment_turned_in_rounded,
              iconColor: const Color(0xFFF59E0B),
              accentColor: const Color(0xFFF59E0B),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color accentColor,
    double? progressValue,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (progressValue != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: const Color(0xFFE2E8F0),
                color: iconColor,
                minHeight: 5,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionHub(ApiService apiService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUICK ACTION HUB',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0B192C),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              final buttons = [
                _buildActionButton(
                  icon: Icons.assignment_turned_in_rounded,
                  label: 'HCP Profiling',
                  subtitle: 'New Submission',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HcpWizardScreen()),
                    );
                  },
                ),
                if (apiService.isAdmin)
                  _buildActionButton(
                    icon: Icons.groups_rounded,
                    label: 'Doctor Listing',
                    subtitle: 'Manage & View HCPs',
                    color: const Color(0xFF0066FF),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DoctorMasterlistScreen()),
                      );
                    },
                  ),
                _buildActionButton(
                  icon: Icons.account_box_rounded,
                  label: 'Doctor Account',
                  subtitle: apiService.isMedRep ? 'My Doctor Accounts' : 'Manage & View Accounts',
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DoctorAccountScreen()),
                    );
                  },
                ),
              ];

              if (isNarrow) {
                return Column(
                  children: [
                    for (int i = 0; i < buttons.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      buttons[i],
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (int i = 0; i < buttons.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: buttons[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorsBySpecialtyCard() {
    final totalDocs = _doctors.isNotEmpty ? _doctors.length : 1;
    final sortedEntries = _specialtyCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final barColors = [
      const Color(0xFF0066FF),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF3B82F6),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.bar_chart_rounded, color: Color(0xFF0B192C), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Doctors by Specialty',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                'Total Represented: ${_doctors.length}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sortedEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No specialty breakdown available', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            )
          else
            ...List.generate(sortedEntries.take(6).length, (idx) {
              final entry = sortedEntries[idx];
              final count = entry.value;
              final percent = (count / totalDocs * 100).round();
              final color = barColors[idx % barColors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        Text(
                          '$count Doctors ($percent%)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: count / totalDocs,
                        backgroundColor: const Color(0xFFF1F5F9),
                        color: color,
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDoctorsBySubSpecialtyCard() {
    final sortedEntries = _subSpecialtyCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalDocs = _doctors.isEmpty ? 1 : _doctors.length;

    final barColors = const [
      Color(0xFF10B981),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.pie_chart_rounded, color: Color(0xFF0B192C), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Doctors by Sub-Specialty',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                'Sub-Specialties: ${sortedEntries.length}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sortedEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No sub-specialty data recorded yet', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            )
          else
            ...List.generate(sortedEntries.take(6).length, (idx) {
              final entry = sortedEntries[idx];
              final count = entry.value;
              final percent = (count / totalDocs * 100).round();
              final color = barColors[idx % barColors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        Text(
                          '$count Doctors ($percent%)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (count / totalDocs).clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFF1F5F9),
                        color: color,
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentConsentLogsCard(ApiService apiService, List<HcpProfileSubmission> effectiveSubmissions) {
    final recentSubs = effectiveSubmissions.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: Color(0xFF0B192C), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  apiService.isMedRep ? 'My Recent Consent Logs' : 'Recent Field Consent Logs',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentSubs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No recent field consent logs', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentSubs.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 16),
              itemBuilder: (ctx, idx) {
                final item = recentSubs[idx];
                final doctorName = '${item.firstName ?? ''} ${item.lastName ?? ''}'.trim();
                final specialty = item.specialties.isNotEmpty
                    ? (item.specialties.first.specialtyName ?? item.specialties.first.hcpSpecialty ?? 'Specialty Pending')
                    : 'Specialty Pending';
                final workflow = item.workflowState ?? item.status ?? (item.docstatus == 1 ? 'Approved' : (item.docstatus == 2 ? 'Rejected' : 'Pending Approval'));

                Color statusBg;
                final wLower = workflow.toLowerCase().trim();
                if (wLower.contains('reject')) {
                  statusBg = const Color(0xFFDC2626);
                } else if (wLower.contains('cancel')) {
                  statusBg = const Color(0xFF991B1B);
                } else if (wLower.contains('draft')) {
                  statusBg = const Color(0xFF64748B);
                } else if (wLower.contains('pend')) {
                  statusBg = const Color(0xFFD97706);
                } else if (wLower.contains('appr')) {
                  statusBg = const Color(0xFF16A34A);
                } else {
                  statusBg = const Color(0xFF4B5563);
                }
                final statusLabel = workflow;

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF0B192C).withOpacity(0.08),
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B192C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctorName.isEmpty ? (item.name ?? 'Doctor') : 'Dr. $doctorName',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            specialty,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          if (item.submissionDate != null && item.submissionDate!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 10.5, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 3),
                                  Text(
                                    _format12HrDate(item.submissionDate),
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  String _format12HrDate(String? dateStr) {
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
                dt = DateTime.tryParse('${dp[0]}-${dp[1].padLeft(2, '0')}-${dp[2].padLeft(2, '0')}T$timePart');
              } else if (dp[2].length == 4) {
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

  Widget _buildTerritoryDistributionCard() {
    final totalDocs = _doctors.isNotEmpty ? _doctors.length : (_submissions.isNotEmpty ? _submissions.length : 1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.map_rounded, color: Color(0xFF0B192C), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Territory & Regional Distribution',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const Text(
                'Dynamic Regional Routing',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildRegionBox(
                  regionName: 'National Capital Region',
                  count: _ncrCount,
                  total: totalDocs,
                  barColor: const Color(0xFF0066FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRegionBox(
                  regionName: 'Luzon Provinces',
                  count: _luzonCount,
                  total: totalDocs,
                  barColor: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRegionBox(
                  regionName: 'Visayas & Mindanao',
                  count: _visminCount,
                  total: totalDocs,
                  barColor: const Color(0xFFEC4899),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegionBox({
    required String regionName,
    required int count,
    required int total,
    required Color barColor,
  }) {
    final percent = total > 0 ? (count / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            regionName,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            'HCP Profiles ($percent%)',
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
