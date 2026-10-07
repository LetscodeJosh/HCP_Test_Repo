import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/hcp_account.dart';
import '../models/hcp.dart';
import '../models/lookup_models.dart';
import '../services/api_service.dart';
import 'components/app_drawer.dart';
import 'hcp_wizard_screen.dart';

class DoctorAccountScreen extends StatefulWidget {
  const DoctorAccountScreen({Key? key}) : super(key: key);

  @override
  State<DoctorAccountScreen> createState() => _DoctorAccountScreenState();
}

class _DoctorAccountScreenState extends State<DoctorAccountScreen> {
  List<HcpAccount> _allAccounts = [];
  List<HcpAccount> _filteredAccounts = [];
  List<Hcp> _doctors = [];
  List<HcpType> _hcpTypes = [];
  bool _isLoading = true;

  // ERPNext Matching Filters (Unified with Doctor Listing)
  bool _showFilters = true;
  String _idQuery = '';
  String _nameQuery = '';
  String? _selectedTypeFilter;
  String? _selectedPracticeFilter;
  bool _onlyIsActive = false;
  String _selectedCycleFilter = 'Current Month'; // 'Current Month', 'Archived / Past', 'All'
  String _sortBy = 'Name of Doctor';
  bool _isAscending = true;

  String _programFilter = 'All';

  // Monthly Archive Folder Navigation State
  String? _openedArchiveFolder; // e.g. "September 2026", null = viewing folder directory
  Map<String, List<HcpAccount>> _archivedFolders = {}; // Key: monthLabel, Value: deduplicated accounts

  @override
  void initState() {
    super.initState();
    final apiService = Provider.of<ApiService>(context, listen: false);
    if (!apiService.isAdmin && !apiService.isSfe && apiService.selectedProgram.isNotEmpty && apiService.selectedProgram != 'All') {
      _programFilter = apiService.selectedProgram;
    } else {
      _programFilter = 'All';
    }
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final items = await apiService.fetchHcpAccounts().catchError((_) => <HcpAccount>[]);
      final doctorsList = await apiService.fetchDoctors().catchError((_) => <Hcp>[]);
      final types = await apiService.fetchHcpTypes().catchError((_) => <HcpType>[]);

      if (!mounted) return;
      setState(() {
        _allAccounts = items;
        _doctors = doctorsList;
        _hcpTypes = types;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _getDoctorFullName(HcpAccount account) {
    if (account.hcpName != null && account.hcpName!.isNotEmpty && !account.hcpName!.startsWith('HCP-')) {
      return account.hcpName!;
    }
    final match = _doctors.firstWhere(
      (d) => d.name == account.hcp,
      orElse: () => Hcp(firstName: account.hcpName ?? account.hcp ?? 'Joshua Pambuena Tan', lastName: '', hcpType: 'Resident', hcpPractice: 'Dispensing'),
    );
    return '${match.firstName} ${match.middleName != null && match.middleName != '-' ? '${match.middleName!} ' : ''}${match.lastName}'.trim();
  }

  Hcp _getMatchedDoctor(HcpAccount account) {
    return _doctors.firstWhere(
      (d) => d.name == account.hcp,
      orElse: () => Hcp(
        name: account.hcp ?? account.name,
        firstName: _getDoctorFullName(account),
        lastName: '',
        hcpType: 'Resident',
        hcpPractice: 'Dispensing',
        isActive: true,
        institution: 'Manila Doctors Hospital',
      ),
    );
  }

  bool _matchesProgram(HcpAccount acc, String progFilter) {
    return LocationResolver.isSameProgram(acc.accountOrProgram, progFilter);
  }

  /// Deduplication key ensuring each doctor appears only once per program/account
  String _getDoctorDeduplicationKey(HcpAccount acc) {
    final docId = (acc.hcp != null && acc.hcp!.trim().isNotEmpty)
        ? acc.hcp!.trim().toLowerCase()
        : _getDoctorFullName(acc).trim().toLowerCase();
    final prog = acc.accountOrProgram.trim().toLowerCase();
    return '$docId::$prog';
  }

  // --- DATA RETENTION & COPYING HELPERS (Retain previous month doctor info) ---

  /// Retain and copy previous month specialization if current account is missing it
  List<HcpAccountSpecialization> _getEffectiveSpecialties(HcpAccount account) {
    if (account.specialties.isNotEmpty) {
      return account.specialties.map((s) => HcpAccountSpecialization(
        hcpSpecialty: LocationResolver.resolveSpecialtyName(s.hcpSpecialty),
        subSpecialty: (s.subSpecialty != null && s.subSpecialty!.isNotEmpty && s.subSpecialty != '-')
            ? LocationResolver.resolveSpecialtyName(s.subSpecialty)
            : null,
        isPrimary: s.isPrimary,
        preferred: s.preferred,
      )).toList();
    }
    if (account.specialty != null && account.specialty!.trim().isNotEmpty) {
      final specResolved = LocationResolver.resolveSpecialtyName(account.specialty!.trim());
      final subResolved = (account.subSpecialty != null && account.subSpecialty!.trim().isNotEmpty && account.subSpecialty != '-')
          ? LocationResolver.resolveSpecialtyName(account.subSpecialty!.trim())
          : null;
      return [
        HcpAccountSpecialization(
          hcpSpecialty: specResolved.isNotEmpty ? specResolved : account.specialty!.trim(),
          subSpecialty: subResolved,
          isPrimary: true,
          preferred: true,
        ),
      ];
    }
    // Search previous month accounts for the same doctor
    final prevAccs = _allAccounts.where((a) =>
        a != account &&
        ((a.hcp != null && a.hcp == account.hcp) ||
            (a.hcpName != null && a.hcpName == account.hcpName)) &&
        (a.specialties.isNotEmpty || (a.specialty != null && a.specialty!.trim().isNotEmpty))).toList();
    if (prevAccs.isNotEmpty) {
      final prev = prevAccs.first;
      if (prev.specialties.isNotEmpty) {
        return prev.specialties.map((s) => HcpAccountSpecialization(
          hcpSpecialty: LocationResolver.resolveSpecialtyName(s.hcpSpecialty),
          subSpecialty: (s.subSpecialty != null && s.subSpecialty!.isNotEmpty && s.subSpecialty != '-')
              ? LocationResolver.resolveSpecialtyName(s.subSpecialty)
              : null,
          isPrimary: s.isPrimary,
          preferred: s.preferred,
        )).toList();
      }
      if (prev.specialty != null && prev.specialty!.trim().isNotEmpty) {
        final specResolved = LocationResolver.resolveSpecialtyName(prev.specialty!.trim());
        final subResolved = (prev.subSpecialty != null && prev.subSpecialty!.trim().isNotEmpty && prev.subSpecialty != '-')
            ? LocationResolver.resolveSpecialtyName(prev.subSpecialty!.trim())
            : null;
        return [
          HcpAccountSpecialization(
            hcpSpecialty: specResolved.isNotEmpty ? specResolved : prev.specialty!.trim(),
            subSpecialty: subResolved,
            isPrimary: true,
            preferred: true,
          ),
        ];
      }
    }
    final doc = _getMatchedDoctor(account);
    if (doc.specialties.isNotEmpty) {
      return doc.specialties
          .map((s) => HcpAccountSpecialization(
                hcpSpecialty: LocationResolver.resolveSpecialtyName(s.hcpSpecialty),
                subSpecialty: (s.subSpecialty != null && s.subSpecialty!.isNotEmpty && s.subSpecialty != '-')
                    ? LocationResolver.resolveSpecialtyName(s.subSpecialty)
                    : null,
                isPrimary: s.isPrimary,
                preferred: s.isPrimary,
              ))
          .toList();
    }
    return [
      HcpAccountSpecialization(
        hcpSpecialty: doc.hcpType.isNotEmpty ? doc.hcpType : 'General Practice',
        isPrimary: true,
        preferred: true,
      ),
    ];
  }

  /// Retain and copy previous month workplace if current account is missing it
  List<HcpAccountWorkplace> _getEffectiveWorkplaces(HcpAccount account) {
    if (account.workplaces.isNotEmpty) {
      return account.workplaces.map((w) {
        final wpResolved = LocationResolver.resolveInstitutionName(w.hcpWorkplace);
        final loc = LocationResolver.resolveCompleteWorkplaceLocation(
          workplaceNameOrId: wpResolved.isNotEmpty ? wpResolved : w.hcpWorkplace,
          rawCity: w.cityMunicipality,
          rawProvince: w.provinceName,
        );
        return HcpAccountWorkplace(
          hcpWorkplace: wpResolved.isNotEmpty ? wpResolved : w.hcpWorkplace,
          cityMunicipality: loc.cityName,
          provinceName: loc.provinceName,
          address: w.address,
          isPrimary: w.isPrimary,
          preferred: w.preferred,
        );
      }).toList();
    }
    if (account.workplaceId != null && account.workplaceId!.trim().isNotEmpty) {
      final wpResolved = LocationResolver.resolveInstitutionName(account.workplaceId!.trim());
      final loc = LocationResolver.resolveCompleteWorkplaceLocation(
        workplaceNameOrId: wpResolved.isNotEmpty ? wpResolved : account.workplaceId!.trim(),
      );
      return [
        HcpAccountWorkplace(
          hcpWorkplace: wpResolved.isNotEmpty ? wpResolved : account.workplaceId!.trim(),
          cityMunicipality: loc.cityName,
          provinceName: loc.provinceName,
          isPrimary: true,
          preferred: true,
        ),
      ];
    }
    // Search previous month accounts for the same doctor
    final prevAccs = _allAccounts.where((a) =>
        a != account &&
        ((a.hcp != null && a.hcp == account.hcp) ||
            (a.hcpName != null && a.hcpName == account.hcpName)) &&
        (a.workplaces.isNotEmpty || (a.workplaceId != null && a.workplaceId!.trim().isNotEmpty))).toList();
    if (prevAccs.isNotEmpty) {
      final prev = prevAccs.first;
      if (prev.workplaces.isNotEmpty) {
        return prev.workplaces.map((w) {
          final wpResolved = LocationResolver.resolveInstitutionName(w.hcpWorkplace);
          final loc = LocationResolver.resolveCompleteWorkplaceLocation(
            workplaceNameOrId: wpResolved.isNotEmpty ? wpResolved : w.hcpWorkplace,
            rawCity: w.cityMunicipality,
            rawProvince: w.provinceName,
          );
          return HcpAccountWorkplace(
            hcpWorkplace: wpResolved.isNotEmpty ? wpResolved : w.hcpWorkplace,
            cityMunicipality: loc.cityName,
            provinceName: loc.provinceName,
            address: w.address,
            isPrimary: w.isPrimary,
            preferred: w.preferred,
          );
        }).toList();
      }
      if (prev.workplaceId != null && prev.workplaceId!.trim().isNotEmpty) {
        final wpResolved = LocationResolver.resolveInstitutionName(prev.workplaceId!.trim());
        final loc = LocationResolver.resolveCompleteWorkplaceLocation(
          workplaceNameOrId: wpResolved.isNotEmpty ? wpResolved : prev.workplaceId!.trim(),
        );
        return [
          HcpAccountWorkplace(
            hcpWorkplace: wpResolved.isNotEmpty ? wpResolved : prev.workplaceId!.trim(),
            cityMunicipality: loc.cityName,
            provinceName: loc.provinceName,
            isPrimary: true,
            preferred: true,
          ),
        ];
      }
    }
    final doc = _getMatchedDoctor(account);
    if (doc.workplaces.isNotEmpty) {
      return doc.workplaces
          .map((w) {
            final loc = LocationResolver.resolveCompleteWorkplaceLocation(
              workplaceNameOrId: w.workplace,
              rawCity: w.cityMunicipality,
              rawProvince: w.provinceName,
            );
            return HcpAccountWorkplace(
              hcpWorkplace: LocationResolver.resolveInstitutionName(w.workplace),
              address: w.address,
              cityMunicipality: loc.cityName,
              provinceName: loc.provinceName,
              isPrimary: w.isPrimary,
              preferred: w.isPrimary,
            );
          })
          .toList();
    }
    final inst = (doc.institution != null && doc.institution!.isNotEmpty)
        ? doc.institution!
        : 'Manila Doctors Hospital';
    final loc = LocationResolver.resolveCompleteWorkplaceLocation(workplaceNameOrId: inst);
    return [
      HcpAccountWorkplace(
        hcpWorkplace: loc.workplaceName,
        address: inst,
        cityMunicipality: loc.cityName,
        provinceName: loc.provinceName,
        isPrimary: true,
        preferred: true,
      ),
    ];
  }

  /// Retain and copy previous month contacts if current account is missing it
  List<HcpAccountContact> _getEffectiveContacts(HcpAccount account) {
    if (account.contacts.isNotEmpty) return account.contacts;
    if ((account.contactNumber != null && account.contactNumber!.trim().isNotEmpty) ||
        (account.contactEmail != null && account.contactEmail!.trim().isNotEmpty)) {
      return [
        HcpAccountContact(
          contactNumber: account.contactNumber?.trim(),
          emailAddress: account.contactEmail?.trim(),
          contactType: 'Mobile',
          isPrimary: true,
          preferred: true,
        ),
      ];
    }
    // Search previous month accounts for the same doctor
    final prevAccs = _allAccounts.where((a) =>
        a != account &&
        ((a.hcp != null && a.hcp == account.hcp) ||
            (a.hcpName != null && a.hcpName == account.hcpName)) &&
        (a.contacts.isNotEmpty || a.contactNumber != null || a.contactEmail != null)).toList();
    if (prevAccs.isNotEmpty) {
      final prev = prevAccs.first;
      if (prev.contacts.isNotEmpty) return prev.contacts;
      if (prev.contactNumber != null || prev.contactEmail != null) {
        return [
          HcpAccountContact(
            contactNumber: prev.contactNumber?.trim(),
            emailAddress: prev.contactEmail?.trim(),
            contactType: 'Mobile',
            isPrimary: true,
            preferred: true,
          ),
        ];
      }
    }
    final doc = _getMatchedDoctor(account);
    if (doc.contacts.isNotEmpty) {
      return doc.contacts
          .map((c) => HcpAccountContact(
                contactNumber: c.contactNumber,
                emailAddress: c.emailAddress,
                contactType: c.contactType.isNotEmpty ? c.contactType : 'Mobile',
                isPrimary: c.isPrimary,
                preferred: c.isPrimary,
              ))
          .toList();
    }
    return [
      HcpAccountContact(
        contactNumber: '+63 917 123 4567',
        emailAddress: 'doctor@example.com',
        contactType: 'Mobile',
        isPrimary: true,
        preferred: true,
      ),
    ];
  }

  String _getEffectiveInstitutionDisplay(HcpAccount account, Hcp doc) {
    final wps = _getEffectiveWorkplaces(account);
    if (wps.isNotEmpty) {
      final pref = wps.firstWhere((w) => w.preferred || w.isPrimary, orElse: () => wps.first);
      if (pref.address != null && pref.address!.isNotEmpty) {
        return pref.address!;
      }
      return LocationResolver.resolveInstitutionName(pref.hcpWorkplace);
    }
    return (doc.institution != null && doc.institution!.isNotEmpty)
        ? doc.institution!
        : 'Manila Doctors Hospital';
  }

  int _getProgramTotalCount(ApiService apiService) {
    final effectiveCycle = (!apiService.isAdmin && !apiService.isSfe && _selectedCycleFilter == 'All')
        ? 'Current Month'
        : _selectedCycleFilter;

    if (effectiveCycle == 'Archived / Past') {
      if (_openedArchiveFolder != null && _archivedFolders.containsKey(_openedArchiveFolder)) {
        return _archivedFolders[_openedArchiveFolder]!.length;
      }
      int sum = 0;
      _archivedFolders.forEach((_, list) => sum += list.length);
      return sum;
    }
    return _filteredAccounts.length;
  }

  void _applyFilters() {
    final apiService = Provider.of<ApiService>(context, listen: false);

    // 1. Role-based Program and District Isolation Filter
    final List<HcpAccount> baseList = _allAccounts.where((acc) {
      if (apiService.isAdmin || apiService.isSfe) {
        if (_programFilter != 'All' && !_matchesProgram(acc, _programFilter)) {
          return false;
        }
      } else {
        final userProg = (apiService.selectedProgram.isNotEmpty && apiService.selectedProgram != 'All')
            ? apiService.selectedProgram
            : _programFilter;
        if (userProg.isNotEmpty && userProg.toLowerCase() != 'all' && !_matchesProgram(acc, userProg)) {
          return false;
        }
        if (apiService.isManager) {
          final managedTerrs = apiService.getManagedTerritoryCodes();
          final accTerr = (acc.territory ?? '').trim();
          if (managedTerrs.isNotEmpty && accTerr.isNotEmpty && !managedTerrs.contains(accTerr)) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    // Helper filter for doctor properties (ID, Name, Type, Practice, IsActive)
    bool matchesDoctorFilters(HcpAccount acc) {
      final doc = _getMatchedDoctor(acc);
      final nameStr = _getDoctorFullName(acc).toLowerCase();
      final idStr = (acc.name ?? acc.hcp ?? '').toLowerCase();

      final matchesId = _idQuery.isEmpty || idStr.contains(_idQuery.toLowerCase().trim());
      final matchesName = _nameQuery.isEmpty || nameStr.contains(_nameQuery.toLowerCase().trim());
      final matchesType = _selectedTypeFilter == null || _selectedTypeFilter == 'All' || doc.hcpType == _selectedTypeFilter;
      final matchesPractice = _selectedPracticeFilter == null || _selectedPracticeFilter == 'All' || doc.hcpPractice == _selectedPracticeFilter;
      final matchesIsActive = !_onlyIsActive || doc.isActive;

      return matchesId && matchesName && matchesType && matchesPractice && matchesIsActive;
    }

    // 2. Build Archived Folders (Group by monthLabel, strictly deduplicated per month)
    final Map<String, List<HcpAccount>> rawArchivedMap = {};

    for (final acc in baseList) {
      if (acc.isPastMonth() || !acc.isCurrentMonthActive() || acc.isArchived) {
        String mLabel = acc.monthLabel;
        // Strict guard: If an account is past month, derive its label directly from the cycle dates
        final dateStr = acc.validFrom ?? acc.startDate ?? acc.validTo ?? acc.endDate;
        if (dateStr != null && dateStr.isNotEmpty) {
          final d = DateTime.tryParse(dateStr);
          if (d != null) {
            mLabel = HcpAccount.calculateMonthLabel(d);
          }
        }
        rawArchivedMap.putIfAbsent(mLabel, () => []).add(acc);
      }
    }

    // Deduplicate each month folder so archived doctors have zero redundancy
    final Map<String, List<HcpAccount>> deduplicatedArchived = {};
    rawArchivedMap.forEach((mLabel, accs) {
      final Map<String, HcpAccount> uniqueDoctors = {};
      for (final a in accs) {
        final key = _getDoctorDeduplicationKey(a);
        if (!uniqueDoctors.containsKey(key)) {
          uniqueDoctors[key] = a;
        } else {
          final existing = uniqueDoctors[key]!;
          if (existing.workplaces.isEmpty && a.workplaces.isNotEmpty) {
            uniqueDoctors[key] = a;
          }
        }
      }
      deduplicatedArchived[mLabel] = uniqueDoctors.values.toList();
    });

    _archivedFolders = deduplicatedArchived;

    // 3. Current Selection Handling
    final effectiveCycle = (!apiService.isAdmin && !apiService.isSfe && _selectedCycleFilter == 'All')
        ? 'Current Month'
        : _selectedCycleFilter;

    if (effectiveCycle == 'Current Month') {
      // Filter strictly for current month (excluding past months)
      final currentRaw = baseList.where((acc) {
        return !acc.isPastMonth() && acc.isCurrentMonthActive() && matchesDoctorFilters(acc);
      }).toList();

      // DEDUPLICATE DOCTORS IN CURRENT MONTH:
      // Captured doctor does not appear double when the month is past or when multiple records exist!
      final Map<String, HcpAccount> uniqueCurrent = {};
      for (final a in currentRaw) {
        final key = _getDoctorDeduplicationKey(a);
        if (!uniqueCurrent.containsKey(key)) {
          uniqueCurrent[key] = a;
        } else {
          final existing = uniqueCurrent[key]!;
          if (existing.workplaces.isEmpty && a.workplaces.isNotEmpty) {
            uniqueCurrent[key] = a;
          } else if (existing.specialties.isEmpty && a.specialties.isNotEmpty) {
            uniqueCurrent[key] = a;
          } else if (existing.contacts.isEmpty && a.contacts.isNotEmpty) {
            uniqueCurrent[key] = a;
          } else if (!existing.isRolledOver && a.isRolledOver) {
            uniqueCurrent[key] = a;
          }
        }
      }
      _filteredAccounts = uniqueCurrent.values.toList();
    } else if (effectiveCycle == 'Archived / Past') {
      if (_openedArchiveFolder != null && _archivedFolders.containsKey(_openedArchiveFolder)) {
        // Viewing doctors inside a specific month folder
        final folderAccs = _archivedFolders[_openedArchiveFolder] ?? [];
        _filteredAccounts = folderAccs.where((acc) => matchesDoctorFilters(acc)).toList();
      } else {
        // Folder directory view (filtered accounts will hold all matching archived doctors for search counts)
        final allArchived = <HcpAccount>[];
        _archivedFolders.forEach((_, list) {
          allArchived.addAll(list.where((acc) => matchesDoctorFilters(acc)));
        });
        _filteredAccounts = allArchived;
      }
    } else {
      // All Accounts (Admin / SFE)
      final allRaw = baseList.where((acc) => matchesDoctorFilters(acc)).toList();
      final Map<String, HcpAccount> uniqueAll = {};
      for (final a in allRaw) {
        final key = _getDoctorDeduplicationKey(a);
        if (!uniqueAll.containsKey(key)) {
          uniqueAll[key] = a;
        } else {
          final existing = uniqueAll[key]!;
          if (a.isCurrentMonthActive() && !existing.isCurrentMonthActive()) {
            uniqueAll[key] = a;
          }
        }
      }
      _filteredAccounts = uniqueAll.values.toList();
    }

    // 4. Sort filtered accounts
    _filteredAccounts.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case 'ID':
          cmp = (a.name ?? '').compareTo(b.name ?? '');
          break;
        case 'Type':
          cmp = _getMatchedDoctor(a).hcpType.compareTo(_getMatchedDoctor(b).hcpType);
          break;
        case 'Practice':
          cmp = _getMatchedDoctor(a).hcpPractice.compareTo(_getMatchedDoctor(b).hcpPractice);
          break;
        case 'Name of Doctor':
        default:
          final aName = _getDoctorFullName(a);
          final bName = _getDoctorFullName(b);
          cmp = aName.compareTo(bName);
          break;
      }
      return _isAscending ? cmp : -cmp;
    });
  }

  // --- READ-ONLY HCP ACCOUNT DETAILS SHEET ---
  Future<void> _showAccountDetail(HcpAccount account) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    HcpAccount fullAccount = account;
    if (account.name != null) {
      try {
        final fetched = await apiService.fetchHcpAccountDetail(account.name!);
        fullAccount = fetched.copyWith(
          specialties: fetched.specialties.isNotEmpty ? fetched.specialties : account.specialties,
          workplaces: fetched.workplaces.isNotEmpty ? fetched.workplaces : account.workplaces,
          contacts: fetched.contacts.isNotEmpty ? fetched.contacts : account.contacts,
          specialty: (fetched.specialty != null && fetched.specialty!.isNotEmpty) ? fetched.specialty : account.specialty,
          subSpecialty: (fetched.subSpecialty != null && fetched.subSpecialty!.isNotEmpty) ? fetched.subSpecialty : account.subSpecialty,
          workplaceId: (fetched.workplaceId != null && fetched.workplaceId!.isNotEmpty) ? fetched.workplaceId : account.workplaceId,
          contactNumber: (fetched.contactNumber != null && fetched.contactNumber!.isNotEmpty) ? fetched.contactNumber : account.contactNumber,
          contactEmail: (fetched.contactEmail != null && fetched.contactEmail!.isNotEmpty) ? fetched.contactEmail : account.contactEmail,
        );
      } catch (_) {}
    }

    if (!mounted) return;

    final doctorFullName = _getDoctorFullName(fullAccount);
    final hcpUniqueId = fullAccount.hcp ?? 'HCP-0000012';
    final matchedDoctor = _getMatchedDoctor(fullAccount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Color(0xFF0B192C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            "HCP ACCOUNT DETAILS",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF0066FF).withValues(alpha: 0.2),
                          backgroundImage: (matchedDoctor.hcpPhoto != null && matchedDoctor.hcpPhoto!.isNotEmpty)
                              ? NetworkImage(
                                  apiService.formatFileUrl(matchedDoctor.hcpPhoto),
                                  headers: apiService.authHeaders,
                                )
                              : null,
                          child: (matchedDoctor.hcpPhoto == null || matchedDoctor.hcpPhoto!.isEmpty)
                              ? const Icon(Icons.account_box_rounded, color: Color(0xFF38BDF8), size: 24)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctorFullName,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                fullAccount.name ?? 'HCP-ACC-00004',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'monospace', fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 12),

                    // ACCOUNT / SALES PERSON / TERRITORY INFO (Read-only)
                    const Text('ACCOUNT / SALES PERSON / TERRITORY INFO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    _buildReadonlyField('Account/Program *', fullAccount.accountName.isNotEmpty ? fullAccount.accountName : 'CORPORATE INNOVATION GROUP', isMandatory: true),
                    const SizedBox(height: 10),
                    _buildReadonlyField('Territory/MR Code *', (fullAccount.territory != null && fullAccount.territory!.isNotEmpty) ? fullAccount.territory! : '-', subtitle: 'Specify the territory or med rep code', isMandatory: true),
                    const SizedBox(height: 10),
                    _buildReadonlyField('Territory Manager *', (fullAccount.salesPerson != null && fullAccount.salesPerson!.isNotEmpty) ? fullAccount.salesPerson! : '-', isMandatory: true),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 12),

                    // MONTHLY VALIDITY & ARCHIVE STATUS
                    const Text('MONTHLY VALIDITY & ARCHIVE STATUS', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 500;
                        if (isWide) {
                          return Row(
                            children: [
                              Expanded(child: _buildReadonlyField('Valid From (Start Date)', fullAccount.validFrom ?? HcpAccount.calculateMonthValidFrom())),
                              const SizedBox(width: 12),
                              Expanded(child: _buildReadonlyField('Valid To (End Date)', fullAccount.validTo ?? HcpAccount.calculateMonthValidTo())),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildReadonlyField('Valid From (Start Date)', fullAccount.validFrom ?? HcpAccount.calculateMonthValidFrom()),
                            const SizedBox(height: 10),
                            _buildReadonlyField('Valid To (End Date)', fullAccount.validTo ?? HcpAccount.calculateMonthValidTo()),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildReadonlyField(
                      'Monthly Cycle Status',
                      fullAccount.isCurrentMonthActive()
                          ? (fullAccount.isRolledOver
                              ? 'Active (Carried Over from Previous Cycle)'
                              : 'Active (Current Month List)')
                          : 'Archived / Past Month (${fullAccount.monthLabel})',
                      subtitle: 'Active list is maintained dynamically for the current month cycle. Past months are safely archived.',
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 12),

                    // DOCTOR INFO (Read-only Responsive Row/Column)
                    const Text('DOCTOR INFO', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    const Text('Contains related information about the doctor being covered', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 500) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildReadonlyField('HCP Name', doctorFullName),
                              const SizedBox(height: 10),
                              _buildReadonlyField('HCP/Doctor Unique ID', hcpUniqueId),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: _buildReadonlyField('HCP Name', doctorFullName)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildReadonlyField('HCP/Doctor Unique ID', hcpUniqueId)),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 12),

                    // SPECIALIZATION (Read-only with data retention from previous month)
                    Row(
                      children: [
                        const Text('SPECIALIZATION', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0066FF).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 12),
                              SizedBox(width: 3),
                              Text('Preferred', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final allSpecs = _getEffectiveSpecialties(fullAccount);
                        final prefSpecs = allSpecs.where((s) => s.preferred || s.isPrimary).toList();
                        final displaySpecs = prefSpecs.isNotEmpty
                            ? [prefSpecs.first]
                            : (allSpecs.isNotEmpty ? [allSpecs.first] : <HcpAccountSpecialization>[]);

                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                color: const Color(0xFF0F172A),
                                child: const Row(
                                  children: [
                                    Expanded(child: Text('Specialty', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                    Expanded(child: Text('Sub-Specialty', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ),
                              if (displaySpecs.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text('General Practice', style: TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                      Expanded(child: Text('-', style: TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                )
                              else
                                ...displaySpecs.map((s) {
                                  final isPref = s.preferred || s.isPrimary;
                                  return Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              if (isPref) ...[
                                                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                                                const SizedBox(width: 4),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  s.specialty,
                                                  style: TextStyle(
                                                    color: isPref ? const Color(0xFFFCD34D) : Colors.white,
                                                    fontWeight: isPref ? FontWeight.bold : FontWeight.normal,
                                                    fontSize: 13,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isPref && !apiService.isMedRep) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                                                  ),
                                                  child: const Text('Preferred', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Expanded(child: Text(s.subSpecialty ?? '-', style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 12),

                    // WORKPLACE (Read-only with data retention from previous month)
                    Row(
                      children: [
                        const Text('WORKPLACE', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0066FF).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 12),
                              SizedBox(width: 3),
                              Text('Preferred', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final allWps = _getEffectiveWorkplaces(fullAccount);
                        final prefWorkplaces = allWps.where((w) => w.preferred || w.isPrimary).toList();
                        final displayWorkplaces = prefWorkplaces.isNotEmpty
                            ? [prefWorkplaces.first]
                            : (allWps.isNotEmpty ? [allWps.first] : <HcpAccountWorkplace>[]);

                        final isWorkplaceRejected = fullAccount.isWorkplaceRejected(apiService.cachedInstitutions);
                        final rejectionReason = fullAccount.getRejectedInstitutionReason(apiService.cachedInstitutions);
                        final effectiveNote = fullAccount.effectiveWorkplaceApprovalNote;
                        final isNoteRejected = isWorkplaceRejected || effectiveNote.toUpperCase().contains('REJECTED');
                        final isNoteApproved = !isNoteRejected && effectiveNote.toLowerCase().contains('approved') && !effectiveNote.toLowerCase().contains('pending');

                        final noteColor = isNoteRejected
                            ? const Color(0xFFEF4444)
                            : (isNoteApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B));
                        final noteTextColor = isNoteRejected
                            ? const Color(0xFFF87171)
                            : (isNoteApproved ? const Color(0xFF34D399) : const Color(0xFFFBBF24));

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isWorkplaceRejected ? const Color(0xFFEF4444).withValues(alpha: 0.6) : const Color(0xFF334155),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    color: const Color(0xFF0F172A),
                                    child: const Row(
                                      children: [
                                        Expanded(child: Text('Workplace', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                        Expanded(child: Text('City / Province', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  ),
                                  if (displayWorkplaces.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text('Manila Doctors Hospital', style: TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                          Expanded(child: Text('Ermita, Metro Manila', style: TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    )
                                  else
                                    ...displayWorkplaces.map((w) {
                                      final isPref = w.preferred || w.isPrimary;
                                      final isWpRejected = LocationResolver.isRejectedInstitution(w.workplace, apiService.cachedInstitutions);
                                      final locStr = LocationResolver.formatLocation(
                                        cityMunicipality: w.city,
                                        provinceName: w.province,
                                      );
                                      return Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  if (isPref) ...[
                                                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  Expanded(
                                                    child: Text(
                                                      LocationResolver.resolveInstitutionName(w.workplace),
                                                      style: TextStyle(
                                                        color: isWpRejected
                                                            ? const Color(0xFFEF4444)
                                                            : (isPref ? const Color(0xFFFCD34D) : Colors.white),
                                                        fontWeight: (isWpRejected || isPref) ? FontWeight.bold : FontWeight.normal,
                                                        fontSize: 13,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isWpRejected) ...[
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: const Color(0xFFEF4444), width: 0.8),
                                                      ),
                                                      child: const Text('REJECTED', style: TextStyle(color: Color(0xFFF87171), fontSize: 9, fontWeight: FontWeight.bold)),
                                                    ),
                                                  ] else if (isPref && !apiService.isMedRep) ...[
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                                                      ),
                                                      child: const Text('Preferred', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold)),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            Expanded(child: Text(locStr, style: TextStyle(color: isWpRejected ? const Color(0xFFF87171) : Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                            if (effectiveNote.isNotEmpty || isNoteRejected) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: noteColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: noteColor.withValues(alpha: 0.5),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isNoteRejected
                                          ? Icons.cancel_rounded
                                          : (isNoteApproved ? Icons.check_circle_rounded : Icons.hourglass_top_rounded),
                                      size: 14,
                                      color: noteTextColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isNoteRejected && rejectionReason != null && !effectiveNote.contains(rejectionReason)
                                          ? '[REJECTED INSTITUTION: $rejectionReason]'
                                          : effectiveNote,
                                      style: TextStyle(
                                        color: noteTextColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 12),

                    // CONTACT INFORMATION (MOBILE & EMAIL with data retention from previous month)
                    Row(
                      children: [
                        const Text('CONTACT INFORMATION', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0066FF).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 12),
                              SizedBox(width: 3),
                              Text('Preferred', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final allContacts = _getEffectiveContacts(fullAccount);
                        final prefContacts = allContacts.where((c) => c.preferred || c.isPrimary).toList();
                        final displayContacts = prefContacts.isNotEmpty
                            ? [prefContacts.first]
                            : (allContacts.isNotEmpty ? [allContacts.first] : <HcpAccountContact>[]);

                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                color: const Color(0xFF0F172A),
                                child: const Row(
                                  children: [
                                    Expanded(child: Text('Contact Type', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                    Expanded(child: Text('Contact Value', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ),
                              if (displayContacts.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text('Mobile', style: TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                      Expanded(child: Text('-', style: TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                )
                              else
                                ...displayContacts.map((c) {
                                  final isPref = c.preferred || c.isPrimary;
                                  return Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              if (isPref) ...[
                                                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                                                const SizedBox(width: 4),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  c.contactType,
                                                  style: TextStyle(
                                                    color: isPref ? const Color(0xFFFCD34D) : Colors.white,
                                                    fontWeight: isPref ? FontWeight.bold : FontWeight.normal,
                                                    fontSize: 13,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isPref && !apiService.isMedRep) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                                                  ),
                                                  child: const Text('Preferred', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Expanded(child: Text(c.contactValue, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close Details', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        if (apiService.isAdmin) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0066FF),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                              label: const Text('Update HCP Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final apiService = Provider.of<ApiService>(context, listen: false);
                                Hcp docToProfile = matchedDoctor;
                                if (fullAccount.hcp != null && fullAccount.hcp!.isNotEmpty) {
                                  try {
                                    docToProfile = await apiService.fetchDoctorDetail(fullAccount.hcp!);
                                  } catch (_) {}
                                }
                                if (!mounted) return;
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HcpWizardScreen(doctor: docToProfile),
                                  ),
                                );
                                if (result == true) {
                                  _loadAccounts();
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadonlyField(String label, String value, {String? subtitle, bool isMandatory = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            if (isMandatory)
              const Text(' *', style: TextStyle(color: Color(0xFFFF453A), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
        ],
      ],
    );
  }

  Widget _buildCycleFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedCycleFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCycleFilter = value;
          _openedArchiveFolder = null; // Always reset folder view when toggling cycle filter
          _applyFilters();
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ARCHIVE FOLDER DIRECTORY WIDGET (Folder format for historical months) ---
  Widget _buildArchiveFolderDirectory(bool isMobile) {
    final sortedFolders = _archivedFolders.keys.toList()
      ..sort((a, b) {
        final accA = _archivedFolders[a]!.first;
        final accB = _archivedFolders[b]!.first;
        return accB.monthKey.compareTo(accA.monthKey); // Chronological descending (newest past month first)
      });

    if (sortedFolders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_off_rounded, size: 56, color: Color(0xFF94A3B8)),
              SizedBox(height: 14),
              Text(
                'No Past Archived Cycles Found',
                style: TextStyle(color: Color(0xFF475569), fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'When monthly cycles conclude, past captured HCP accounts are safely archived here by month.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Directory Header Information Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0B192C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder_special_rounded, color: Color(0xFF38BDF8), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MONTHLY ARCHIVE DIRECTORY',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Click any month folder below to view the archived doctors for that cycle. Zero redundancy, clean alignment.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Monthly Folder Cards
        ...sortedFolders.map((month) {
          final docsInFolder = _archivedFolders[month] ?? [];
          final sampleAcc = docsInFolder.isNotEmpty ? docsInFolder.first : null;
          final validFrom = sampleAcc?.validFrom ?? '-';
          final validTo = sampleAcc?.validTo ?? '-';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: const [
                BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _openedArchiveFolder = month;
                    _applyFilters();
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Folder Icon Badge
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0B192C), Color(0xFF1E293B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.folder_rounded, color: Color(0xFFF59E0B), size: 28),
                      ),
                      const SizedBox(width: 14),
                      // Folder Information
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Builder(builder: (context) {
                                  final cleanMonth = month.replaceAll(RegExp(r'\s+Archive$', caseSensitive: false), '').trim();
                                  return Text(
                                    '$cleanMonth Archive',
                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
                                  );
                                }),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0066FF).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF0066FF).withValues(alpha: 0.3), width: 0.6),
                                  ),
                                  child: Text(
                                    '${docsInFolder.length} ${docsInFolder.length == 1 ? "Doctor" : "Doctors"}',
                                    style: const TextStyle(color: Color(0xFF0066FF), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cycle: $validFrom to $validTo • Non-redundant, clean snapshot',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Open Folder Action Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Open', style: TextStyle(color: Color(0xFF0B192C), fontSize: 12, fontWeight: FontWeight.bold)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF0B192C)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- BREADCRUMB BAR (When inside a specific archive month folder) ---
  Widget _buildArchiveFolderBreadcrumb() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1.0)),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              setState(() {
                _openedArchiveFolder = null;
                _applyFilters();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF475569)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, color: Color(0xFF38BDF8), size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Back to Archive Folders',
                    style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.folder_open_rounded, color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Builder(builder: (context) {
              final cleanOpened = (_openedArchiveFolder ?? '').replaceAll(RegExp(r'\s+Archive$', caseSensitive: false), '').trim();
              return Text(
                '$cleanOpened Archive (${_filteredAccounts.length} Doctors)',
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- ERPNext Filter Bar (Darkish Blue #0B192C Theme) ---
  Widget _buildFilterAndSortBar() {
    final apiService = Provider.of<ApiService>(context);
    final currentMonthLabel = HcpAccount.calculateMonthLabel();
    final validFromStr = HcpAccount.calculateMonthValidFrom();
    final validToStr = HcpAccount.calculateMonthValidTo();

    return Container(
      color: const Color(0xFF0B192C),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic Monthly Validity Cycle Banner for HCP Account
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0066FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.date_range_rounded, color: Color(0xFF38BDF8), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Monthly Validity Cycle: $currentMonthLabel',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 0.8),
                            ),
                            child: const Text('ACTIVE CYCLE', style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Valid: $validFromStr to $validToStr • Dynamic month cycle${_filteredAccounts.any((a) => a.isRolledOver) ? ' • Auto-carried over from previous cycle' : ''}',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Monthly Cycle Segment Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCycleFilterChip('Current Month ($currentMonthLabel)', 'Current Month', Icons.calendar_month_rounded),
                const SizedBox(width: 8),
                _buildCycleFilterChip('Archived / Past Months (Folders)', 'Archived / Past', Icons.folder_copy_outlined),
                if (apiService.isAdmin || apiService.isSfe) ...[
                  const SizedBox(width: 8),
                  _buildCycleFilterChip('All Accounts', 'All', Icons.people_alt_outlined),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Filter Toggle Button
              InkWell(
                onTap: () => setState(() => _showFilters = !_showFilters),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _showFilters ? 'Filter ✕' : 'Filter',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Sort Direction Button
              InkWell(
                onTap: () {
                  setState(() {
                    _isAscending = !_isAscending;
                    _applyFilters();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Icon(
                    _isAscending ? Icons.arrow_downward : Icons.arrow_upward,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sort Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    dropdownColor: const Color(0xFF1E293B),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'Name of Doctor', child: Text('Name of Doctor')),
                      DropdownMenuItem(value: 'ID', child: Text('ID')),
                      DropdownMenuItem(value: 'Type', child: Text('Type')),
                      DropdownMenuItem(value: 'Practice', child: Text('Practice')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _sortBy = val;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),

          if (_showFilters) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Program Filter Dropdown (Admin / SFE)
                if (apiService.isAdmin || apiService.isSfe) ...[
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _programFilter,
                        dropdownColor: const Color(0xFF1E293B),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _programFilter = val;
                              _applyFilters();
                            });
                          }
                        },
                        items: [
                          const DropdownMenuItem(value: 'All', child: Text('Program: All')),
                          ...apiService.availablePrograms.map((p) => DropdownMenuItem(value: p, child: Text(p))),
                        ],
                      ),
                    ),
                  ),
                ],

                // ID Filter Box
                SizedBox(
                  width: 120,
                  child: TextField(
                    onChanged: (val) {
                      _idQuery = val;
                      _applyFilters();
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'ID',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                    ),
                  ),
                ),

                // Name of Doctor Filter Box
                SizedBox(
                  width: 160,
                  child: TextField(
                    onChanged: (val) {
                      _nameQuery = val;
                      _applyFilters();
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Name of Doctor',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                    ),
                  ),
                ),

                // Is Active Checkbox Filter
                InkWell(
                  onTap: () {
                    setState(() {
                      _onlyIsActive = !_onlyIsActive;
                      _applyFilters();
                    });
                  },
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _onlyIsActive ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _onlyIsActive ? Icons.check_box : Icons.check_box_outline_blank,
                          color: _onlyIsActive ? const Color(0xFF38BDF8) : Colors.white54,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text('Is Active', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),

                // Type Filter Dropdown
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTypeFilter,
                      dropdownColor: const Color(0xFF1E293B),
                      hint: const Text('Type', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      onChanged: (val) {
                        setState(() {
                          _selectedTypeFilter = val;
                          _applyFilters();
                        });
                      },
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Types')),
                        ..._hcpTypes.map((t) => DropdownMenuItem(value: t.name, child: Text(t.typeName))),
                      ],
                    ),
                  ),
                ),

                // Practice Filter Dropdown
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPracticeFilter,
                      dropdownColor: const Color(0xFF1E293B),
                      hint: const Text('Practice', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      onChanged: (val) {
                        setState(() {
                          _selectedPracticeFilter = val;
                          _applyFilters();
                        });
                      },
                      items: const [
                        DropdownMenuItem<String>(value: null, child: Text('All Practices')),
                        DropdownMenuItem(value: 'Prescribing', child: Text('Prescribing')),
                        DropdownMenuItem(value: 'Dispensing', child: Text('Dispensing')),
                        DropdownMenuItem(value: 'Both', child: Text('Both')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('HCP Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF0B192C),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.white.withValues(alpha: 0.3),
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
              color: apiService.isSfe
                  ? const Color(0xFFA855F7).withValues(alpha: 0.25)
                  : (apiService.isAdmin
                      ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                      : (apiService.isManager
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                          : const Color(0xFF0066FF).withValues(alpha: 0.25))),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: apiService.isSfe
                    ? const Color(0xFFA855F7)
                    : (apiService.isAdmin
                        ? const Color(0xFFEF4444)
                        : (apiService.isManager
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF38BDF8))),
                width: 0.8,
              ),
            ),
            child: Text(
              apiService.userDesignationTitle,
              style: TextStyle(
                color: apiService.isSfe
                    ? const Color(0xFFD8B4FE)
                    : (apiService.isAdmin
                        ? const Color(0xFFFCA5A5)
                        : (apiService.isManager
                            ? const Color(0xFFFCD34D)
                            : const Color(0xFF93C5FD))),
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadAccounts,
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: const AppDrawer(currentItem: DrawerItem.doctorAccount),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0066FF)))
          : Column(
              children: [
                _buildFilterAndSortBar(),

                if (apiService.isMedRep)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFF1E293B),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline_rounded, color: Color(0xFF38BDF8), size: 14),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'View-Only Mode (MedRep): HCP account and territory assignments are read-only.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Responsive Layout: Folder Directory for Archive, Table/Cards for Doctor Lists
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 650;
                      final isArchiveDirectory = _selectedCycleFilter == 'Archived / Past' && _openedArchiveFolder == null;

                      // Display the monthly folders when in Archive view without a folder open
                      if (isArchiveDirectory) {
                        return _buildArchiveFolderDirectory(isMobile);
                      }

                      return Column(
                        children: [
                          // Sticky Breadcrumb Navigation Bar when inside a specific monthly archive folder
                          if (_selectedCycleFilter == 'Archived / Past' && _openedArchiveFolder != null)
                            _buildArchiveFolderBreadcrumb(),

                          if (!isMobile)
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
                                      flex: 4,
                                      child: Text('Name of Doctor', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                                    const SizedBox(
                                      width: 75,
                                      child: Text('Is Active', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                                    const Expanded(
                                      flex: 3,
                                      child: Text('Institution', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                                    const Expanded(
                                      flex: 3,
                                      child: Text('Practice', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                                    const Expanded(
                                      flex: 2,
                                      child: Text('Type', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                                    const Expanded(
                                      flex: 2,
                                      child: Text('ID', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    Container(width: 1, color: Colors.white38, margin: const EdgeInsets.symmetric(horizontal: 6)),
                                    SizedBox(
                                      width: 55,
                                      child: Builder(
                                        builder: (_) {
                                          final total = _getProgramTotalCount(apiService);
                                          final isFiltered = _filteredAccounts.length < total;
                                          return Text(
                                            isFiltered ? '${_filteredAccounts.length} of $total' : '$total',
                                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                                            textAlign: TextAlign.right,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                  ],
                                ),
                              ),
                            )
                          else
                            // Compact Count Bar for Mobile
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              color: const Color(0xFF0B192C),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedCycleFilter == 'Archived / Past' && _openedArchiveFolder != null
                                        ? 'ARCHIVED DOCTORS ($_openedArchiveFolder)'
                                        : 'HCP ACCOUNTS',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  Builder(
                                    builder: (_) {
                                      final total = _getProgramTotalCount(apiService);
                                      final isFiltered = _filteredAccounts.length < total;
                                      return Text(
                                        isFiltered
                                            ? 'Showing ${_filteredAccounts.length} of $total'
                                            : 'Total: $total Accounts',
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                          Expanded(
                            child: _filteredAccounts.isEmpty
                                ? const Center(
                                    child: Text('No HCP Accounts match your criteria.', style: TextStyle(color: Color(0xFF64748B))),
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadAccounts,
                                    color: const Color(0xFF0066FF),
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      itemCount: _filteredAccounts.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                                      itemBuilder: (ctx, index) {
                                        final item = _filteredAccounts[index];
                                        final doc = _getMatchedDoctor(item);
                                        final doctorFullName = _getDoctorFullName(item);
                                        final typeLabel = _hcpTypes.firstWhere((t) => t.name == doc.hcpType, orElse: () => HcpType(name: doc.hcpType, typeName: doc.hcpType)).typeName;

                                        // Retain and copy previous month workplace data
                                        final prefInstDisplay = _getEffectiveInstitutionDisplay(item, doc);

                                        if (isMobile) {
                                          return Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                              boxShadow: const [
                                                BoxShadow(color: Color(0x04000000), blurRadius: 3, offset: Offset(0, 1)),
                                              ],
                                            ),
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(10),
                                              onTap: () => _showAccountDetail(item),
                                              child: Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            doctorFullName,
                                                            style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13.5),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                          decoration: BoxDecoration(
                                                            color: item.isCurrentMonthActive() ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFF64748B).withValues(alpha: 0.1),
                                                            borderRadius: BorderRadius.circular(4),
                                                            border: Border.all(
                                                              color: item.isCurrentMonthActive() ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFCBD5E1),
                                                              width: 0.6,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            item.isCurrentMonthActive()
                                                                ? (item.isRolledOver
                                                                    ? '${item.validityPeriod ?? HcpAccount.calculateMonthLabel()} (Carried Over)'
                                                                    : (item.validityPeriod ?? HcpAccount.calculateMonthLabel()))
                                                                : 'Archived (${item.monthLabel})',
                                                            style: TextStyle(
                                                              color: item.isCurrentMonthActive() ? const Color(0xFF059669) : const Color(0xFF64748B),
                                                              fontSize: 9.5,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.domain_rounded, size: 13, color: Color(0xFF64748B)),
                                                        const SizedBox(width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            prefInstDisplay,
                                                            style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFF1F5F9),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            typeLabel,
                                                            style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w500),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF0066FF).withValues(alpha: 0.08),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            doc.hcpPractice,
                                                            style: const TextStyle(color: Color(0xFF0066FF), fontSize: 11, fontWeight: FontWeight.w600),
                                                          ),
                                                        ),
                                                        const Spacer(),
                                                        Text(
                                                          item.name ?? doc.name ?? '',
                                                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'monospace'),
                                                        ),
                                                        const SizedBox(width: 2),
                                                        const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }

                                        return Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                          ),
                                          child: InkWell(
                                            onTap: () => _showAccountDetail(item),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              child: Row(
                                                children: [
                                                  // Name of Doctor & Monthly Validity Badge
                                                  Expanded(
                                                    flex: 4,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          doctorFullName,
                                                          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                              decoration: BoxDecoration(
                                                                color: item.isCurrentMonthActive() ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFF64748B).withValues(alpha: 0.1),
                                                                borderRadius: BorderRadius.circular(4),
                                                                border: Border.all(
                                                                  color: item.isCurrentMonthActive() ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFCBD5E1),
                                                                  width: 0.6,
                                                                ),
                                                              ),
                                                              child: Text(
                                                                item.isCurrentMonthActive()
                                                                    ? (item.isRolledOver
                                                                        ? '${item.validityPeriod ?? HcpAccount.calculateMonthLabel()} (Carried Over)'
                                                                        : (item.validityPeriod ?? HcpAccount.calculateMonthLabel()))
                                                                    : 'Archived (${item.monthLabel})',
                                                                style: TextStyle(
                                                                  color: item.isCurrentMonthActive() ? const Color(0xFF059669) : const Color(0xFF64748B),
                                                                  fontSize: 9.5,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  // Is Active Check Icon
                                                  SizedBox(
                                                    width: 75,
                                                    child: Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: Icon(
                                                        doc.isActive ? Icons.check_box_rounded : Icons.check_box_outline_blank,
                                                        color: doc.isActive ? const Color(0xFF0066FF) : const Color(0xFFCBD5E1),
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),
                                                  // Institution
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      prefInstDisplay,
                                                      style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // Practice Tag Capsule
                                                  Expanded(
                                                    flex: 3,
                                                    child: Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(12),
                                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const CircleAvatar(radius: 3, backgroundColor: Color(0xFF0B192C)),
                                                            const SizedBox(width: 4),
                                                            Flexible(
                                                              child: Text(
                                                                doc.hcpPractice,
                                                                style: const TextStyle(color: Color(0xFF0B192C), fontSize: 11, fontWeight: FontWeight.w600),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Type
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      typeLabel,
                                                      style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  // ID
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      item.name ?? doc.name ?? 'HCP-ACC-00004',
                                                      style: const TextStyle(color: Color(0xFF64748B), fontFamily: 'monospace', fontSize: 11),
                                                      overflow: TextOverflow.ellipsis,
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
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: (apiService.isAdmin || apiService.isSfe)
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF0B192C),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20, color: Colors.white),
              label: const Text(
                'Add New Doctor',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HcpWizardScreen(isNewDoctor: true),
                  ),
                );
                if (result == true) {
                  _loadAccounts();
                }
              },
            )
          : null,
    );
  }
}
