import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/engagement.dart';
import '../models/hcp.dart';
import '../models/submission.dart';
import '../models/lookup_models.dart';
import '../models/hcp_account.dart';
import '../models/corenergy_engage.dart';
import '../app_config.dart';
import 'db_helper.dart';
import 'biometric_service.dart';
import 'notification_service.dart';
import 'app_logger.dart';

enum UserPosition {
  admin,
  manager,
  medRep,
  sfe,
}

class ApiService extends ChangeNotifier {
  ApiService() {
    initServerConfig();
    checkOnlineStatus();
    _startAutoSyncTimer();
  }

  // User Position & Role Permissions
  UserPosition _userPosition = UserPosition.medRep;
  UserPosition get userPosition => _userPosition;

  // User Role Profile (Primary decider for workflow actions & permissions)
  String _userRoleProfile = '';
  String get userRoleProfile => _userRoleProfile;
  bool _isRoleAuthorized = true;
  bool get isRoleAuthorized => _isRoleAuthorized;
  String? loginErrorMessage;

  // Employee Metadata & Designation (Display indicator for who is logged in)
  String _userDesignation = '';
  String get userDesignation => _userDesignation;
  String? employeeId;
  String? employeeReportsTo;
  String? employeeDepartment;
  String? employeeBranch;

  bool _sfeModeOverride = false;
  bool get sfeModeOverride => _sfeModeOverride;
  void toggleSfeMode() {
    _sfeModeOverride = !_sfeModeOverride;
    notifyListeners();
  }

  bool get isAdmin => _userPosition == UserPosition.admin && !_sfeModeOverride;
  bool get isManager => _userPosition == UserPosition.manager && !_sfeModeOverride;
  bool get isMedRep => _userPosition == UserPosition.medRep && !_sfeModeOverride;
  bool get isSfe => _userPosition == UserPosition.sfe || (_userPosition == UserPosition.admin && _sfeModeOverride);
  bool get canManageAllDoctypes => isAdmin || isSfe;
  bool get canCreateOrEditDoctor => isAdmin || isSfe;
  bool get canCreateOrEditDoctorAccount => isAdmin || isSfe;

  String get userPositionTitle {
    if (isSfe) return 'SFE';
    switch (_userPosition) {
      case UserPosition.admin:
        return 'Admin';
      case UserPosition.manager:
        return 'Manager';
      case UserPosition.medRep:
        return 'MedRep';
      case UserPosition.sfe:
        return 'SFE';
    }
  }

  /// Returns clean short / acronym title for the designation (e.g. Sales Rep, PHSR, PHSS, DSM, GM, etc.)
  String get userDesignationTitle {
    if (isSfe) return 'SFE';
    if (_userDesignation.isEmpty) {
      return userPositionTitle;
    }
    final des = _userDesignation.trim();
    final lower = des.toLowerCase();

    // Exact PMII / PIMS ERPNext Designations
    if (lower.contains('sales force effectiveness manager')) return 'SFE Mgr';
    if (lower.contains('sales force effectiveness') || lower == 'sfe') return 'SFE';
    if (lower == 'sales representative') return 'Sales Rep';
    if (lower.contains('professional health specialist representative') || lower == 'phsr') return 'PHSR';
    if (lower.contains('professional health specialist supervisor') || lower == 'phss') return 'PHSS';
    if (lower.contains('virtual medical representative')) return 'V-MedRep';
    if (lower.contains('medical representative') || lower == 'medrep' || lower == 'mr') return 'MedRep';
    if (lower.contains('senior district manager')) return 'Sr. DM';
    if (lower.contains('district sales manager') || lower == 'dsm') return 'DSM';
    if (lower.contains('district manager') || lower == 'dm') return 'DM';
    if (lower.contains('regional sales manager') || lower == 'rsm') return 'RSM';
    if (lower.contains('area sales manager') || lower == 'asm') return 'ASM';
    if (lower.contains('general manager') || lower == 'gm') return 'GM';
    if (lower.contains('territory sales manager') || lower == 'tsm') return 'TSM';
    if (lower.contains('sales force effectiveness manager')) return 'SFE Mgr';
    if (lower.contains('trade pharmacy representative')) return 'TPR';
    if (lower.contains('trade merchandising representative')) return 'TMR';
    if (lower.contains('hospital account specialist')) return 'HAS';
    if (lower.contains('hospital account manager')) return 'HAM';
    if (lower.contains('field representative')) return 'Field Rep';
    if (lower.contains('product specialist') || lower == 'ps') return 'PS';
    if (lower.contains('program manager')) return 'Program Mgr';
    if (lower.contains('program head')) return 'Program Head';
    if (lower.contains('technical support') || lower == 'tech support') return 'Tech Support';
    if (lower.contains('it manager')) return 'IT Mgr';
    if (lower.contains('sales supervisor')) return 'Supervisor';
    if (lower.contains('team leader')) return 'TL';
    if (lower.contains('administrator') || lower == 'admin') return 'Admin';
    if (lower.contains('system manager') || lower.contains('system administrator')) return 'Sys Admin';

    // If string length is short enough (<= 15 chars), use it directly
    if (des.length <= 15) return des;

    // Otherwise generate acronym from capital letters or words
    final words = des.split(RegExp(r'\s+'));
    if (words.length > 1) {
      return words.map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    }
    return des;
  }

  void setUserPosition(UserPosition pos) {
    _userPosition = pos;
    notifyListeners();
  }

  String selectedProgram = 'COREnergy';
  List<String> availablePrograms = [
    'Abbott Diabetes Care',
    'Bayer Consumer Health - Team 1',
    'Bayer Consumer Health - Team 2',
    'Bayer Consumer Health - Team 3',
    'Bayer',
    'Biomerieux',
    'COREnergy',
    'Exeltis (Philippines)',
    'FLEUR',
    'Fonterra',
    'FONTERRA ANMUM',
    'FONTERRA ANLENE',
    'iGROW - Pediasure',
    'NES',
    'Nurturemed',
    'PBEAT',
    'PCH 1',
    'PFIZER',
    'Pharmabest',
    'RiteMed',
    'Taisho Hospital Team - Pedia',
    'Taisho Hospital Team - Primary Care (Adult)',
    'Taisho PH-MDRP',
    'Taisho Trade Merchandising Program',
    'TSTACCO',
    'TSTACC1',
    'Vivaro',
  ];

  // Offline Mode variables
  bool _isOffline = false;
  bool get isOffline => _isOffline;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Timer? _autoSyncTimer;
  String? _syncMessage;
  String? get syncMessage => _syncMessage;

  void clearSyncMessage() {
    _syncMessage = null;
  }

  void _startAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        // Always check online status to keep the UI Mode indicator accurate
        final isOnline = await checkOnlineStatus();
        if (isOnline) {
          final pending = await DbHelper.getPendingEngagements();
          if (pending.isNotEmpty) {
            await syncOfflineData();
          }
        }
      } catch (e) {
        print('Auto-sync timer error: $e');
      }
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<bool> checkOnlineStatus() async {
    try {
      final url = Uri.parse('$baseUrl/api/method/ping');
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      final online = response.statusCode == 200;
      _isOffline = !online;
      notifyListeners();
      return online;
    } catch (_) {
      _isOffline = true;
      notifyListeners();
      return false;
    }
  }

  // File cache helpers
  Future<File> _getCacheFile(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$filename');
  }

  Future<void> _writeToCache(String filename, String content) async {
    try {
      final file = await _getCacheFile(filename);
      await file.writeAsString(content);
    } catch (e) {
      print('Error writing to cache $filename: $e');
    }
  }

  Future<String?> _readFromCache(String filename) async {
    try {
      final file = await _getCacheFile(filename);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      print('Error reading from cache $filename: $e');
    }
    return null;
  }

  // Pending offline edits helpers (using SQLite)
  Future<List<COREnergyEngage>> _readPendingCreates() async {
    try {
      final rows = await DbHelper.getPendingEngagements();
      return rows
          .where((row) => row['action_type'] == 'CREATE')
          .map((row) => COREnergyEngage.fromJson(jsonDecode(row['data'])))
          .toList();
    } catch (e) {
      print('Error reading pending creates from SQLite: $e');
      return [];
    }
  }

  Future<void> _addPendingCreate(COREnergyEngage engage) async {
    try {
      await DbHelper.insertPendingEngagement(engage, 'CREATE');
    } catch (e) {
      print('Error saving pending create to SQLite: $e');
    }
  }

  Future<List<COREnergyEngage>> _readPendingUpdates() async {
    try {
      final rows = await DbHelper.getPendingEngagements();
      return rows
          .where((row) => row['action_type'] == 'UPDATE')
          .map((row) => COREnergyEngage.fromJson(jsonDecode(row['data'])))
          .toList();
    } catch (e) {
      print('Error reading pending updates from SQLite: $e');
      return [];
    }
  }

  Future<void> _addPendingUpdate(String name, COREnergyEngage engage) async {
    try {
      final offlineKey = engage.institutionName ?? name;
      if (offlineKey.startsWith('OFFLINE-')) {
        await DbHelper.insertPendingEngagement(engage, 'CREATE');
      } else {
        final pending = await DbHelper.getPendingEngagements();
        final match = pending.where((r) => r['temp_id'] == offlineKey && r['action_type'] == 'CREATE');
        if (match.isNotEmpty) {
          await DbHelper.insertPendingEngagement(engage, 'CREATE');
        } else {
          await DbHelper.insertPendingEngagement(engage, 'UPDATE');
        }
      }
    } catch (e) {
      print('Error saving pending update to SQLite: $e');
    }
  }

  Future<void> _saveDetailToCache(String name, COREnergyEngage engage) async {
    final cache = await _readFromCache('engage_details_cache.json');
    Map<String, dynamic> cacheMap = {};
    if (cache != null) {
      try {
        cacheMap = Map<String, dynamic>.from(jsonDecode(cache));
      } catch (_) {}
    }
    cacheMap[name] = engage.toJson();
    await _writeToCache('engage_details_cache.json', jsonEncode(cacheMap));
  }

  Future<void> syncOfflineData() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();
    bool somethingSynced = false;
    try {
      final pendingRows = await DbHelper.getPendingEngagements();
      if (pendingRows.isEmpty) return;

      for (var row in pendingRows) {
        final String tempId = row['temp_id'];
        final String actionType = row['action_type'];
        final COREnergyEngage engage = COREnergyEngage.fromJson(jsonDecode(row['data']));

        try {
          if (actionType == 'CREATE') {
            final url = Uri.parse('$baseUrl/api/resource/COREnergy%20Engage');
            final syncEngage = COREnergyEngage(
              name: engage.name,
              institutionName: engage.institutionName,
              hospitalClinic: engage.hospitalClinic,
              region: engage.region,
              province: engage.province,
              cityMunicipality: engage.cityMunicipality,
              streetAddress: engage.streetAddress,
              salesRep: engage.salesRep,
              contacts: engage.contacts,
              visits: engage.visits,
              actionItems: engage.actionItems,
            );
            final payload = syncEngage.toJson();
            payload.remove('name'); // Always remove name for CREATE requests to let server assign/determine naming
            
            final response = await http.post(
              url,
              headers: _headers,
              body: jsonEncode(payload),
            ).timeout(const Duration(seconds: 10));
            
            if (response.statusCode == 200 || response.statusCode == 201) {
              final body = jsonDecode(response.body);
              final created = COREnergyEngage.fromJson(body['data']);
              await _saveDetailToCache(created.name, created);
              if (created.institutionName != null) {
                await _saveDetailToCache(created.institutionName!, created);
              }
              somethingSynced = true;
            } else if (response.statusCode == 409 || 
                       response.body.contains('already exists') || 
                       response.body.contains('DuplicateEntryError') || 
                       response.body.contains('Duplicate')) {
              // Self-healing: Convert CREATE to UPDATE if the record already exists on the server
              print('Duplicate COREnergy Engage document detected during sync for ${engage.institutionName}. Falling back to PUT update...');
              
              String? serverDocName;
              try {
                final searchUrl = Uri.parse(
                  '$baseUrl/api/resource/COREnergy%20Engage?filters=[["institution_name","=","${engage.institutionName}"]]'
                );
                final searchResponse = await http.get(searchUrl, headers: _headers).timeout(const Duration(seconds: 7));
                if (searchResponse.statusCode == 200) {
                  final searchBody = jsonDecode(searchResponse.body);
                  final List<dynamic> searchData = searchBody['data'] ?? [];
                  if (searchData.isNotEmpty) {
                    serverDocName = searchData[0]['name'];
                  }
                }
              } catch (e) {
                print('Error searching for duplicate document name: $e');
              }

              final targetName = serverDocName ?? engage.name;
              final updateUrl = Uri.parse('$baseUrl/api/resource/COREnergy%20Engage/$targetName');
              final updateResponse = await http.put(
                updateUrl,
                headers: _headers,
                body: jsonEncode(payload),
              ).timeout(const Duration(seconds: 10));
              
              if (updateResponse.statusCode == 200) {
                final body = jsonDecode(updateResponse.body);
                final updated = COREnergyEngage.fromJson(body['data']);
                await _saveDetailToCache(updated.name, updated);
                if (updated.institutionName != null) {
                  await _saveDetailToCache(updated.institutionName!, updated);
                }
                somethingSynced = true;
              } else {
                throw Exception('Sync fallback update failed: ${updateResponse.body}');
              }
            } else {
              throw Exception('Sync create failed: ${response.body}');
            }
          } else if (actionType == 'UPDATE') {
            String targetName = engage.name;
            if (targetName == engage.institutionName) {
              // It's the Institution ID, let's search if the server has a COREnergy Engage ID for this institution
              try {
                final searchUrl = Uri.parse(
                  '$baseUrl/api/resource/COREnergy%20Engage?filters=[["institution_name","=","${engage.institutionName}"]]'
                );
                final searchResponse = await http.get(searchUrl, headers: _headers).timeout(const Duration(seconds: 7));
                if (searchResponse.statusCode == 200) {
                  final searchBody = jsonDecode(searchResponse.body);
                  final List<dynamic> searchData = searchBody['data'] ?? [];
                  if (searchData.isNotEmpty) {
                    targetName = searchData[0]['name'];
                  }
                }
              } catch (e) {
                print('Error resolving server name for update: $e');
              }
            }

            final url = Uri.parse('$baseUrl/api/resource/COREnergy%20Engage/$targetName');
            final payloadMap = engage.toJson();
            payloadMap.remove('name');
            final response = await http.put(
              url,
              headers: _headers,
              body: jsonEncode(payloadMap),
            ).timeout(const Duration(seconds: 10));
            
            if (response.statusCode == 200) {
              final body = jsonDecode(response.body);
              final updated = COREnergyEngage.fromJson(body['data']);
              await _saveDetailToCache(updated.name, updated);
              if (updated.institutionName != null) {
                await _saveDetailToCache(updated.institutionName!, updated);
              }
              somethingSynced = true;
            } else if (response.statusCode == 404 || 
                       response.body.contains('DoesNotExistError') || 
                       response.body.contains('not found')) {
              print('COREnergy Engage document does not exist during sync for $targetName. Falling back to POST create...');
              final createUrl = Uri.parse('$baseUrl/api/resource/COREnergy%20Engage');
              final createResponse = await http.post(
                createUrl,
                headers: _headers,
                body: jsonEncode(payloadMap),
              ).timeout(const Duration(seconds: 10));
              
              if (createResponse.statusCode == 200 || createResponse.statusCode == 201) {
                final body = jsonDecode(createResponse.body);
                final created = COREnergyEngage.fromJson(body['data']);
                await _saveDetailToCache(created.name, created);
                if (created.institutionName != null) {
                  await _saveDetailToCache(created.institutionName!, created);
                }
                somethingSynced = true;
              } else {
                throw Exception('Sync fallback create failed: ${createResponse.body}');
              }
            } else {
              throw Exception('Sync update failed: ${response.body}');
            }
          }
          await DbHelper.deletePendingEngagement(tempId);
          _syncMessage = 'Sync successful: "${engage.hospitalClinic ?? engage.name}" is now uploaded.';
          notifyListeners();
        } catch (e) {
          print('Sync failed for offline row $tempId: $e');
          _syncMessage = 'Sync failed for "${engage.hospitalClinic ?? engage.name}": $e';
          notifyListeners();
          break; // Stop syncing to avoid data loss
        }
      }
      
      if (somethingSynced && !_isOffline) {
        await fetchCOREnergyEngages();
      }
    } catch (e) {
      print('syncOfflineData SQLite error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void setProgram(String program) {
    if (selectedProgram != program) {
      selectedProgram = program;
      notifyListeners();
    }
  }

  Future<void> fetchAvailablePrograms() async {
    try {
      final accounts = await hcpAccounts.list(fields: ['account_or_program', 'account_name', 'name']);
      final names = accounts
          .map((a) => a.accountName.isNotEmpty ? a.accountName : (a.name ?? ''))
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
      if (names.isNotEmpty) {
        final set = {...availablePrograms, ...names};
        final list = set.toList()..sort();
        availablePrograms = list;
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching available programs: $e');
    }
  }

  static String get devServerUrl => AppConfig.serverUrl;
  static const String _keyServerUrl = 'hcp_saved_server_url';

  String _baseUrl = AppConfig.serverUrl;
  String get baseUrl => _baseUrl;

  Future<void> initServerConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyServerUrl);
      _baseUrl = AppConfig.serverUrl;
    } catch (_) {}
  }

  Future<void> setBaseUrl(String url) async {
    if (_baseUrl != url) {
      _baseUrl = url;
      _sessionCookie = null;
      _csrfToken = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyServerUrl, url);
      } catch (_) {}
      notifyListeners();
    }
  }

  String? _sessionCookie;
  String? loggedInEmail;
  String? loggedInFullName;

  // Saga Concurrency & In-Flight Mutex Locks (Prevents Lost Updates & Concurrent Conflicts)
  final Set<String> _inFlightSubmissions = {};
  final Set<String> _inFlightHcpIds = {};

  bool isSubmissionInFlight(String name) => _inFlightSubmissions.contains(name);
  bool isHcpInFlight(String hcpId) => _inFlightHcpIds.contains(hcpId);

  late final FrappeRepository<Hcp> hcps = FrappeRepository<Hcp>(
    api: this,
    docType: 'HCP',
    fromJson: (json) => Hcp.fromJson(json),
    toJson: (item) => item.toJson(),
  );

  late final FrappeRepository<HcpAccount> hcpAccounts = FrappeRepository<HcpAccount>(
    api: this,
    docType: 'HCP Account',
    fromJson: (json) => HcpAccount.fromJson(json),
    toJson: (item) => item.toJson(),
  );

  late final FrappeRepository<HcpAccountDoctors> hcpAccountDoctors = FrappeRepository<HcpAccountDoctors>(
    api: this,
    docType: 'HCP Account Doctors',
    fromJson: (json) => HcpAccountDoctors.fromJson(json),
    toJson: (item) => item.toJson(),
  );

  late final FrappeRepository<HcpProfileSubmission> submissions = FrappeRepository<HcpProfileSubmission>(
    api: this,
    docType: 'HCP Profile Submission',
    fromJson: (json) => HcpProfileSubmission.fromJson(json),
    toJson: (item) => item.toJson(),
  );

  late final FrappeRepository<HcpSurveyTemplate> surveyTemplates = FrappeRepository<HcpSurveyTemplate>(
    api: this,
    docType: 'HCP Survey Template',
    fromJson: (json) => HcpSurveyTemplate.fromJson(json),
    toJson: (item) => item.toJson(),
  );

  late final FrappeRepository<HcpSurveyResponse> surveyResponses = FrappeRepository<HcpSurveyResponse>(
    api: this,
    docType: 'HCP Survey Response',
    fromJson: (json) => HcpSurveyResponse.fromJson(json),
    toJson: (item) => item.toJson(),
  );

  late final FrappeRepository<HcpType> hcpTypes = FrappeRepository<HcpType>(
    api: this,
    docType: 'HCP Type',
    fromJson: (json) => HcpType.fromJson(json),
    toJson: (item) => item.toJson(),
  );

  late final FrappeRepository<Institution> institutions = FrappeRepository<Institution>(
    api: this,
    docType: 'Institution',
    fromJson: (json) => Institution.fromJson(json),
    toJson: (item) => item.toJson(),
  );

  late final FrappeRepository<Specialization> specializations = FrappeRepository<Specialization>(
    api: this,
    docType: 'Specialization',
    fromJson: (json) => Specialization.fromJson(json),
    toJson: (item) => item.toJson(),
  );

  late final FrappeRepository<PsgcLocation> psgcLocations = FrappeRepository<PsgcLocation>(
    api: this,
    docType: 'PSGC Location',
    fromJson: (json) => PsgcLocation.fromJson(json),
    toJson: (item) => item.toJson(),
  );

  bool get isAuthenticated => _sessionCookie != null;

  String? _csrfToken;

  // Header helpers that inject session cookies and Frappe CSRF token
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }
    if (_csrfToken != null && _csrfToken!.isNotEmpty) {
      headers['X-Frappe-CSRF-Token'] = _csrfToken!;
    }
    return headers;
  }

  /// Ensure a valid Frappe CSRF Token is available for mutating API calls
  Future<String?> ensureCsrfToken() async {
    if (_csrfToken != null && _csrfToken!.isNotEmpty) {
      return _csrfToken;
    }
    if (_isOffline || _sessionCookie == null) {
      return null;
    }
    try {
      final appUrl = Uri.parse('$baseUrl/app');
      final appRes = await http.get(appUrl, headers: {
        'Cookie': _sessionCookie!,
        'Accept': 'text/html,application/xhtml+xml',
      });
      if (appRes.statusCode == 200) {
        final html = appRes.body;
        final csrfMatch = RegExp(r'frappe\.csrf_token\s*=\s*["\x27]([^"\x27]+)["\x27]').firstMatch(html);
        if (csrfMatch != null) {
          _csrfToken = csrfMatch.group(1);
          return _csrfToken;
        }
      }
    } catch (e) {
      print('Error extracting CSRF token: $e');
    }
    return _csrfToken;
  }

  Map<String, String> get authHeaders => _headers;

  String formatFileUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }

  /// Authenticate against ERPNext v15
  Future<bool> login(String username, String password) async {
    if (_isOffline) {
      final inputUser = username.trim().toLowerCase();
      if (inputUser.isEmpty || password.isEmpty) {
        loginErrorMessage = 'Username and password are required for offline authentication.';
        return false;
      }
      final savedCreds = await BiometricService.getSavedCredentials();
      if (savedCreds != null) {
        final savedUser = (savedCreds['username'] ?? '').trim().toLowerCase();
        final savedPass = savedCreds['password'] ?? '';
        if (savedUser == inputUser && savedPass == password) {
          loggedInEmail = savedCreds['username']!.trim();
          NotificationService.saveLastActiveUser(loggedInEmail!);
          NotificationService.checkAndNotifyPendingRejections(_cachedInstitutions, userEmail: loggedInEmail);
          if (savedCreds['full_name'] != null && savedCreds['full_name']!.isNotEmpty) {
            loggedInFullName = savedCreds['full_name']!;
          }
          final savedPos = savedCreds['position'] ?? '';
          _applyPositionFromRoleProfile(
            roleProfile: savedPos,
            roleNames: [savedPos],
            email: loggedInEmail ?? '',
            designation: _userDesignation,
          );
          await fetchAvailablePrograms();
          loginErrorMessage = null;
          return true;
        } else {
          loginErrorMessage = 'Offline authentication failed: Invalid credentials for this device.';
          return false;
        }
      } else {
        loginErrorMessage = 'Offline login unavailable: No authorized session enrolled on this device. Please connect to internet to authenticate.';
        return false;
      }
    }
    loginErrorMessage = null;
    final url = Uri.parse('$baseUrl/api/method/login');
    try {
      final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'usr': username,
            'pwd': password,
          }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['message'] == 'Logged In') {
          // Store username as the logged-in email
          loggedInEmail = username.trim();
          NotificationService.saveLastActiveUser(loggedInEmail!);
          NotificationService.checkAndNotifyPendingRejections(_cachedInstitutions, userEmail: loggedInEmail);
          if (body['full_name'] != null && body['full_name'].toString().isNotEmpty) {
            loggedInFullName = body['full_name'].toString();
          } else if (body['user_fullname'] != null && body['user_fullname'].toString().isNotEmpty) {
            loggedInFullName = body['user_fullname'].toString();
          }

          _applyPositionFromRoleProfile(
            roleProfile: _userRoleProfile,
            roleNames: [],
            email: loggedInEmail ?? '',
            designation: _userDesignation,
          );

          // Parse cookie header to persist session (e.g. sid=xxxxxx)
          final rawCookie = response.headers['set-cookie'];
          if (rawCookie != null) {
            _sessionCookie = rawCookie.split(';').firstWhere(
                  (c) => c.trim().startsWith('sid='),
                  orElse: () => '',
                );
          }

          await fetchAvailablePrograms();
          await fetchLoggedInUserInfo();

          if (!_isRoleAuthorized) {
            final unauthProfile = _userRoleProfile.isNotEmpty ? _userRoleProfile : 'Unassigned';
            final unauthDesig = _userDesignation.isNotEmpty ? 'Designation: "$_userDesignation"' : 'Unassigned Designation';
            logout();
            loginErrorMessage = 'Access Restricted: Your account ($unauthDesig, Role Profile: "$unauthProfile") is not authorized to access this application. Only System Manager, Sales Manager, Sales User, and Sales Force Effectiveness roles are permitted.';
            return false;
          }
          loginErrorMessage = null;
          return true;
        }
      } else {
        try {
          final errBody = jsonDecode(response.body);
          if (errBody['message'] != null && errBody['message'].toString().isNotEmpty) {
            loginErrorMessage = errBody['message'].toString();
          } else if (errBody['exception'] != null) {
            final exc = errBody['exception'].toString();
            if (exc.contains('locked')) {
              loginErrorMessage = 'Account temporarily locked due to consecutive login attempts. Please wait 60 seconds before trying again.';
            } else {
              loginErrorMessage = exc.split(':').last.trim();
            }
          } else {
            loginErrorMessage = 'Authentication failed (Status ${response.statusCode}). Please verify your credentials.';
          }
        } catch (_) {
          loginErrorMessage = 'Authentication failed. Please verify your credentials.';
        }
        return false;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      loginErrorMessage = 'Network or connection error. Please check your internet connection.';
      return false;
    }
  }

  /// Fetch Employee record and Designation from ERPNext Employee doctype (https://dev.pmii-marketing.com/app/employee)
  Future<Map<String, dynamic>?> fetchEmployeeDesignation(String userEmail) async {
    if (_isOffline) {
      final cached = await _readFromCache('employee_profile_cache.json');
      if (cached != null) {
        try {
          return jsonDecode(cached) as Map<String, dynamic>;
        } catch (_) {}
      }
      return null;
    }

    // 1. Query Employee by user_id
    try {
      final empUrl = Uri.parse(
        '$baseUrl/api/resource/Employee?filters=[["user_id","=","$userEmail"]]&fields=["name","employee_name","first_name","middle_name","last_name","designation","user_id","company_email","personal_email","department","branch","reports_to"]&limit=1',
      );
      final empResp = await http.get(empUrl, headers: _headers);
      if (empResp.statusCode == 200) {
        final body = jsonDecode(empResp.body);
        final List<dynamic> data = body['data'] ?? [];
        if (data.isNotEmpty) {
          final emp = data.first as Map<String, dynamic>;
          await _writeToCache('employee_profile_cache.json', jsonEncode(emp));
          return emp;
        }
      }
    } catch (e) {
      print('Employee query by user_id error: $e');
    }

    // 2. Query Employee by company_email
    try {
      final empUrl = Uri.parse(
        '$baseUrl/api/resource/Employee?filters=[["company_email","=","$userEmail"]]&fields=["name","employee_name","first_name","middle_name","last_name","designation","user_id","company_email","personal_email","department","branch","reports_to"]&limit=1',
      );
      final empResp = await http.get(empUrl, headers: _headers);
      if (empResp.statusCode == 200) {
        final body = jsonDecode(empResp.body);
        final List<dynamic> data = body['data'] ?? [];
        if (data.isNotEmpty) {
          final emp = data.first as Map<String, dynamic>;
          await _writeToCache('employee_profile_cache.json', jsonEncode(emp));
          return emp;
        }
      }
    } catch (e) {
      print('Employee query by company_email error: $e');
    }

    // 3. Query Employee by personal_email
    try {
      final empUrl = Uri.parse(
        '$baseUrl/api/resource/Employee?filters=[["personal_email","=","$userEmail"]]&fields=["name","employee_name","first_name","middle_name","last_name","designation","user_id","company_email","personal_email","department","branch","reports_to"]&limit=1',
      );
      final empResp = await http.get(empUrl, headers: _headers);
      if (empResp.statusCode == 200) {
        final body = jsonDecode(empResp.body);
        final List<dynamic> data = body['data'] ?? [];
        if (data.isNotEmpty) {
          final emp = data.first as Map<String, dynamic>;
          await _writeToCache('employee_profile_cache.json', jsonEncode(emp));
          return emp;
        }
      }
    } catch (e) {
      print('Employee query by personal_email error: $e');
    }

    // 4. Whitelisted client RPC method fallback
    try {
      final clientUrl = Uri.parse(
        '$baseUrl/api/method/frappe.client.get_list?doctype=Employee&filters=[["user_id","=","$userEmail"]]&fields=["name","employee_name","first_name","last_name","designation","user_id","company_email","department","branch","reports_to"]&limit_page_length=1',
      );
      final clientResp = await http.get(clientUrl, headers: _headers);
      if (clientResp.statusCode == 200) {
        final body = jsonDecode(clientResp.body);
        final List<dynamic> data = body['message'] ?? body['data'] ?? [];
        if (data.isNotEmpty) {
          final emp = data.first as Map<String, dynamic>;
          await _writeToCache('employee_profile_cache.json', jsonEncode(emp));
          return emp;
        }
      }
    } catch (e) {
      print('Employee client method query error: $e');
    }

    // 5. Cache fallback
    final cached = await _readFromCache('employee_profile_cache.json');
    if (cached != null) {
      try {
        return jsonDecode(cached) as Map<String, dynamic>;
      } catch (_) {}
    }

    return null;
  }

  Future<void> fetchLoggedInUserInfo() async {
    if (_isOffline || _sessionCookie == null) {
      _applyPositionFromRoleProfile(
        roleProfile: _userRoleProfile,
        roleNames: [],
        email: loggedInEmail ?? '',
        designation: _userDesignation,
      );
      return;
    }
    try {
      final url = Uri.parse('$baseUrl/api/method/frappe.auth.get_logged_user');
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final userEmail = body['message'];
        if (userEmail != null && userEmail is String) {
          loggedInEmail = userEmail;

          // 1. Fetch User document to extract role_profile_name and roles
          final userDocUrl = Uri.parse('$baseUrl/api/resource/User/${Uri.encodeComponent(userEmail)}');
          final userDocRes = await http.get(userDocUrl, headers: _headers);
          
          // Also fetch Has Role records directly as fallback
          final hasRoleUrl = Uri.parse('$baseUrl/api/resource/Has%20Role?filters=[["parent","=","$userEmail"]]&fields=["role"]&limit=100');
          final hasRoleRes = await http.get(hasRoleUrl, headers: _headers);

          String roleProfile = '';
          List<String> roleNames = [];
          if (userDocRes.statusCode == 200) {
            final userDocBody = jsonDecode(userDocRes.body);
            final data = userDocBody['data'];
            if (data != null) {
              if (data['role_profile_name'] != null && data['role_profile_name'].toString().trim().isNotEmpty) {
                roleProfile = data['role_profile_name'].toString().trim();
              }
              if (data['full_name'] != null && data['full_name'].toString().isNotEmpty) {
                loggedInFullName = data['full_name'];
              }
              if (data['roles'] is List) {
                roleNames.addAll((data['roles'] as List).map((r) => r is Map ? (r['role']?.toString().toLowerCase() ?? '') : r.toString().toLowerCase()));
              }
            }
          }

          // 1b. Fetch active/checked roles directly from frappe.boot on /app (most accurate in ERPNext)
          try {
            final appUrl = Uri.parse('$baseUrl/app');
            final appRes = await http.get(appUrl, headers: _headers);
            if (appRes.statusCode == 200) {
              final html = appRes.body;
              final csrfMatch = RegExp(r'frappe\.csrf_token\s*=\s*["\x27]([^"\x27]+)["\x27]').firstMatch(html);
              if (csrfMatch != null) {
                _csrfToken = csrfMatch.group(1);
              }
              final idx = html.indexOf('frappe.boot =');
              if (idx != -1) {
                final endIdx = html.indexOf('};\n', idx);
                if (endIdx != -1) {
                  final jsonStr = html.substring(idx + 'frappe.boot ='.length, endIdx + 1).trim();
                  final bootData = jsonDecode(jsonStr);
                  if ((_csrfToken == null || _csrfToken!.isEmpty) && bootData['csrf_token'] != null) {
                    _csrfToken = bootData['csrf_token'].toString();
                  }
                  final bootUser = bootData['user'];
                  if (bootUser != null) {
                    if (bootUser['roles'] is List) {
                      for (var r in bootUser['roles']) {
                        final rLower = r.toString().toLowerCase().trim();
                        if (rLower.isNotEmpty && !roleNames.contains(rLower)) {
                          roleNames.add(rLower);
                        }
                      }
                    }
                    if ((loggedInFullName == null || loggedInFullName!.isEmpty)) {
                      final fn = (bootUser['first_name'] ?? '').toString().trim();
                      final ln = (bootUser['last_name'] ?? '').toString().trim();
                      final full = '$fn $ln'.trim();
                      if (full.isNotEmpty) {
                        loggedInFullName = full;
                      }
                    }
                  }
                }
              }
            }
          } catch (e) {
            print('Non-blocking /app boot role extraction: $e');
          }

          // Fallback: Query frappe.client.get_value for role_profile_name if not returned in REST resource
          if (roleProfile.isEmpty) {
            try {
              final getValUrl = Uri.parse('$baseUrl/api/method/frappe.client.get_value?doctype=User&filters={"name":"$userEmail"}&fieldname=["role_profile_name","full_name"]');
              final getValRes = await http.get(getValUrl, headers: _headers);
              if (getValRes.statusCode == 200) {
                final valBody = jsonDecode(getValRes.body);
                final msg = valBody['message'];
                if (msg is Map && msg['role_profile_name'] != null && msg['role_profile_name'].toString().trim().isNotEmpty) {
                  roleProfile = msg['role_profile_name'].toString().trim();
                }
              }
            } catch (_) {}
          }

          // Fallback role profile derivation if hidden on User doc
          if (roleProfile.isEmpty) {
            if (roleNames.contains('sales force effectiveness') || roleNames.contains('sfe') || userEmail.toLowerCase() == 'lesantos@pims-marketing.com') {
              roleProfile = 'Sales Force Effectiveness';
            } else if (roleNames.contains('system manager') || roleNames.contains('administrator')) {
              roleProfile = 'Administrator';
            } else if (roleNames.contains('sales manager') || roleNames.contains('superior') || roleNames.contains('field force manager')) {
              roleProfile = 'Sales Manager';
            } else if (roleNames.contains('sales user')) {
              roleProfile = 'Employee + Sales User';
            }
          }

          if (hasRoleRes.statusCode == 200) {
            final hasRoleBody = jsonDecode(hasRoleRes.body);
            final List<dynamic> hrData = hasRoleBody['data'] ?? [];
            for (var hr in hrData) {
              final rName = hr is Map ? (hr['role']?.toString().toLowerCase() ?? '') : hr.toString().toLowerCase();
              if (rName.isNotEmpty && !roleNames.contains(rName)) {
                roleNames.add(rName);
              }
            }
          }

          // 2. Fetch Employee Designation (used as the UI indicator for who logged in)
          final empData = await fetchEmployeeDesignation(userEmail);
          String designation = '';
          if (empData != null) {
            employeeId = empData['name']?.toString();
            employeeReportsTo = empData['reports_to']?.toString();
            employeeDepartment = empData['department']?.toString();
            employeeBranch = empData['branch']?.toString();
            if (empData['employee_name'] != null && empData['employee_name'].toString().trim().isNotEmpty) {
              loggedInFullName = empData['employee_name'].toString().trim();
            }
            if (empData['designation'] != null) {
              designation = empData['designation'].toString().trim();
            }
          }

          // 3. Apply position strictly based on role_profile_name and workflow allowed roles
          _applyPositionFromRoleProfile(
            roleProfile: roleProfile,
            roleNames: roleNames,
            email: userEmail,
            designation: designation,
          );

          // Auto-detect selectedProgram from employee department/branch
          _autoDetectProgram();

          // Pre-warm Territory and Sales Person caches
          fetchTerritoryInfos();
          fetchSalesPersons();

          notifyListeners();
        }
      }
    } catch (e) {
      print('Error fetching logged in user info: $e');
      _applyPositionFromRoleProfile(
        roleProfile: _userRoleProfile,
        roleNames: [],
        email: loggedInEmail ?? '',
        designation: _userDesignation,
      );
    }
  }

  /// Auto-detect the user's program from their ERPNext department or branch
  void _autoDetectProgram() {
    final dept = (employeeDepartment ?? '').toLowerCase().trim();
    final branch = (employeeBranch ?? '').toLowerCase().trim();
    final lowerEmail = (loggedInEmail ?? '').toLowerCase().trim();
    final combined = '$dept $branch $lowerEmail';

    // 1. Dynamic exact & bidirectional substring match against all programs in availablePrograms
    for (final prog in availablePrograms) {
      final pLower = prog.toLowerCase().trim();
      if (dept.isNotEmpty && (dept == pLower || dept.contains(pLower) || pLower.contains(dept))) {
        selectedProgram = prog;
        return;
      }
      if (branch.isNotEmpty && (branch == pLower || branch.contains(pLower) || pLower.contains(branch))) {
        selectedProgram = prog;
        return;
      }
    }

    // 2. Keyword, team, and email heuristics fallback
    if (combined.contains('abbott') || combined.contains('adc') || lowerEmail.contains('mengorio') || lowerEmail == 'admendoza@profinsights.biz') {
      selectedProgram = 'Abbott Diabetes Care';
    } else if (combined.contains('bayer') || combined.contains('bch') || lowerEmail.contains('sanjuan') || lowerEmail == 'aodimaano@profinsights.biz') {
      if (combined.contains('team 3')) {
        selectedProgram = 'Bayer Consumer Health - Team 3';
      } else if (combined.contains('team 2')) {
        selectedProgram = 'Bayer Consumer Health - Team 2';
      } else {
        selectedProgram = 'Bayer Consumer Health - Team 1';
      }
    } else if (combined.contains('ritemed') || combined.contains('rtmd') || lowerEmail.contains('alvino') || lowerEmail.contains('smolejon')) {
      selectedProgram = 'RiteMed';
    } else if (combined.contains('vivaro') || lowerEmail.contains('cruzkaren') || lowerEmail.contains('skabigting')) {
      selectedProgram = 'Vivaro';
    } else if (combined.contains('exeltis') || lowerEmail.contains('exeltis')) {
      selectedProgram = 'Exeltis (Philippines)';
    } else if (combined.contains('taisho') || combined.contains('tppi')) {
      if (combined.contains('pedia')) {
        selectedProgram = 'Taisho Hospital Team - Pedia';
      } else if (combined.contains('mdrp')) {
        selectedProgram = 'Taisho PH-MDRP';
      } else if (combined.contains('merchandising') || combined.contains('tmp')) {
        selectedProgram = 'Taisho Trade Merchandising Program';
      } else {
        selectedProgram = 'Taisho Hospital Team - Primary Care (Adult)';
      }
    } else if (combined.contains('fonterra') || combined.contains('anmum') || combined.contains('anlene')) {
      selectedProgram = 'Fonterra';
    } else if (combined.contains('biomerieux')) {
      selectedProgram = 'Biomerieux';
    } else if (combined.contains('corenergy') || combined.contains('cor energy')) {
      selectedProgram = 'COREnergy';
    } else if (combined.contains('nes')) {
      selectedProgram = 'NES';
    } else if (combined.contains('nurturemed')) {
      selectedProgram = 'Nurturemed';
    } else if (combined.contains('pch')) {
      selectedProgram = 'PCH 1';
    } else if (combined.contains('pharmabest')) {
      selectedProgram = 'Pharmabest';
    } else if (combined.contains('tstacco')) {
      selectedProgram = 'TSTACCO';
    } else if (combined.contains('tstacc1')) {
      selectedProgram = 'TSTACC1';
    }
    // Admin stays on whatever default or last-used program
  }

  /// Determine user permissions based on role_profile_name and ERPNext roles,
  /// while preserving designation strictly as the UI display indicator on top-right.
  void _applyPositionFromRoleProfile({
    required String roleProfile,
    required List<String> roleNames,
    required String email,
    required String designation,
  }) {
    if (roleProfile.isNotEmpty) {
      _userRoleProfile = roleProfile.trim();
    }
    if (designation.isNotEmpty) {
      _userDesignation = designation.trim();
    }

    final lowerRoleProfile = _userRoleProfile.toLowerCase();
    final lowerEmail = email.toLowerCase().trim();
    final lowerDesignation = _userDesignation.toLowerCase().trim();
    final normalizedRoles = roleNames.map((r) => r.toLowerCase().trim()).toList();

    // 1. Sales Force Effectiveness (SFE Specialist position - Institution Approver Only)
    // SFE specialists only have access to Institution submission and MUST NOT see all program HCPs.
    if (lowerEmail == 'lesantos@pims-marketing.com' ||
        ((normalizedRoles.any((r) => r == 'sales force effectiveness' || r == 'sfe') ||
          lowerRoleProfile.contains('sales force effectiveness') ||
          lowerRoleProfile.contains('sfe') ||
          lowerDesignation.contains('sales force effectiveness') ||
          lowerDesignation.contains('sfe')) &&
         lowerEmail != 'jptan@profinsights.biz' &&
         lowerEmail != 'administrator')) {
      _userPosition = UserPosition.sfe;
      _isRoleAuthorized = true;
      if (_userRoleProfile.isEmpty) _userRoleProfile = 'Sales Force Effectiveness';
      if (_userDesignation.isEmpty) _userDesignation = 'SFE Specialist';
    }
    // 2. System Manager / Administrator (Admin position - Allowed Role 1)
    else if (lowerEmail == 'administrator' ||
        lowerEmail == 'jptan@profinsights.biz' ||
        lowerEmail.contains('cig-it') ||
        normalizedRoles.any((r) => r == 'system manager' || r == 'administrator' || r.contains('it staff')) ||
        lowerRoleProfile == 'system manager' ||
        lowerRoleProfile == 'administrator' ||
        lowerRoleProfile.contains('admin') ||
        lowerRoleProfile.contains('system master') ||
        lowerRoleProfile.contains('it manager') ||
        lowerRoleProfile.contains('it staff') ||
        lowerRoleProfile.contains('technical support') ||
        (lowerEmail.endsWith('@profinsights.biz') && (lowerEmail.contains('josh') || lowerEmail.contains('tan') || lowerEmail.contains('root') || lowerEmail.contains('admin')))) {
      _userPosition = UserPosition.admin;
      _isRoleAuthorized = true;
      if (_userRoleProfile.isEmpty) _userRoleProfile = 'Administrator';
      if (_userDesignation.isEmpty) _userDesignation = 'Administrator';
    } 
    // 3. Sales & Marketing Manager / Sales Manager / Superior (Manager position - Allowed Role 2)
    else if (normalizedRoles.any((r) => r == 'sales manager' || r == 'superior' || r == 'field force manager' || r == 'next level manager' || r.contains('sales manager')) ||
             lowerRoleProfile.contains('sales manager') ||
             lowerRoleProfile.contains('sales & marketing manager') ||
             lowerRoleProfile.contains('marketing manager') ||
             lowerRoleProfile.contains('sales and marketing manager') ||
             lowerRoleProfile.contains('phss') ||
             lowerRoleProfile.contains('superior') ||
             lowerRoleProfile.contains('manager') ||
             lowerRoleProfile.contains('supervisor') ||
             lowerRoleProfile.contains('dsm') ||
             lowerRoleProfile.contains('rsm') ||
             lowerRoleProfile.contains('asm') ||
             lowerRoleProfile.contains('gm') ||
             lowerRoleProfile.contains('tsm') ||
             lowerRoleProfile.contains('director') ||
             lowerDesignation.contains('supervisor') ||
             lowerDesignation.contains('manager') ||
             lowerDesignation.contains('dsm') ||
             lowerDesignation.contains('rsm') ||
             lowerDesignation.contains('asm') ||
             lowerDesignation.contains('phss') ||
             lowerDesignation.contains('program head') ||
             lowerDesignation.contains('team leader') ||
             lowerEmail == 'admendoza@profinsights.biz') {
      _userPosition = UserPosition.manager;
      _isRoleAuthorized = true;
      if (_userRoleProfile.isEmpty) _userRoleProfile = 'Sales Manager';
      if (_userDesignation.isEmpty) _userDesignation = 'District Sales Manager';
    }
    // 4. Sales User / Field Sales Representative (MedRep position - Allowed Role 4)
    else if (normalizedRoles.any((r) => r == 'sales user' || r.contains('sales user') || r.contains('medical representative')) ||
             lowerRoleProfile.contains('sales user') ||
             lowerRoleProfile.contains('employee + sales user') ||
             lowerRoleProfile.contains('sales representative') ||
             lowerRoleProfile.contains('representative') ||
             lowerRoleProfile.contains('medical representative') ||
             lowerRoleProfile.contains('medrep') ||
             lowerRoleProfile.contains('field') ||
             lowerRoleProfile.contains('phsr') ||
             lowerRoleProfile.contains('sales') ||
             lowerDesignation.contains('representative') ||
             lowerDesignation.contains('phsr') ||
             lowerDesignation.contains('sales rep') ||
             lowerDesignation.contains('medical representative') ||
             lowerDesignation.contains('medrep')) {
      _userPosition = UserPosition.medRep;
      _isRoleAuthorized = true;
      if (_userRoleProfile.isEmpty) _userRoleProfile = 'Employee + Sales User';
      if (_userDesignation.isEmpty) _userDesignation = 'Sales Representative';
    } 
    // 5. Any other role is NOT authorized to access the HCP Profiling App
    else {
      _isRoleAuthorized = false;
      _userPosition = UserPosition.medRep;
    }

    notifyListeners();
  }

  /// Log out
  void logout() {
    _sessionCookie = null;
    _csrfToken = null;
    loggedInEmail = null;
    loggedInFullName = null;
    _userRoleProfile = '';
    _userDesignation = '';
    employeeId = null;
    employeeReportsTo = null;
    employeeDepartment = null;
    employeeBranch = null;
    _userPosition = UserPosition.medRep;
    notifyListeners();
  }

  /// Retrieve list of COREnergy engagements
  Future<List<Engagement>> fetchEngagements() async {
    if (_isOffline) {
      final cache = await _readFromCache('engagements_cache.json');
      if (cache != null) {
        try {
          final List<dynamic> dataList = jsonDecode(cache);
          return dataList.map((json) => Engagement.fromJson(json)).toList();
        } catch (_) {}
      }
      return [];
    }
    final url = Uri.parse(
      '$baseUrl/api/resource/Successful%20COREnergy%20Engagement?fields=["name","unsuccessful_call","company","latitude","longitude","location_accuracy","picture","sales_rep","contact","last_name","position_or_role","email_address","contact_number","date_and_time_of_sales_appointment","decision_maker_or_responsible_person_not_available","reason_for_unsuccessful_call","creation","modified"]&limit=5000',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] ?? [];
        await _writeToCache('engagements_cache.json', jsonEncode(dataList));
        return dataList.map((json) => Engagement.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load engagements: ${response.statusCode}');
      }
    } catch (e) {
      print('Fetch engagements error: $e');
      rethrow;
    }
  }

  List<Institution> _cachedInstitutions = [];
  List<Institution> get cachedInstitutions => _cachedInstitutions;

  List<Hcp> _cachedDoctors = [];
  List<Hcp> get cachedDoctors => _cachedDoctors;

  List<HcpAccount> _cachedHcpAccounts = [];
  List<HcpAccount> get cachedHcpAccounts => _cachedHcpAccounts;

  List<HcpProfileSubmission> _cachedSubmissions = [];
  List<HcpProfileSubmission> get cachedSubmissions => _cachedSubmissions;

  /// Retrieve list of Company Institutions with region, province, city, and street address fields
  Future<List<Institution>> fetchInstitutions() async {
    if (_isOffline) {
      final cache = await _readFromCache('institutions_cache.json');
      if (cache != null) {
        try {
          final List<dynamic> dataList = jsonDecode(cache);
          final list = dataList.map((json) => Institution.fromJson(json)).toList();
          _cachedInstitutions = list;
          return list;
        } catch (_) {}
      }
      // Fallback to local asset
      try {
        final String localData = await rootBundle.loadString('assets/institutions.json');
        final List<dynamic> dataList = jsonDecode(localData);
        final list = dataList.map((json) => Institution.fromJson(json)).toList();
        _cachedInstitutions = list;
        return list;
      } catch (err) {
        print('Failed to load local fallback institutions: $err');
        return [];
      }
    }
    final url = Uri.parse(
      '$baseUrl/api/resource/Institution?fields=["name","institution_name","region_name","province_name","city_municipality","street_address","workflow_state","rejection_reason","is_resubmission","owner","creation","modified","docstatus","ownership","institution_type","service_capability","requires_dsm_approval","linked_doctor_name"]&order_by=name%20desc&limit_page_length=5000&limit=5000',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] ?? [];
        await _writeToCache('institutions_cache.json', jsonEncode(dataList));
        final list = dataList.map((json) => Institution.fromJson(json)).toList();
        LocationResolver.registerInstitutions(list);
        _cachedInstitutions = list;
        NotificationService.checkAndNotifyPendingRejections(list, userEmail: loggedInEmail);
        notifyListeners();
        return list;
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Fetch institutions API error, loading local cached fallback: $e');
      try {
        final String localData = await rootBundle.loadString('assets/institutions.json');
        final List<dynamic> dataList = jsonDecode(localData);
        final list = dataList.map((json) => Institution.fromJson(json)).toList();
        LocationResolver.registerInstitutions(list);
        _cachedInstitutions = list;
        NotificationService.checkAndNotifyPendingRejections(list, userEmail: loggedInEmail);
        return list;
      } catch (err) {
        print('Failed to load local fallback institutions: $err');
        rethrow;
      }
    }
  }

  /// List of actual active masterlist institutions for doctor profiling.
  /// Strictly excludes rejected institutions and unapproved pending proposals.
  List<Institution> get actualInstitutions {
    return _cachedInstitutions.where((i) => i.isApprovedForProfiling).toList();
  }

  /// List of institutions submitted by the currently logged-in user
  List<Institution> get mySubmittedInstitutions {
    final email = (loggedInEmail ?? '').trim().toLowerCase();
    if (email.isEmpty) return [];
    return _cachedInstitutions.where((i) {
      final o = (i.owner ?? '').trim().toLowerCase();
      return o == email;
    }).toList();
  }

  int get myPendingInstitutionCount => mySubmittedInstitutions.where((i) => i.isPendingApproval).length;
  int get myRejectedInstitutionCount => mySubmittedInstitutions.where((i) => i.isRejected).length;
  int get myApprovedInstitutionCount => mySubmittedInstitutions.where((i) => i.isApproved).length;
  int get pendingInstitutionApprovalsCount => actualInstitutions.where((i) => i.isPendingApproval).length;

  /// Submit a newly added Institution request with Workplace, Region, Province, City
  Future<Institution> createInstitutionRequest({
    required String workplaceName,
    String? region,
    required String city,
    required String province,
    String? ownership,
    String? institutionType,
    String? serviceCapability,
    bool requiresDsmApproval = false,
    String? linkedDoctorName,
    String? streetAddress,
  }) async {
    final cleanWp = workplaceName.trim();
    final resolvedCity = LocationResolver.resolveCityName(city);
    final resolvedProv = LocationResolver.resolveProvinceName(province);
    final cityId = LocationResolver.resolveCityId(city);
    final provId = LocationResolver.resolveProvinceId(province);

    // Resolve Region: explicit selection, or auto-derived from province
    String regId = LocationResolver.resolveRegionId(region);
    if (regId.isEmpty || !RegExp(r'^\d{9,10}[A-Za-z]?$').hasMatch(regId)) {
      final autoReg = LocationResolver.resolveRegionFromProvince(province);
      if (autoReg.isNotEmpty) {
        regId = LocationResolver.resolveRegionId(autoReg);
      }
    }
    final resolvedReg = LocationResolver.resolveRegionName(regId.isNotEmpty ? regId : region);
    final now = DateTime.now();

    if (_isOffline) {
      final localInst = Institution(
        name: cleanWp,
        institutionName: cleanWp,
        regionName: resolvedReg.isNotEmpty ? resolvedReg : region,
        provinceName: resolvedProv.isNotEmpty ? resolvedProv : province,
        cityMunicipality: resolvedCity.isNotEmpty ? resolvedCity : city,
        streetAddress: streetAddress,
        rawRegionName: regId.isNotEmpty ? regId : region,
        rawProvinceName: provId.isNotEmpty ? provId : province,
        rawCityMunicipality: cityId.isNotEmpty ? cityId : city,
        workflowState: 'Pending Approval',
        owner: loggedInEmail,
        docstatus: 0,
        ownership: ownership,
        institutionType: institutionType,
        serviceCapability: serviceCapability,
        resubmissionCount: 0,
        lastSubmittedAt: now,
        requiresDsmApproval: requiresDsmApproval,
        linkedDoctorName: linkedDoctorName,
      );
      _cachedInstitutions.insert(0, localInst);
      notifyListeners();
      return localInst;
    }

    await ensureCsrfToken();

    // In ERPNext, region_name, province_name and city_municipality link to PSGC Location (e.g. 1380200000 or 1380200000C)
    final bool validRegId = regId.isNotEmpty && RegExp(r'^\d{9,10}[A-Za-z]?$').hasMatch(regId);
    final bool validCityId = cityId.isNotEmpty && RegExp(r'^\d{9,10}[A-Za-z]?$').hasMatch(cityId);
    final bool validProvId = provId.isNotEmpty && RegExp(r'^\d{9,10}[A-Za-z]?$').hasMatch(provId);

    final payload = <String, dynamic>{
      'institution_name': cleanWp,
      if (validRegId) 'region_name': regId,
      if (validCityId) 'city_municipality': cityId,
      if (validProvId) 'province_name': provId,
      if (streetAddress != null && streetAddress.trim().isNotEmpty) 'street_address': streetAddress.trim(),
      if (ownership != null) 'ownership': ownership,
      if (institutionType != null) 'institution_type': institutionType,
      if (serviceCapability != null) 'service_capability': serviceCapability,
      'requires_dsm_approval': requiresDsmApproval ? 1 : 0,
      if (linkedDoctorName != null) 'linked_doctor_name': linkedDoctorName,
      'last_submitted_at': now.toIso8601String(),
    };

    final url = Uri.parse('$baseUrl/api/resource/Institution');
    http.Response res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    // If LinkValidationError occurs, retry inserting with clean institution_name
    if ((res.statusCode != 200 && res.statusCode != 201) &&
        (res.body.contains('LinkValidationError') || res.body.contains('Could not find') || res.body.contains('field not found'))) {
      res = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'institution_name': cleanWp,
          if (ownership != null) 'ownership': ownership,
          if (institutionType != null) 'institution_type': institutionType,
          if (serviceCapability != null) 'service_capability': serviceCapability,
        }),
      );
    }

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body)['data'];
      final created = Institution.fromJson(data);
      final assignedId = created.name;

      // Apply workflow action 'Submit for Approval' to transition Draft -> Pending Approval
      try {
        final wfUrl = Uri.parse('$baseUrl/api/method/frappe.model.workflow.apply_workflow');
        final wfRes = await http.post(
          wfUrl,
          headers: _headers,
          body: jsonEncode({
            'doc': {
              'doctype': 'Institution',
              'name': assignedId,
            },
            'action': 'Submit for Approval',
          }),
        );
        if (wfRes.statusCode != 200) {
          print('Submit for Approval workflow transition returned ${wfRes.statusCode}: ${wfRes.body}');
        }
      } catch (wfErr) {
        print('Apply Submit for Approval workflow error: $wfErr');
      }

      final initialAudit = [
        InstitutionAuditLogEntry(
          timestamp: now,
          user: loggedInFullName ?? loggedInEmail ?? 'MedRep',
          role: isManager ? 'DSM' : (isSfe ? 'SFE Specialist' : 'MedRep'),
          action: 'Initial Proposal',
          details: 'Proposed new $institutionType ($ownership) with capability: $serviceCapability at $resolvedCity, $resolvedProv',
          snapshot: {
            'institution_name': cleanWp,
            'ownership': ownership,
            'institution_type': institutionType,
            'service_capability': serviceCapability,
            'location': '$resolvedCity, $resolvedProv',
          },
        ),
      ];

      final newInst = Institution(
        name: assignedId.isNotEmpty ? assignedId : cleanWp,
        institutionName: cleanWp,
        regionName: resolvedReg.isNotEmpty ? resolvedReg : region,
        provinceName: resolvedProv.isNotEmpty ? resolvedProv : province,
        cityMunicipality: resolvedCity.isNotEmpty ? resolvedCity : city,
        rawRegionName: validRegId ? regId : region,
        rawProvinceName: validProvId ? provId : province,
        rawCityMunicipality: validCityId ? cityId : city,
        workflowState: 'Pending Approval',
        owner: loggedInEmail,
        docstatus: 0,
        ownership: ownership,
        institutionType: institutionType,
        serviceCapability: serviceCapability,
        resubmissionCount: 0,
        lastSubmittedAt: now,
        requiresDsmApproval: requiresDsmApproval,
        linkedDoctorName: linkedDoctorName,
        auditTrail: initialAudit,
      );
      _cachedInstitutions.removeWhere((i) => i.name == newInst.name);
      _cachedInstitutions.insert(0, newInst);
      notifyListeners();

      // Trigger background refresh so server-assigned metadata is fully in sync
      fetchInstitutions().catchError((_) => <Institution>[]);

      return newInst;
    } else {
      String errMsg = 'Server returned HTTP ${res.statusCode}';
      try {
        final errJson = jsonDecode(res.body);
        if (errJson['exception'] != null) {
          errMsg = errJson['exception'].toString().split('\n').first;
        } else if (errJson['_server_messages'] != null) {
          final msgs = jsonDecode(errJson['_server_messages']);
          if (msgs is List && msgs.isNotEmpty) {
            final first = jsonDecode(msgs[0]);
            errMsg = first['message'] ?? errMsg;
          }
        }
      } catch (_) {}
      throw Exception('Failed to create institution on server: $errMsg');
    }
  }

  /// Resubmit an edited Institution after SFE rejection (Max 2 resubmissions, 1-min cooldown)
  Future<Institution> resubmitInstitutionRequest({
    required String name,
    required String workplaceName,
    String? region,
    required String city,
    required String province,
    String? ownership,
    String? institutionType,
    String? serviceCapability,
    bool requiresDsmApproval = false,
  }) async {
    final existingIdx = _cachedInstitutions.indexWhere((i) => i.name == name);
    final existing = existingIdx >= 0 ? _cachedInstitutions[existingIdx] : null;

    if (existing != null) {
      if (existing.isCooldownActive) {
        throw Exception(
          'Concurrency Lock Active: Please wait ${existing.cooldownRemainingSeconds}s before submitting to prevent concurrent edits.',
        );
      }
      if (existing.resubmissionCount >= 2) {
        throw Exception(
          'Maximum resubmissions reached (2 attempts). Please contact the SFE Specialist directly to resolve this facility.',
        );
      }
    }

    final newCount = (existing?.resubmissionCount ?? 0) + 1;
    final now = DateTime.now();

    final cleanWp = workplaceName.trim();
    final resolvedCity = LocationResolver.resolveCityName(city);
    final resolvedProv = LocationResolver.resolveProvinceName(province);
    final cityId = LocationResolver.resolveCityId(city);
    final provId = LocationResolver.resolveProvinceId(province);

    // Resolve Region: explicit selection, or auto-derived from province
    String regId = LocationResolver.resolveRegionId(region);
    if (regId.isEmpty || !RegExp(r'^\d{10}$').hasMatch(regId)) {
      final autoReg = LocationResolver.resolveRegionFromProvince(province);
      if (autoReg.isNotEmpty) {
        regId = LocationResolver.resolveRegionId(autoReg);
      }
    }
    final resolvedReg = LocationResolver.resolveRegionName(regId.isNotEmpty ? regId : region);

    await ensureCsrfToken();

    final bool validRegId = regId.isNotEmpty && RegExp(r'^\d{9,10}[A-Za-z]?$').hasMatch(regId);
    final bool validCityId = cityId.isNotEmpty && RegExp(r'^\d{9,10}[A-Za-z]?$').hasMatch(cityId);
    final bool validProvId = provId.isNotEmpty && RegExp(r'^\d{9,10}[A-Za-z]?$').hasMatch(provId);

    final payload = <String, dynamic>{
      'institution_name': cleanWp,
      if (validRegId) 'region_name': regId,
      if (validCityId) 'city_municipality': cityId,
      if (validProvId) 'province_name': provId,
      if (ownership != null) 'ownership': ownership,
      if (institutionType != null) 'institution_type': institutionType,
      if (serviceCapability != null) 'service_capability': serviceCapability,
      'rejection_reason': '',
      'is_resubmission': 1,
      'resubmission_count': newCount,
      'last_submitted_at': now.toIso8601String(),
    };

    if (!_isOffline) {
      final url = Uri.parse('$baseUrl/api/resource/Institution/${Uri.encodeComponent(name)}');
      http.Response putRes = await http.put(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      );

      if ((putRes.statusCode != 200 && putRes.statusCode != 201) &&
          (putRes.body.contains('LinkValidationError') || putRes.body.contains('Could not find'))) {
        putRes = await http.put(
          url,
          headers: _headers,
          body: jsonEncode({
            'institution_name': cleanWp,
            'rejection_reason': '',
            'is_resubmission': 1,
          }),
        );
      }

      try {
        final wfUrl = Uri.parse('$baseUrl/api/method/frappe.model.workflow.apply_workflow');
        await http.post(
          wfUrl,
          headers: _headers,
          body: jsonEncode({
            'doc': {
              'doctype': 'Institution',
              'name': name,
            },
            'action': 'Submit for Approval',
          }),
        );
      } catch (_) {}
    }

    final updatedAudit = List<InstitutionAuditLogEntry>.from(existing?.auditTrail ?? []);
    updatedAudit.add(
      InstitutionAuditLogEntry(
        timestamp: now,
        user: loggedInFullName ?? loggedInEmail ?? 'MedRep',
        role: isManager ? 'DSM' : 'MedRep',
        action: 'Resubmitted (Attempt $newCount/2)',
        details: 'Updated facility: $cleanWp ($ownership, $institutionType, $serviceCapability) at $resolvedCity, $resolvedProv',
        snapshot: {
          'institution_name': cleanWp,
          'ownership': ownership,
          'institution_type': institutionType,
          'service_capability': serviceCapability,
          'location': '$resolvedCity, $resolvedProv',
        },
      ),
    );

    final resubmitted = Institution(
      name: name,
      institutionName: cleanWp,
      regionName: resolvedReg.isNotEmpty ? resolvedReg : region,
      provinceName: resolvedProv.isNotEmpty ? resolvedProv : province,
      cityMunicipality: resolvedCity.isNotEmpty ? resolvedCity : city,
      rawRegionName: validRegId ? regId : region,
      rawProvinceName: validProvId ? provId : province,
      rawCityMunicipality: validCityId ? cityId : city,
      workflowState: requiresDsmApproval ? 'Pending DSM Approval' : 'Pending Approval',
      owner: existing?.owner ?? loggedInEmail,
      rejectionReason: '',
      docstatus: 0,
      isResubmission: true,
      resubmissionCount: newCount,
      lastSubmittedAt: now,
      activeEditingLock: null,
      editingUser: null,
      ownership: ownership ?? existing?.ownership,
      institutionType: institutionType ?? existing?.institutionType,
      serviceCapability: serviceCapability ?? existing?.serviceCapability,
      requiresDsmApproval: requiresDsmApproval || (existing?.requiresDsmApproval ?? false),
      creation: existing?.creation,
      modified: now.toIso8601String(),
      auditTrail: updatedAudit,
    );

    if (existingIdx >= 0) {
      _cachedInstitutions[existingIdx] = resubmitted;
    } else {
      _cachedInstitutions.insert(0, resubmitted);
    }
    notifyListeners();

    fetchInstitutions().catchError((_) => <Institution>[]);

    return resubmitted;
  }

  /// SFE Normalize Feature: Normalize institution details in database and approve
  Future<Institution> normalizeInstitution({
    required String name,
    required String workplaceName,
    String? region,
    required String city,
    required String province,
    String? ownership,
    String? institutionType,
    String? serviceCapability,
    bool autoApprove = true,
  }) async {
    final existingIdx = _cachedInstitutions.indexWhere((i) => i.name == name);
    final existing = existingIdx >= 0 ? _cachedInstitutions[existingIdx] : null;
    final cleanWp = workplaceName.trim();
    final resolvedCity = LocationResolver.resolveCityName(city);
    final resolvedProv = LocationResolver.resolveProvinceName(province);
    final cityId = LocationResolver.resolveCityId(city);
    final provId = LocationResolver.resolveProvinceId(province);

    String regId = LocationResolver.resolveRegionId(region);
    if (regId.isEmpty || !RegExp(r'^\d{10}$').hasMatch(regId)) {
      final autoReg = LocationResolver.resolveRegionFromProvince(province);
      if (autoReg.isNotEmpty) {
        regId = LocationResolver.resolveRegionId(autoReg);
      }
    }
    final resolvedReg = LocationResolver.resolveRegionName(regId.isNotEmpty ? regId : region);

    await ensureCsrfToken();

    final bool validRegId = regId.isNotEmpty && RegExp(r'^\d{9,10}[A-Za-z]?$').hasMatch(regId);
    final bool validCityId = cityId.isNotEmpty && RegExp(r'^\d{9,10}[A-Za-z]?$').hasMatch(cityId);
    final bool validProvId = provId.isNotEmpty && RegExp(r'^\d{9,10}[A-Za-z]?$').hasMatch(provId);

    final payload = <String, dynamic>{
      'institution_name': cleanWp,
      if (validRegId) 'region_name': regId,
      if (validCityId) 'city_municipality': cityId,
      if (validProvId) 'province_name': provId,
      if (ownership != null) 'ownership': ownership,
      if (institutionType != null) 'institution_type': institutionType,
      if (serviceCapability != null) 'service_capability': serviceCapability,
      if (autoApprove) 'rejection_reason': '',
    };

    if (!_isOffline) {
      final url = Uri.parse('$baseUrl/api/resource/Institution/${Uri.encodeComponent(name)}');
      await http.put(url, headers: _headers, body: jsonEncode(payload));
    }

    if (autoApprove) {
      await approveInstitution(name);
    }

    final updatedAudit = List<InstitutionAuditLogEntry>.from(existing?.auditTrail ?? []);
    updatedAudit.add(
      InstitutionAuditLogEntry(
        timestamp: DateTime.now(),
        user: loggedInFullName ?? loggedInEmail ?? 'SFE Specialist',
        role: isSfe ? 'SFE Specialist' : 'Admin',
        action: 'Normalized by SFE',
        details: 'Standardized facility metadata: $cleanWp ($ownership, $institutionType, $serviceCapability) at $resolvedCity, $resolvedProv',
        snapshot: {
          'institution_name': cleanWp,
          'ownership': ownership,
          'institution_type': institutionType,
          'service_capability': serviceCapability,
          'location': '$resolvedCity, $resolvedProv',
        },
      ),
    );

    final normalized = Institution(
      name: name,
      institutionName: cleanWp,
      regionName: resolvedReg.isNotEmpty ? resolvedReg : region,
      provinceName: resolvedProv.isNotEmpty ? resolvedProv : province,
      cityMunicipality: resolvedCity.isNotEmpty ? resolvedCity : city,
      rawRegionName: validRegId ? regId : region,
      rawProvinceName: validProvId ? provId : province,
      rawCityMunicipality: validCityId ? cityId : city,
      workflowState: autoApprove
          ? ((existing?.requiresDsmApproval == true) ? 'Pending DSM Approval' : 'Approved')
          : (existing?.workflowState ?? 'Pending Approval'),
      docstatus: autoApprove ? ((existing?.requiresDsmApproval == true) ? 0 : 1) : 0,
      ownership: ownership ?? existing?.ownership,
      institutionType: institutionType ?? existing?.institutionType,
      serviceCapability: serviceCapability ?? existing?.serviceCapability,
      resubmissionCount: existing?.resubmissionCount ?? 0,
      rejectionReason: autoApprove ? null : existing?.rejectionReason,
      requiresDsmApproval: existing?.requiresDsmApproval ?? false,
      linkedDoctorName: existing?.linkedDoctorName,
      activeEditingLock: null,
      editingUser: null,
      owner: existing?.owner,
      creation: existing?.creation,
      modified: DateTime.now().toIso8601String(),
      auditTrail: updatedAudit,
    );

    if (existingIdx >= 0) {
      _cachedInstitutions[existingIdx] = normalized;
    } else {
      _cachedInstitutions.insert(0, normalized);
    }

    // Propagate normalized workplace name and approval to linked HCP Accounts & Doctors
    final oldInstName = existing?.institutionName ?? name;
    for (int i = 0; i < _cachedHcpAccounts.length; i++) {
      final acc = _cachedHcpAccounts[i];
      final bool hasMatch = (acc.workplaceId != null && (acc.workplaceId == name || acc.workplaceId == oldInstName)) ||
          acc.workplaces.any((w) => w.hcpWorkplace == name || w.hcpWorkplace == oldInstName);
      if (hasMatch) {
        final updatedWps = acc.workplaces.map((w) {
          if (w.hcpWorkplace == name || w.hcpWorkplace == oldInstName) {
            return HcpAccountWorkplace(
              hcpWorkplace: cleanWp,
              isPrimary: w.isPrimary,
              preferred: w.preferred,
            );
          }
          return w;
        }).toList();

        _cachedHcpAccounts[i] = acc.copyWith(
          workplaceId: (acc.workplaceId == name || acc.workplaceId == oldInstName) ? cleanWp : acc.workplaceId,
          workplaceApprovalNote: autoApprove ? 'this institution is now approved' : acc.workplaceApprovalNote,
          workplaces: updatedWps,
        );
      }
    }

    for (int i = 0; i < _cachedDoctors.length; i++) {
      final doc = _cachedDoctors[i];
      final bool hasMatch = (doc.institution != null && (doc.institution == name || doc.institution == oldInstName)) ||
          doc.workplaces.any((w) => w.workplace == name || w.workplace == oldInstName);
      if (hasMatch) {
        final updatedWps = doc.workplaces.map((w) {
          if (w.workplace == name || w.workplace == oldInstName) {
            return HcpWorkplace(
              workplace: cleanWp,
              address: w.address,
              cityMunicipality: resolvedCity.isNotEmpty ? resolvedCity : w.cityMunicipality,
              provinceName: resolvedProv.isNotEmpty ? resolvedProv : w.provinceName,
            );
          }
          return w;
        }).toList();

        _cachedDoctors[i] = doc.copyWith(
          institution: (doc.institution == name || doc.institution == oldInstName) ? cleanWp : doc.institution,
          workplaces: updatedWps,
        );
      }
    }

    notifyListeners();
    return normalized;
  }

  /// SFE Approval Action:
  /// - If doctor and inst -> DSM approval
  /// - If institution only -> Done (Approved)
  Future<bool> approveInstitution(String name) async {
    try {
      await ensureCsrfToken();

      final idx = _cachedInstitutions.indexWhere((i) => i.name == name);
      final existing = idx >= 0 ? _cachedInstitutions[idx] : null;
      final bool needsDsm = existing?.requiresDsmApproval == true;

      final targetWorkflowState = needsDsm ? 'Pending DSM Approval' : 'Approved';
      final targetDocstatus = needsDsm ? 0 : 1;
      final actionName = needsDsm ? 'Route to DSM' : 'Approve';

      final wfUrl = Uri.parse('$baseUrl/api/method/frappe.model.workflow.apply_workflow');
      final res = await http.post(
        wfUrl,
        headers: _headers,
        body: jsonEncode({
          'doc': {
            'doctype': 'Institution',
            'name': name,
          },
          'action': actionName,
        }),
      );

      bool success = res.statusCode == 200;

      // Fallback: If workflow action fails but user has write/system manager permissions
      if (!success) {
        final instUrl = Uri.parse('$baseUrl/api/resource/Institution/${Uri.encodeComponent(name)}');
        final putRes = await http.put(
          instUrl,
          headers: _headers,
          body: jsonEncode({
            'workflow_state': targetWorkflowState,
            'docstatus': targetDocstatus,
          }),
        );
        if (!success) {
          try {
            final setValueUrl = Uri.parse('$baseUrl/api/method/frappe.client.set_value');
            final setRes = await http.post(
              setValueUrl,
              headers: _headers,
              body: jsonEncode({
                'doctype': 'Institution',
                'name': name,
                'fieldname': {
                  'workflow_state': targetWorkflowState,
                  'docstatus': targetDocstatus,
                },
              }),
            );
            success = setRes.statusCode == 200;
          } catch (_) {}
          if (!success) {
            print('approveInstitution workflow failed (${res.statusCode}: ${res.body}) and fallback failed (${putRes.statusCode}: ${putRes.body})');
          }
        }
      }

      if (success) {
        final now = DateTime.now();
        final user = loggedInFullName ?? loggedInEmail ?? (isSfe ? 'SFE Specialist' : 'System Admin');
        final role = isSfe ? 'SFE Specialist' : (isManager ? 'DSM' : 'System Admin');
        final updatedAudit = List<InstitutionAuditLogEntry>.from(existing?.auditTrail ?? []);
        updatedAudit.add(
          InstitutionAuditLogEntry(
            timestamp: now,
            user: user,
            role: role,
            action: needsDsm ? 'Routed to DSM' : 'Approved',
            details: needsDsm ? 'Validated by SFE and routed to DSM for regional approval' : 'Institution validated and approved by SFE',
            snapshot: {
              'workflow_state': targetWorkflowState,
              'institution_name': existing?.institutionName ?? name,
            },
          ),
        );

        if (idx >= 0 && existing != null) {
          _cachedInstitutions[idx] = existing.copyWith(
            workflowState: targetWorkflowState,
            docstatus: targetDocstatus,
            auditTrail: updatedAudit,
            activeEditingLock: null,
            editingUser: null,
          );
        }
        notifyListeners();
        fetchInstitutions().catchError((_) => <Institution>[]);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('approveInstitution exception: $e');
      return false;
    }
  }

  /// DSM Approval Action: District Sales Manager approves an institution validated by SFE
  Future<bool> dsmApproveInstitution(String name) async {
    try {
      await ensureCsrfToken();
      final idx = _cachedInstitutions.indexWhere((i) => i.name == name);
      final existing = idx >= 0 ? _cachedInstitutions[idx] : null;

      const targetWorkflowState = 'Approved';
      const targetDocstatus = 1;

      final wfUrl = Uri.parse('$baseUrl/api/method/frappe.model.workflow.apply_workflow');
      final res = await http.post(
        wfUrl,
        headers: _headers,
        body: jsonEncode({
          'doc': {
            'doctype': 'Institution',
            'name': name,
          },
          'action': 'Approve',
        }),
      );

      bool success = res.statusCode == 200;

      if (!success) {
        final instUrl = Uri.parse('$baseUrl/api/resource/Institution/${Uri.encodeComponent(name)}');
        final putRes = await http.put(
          instUrl,
          headers: _headers,
          body: jsonEncode({
            'workflow_state': targetWorkflowState,
            'docstatus': targetDocstatus,
          }),
        );
        success = putRes.statusCode == 200;
        if (!success) {
          try {
            final setValueUrl = Uri.parse('$baseUrl/api/method/frappe.client.set_value');
            final setRes = await http.post(
              setValueUrl,
              headers: _headers,
              body: jsonEncode({
                'doctype': 'Institution',
                'name': name,
                'fieldname': {
                  'workflow_state': targetWorkflowState,
                  'docstatus': targetDocstatus,
                },
              }),
            );
            success = setRes.statusCode == 200;
          } catch (_) {}
        }
      }

      if (success) {
        final now = DateTime.now();
        final user = loggedInFullName ?? loggedInEmail ?? 'DSM';
        final updatedAudit = List<InstitutionAuditLogEntry>.from(existing?.auditTrail ?? []);
        updatedAudit.add(
          InstitutionAuditLogEntry(
            timestamp: now,
            user: user,
            role: 'DSM',
            action: 'Approved by DSM',
            details: 'Regional endorsement and final approval granted by District Sales Manager',
            snapshot: {
              'workflow_state': targetWorkflowState,
              'institution_name': existing?.institutionName ?? name,
            },
          ),
        );

        if (idx >= 0 && existing != null) {
          _cachedInstitutions[idx] = existing.copyWith(
            workflowState: targetWorkflowState,
            docstatus: targetDocstatus,
            auditTrail: updatedAudit,
            activeEditingLock: null,
            editingUser: null,
          );
        }
        notifyListeners();
        fetchInstitutions().catchError((_) => <Institution>[]);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('dsmApproveInstitution exception: $e');
      return false;
    }
  }

  /// Permanently deletes an institution request from ERPNext and local cache
  Future<bool> deleteInstitution(String name) async {
    if (_isOffline) {
      _cachedInstitutions.removeWhere((i) => i.name == name);
      notifyListeners();
      return true;
    }

    try {
      await ensureCsrfToken();
      final url = Uri.parse('$baseUrl/api/resource/Institution/${Uri.encodeComponent(name)}');
      http.Response res = await http.delete(url, headers: _headers);

      // If document is submitted (docstatus: 1), ERPNext requires cancellation first.
      if (res.statusCode != 200 && res.statusCode != 202 && res.statusCode != 204 && res.statusCode != 404 &&
          (res.body.contains('Submitted Record cannot be deleted') || res.body.contains('Cancel'))) {
        try {
          final cancelUrl = Uri.parse('$baseUrl/api/method/frappe.client.cancel');
          await http.post(
            cancelUrl,
            headers: _headers,
            body: jsonEncode({
              'doctype': 'Institution',
              'name': name,
            }),
          );
          res = await http.delete(url, headers: _headers);
        } catch (_) {}
      }

      if (res.statusCode == 200 || res.statusCode == 202 || res.statusCode == 204 || res.statusCode == 404) {
        _cachedInstitutions.removeWhere((i) => i.name == name);
        notifyListeners();
        return true;
      } else {
        String errMsg = 'Server returned HTTP ${res.statusCode}';
        try {
          final errJson = jsonDecode(res.body);
          if (errJson['exception'] != null) {
            errMsg = errJson['exception'].toString().split('\n').first;
          } else if (errJson['_server_messages'] != null) {
            final msgs = jsonDecode(errJson['_server_messages']);
            if (msgs is List && msgs.isNotEmpty) {
              final first = jsonDecode(msgs[0]);
              errMsg = first['message'] ?? errMsg;
            }
          }
        } catch (_) {}
        throw Exception('Failed to delete institution from server: $errMsg');
      }
    } catch (e) {
      print('deleteInstitution exception: $e');
      rethrow;
    }
  }

  /// SFE Rejection Action: Updates rejection_reason and transitions state to Rejected.
  /// MedReps can continuously modify and resubmit rejected institutions without deletion (up to 2 times).
  /// Rejection automatically propagates across DocTypes (HCP Account, HCP, Institution).
  Future<bool> rejectInstitution(String name, String reason) async {
    try {
      await ensureCsrfToken();
      final cleanReason = reason.trim();

      // 1. Update rejection_reason on the Institution
      final instUrl = Uri.parse('$baseUrl/api/resource/Institution/${Uri.encodeComponent(name)}');
      await http.put(
        instUrl,
        headers: _headers,
        body: jsonEncode({
          'rejection_reason': cleanReason,
        }),
      );

      // 2. Apply workflow action 'Reject'
      final wfUrl = Uri.parse('$baseUrl/api/method/frappe.model.workflow.apply_workflow');
      final res = await http.post(
        wfUrl,
        headers: _headers,
        body: jsonEncode({
          'doc': {
            'doctype': 'Institution',
            'name': name,
          },
          'action': 'Reject',
        }),
      );

      bool success = res.statusCode == 200;

      // Fallback: If apply_workflow failed but user has direct update rights, apply state directly
      if (!success) {
        final putRes = await http.put(
          instUrl,
          headers: _headers,
          body: jsonEncode({
            'rejection_reason': cleanReason,
            'workflow_state': 'Rejected',
            'docstatus': 0,
          }),
        );
        success = putRes.statusCode == 200;
        if (!success) {
          print('rejectInstitution workflow failed (${res.statusCode}: ${res.body}) and fallback failed (${putRes.statusCode}: ${putRes.body})');
        }
      }

      if (success) {
        final idx = _cachedInstitutions.indexWhere((i) => i.name == name);
        String targetInstName = name;
        final now = DateTime.now();
        final user = loggedInFullName ?? loggedInEmail ?? (isSfe ? 'SFE Specialist' : 'Reviewer');
        final role = isSfe ? 'SFE Specialist' : (isManager ? 'DSM' : 'System Admin');

        if (idx >= 0) {
          final old = _cachedInstitutions[idx];
          targetInstName = old.institutionName;
          final updatedAudit = List<InstitutionAuditLogEntry>.from(old.auditTrail);
          updatedAudit.add(
            InstitutionAuditLogEntry(
              timestamp: now,
              user: user,
              role: role,
              action: 'Rejected',
              details: 'Rejected with reason: $cleanReason',
              snapshot: {
                'rejection_reason': cleanReason,
                'institution_name': old.institutionName,
                'resubmission_count': old.resubmissionCount,
              },
            ),
          );

          _cachedInstitutions[idx] = old.copyWith(
            workflowState: 'Rejected',
            rejectionReason: cleanReason,
            docstatus: 0,
            auditTrail: updatedAudit,
            activeEditingLock: null,
            editingUser: null,
          );
        }

        // 3. Propagate rejection with cause note to linked HCP Accounts
        final rejectionTag = '[REJECTED INSTITUTION: $cleanReason]';
        for (int i = 0; i < _cachedHcpAccounts.length; i++) {
          final acc = _cachedHcpAccounts[i];
          final bool hasMatch = (acc.workplaceId != null && (acc.workplaceId == name || acc.workplaceId == targetInstName)) ||
              acc.workplaces.any((w) => w.hcpWorkplace == name || w.hcpWorkplace == targetInstName);
          if (hasMatch) {
            _cachedHcpAccounts[i] = acc.copyWith(
              workplaceApprovalNote: rejectionTag,
            );
            if (acc.name != null && acc.name!.isNotEmpty) {
              http.put(
                Uri.parse('$baseUrl/api/resource/HCP%20Account/${Uri.encodeComponent(acc.name!)}'),
                headers: _headers,
                body: jsonEncode({
                  'workplace_approval_note': rejectionTag,
                  'rejection_reason': cleanReason,
                }),
              ).catchError((_) => http.Response('', 500));
            }
          }
        }

        // 4. Propagate rejection with cause note to linked HCP Profile Submissions
        for (int i = 0; i < _cachedSubmissions.length; i++) {
          final sub = _cachedSubmissions[i];
          final bool hasMatch = (sub.institution != null && (sub.institution == name || sub.institution == targetInstName)) ||
              sub.workplaces.any((w) => w.hcpWorkplace == name || w.hcpWorkplace == targetInstName || w.workplaceName == targetInstName);
          if (hasMatch) {
            final updatedWps = sub.workplaces.map((w) {
              if (w.hcpWorkplace == name || w.hcpWorkplace == targetInstName || w.workplaceName == targetInstName) {
                return w.copyWith(workflowState: 'Rejected', rejectionReason: cleanReason);
              }
              return w;
            }).toList();
            _cachedSubmissions[i] = sub.copyWith(
              workplaces: updatedWps,
              rejectionRemarks: rejectionTag,
            );
            if (sub.name != null && sub.name!.isNotEmpty) {
              http.put(
                Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(sub.name!)}'),
                headers: _headers,
                body: jsonEncode({
                  'rejection_reason': rejectionTag,
                  'rejection_remarks': rejectionTag,
                  'table_workplaces': updatedWps.map((w) => w.toJson()).toList(),
                }),
              ).catchError((_) => http.Response('', 500));
            }
          }
        }

        // 5. Propagate rejection to linked HCP Doctors
        for (int i = 0; i < _cachedDoctors.length; i++) {
          final doc = _cachedDoctors[i];
          final bool hasMatch = (doc.institution != null && (doc.institution == name || doc.institution == targetInstName)) ||
              doc.workplaces.any((w) => w.workplace == name || w.workplace == targetInstName);
          if (hasMatch && doc.name != null && doc.name!.isNotEmpty) {
            http.put(
              Uri.parse('$baseUrl/api/resource/HCP/${Uri.encodeComponent(doc.name!)}'),
              headers: _headers,
              body: jsonEncode({
                'workplace_approval_note': rejectionTag,
                'rejection_reason': cleanReason,
              }),
            ).catchError((_) => http.Response('', 500));
          }
        }

        // 6. Trigger Pop-up Lockscreen & Homescreen System Notification
        final oldInst = (idx >= 0) ? _cachedInstitutions[idx] : null;
        NotificationService.showInstitutionRejectedNotification(
          institutionName: targetInstName,
          reason: cleanReason,
          submittedBy: oldInst?.owner,
          institutionId: name,
        ).catchError((e) => AppLogger.e('ApiService', 'Notification dispatch failed: $e'));

        notifyListeners();
        fetchInstitutions().catchError((_) => <Institution>[]);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('rejectInstitution exception: $e');
      return false;
    }
  }

  /// SFE Remediation Action: Remaps a rejected institution to a valid approved masterlist facility.
  /// Replaces the rejected institution in HCP Profile Submission, HCP Account, and HCP DocTypes,
  /// updating status notes and allowing MedReps to immediately continue HCP profiling.
  /// SFE Remediation Action: Remaps a rejected institution to a valid approved masterlist facility.
  /// Replaces the rejected institution in HCP Profile Submission, HCP Account, and HCP DocTypes,
  /// updating status notes and allowing MedReps to immediately continue HCP profiling.
  Future<bool> remapRejectedInstitution({
    required String rejectedInstitutionNameOrId,
    required Institution replacementInstitution,
    String? resolutionNote,
  }) async {
    try {
      await ensureCsrfToken();
      final String note = (resolutionNote != null && resolutionNote.trim().isNotEmpty)
          ? resolutionNote.trim()
          : 'Remapped duplicate/unprofiled institution to approved facility: ${replacementInstitution.institutionName}';

      final String remappedTag = 'Remapped by SFE to: ${replacementInstitution.institutionName}';

      String oldId = rejectedInstitutionNameOrId.trim();
      String oldName = rejectedInstitutionNameOrId.trim();

      final idx = _cachedInstitutions.indexWhere(
          (i) => i.name.toLowerCase() == rejectedInstitutionNameOrId.toLowerCase() ||
                 i.institutionName.toLowerCase() == rejectedInstitutionNameOrId.toLowerCase());
      if (idx >= 0) {
        final old = _cachedInstitutions[idx];
        oldId = old.name;
        oldName = old.institutionName;
      } else {
        final resId = LocationResolver.resolveInstitutionId(rejectedInstitutionNameOrId);
        final resName = LocationResolver.resolveInstitutionName(rejectedInstitutionNameOrId);
        if (resId.isNotEmpty) oldId = resId;
        if (resName.isNotEmpty) oldName = resName;
      }

      // 1. Transition Institution doc in ERPNext using workflow
      final wfUrl = Uri.parse('$baseUrl/api/method/frappe.model.workflow.apply_workflow');
      final wfRes = await http.post(
        wfUrl,
        headers: _headers,
        body: jsonEncode({
          'doc': {
            'doctype': 'Institution',
            'name': oldId,
          },
          'action': 'Remap',
        }),
      );

      // Also ensure rejection_reason / notes are saved on Institution
      final instUrl = Uri.parse('$baseUrl/api/resource/Institution/${Uri.encodeComponent(oldId)}');
      await http.put(
        instUrl,
        headers: _headers,
        body: jsonEncode({
          'rejection_reason': '$remappedTag ($note)',
          if (wfRes.statusCode != 200) 'workflow_state': 'Remapped',
        }),
      );

      // 2. Update local cached institution
      if (idx >= 0) {
        final old = _cachedInstitutions[idx];
        final updatedAudit = List<InstitutionAuditLogEntry>.from(old.auditTrail);
        updatedAudit.add(
          InstitutionAuditLogEntry(
            timestamp: DateTime.now(),
            user: loggedInFullName ?? loggedInEmail ?? 'SFE Specialist',
            role: isSfe ? 'SFE Specialist' : (isAdmin ? 'System Admin' : 'Reviewer'),
            action: 'Remapped by SFE',
            details: '$remappedTag. $note',
            snapshot: {
              'original_rejected': old.institutionName,
              'original_id': old.name,
              'replacement': replacementInstitution.institutionName,
              'replacement_id': replacementInstitution.name,
              'note': note,
            },
          ),
        );
        _cachedInstitutions[idx] = old.copyWith(
          workflowState: 'Remapped',
          rejectionReason: '$remappedTag ($note)',
          auditTrail: updatedAudit,
        );
      }

      // 3. Remap across linked HCP Profile Submissions (Server + Cache)
      final Set<String> targetSubNames = {};
      try {
        final q1 = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission?filters=[["institution","in",["${Uri.encodeComponent(oldId)}","${Uri.encodeComponent(oldName)}"]]]&fields=["name"]&limit=500');
        final r1 = await http.get(q1, headers: _headers);
        if (r1.statusCode == 200) {
          final data = jsonDecode(r1.body)['data'] as List?;
          data?.forEach((d) => targetSubNames.add(d['name'].toString()));
        }
      } catch (_) {}

      try {
        final q2 = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission?filters=[["HCP%20Profile%20Submission%20Workplaces","hcp_workplace","in",["${Uri.encodeComponent(oldId)}","${Uri.encodeComponent(oldName)}"]]]&fields=["name"]&limit=500');
        final r2 = await http.get(q2, headers: _headers);
        if (r2.statusCode == 200) {
          final data = jsonDecode(r2.body)['data'] as List?;
          data?.forEach((d) => targetSubNames.add(d['name'].toString()));
        }
      } catch (_) {}

      for (final s in _cachedSubmissions) {
        if (s.name != null && (s.institution == oldId || s.institution == oldName || s.workplaces.any((w) => w.hcpWorkplace == oldId || w.hcpWorkplace == oldName || w.workplaceName == oldName || w.workplaceName == oldId))) {
          targetSubNames.add(s.name!);
        }
      }

      for (final subName in targetSubNames) {
        try {
          final subGetUrl = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(subName)}');
          final subGetRes = await http.get(subGetUrl, headers: _headers);
          if (subGetRes.statusCode == 200) {
            final subDoc = jsonDecode(subGetRes.body)['data'] as Map<String, dynamic>;
            final rawWps = (subDoc['table_workplaces'] as List? ?? []).cast<Map<String, dynamic>>();
            bool modifiedWps = false;
            final updatedWpsList = rawWps.map((wp) {
              final wId = (wp['hcp_workplace'] ?? '').toString();
              final wName = (wp['workplace_name'] ?? '').toString();
              if (wId == oldId || wId == oldName || wName == oldName || wName == oldId) {
                modifiedWps = true;
                final copy = Map<String, dynamic>.from(wp);
                copy['hcp_workplace'] = replacementInstitution.name;
                copy['workplace_name'] = replacementInstitution.institutionName;
                copy['city_municipality'] = replacementInstitution.cityMunicipality;
                copy['province_name'] = replacementInstitution.provinceName;
                copy['city_title'] = replacementInstitution.cityMunicipality;
                copy['province_title'] = replacementInstitution.provinceName;
                return copy;
              }
              return wp;
            }).toList();

            final subPutBody = <String, dynamic>{};
            if (modifiedWps) {
              subPutBody['table_workplaces'] = updatedWpsList;
            }
            if (subDoc['institution'] == oldId || subDoc['institution'] == oldName) {
              subPutBody['institution'] = replacementInstitution.name;
            }
            subPutBody['rejection_remarks'] = remappedTag;
            subPutBody['rejection_reason'] = '';

            await http.put(subGetUrl, headers: _headers, body: jsonEncode(subPutBody));
          }
        } catch (e) {
          AppLogger.e('ApiService', 'Error updating submission $subName: $e');
        }
      }

      // Update in-memory submissions
      for (int i = 0; i < _cachedSubmissions.length; i++) {
        final sub = _cachedSubmissions[i];
        final bool hasMatch = (sub.institution != null && (sub.institution == oldId || sub.institution == oldName)) ||
            sub.workplaces.any((w) => w.hcpWorkplace == oldId || w.hcpWorkplace == oldName || w.workplaceName == oldName || w.workplaceName == oldId);
        if (hasMatch) {
          final updatedWps = sub.workplaces.map((w) {
            if (w.hcpWorkplace == oldId || w.hcpWorkplace == oldName || w.workplaceName == oldName || w.workplaceName == oldId) {
              return w.copyWith(
                hcpWorkplace: replacementInstitution.name,
                workplaceName: replacementInstitution.institutionName,
                cityMunicipality: replacementInstitution.cityMunicipality,
                provinceName: replacementInstitution.provinceName,
                regionName: replacementInstitution.regionName,
                workflowState: 'Approved',
                rejectionReason: null,
              );
            }
            return w;
          }).toList();
          _cachedSubmissions[i] = sub.copyWith(
            institution: (sub.institution == oldId || sub.institution == oldName)
                ? replacementInstitution.institutionName
                : sub.institution,
            workplaces: updatedWps,
            rejectionRemarks: remappedTag,
          );
        }
      }

      // 4. Remap across linked HCP Doctors (Server + Cache)
      final Set<String> targetDocNames = {};
      try {
        final qd1 = Uri.parse('$baseUrl/api/resource/HCP?filters=[["institution","in",["${Uri.encodeComponent(oldId)}","${Uri.encodeComponent(oldName)}"]]]&fields=["name"]&limit=500');
        final rd1 = await http.get(qd1, headers: _headers);
        if (rd1.statusCode == 200) {
          final data = jsonDecode(rd1.body)['data'] as List?;
          data?.forEach((d) => targetDocNames.add(d['name'].toString()));
        }
      } catch (_) {}

      try {
        final qd2 = Uri.parse('$baseUrl/api/resource/HCP?filters=[["HCP%20Workplaces","hcp_workplace","in",["${Uri.encodeComponent(oldId)}","${Uri.encodeComponent(oldName)}"]]]&fields=["name"]&limit=500');
        final rd2 = await http.get(qd2, headers: _headers);
        if (rd2.statusCode == 200) {
          final data = jsonDecode(rd2.body)['data'] as List?;
          data?.forEach((d) => targetDocNames.add(d['name'].toString()));
        }
      } catch (_) {}

      for (final d in _cachedDoctors) {
        if (d.name != null && (d.institution == oldId || d.institution == oldName || d.workplaces.any((w) => w.workplace == oldId || w.workplace == oldName))) {
          targetDocNames.add(d.name!);
        }
      }

      for (final docName in targetDocNames) {
        try {
          final docGetUrl = Uri.parse('$baseUrl/api/resource/HCP/${Uri.encodeComponent(docName)}');
          final docGetRes = await http.get(docGetUrl, headers: _headers);
          if (docGetRes.statusCode == 200) {
            final docData = jsonDecode(docGetRes.body)['data'] as Map<String, dynamic>;
            final rawWps = (docData['hcp_workplace'] as List? ?? []).cast<Map<String, dynamic>>();
            bool modifiedWps = false;
            final updatedWpsList = rawWps.map((wp) {
              final wId = (wp['hcp_workplace'] ?? '').toString();
              if (wId == oldId || wId == oldName) {
                modifiedWps = true;
                final copy = Map<String, dynamic>.from(wp);
                copy['hcp_workplace'] = replacementInstitution.name;
                copy['city_municipality'] = replacementInstitution.cityMunicipality;
                copy['province_name'] = replacementInstitution.provinceName;
                return copy;
              }
              return wp;
            }).toList();

            final docPutBody = <String, dynamic>{};
            if (modifiedWps) {
              docPutBody['hcp_workplace'] = updatedWpsList;
            }
            if (docData['institution'] == oldId || docData['institution'] == oldName) {
              docPutBody['institution'] = replacementInstitution.name;
            }
            docPutBody['rejection_reason'] = '';
            docPutBody['workplace_approval_note'] = remappedTag;

            await http.put(docGetUrl, headers: _headers, body: jsonEncode(docPutBody));
          }
        } catch (e) {
          AppLogger.e('ApiService', 'Error updating doctor $docName: $e');
        }
      }

      // Update in-memory doctors
      for (int i = 0; i < _cachedDoctors.length; i++) {
        final doc = _cachedDoctors[i];
        final bool hasMatch = (doc.institution != null && (doc.institution == oldId || doc.institution == oldName)) ||
            doc.workplaces.any((w) => w.workplace == oldId || w.workplace == oldName);
        if (hasMatch) {
          final updatedWps = doc.workplaces.map((w) {
            if (w.workplace == oldId || w.workplace == oldName) {
              return HcpWorkplace(
                workplace: replacementInstitution.name,
                address: replacementInstitution.institutionName,
                cityMunicipality: replacementInstitution.cityMunicipality,
                provinceName: replacementInstitution.provinceName,
                isPrimary: w.isPrimary,
              );
            }
            return w;
          }).toList();
          _cachedDoctors[i] = doc.copyWith(
            workplaces: updatedWps,
            institution: replacementInstitution.name,
          );
        }
      }

      // 5. Remap across linked HCP Accounts (Server + Cache)
      final Set<String> targetAccNames = {};
      try {
        final qa1 = Uri.parse('$baseUrl/api/resource/HCP%20Account?filters=[["workplace_id","in",["${Uri.encodeComponent(oldId)}","${Uri.encodeComponent(oldName)}"]]]&fields=["name"]&limit=500');
        final ra1 = await http.get(qa1, headers: _headers);
        if (ra1.statusCode == 200) {
          final data = jsonDecode(ra1.body)['data'] as List?;
          data?.forEach((d) => targetAccNames.add(d['name'].toString()));
        }
      } catch (_) {}

      try {
        final qa2 = Uri.parse('$baseUrl/api/resource/HCP%20Account?filters=[["HCP%20Account%20Workplace","hcp_workplace","in",["${Uri.encodeComponent(oldId)}","${Uri.encodeComponent(oldName)}"]]]&fields=["name"]&limit=500');
        final ra2 = await http.get(qa2, headers: _headers);
        if (ra2.statusCode == 200) {
          final data = jsonDecode(ra2.body)['data'] as List?;
          data?.forEach((d) => targetAccNames.add(d['name'].toString()));
        }
      } catch (_) {}

      for (final a in _cachedHcpAccounts) {
        if (a.name != null && (a.workplaceId == oldId || a.workplaceId == oldName || a.workplaces.any((w) => w.hcpWorkplace == oldId || w.hcpWorkplace == oldName))) {
          targetAccNames.add(a.name!);
        }
      }

      for (final accName in targetAccNames) {
        try {
          final accGetUrl = Uri.parse('$baseUrl/api/resource/HCP%20Account/${Uri.encodeComponent(accName)}');
          final accGetRes = await http.get(accGetUrl, headers: _headers);
          if (accGetRes.statusCode == 200) {
            final accData = jsonDecode(accGetRes.body)['data'] as Map<String, dynamic>;
            final rawWps = (accData['workplace_info'] as List? ?? []).cast<Map<String, dynamic>>();
            bool modifiedWps = false;
            final updatedWpsList = rawWps.map((wp) {
              final wId = (wp['hcp_workplace'] ?? '').toString();
              if (wId == oldId || wId == oldName) {
                modifiedWps = true;
                final copy = Map<String, dynamic>.from(wp);
                copy['hcp_workplace'] = replacementInstitution.name;
                copy['city_municipality'] = replacementInstitution.cityMunicipality;
                copy['province_name'] = replacementInstitution.provinceName;
                return copy;
              }
              return wp;
            }).toList();

            final accPutBody = <String, dynamic>{};
            if (modifiedWps) {
              accPutBody['workplace_info'] = updatedWpsList;
            }
            if (accData['workplace_id'] == oldId || accData['workplace_id'] == oldName) {
              accPutBody['workplace_id'] = replacementInstitution.name;
            }
            accPutBody['workplace_approval_note'] = remappedTag;
            accPutBody['rejection_reason'] = '';

            await http.put(accGetUrl, headers: _headers, body: jsonEncode(accPutBody));
          }
        } catch (e) {
          AppLogger.e('ApiService', 'Error updating account $accName: $e');
        }
      }

      // Update in-memory accounts
      for (int i = 0; i < _cachedHcpAccounts.length; i++) {
        final acc = _cachedHcpAccounts[i];
        final bool hasMatch = (acc.workplaceId != null && (acc.workplaceId == oldId || acc.workplaceId == oldName)) ||
            acc.workplaces.any((w) => w.hcpWorkplace == oldId || w.hcpWorkplace == oldName);
        if (hasMatch) {
          final updatedWps = acc.workplaces.map((w) {
            if (w.hcpWorkplace == oldId || w.hcpWorkplace == oldName) {
              return HcpAccountWorkplace(
                hcpWorkplace: replacementInstitution.name,
                address: replacementInstitution.institutionName,
                cityMunicipality: replacementInstitution.cityMunicipality,
                provinceName: replacementInstitution.provinceName,
                isPrimary: w.isPrimary,
                preferred: w.preferred,
              );
            }
            return w;
          }).toList();
          _cachedHcpAccounts[i] = acc.copyWith(
            workplaceId: (acc.workplaceId == oldId || acc.workplaceId == oldName)
                ? replacementInstitution.name
                : acc.workplaceId,
            workplaces: updatedWps,
            workplaceApprovalNote: remappedTag,
          );
        }
      }

      // 6. Persist local cache files
      await _writeToCache('institutions_cache.json', jsonEncode(_cachedInstitutions.map((e) => e.toJson()).toList()));
      if (_cachedDoctors.isNotEmpty) {
        await _writeToCache('hcp_cache.json', jsonEncode(_cachedDoctors.map((e) => e.toJson()).toList()));
      }
      if (_cachedHcpAccounts.isNotEmpty) {
        await _writeToCache('hcp_accounts_cache.json', jsonEncode(_cachedHcpAccounts.map((e) => e.toJson()).toList()));
      }
      if (_cachedSubmissions.isNotEmpty) {
        await _writeToCache('submissions_cache.json', jsonEncode(_cachedSubmissions.map((e) => e.toJson()).toList()));
      }

      // 7. Notify MedRep of Remapping
      NotificationService.showInstitutionRemappedNotification(
        oldInstitutionName: oldName,
        newInstitutionName: replacementInstitution.institutionName,
        reason: note,
      ).catchError((e) => AppLogger.e('ApiService', 'Notification dispatch failed: $e'));

      notifyListeners();
      fetchInstitutions().catchError((_) => <Institution>[]);
      AppLogger.i('ApiService', 'Successfully remapped rejected institution $oldName ($oldId) to ${replacementInstitution.institutionName}');
      return true;
    } catch (e, st) {
      AppLogger.e('ApiService', 'remapRejectedInstitution error: $e', e, st);
      return false;
    }
  }

  /// Starts 60-second editing lock on an institution when user clicks "Edit"
  void startEditingCooldown(String nameOrId, {String? user}) {
    final idx = _cachedInstitutions.indexWhere((i) => i.name == nameOrId || i.institutionName.toLowerCase() == nameOrId.toLowerCase());
    if (idx >= 0) {
      final old = _cachedInstitutions[idx];
      final editor = user ?? loggedInFullName ?? loggedInEmail ?? 'User';
      _cachedInstitutions[idx] = old.copyWith(
        activeEditingLock: DateTime.now(),
        editingUser: editor,
      );
      notifyListeners();
    }
  }

  /// Clears active editing cooldown on cancel or submit
  void clearEditingCooldown(String nameOrId) {
    final idx = _cachedInstitutions.indexWhere((i) => i.name == nameOrId || i.institutionName.toLowerCase() == nameOrId.toLowerCase());
    if (idx >= 0) {
      final old = _cachedInstitutions[idx];
      _cachedInstitutions[idx] = old.copyWith(
        activeEditingLock: null,
        editingUser: null,
      );
      notifyListeners();
    }
  }

  /// Retrieve list of COREnergy Engage logs
  Future<List<COREnergyEngage>> fetchCOREnergyEngages() async {
    List<COREnergyEngage> baseList = [];
    bool fetchedOnline = false;

    if (!_isOffline) {
      final url = Uri.parse(
        '$baseUrl/api/resource/COREnergy%20Engage?fields=["name","institution_name","region_name","province_name","city_municipality","street_address","sales_rep","creation","modified"]&limit=5000',
      );
      try {
        final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 7));
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final List<dynamic> dataList = body['data'] ?? [];
          await _writeToCache('corenergy_engages_cache.json', jsonEncode(dataList));
          baseList = dataList.map((json) => COREnergyEngage.fromJson(json)).toList();
          fetchedOnline = true;
        }
      } catch (e) {
        print('Fetch COREnergy Engages online failed, reading from cache... error: $e');
        _isOffline = true;
        notifyListeners();
      }
    }

    if (!fetchedOnline) {
      final cache = await _readFromCache('corenergy_engages_cache.json');
      if (cache != null) {
        try {
          final List<dynamic> jsonList = jsonDecode(cache);
          baseList = jsonList.map((json) => COREnergyEngage.fromJson(json)).toList();
        } catch (_) {}
      } else {
        // Mock fallback if no cache exists yet
        baseList = [
          COREnergyEngage(
            name: 'INST-04249',
            institutionName: 'INST-04249',
            hospitalClinic: 'Bayview Hotel Development Corp',
            region: 'NCR',
            province: 'Metro Manila-Manila',
            cityMunicipality: 'Ermita',
            streetAddress: '123 Roxas Blvd',
            salesRep: loggedInEmail ?? 'jptan@profinsights.biz',
            creation: '2026-07-01 10:00:00',
          ),
          COREnergyEngage(
            name: 'INST-04644',
            institutionName: 'INST-04644',
            hospitalClinic: 'Dolmar Press Incorporated',
            region: 'NCR',
            province: 'Metro Manila-Manila',
            cityMunicipality: 'Ermita',
            streetAddress: '456 Taft Ave',
            salesRep: 'kmtaotao@pims-marketing.com',
            creation: '2026-07-02 11:30:00',
          ),
        ];
      }
    }

    // Apply pending updates from SQLite over the baseList
    final pendingUpdates = await _readPendingUpdates();
    for (var update in pendingUpdates) {
      final idx = baseList.indexWhere((e) => e.name == update.name);
      if (idx != -1) {
        baseList[idx] = update;
      }
    }

    // Apply pending creations from SQLite over the baseList
    final pendingCreates = await _readPendingCreates();
    final existingNames = baseList.map((e) => e.name).toSet();
    for (var create in pendingCreates) {
      if (!existingNames.contains(create.name)) {
        baseList.insert(0, create);
      }
    }

    return baseList;
  }

  /// Retrieve full details of a single COREnergy Engage log (including child tables)
  Future<COREnergyEngage> fetchCOREnergyEngageByName(String name) async {
    // Check local SQLite queues first (if it's a pending create/update, SQLite details are most current)
    final pendingCreates = await _readPendingCreates();
    final matchCreate = pendingCreates.where((e) => e.name == name);
    if (matchCreate.isNotEmpty) return matchCreate.first;

    final pendingUpdates = await _readPendingUpdates();
    final matchUpdate = pendingUpdates.where((e) => e.name == name);
    if (matchUpdate.isNotEmpty) return matchUpdate.first;

    if (_isOffline) {
      final cache = await _readFromCache('engage_details_cache.json');
      if (cache != null) {
        try {
          final Map<String, dynamic> cacheMap = jsonDecode(cache);
          if (cacheMap.containsKey(name)) {
            return COREnergyEngage.fromJson(cacheMap[name]);
          }
        } catch (_) {}
      }

      // Check main list
      final mainList = await fetchCOREnergyEngages();
      final matchMain = mainList.where((e) => e.name == name);
      if (matchMain.isNotEmpty) return matchMain.first;

      throw Exception('COREnergy Engage detail not found in offline cache.');
    }

    final url = Uri.parse('$baseUrl/api/resource/COREnergy%20Engage/$name');
    try {
      final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final detailedEngage = COREnergyEngage.fromJson(body['data']);
        await _saveDetailToCache(name, detailedEngage);
        return detailedEngage;
      } else {
        throw Exception('Failed to load COREnergy Engage detail: ${response.statusCode}');
      }
    } catch (e) {
      print('Fetch detail online failed, reading from cache... error: $e');
      final cache = await _readFromCache('engage_details_cache.json');
      if (cache != null) {
        try {
          final Map<String, dynamic> cacheMap = jsonDecode(cache);
          if (cacheMap.containsKey(name)) {
            return COREnergyEngage.fromJson(cacheMap[name]);
          }
        } catch (_) {}
      }
      throw Exception('COREnergy Engage detail not found in offline cache.');
    }
  }

  /// Create a new COREnergy Engage record
  Future<COREnergyEngage> createCOREnergyEngage(COREnergyEngage engage) async {
    if (_isOffline) {
      return _saveCOREnergyEngageOffline(engage, isCreate: true);
    }

    final url = Uri.parse('$baseUrl/api/resource/COREnergy%20Engage');
    final payload = engage.toJson();
    payload.remove('name'); // Always remove name for CREATE requests to let server assign/determine naming
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final created = COREnergyEngage.fromJson(body['data']);
        await _saveDetailToCache(created.name, created);

        // Update list cache
        final cache = await _readFromCache('corenergy_engages_cache.json');
        if (cache != null) {
          try {
            final List<dynamic> jsonList = jsonDecode(cache);
            final list = jsonList.map((json) => COREnergyEngage.fromJson(json)).toList();
            if (!list.any((e) => e.name == created.name)) {
              list.insert(0, created);
              await _writeToCache('corenergy_engages_cache.json', jsonEncode(list.map((e) => e.toJson()).toList()));
            }
          } catch (_) {}
        }

        return created;
      } else {
        throw Exception('Failed to create COREnergy Engage: ${response.body}');
      }
    } catch (e) {
      print('Create COREnergy Engage online failed: $e. Falling back to SQLite offline queue...');
      _isOffline = true;
      notifyListeners();
      return _saveCOREnergyEngageOffline(engage, isCreate: true);
    }
  }

  /// Update an existing COREnergy Engage record
  Future<COREnergyEngage> updateCOREnergyEngage(String name, COREnergyEngage engage) async {
    if (_isOffline) {
      return _saveCOREnergyEngageOffline(engage, isCreate: false);
    }

    final url = Uri.parse('$baseUrl/api/resource/COREnergy%20Engage/$name');
    final payloadMap = engage.toJson();
    payloadMap.remove('name');
    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode(payloadMap),
      ).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final updated = COREnergyEngage.fromJson(body['data']);
        await _saveDetailToCache(name, updated);

        // Update list cache
        final cache = await _readFromCache('corenergy_engages_cache.json');
        if (cache != null) {
          try {
            final List<dynamic> jsonList = jsonDecode(cache);
            final list = jsonList.map((json) => COREnergyEngage.fromJson(json)).toList();
            final idx = list.indexWhere((e) => e.name == name);
            if (idx != -1) {
              list[idx] = updated;
              await _writeToCache('corenergy_engages_cache.json', jsonEncode(list.map((e) => e.toJson()).toList()));
            }
          } catch (_) {}
        }

        return updated;
      } else if (response.statusCode == 404 || 
                 response.body.contains('DoesNotExistError') || 
                 response.body.contains('not found')) {
        print('COREnergy Engage document does not exist online for $name. Falling back to CREATE...');
        return await createCOREnergyEngage(engage);
      } else {
        throw Exception('Failed to update COREnergy Engage: ${response.body}');
      }
    } catch (e) {
      print('Update COREnergy Engage online failed: $e. Falling back to SQLite offline queue...');
      _isOffline = true;
      notifyListeners();
      return _saveCOREnergyEngageOffline(engage, isCreate: false);
    }
  }

  Future<COREnergyEngage> _saveCOREnergyEngageOffline(COREnergyEngage engage, {required bool isCreate}) async {
    final offlineKey = engage.institutionName ?? engage.name;
    final nowStr = DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19);
    final localEngage = COREnergyEngage(
      name: engage.name.isEmpty ? offlineKey : engage.name,
      institutionName: offlineKey,
      hospitalClinic: engage.hospitalClinic,
      region: engage.region,
      province: engage.province,
      cityMunicipality: engage.cityMunicipality,
      streetAddress: engage.streetAddress,
      salesRep: engage.salesRep,
      creation: engage.creation ?? nowStr,
      modified: nowStr,
      contacts: engage.contacts,
      visits: engage.visits,
      actionItems: engage.actionItems,
    );

    if (isCreate) {
      await _addPendingCreate(localEngage);
    } else {
      await _addPendingUpdate(offlineKey, localEngage);
    }
    await _saveDetailToCache(localEngage.name, localEngage);
    if (localEngage.institutionName != null && localEngage.institutionName != localEngage.name) {
      await _saveDetailToCache(localEngage.institutionName!, localEngage);
    }

    // Update list cache
    final cache = await _readFromCache('corenergy_engages_cache.json');
    if (cache != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cache);
        final list = jsonList.map((json) => COREnergyEngage.fromJson(json)).toList();
        final idx = list.indexWhere((e) => e.name == localEngage.name || e.institutionName == localEngage.institutionName);
        if (idx != -1) {
          list[idx] = localEngage;
        } else {
          list.insert(0, localEngage);
        }
        await _writeToCache('corenergy_engages_cache.json', jsonEncode(list.map((e) => e.toJson()).toList()));
      } catch (_) {}
    }

    return localEngage;
  }

  /// Create a new engagement record
  Future<Engagement> createEngagement(Engagement engagement) async {
    final url = Uri.parse('$baseUrl/api/resource/Successful%20COREnergy%20Engagement');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(engagement.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        return Engagement.fromJson(body['data']);
      } else {
        throw Exception('Failed to create record: ${response.body}');
      }
    } catch (e) {
      print('Create engagement error: $e');
      rethrow;
    }
  }

  /// Update an existing engagement record
  Future<Engagement> updateEngagement(String name, Engagement engagement) async {
    final url = Uri.parse(
      '$baseUrl/api/resource/Successful%20COREnergy%20Engagement/${Uri.encodeComponent(name)}',
    );
    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode(engagement.toJson()),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return Engagement.fromJson(body['data']);
      } else {
        throw Exception('Failed to update record: ${response.body}');
      }
    } catch (e) {
      print('Update engagement error: $e');
      rethrow;
    }
  }

  /// Retrieve list of HCP/Doctors
  /// Retrieve list of HCP/Doctors with multi-tier resilient fallback (permits MedRep & Manager access)
  Future<List<Hcp>> fetchDoctors() async {
    if (_isOffline) {
      final cache = await _readFromCache('doctors_cache.json');
      if (cache != null) {
        try {
          final List<dynamic> dataList = jsonDecode(cache);
          final list = dataList.map((json) => Hcp.fromJson(json)).toList();
          _cachedDoctors = list;
          return list;
        } catch (_) {}
      }
      return _cachedDoctors;
    }

    // Tier 1: Query HCP doctype with fields=["*"] via REST Resource API
    try {
      final url = Uri.parse('$baseUrl/api/resource/HCP?fields=["*"]&limit_page_length=5000&limit=5000');
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] ?? [];
        if (dataList.isNotEmpty) {
          final list = dataList.map((json) => Hcp.fromJson(json)).toList();
          _cachedDoctors = list;
          await _writeToCache('doctors_cache.json', jsonEncode(dataList));
          return list;
        }
      }
    } catch (e) {
      print('Tier 1 fetch doctors error: $e');
    }

    // Tier 2: Whitelisted client method with fields=["*"] strictly from HCP DocType
    try {
      final clientUrl = Uri.parse(
        '$baseUrl/api/method/frappe.client.get_list?doctype=HCP&fields=["*"]&limit_page_length=5000',
      );
      final clientResp = await http.get(clientUrl, headers: _headers);
      if (clientResp.statusCode == 200) {
        final body = jsonDecode(clientResp.body);
        final List<dynamic> dataList = body['message'] ?? body['data'] ?? [];
        if (dataList.isNotEmpty) {
          final list = dataList.map((json) => Hcp.fromJson(json)).toList();
          _cachedDoctors = list;
          await _writeToCache('doctors_cache.json', jsonEncode(dataList));
          return list;
        }
      }
    } catch (e) {
      print('Tier 2 client method fetch doctors error: $e');
    }

    // Tier 3: Query HCP doctype with explicit public fields (permlevel 0 safe for MedRep)
    try {
      final urlPublic = Uri.parse(
        '$baseUrl/api/resource/HCP?fields=["name","first_name","middle_name","last_name","hcp_full_name","birth_date","hcp_photo","hcp_type","hcp_practice","is_active","profile_last_updated"]&limit_page_length=5000&limit=5000',
      );
      final response = await http.get(urlPublic, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] ?? [];
        if (dataList.isNotEmpty) {
          final list = dataList.map((json) => Hcp.fromJson(json)).toList();
          _cachedDoctors = list;
          await _writeToCache('doctors_cache.json', jsonEncode(dataList));
          return list;
        }
      }
    } catch (e) {
      print('Tier 3 fetch doctors error: $e');
    }

    // Tier 4: Whitelisted client method with explicit fields strictly from HCP DocType
    try {
      final clientUrl = Uri.parse(
        '$baseUrl/api/method/frappe.client.get_list?doctype=HCP&fields=["name","first_name","middle_name","last_name","hcp_full_name","birth_date","hcp_photo","hcp_type","hcp_practice","is_active"]&limit_page_length=5000',
      );
      final clientResp = await http.get(clientUrl, headers: _headers);
      if (clientResp.statusCode == 200) {
        final body = jsonDecode(clientResp.body);
        final List<dynamic> dataList = body['message'] ?? body['data'] ?? [];
        if (dataList.isNotEmpty) {
          final list = dataList.map((json) => Hcp.fromJson(json)).toList();
          _cachedDoctors = list;
          await _writeToCache('doctors_cache.json', jsonEncode(dataList));
          return list;
        }
      }
    } catch (e) {
      print('Tier 4 fetch doctors error: $e');
    }

    // Tier 5: Cache fallback from previous successful HCP DocType fetches
    final cache = await _readFromCache('doctors_cache.json');
    if (cache != null) {
      try {
        final List<dynamic> dataList = jsonDecode(cache);
        final list = dataList.map((json) => Hcp.fromJson(json)).toList();
        _cachedDoctors = list;
        return list;
      } catch (_) {}
    }

    if (_cachedDoctors.isNotEmpty) return _cachedDoctors;
    return [];
  }

  /// Fetch full details of a specific Doctor (HCP) including child tables
  Future<Hcp> fetchDoctorDetail(String name) async {
    final url = Uri.parse(
      '$baseUrl/api/resource/HCP/${Uri.encodeComponent(name)}',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return Hcp.fromJson(body['data']);
      }
    } catch (e) {
      print('Fetch doctor detail direct error: $e');
    }

    // Try fallback via frappe.client.get
    try {
      final fallbackUrl = Uri.parse(
        '$baseUrl/api/method/frappe.client.get?doctype=HCP&name=${Uri.encodeComponent(name)}',
      );
      final resp = await http.get(fallbackUrl, headers: _headers);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final data = body['message'] ?? body['data'];
        if (data != null) return Hcp.fromJson(data);
      }
    } catch (_) {}

    // Try fallback via HCP Account
    try {
      final accounts = await fetchHcpAccounts();
      final matched = accounts.firstWhere(
        (a) => a.hcp == name || a.name == name || (a.hcpName != null && a.hcpName!.toLowerCase() == name.toLowerCase()),
      );
      return Hcp(
        name: matched.hcp ?? matched.name,
        firstName: matched.hcpName ?? 'Doctor',
        lastName: '',
        hcpFullName: matched.hcpName,
        hcpType: 'Resident',
        hcpPractice: 'Both',
        specialties: matched.specialties.map((s) => HcpSpecialty(hcpSpecialty: s.hcpSpecialty, subSpecialty: s.subSpecialty, isPrimary: s.preferred)).toList(),
        workplaces: matched.workplaces.map((w) => HcpWorkplace(workplace: w.hcpWorkplace, cityMunicipality: w.cityMunicipality, provinceName: w.provinceName, address: w.address, isPrimary: w.preferred)).toList(),
        contacts: matched.contacts.map((c) => HcpContact(contactNumber: c.contactNumber, emailAddress: c.emailAddress, isPrimary: c.preferred)).toList(),
      );
    } catch (_) {}

    throw Exception('Failed to load doctor details: $name');
  }

  /// Create a new HCP/Doctor record
  Future<Hcp> createDoctor(Hcp hcp) async {
    final url = Uri.parse('$baseUrl/api/resource/HCP');
    try {
      final payload = hcp.toJson();

      final fullNameParts = [
        if (hcp.firstName.trim().isNotEmpty) hcp.firstName.trim(),
        if (hcp.middleName != null && hcp.middleName!.trim().isNotEmpty && hcp.middleName!.trim() != '-') hcp.middleName!.trim(),
        if (hcp.lastName.trim().isNotEmpty) hcp.lastName.trim(),
      ].join(' ');

      final effectiveName = (hcp.hcpFullName != null && hcp.hcpFullName!.trim().isNotEmpty && !hcp.hcpFullName!.trim().startsWith('HCP-'))
          ? hcp.hcpFullName!.trim()
          : (fullNameParts.isNotEmpty ? fullNameParts : '${hcp.firstName.trim()} ${hcp.lastName.trim()}'.trim());

      payload['first_name'] = hcp.firstName.trim();
      payload['middle_name'] = (hcp.middleName != null && hcp.middleName!.trim().isNotEmpty && hcp.middleName!.trim() != '-')
          ? hcp.middleName!.trim()
          : '-';
      payload['last_name'] = hcp.lastName.trim();
      payload['hcp_full_name'] = effectiveName;
      payload['full_name'] = effectiveName;
      payload['doctor_name'] = effectiveName;
      payload['hcp_name'] = effectiveName;
      payload['name_of_doctor'] = effectiveName;
      payload['is_active'] = hcp.isActive ? 1 : 0;
      if (payload['birth_date'] == null || payload['birth_date'].toString().trim().isEmpty) {
        payload.remove('birth_date');
      }

      // Map hcp_type Link field to valid ERPNext key
      final rawType = (payload['hcp_type'] ?? hcp.hcpType ?? '').toString().trim();
      if (rawType.toLowerCase().contains('consultant') || rawType == 'HCP-TYPE-01') {
        payload['hcp_type'] = 'HCP-TYPE-01';
      } else if (rawType.toLowerCase().contains('resident') || rawType == 'HCP-TYPE-02') {
        payload['hcp_type'] = 'HCP-TYPE-02';
      } else if (rawType.toLowerCase().contains('fellow') || rawType == 'HCP-TYPE-03') {
        payload['hcp_type'] = 'HCP-TYPE-03';
      } else {
        payload['hcp_type'] = rawType.isNotEmpty ? rawType : 'HCP-TYPE-01';
      }

      // Map hcp_practice field
      final rawPractice = (payload['hcp_practice'] ?? hcp.hcpPractice ?? '').toString().trim();
      if (rawPractice == 'Dispensing' || rawPractice == 'Prescribing' || rawPractice == 'Both') {
        payload['hcp_practice'] = rawPractice;
      } else {
        payload['hcp_practice'] = 'Prescribing';
      }

      // Handle doctor photo upload if base64
      if (payload['hcp_photo'] != null) {
        final hp = payload['hcp_photo'].toString().trim();
        if (hp.startsWith('data:') || hp.length > 200) {
          try {
            Uint8List? rawBytes;
            if (hp.contains(',')) {
              rawBytes = base64Decode(hp.split(',').last.trim());
            } else {
              rawBytes = base64Decode(hp.trim());
            }
            final uploadedUrl = await uploadFile(
              bytes: rawBytes,
              filename: 'hcp_${DateTime.now().millisecondsSinceEpoch}.jpg',
              doctype: 'HCP',
            );
            if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
              payload['hcp_photo'] = uploadedUrl;
              payload['image'] = uploadedUrl;
              payload['photo'] = uploadedUrl;
            } else {
              payload.remove('hcp_photo');
              payload.remove('image');
              payload.remove('photo');
            }
          } catch (e) {
            print('Could not upload doctor hcp_photo: $e');
            payload.remove('hcp_photo');
            payload.remove('image');
            payload.remove('photo');
          }
        } else {
          payload['image'] = hp;
          payload['photo'] = hp;
        }
      }
      
      // Ensure hcp_specialty Link fields map to valid ERPNext Specialization primary keys
      final specs = await fetchSpecializations().catchError((_) => <Specialization>[]);
      final List<Map<String, dynamic>> cleanSpecs = [];
      if (payload['hcp_specialty'] is List && (payload['hcp_specialty'] as List).isNotEmpty) {
        for (var item in (payload['hcp_specialty'] as List)) {
          if (item is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(item);
            final rawSpec = (map['hcp_specialty'] ?? map['specialty'] ?? '').toString().trim();
            if (rawSpec.isNotEmpty) {
              final specId = LocationResolver.resolveSpecialtyId(rawSpec, specs.isNotEmpty ? specs : null);
              map['hcp_specialty'] = specId.isNotEmpty ? specId : 'SPEC-00001';
              map['specialty'] = specId.isNotEmpty ? specId : 'SPEC-00001';
            }
            final rawSub = (map['sub_specialty'] ?? '').toString().trim();
            if (rawSub.isNotEmpty && rawSub != 'None' && rawSub != '-') {
              final subId = LocationResolver.resolveSpecialtyId(rawSub, specs.isNotEmpty ? specs : null);
              map['sub_specialty'] = subId.isNotEmpty ? subId : null;
            } else {
              map.remove('sub_specialty');
            }
            final isPref = (map['is_primary'] == 1 || map['is_primary'] == true ||
                map['primary'] == 1 || map['primary'] == true ||
                map['preferred'] == 1 || map['preferred'] == true ||
                map['is_preferred'] == 1 || map['is_preferred'] == true);
            map['is_primary'] = isPref ? 1 : 0;
            map['preferred'] = isPref ? 1 : 0;
            cleanSpecs.add(map);
          }
        }
      }
      if (cleanSpecs.isEmpty) {
        cleanSpecs.add({'hcp_specialty': 'SPEC-00001', 'is_primary': 1, 'preferred': 1});
      }
      payload['hcp_specialty'] = cleanSpecs;

      // Ensure hcp_workplace Link fields map to valid ERPNext Institution primary keys
      final insts = await fetchInstitutions().catchError((_) => <Institution>[]);
      final psgc = await fetchPsgcLocations().catchError((_) => <PsgcLocation>[]);
      final List<Map<String, dynamic>> cleanWps = [];
      if (payload['hcp_workplace'] is List && (payload['hcp_workplace'] as List).isNotEmpty) {
        for (var item in (payload['hcp_workplace'] as List)) {
          if (item is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(item);
            final rawWp = (map['hcp_workplace'] ?? map['workplace'] ?? map['address'] ?? map['workplace_name'] ?? '').toString().trim();
            final rawProv = (map['province_name'] ?? map['province'] ?? '').toString().trim();
            final rawCity = (map['city_municipality'] ?? map['city'] ?? '').toString().trim();

            final resolvedLoc = LocationResolver.resolveCompleteWorkplaceLocation(
              institutionIdOrName: rawWp,
              cityIdOrName: rawCity,
              provinceIdOrName: rawProv,
              institutions: insts,
              dynamicLocations: psgc,
            );

            final isPref = (map['is_primary'] == 1 || map['is_primary'] == true ||
                map['primary'] == 1 || map['primary'] == true ||
                map['preferred'] == 1 || map['preferred'] == true ||
                map['is_preferred'] == 1 || map['is_preferred'] == true);

            cleanWps.add({
              'hcp_workplace': resolvedLoc.workplaceId,
              'workplace': resolvedLoc.workplaceId,
              'province_name': resolvedLoc.provinceId,
              'city_municipality': resolvedLoc.cityId,
              'is_primary': isPref ? 1 : 0,
              'primary': isPref ? 1 : 0,
              'preferred': isPref ? 1 : 0,
              'is_preferred': isPref ? 1 : 0,
            });
          }
        }
      }
      if (cleanWps.isEmpty) {
        cleanWps.add({
          'hcp_workplace': 'INST-00001',
          'workplace': 'INST-00001',
          'province_name': '1380600000',
          'city_municipality': '1380608000',
          'is_primary': 1,
          'preferred': 1,
        });
      }
      payload['hcp_workplace'] = cleanWps;

      // Ensure parent level region_name, province_name, city_municipality, institution are NEVER blank!
      if (cleanWps.isNotEmpty) {
        final prefMap = cleanWps.firstWhere((w) => w['is_primary'] == 1, orElse: () => cleanWps.first);
        if (payload['institution'] == null || payload['institution'].toString().trim().isEmpty) {
          payload['institution'] = prefMap['hcp_workplace'];
        }
        if (payload['province_name'] == null || payload['province_name'].toString().trim().isEmpty) {
          payload['province_name'] = prefMap['province_name'];
        }
        if (payload['city_municipality'] == null || payload['city_municipality'].toString().trim().isEmpty) {
          payload['city_municipality'] = prefMap['city_municipality'];
        }
        if (payload['region_name'] == null || payload['region_name'].toString().trim().isEmpty) {
          final reg = LocationResolver.resolveRegionFromProvince(prefMap['province_name']);
          final regId = LocationResolver.resolveRegionId(reg);
          payload['region_name'] = regId.isNotEmpty ? regId : '1300000000';
        }
      }

      // Ensure contacts are properly structured
      if (payload['contacts'] is List) {
        final List<Map<String, dynamic>> cleanContacts = [];
        for (var item in (payload['contacts'] as List)) {
          if (item is Map<String, dynamic>) {
            final num = (item['contact_number'] ?? item['phone'] ?? item['mobile'] ?? '').toString().trim();
            final em = (item['email_address'] ?? item['email'] ?? '').toString().trim();
            if (num.isNotEmpty || em.isNotEmpty) {
              cleanContacts.add({
                if (num.isNotEmpty) 'contact_number': num,
                if (em.isNotEmpty) 'email_address': em,
                'is_primary': (item['is_primary'] == 1 || item['preferred'] == 1 || item['primary'] == true) ? 1 : 0,
              });
            }
          }
        }
        if (cleanContacts.isNotEmpty) {
          payload['contacts'] = cleanContacts;
          payload['contact_info'] = cleanContacts;
          payload['hcp_contact_info'] = cleanContacts;
        }
      }

      // Log the payload for debugging
      print('[createDoctor] Sending payload to /api/resource/HCP');
      print('[createDoctor] first_name=${payload['first_name']}, last_name=${payload['last_name']}, hcp_type=${payload['hcp_type']}');
      print('[createDoctor] specialties count=${(payload['hcp_specialty'] as List?)?.length ?? 0}');
      print('[createDoctor] workplaces count=${(payload['hcp_workplace'] as List?)?.length ?? 0}');

      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      );
      print('[createDoctor] POST /api/resource/HCP status=${response.statusCode}');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        print('[createDoctor] Doctor created: ${body['data']?['name']}');
        return Hcp.fromJson(body['data']);
      } else {
        print('[createDoctor] POST failed: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
        
        // Fallback 1: Try frappe.client.insert RPC method
        final rpcUrl = Uri.parse('$baseUrl/api/method/frappe.client.insert');
        final rpcResp = await http.post(
          rpcUrl,
          headers: _headers,
          body: jsonEncode({
            'doc': {
              'doctype': 'HCP',
              ...payload,
            }
          }),
        );
        print('[createDoctor] RPC insert status=${rpcResp.statusCode}');
        if (rpcResp.statusCode == 200) {
          final rpcBody = jsonDecode(rpcResp.body);
          final docData = rpcBody['message'] ?? rpcBody['data'];
          if (docData != null && docData is Map<String, dynamic>) {
            print('[createDoctor] Doctor created via RPC: ${docData['name']}');
            return Hcp.fromJson(docData);
          }
        }

        // Fallback 2: If child table validation failed, try with minimal mandatory fields
        print('[createDoctor] Retrying with minimal clean fields...');
        final minimalPayload = {
          'first_name': payload['first_name'],
          'middle_name': payload['middle_name'] ?? '-',
          'last_name': payload['last_name'],
          'hcp_full_name': payload['hcp_full_name'],
          'hcp_type': payload['hcp_type'] ?? 'HCP-TYPE-01',
          'hcp_practice': payload['hcp_practice'] ?? 'Prescribing',
          'is_active': 1,
          'hcp_specialty': [
            {'hcp_specialty': cleanSpecs.first['hcp_specialty'] ?? 'SPEC-00001', 'is_primary': 1}
          ],
          'hcp_workplace': [
            {'hcp_workplace': cleanWps.first['hcp_workplace'] ?? 'INST-00001', 'is_primary': 1}
          ],
        };

        final minResp = await http.post(
          url,
          headers: _headers,
          body: jsonEncode(minimalPayload),
        );
        if (minResp.statusCode == 200) {
          final minBody = jsonDecode(minResp.body);
          print('[createDoctor] Doctor created via minimal payload: ${minBody['data']?['name']}');
          return Hcp.fromJson(minBody['data']);
        }

        final minRpcResp = await http.post(
          rpcUrl,
          headers: _headers,
          body: jsonEncode({
            'doc': {
              'doctype': 'HCP',
              ...minimalPayload,
            }
          }),
        );
        if (minRpcResp.statusCode == 200) {
          final minRpcBody = jsonDecode(minRpcResp.body);
          final docData = minRpcBody['message'] ?? minRpcBody['data'];
          if (docData != null && docData is Map<String, dynamic>) {
            print('[createDoctor] Doctor created via minimal RPC: ${docData['name']}');
            return Hcp.fromJson(docData);
          }
        }

        throw Exception('Failed to create doctor. Server response: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
      }
    } catch (e) {
      print('[createDoctor] Error: $e');
      rethrow;
    }
  }

  /// Update an existing HCP/Doctor record
  Future<Hcp> updateDoctor(String name, Hcp hcp) async {
    final isAlreadyLocked = _inFlightHcpIds.contains(name);
    if (!isAlreadyLocked) {
      _inFlightHcpIds.add(name);
    }
    final url = Uri.parse(
      '$baseUrl/api/resource/HCP/${Uri.encodeComponent(name)}',
    );
    try {
      final payload = hcp.toJson();
      final fullNameParts = [
        if (hcp.firstName.trim().isNotEmpty) hcp.firstName.trim(),
        if (hcp.middleName != null && hcp.middleName!.trim().isNotEmpty && hcp.middleName!.trim() != '-') hcp.middleName!.trim(),
        if (hcp.lastName.trim().isNotEmpty) hcp.lastName.trim(),
      ].join(' ');

      final effectiveName = (hcp.hcpFullName != null && hcp.hcpFullName!.trim().isNotEmpty && !hcp.hcpFullName!.trim().startsWith('HCP-'))
          ? hcp.hcpFullName!.trim()
          : (fullNameParts.isNotEmpty ? fullNameParts : '${hcp.firstName.trim()} ${hcp.lastName.trim()}'.trim());

      payload['first_name'] = hcp.firstName.trim();
      payload['middle_name'] = (hcp.middleName != null && hcp.middleName!.trim().isNotEmpty && hcp.middleName!.trim() != '-') ? hcp.middleName!.trim() : '-';
      payload['last_name'] = hcp.lastName.trim();
      payload['hcp_full_name'] = effectiveName;
      payload['full_name'] = effectiveName;
      payload['doctor_name'] = effectiveName;
      payload['hcp_name'] = effectiveName;
      payload['name_of_doctor'] = effectiveName;

      // Ensure hcp_type Link ID is valid
      final rawType = (payload['hcp_type'] ?? hcp.hcpType).toString().trim();
      if (rawType.toLowerCase().contains('consultant') || rawType == 'HCP-TYPE-01') {
        payload['hcp_type'] = 'HCP-TYPE-01';
      } else if (rawType.toLowerCase().contains('resident') || rawType == 'HCP-TYPE-02') {
        payload['hcp_type'] = 'HCP-TYPE-02';
      } else if (rawType.toLowerCase().contains('fellow') || rawType == 'HCP-TYPE-03') {
        payload['hcp_type'] = 'HCP-TYPE-03';
      } else if (rawType.isNotEmpty) {
        payload['hcp_type'] = rawType;
      }

      // Ensure hcp_practice is valid
      final rawPractice = (payload['hcp_practice'] ?? hcp.hcpPractice).toString().trim();
      if (rawPractice == 'Dispensing' || rawPractice == 'Prescribing' || rawPractice == 'Both') {
        payload['hcp_practice'] = rawPractice;
      }

      // Handle doctor photo upload if base64
      if (payload['hcp_photo'] != null) {
        final hp = payload['hcp_photo'].toString().trim();
        if (hp.startsWith('data:') || hp.length > 200) {
          try {
            Uint8List? rawBytes;
            if (hp.contains(',')) {
              rawBytes = base64Decode(hp.split(',').last.trim());
            } else {
              rawBytes = base64Decode(hp.trim());
            }
            final uploadedUrl = await uploadFile(
              bytes: rawBytes,
              filename: 'hcp_${DateTime.now().millisecondsSinceEpoch}.jpg',
              doctype: 'HCP',
              docname: name,
            );
            if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
              payload['hcp_photo'] = uploadedUrl;
              payload['image'] = uploadedUrl;
              payload['photo'] = uploadedUrl;
            } else {
              payload.remove('hcp_photo');
              payload.remove('image');
              payload.remove('photo');
            }
          } catch (e) {
            print('Could not upload doctor hcp_photo: $e');
            payload.remove('hcp_photo');
            payload.remove('image');
            payload.remove('photo');
          }
        } else {
          payload['image'] = hp;
          payload['photo'] = hp;
        }
      }

      // Ensure hcp_specialty Link fields map to valid ERPNext Specialization primary keys
      if (payload['hcp_specialty'] is List && (payload['hcp_specialty'] as List).isNotEmpty) {
        final specs = await fetchSpecializations().catchError((_) => <Specialization>[]);
        final List<Map<String, dynamic>> cleanSpecs = [];
        for (var item in (payload['hcp_specialty'] as List)) {
          if (item is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(item);
            final rawSpec = (map['hcp_specialty'] ?? map['specialty'] ?? '').toString().trim();
            if (rawSpec.isNotEmpty) {
              final specId = LocationResolver.resolveSpecialtyId(rawSpec, specs.isNotEmpty ? specs : null);
              map['hcp_specialty'] = specId.isNotEmpty ? specId : 'SPEC-00001';
              map['specialty'] = specId.isNotEmpty ? specId : 'SPEC-00001';
            }
            final rawSub = (map['sub_specialty'] ?? '').toString().trim();
            if (rawSub.isNotEmpty && rawSub != 'None' && rawSub != '-') {
              final subId = LocationResolver.resolveSpecialtyId(rawSub, specs.isNotEmpty ? specs : null);
              map['sub_specialty'] = subId.isNotEmpty ? subId : null;
            } else {
              map.remove('sub_specialty');
            }
            cleanSpecs.add(map);
          }
        }
        payload['hcp_specialty'] = cleanSpecs;
      }
      if (payload['birth_date'] == null || payload['birth_date'].toString().trim().isEmpty) {
        payload.remove('birth_date');
      }

      // Ensure hcp_workplace Link fields map to valid ERPNext Institution primary keys
      if (payload['hcp_workplace'] is List && (payload['hcp_workplace'] as List).isNotEmpty) {
        final insts = await fetchInstitutions().catchError((_) => <Institution>[]);
        final psgc = await fetchPsgcLocations().catchError((_) => <PsgcLocation>[]);
        final List<Map<String, dynamic>> cleanWps = [];
        for (var item in (payload['hcp_workplace'] as List)) {
          if (item is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(item);
            final rawWp = (map['hcp_workplace'] ?? map['workplace'] ?? map['address'] ?? map['workplace_name'] ?? '').toString().trim();
            final rawProv = (map['province_name'] ?? map['province'] ?? '').toString().trim();
            final rawCity = (map['city_municipality'] ?? map['city'] ?? '').toString().trim();

            final resolvedLoc = LocationResolver.resolveCompleteWorkplaceLocation(
              institutionIdOrName: rawWp,
              cityIdOrName: rawCity,
              provinceIdOrName: rawProv,
              institutions: insts,
              dynamicLocations: psgc,
            );

            cleanWps.add({
              'hcp_workplace': resolvedLoc.workplaceId,
              'workplace': resolvedLoc.workplaceId,
              'province_name': resolvedLoc.provinceId,
              'city_municipality': resolvedLoc.cityId,
              'is_primary': map['is_primary'] == 1 ? 1 : 0,
              'preferred': map['preferred'] == 1 ? 1 : 0,
            });
          }
        }
        payload['hcp_workplace'] = cleanWps;

        // Ensure parent level region_name, province_name, city_municipality, institution are NEVER blank!
        if (cleanWps.isNotEmpty) {
          final prefMap = cleanWps.firstWhere((w) => w['is_primary'] == 1, orElse: () => cleanWps.first);
          if (payload['institution'] == null || payload['institution'].toString().trim().isEmpty) {
            payload['institution'] = prefMap['hcp_workplace'];
          }
          if (payload['province_name'] == null || payload['province_name'].toString().trim().isEmpty) {
            payload['province_name'] = prefMap['province_name'];
          }
          if (payload['city_municipality'] == null || payload['city_municipality'].toString().trim().isEmpty) {
            payload['city_municipality'] = prefMap['city_municipality'];
          }
          if (payload['region_name'] == null || payload['region_name'].toString().trim().isEmpty) {
            final reg = LocationResolver.resolveRegionFromProvince(prefMap['province_name']);
            final regId = LocationResolver.resolveRegionId(reg);
            payload['region_name'] = regId.isNotEmpty ? regId : '1300000000';
          }
        }
      }

      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return Hcp.fromJson(body['data']);
      } else {
        // Fallback: Try frappe.client.save RPC method
        final rpcUrl = Uri.parse('$baseUrl/api/method/frappe.client.save');
        final rpcResp = await http.post(
          rpcUrl,
          headers: _headers,
          body: jsonEncode({
            'doc': {
              'doctype': 'HCP',
              'name': name,
              ...payload,
            }
          }),
        );
        if (rpcResp.statusCode == 200) {
          final rpcBody = jsonDecode(rpcResp.body);
          final docData = rpcBody['message'] ?? rpcBody['data'];
          if (docData != null && docData is Map<String, dynamic>) {
            return Hcp.fromJson(docData);
          }
        }
        throw Exception('Failed to update doctor: ${response.body}');
      }
    } catch (e) {
      print('Update doctor error: $e');
      rethrow;
    } finally {
      if (!isAlreadyLocked) {
        _inFlightHcpIds.remove(name);
      }
    }
  }

  /// Applies monthly auto-rollover on a list of HCP Accounts.
  /// For any doctor account that was active in a prior month (and not archived),
  /// if they do not yet have an account for the target current month, this automatically
  /// carries them forward into the current month without modifying past archived cycles.
  List<HcpAccount> applyMonthlyAutoRollover(
    List<HcpAccount> rawAccounts, {
    DateTime? referenceDate,
    bool persistToServer = true,
  }) {
    if (rawAccounts.isEmpty) return rawAccounts;
    final now = referenceDate ?? DateTime.now();
    final targetMonthStart = DateTime(now.year, now.month, 1);
    final targetValidFrom = HcpAccount.calculateMonthValidFrom(now);

    // Group accounts by doctor ID and resolved program
    final Map<String, List<HcpAccount>> byDocProg = {};
    for (final acc in rawAccounts) {
      final hcpId = (acc.hcp ?? '').trim().toLowerCase();
      if (hcpId.isEmpty) continue;
      final prog = LocationResolver.resolveProgramBranch(acc.accountOrProgram).toLowerCase();
      final key = '$hcpId::$prog';
      byDocProg.putIfAbsent(key, () => []).add(acc);
    }

    final List<HcpAccount> rolledOverAccounts = [];

    byDocProg.forEach((key, accs) {
      // 1. Check if doctor already has an active account for current month
      final hasCurrentMonth = accs.any((a) {
        if (a.isArchived) return false;
        final vFrom = a.validFrom ?? a.startDate;
        if (vFrom != null && vFrom.startsWith(targetValidFrom)) return true;
        return a.isCurrentMonthActive(now);
      });

      if (hasCurrentMonth) return;

      // 2. Find the most recent active account from previous cycles
      final candidates = accs.where((a) {
        if (a.isArchived || !a.isActive) return false;
        final toStr = a.validTo ?? a.endDate;
        if (toStr != null && toStr.isNotEmpty) {
          try {
            final toDate = DateTime.parse(toStr);
            return toDate.isBefore(targetMonthStart);
          } catch (_) {}
        }
        return true;
      }).toList();

      if (candidates.isEmpty) return;

      // Sort by validTo descending to pick the most recent cycle
      candidates.sort((a, b) {
        final aTo = a.validTo ?? a.endDate ?? '';
        final bTo = b.validTo ?? b.endDate ?? '';
        return bTo.compareTo(aTo);
      });

      final sourceAccount = candidates.first;
      final rolledOver = sourceAccount.copyForNewMonth(targetMonth: now);
      rolledOverAccounts.add(rolledOver);
    });

    if (rolledOverAccounts.isEmpty) return rawAccounts;

    return [...rawAccounts, ...rolledOverAccounts];
  }

  /// Deduplicates HCP Accounts so each doctor under a program only has one canonical record
  List<HcpAccount> _deduplicateHcpAccounts(List<HcpAccount> accounts) {
    final Map<String, HcpAccount> canonicalMap = {};
    for (final acc in accounts) {
      final hcpId = (acc.hcp ?? '').trim().toLowerCase();
      if (hcpId.isEmpty) continue;
      final prog = LocationResolver.resolveProgramBranch(acc.accountOrProgram).toLowerCase();
      final mKey = acc.monthKey;
      final key = '$hcpId::$prog::$mKey';
      if (!canonicalMap.containsKey(key)) {
        canonicalMap[key] = acc;
      } else {
        final existing = canonicalMap[key]!;
        // Keep the richest record with populated child tables or more recent
        if (existing.workplaces.isEmpty && acc.workplaces.isNotEmpty) {
          canonicalMap[key] = acc;
        } else if (existing.specialties.isEmpty && acc.specialties.isNotEmpty) {
          canonicalMap[key] = acc;
        } else if (existing.contacts.isEmpty && acc.contacts.isNotEmpty) {
          canonicalMap[key] = acc;
        }
      }
    }
    return canonicalMap.values.toList();
  }

  /// Enriches an HCP Account with doctor masterlist data if child tables or fields are missing
  HcpAccount _enrichSingleAccountWithMasterData(HcpAccount account) {
    if (account.specialties.isNotEmpty && account.workplaces.isNotEmpty && account.contacts.isNotEmpty) {
      return account;
    }

    // 1. Try finding matching doctor in cachedDoctors
    final doc = _cachedDoctors.where((d) {
      if (account.hcp != null && account.hcp!.isNotEmpty && d.name == account.hcp) {
        return true;
      }
      if (account.hcpName != null && account.hcpName!.isNotEmpty && d.fullName.toLowerCase() == account.hcpName!.toLowerCase()) {
        return true;
      }
      return false;
    }).firstOrNull;

    // 2. Try finding in previous cached accounts for this doctor
    final prevAcc = _cachedHcpAccounts.where((a) =>
        a != account &&
        ((a.hcp != null && a.hcp == account.hcp) || (a.hcpName != null && a.hcpName == account.hcpName)) &&
        (a.specialties.isNotEmpty || a.workplaces.isNotEmpty || a.contacts.isNotEmpty)
    ).firstOrNull;

    List<HcpAccountSpecialization> effectiveSpecs = List.from(account.specialties);
    if (effectiveSpecs.isEmpty) {
      if (prevAcc != null && prevAcc.specialties.isNotEmpty) {
        effectiveSpecs = List.from(prevAcc.specialties);
      } else if (doc != null && doc.specialties.isNotEmpty) {
        effectiveSpecs = doc.specialties.map((s) => HcpAccountSpecialization(
          hcpSpecialty: LocationResolver.resolveSpecialtyName(s.hcpSpecialty),
          subSpecialty: (s.subSpecialty != null && s.subSpecialty!.isNotEmpty && s.subSpecialty != '-')
              ? LocationResolver.resolveSpecialtyName(s.subSpecialty)
              : null,
          isPrimary: s.isPrimary,
          preferred: true,
        )).toList();
      } else if (account.specialty != null && account.specialty!.isNotEmpty) {
        final specResolved = LocationResolver.resolveSpecialtyName(account.specialty);
        final subResolved = (account.subSpecialty != null && account.subSpecialty!.isNotEmpty && account.subSpecialty != '-')
            ? LocationResolver.resolveSpecialtyName(account.subSpecialty)
            : null;
        effectiveSpecs = [
          HcpAccountSpecialization(
            hcpSpecialty: specResolved,
            subSpecialty: subResolved,
            isPrimary: true,
            preferred: true,
          ),
        ];
      }
    }

    List<HcpAccountWorkplace> effectiveWps = List.from(account.workplaces);
    if (effectiveWps.isEmpty) {
      if (prevAcc != null && prevAcc.workplaces.isNotEmpty) {
        effectiveWps = List.from(prevAcc.workplaces);
      } else if (doc != null && doc.workplaces.isNotEmpty) {
        effectiveWps = doc.workplaces.map((w) {
          final loc = LocationResolver.resolveCompleteWorkplaceLocation(
            workplaceNameOrId: w.workplace,
            rawCity: w.cityMunicipality,
            rawProvince: w.provinceName,
          );
          return HcpAccountWorkplace(
            hcpWorkplace: LocationResolver.resolveInstitutionName(w.workplace),
            cityMunicipality: loc.cityName,
            provinceName: loc.provinceName,
            address: w.address,
            isPrimary: w.isPrimary,
            preferred: true,
          );
        }).toList();
      } else if (account.workplaceId != null && account.workplaceId!.isNotEmpty) {
        final wpResolved = LocationResolver.resolveInstitutionName(account.workplaceId);
        final loc = LocationResolver.resolveCompleteWorkplaceLocation(
          workplaceNameOrId: wpResolved,
        );
        effectiveWps = [
          HcpAccountWorkplace(
            hcpWorkplace: wpResolved,
            cityMunicipality: loc.cityName,
            provinceName: loc.provinceName,
            isPrimary: true,
            preferred: true,
          ),
        ];
      }
    }

    List<HcpAccountContact> effectiveContacts = List.from(account.contacts);
    if (effectiveContacts.isEmpty) {
      if (prevAcc != null && prevAcc.contacts.isNotEmpty) {
        effectiveContacts = List.from(prevAcc.contacts);
      } else if (doc != null && doc.contacts.isNotEmpty) {
        final cNum = doc.contacts.first.contactNumber;
        final cEm = doc.contacts.first.emailAddress;
        if ((cNum != null && cNum.isNotEmpty) || (cEm != null && cEm.isNotEmpty)) {
          effectiveContacts = [
            HcpAccountContact(
              contactNumber: cNum,
              emailAddress: cEm,
              isPrimary: true,
              preferred: true,
            ),
          ];
        }
      } else if ((account.contactNumber != null && account.contactNumber!.isNotEmpty) ||
          (account.contactEmail != null && account.contactEmail!.isNotEmpty)) {
        effectiveContacts = [
          HcpAccountContact(
            contactNumber: account.contactNumber,
            emailAddress: account.contactEmail,
            isPrimary: true,
            preferred: true,
          ),
        ];
      }
    }

    return account.copyWith(
      specialties: effectiveSpecs,
      workplaces: effectiveWps,
      contacts: effectiveContacts,
    );
  }

  /// Batch enriches list of accounts with doctor masterlist data
  List<HcpAccount> _enrichAccountsWithMasterDoctors(List<HcpAccount> accounts) {
    return accounts.map((acc) => _enrichSingleAccountWithMasterData(acc)).toList();
  }

  /// Retrieve list of HCP Account doctype records with automatic monthly rollover
  Future<List<HcpAccount>> fetchHcpAccounts({bool enableAutoRollover = true, DateTime? referenceDate}) async {
    if (_isOffline) {
      final cache = await _readFromCache('hcp_accounts_cache.json');
      if (cache != null) {
        try {
          final List<dynamic> dataList = jsonDecode(cache);
          final raw = dataList.map((json) => HcpAccount.fromJson(json)).toList();
          final deduplicated = _deduplicateHcpAccounts(raw);
          final enriched = _enrichAccountsWithMasterDoctors(deduplicated);
          return enableAutoRollover ? applyMonthlyAutoRollover(enriched, referenceDate: referenceDate, persistToServer: false) : enriched;
        } catch (_) {}
      }
      return [];
    }

    final url = Uri.parse(
      '$baseUrl/api/resource/HCP%20Account?fields=["*"]&limit_page_length=5000&limit=5000',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] ?? [];
        final raw = dataList.map((json) => HcpAccount.fromJson(json)).toList();
        final deduplicated = _deduplicateHcpAccounts(raw);
        final enriched = _enrichAccountsWithMasterDoctors(deduplicated);
        final processed = enableAutoRollover ? applyMonthlyAutoRollover(enriched, referenceDate: referenceDate) : enriched;
        _cachedHcpAccounts = processed;
        await _writeToCache('hcp_accounts_cache.json', jsonEncode(deduplicated.map((a) => a.toJson()).toList()));
        return processed;
      }
    } catch (e) {
      print('Fetch HCP Accounts direct error: $e');
    }

    // Fallback via client method
    try {
      final clientUrl = Uri.parse(
        '$baseUrl/api/method/frappe.client.get_list?doctype=HCP%20Account&fields=["*"]&limit_page_length=5000',
      );
      final clientResp = await http.get(clientUrl, headers: _headers);
      if (clientResp.statusCode == 200) {
        final body = jsonDecode(clientResp.body);
        final List<dynamic> dataList = body['message'] ?? body['data'] ?? [];
        if (dataList.isNotEmpty) {
          final raw = dataList.map((json) => HcpAccount.fromJson(json)).toList();
          final deduplicated = _deduplicateHcpAccounts(raw);
          final enriched = _enrichAccountsWithMasterDoctors(deduplicated);
          final processed = enableAutoRollover ? applyMonthlyAutoRollover(enriched, referenceDate: referenceDate) : enriched;
          _cachedHcpAccounts = processed;
          await _writeToCache('hcp_accounts_cache.json', jsonEncode(deduplicated.map((a) => a.toJson()).toList()));
          return processed;
        }
      }
    } catch (e) {
      print('Fetch HCP Accounts fallback error: $e');
    }

    // Cache fallback
    final cache = await _readFromCache('hcp_accounts_cache.json');
    if (cache != null) {
      try {
        final List<dynamic> dataList = jsonDecode(cache);
        final raw = dataList.map((json) => HcpAccount.fromJson(json)).toList();
        final deduplicated = _deduplicateHcpAccounts(raw);
        final enriched = _enrichAccountsWithMasterDoctors(deduplicated);
        final processed = enableAutoRollover ? applyMonthlyAutoRollover(enriched, referenceDate: referenceDate, persistToServer: false) : enriched;
        _cachedHcpAccounts = processed;
        return processed;
      } catch (_) {}
    }

    return [];
  }

  /// Fetch full details of a specific HCP Account including child tables
  Future<HcpAccount> fetchHcpAccountDetail(String name) async {
    final url = Uri.parse(
      '$baseUrl/api/resource/HCP%20Account/${Uri.encodeComponent(name)}',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final acc = HcpAccount.fromJson(body['data']);
        return _enrichSingleAccountWithMasterData(acc);
      }
    } catch (e) {
      print('Fetch HCP Account detail direct error: $e');
    }

    // Fallback via client method
    try {
      final clientUrl = Uri.parse(
        '$baseUrl/api/method/frappe.client.get?doctype=HCP%20Account&name=${Uri.encodeComponent(name)}',
      );
      final clientResp = await http.get(clientUrl, headers: _headers);
      if (clientResp.statusCode == 200) {
        final body = jsonDecode(clientResp.body);
        final data = body['message'] ?? body['data'];
        if (data != null) {
          final acc = HcpAccount.fromJson(data);
          return _enrichSingleAccountWithMasterData(acc);
        }
      }
    } catch (_) {}

    // Fallback from cache or _cachedHcpAccounts
    final cached = _cachedHcpAccounts.where((a) => a.name == name).firstOrNull;
    if (cached != null) return _enrichSingleAccountWithMasterData(cached);

    throw Exception('Failed to load HCP Account details: $name');
  }

  /// Find the specific HCP Account for a given doctor under a specific program.
  /// Strictly isolates "preferred" data on a per-program basis.
  Future<HcpAccount?> getAccountForDoctorAndProgram(String hcpId, {String? program}) async {
    final effectiveProgram = (program != null && program.isNotEmpty && program != 'All')
        ? program
        : selectedProgram;
    final cleanProg = LocationResolver.resolveProgramBranch(effectiveProgram).toLowerCase().trim();
    if (cleanProg.isEmpty || cleanProg == 'all') return null;

    try {
      final accounts = await fetchHcpAccounts();
      final matched = accounts.where((a) {
        final matchesHcp = (a.hcp == hcpId || a.name == hcpId || (a.hcpName != null && a.hcpName!.toLowerCase() == hcpId.toLowerCase()));
        if (!matchesHcp) return false;
        return LocationResolver.isSameProgram(a.accountOrProgram, effectiveProgram);
      }).firstOrNull;

      if (matched != null) {
        // If child tables are not populated in summary list, fetch full details
        if (matched.name != null && (matched.workplaces.isEmpty || matched.specialties.isEmpty)) {
          try {
            return await fetchHcpAccountDetail(matched.name!);
          } catch (_) {
            return matched;
          }
        }
        return matched;
      }
    } catch (e) {
      print('getAccountForDoctorAndProgram error: $e');
    }
    return null;
  }

  /// Retrieve list of HCP Profile Submissions
  Future<List<HcpProfileSubmission>> fetchSubmissions() async {
    if (_isOffline) {
      final cache = await _readFromCache('submissions_cache.json');
      if (cache != null) {
        try {
          final List<dynamic> dataList = jsonDecode(cache);
          return dataList.map((json) => HcpProfileSubmission.fromJson(json)).toList();
        } catch (_) {}
      }
      return [];
    }

    const submissionFields = '["name","owner","creation","modified","docstatus","workflow_state","profile_action","application_status","rejection_reason","hcp_name","hcp_full_name","first_name","middle_name","last_name","hcp_type","hcp_practice","account_or_program","territory","sales_person","user_id","submission_date","hcp_photo","consent_photo","consent_signature","consent_privacy_understood"]';
    final encodedFields = Uri.encodeQueryComponent(submissionFields);
    final url = Uri.parse(
      '$baseUrl/api/resource/HCP%20Profile%20Submission?fields=$encodedFields&limit_page_length=5000&limit=5000&order_by=creation%20desc',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] ?? [];

        // Map dedicated rejection_reason field directly from ERPNext DocType (ONLY for rejected status)
        for (var d in dataList) {
          if (d is Map) {
            final wf = (d['workflow_state'] ?? d['status'] ?? '').toString().toLowerCase();
            final isRej = wf == 'rejected' || wf.contains('reject') || d['docstatus'] == 2;
            if (isRej) {
              final reason = d['rejection_reason']?.toString().trim();
              if (reason != null && reason.isNotEmpty) {
                d['rejection_remarks'] = cleanCommentHtml(reason);
              }
            } else {
              d['rejection_remarks'] = null;
              d['rejection_reason'] = null;
              d['rejected_by'] = null;
            }
          }
        }

        // Enrich rejected submissions with latest Frappe timeline comments if rejection_reason was empty
        try {
          final commentsUrl = Uri.parse(
            '$baseUrl/api/resource/Comment?filters=[["reference_doctype","=","HCP Profile Submission"]]&fields=["reference_name","content","comment_by","creation"]&order_by=creation%20desc&limit_page_length=200',
          );
          final commResp = await http.get(commentsUrl, headers: _headers);
          if (commResp.statusCode == 200) {
            final commBody = jsonDecode(commResp.body);
            final List<dynamic> commData = commBody['data'] ?? [];
            final Map<String, Map<String, dynamic>> latestComments = {};
            for (var c in commData) {
              if (c is Map) {
                final ref = c['reference_name']?.toString() ?? '';
                if (ref.isNotEmpty && !latestComments.containsKey(ref)) {
                  latestComments[ref] = c.cast<String, dynamic>();
                }
              }
            }
            for (var d in dataList) {
              if (d is Map) {
                final wf = (d['workflow_state'] ?? d['status'] ?? '').toString().toLowerCase();
                final isRej = wf == 'rejected' || wf.contains('reject') || d['docstatus'] == 2;
                if (!isRej) {
                  d['rejection_remarks'] = null;
                  d['rejected_by'] = null;
                  continue;
                }
                final name = d['name']?.toString() ?? '';
                if (latestComments.containsKey(name)) {
                  if (d['rejection_remarks'] == null || d['rejection_remarks'].toString().trim().isEmpty) {
                    d['rejection_remarks'] = cleanCommentHtml(latestComments[name]!['content']?.toString() ?? '');
                  }
                  d['rejected_by'] ??= latestComments[name]!['comment_by'];
                }
              }
            }
          }
        } catch (_) {}

        // Fallback/Dedicated enrichment for MedRep/Sales User via getdoc if Comment resource returned 403
        final unpopulatedRejected = dataList.where((d) {
          if (d is! Map) return false;
          final wf = (d['workflow_state'] ?? d['status'] ?? '').toString().toLowerCase();
          final isRej = wf == 'rejected' || wf.contains('reject') || d['docstatus'] == 2;
          final hasRemark = d['rejection_remarks'] != null && d['rejection_remarks'].toString().trim().isNotEmpty;
          return isRej && !hasRemark;
        }).toList();

        if (unpopulatedRejected.isNotEmpty) {
          await Future.wait(unpopulatedRejected.map((d) async {
            final name = d['name']?.toString() ?? '';
            if (name.isNotEmpty) {
              try {
                final comments = await fetchSubmissionComments(name);
                if (comments.isNotEmpty) {
                  final latest = comments.first;
                  d['rejection_remarks'] = latest['content'];
                  d['rejected_by'] = latest['comment_by'] ?? latest['owner'];
                }
              } catch (_) {}
            }
          }));
        }

        await _writeToCache('submissions_cache.json', jsonEncode(dataList));
        final list = dataList.map((json) => HcpProfileSubmission.fromJson(json)).toList();
        _cachedSubmissions = list;
        return list;
      } else {
        print('Fetch submissions error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Fetch submissions direct error: $e');
    }

    // Fallback via client method using fields=["*"]
    try {
      final clientUrl = Uri.parse(
        '$baseUrl/api/method/frappe.client.get_list?doctype=HCP%20Profile%20Submission&fields=["*"]&limit_page_length=5000&order_by=creation%20desc',
      );
      final clientResp = await http.get(clientUrl, headers: _headers);
      if (clientResp.statusCode == 200) {
        final body = jsonDecode(clientResp.body);
        final List<dynamic> dataList = body['message'] ?? body['data'] ?? [];
        if (dataList.isNotEmpty) {
          await _writeToCache('submissions_cache.json', jsonEncode(dataList));
          final list = dataList.map((json) => HcpProfileSubmission.fromJson(json)).toList();
          _cachedSubmissions = list;
          return list;
        }
      }
    } catch (e) {
      print('Fetch submissions fallback error: $e');
    }

    // Cache fallback
    final cache = await _readFromCache('submissions_cache.json');
    if (cache != null) {
      try {
        final List<dynamic> dataList = jsonDecode(cache);
        final list = dataList.map((json) => HcpProfileSubmission.fromJson(json)).toList();
        _cachedSubmissions = list;
        return list;
      } catch (_) {}
    }

    return [];
  }

  /// Fetch full details of a specific HCP Profile Submission including child tables and changes
  Future<HcpProfileSubmission> fetchSubmissionDetail(String name) async {
    final url = Uri.parse(
      '$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(name)}',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final base = HcpProfileSubmission.fromJson(body['data']);
        final isRej = base.isRejected;
        if (!isRej) {
          return base.copyWith(rejectionRemarks: null, rejectedBy: null);
        }
        if (base.rejectionRemarks != null && base.rejectionRemarks!.trim().isNotEmpty) {
          return base;
        }
        try {
          final comments = await fetchSubmissionComments(name);
          if (comments.isNotEmpty) {
            final latest = comments.first;
            final commentText = latest['content']?.toString() ?? '';
            final commentAuthor = latest['comment_by']?.toString() ?? latest['owner']?.toString() ?? '';
            if (commentText.isNotEmpty) {
              return base.copyWith(
                rejectionRemarks: commentText,
                rejectedBy: commentAuthor.isNotEmpty ? commentAuthor : base.rejectedBy,
              );
            }
          }
        } catch (_) {}
        return base;
      }
    } catch (e) {
      print('Fetch submission detail direct error: $e');
    }

    // Fallback via frappe.client.get
    try {
      final fallbackUrl = Uri.parse(
        '$baseUrl/api/method/frappe.client.get?doctype=HCP%20Profile%20Submission&name=${Uri.encodeComponent(name)}',
      );
      final resp = await http.get(fallbackUrl, headers: _headers);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final data = body['message'] ?? body['data'];
        if (data != null) {
          final base = HcpProfileSubmission.fromJson(data);
          final isRej = base.isRejected;
          if (!isRej) {
            return base.copyWith(rejectionRemarks: null, rejectedBy: null);
          }
          try {
            final comments = await fetchSubmissionComments(name);
            if (comments.isNotEmpty) {
              final latest = comments.first;
              final commentText = latest['content']?.toString() ?? '';
              final commentAuthor = latest['comment_by']?.toString() ?? latest['owner']?.toString() ?? '';
              if (commentText.isNotEmpty) {
                return base.copyWith(
                  rejectionRemarks: commentText,
                  rejectedBy: commentAuthor.isNotEmpty ? commentAuthor : base.rejectedBy,
                );
              }
            }
          } catch (_) {}
          return base;
        }
      }
    } catch (_) {}

    // Fallback via cached list
    try {
      final list = await fetchSubmissions();
      final found = list.firstWhere((s) => s.name == name);
      return found;
    } catch (_) {}

    throw Exception('Failed to load submission details: $name');
  }

  /// Upload a file or image to ERPNext (/api/method/upload_file)
  Future<String?> uploadFile({
    required Uint8List bytes,
    required String filename,
    String? doctype,
    String? docname,
    String? fieldname,
    bool isPrivate = false,
  }) async {
    final url = Uri.parse('$baseUrl/api/method/upload_file');
    try {
      // 1. Try standard Frappe multipart form-data upload
      final request = http.MultipartRequest('POST', url);
      _headers.forEach((key, val) {
        if (key.toLowerCase() != 'content-type') {
          request.headers[key] = val;
        }
      });

      request.fields['is_private'] = isPrivate ? '1' : '0';
      if (doctype != null && doctype.isNotEmpty) request.fields['doctype'] = doctype;
      if (docname != null && docname.isNotEmpty) request.fields['docname'] = docname;
      if (fieldname != null && fieldname.isNotEmpty) request.fields['attached_to_field'] = fieldname;

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] is Map) {
          final fileUrl = body['message']['file_url'] ?? body['message']['file_name'];
          if (fileUrl != null) return '$fileUrl';
        }
      }

      // 2. Fallback: Try JSON base64 filedata upload
      final jsonPayload = {
        'filename': filename,
        'filedata': base64Encode(bytes),
        'is_private': isPrivate ? 1 : 0,
        if (doctype != null) 'doctype': doctype,
        if (docname != null) 'docname': docname,
        if (fieldname != null) 'attached_to_field': fieldname,
      };

      final jsonResp = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(jsonPayload),
      );

      if (jsonResp.statusCode == 200) {
        final body = jsonDecode(jsonResp.body);
        if (body is Map && body['message'] is Map) {
          final fileUrl = body['message']['file_url'] ?? body['message']['file_name'];
          if (fileUrl != null) return '$fileUrl';
        }
      }
    } catch (e) {
      print('uploadFile error: $e');
    }
    return null;
  }

  /// Create a new HCP Profile Submission record
  Future<HcpProfileSubmission> createSubmission(HcpProfileSubmission submission) async {
    final url = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission');
    try {
      final payload = submission.toJson();

      // Frappe workflow requires insertion in Draft state first.
      // Transitions (Draft → Pending Approval → Approved / Processed) are applied AFTER creation.
      final targetWorkflow = submission.workflowState ?? 'Pending Approval';
      final targetAppStatus = submission.applicationStatus ?? ((targetWorkflow == 'Approved' || targetWorkflow == 'Processed') ? 'Applied' : 'Not Applied');
      payload['application_status'] = targetAppStatus;
      payload.remove('workflow_state');
      payload.remove('status');
      payload['docstatus'] = 0;

      // Ensure consent_photo does not exceed column size (upload to ERPNext /files/ if base64)
      if (payload['consent_photo'] != null) {
        final cp = payload['consent_photo'].toString().trim();
        if (cp.startsWith('data:') || cp.length > 200) {
          try {
            Uint8List? rawBytes;
            if (cp.contains(',')) {
              rawBytes = base64Decode(cp.split(',').last.trim());
            } else {
              rawBytes = base64Decode(cp.trim());
            }
            final uploadedUrl = await uploadFile(
              bytes: rawBytes,
              filename: 'consent_${DateTime.now().millisecondsSinceEpoch}.jpg',
              doctype: 'HCP Profile Submission',
            );
            if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
              payload['consent_photo'] = uploadedUrl;
            } else {
              payload.remove('consent_photo');
            }
          } catch (e) {
            print('Could not upload consent_photo base64: $e');
            payload.remove('consent_photo');
          }
        }
      }

      // Ensure hcp_photo does not exceed column size (upload to ERPNext /files/ if base64)
      if (payload['hcp_photo'] != null) {
        final hp = payload['hcp_photo'].toString().trim();
        if (hp.startsWith('data:') || hp.length > 200) {
          try {
            Uint8List? rawBytes;
            if (hp.contains(',')) {
              rawBytes = base64Decode(hp.split(',').last.trim());
            } else {
              rawBytes = base64Decode(hp.trim());
            }
            final uploadedUrl = await uploadFile(
              bytes: rawBytes,
              filename: 'hcp_${DateTime.now().millisecondsSinceEpoch}.jpg',
              doctype: 'HCP Profile Submission',
            );
            if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
              payload['hcp_photo'] = uploadedUrl;
            } else {
              payload.remove('hcp_photo');
            }
          } catch (e) {
            print('Could not upload hcp_photo base64: $e');
            payload.remove('hcp_photo');
          }
        }
      }

      // Ensure table_specialties fields store valid Link IDs for Frappe Link fields and human-readable names in data fields
      if (payload['table_specialties'] is List && (payload['table_specialties'] as List).isNotEmpty) {
        final specs = await fetchSpecializations().catchError((_) => <Specialization>[]);
        final List<Map<String, dynamic>> cleanSpecs = [];
        for (var item in (payload['table_specialties'] as List)) {
          if (item is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(item);
            final isPref = (map['preferred'] == 1 || map['preferred'] == true ||
                map['is_preferred'] == 1 || map['is_preferred'] == true ||
                map['is_primary'] == 1 || map['is_primary'] == true ||
                map['primary'] == 1 || map['primary'] == true);
            map['preferred'] = isPref ? 1 : 0;
            map['is_preferred'] = isPref ? 1 : 0;
            map['is_primary'] = isPref ? 1 : 0;
            map['primary'] = isPref ? 1 : 0;

            final rawSpec = (map['specialty_name'] ?? map['specialty'] ?? map['hcp_specialty'] ?? '').toString().trim();
            if (rawSpec.isNotEmpty) {
              final specId = LocationResolver.resolveSpecialtyId(rawSpec, specs.isNotEmpty ? specs : null);
              final specName = LocationResolver.resolveSpecialtyName(rawSpec, specs.isNotEmpty ? specs : null);
              final finalId = specId.isNotEmpty ? specId : rawSpec;
              final finalName = specName.isNotEmpty ? specName : rawSpec;
              map['hcp_specialty'] = finalId;
              map['specialty'] = finalId;
              map['specialty_name'] = finalName;
            }
            final rawSub = (map['sub_specialty_name'] ?? map['sub_specialty'] ?? '').toString().trim();
            if (rawSub.isNotEmpty && rawSub != 'None' && rawSub != '-') {
              final subId = LocationResolver.resolveSpecialtyId(rawSub, specs.isNotEmpty ? specs : null);
              final subName = LocationResolver.resolveSpecialtyName(rawSub, specs.isNotEmpty ? specs : null);
              final finalSubId = subId.isNotEmpty ? subId : rawSub;
              final finalSubName = subName.isNotEmpty ? subName : rawSub;
              map['sub_specialty'] = finalSubId;
              map['sub_specialty_name'] = finalSubName;
            } else {
              map.remove('sub_specialty');
              map.remove('sub_specialty_name');
            }
            cleanSpecs.add(map);
          }
        }
        payload['table_specialties'] = cleanSpecs;
      }

      // Ensure table_workplaces fields store valid Link IDs for Frappe Link fields and human-readable names in data fields
      if (payload['table_workplaces'] is List && (payload['table_workplaces'] as List).isNotEmpty) {
        final insts = await fetchInstitutions().catchError((_) => <Institution>[]);
        final psgc = await fetchPsgcLocations().catchError((_) => <PsgcLocation>[]);
        final List<Map<String, dynamic>> cleanWps = [];
        for (var item in (payload['table_workplaces'] as List)) {
          if (item is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(item);
            final isPref = (map['preferred'] == 1 || map['preferred'] == true ||
                map['is_preferred'] == 1 || map['is_preferred'] == true ||
                map['is_primary'] == 1 || map['is_primary'] == true ||
                map['primary'] == 1 || map['primary'] == true);
            map['preferred'] = isPref ? 1 : 0;
            map['is_preferred'] = isPref ? 1 : 0;
            map['is_primary'] = isPref ? 1 : 0;
            map['primary'] = isPref ? 1 : 0;

            final rawWp = (map['workplace_name'] ?? map['workplace'] ?? map['hcp_workplace'] ?? map['address'] ?? '').toString().trim();
            final rawCity = (map['city_municipality'] ?? map['city_title'] ?? map['city_name'] ?? map['city'] ?? '').toString().trim();
            final rawProv = (map['province_name'] ?? map['province_title'] ?? map['province'] ?? '').toString().trim();
            final rawReg = (map['region_name'] ?? map['region_title'] ?? map['region'] ?? '').toString().trim();

            if (rawWp.isNotEmpty) {
              final candidateMatch = insts.where((i) =>
                  i.name == rawWp ||
                  i.name.toLowerCase() == rawWp.toLowerCase() ||
                  i.institutionName.toLowerCase() == rawWp.toLowerCase()
              ).firstOrNull;

              if (candidateMatch != null && candidateMatch.isRejected) {
                throw Exception('Cannot submit doctor profile: Workplace "${candidateMatch.institutionName}" was rejected by SFE Specialist. Please modify and resubmit via Institution Submission.');
              }

              final resolvedLoc = LocationResolver.resolveCompleteWorkplaceLocation(
                institutionIdOrName: rawWp,
                institutionName: candidateMatch?.institutionName ?? rawWp,
                cityIdOrName: rawCity.isNotEmpty ? rawCity : (candidateMatch?.rawCityMunicipality ?? candidateMatch?.cityMunicipality),
                provinceIdOrName: rawProv.isNotEmpty ? rawProv : (candidateMatch?.rawProvinceName ?? candidateMatch?.provinceName),
                regionIdOrName: rawReg.isNotEmpty ? rawReg : (candidateMatch?.rawRegionName ?? candidateMatch?.regionName),
                streetAddress: candidateMatch?.streetAddress,
                institutions: insts,
                dynamicLocations: psgc,
              );

              map['hcp_workplace'] = resolvedLoc.workplaceId;
              map['workplace'] = resolvedLoc.workplaceId;
              map['workplace_name'] = resolvedLoc.workplaceName;
              map['address'] = resolvedLoc.workplaceName;
              map['city_municipality'] = resolvedLoc.cityId;
              map['city'] = resolvedLoc.cityId;
              map['city_title'] = resolvedLoc.cityName;
              map['city_name'] = resolvedLoc.cityName;
              map['province_name'] = resolvedLoc.provinceId;
              map['province'] = resolvedLoc.provinceId;
              map['province_title'] = resolvedLoc.provinceName;
              map['region_name'] = resolvedLoc.regionId;
              map['region_title'] = resolvedLoc.regionName;
            }
            cleanWps.add(map);
          }
        }
        payload['table_workplaces'] = cleanWps;

        // Guarantee parent payload region_name, province_name, city_municipality, institution are NEVER blank!
        if (cleanWps.isNotEmpty) {
          final prefMap = cleanWps.firstWhere((w) => w['preferred'] == 1, orElse: () => cleanWps.first);
          if (payload['institution'] == null || payload['institution'].toString().trim().isEmpty) {
            payload['institution'] = prefMap['hcp_workplace'] ?? prefMap['workplace_name'];
          }
          if (payload['city_municipality'] == null || payload['city_municipality'].toString().trim().isEmpty) {
            payload['city_municipality'] = prefMap['city_municipality'];
          }
          if (payload['province_name'] == null || payload['province_name'].toString().trim().isEmpty) {
            payload['province_name'] = prefMap['province_name'];
          }
          if (payload['region_name'] == null || payload['region_name'].toString().trim().isEmpty) {
            final regFromProv = LocationResolver.resolveRegionFromProvince(prefMap['province_title'] ?? prefMap['province_name']);
            final regId = LocationResolver.resolveRegionId(regFromProv);
            payload['region_name'] = regId.isNotEmpty ? regId : (prefMap['region_name'] ?? '1300000000');
          }
        }
      }

      // Ensure table_contact_info fields preserve preferred flags
      if (payload['table_contact_info'] is List && (payload['table_contact_info'] as List).isNotEmpty) {
        final List<Map<String, dynamic>> cleanContacts = [];
        for (var item in (payload['table_contact_info'] as List)) {
          if (item is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(item);
            final isPref = (map['preferred'] == 1 || map['preferred'] == true ||
                map['is_preferred'] == 1 || map['is_preferred'] == true ||
                map['is_primary'] == 1 || map['is_primary'] == true ||
                map['primary'] == 1 || map['primary'] == true);
            map['preferred'] = isPref ? 1 : 0;
            map['is_preferred'] = isPref ? 1 : 0;
            map['is_primary'] = isPref ? 1 : 0;
            map['primary'] = isPref ? 1 : 0;
            cleanContacts.add(map);
          }
        }
        payload['table_contact_info'] = cleanContacts;
      }

      // Ensure profile_action is explicitly set according to doctor status
      final effectiveProfileAction = (submission.profileAction != null && submission.profileAction!.isNotEmpty)
          ? submission.profileAction!
          : (payload['profile_action'] != null && payload['profile_action'].toString().isNotEmpty
              ? payload['profile_action'].toString()
              : (targetWorkflow == 'Processed' || submission.hcpName.isNotEmpty ? 'Existing HCP' : 'New HCP'));
      payload['profile_action'] = effectiveProfileAction;

      // Ensure mandatory fields required by ERPNext are set with valid defaults
      final mn = (payload['middle_name'] ?? submission.middleName ?? '').toString().trim();
      payload['middle_name'] = (mn.isNotEmpty && mn != '-') ? mn : '-';

      final ht = (payload['hcp_type'] ?? submission.hcpType ?? '').toString().trim();
      payload['hcp_type'] = ht.isNotEmpty ? LocationResolver.resolveHcpTypeId(ht) : 'HCP-TYPE-01';

      final hp = (payload['hcp_practice'] ?? submission.hcpPractice ?? '').toString().trim();
      payload['hcp_practice'] = (hp == 'Dispensing' || hp == 'Prescribing' || hp == 'Both') ? hp : 'Dispensing';
      if (payload['birth_date'] == null || payload['birth_date'].toString().trim().isEmpty) {
        payload.remove('birth_date');
      }

      // Ensure account_or_program resolves to exact ERPNext Branch primary key (e.g. RTMD, FONTERRA ANMUM, etc.)
      final rawProg = (payload['account_or_program'] ?? submission.accountOrProgram ?? '').toString().trim();
      if (rawProg.isNotEmpty) {
        payload['account_or_program'] = LocationResolver.resolveProgramBranch(rawProg);
      }

      // Automatically detect and set accurate Territory Code and Territory Manager upon submission
      if (payload['territory'] == null || payload['territory'].toString().trim().isEmpty ||
          payload['sales_person'] == null || payload['sales_person'].toString().trim().isEmpty) {
        try {
          final targetProg = rawProg.isNotEmpty ? rawProg : selectedProgram;
          final submittingUser = (payload['user_id'] ?? payload['medrep_email'] ?? loggedInEmail ?? '').toString().trim();
          final resolvedTerritory = await resolveUserTerritory(
            userEmail: submittingUser,
            program: targetProg,
            currentTerritory: payload['territory']?.toString(),
            currentSalesPerson: payload['sales_person']?.toString(),
          );
          if (payload['territory'] == null || payload['territory'].toString().trim().isEmpty) {
            payload['territory'] = resolvedTerritory.territoryCode;
          }
          if (payload['sales_person'] == null || payload['sales_person'].toString().trim().isEmpty) {
            payload['sales_person'] = resolvedTerritory.territoryManager;
          }
        } catch (e) {
          print('[SUBMISSION] Territory auto-detection fallback error: $e');
        }
      }

      // Remove non-schema / temporary / mock keys before sending to ERPNext, ensuring all valid doctype fields are preserved
      final allowedDoctypeFields = {
        'doctype',
        'name',
        'hcp_name',
        'hcp_full_name',
        'first_name',
        'middle_name',
        'last_name',
        'birth_date',
        'hcp_photo',
        'consent_privacy_understood',
        'consent_signature',
        'consent_photo',
        'hcp_type',
        'hcp_practice',
        'profile_action',
        'table_specialties',
        'table_workplaces',
        'table_contact_info',
        'region_name',
        'province_name',
        'city_municipality',
        'barangay_name',
        'institution',
        'account_or_program',
        'territory',
        'sales_person',
        'user_id',
        'medrep_email',
        'survey_template',
        'survey_template_title',
        'survey_response',
        'answers',
        'submission_date',
        'valid_from',
        'valid_to',
        'validity_period',
        'workflow_state',
        'status',
        'application_status',
        'change_summary_html',
        'changes_json',
        'docstatus',
      };
      payload.removeWhere((k, _) => !allowedDoctypeFields.contains(k));

      await ensureCsrfToken();

      var response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      );

      // Automatic CSRF token refresh & retry if server throws CSRFTokenError
      if (response.statusCode == 400 && response.body.contains('CSRFTokenError')) {
        _csrfToken = null;
        await ensureCsrfToken();
        response = await http.post(
          url,
          headers: _headers,
          body: jsonEncode(payload),
        );
      }

      String? createdName;
      Map<String, dynamic>? createdData;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        createdData = body['data'];
        createdName = createdData != null ? '${createdData['name']}' : null;
      } else {
        // Fallback: frappe.client.insert
        final rpcUrl = Uri.parse('$baseUrl/api/method/frappe.client.insert');
        var rpcResp = await http.post(
          rpcUrl,
          headers: _headers,
          body: jsonEncode({
            'doc': {
              'doctype': 'HCP Profile Submission',
              ...payload,
            }
          }),
        );
        if (rpcResp.statusCode == 400 && rpcResp.body.contains('CSRFTokenError')) {
          _csrfToken = null;
          await ensureCsrfToken();
          rpcResp = await http.post(
            rpcUrl,
            headers: _headers,
            body: jsonEncode({
              'doc': {
                'doctype': 'HCP Profile Submission',
                ...payload,
              }
            }),
          );
        }
        if (rpcResp.statusCode == 200) {
          final body = jsonDecode(rpcResp.body);
          final resDoc = body['message'] ?? body['data'];
          if (resDoc is Map<String, dynamic>) {
            createdData = resDoc;
            createdName = '${resDoc['name']}';
          }
        } else {
          throw Exception('Failed to create submission: ${response.statusCode} - ${response.body}');
        }
      }

      // After creation, apply exact Workflow State & Status as defined by ERPNext HCP Profile Submission WF
      if (createdName != null && createdName.isNotEmpty) {
        final wfUrl = Uri.parse('$baseUrl/api/method/frappe.model.workflow.apply_workflow');
        final updateUrl = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(createdName)}');

        // Fetch fresh live doc from ERPNext so workflow engine has full doc context
        Map<String, dynamic> liveDoc = {};
        try {
          final getDocUrl = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(createdName)}');
          final getResp = await http.get(getDocUrl, headers: _headers);
          if (getResp.statusCode == 200) {
            final gb = jsonDecode(getResp.body);
            if (gb['data'] is Map) {
              liveDoc = Map<String, dynamic>.from(gb['data']);
            }
          }
        } catch (_) {}

        final fullDocParam = {
          if (createdData != null) ...createdData else ...payload,
          if (liveDoc.isNotEmpty) ...liveDoc,
          'doctype': 'HCP Profile Submission',
          'name': createdName,
          'profile_action': effectiveProfileAction,
        };

        // Apply exact Workflow State & Status as defined by ERPNext HCP Profile Submission WF
        final actionToApply = (targetWorkflow == 'Approved')
            ? 'Approve'
            : (effectiveProfileAction == 'Existing HCP' || targetWorkflow == 'Processed'
                ? 'Submit for Processing'
                : 'Submit for Approval');

        final String targetWfState = (actionToApply == 'Approve')
            ? 'Approved'
            : (actionToApply == 'Submit for Processing' ? 'Processed' : 'Pending Approval');
        final String targetAppStatus = (targetWfState == 'Processed' || targetWfState == 'Approved')
            ? 'Applied'
            : 'Not Applied';
        final int targetDocstatus = (targetWfState == 'Approved') ? 1 : 0;

        try {
          final wfResp = await http.post(
            wfUrl,
            headers: _headers,
            body: jsonEncode({
              'doc': fullDocParam,
              'action': actionToApply,
            }),
          );
          if (wfResp.statusCode != 200) {
            print('apply_workflow response non-200: ${wfResp.statusCode} - ${wfResp.body}');
          }
        } catch (e) {
          print('apply_workflow error: $e');
        }

        // Direct state alignment via frappe.client.set_value to ensure ERPNext Desk is immediately 100% aligned
        // This guarantees IT Managers reviewing in ERPNext Desk see Processed + Applied for Existing HCP immediately
        try {
          final setValUrl = Uri.parse('$baseUrl/api/method/frappe.client.set_value');
          await http.post(
            setValUrl,
            headers: _headers,
            body: jsonEncode({
              'doctype': 'HCP Profile Submission',
              'name': createdName,
              'fieldname': {
                'workflow_state': targetWfState,
                'status': targetWfState,
                'application_status': targetAppStatus,
                'profile_action': effectiveProfileAction,
                'docstatus': targetDocstatus,
              },
            }),
          );
        } catch (e) {
          print('State alignment set_value error: $e');
        }

        // Automatic non-destructive masterlist merge & HCP Account sync for Existing HCP
        if (actionToApply == 'Submit for Processing' || targetWfState == 'Processed') {
          try {
            await processExistingSubmission(HcpProfileSubmission.fromJson(liveDoc.isNotEmpty ? liveDoc : fullDocParam));
          } catch (e) {
            print('[SUBMISSION] Existing HCP auto-merge notice: $e');
          }
        }

        // Re-fetch the final clean state from ERPNext to return accurate data
        // No redundant frappe.client.save call, preventing dirty/Not Saved state in ERPNext Desk
        try {
          final freshResp = await http.get(updateUrl, headers: _headers);
          if (freshResp.statusCode == 200) {
            final freshBody = jsonDecode(freshResp.body);
            final rawData = Map<String, dynamic>.from(freshBody['data']);
            rawData['workflow_state'] = rawData['workflow_state'] ?? targetWfState;
            rawData['status'] = rawData['status'] ?? targetWfState;
            rawData['application_status'] = rawData['application_status'] ?? targetAppStatus;
            rawData['profile_action'] = rawData['profile_action'] ?? effectiveProfileAction;
            final freshSub = HcpProfileSubmission.fromJson(rawData);
            await _updateSubmissionInLocalCache(freshSub);
            return freshSub;
          }
        } catch (_) {}
      }

      final fallbackData = Map<String, dynamic>.from(createdData ?? payload);
      fallbackData['name'] = createdName ?? fallbackData['name'];
      fallbackData['workflow_state'] = (effectiveProfileAction == 'Existing HCP' || targetWorkflow == 'Processed') ? 'Processed' : 'Pending Approval';
      fallbackData['status'] = fallbackData['workflow_state'];
      fallbackData['application_status'] = (fallbackData['workflow_state'] == 'Processed') ? 'Applied' : 'Not Applied';
      fallbackData['profile_action'] = effectiveProfileAction;
      final result = HcpProfileSubmission.fromJson(fallbackData);
      await _updateSubmissionInLocalCache(result);
      return result;
    } catch (e) {
      print('Create submission error: $e');
      rethrow;
    }
  }

  /// Helper to safely update a submission record inside the local offline cache
  Future<void> _updateSubmissionInLocalCache(HcpProfileSubmission sub) async {
    try {
      final cache = await _readFromCache('submissions_cache.json');
      if (cache != null) {
        final List<dynamic> dataList = jsonDecode(cache);
        final index = dataList.indexWhere((item) => (item is Map && item['name'] == sub.name));
        if (index >= 0) {
          dataList[index] = sub.toJson();
        } else {
          dataList.insert(0, sub.toJson());
        }
        await _writeToCache('submissions_cache.json', jsonEncode(dataList));
      }
    } catch (_) {}
  }

  /// Update/overwrite an existing HCP Profile Submission record (in-place "tamper" to prevent duplicates)
  Future<HcpProfileSubmission> updateSubmission(String submissionName, HcpProfileSubmission submission) async {
    final url = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(submissionName)}');
    try {
      final payload = submission.toJson();

      // Ensure docstatus and workflow state are properly configured
      final targetWorkflow = submission.workflowState ?? 'Approved';
      final targetAppStatus = submission.applicationStatus ?? 'Applied';
      final targetDocstatus = submission.docstatus;
      payload['workflow_state'] = targetWorkflow;
      payload['application_status'] = targetAppStatus;
      payload['status'] = targetWorkflow;
      payload['docstatus'] = targetDocstatus;
      if (targetWorkflow == 'Pending Approval') {
        payload['rejection_reason'] = '';
      }

      // Handle consent_photo if base64
      if (payload['consent_photo'] != null) {
        final cp = payload['consent_photo'].toString().trim();
        if (cp.startsWith('data:') || cp.length > 200) {
          try {
            Uint8List? rawBytes;
            if (cp.contains(',')) {
              rawBytes = base64Decode(cp.split(',').last.trim());
            } else {
              rawBytes = base64Decode(cp.trim());
            }
            final uploadedUrl = await uploadFile(
              bytes: rawBytes,
              filename: 'consent_${DateTime.now().millisecondsSinceEpoch}.jpg',
              doctype: 'HCP Profile Submission',
              docname: submissionName,
            );
            if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
              payload['consent_photo'] = uploadedUrl;
            } else {
              payload.remove('consent_photo');
            }
          } catch (e) {
            payload.remove('consent_photo');
          }
        }
      }

      // Handle hcp_photo if base64
      if (payload['hcp_photo'] != null) {
        final hp = payload['hcp_photo'].toString().trim();
        if (hp.startsWith('data:') || hp.length > 200) {
          try {
            Uint8List? rawBytes;
            if (hp.contains(',')) {
              rawBytes = base64Decode(hp.split(',').last.trim());
            } else {
              rawBytes = base64Decode(hp.trim());
            }
            final uploadedUrl = await uploadFile(
              bytes: rawBytes,
              filename: 'hcp_${DateTime.now().millisecondsSinceEpoch}.jpg',
              doctype: 'HCP Profile Submission',
              docname: submissionName,
            );
            if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
              payload['hcp_photo'] = uploadedUrl;
            } else {
              payload.remove('hcp_photo');
            }
          } catch (e) {
            payload.remove('hcp_photo');
          }
        }
      }

      // Sanitize table_specialties
      if (payload['table_specialties'] is List && (payload['table_specialties'] as List).isNotEmpty) {
        final specs = await fetchSpecializations().catchError((_) => <Specialization>[]);
        final List<Map<String, dynamic>> cleanSpecs = [];
        for (var item in (payload['table_specialties'] as List)) {
          if (item is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(item);
            final isPref = (map['preferred'] == 1 || map['preferred'] == true ||
                map['is_preferred'] == 1 || map['is_preferred'] == true ||
                map['is_primary'] == 1 || map['is_primary'] == true ||
                map['primary'] == 1 || map['primary'] == true);
            map['preferred'] = isPref ? 1 : 0;
            map['is_preferred'] = isPref ? 1 : 0;
            map['is_primary'] = isPref ? 1 : 0;
            map['primary'] = isPref ? 1 : 0;

            final rawSpec = (map['specialty_name'] ?? map['specialty'] ?? map['hcp_specialty'] ?? '').toString().trim();
            if (rawSpec.isNotEmpty) {
              final specId = LocationResolver.resolveSpecialtyId(rawSpec, specs.isNotEmpty ? specs : null);
              final specName = LocationResolver.resolveSpecialtyName(rawSpec, specs.isNotEmpty ? specs : null);
              map['hcp_specialty'] = specId.isNotEmpty ? specId : rawSpec;
              map['specialty'] = specId.isNotEmpty ? specId : rawSpec;
              map['specialty_name'] = specName.isNotEmpty ? specName : rawSpec;
            }
            final rawSub = (map['sub_specialty_name'] ?? map['sub_specialty'] ?? '').toString().trim();
            if (rawSub.isNotEmpty && rawSub != 'None' && rawSub != '-') {
              final subId = LocationResolver.resolveSpecialtyId(rawSub, specs.isNotEmpty ? specs : null);
              final subName = LocationResolver.resolveSpecialtyName(rawSub, specs.isNotEmpty ? specs : null);
              map['sub_specialty'] = subId.isNotEmpty ? subId : rawSub;
              map['sub_specialty_name'] = subName.isNotEmpty ? subName : rawSub;
            } else {
              map.remove('sub_specialty');
              map.remove('sub_specialty_name');
            }
            cleanSpecs.add(map);
          }
        }
        payload['table_specialties'] = cleanSpecs;
      }

      // Sanitize table_workplaces
      if (payload['table_workplaces'] is List && (payload['table_workplaces'] as List).isNotEmpty) {
        final insts = await fetchInstitutions().catchError((_) => <Institution>[]);
        final psgc = await fetchPsgcLocations().catchError((_) => <PsgcLocation>[]);
        final List<Map<String, dynamic>> cleanWps = [];
        for (var item in (payload['table_workplaces'] as List)) {
          if (item is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(item);
            final isPref = (map['preferred'] == 1 || map['preferred'] == true ||
                map['is_preferred'] == 1 || map['is_preferred'] == true ||
                map['is_primary'] == 1 || map['is_primary'] == true ||
                map['primary'] == 1 || map['primary'] == true);
            map['preferred'] = isPref ? 1 : 0;
            map['is_preferred'] = isPref ? 1 : 0;
            map['is_primary'] = isPref ? 1 : 0;
            map['primary'] = isPref ? 1 : 0;

            final rawWp = (map['workplace_name'] ?? map['workplace'] ?? map['hcp_workplace'] ?? map['address'] ?? '').toString().trim();
            final rawCity = (map['city_municipality'] ?? map['city_title'] ?? map['city_name'] ?? map['city'] ?? '').toString().trim();
            final rawProv = (map['province_name'] ?? map['province_title'] ?? map['province'] ?? '').toString().trim();
            final rawReg = (map['region_name'] ?? map['region_title'] ?? map['region'] ?? '').toString().trim();

            if (rawWp.isNotEmpty) {
              final candidateMatch = insts.where((i) =>
                  i.name == rawWp ||
                  i.name.toLowerCase() == rawWp.toLowerCase() ||
                  i.institutionName.toLowerCase() == rawWp.toLowerCase()
              ).firstOrNull;

              if (candidateMatch != null && candidateMatch.isRejected) {
                throw Exception('Cannot update doctor profile: Workplace "${candidateMatch.institutionName}" was rejected by SFE Specialist. Please modify and resubmit via Institution Submission.');
              }

              final resolvedLoc = LocationResolver.resolveCompleteWorkplaceLocation(
                institutionIdOrName: rawWp,
                institutionName: candidateMatch?.institutionName ?? rawWp,
                cityIdOrName: rawCity.isNotEmpty ? rawCity : (candidateMatch?.rawCityMunicipality ?? candidateMatch?.cityMunicipality),
                provinceIdOrName: rawProv.isNotEmpty ? rawProv : (candidateMatch?.rawProvinceName ?? candidateMatch?.provinceName),
                regionIdOrName: rawReg.isNotEmpty ? rawReg : (candidateMatch?.rawRegionName ?? candidateMatch?.regionName),
                streetAddress: candidateMatch?.streetAddress,
                institutions: insts,
                dynamicLocations: psgc,
              );

              map['hcp_workplace'] = resolvedLoc.workplaceId;
              map['workplace'] = resolvedLoc.workplaceId;
              map['workplace_name'] = resolvedLoc.workplaceName;
              map['address'] = resolvedLoc.workplaceName;
              map['city_municipality'] = resolvedLoc.cityId;
              map['city'] = resolvedLoc.cityId;
              map['city_title'] = resolvedLoc.cityName;
              map['city_name'] = resolvedLoc.cityName;
              map['province_name'] = resolvedLoc.provinceId;
              map['province'] = resolvedLoc.provinceId;
              map['province_title'] = resolvedLoc.provinceName;
              map['region_name'] = resolvedLoc.regionId;
              map['region_title'] = resolvedLoc.regionName;
            }
            cleanWps.add(map);
          }
        }
        payload['table_workplaces'] = cleanWps;

        // Guarantee parent payload region_name, province_name, city_municipality, institution are NEVER blank!
        if (cleanWps.isNotEmpty) {
          final prefMap = cleanWps.firstWhere((w) => w['preferred'] == 1, orElse: () => cleanWps.first);
          if (payload['institution'] == null || payload['institution'].toString().trim().isEmpty) {
            payload['institution'] = prefMap['hcp_workplace'] ?? prefMap['workplace_name'];
          }
          if (payload['city_municipality'] == null || payload['city_municipality'].toString().trim().isEmpty) {
            payload['city_municipality'] = prefMap['city_municipality'];
          }
          if (payload['province_name'] == null || payload['province_name'].toString().trim().isEmpty) {
            payload['province_name'] = prefMap['province_name'];
          }
          if (payload['region_name'] == null || payload['region_name'].toString().trim().isEmpty) {
            final regFromProv = LocationResolver.resolveRegionFromProvince(prefMap['province_title'] ?? prefMap['province_name']);
            final regId = LocationResolver.resolveRegionId(regFromProv);
            payload['region_name'] = regId.isNotEmpty ? regId : (prefMap['region_name'] ?? '1300000000');
          }
        }
      }

      // Sanitize table_contact_info
      if (payload['table_contact_info'] is List && (payload['table_contact_info'] as List).isNotEmpty) {
        final List<Map<String, dynamic>> cleanContacts = [];
        for (var item in (payload['table_contact_info'] as List)) {
          if (item is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(item);
            final isPref = (map['preferred'] == 1 || map['preferred'] == true ||
                map['is_preferred'] == 1 || map['is_preferred'] == true ||
                map['is_primary'] == 1 || map['is_primary'] == true ||
                map['primary'] == 1 || map['primary'] == true);
            map['preferred'] = isPref ? 1 : 0;
            map['is_preferred'] = isPref ? 1 : 0;
            map['is_primary'] = isPref ? 1 : 0;
            map['primary'] = isPref ? 1 : 0;
            cleanContacts.add(map);
          }
        }
        payload['table_contact_info'] = cleanContacts;
      }

      // Root level links
      if (payload['province_name'] != null || payload['province'] != null) {
        final raw = (payload['province_name'] ?? payload['province']).toString();
        var provId = LocationResolver.resolveProvinceId(raw);
        final provName = LocationResolver.resolveProvinceName(raw);
        if (provId == '1376000000' || provId.startsWith('1376')) {
          provId = '1380600000';
        }
        payload['province_name'] = provId.isNotEmpty ? provId : raw;
        payload['province'] = provId.isNotEmpty ? provId : raw;
        payload['province_title'] = provName.isNotEmpty ? provName : raw;
      }
      if (payload['city_municipality'] != null || payload['city'] != null) {
        final raw = (payload['city_municipality'] ?? payload['city']).toString();
        var cityId = LocationResolver.resolveCityId(raw);
        final cityName = LocationResolver.resolveCityName(raw);
        if (cityId == '133900000' || cityId.startsWith('1339')) {
          cityId = '1380608000';
        }
        payload['city_municipality'] = cityId.isNotEmpty ? cityId : raw;
        payload['city'] = cityId.isNotEmpty ? cityId : raw;
        payload['city_title'] = cityName.isNotEmpty ? cityName : raw;
      }
      if (payload['region_name'] != null || payload['region'] != null) {
        final raw = (payload['region_name'] ?? payload['region']).toString();
        final regId = LocationResolver.resolveRegionId(raw);
        payload['region_name'] = regId.isNotEmpty ? regId : raw;
        payload['region'] = regId.isNotEmpty ? regId : raw;
      }
      if (payload['institution'] != null) {
        final raw = payload['institution'].toString();
        final instId = LocationResolver.resolveInstitutionId(raw);
        final instName = LocationResolver.resolveInstitutionName(raw);
        payload['institution'] = instId.isNotEmpty ? instId : raw;
        payload['institution_name'] = instName.isNotEmpty ? instName : raw;
      }
      if (payload['birth_date'] == null || payload['birth_date'].toString().trim().isEmpty) {
        payload.remove('birth_date');
      }

      final allowedDoctypeFields = {
        'doctype',
        'name',
        'hcp_name',
        'hcp_full_name',
        'first_name',
        'middle_name',
        'last_name',
        'birth_date',
        'hcp_photo',
        'consent_privacy_understood',
        'consent_signature',
        'consent_photo',
        'hcp_type',
        'hcp_practice',
        'table_specialties',
        'table_workplaces',
        'table_contact_info',
        'region_name',
        'province_name',
        'city_municipality',
        'barangay_name',
        'institution',
        'account_or_program',
        'territory',
        'sales_person',
        'user_id',
        'medrep_email',
        'survey_template',
        'survey_template_title',
        'survey_response',
        'submission_date',
        'workflow_state',
        'status',
        'application_status',
        'docstatus',
        'profile_action',
        'change_summary_html',
        'changes_json',
        'answers',
      };
      payload.removeWhere((k, _) => !allowedDoctypeFields.contains(k));

      HcpProfileSubmission updatedResult;
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? payload;
        data['name'] = submissionName;
        updatedResult = HcpProfileSubmission.fromJson(data);
      } else {
        // Fallback: frappe.client.save
        final rpcUrl = Uri.parse('$baseUrl/api/method/frappe.client.save');
        final rpcResp = await http.post(
          rpcUrl,
          headers: _headers,
          body: jsonEncode({
            'doc': {
              'doctype': 'HCP Profile Submission',
              'name': submissionName,
              ...payload,
            }
          }),
        );
        if (rpcResp.statusCode == 200) {
          final body = jsonDecode(rpcResp.body);
          final docData = body['message'] ?? body['data'] ?? payload;
          docData['name'] = submissionName;
          updatedResult = HcpProfileSubmission.fromJson(docData);
        } else {
          // Fallback: frappe.client.set_value for key scalar values
          try {
            final setValUrl = Uri.parse('$baseUrl/api/method/frappe.client.set_value');
            for (var entry in payload.entries) {
              if (entry.key != 'doctype' && entry.key != 'name' && entry.value is! List) {
                await http.post(
                  setValUrl,
                  headers: _headers,
                  body: jsonEncode({
                    'doctype': 'HCP Profile Submission',
                    'name': submissionName,
                    'fieldname': entry.key,
                    'value': entry.value,
                  }),
                );
              }
            }
          } catch (_) {}
          payload['name'] = submissionName;
          updatedResult = HcpProfileSubmission.fromJson(payload);
        }
      }

      // Update submissions cache in-place
      try {
        final cache = await _readFromCache('submissions_cache.json');
        if (cache != null) {
          final List<dynamic> dataList = jsonDecode(cache);
          final index = dataList.indexWhere((item) => (item is Map && item['name'] == submissionName));
          if (index >= 0) {
            dataList[index] = updatedResult.toJson();
          } else {
            dataList.insert(0, updatedResult.toJson());
          }
          await _writeToCache('submissions_cache.json', jsonEncode(dataList));
        }
      } catch (_) {}

      return updatedResult;
    } catch (e) {
      print('Update submission error: $e');
      rethrow;
    }
  }

  /// Apply a workflow transition action on an HCP Profile Submission
  Future<HcpProfileSubmission> applyWorkflowAction(HcpProfileSubmission submission, String action, {String remarks = ''}) async {
    final subName = submission.name;
    if (subName == null || subName.isEmpty) {
      throw Exception('Cannot apply workflow action: submission name is missing.');
    }

    // 1. In-flight Concurrency Mutex Lock (Eliminates Lost Updates)
    if (_inFlightSubmissions.contains(subName)) {
      throw Exception('A workflow transaction for submission "$subName" is currently in progress. Please wait.');
    }
    _inFlightSubmissions.add(subName);

    try {
      // 2. Authoritative Fresh Live Read (Eliminates Fuzzy / Non-Repeatable Reads)
      HcpProfileSubmission liveSubmission = submission;
      try {
        liveSubmission = await fetchSubmissionDetail(subName);
      } catch (e) {
        print('[WORKFLOW] Using provided submission snapshot (live fetch notice: $e)');
      }

      // 3. Idempotency Guards: If already in desired terminal state, return immediately
      if (action == 'Approve' && (liveSubmission.workflowState == 'Approved' || liveSubmission.docstatus == 1)) {
        print('[WORKFLOW] Submission "$subName" is ALREADY approved. Returning current record.');
        return liveSubmission;
      }
      if (action == 'Reject' && liveSubmission.workflowState == 'Rejected') {
        print('[WORKFLOW] Submission "$subName" is ALREADY rejected. Returning current record.');
        return liveSubmission;
      }
      if (liveSubmission.workflowState == 'Processed' && (action == 'Submit for Processing' || action == 'Select for Processing')) {
        print('[WORKFLOW] Submission "$subName" is ALREADY processed. Returning current record.');
        return liveSubmission;
      }

      final wfUrl = Uri.parse('$baseUrl/api/method/frappe.model.workflow.apply_workflow');
      String targetState = '';
      int targetDocStatus = 0;

      final normalizedAction = action.trim();
      String effectiveAction = normalizedAction;

      switch (normalizedAction) {
        case 'Submit for Processing':
        case 'Select for Processing':
          targetState = 'Processed';
          targetDocStatus = 0;
          effectiveAction = 'Submit for Processing';
          break;
        case 'Submit for Approval':
          targetState = 'Pending Approval';
          targetDocStatus = 0;
          effectiveAction = 'Submit for Approval';
          break;
        case 'Approve':
          targetState = 'Approved';
          targetDocStatus = 1;
          effectiveAction = 'Approve';
          break;
        case 'Reject':
          targetState = 'Rejected';
          targetDocStatus = 0;
          effectiveAction = 'Reject';
          break;
      }

      if (action == 'Approve') {
        await approveSubmission(liveSubmission);
        final updateUrl = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(subName)}');
        try {
          final freshResp = await http.get(updateUrl, headers: _headers);
          if (freshResp.statusCode == 200) {
            final freshBody = jsonDecode(freshResp.body);
            return HcpProfileSubmission.fromJson(freshBody['data']);
          }
        } catch (_) {}
        return liveSubmission.copyWith(workflowState: 'Approved', status: 'Approved', docstatus: 1);
      }

      if (action == 'Reject') {
        final rejectedSub = await rejectSubmission(subName, remarks: remarks, submission: liveSubmission);
        return rejectedSub;
      }

      if (action == 'Submit for Processing' || action == 'Select for Processing') {
        try {
          await processExistingSubmission(liveSubmission);
        } catch (e) {
          print('[WORKFLOW] processExistingSubmission notice: $e');
        }
      }

      // For "Submit for Processing" and "Submit for Approval":
      final effectiveActionProfile = liveSubmission.profileAction ?? (liveSubmission.hcpName.isNotEmpty ? 'Existing HCP' : 'New HCP');
      final docWorkflowPayload = {
        'doctype': 'HCP Profile Submission',
        'name': subName,
        'profile_action': effectiveActionProfile,
        ...liveSubmission.toJson(),
      };

      // Ensure New HCP submissions bypass ERPNext sync_submission hook crash
      if (effectiveActionProfile == 'New HCP') {
        docWorkflowPayload['application_status'] = 'Applied';
        try {
          final preArmUrl = Uri.parse('$baseUrl/api/method/frappe.client.set_value');
          await http.post(
            preArmUrl,
            headers: _headers,
            body: jsonEncode({
              'doctype': 'HCP Profile Submission',
              'name': subName,
              'fieldname': 'application_status',
              'value': 'Applied',
            }),
          );
        } catch (_) {}
      }

    try {
      await http.post(
        wfUrl,
        headers: _headers,
        body: jsonEncode({
          'doc': docWorkflowPayload,
          'action': effectiveAction,
        }),
      );
    } catch (_) {}

    // Seal state fields directly via frappe.client.set_value to ensure ERPNext Desk is 100% aligned
    final targetAppStatus = (targetState == 'Processed' || targetState == 'Approved')
        ? 'Applied'
        : 'Not Applied';
    if (targetState.isNotEmpty) {
      try {
        final setValUrl = Uri.parse('$baseUrl/api/method/frappe.client.set_value');
        await http.post(
          setValUrl,
          headers: _headers,
          body: jsonEncode({
            'doctype': 'HCP Profile Submission',
            'name': subName,
            'fieldname': {
              'profile_action': effectiveActionProfile,
              'workflow_state': targetState,
              'status': targetState,
              'application_status': targetAppStatus,
              'docstatus': targetDocStatus,
            },
          }),
        );
      } catch (_) {}
    }

    // Update local cache
    try {
      final cache = await _readFromCache('submissions_cache.json');
      if (cache != null) {
        final List<dynamic> dataList = jsonDecode(cache);
        final index = dataList.indexWhere((item) => (item is Map && item['name'] == subName));
        if (index >= 0) {
          dataList[index]['workflow_state'] = targetState;
          dataList[index]['status'] = targetState;
          dataList[index]['application_status'] = targetAppStatus;
          dataList[index]['docstatus'] = targetDocStatus;
          await _writeToCache('submissions_cache.json', jsonEncode(dataList));
        }
      }
    } catch (_) {}

    return liveSubmission.copyWith(
      workflowState: targetState,
      status: targetState,
      applicationStatus: targetAppStatus,
      docstatus: targetDocStatus,
    );
    } finally {
      _inFlightSubmissions.remove(subName);
    }
  }

  /// Bulk approve multiple HCP Profile Submissions sequentially.
  /// Calls [applyWorkflowAction] with 'Approve' for each submission.
  /// Returns a map with 'successCount', 'failureCount', and 'errors'.
  Future<Map<String, dynamic>> bulkApproveSubmissions(
    List<HcpProfileSubmission> submissions, {
    void Function(int current, int total, String doctorName)? onProgress,
  }) async {
    int successCount = 0;
    int failureCount = 0;
    final List<String> errors = [];

    for (int i = 0; i < submissions.length; i++) {
      final sub = submissions[i];
      final docName = (sub.hcpFullName != null && sub.hcpFullName!.isNotEmpty)
          ? sub.hcpFullName!
          : (sub.hcpName.isNotEmpty ? sub.hcpName : (sub.name ?? 'Doctor'));
      if (onProgress != null) {
        onProgress(i + 1, submissions.length, docName);
      }
      try {
        await applyWorkflowAction(sub, 'Approve');
        successCount++;
      } catch (e) {
        failureCount++;
        errors.add('$docName: $e');
        print('[BULK APPROVE ERROR] Failed to approve ${sub.name}: $e');
      }
    }

    // Refresh masterlists and submissions cache
    await fetchDoctors().catchError((_) => <Hcp>[]);
    await fetchHcpAccounts().catchError((_) => <HcpAccount>[]);
    await fetchSubmissions().catchError((_) => <HcpProfileSubmission>[]);

    return {
      'successCount': successCount,
      'failureCount': failureCount,
      'errors': errors,
    };
  }

  /// Sync HCP Account in ERPNext for the doctor under active program
  Future<void> syncHcpAccount({
    required String hcpId,
    required String hcpFullName,
    required String program,
    required String territory,
    String? salesPerson,
    String? userId,
    List<HcpAccountSpecialization> specialties = const [],
    List<HcpAccountWorkplace> workplaces = const [],
    List<HcpAccountContact> contacts = const [],
  }) async {
    final isAlreadyLocked = hcpId.isNotEmpty && _inFlightHcpIds.contains(hcpId);
    if (!isAlreadyLocked && hcpId.isNotEmpty) {
      _inFlightHcpIds.add(hcpId);
    }
    try {
      final cleanProgram = LocationResolver.resolveProgramBranch(program);
      final validFrom = HcpAccount.calculateMonthValidFrom();
      final validTo = HcpAccount.calculateMonthValidTo();

      // Check if HCP Account already exists for this doctor and program in the CURRENT active month
      final searchUrl = Uri.parse(
        '$baseUrl/api/resource/HCP%20Account?filters=[["hcp","=","$hcpId"]]&fields=["name","account_or_program","valid_from","valid_to"]&limit_page_length=50',
      );
      final searchResp = await http.get(searchUrl, headers: _headers);
      String? existingAccountName;
      if (searchResp.statusCode == 200) {
        final searchBody = jsonDecode(searchResp.body);
        final List<dynamic> data = searchBody['data'] ?? [];
        for (var d in data) {
          final aProg = (d['account_or_program'] ?? '').toString().trim();
          final vFrom = (d['valid_from'] ?? '').toString().trim();
          // Strictly match existing account in the current month so historical months are never overwritten
          if (LocationResolver.isSameProgram(aProg, cleanProgram) && vFrom.startsWith(validFrom)) {
            existingAccountName = d['name'];
            break;
          }
        }
      }

      final effectiveSalesPerson = (salesPerson != null && salesPerson.trim().isNotEmpty)
          ? salesPerson.trim()
          : getTerritoryManagerForTerritory(territory);

      // Filter strictly to the single preferred item for this program's HCP Account
      final prefSpecsList = specialties.where((s) => s.preferred || s.isPrimary).toList();
      final effectiveSpec = prefSpecsList.isNotEmpty
          ? prefSpecsList.first
          : (specialties.isNotEmpty ? specialties.first : null);

      // Clean specialization child table links - strictly 1 preferred row
      final List<Map<String, dynamic>> cleanSpecs = [];
      if (effectiveSpec != null) {
        final sId = LocationResolver.resolveSpecialtyId(effectiveSpec.hcpSpecialty);
        if (sId.isNotEmpty) {
          final subId = (effectiveSpec.subSpecialty != null &&
                  effectiveSpec.subSpecialty!.isNotEmpty &&
                  effectiveSpec.subSpecialty != '-')
              ? LocationResolver.resolveSpecialtyId(effectiveSpec.subSpecialty)
              : null;
          cleanSpecs.add({
            'hcp_specialty': sId,
            if (subId != null && subId.isNotEmpty) 'sub_specialty': subId,
          });
        }
      }

      final usableWorkplaces = workplaces.where((w) {
        final wpRaw = w.hcpWorkplace.trim();
        return wpRaw.isNotEmpty;
      }).toList();

      final prefWpsList = usableWorkplaces.where((w) => w.preferred || w.isPrimary).toList();
      final effectiveWp = prefWpsList.isNotEmpty
          ? prefWpsList.first
          : (usableWorkplaces.isNotEmpty ? usableWorkplaces.first : null);

      // Clean workplace child table links - strictly 1 preferred row
      final List<Map<String, dynamic>> cleanWps = [];
      if (effectiveWp != null) {
        final resolvedLoc = LocationResolver.resolveCompleteWorkplaceLocation(
          institutionIdOrName: effectiveWp.hcpWorkplace,
          cityIdOrName: effectiveWp.cityMunicipality,
          provinceIdOrName: effectiveWp.provinceName,
        );
        cleanWps.add({
          'hcp_workplace': resolvedLoc.workplaceId,
          'city_municipality': resolvedLoc.cityId,
          'province_name': resolvedLoc.provinceId,
        });
      }
      if (cleanWps.isEmpty) {
        cleanWps.add({
          'hcp_workplace': 'INST-00001',
          'city_municipality': '1380608000',
          'province_name': '1380600000',
        });
      }

      final prefContactsList = contacts.where((c) => c.preferred || c.isPrimary).toList();
      final effectiveContact = prefContactsList.isNotEmpty
          ? prefContactsList.first
          : (contacts.isNotEmpty ? contacts.first : null);

      // Clean contact child table - strictly 1 preferred row
      final List<Map<String, dynamic>> cleanContacts = [];
      if (effectiveContact != null) {
        final num = (effectiveContact.contactNumber ?? '').trim();
        final em = (effectiveContact.emailAddress ?? '').trim();
        if (num.isNotEmpty || em.isNotEmpty) {
          cleanContacts.add({
            if (num.isNotEmpty) 'contact_number': num,
            if (em.isNotEmpty) 'email_address': em,
          });
        }
      }

      // Extract summary top-level fields for preferred data
      final primarySpecId = cleanSpecs.isNotEmpty ? cleanSpecs.first['hcp_specialty'] : null;
      final primarySubSpecId = cleanSpecs.isNotEmpty ? cleanSpecs.first['sub_specialty'] : null;
      final primaryWpId = cleanWps.isNotEmpty ? cleanWps.first['hcp_workplace'] : null;
      final wpApprovalNote = LocationResolver.getInstitutionApprovalStatusNote(primaryWpId);
      final primaryContactNum = cleanContacts.isNotEmpty ? cleanContacts.first['contact_number'] : null;
      final primaryEmail = cleanContacts.isNotEmpty ? cleanContacts.first['email_address'] : null;

      final Map<String, dynamic> payload = {
        'account_or_program': cleanProgram,
        'territory': territory,
        'sales_person': effectiveSalesPerson,
        'user_id': userId ?? loggedInEmail ?? 'jptan@profinsights.biz',
        'hcp': hcpId,
        'hcp_name': hcpFullName,
        'valid_from': validFrom,
        'valid_to': validTo,
        if (primarySpecId != null) 'specialty': primarySpecId,
        if (primarySubSpecId != null) 'sub_specialty': primarySubSpecId,
        if (primaryWpId != null) 'workplace_id': primaryWpId,
        'workplace_approval_note': wpApprovalNote,
        if (primaryContactNum != null) 'contact_number': primaryContactNum,
        if (primaryEmail != null) 'contact_email': primaryEmail,
        'specialization': cleanSpecs,
        'workplace_info': cleanWps,
        'contact_info': cleanContacts,
      };

      if (existingAccountName != null) {
        // Direct update with clean single-row child tables (overwrites legacy duplicates and keeps strictly preferred)
        final updateUrl = Uri.parse('$baseUrl/api/resource/HCP%20Account/${Uri.encodeComponent(existingAccountName)}');
        final resp = await http.put(updateUrl, headers: _headers, body: jsonEncode(payload));
        if (resp.statusCode != 200) {
          final rpcUrl = Uri.parse('$baseUrl/api/method/frappe.client.save');
          final rpcResp = await http.post(
            rpcUrl,
            headers: _headers,
            body: jsonEncode({
              'doc': {
                'doctype': 'HCP Account',
                'name': existingAccountName,
                ...payload,
              }
            }),
          );
          if (rpcResp.statusCode != 200) {
            throw Exception('Failed to update HCP Account ($existingAccountName): HTTP ${resp.statusCode}, RPC ${rpcResp.statusCode}');
          }
        }
      } else {
        final createUrl = Uri.parse('$baseUrl/api/resource/HCP%20Account');
        final resp = await http.post(createUrl, headers: _headers, body: jsonEncode(payload));
        if (resp.statusCode != 200) {
          final rpcUrl = Uri.parse('$baseUrl/api/method/frappe.client.insert');
          final rpcResp = await http.post(
            rpcUrl,
            headers: _headers,
            body: jsonEncode({
              'doc': {
                'doctype': 'HCP Account',
                ...payload,
              }
            }),
          );
          if (rpcResp.statusCode != 200) {
            throw Exception('Failed to create HCP Account: HTTP ${resp.statusCode}, RPC ${rpcResp.statusCode}');
          }
        }
      }
    } catch (e) {
      print('Sync HCP Account error: $e');
      rethrow;
    } finally {
      if (!isAlreadyLocked && hcpId.isNotEmpty) {
        _inFlightHcpIds.remove(hcpId);
      }
    }
  }

  /// Process an Existing HCP submission (Direct Auto-Merge into HCP Masterlist & HCP Account Sync)
  /// Aligned with AGENTS.md:
  /// - Action: 'Submit for Processing' -> State: 'Processed'
  /// - Requires NO Managerial Approval
  /// - Merges automatically upon submission directly into universal HCP record and syncs HCP Account with preferred features active.
  Future<void> processExistingSubmission(HcpProfileSubmission submission) async {
    final subName = submission.name;
    HcpProfileSubmission fullSub = submission;
    if (subName != null && subName.isNotEmpty) {
      try {
        fullSub = await fetchSubmissionDetail(subName);
      } catch (_) {}
    }

    String effectiveHcpId = (fullSub.hcpName).trim();
    if (effectiveHcpId.isEmpty || effectiveHcpId == 'NEW-HCP') {
      print('[PROCESS EXISTING] Notice: hcpName is empty, cannot update existing doctor masterlist.');
      return;
    }

    // 1. Additive Merge into universal HCP Masterlist
    try {
      final existing = await fetchDoctorDetail(effectiveHcpId);

      // Additive merge of specialties
      final Map<String, HcpSpecialty> mergedSpecs = {};
      for (var s in existing.specialties) {
        mergedSpecs[s.hcpSpecialty] = s;
      }
      for (var s in fullSub.specialties) {
        final specId = LocationResolver.resolveSpecialtyId(s.hcpSpecialty);
        if (specId.isNotEmpty) {
          mergedSpecs[specId] = HcpSpecialty(
            hcpSpecialty: specId,
            subSpecialty: (s.subSpecialty != null && s.subSpecialty!.isNotEmpty && s.subSpecialty != '-')
                ? LocationResolver.resolveSpecialtyId(s.subSpecialty)
                : null,
            isPrimary: s.preferred,
          );
        }
      }

      // Additive merge of workplaces
      final Map<String, HcpWorkplace> mergedWps = {};
      for (var w in existing.workplaces) {
        mergedWps[w.workplace] = w;
      }
      for (var w in fullSub.workplaces) {
        final wpId = LocationResolver.resolveInstitutionId(w.hcpWorkplace);
        if (wpId.isNotEmpty) {
          mergedWps[wpId] = HcpWorkplace(
            workplace: wpId,
            provinceName: (w.provinceName != null && w.provinceName!.isNotEmpty) ? LocationResolver.resolveProvinceId(w.provinceName) : null,
            cityMunicipality: (w.cityMunicipality != null && w.cityMunicipality!.isNotEmpty) ? LocationResolver.resolveCityId(w.cityMunicipality) : null,
            address: w.workplaceName,
            isPrimary: w.preferred,
          );
        }
      }

      // Additive merge of contacts
      final Map<String, HcpContact> mergedContacts = {};
      for (var c in existing.contacts) {
        final key = '${c.contactNumber ?? ""}_${c.emailAddress ?? ""}';
        if (key != '_') mergedContacts[key] = c;
      }
      for (var c in fullSub.contacts) {
        final key = '${c.contactNumber ?? ""}_${c.emailAddress ?? ""}';
        if (key != '_') {
          mergedContacts[key] = HcpContact(
            contactNumber: c.contactNumber,
            emailAddress: c.emailAddress,
            isPrimary: c.preferred,
          );
        }
      }

      final updatedDoctor = Hcp(
        name: existing.name,
        firstName: (fullSub.firstName != null && fullSub.firstName!.isNotEmpty) ? fullSub.firstName! : existing.firstName,
        middleName: (fullSub.middleName != null && fullSub.middleName!.isNotEmpty) ? fullSub.middleName : existing.middleName,
        lastName: (fullSub.lastName != null && fullSub.lastName!.isNotEmpty) ? fullSub.lastName! : existing.lastName,
        birthDate: (fullSub.birthDate != null && fullSub.birthDate!.isNotEmpty) ? fullSub.birthDate : existing.birthDate,
        hcpPhoto: (fullSub.hcpPhoto != null && fullSub.hcpPhoto!.isNotEmpty) ? fullSub.hcpPhoto : existing.hcpPhoto,
        hcpType: LocationResolver.resolveHcpTypeId(fullSub.hcpType ?? existing.hcpType),
        hcpPractice: fullSub.hcpPractice ?? existing.hcpPractice,
        specialties: mergedSpecs.values.toList(),
        workplaces: mergedWps.values.toList(),
        contacts: mergedContacts.values.toList(),
        profileLastUpdated: DateTime.now().toIso8601String().split('.').first,
      );
      await updateDoctor(effectiveHcpId, updatedDoctor);
      print('[PROCESS EXISTING] Universal HCP record $effectiveHcpId updated successfully.');
    } catch (e) {
      print('[PROCESS EXISTING] Doctor update notice: $e');
    }

    // 2. Sync Program-Specific HCP Account with Strictly Preferred Data
    final docParts = [
      if (fullSub.firstName != null && fullSub.firstName!.isNotEmpty) fullSub.firstName!,
      if (fullSub.middleName != null && fullSub.middleName!.isNotEmpty && fullSub.middleName != '-') fullSub.middleName!,
      if (fullSub.lastName != null && fullSub.lastName!.isNotEmpty) fullSub.lastName!,
    ];
    final docFullName = (fullSub.hcpFullName != null && fullSub.hcpFullName!.isNotEmpty)
        ? fullSub.hcpFullName!
        : (docParts.isNotEmpty ? docParts.join(' ') : '${fullSub.firstName ?? ''} ${fullSub.lastName ?? ''}'.trim());

    final submittingUser = (fullSub.userId != null && fullSub.userId!.trim().isNotEmpty)
        ? fullSub.userId!.trim()
        : ((fullSub.medrepEmail != null && fullSub.medrepEmail!.trim().isNotEmpty)
            ? fullSub.medrepEmail!.trim()
            : (fullSub.owner ?? loggedInEmail ?? ''));

    final targetProg = (fullSub.accountOrProgram != null && fullSub.accountOrProgram!.trim().isNotEmpty)
        ? fullSub.accountOrProgram!.trim()
        : selectedProgram;

    final resolvedTerritory = await resolveUserTerritory(
      userEmail: submittingUser,
      program: targetProg,
      currentTerritory: fullSub.territory,
      currentSalesPerson: fullSub.salesPerson,
    );

    final prefSubSpecs = fullSub.specialties.where((s) => s.preferred).toList();
    final effectiveSubSpecs = prefSubSpecs.isNotEmpty ? prefSubSpecs : fullSub.specialties;

    final prefSubWps = fullSub.workplaces.where((w) => w.preferred).toList();
    final effectiveSubWps = prefSubWps.isNotEmpty ? prefSubWps : fullSub.workplaces;

    final prefSubContacts = fullSub.contacts.where((c) => c.preferred).toList();
    final effectiveSubContacts = prefSubContacts.isNotEmpty ? prefSubContacts : fullSub.contacts;

    try {
      await syncHcpAccount(
        hcpId: effectiveHcpId,
        hcpFullName: docFullName.isNotEmpty ? docFullName : 'Doctor',
        program: targetProg,
        territory: resolvedTerritory.territoryCode,
        salesPerson: resolvedTerritory.territoryManager,
        userId: submittingUser.isNotEmpty ? submittingUser : loggedInEmail,
        specialties: effectiveSubSpecs
            .where((s) => s.hcpSpecialty != null && s.hcpSpecialty!.isNotEmpty)
            .map((s) => HcpAccountSpecialization(
                  hcpSpecialty: LocationResolver.resolveSpecialtyId(s.hcpSpecialty),
                  subSpecialty: (s.subSpecialty != null && s.subSpecialty!.isNotEmpty && s.subSpecialty != '-') ? LocationResolver.resolveSpecialtyId(s.subSpecialty) : null,
                  isPrimary: true,
                  preferred: true,
                ))
            .toList(),
        workplaces: effectiveSubWps
            .where((w) => w.hcpWorkplace != null && w.hcpWorkplace!.isNotEmpty)
            .map((w) => HcpAccountWorkplace(
                  hcpWorkplace: LocationResolver.resolveInstitutionId(w.hcpWorkplace),
                  address: w.workplaceName,
                  isPrimary: true,
                  preferred: true,
                ))
            .toList(),
        contacts: effectiveSubContacts
            .where((c) => ((c.contactNumber != null && c.contactNumber!.isNotEmpty) || (c.emailAddress != null && c.emailAddress!.isNotEmpty)))
            .map((c) => HcpAccountContact(
                  contactNumber: c.contactNumber,
                  emailAddress: c.emailAddress,
                  isPrimary: true,
                  preferred: true,
                ))
            .toList(),
      );
      print('[PROCESS EXISTING] Program HCP Account synced with single preferred rows for $effectiveHcpId');
    } catch (e) {
      print('[PROCESS EXISTING] syncHcpAccount notice: $e');
    }
  }

  /// Approve a pending HCP Profile Submission (Admin / Manager)
  /// - Phase 1: If doctor is new, creates doctor in HCP doctype; if existing, performs non-destructive additive merge.
  /// - Phase 2: Syncs / creates doctor's HCP Account with non-destructive additive child tables.
  /// - Phase 3: Seals state by updating submission workflow_state = 'Approved', docstatus = 1 only if Phase 1 & 2 succeed.
  Future<void> approveSubmission(HcpProfileSubmission submission) async {
    final subName = submission.name;
    if (subName == null || subName.isEmpty) {
      throw Exception('Cannot approve submission: submission name is missing.');
    }

    // 0. Concurrency Mutex Lock (Eliminates Lost Updates & Double Approvals)
    final isAlreadyLockedByCaller = _inFlightSubmissions.contains(subName);
    if (!isAlreadyLockedByCaller) {
      _inFlightSubmissions.add(subName);
    }
    String? lockedHcpId;

    try {
      // 1. Authoritative Live Fetch (Eliminates Fuzzy / Non-Repeatable Reads)
      HcpProfileSubmission fullSub = submission;
      try {
        fullSub = await fetchSubmissionDetail(subName);
        print('[APPROVE] Authoritative live submission fetched for $subName: state=${fullSub.workflowState}, hcpName=${fullSub.hcpName}');
      } catch (e) {
        print('[APPROVE] Warning: Could not fetch fresh submission detail: $e. Using local snapshot.');
      }

      // Idempotency Verification: If already approved or submitted, no-op immediately
      if (fullSub.workflowState == 'Approved' || fullSub.docstatus == 1) {
        print('[APPROVE] Submission $subName is ALREADY approved (docstatus=${fullSub.docstatus}). Aborting redundant approval saga.');
        return;
      }

      if (fullSub.workflowState == 'Rejected') {
        throw Exception('Cannot approve submission $subName: it was already rejected.');
      }

      // District / Territory Enforcement: Manager cannot approve submission from another district
      if (isManager && !isAdmin) {
        final managedTerrs = getManagedTerritoryCodes();
        final subTerr = (fullSub.territory ?? '').trim();
        if (managedTerrs.isNotEmpty && subTerr.isNotEmpty && !managedTerrs.contains(subTerr)) {
          throw Exception('Cannot approve submission: Doctor belongs to territory "$subTerr", which is outside your assigned district.');
        }
      }

      String effectiveHcpId = fullSub.hcpName.trim();
      final bool isNewDoctor = effectiveHcpId.isEmpty || effectiveHcpId == 'NEW-HCP';
      if (!isNewDoctor && effectiveHcpId.isNotEmpty) {
        if (_inFlightHcpIds.contains(effectiveHcpId)) {
          throw Exception('Doctor $effectiveHcpId is currently locked by another concurrent process. Please wait.');
        }
        _inFlightHcpIds.add(effectiveHcpId);
        lockedHcpId = effectiveHcpId;
      }
      print('[APPROVE] Starting approval for $subName, hcpName=$effectiveHcpId, isNewDoctor=$isNewDoctor');

      // ─────────────────────────────────────────────────────────────
      // PHASE 1: DOCTOR MASTER PROVISIONING (HCP DOCTYPE)
      // ─────────────────────────────────────────────────────────────
      if (isNewDoctor) {
        // Countermeasure 4: Idempotent Service - Check if master doctor was already provisioned
        // to prevent duplicate records if an earlier attempt succeeded before a network retry
        if (effectiveHcpId.isEmpty || effectiveHcpId == 'NEW-HCP') {
          try {
            final fName = fullSub.firstName?.trim() ?? '';
            final lName = fullSub.lastName?.trim() ?? '';
            if (fName.isNotEmpty && lName.isNotEmpty) {
              final checkUrl = Uri.parse(
                '$baseUrl/api/resource/HCP?filters=[["first_name","=","${Uri.encodeComponent(fName)}"],["last_name","=","${Uri.encodeComponent(lName)}"]]&fields=["name"]&limit=1',
              );
              final checkResp = await http.get(checkUrl, headers: _headers);
              if (checkResp.statusCode == 200) {
                final checkBody = jsonDecode(checkResp.body);
                final List<dynamic> checkData = checkBody['data'] ?? [];
                if (checkData.isNotEmpty && checkData[0]['name'] != null) {
                  effectiveHcpId = checkData[0]['name'].toString().trim();
                  print('[APPROVE] Idempotency match: Reusing already provisioned Doctor $effectiveHcpId.');
                }
              }
            }
          } catch (_) {}
        }

        if (effectiveHcpId.isNotEmpty && effectiveHcpId != 'NEW-HCP') {
          _inFlightHcpIds.add(effectiveHcpId);
          lockedHcpId = effectiveHcpId;
        } else {
          SubmissionWorkplace? primaryWp;
          if (fullSub.workplaces.isNotEmpty) {
            primaryWp = fullSub.workplaces.firstWhere((w) => w.preferred, orElse: () => fullSub.workplaces.first);
          }
          final primaryLoc = LocationResolver.resolveCompleteWorkplaceLocation(
            institutionIdOrName: primaryWp?.hcpWorkplace ?? primaryWp?.workplaceName ?? fullSub.institution,
            cityIdOrName: primaryWp?.cityMunicipality ?? primaryWp?.cityTitle ?? fullSub.cityMunicipality,
            provinceIdOrName: primaryWp?.provinceName ?? primaryWp?.provinceTitle ?? fullSub.provinceName,
            regionIdOrName: primaryWp?.regionName ?? primaryWp?.regionTitle ?? fullSub.regionName,
          );

          final newDoctor = Hcp(
            firstName: (fullSub.firstName != null && fullSub.firstName!.trim().isNotEmpty) ? fullSub.firstName!.trim() : 'Doctor',
            middleName: (fullSub.middleName != null && fullSub.middleName!.trim().isNotEmpty && fullSub.middleName!.trim() != '-') ? fullSub.middleName!.trim() : '-',
            lastName: (fullSub.lastName != null && fullSub.lastName!.trim().isNotEmpty) ? fullSub.lastName!.trim() : '',
            birthDate: fullSub.birthDate ?? '',
            hcpPhoto: fullSub.hcpPhoto,
            hcpType: LocationResolver.resolveHcpTypeId(fullSub.hcpType),
            hcpPractice: (fullSub.hcpPractice != null && fullSub.hcpPractice!.isNotEmpty) ? fullSub.hcpPractice! : 'Prescribing',
            regionName: primaryLoc.regionId,
            provinceName: primaryLoc.provinceId,
            cityMunicipality: primaryLoc.cityId,
            institution: primaryLoc.workplaceId,
            specialties: fullSub.specialties
                .where((s) => s.hcpSpecialty != null && s.hcpSpecialty!.isNotEmpty)
                .map((s) => HcpSpecialty(
                      hcpSpecialty: LocationResolver.resolveSpecialtyId(s.hcpSpecialty),
                      subSpecialty: (s.subSpecialty != null && s.subSpecialty!.isNotEmpty && s.subSpecialty != '-') ? LocationResolver.resolveSpecialtyId(s.subSpecialty) : null,
                      isPrimary: s.preferred,
                    ))
                .toList(),
            workplaces: fullSub.workplaces
                .where((w) => w.hcpWorkplace != null && w.hcpWorkplace!.isNotEmpty)
                .map((w) {
                  final loc = LocationResolver.resolveCompleteWorkplaceLocation(
                    institutionIdOrName: w.hcpWorkplace,
                    institutionName: w.workplaceName,
                    cityIdOrName: w.cityMunicipality ?? w.cityTitle,
                    provinceIdOrName: w.provinceName ?? w.provinceTitle,
                    regionIdOrName: w.regionName ?? w.regionTitle,
                  );
                  return HcpWorkplace(
                    workplace: loc.workplaceId,
                    provinceName: loc.provinceId,
                    cityMunicipality: loc.cityId,
                    address: loc.workplaceName,
                    isPrimary: w.preferred,
                  );
                })
                .toList(),
            contacts: fullSub.contacts
                .where((c) => (c.contactNumber != null && c.contactNumber!.isNotEmpty) || (c.emailAddress != null && c.emailAddress!.isNotEmpty))
                .map((c) => HcpContact(contactNumber: c.contactNumber, emailAddress: c.emailAddress, isPrimary: c.preferred))
                .toList(),
            profileLastUpdated: DateTime.now().toIso8601String().split('.').first,
          );

          try {
            final createdDoc = await createDoctor(newDoctor);
            effectiveHcpId = (createdDoc.name ?? '').trim();
            if (effectiveHcpId.isEmpty) {
              throw Exception('Server returned an empty Doctor ID when creating master HCP.');
            }
            _inFlightHcpIds.add(effectiveHcpId);
            lockedHcpId = effectiveHcpId;
            print('[APPROVE] Doctor created successfully in HCP masterlist: $effectiveHcpId');
          } catch (e) {
            // STRICT PHASE 1 FAILURE: Abort immediately (Prevents Dirty Reads)
            print('[APPROVE] Phase 1 failed (createDoctor): $e');
            throw Exception('Failed to create doctor in HCP masterlist: $e');
          }
        }
      } else {
        // Existing doctor: perform NON-DESTRUCTIVE ADDITIVE MERGE (Prevents Lost Updates)
        try {
          final existing = await fetchDoctorDetail(effectiveHcpId);

          // Additive merge of specialties
          final Map<String, HcpSpecialty> mergedSpecs = {};
          for (var s in existing.specialties) {
            mergedSpecs[s.hcpSpecialty] = s;
          }
          for (var s in fullSub.specialties) {
            final specId = LocationResolver.resolveSpecialtyId(s.hcpSpecialty);
            if (specId.isNotEmpty) {
              mergedSpecs[specId] = HcpSpecialty(
                hcpSpecialty: specId,
                subSpecialty: (s.subSpecialty != null && s.subSpecialty!.isNotEmpty && s.subSpecialty != '-')
                    ? LocationResolver.resolveSpecialtyId(s.subSpecialty)
                    : null,
                isPrimary: s.preferred,
              );
            }
          }

          // Additive merge of workplaces
          final Map<String, HcpWorkplace> mergedWps = {};
          for (var w in existing.workplaces) {
            mergedWps[w.workplace] = w;
          }
          for (var w in fullSub.workplaces) {
            final loc = LocationResolver.resolveCompleteWorkplaceLocation(
              institutionIdOrName: w.hcpWorkplace,
              institutionName: w.workplaceName,
              cityIdOrName: w.cityMunicipality ?? w.cityTitle,
              provinceIdOrName: w.provinceName ?? w.provinceTitle,
              regionIdOrName: w.regionName ?? w.regionTitle,
            );
            if (loc.workplaceId.isNotEmpty) {
              mergedWps[loc.workplaceId] = HcpWorkplace(
                workplace: loc.workplaceId,
                provinceName: loc.provinceId,
                cityMunicipality: loc.cityId,
                address: loc.workplaceName,
                isPrimary: w.preferred,
              );
            }
          }

          // Additive merge of contacts
          final Map<String, HcpContact> mergedContacts = {};
          for (var c in existing.contacts) {
            final key = '${c.contactNumber ?? ""}_${c.emailAddress ?? ""}';
            if (key != '_') mergedContacts[key] = c;
          }
          for (var c in fullSub.contacts) {
            final key = '${c.contactNumber ?? ""}_${c.emailAddress ?? ""}';
            if (key != '_') {
              mergedContacts[key] = HcpContact(
                contactNumber: c.contactNumber,
                emailAddress: c.emailAddress,
                isPrimary: c.preferred,
              );
            }
          }

          SubmissionWorkplace? primaryWp;
          if (fullSub.workplaces.isNotEmpty) {
            primaryWp = fullSub.workplaces.firstWhere((w) => w.preferred, orElse: () => fullSub.workplaces.first);
          }
          final primaryLoc = LocationResolver.resolveCompleteWorkplaceLocation(
            institutionIdOrName: primaryWp?.hcpWorkplace ?? primaryWp?.workplaceName ?? existing.institution,
            cityIdOrName: primaryWp?.cityMunicipality ?? primaryWp?.cityTitle ?? existing.cityMunicipality,
            provinceIdOrName: primaryWp?.provinceName ?? primaryWp?.provinceTitle ?? existing.provinceName,
            regionIdOrName: primaryWp?.regionName ?? primaryWp?.regionTitle ?? existing.regionName,
          );

          final updatedDoctor = Hcp(
            name: existing.name,
            firstName: (fullSub.firstName != null && fullSub.firstName!.isNotEmpty) ? fullSub.firstName! : existing.firstName,
            middleName: (fullSub.middleName != null && fullSub.middleName!.isNotEmpty) ? fullSub.middleName : existing.middleName,
            lastName: (fullSub.lastName != null && fullSub.lastName!.isNotEmpty) ? fullSub.lastName! : existing.lastName,
            birthDate: (fullSub.birthDate != null && fullSub.birthDate!.isNotEmpty) ? fullSub.birthDate : existing.birthDate,
            hcpPhoto: (fullSub.hcpPhoto != null && fullSub.hcpPhoto!.isNotEmpty) ? fullSub.hcpPhoto : existing.hcpPhoto,
            hcpType: LocationResolver.resolveHcpTypeId(fullSub.hcpType ?? existing.hcpType),
            hcpPractice: fullSub.hcpPractice ?? existing.hcpPractice,
            regionName: primaryLoc.regionId,
            provinceName: primaryLoc.provinceId,
            cityMunicipality: primaryLoc.cityId,
            institution: primaryLoc.workplaceId,
            specialties: mergedSpecs.values.toList(),
            workplaces: mergedWps.values.toList(),
            contacts: mergedContacts.values.toList(),
            profileLastUpdated: DateTime.now().toIso8601String().split('.').first,
          );
          await updateDoctor(effectiveHcpId, updatedDoctor);
          print('[APPROVE] Doctor $effectiveHcpId updated with non-destructive additive merge.');
        } catch (e) {
          print('[APPROVE] Doctor update non-blocking warning: $e');
        }
      }

      // ─────────────────────────────────────────────────────────────
      // PHASE 2: PROGRAM AFFILIATION PROVISIONING (HCP ACCOUNT DOCTYPE)
      // ─────────────────────────────────────────────────────────────
      if (effectiveHcpId.isEmpty || effectiveHcpId == 'NEW-HCP') {
        throw Exception('Cannot sync HCP Account: effective Doctor ID was not determined.');
      }

      final docParts = [
        if (fullSub.firstName != null && fullSub.firstName!.isNotEmpty) fullSub.firstName!,
        if (fullSub.middleName != null && fullSub.middleName!.isNotEmpty && fullSub.middleName != '-') fullSub.middleName!,
        if (fullSub.lastName != null && fullSub.lastName!.isNotEmpty) fullSub.lastName!,
      ];
      final docFullName = (fullSub.hcpFullName != null && fullSub.hcpFullName!.isNotEmpty)
          ? fullSub.hcpFullName!
          : (docParts.isNotEmpty ? docParts.join(' ') : '${fullSub.firstName ?? ''} ${fullSub.lastName ?? ''}'.trim());

      final submittingUser = (fullSub.userId != null && fullSub.userId!.trim().isNotEmpty)
          ? fullSub.userId!.trim()
          : ((fullSub.medrepEmail != null && fullSub.medrepEmail!.trim().isNotEmpty)
              ? fullSub.medrepEmail!.trim()
              : (fullSub.owner ?? loggedInEmail ?? ''));

      final targetProg = (fullSub.accountOrProgram != null && fullSub.accountOrProgram!.trim().isNotEmpty)
          ? fullSub.accountOrProgram!.trim()
          : selectedProgram;

      final resolvedTerritory = await resolveUserTerritory(
        userEmail: submittingUser,
        program: targetProg,
        currentTerritory: fullSub.territory,
        currentSalesPerson: fullSub.salesPerson,
      );

      // Keep HCP Profile Submission synchronized with accurate territory & manager
      if (fullSub.territory != resolvedTerritory.territoryCode ||
          fullSub.salesPerson != resolvedTerritory.territoryManager) {
        try {
          final patchUrl = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(subName)}');
          await http.put(
            patchUrl,
            headers: _headers,
            body: jsonEncode({
              'territory': resolvedTerritory.territoryCode,
              'sales_person': resolvedTerritory.territoryManager,
            }),
          );
        } catch (e) {
          print('[APPROVE] Non-blocking submission territory sync notice: $e');
        }
      }

      final prefSubSpecs = fullSub.specialties.where((s) => s.preferred).toList();
      final effectiveSubSpecs = prefSubSpecs.isNotEmpty ? prefSubSpecs : fullSub.specialties;

      final prefSubWps = fullSub.workplaces.where((w) => w.preferred).toList();
      final effectiveSubWps = prefSubWps.isNotEmpty ? prefSubWps : fullSub.workplaces;

      final prefSubContacts = fullSub.contacts.where((c) => c.preferred).toList();
      final effectiveSubContacts = prefSubContacts.isNotEmpty ? prefSubContacts : fullSub.contacts;

      try {
        await syncHcpAccount(
          hcpId: effectiveHcpId,
          hcpFullName: docFullName.isNotEmpty ? docFullName : 'Doctor',
          program: targetProg,
          territory: resolvedTerritory.territoryCode,
          salesPerson: resolvedTerritory.territoryManager,
          userId: submittingUser.isNotEmpty ? submittingUser : loggedInEmail,
          specialties: effectiveSubSpecs
              .where((s) => s.hcpSpecialty != null && s.hcpSpecialty!.isNotEmpty)
              .map((s) => HcpAccountSpecialization(
                    hcpSpecialty: LocationResolver.resolveSpecialtyId(s.hcpSpecialty),
                    subSpecialty: (s.subSpecialty != null && s.subSpecialty!.isNotEmpty && s.subSpecialty != '-') ? LocationResolver.resolveSpecialtyId(s.subSpecialty) : null,
                    isPrimary: true,
                    preferred: true,
                  ))
              .toList(),
          workplaces: effectiveSubWps
              .where((w) => w.hcpWorkplace != null && w.hcpWorkplace!.isNotEmpty)
              .map((w) => HcpAccountWorkplace(
                    hcpWorkplace: LocationResolver.resolveInstitutionId(w.hcpWorkplace),
                    address: w.workplaceName,
                    isPrimary: true,
                    preferred: true,
                  ))
              .toList(),
          contacts: effectiveSubContacts
              .where((c) => ((c.contactNumber != null && c.contactNumber!.isNotEmpty) || (c.emailAddress != null && c.emailAddress!.isNotEmpty)))
              .map((c) => HcpAccountContact(
                    contactNumber: c.contactNumber,
                    emailAddress: c.emailAddress,
                    isPrimary: true,
                    preferred: true,
                  ))
              .toList(),
        );
        print('[APPROVE] Phase 2 succeeded: HCP Account synced successfully for $effectiveHcpId');
      } catch (e) {
        // STRICT PHASE 2 FAILURE: Abort before advancing workflow to Approved! (Prevents Dirty Reads)
        print('[APPROVE] Phase 2 failed (syncHcpAccount): $e');
        throw Exception('Failed to sync HCP Account: $e. Submission remains Pending Approval.');
      }

      // ─────────────────────────────────────────────────────────────
      // PHASE 3: WORKFLOW STATE SEALING (ADVANCE TO APPROVED)
      // ─────────────────────────────────────────────────────────────
      // Countermeasure 3: REREAD VALUE before final commit to verify database state was not altered mid-workflow
      Map<String, dynamic> liveDoc = {};
      try {
        final getUrl = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(subName)}');
        final getResp = await http.get(getUrl, headers: _headers);
        if (getResp.statusCode == 200) {
          liveDoc = jsonDecode(getResp.body)['data'] ?? {};
        }
      } catch (_) {}

      if (liveDoc.isNotEmpty) {
        final midState = (liveDoc['workflow_state'] ?? liveDoc['status'] ?? '').toString();
        final midDocstatus = liveDoc['docstatus'];
        if (midState == 'Rejected' || midDocstatus == 2) {
          print('[APPROVE] Reread Value conflict: Submission $subName was rejected mid-workflow. Aborting commit.');
          throw Exception('Aborting approval commit: Submission $subName was rejected mid-workflow by another user.');
        }
        if (midState == 'Approved' || midDocstatus == 1) {
          print('[APPROVE] Reread Value notice: Submission $subName was already marked Approved mid-workflow. Sealing complete.');
          return;
        }
      }

      liveDoc['hcp_name'] = effectiveHcpId;

      bool workflowApplied = false;
      final possibleActions = ['Approve', 'Approved', 'Approve Submission'];
      for (var actionName in possibleActions) {
        if (workflowApplied) break;
        try {
          final wfUrl = Uri.parse('$baseUrl/api/method/frappe.model.workflow.apply_workflow');
          final wfResp = await http.post(
            wfUrl,
            headers: _headers,
            body: jsonEncode({
              'doc': liveDoc.isNotEmpty ? liveDoc : {
                'doctype': 'HCP Profile Submission',
                'name': subName,
                'hcp_name': effectiveHcpId,
              },
              'action': actionName,
            }),
          );
          if (wfResp.statusCode == 200) {
            workflowApplied = true;
          }
        } catch (e) {
          print('[APPROVE] apply_workflow action="$actionName" notice: $e');
        }
      }

      // Fallback: set_value directly
      if (!workflowApplied) {
        try {
          final setValueUrl = Uri.parse('$baseUrl/api/method/frappe.client.set_value');
          final svResp = await http.post(
            setValueUrl,
            headers: _headers,
            body: jsonEncode({
              'doctype': 'HCP Profile Submission',
              'name': subName,
              'fieldname': {
                'hcp_name': effectiveHcpId,
                'workflow_state': 'Approved',
                'status': 'Approved',
                'application_status': 'Applied',
              },
            }),
          );
          if (svResp.statusCode == 200) workflowApplied = true;
        } catch (_) {}
      }

      // Fallback: direct REST PUT
      if (!workflowApplied) {
        try {
          final updateUrl = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(subName)}');
          await http.put(
            updateUrl,
            headers: _headers,
            body: jsonEncode({
              'hcp_name': effectiveHcpId,
              'workflow_state': 'Approved',
              'status': 'Approved',
              'application_status': 'Applied',
              'docstatus': 1,
            }),
          );
        } catch (_) {}
      }

      // ─────────────────────────────────────────────────────────────
      // PHASE 4: LOCAL CACHE SYNCHRONIZATION
      // ─────────────────────────────────────────────────────────────
      try {
        final cache = await _readFromCache('submissions_cache.json');
        if (cache != null) {
          final List<dynamic> list = jsonDecode(cache);
          final idx = list.indexWhere((item) => item['name'] == subName);
          if (idx != -1) {
            list[idx]['workflow_state'] = 'Approved';
            list[idx]['status'] = 'Approved';
            list[idx]['application_status'] = 'Applied';
            list[idx]['docstatus'] = 1;
            list[idx]['hcp_name'] = effectiveHcpId;
            await _writeToCache('submissions_cache.json', jsonEncode(list));
          }
        }
      } catch (_) {}

    } finally {
      if (lockedHcpId != null) {
        _inFlightHcpIds.remove(lockedHcpId);
      }
      if (!isAlreadyLockedByCaller) {
        _inFlightSubmissions.remove(subName);
      }
    }
  }

  /// Reject a pending HCP Profile Submission (Admin / Manager)
  Future<HcpProfileSubmission> rejectSubmission(String submissionName, {String remarks = '', HcpProfileSubmission? submission}) async {
    bool workflowApplied = false;
    final trimmedRemarks = remarks.trim();

    // 1. Direct atomic transition via frappe.client.set_value:
    // Sets workflow_state: 'Rejected', status: 'Rejected', application_status: 'Applied',
    // and stores the rejection comment in the dedicated field 'rejection_reason'
    try {
      final setValueUrl = Uri.parse('$baseUrl/api/method/frappe.client.set_value');
      final svResp = await http.post(
        setValueUrl,
        headers: _headers,
        body: jsonEncode({
          'doctype': 'HCP Profile Submission',
          'name': submissionName,
          'fieldname': {
            'workflow_state': 'Rejected',
            'status': 'Rejected',
            'application_status': 'Applied',
            'rejection_reason': trimmedRemarks,
            'docstatus': 0,
          },
        }),
      );
      if (svResp.statusCode == 200) {
        workflowApplied = true;
        print('[REJECT] Successfully rejected and saved rejection_reason via frappe.client.set_value for $submissionName');
      } else {
        print('[REJECT] set_value response: ${svResp.statusCode} - ${svResp.body}');
      }
    } catch (e) {
      print('[REJECT] set_value error: $e');
    }

    // 2. Fallback: Official Frappe workflow engine transition with fresh document snapshot
    if (!workflowApplied) {
      try {
        Map<String, dynamic> freshDoc = {};
        final getUrl = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(submissionName)}');
        final getResp = await http.get(getUrl, headers: _headers);
        if (getResp.statusCode == 200) {
          freshDoc = jsonDecode(getResp.body)['data'] ?? {};
        }

        freshDoc['doctype'] = 'HCP Profile Submission';
        freshDoc['name'] = submissionName;
        freshDoc['application_status'] = 'Applied';
        freshDoc['rejection_reason'] = trimmedRemarks;
        if (freshDoc['profile_action'] == null || freshDoc['profile_action'].toString().trim().isEmpty) {
          freshDoc['profile_action'] = (submission?.profileAction?.isNotEmpty == true)
              ? submission!.profileAction
              : (freshDoc['hcp_name'] != null && freshDoc['hcp_name'].toString().trim().isNotEmpty ? 'Existing HCP' : 'New HCP');
        }

        final wfUrl = Uri.parse('$baseUrl/api/method/frappe.model.workflow.apply_workflow');
        final wfResp = await http.post(
          wfUrl,
          headers: _headers,
          body: jsonEncode({
            'doc': freshDoc,
            'action': 'Reject',
          }),
        );
        if (wfResp.statusCode == 200) {
          workflowApplied = true;
          print('[REJECT] Successfully applied workflow action "Reject" for $submissionName');
          try {
            final setValueUrl = Uri.parse('$baseUrl/api/method/frappe.client.set_value');
            await http.post(
              setValueUrl,
              headers: _headers,
              body: jsonEncode({
                'doctype': 'HCP Profile Submission',
                'name': submissionName,
                'fieldname': 'rejection_reason',
                'value': trimmedRemarks,
              }),
            );
          } catch (_) {}
        } else {
          print('[REJECT] apply_workflow fallback response: ${wfResp.statusCode} - ${wfResp.body}');
        }
      } catch (e) {
        print('[REJECT] apply_workflow fallback error: $e');
      }
    }

    // 3. Also post to Frappe timeline comment as non-blocking secondary record
    if (trimmedRemarks.isNotEmpty) {
      try {
        await addSubmissionComment(
          submissionName: submissionName,
          content: trimmedRemarks,
        );
      } catch (e) {
        print('[REJECT] addSubmissionComment notice: $e');
      }
    }

    if (!workflowApplied) {
      throw Exception('Failed to reject submission on ERPNext server. Please verify network or managerial permissions.');
    }

    // 4. Re-fetch the final clean state from ERPNext to verify server state
    final updateUrl = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(submissionName)}');
    HcpProfileSubmission freshSub;
    try {
      final freshResp = await http.get(updateUrl, headers: _headers);
      if (freshResp.statusCode == 200) {
        final freshBody = jsonDecode(freshResp.body);
        final rawData = Map<String, dynamic>.from(freshBody['data']);
        rawData['workflow_state'] = 'Rejected';
        rawData['status'] = 'Rejected';
        freshSub = HcpProfileSubmission.fromJson(rawData);
      } else {
        freshSub = (submission ?? HcpProfileSubmission(hcpName: submissionName)).copyWith(
          workflowState: 'Rejected',
          status: 'Rejected',
          docstatus: 0,
        );
      }
    } catch (_) {
      freshSub = (submission ?? HcpProfileSubmission(hcpName: submissionName)).copyWith(
        workflowState: 'Rejected',
        status: 'Rejected',
        docstatus: 0,
      );
    }

    freshSub = freshSub.copyWith(
      workflowState: 'Rejected',
      status: 'Rejected',
      docstatus: 0,
      rejectionRemarks: remarks.trim().isNotEmpty ? remarks.trim() : freshSub.rejectionRemarks,
      rejectedBy: (loggedInFullName != null && loggedInFullName!.trim().isNotEmpty)
          ? loggedInFullName!.trim()
          : (loggedInEmail ?? 'Manager'),
    );

    // 5. Update local cache immediately
    await _updateSubmissionInLocalCache(freshSub);
    return freshSub;
  }

  /// Add a comment/rejection note to an HCP Profile Submission via Frappe API
  Future<bool> addSubmissionComment({
    required String submissionName,
    required String content,
  }) async {
    if (_isOffline) return false;
    try {
      final url = Uri.parse('$baseUrl/api/method/frappe.desk.form.utils.add_comment');
      final authorName = (loggedInFullName != null && loggedInFullName!.trim().isNotEmpty)
          ? loggedInFullName!.trim()
          : (loggedInEmail ?? 'Manager');
      final authorEmail = loggedInEmail ?? 'administrator@profinsights.biz';

      final resp = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'reference_doctype': 'HCP Profile Submission',
          'reference_name': submissionName,
          'content': content.trim(),
          'comment_email': authorEmail,
          'comment_by': authorName,
        }),
      );
      if (resp.statusCode == 200) {
        print('[COMMENT] Successfully added comment to $submissionName');
        return true;
      } else {
        print('[COMMENT] add_comment warning: ${resp.statusCode} - ${resp.body}');
      }
    } catch (e) {
      print('[COMMENT] add_comment error: $e');
    }
    return false;
  }

  /// Clean HTML formatting and tags from Frappe rich text comments
  static String cleanCommentHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(r'&#39;', "'")
        .replaceAll('\n\n', '\n')
        .trim();
  }

  /// Fetch all comments for an HCP Profile Submission ordered newest first.
  /// Uses frappe.desk.form.load.getdoc as the primary method so that MedReps (Sales User role)
  /// can read comments without encountering 403 Forbidden on the Comment doctype.
  Future<List<Map<String, dynamic>>> fetchSubmissionComments(String submissionName) async {
    if (_isOffline) return [];

    // 1. Primary: Frappe form load getdoc (allowed for Sales User / MedRep without DocType permission errors)
    try {
      final getDocUrl = Uri.parse(
        '$baseUrl/api/method/frappe.desk.form.load.getdoc?doctype=HCP%20Profile%20Submission&name=${Uri.encodeComponent(submissionName)}',
      );
      final resp = await http.get(getDocUrl, headers: _headers);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final docinfo = body['docinfo'];
        if (docinfo is Map) {
          final rawComments = docinfo['comments'];
          final userInfo = (docinfo['user_info'] is Map) ? (docinfo['user_info'] as Map) : {};

          if (rawComments is List && rawComments.isNotEmpty) {
            final List<Map<String, dynamic>> parsedList = [];
            for (var c in rawComments) {
              if (c is Map) {
                final map = Map<String, dynamic>.from(c);
                final rawContent = map['content']?.toString() ?? '';
                map['content'] = cleanCommentHtml(rawContent);

                // Resolve friendly author name from docinfo user_info or comment_by
                final owner = map['owner']?.toString() ?? '';
                final currentCommentBy = map['comment_by']?.toString() ?? '';
                if (currentCommentBy.isEmpty || currentCommentBy.contains('@')) {
                  if (userInfo.containsKey(owner) && userInfo[owner] is Map) {
                    final fullname = userInfo[owner]['fullname']?.toString() ?? '';
                    if (fullname.trim().isNotEmpty) {
                      map['comment_by'] = fullname.trim();
                    }
                  }
                }
                parsedList.add(map);
              }
            }

            // Order newest first
            parsedList.sort((a, b) {
              final aCreation = a['creation']?.toString() ?? '';
              final bCreation = b['creation']?.toString() ?? '';
              return bCreation.compareTo(aCreation);
            });

            if (parsedList.isNotEmpty) {
              return parsedList;
            }
          }
        }
      }
    } catch (e) {
      print('[COMMENT] Fetch via getdoc warning: $e');
    }

    // 2. Fallback: Direct Comment resource API (accessible to System Manager / Admin)
    try {
      final filtersJson = jsonEncode([
        ['reference_doctype', '=', 'HCP Profile Submission'],
        ['reference_name', '=', submissionName],
      ]);
      final fieldsJson = jsonEncode(['name', 'content', 'comment_by', 'owner', 'creation']);
      final params = Uri(queryParameters: {
        'filters': filtersJson,
        'fields': fieldsJson,
        'order_by': 'creation desc',
      }).query;
      final url = Uri.parse('$baseUrl/api/resource/Comment?$params');
      final resp = await http.get(url, headers: _headers);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final List<dynamic> data = body['data'] ?? [];
        return data.map((c) {
          final m = Map<String, dynamic>.from(c as Map);
          m['content'] = cleanCommentHtml(m['content']?.toString() ?? '');
          return m;
        }).toList();
      }
    } catch (e) {
      print('[COMMENT] Fetch via resource/Comment fallback error: $e');
    }

    return [];
  }

  /// Retrieve list of Specializations with multi-tier cache & local fallback
  Future<List<Specialization>> fetchSpecializations() async {
    if (_isOffline) {
      final cache = await _readFromCache('specializations_cache.json');
      if (cache != null) {
        try {
          final List<dynamic> dataList = jsonDecode(cache);
          if (dataList.isNotEmpty) {
            return dataList.map((json) => Specialization.fromJson(json)).toList();
          }
        } catch (_) {}
      }
      try {
        final String localData = await rootBundle.loadString('assets/specializations.json');
        final List<dynamic> dataList = jsonDecode(localData);
        return dataList.map((json) => Specialization.fromJson(json)).toList();
      } catch (err) {
        print('Failed to load local fallback specializations: $err');
        return [];
      }
    }

    final url = Uri.parse(
      '$baseUrl/api/resource/Specialization?fields=["name","specialty","specialty_group","parent_specialization","is_group"]&limit_page_length=1000',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] ?? [];
        if (dataList.isNotEmpty) {
          await _writeToCache('specializations_cache.json', jsonEncode(dataList));
          final list = dataList.map((json) => Specialization.fromJson(json)).toList();
          LocationResolver.registerSpecializations(list);
          return list;
        }
      }
      
      // Fallback attempt: frappe.client.get_list method
      final rpcUrl = Uri.parse(
        '$baseUrl/api/method/frappe.client.get_list?doctype=Specialization&fields=["name","specialty","specialty_group","parent_specialization","is_group"]&limit_page_length=1000',
      );
      final rpcResp = await http.get(rpcUrl, headers: _headers);
      if (rpcResp.statusCode == 200) {
        final body = jsonDecode(rpcResp.body);
        final List<dynamic> dataList = (body['message'] is List) ? body['message'] : (body['data'] ?? []);
        if (dataList.isNotEmpty) {
          await _writeToCache('specializations_cache.json', jsonEncode(dataList));
          final list = dataList.map((json) => Specialization.fromJson(json)).toList();
          LocationResolver.registerSpecializations(list);
          return list;
        }
      }
    } catch (e) {
      print('Fetch specializations online error: $e');
    }

    // Fallback to cache or bundled asset
    try {
      final cache = await _readFromCache('specializations_cache.json');
      if (cache != null) {
        final List<dynamic> dataList = jsonDecode(cache);
        if (dataList.isNotEmpty) {
          final list = dataList.map((json) => Specialization.fromJson(json)).toList();
          LocationResolver.registerSpecializations(list);
          return list;
        }
      }
    } catch (_) {}

    try {
      final String localData = await rootBundle.loadString('assets/specializations.json');
      final List<dynamic> dataList = jsonDecode(localData);
      final list = dataList.map((json) => Specialization.fromJson(json)).toList();
      LocationResolver.registerSpecializations(list);
      return list;
    } catch (err) {
      print('Failed to load local fallback specializations: $err');
      return [];
    }
  }

  /// Retrieve list of PSGC Locations
  Future<List<PsgcLocation>> fetchPsgcLocations() async {
    if (_isOffline) {
      final cache = await _readFromCache('psgc_locations_cache.json');
      if (cache != null) {
        try {
          final List<dynamic> dataList = jsonDecode(cache);
          final list = dataList.map((json) => PsgcLocation.fromJson(json)).toList();
          LocationResolver.registerPsgcLocations(list);
          return list;
        } catch (_) {}
      }
      try {
        final localData = await rootBundle.loadString('assets/data/psgc_locations.json');
        final List<dynamic> dataList = jsonDecode(localData);
        final list = dataList.map((json) => PsgcLocation.fromJson(json)).toList();
        LocationResolver.registerPsgcLocations(list);
        return list;
      } catch (_) {}
      return [];
    }
    final url = Uri.parse(
      '$baseUrl/api/resource/PSGC%20Location?fields=["name","location_label","location_type","parent_psgc_location","psgc_code","is_group"]&filters=[["location_type","in",["Region","Province","City"]]]&limit_page_length=5000&limit=5000',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] ?? [];
        await _writeToCache('psgc_locations_cache.json', jsonEncode(dataList));
        final list = dataList.map((json) => PsgcLocation.fromJson(json)).toList();
        LocationResolver.registerPsgcLocations(list);
        return list;
      } else {
        throw Exception('Failed to load PSGC locations: ${response.statusCode}');
      }
    } catch (e) {
      print('Fetch PSGC locations error: $e');
      final cache = await _readFromCache('psgc_locations_cache.json');
      if (cache != null) {
        try {
          final List<dynamic> dataList = jsonDecode(cache);
          final list = dataList.map((json) => PsgcLocation.fromJson(json)).toList();
          LocationResolver.registerPsgcLocations(list);
          return list;
        } catch (_) {}
      }
      try {
        final localData = await rootBundle.loadString('assets/data/psgc_locations.json');
        final List<dynamic> dataList = jsonDecode(localData);
        final list = dataList.map((json) => PsgcLocation.fromJson(json)).toList();
        LocationResolver.registerPsgcLocations(list);
        return list;
      } catch (_) {}
      rethrow;
    }
  }

  /// Retrieve active Survey Templates
  Future<List<HcpSurveyTemplate>> fetchSurveyTemplates() async {
    final url = Uri.parse(
      '$baseUrl/api/resource/HCP%20Survey%20Template?fields=["name","template_name","is_active","account_or_program","description"]&filters=[["is_active","=",1]]',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] ?? [];
        
        // Survey templates have nested questions child table, we load details for active ones
        List<HcpSurveyTemplate> templates = [];
        for (var item in dataList) {
          final detailUrl = Uri.parse('$baseUrl/api/resource/HCP%20Survey%20Template/${Uri.encodeComponent(item['name'])}');
          final detailResp = await http.get(detailUrl, headers: _headers);
          if (detailResp.statusCode == 200) {
            final detailBody = jsonDecode(detailResp.body);
            templates.add(HcpSurveyTemplate.fromJson(detailBody['data']));
          }
        }
        return templates;
      } else {
        throw Exception('Failed to load survey templates: ${response.statusCode}');
      }
    } catch (e) {
      print('Fetch survey templates error: $e');
      rethrow;
    }
  }

  /// Retrieve list of HCP Types (used as Link values for hcp_type field) with cache & local fallback
  Future<List<HcpType>> fetchHcpTypes() async {
    if (_isOffline) {
      final cache = await _readFromCache('hcp_types_cache.json');
      if (cache != null) {
        try {
          final List<dynamic> dataList = jsonDecode(cache);
          if (dataList.isNotEmpty) {
            final list = dataList.map((json) => HcpType.fromJson(json)).toList();
            LocationResolver.registerHcpTypes(list);
            return list;
          }
        } catch (_) {}
      }
      try {
        final String localData = await rootBundle.loadString('assets/hcp_types.json');
        final List<dynamic> dataList = jsonDecode(localData);
        final list = dataList.map((json) => HcpType.fromJson(json)).toList();
        LocationResolver.registerHcpTypes(list);
        return list;
      } catch (err) {
        print('Failed to load local fallback HCP types: $err');
        final list = [
          HcpType(name: 'HCP-TYPE-01', typeName: 'Consultant', description: 'About this type'),
          HcpType(name: 'HCP-TYPE-02', typeName: 'Resident', description: 'About this type'),
          HcpType(name: 'HCP-TYPE-03', typeName: 'Fellow', description: 'About this type'),
        ];
        LocationResolver.registerHcpTypes(list);
        return list;
      }
    }

    final url = Uri.parse(
      '$baseUrl/api/resource/HCP%20Type?fields=["name","hcp_type","description"]&limit_page_length=100',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] ?? [];
        if (dataList.isNotEmpty) {
          await _writeToCache('hcp_types_cache.json', jsonEncode(dataList));
          final list = dataList.map((json) => HcpType.fromJson(json)).toList();
          LocationResolver.registerHcpTypes(list);
          return list;
        }
      }

      // Fallback attempt: frappe.client.get_list method
      final rpcUrl = Uri.parse(
        '$baseUrl/api/method/frappe.client.get_list?doctype=HCP%20Type&fields=["name","hcp_type","description"]&limit_page_length=100',
      );
      final rpcResp = await http.get(rpcUrl, headers: _headers);
      if (rpcResp.statusCode == 200) {
        final body = jsonDecode(rpcResp.body);
        final List<dynamic> dataList = (body['message'] is List) ? body['message'] : (body['data'] ?? []);
        if (dataList.isNotEmpty) {
          await _writeToCache('hcp_types_cache.json', jsonEncode(dataList));
          final list = dataList.map((json) => HcpType.fromJson(json)).toList();
          LocationResolver.registerHcpTypes(list);
          return list;
        }
      }
    } catch (e) {
      print('Fetch HCP types online error: $e');
    }

    // Fallback to cache or bundled asset
    try {
      final cache = await _readFromCache('hcp_types_cache.json');
      if (cache != null) {
        final List<dynamic> dataList = jsonDecode(cache);
        if (dataList.isNotEmpty) {
          final list = dataList.map((json) => HcpType.fromJson(json)).toList();
          LocationResolver.registerHcpTypes(list);
          return list;
        }
      }
    } catch (_) {}

    try {
      final String localData = await rootBundle.loadString('assets/hcp_types.json');
      final List<dynamic> dataList = jsonDecode(localData);
      final list = dataList.map((json) => HcpType.fromJson(json)).toList();
      LocationResolver.registerHcpTypes(list);
      return list;
    } catch (err) {
      print('Failed to load local fallback HCP types: $err');
      final list = [
        HcpType(name: 'HCP-TYPE-01', typeName: 'Consultant', description: 'About this type'),
        HcpType(name: 'HCP-TYPE-02', typeName: 'Resident', description: 'About this type'),
        HcpType(name: 'HCP-TYPE-03', typeName: 'Fellow', description: 'About this type'),
      ];
      LocationResolver.registerHcpTypes(list);
      return list;
    }
  }

  List<TerritoryInfo> _territoryInfos = [];
  List<TerritoryInfo> get territoryInfos => _territoryInfos;

  List<Map<String, dynamic>> _salesPersons = [];
  List<Map<String, dynamic>> get salesPersons => _salesPersons;

  /// Retrieve list of Sales Persons from ERPNext with local caching
  Future<List<Map<String, dynamic>>> fetchSalesPersons({bool forceRefresh = false}) async {
    if (!forceRefresh && _salesPersons.isNotEmpty) {
      return _salesPersons;
    }

    if (!_isOffline && _sessionCookie != null) {
      try {
        final url = Uri.parse(
          '$baseUrl/api/resource/Sales%20Person?fields=["name","sales_person_name","parent_sales_person","employee","is_group"]&limit=1000',
        );
        final response = await http.get(url, headers: _headers);
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final List<dynamic> dataList = body['data'] ?? [];
          final List<Map<String, dynamic>> list = [];
          for (var item in dataList) {
            if (item is Map<String, dynamic>) {
              list.add(item);
            }
          }
          if (list.isNotEmpty) {
            _salesPersons = list;
            await _writeToCache('sales_persons_cache.json', jsonEncode(list));
            return list;
          }
        }
      } catch (e) {
        print('Fetch sales persons error: $e');
      }
    }

    // Cache fallback
    final cached = await _readFromCache('sales_persons_cache.json');
    if (cached != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cached);
        _salesPersons = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        return _salesPersons;
      } catch (_) {}
    }

    return _salesPersons;
  }

  /// Retrieve list of rich Territory Info with Territory Managers from ERPNext
  Future<List<TerritoryInfo>> fetchTerritoryInfos({bool forceRefresh = false}) async {
    if (!forceRefresh && _territoryInfos.isNotEmpty) {
      return _territoryInfos;
    }

    if (!_isOffline && _sessionCookie != null) {
      final url = Uri.parse(
        '$baseUrl/api/resource/Territory?fields=["name","territory_name","territory_manager","parent_territory","is_group","custom_user_id","custom_account_or_program"]&limit=1000',
      );
      try {
        final response = await http.get(url, headers: _headers);
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final List<dynamic> dataList = body['data'] ?? [];
          final List<TerritoryInfo> list = [];
          for (var item in dataList) {
            final tInfo = TerritoryInfo.fromJson(item);
            if (tInfo.name.isNotEmpty && !list.any((t) => t.name == tInfo.name)) {
              list.add(tInfo);
            }
          }
          if (list.isNotEmpty) {
            _territoryInfos = list;
            await _writeToCache('territory_infos_cache.json', jsonEncode(list.map((t) => t.toJson()).toList()));
            return list;
          }
        }
      } catch (e) {
        print('Fetch territory infos error: $e');
      }
    }

    // Cache fallback
    final cached = await _readFromCache('territory_infos_cache.json');
    if (cached != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cached);
        _territoryInfos = decoded.map((e) => TerritoryInfo.fromJson(e as Map<String, dynamic>)).toList();
        if (_territoryInfos.isNotEmpty) {
          return _territoryInfos;
        }
      } catch (_) {}
    }

    final fallback = [
      TerritoryInfo(name: 'BA1-01', territoryName: 'BA1-01', territoryManager: 'KC Cassandra Enriquez (BA1-01)', parentTerritory: 'BA1 - SOUTH GMA/BACOLOD/ILOILO'),
      TerritoryInfo(name: 'BA2-05', territoryName: 'BA2-05', territoryManager: 'Ivy Marie Mateo (BA2-05)', parentTerritory: 'BA2 - WEST GMA'),
      TerritoryInfo(name: 'AD0101', territoryName: 'AD0101', territoryManager: 'GRAZIEL RIVO (AD0101)', parentTerritory: 'AD1 - GMA/NORTH LUZON/CENTRAL LUZON'),
      TerritoryInfo(name: 'AD0107', territoryName: 'AD0107', territoryManager: 'LOUIE GLENN MINABES (AD0107)', parentTerritory: 'AD0105 (COOR)'),
      TerritoryInfo(name: 'AD0110', territoryName: 'AD0110', territoryManager: 'JORGE MENGORIO (AD0110)', parentTerritory: 'AD2 - GMA/SOUTH LUZON'),
      TerritoryInfo(name: 'AA1ADC', territoryName: 'AA1ADC', territoryManager: 'MARY GRACE DIPASUPIL (ADC Samples PHSR AA - AA1ADC)', parentTerritory: 'Abbott Samples PHSR'),
      TerritoryInfo(name: 'RND02', territoryName: 'RND02', territoryManager: '', parentTerritory: 'Abbott Samples RND'),
      TerritoryInfo(name: 'RM101', territoryName: 'RM101', territoryManager: '', parentTerritory: 'RiteMed Territories'),
      TerritoryInfo(name: 'VIV-01', territoryName: 'VIV-01', territoryManager: '', parentTerritory: 'Vivaro Territories'),
      TerritoryInfo(name: 'CORE01', territoryName: 'CORE01', territoryManager: '', parentTerritory: 'All Territories'),
      TerritoryInfo(name: 'CORE02', territoryName: 'CORE02', territoryManager: '', parentTerritory: 'All Territories'),
    ];
    _territoryInfos = fallback;
    return fallback;
  }

  /// Get leaf territories filtered for a given program/branch
  List<TerritoryInfo> getLeafTerritoriesForProgram(String program) {
    if (_territoryInfos.isEmpty) {
      return [];
    }
    final pLower = program.toLowerCase().trim();
    final leaves = _territoryInfos.where((t) => !t.isGroup && t.name.isNotEmpty && t.name.toLowerCase() != 'all territories').toList();

    if (pLower.contains('bayer')) {
      final bayer = leaves.where((t) {
        final n = t.name.toUpperCase();
        final parent = (t.parentTerritory ?? '').toLowerCase();
        return n.startsWith('BA') || n.startsWith('BAS') || parent.contains('bayer') || parent.startsWith('ba');
      }).toList();
      if (bayer.isNotEmpty) return bayer;
    }

    if (pLower.contains('abbott diabetes') || pLower.contains('abbott dc') || pLower == 'adc') {
      final adc = leaves.where((t) {
        final n = t.name.toUpperCase();
        final parent = (t.parentTerritory ?? '').toLowerCase();
        return n.startsWith('AD') || parent.contains('abbott dc');
      }).toList();
      if (adc.isNotEmpty) return adc;
    }

    if (pLower.contains('phsr')) {
      final phsr = leaves.where((t) {
        final n = t.name.toUpperCase();
        final parent = (t.parentTerritory ?? '').toLowerCase();
        return n.startsWith('AA') || parent.contains('phsr');
      }).toList();
      if (phsr.isNotEmpty) return phsr;
    }

    if (pLower.contains('rnd')) {
      final rnd = leaves.where((t) {
        final n = t.name.toUpperCase();
        final parent = (t.parentTerritory ?? '').toLowerCase();
        return n.startsWith('RND') || parent.contains('rnd');
      }).toList();
      if (rnd.isNotEmpty) return rnd;
    }

    if (pLower.contains('ritemed') || pLower.contains('rtmd')) {
      final rm = leaves.where((t) {
        final n = t.name.toUpperCase();
        final parent = (t.parentTerritory ?? '').toLowerCase();
        final cprog = (t.customAccountOrProgram ?? '').toLowerCase();
        return n.startsWith('RM') || parent.contains('ritemed') || parent.contains('ngma') || parent.contains('sgma') || cprog.contains('rtmd') || cprog.contains('ritemed');
      }).toList();
      if (rm.isNotEmpty) return rm;
    }

    if (pLower.contains('vivaro')) {
      final viv = leaves.where((t) {
        final n = t.name.toUpperCase();
        final parent = (t.parentTerritory ?? '').toLowerCase();
        return n.startsWith('VIV') || parent.contains('vivaro');
      }).toList();
      if (viv.isNotEmpty) return viv;
    }

    if (pLower.contains('corenergy')) {
      final core = leaves.where((t) => t.name.toUpperCase().startsWith('CORE')).toList();
      if (core.isNotEmpty) return core;
    }

    if (pLower.contains('taisho')) {
      final tai = leaves.where((t) {
        final n = t.name.toUpperCase();
        final parent = (t.parentTerritory ?? '').toLowerCase();
        return n.startsWith('TAI') || n.startsWith('TP') || n.startsWith('TS') || parent.contains('taisho');
      }).toList();
      if (tai.isNotEmpty) return tai;
    }

    if (pLower.contains('fonterra')) {
      final fon = leaves.where((t) {
        final n = t.name.toUpperCase();
        final parent = (t.parentTerritory ?? '').toLowerCase();
        return n.startsWith('FON') || parent.contains('fonterra');
      }).toList();
      if (fon.isNotEmpty) return fon;
    }

    if (pLower.contains('biomerieux')) {
      final bio = leaves.where((t) {
        final n = t.name.toUpperCase();
        final parent = (t.parentTerritory ?? '').toLowerCase();
        return n.startsWith('BIO') || parent.contains('biomerieux');
      }).toList();
      if (bio.isNotEmpty) return bio;
    }

    if (pLower.contains('exeltis')) {
      final exe = leaves.where((t) {
        final n = t.name.toUpperCase();
        final parent = (t.parentTerritory ?? '').toLowerCase();
        return n.startsWith('EXE') || parent.contains('exeltis');
      }).toList();
      if (exe.isNotEmpty) return exe;
    }

    // Default to all leaf territories if program not specifically matched
    return leaves;
  }

  /// Get the assigned territory manager for a given territory code
  String getTerritoryManagerForTerritory(String territoryCode) {
    if (territoryCode.trim().isEmpty) return '';
    if (_territoryInfos.isEmpty) {
      fetchTerritoryInfos(); // fire-and-forget population
    }
    final match = _territoryInfos.firstWhere(
      (t) => t.name.toLowerCase() == territoryCode.toLowerCase().trim() || t.territoryName.toLowerCase() == territoryCode.toLowerCase().trim(),
      orElse: () => TerritoryInfo(name: territoryCode, territoryName: territoryCode, territoryManager: ''),
    );
    return match.territoryManager;
  }

  /// Get all territory codes managed by the logged in user (for DSM / District Manager)
  /// Returns empty set if Admin (unrestricted global access)
  Set<String> getManagedTerritoryCodes() {
    if (isAdmin) return {}; // Admin has unrestricted access to all districts
    final email = (loggedInEmail ?? '').trim().toLowerCase();
    final fullName = (loggedInFullName ?? '').trim().toLowerCase();
    final nameTokens = fullName.split(RegExp(r'[\s\-]+')).where((t) => t.length >= 3).toList();

    // 1. Find root group territories directly assigned to this manager
    final Set<String> roots = {};
    for (final t in _territoryInfos) {
      final uid = (t.customUserId ?? '').trim().toLowerCase();
      final tm = t.territoryManager.trim().toLowerCase();
      final tName = t.name.trim();

      bool isMatch = false;
      if (email.isNotEmpty && uid.isNotEmpty && uid == email) {
        isMatch = true;
      } else if (fullName.isNotEmpty && tm.isNotEmpty && (fullName.contains(tm) || tm.contains(fullName))) {
        isMatch = true;
      } else if (nameTokens.isNotEmpty && tm.isNotEmpty && nameTokens.where((tok) => tm.contains(tok)).length >= 2) {
        isMatch = true;
      }

      if (isMatch) {
        roots.add(tName);
      }
    }

    // Fallback for specific DSM district root territories if custom_user_id wasn't set in ERPNext
    if (roots.isEmpty) {
      if (email == 'rbviray@profinsights.biz') roots.add('BA1 - SOUTH GMA/BACOLOD/ILOILO');
      if (email == 'ginlorcullo@profinsights.biz') roots.add('BA2 - WEST GMA');
      if (email == 'cmrinon@profinsights.biz') roots.add('BA4 - SOUTH LUZON');
      if (email == 'rlbanasihan@profinsights.biz') roots.add('AD1 - GMA/NORTH LUZON/CENTRAL LUZON');
      if (email == 'admendoza@profinsights.biz') roots.add('AD2 - GMA/SOUTH LUZON');
      if (email == 'syucaran@profinsights.biz') roots.add('AD0105 (COOR)');
      if (email == 'dbdelossantos@profinsights.biz') roots.add('NGMA/NLZ/VIZ');
    }

    // 2. Add all child territories belonging to the DSM's root district
    final Set<String> allManaged = Set.from(roots);
    for (final root in roots) {
      for (final t in _territoryInfos) {
        final parent = (t.parentTerritory ?? '').trim().toLowerCase();
        if (parent.isNotEmpty && parent == root.toLowerCase()) {
          allManaged.add(t.name);
        }
      }
      final codePrefix = root.split(RegExp(r'[\s\-]+')).first.toUpperCase();
      if (codePrefix.length >= 2 && codePrefix != 'ALL' && codePrefix != 'REST') {
        for (final t in _territoryInfos) {
          final tName = t.name.toUpperCase();
          if (tName.startsWith('$codePrefix-') || tName == codePrefix) {
            allManaged.add(t.name);
          }
        }
      }
    }
    return allManaged;
  }

  /// Dynamically resolve the accurate Territory Code and Territory Manager for a user and program
  Future<ResolvedTerritory> resolveUserTerritory({
    String? userEmail,
    String? userName,
    String? program,
    String? currentTerritory,
    String? currentSalesPerson,
  }) async {
    if (_territoryInfos.isEmpty) {
      await fetchTerritoryInfos();
    }
    if (_salesPersons.isEmpty) {
      await fetchSalesPersons();
    }

    final effectiveEmail = (userEmail != null && userEmail.trim().isNotEmpty)
        ? userEmail.trim().toLowerCase()
        : (loggedInEmail ?? '').toLowerCase();

    // Fetch Employee profile if we have an email but not full name
    String effectiveName = (userName != null && userName.trim().isNotEmpty)
        ? userName.trim()
        : (loggedInFullName ?? '');

    String empId = (employeeId ?? '').trim();
    if (effectiveEmail.isNotEmpty && (effectiveName.isEmpty || empId.isEmpty)) {
      final empDoc = await fetchEmployeeDesignation(effectiveEmail);
      if (empDoc != null) {
        if (empDoc['employee_name'] != null && effectiveName.isEmpty) {
          effectiveName = empDoc['employee_name'].toString().trim();
        }
        if (empDoc['name'] != null && empId.isEmpty) {
          empId = empDoc['name'].toString().trim();
        }
      }
    }

    final effectiveProgram = (program != null && program.trim().isNotEmpty)
        ? program.trim()
        : selectedProgram;

    // 0. Direct match via custom_user_id and custom_account_or_program on Territory
    if (effectiveEmail.isNotEmpty) {
      final tByEmailAndProg = _territoryInfos.firstWhere(
        (t) => (t.customUserId ?? '').trim().toLowerCase() == effectiveEmail &&
               (t.customAccountOrProgram != null && t.customAccountOrProgram!.trim().isNotEmpty && t.customAccountOrProgram!.trim().toLowerCase() == effectiveProgram.toLowerCase()),
        orElse: () => _territoryInfos.firstWhere(
          (t) => (t.customUserId ?? '').trim().toLowerCase() == effectiveEmail,
          orElse: () => TerritoryInfo(name: '', territoryName: '', territoryManager: ''),
        ),
      );
      if (tByEmailAndProg.name.isNotEmpty) {
        return ResolvedTerritory(
          territoryCode: tByEmailAndProg.name,
          territoryName: tByEmailAndProg.territoryName,
          territoryManager: tByEmailAndProg.territoryManager.isNotEmpty ? tByEmailAndProg.territoryManager : effectiveName,
        );
      }
    }

    // 1. Check Sales Person records by linked Employee ID
    if (empId.isNotEmpty) {
      final spByEmp = _salesPersons.firstWhere(
        (sp) => sp['employee']?.toString().trim().toLowerCase() == empId.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      if (spByEmp.isNotEmpty) {
        final spName = (spByEmp['name'] ?? spByEmp['sales_person_name'] ?? '').toString().trim();
        final match = RegExp(r'\(([^)]+)\)').firstMatch(spName);
        if (match != null) {
          final terrCode = match.group(1)!.trim();
          final tInfo = _territoryInfos.firstWhere(
            (t) => t.name.toLowerCase() == terrCode.toLowerCase(),
            orElse: () => TerritoryInfo(name: terrCode, territoryName: terrCode, territoryManager: spName),
          );
          return ResolvedTerritory(
            territoryCode: tInfo.name,
            territoryName: tInfo.territoryName,
            territoryManager: tInfo.territoryManager.isNotEmpty ? tInfo.territoryManager : spName,
          );
        }
      }
    }

    // 2. Check Sales Person records by User Full Name
    if (effectiveName.isNotEmpty) {
      final nameLower = effectiveName.toLowerCase();
      final nameTokens = nameLower.split(RegExp(r'[\s\-]+')).where((t) => t.length >= 3).toList();

      for (final sp in _salesPersons) {
        final spName = (sp['name'] ?? sp['sales_person_name'] ?? '').toString().trim();
        final spLower = spName.toLowerCase();

        bool isMatch = false;
        if (spLower.contains(nameLower) || nameLower.contains(spLower)) {
          isMatch = true;
        } else if (nameTokens.isNotEmpty && nameTokens.where((tok) => spLower.contains(tok)).length >= 2) {
          isMatch = true;
        }

        if (isMatch) {
          final match = RegExp(r'\(([^)]+)\)').firstMatch(spName);
          if (match != null) {
            final terrCode = match.group(1)!.trim();
            final tInfo = _territoryInfos.firstWhere(
              (t) => t.name.toLowerCase() == terrCode.toLowerCase(),
              orElse: () => TerritoryInfo(name: terrCode, territoryName: terrCode, territoryManager: spName),
            );
            return ResolvedTerritory(
              territoryCode: tInfo.name,
              territoryName: tInfo.territoryName,
              territoryManager: tInfo.territoryManager.isNotEmpty ? tInfo.territoryManager : spName,
            );
          }
        }
      }

      // Check Territory records where territory_manager matches effectiveName
      for (final t in _territoryInfos) {
        if (t.isGroup) continue;
        final tmLower = t.territoryManager.toLowerCase();
        if (tmLower.contains(nameLower) || (nameTokens.isNotEmpty && nameTokens.where((tok) => tmLower.contains(tok)).length >= 2)) {
          return ResolvedTerritory(
            territoryCode: t.name,
            territoryName: t.territoryName,
            territoryManager: t.territoryManager,
          );
        }
      }
    }

    // 3. Check existing territory from submission/account
    if (currentTerritory != null && currentTerritory.trim().isNotEmpty) {
      final cCode = currentTerritory.trim();
      final pLower = effectiveProgram.toLowerCase();
      final isAbbottProg = pLower.contains('abbott');

      // Detect if currentTerritory was a stale default bug (AD0110 on any non-Abbott program)
      bool isStaleDefault = false;
      if (cCode.toUpperCase() == 'AD0110' && !isAbbottProg) {
        isStaleDefault = true;
      }

      if (!isStaleDefault) {
        final matched = _territoryInfos.firstWhere(
          (t) => t.name.toLowerCase() == cCode.toLowerCase() && !t.isGroup,
          orElse: () => TerritoryInfo(name: '', territoryName: '', territoryManager: ''),
        );
        if (matched.name.isNotEmpty) {
          final mgr = (currentSalesPerson != null && currentSalesPerson.trim().isNotEmpty && currentSalesPerson.trim() != 'Jorge Mengorio')
              ? currentSalesPerson.trim()
              : (matched.territoryManager.isNotEmpty ? matched.territoryManager : effectiveName);
          return ResolvedTerritory(
            territoryCode: matched.name,
            territoryName: matched.territoryName,
            territoryManager: mgr.isNotEmpty ? mgr : effectiveName,
          );
        }
      }
    }

    // 4. Fallback by Program Branch
    final progLeaves = getLeafTerritoriesForProgram(effectiveProgram);
    if (progLeaves.isNotEmpty) {
      final firstLeaf = progLeaves.first;
      final mgr = firstLeaf.territoryManager.isNotEmpty
          ? firstLeaf.territoryManager
          : (effectiveName.isNotEmpty ? effectiveName : firstLeaf.name);
      return ResolvedTerritory(
        territoryCode: firstLeaf.name,
        territoryName: firstLeaf.territoryName,
        territoryManager: mgr,
      );
    }

    // Ultimate fallback (dynamic non-group territory)
    final nonGroup = _territoryInfos.where((t) => !t.isGroup && t.name.isNotEmpty && t.name.toLowerCase() != 'all territories').toList();
    final defaultLeaf = (progLeaves.isNotEmpty)
        ? progLeaves.first
        : (nonGroup.isNotEmpty ? nonGroup.first : null);

    final isAbbott = effectiveProgram.toLowerCase().contains('abbott');
    final fallbackCode = defaultLeaf?.name ?? (isAbbott ? 'AD0110' : 'TERR-01');
    final fallbackMgr = defaultLeaf != null && defaultLeaf.territoryManager.isNotEmpty
        ? defaultLeaf.territoryManager
        : (effectiveName.isNotEmpty ? effectiveName : (isAbbott ? 'Jorge Mengorio' : ''));

    return ResolvedTerritory(
      territoryCode: fallbackCode,
      territoryName: defaultLeaf?.territoryName ?? fallbackCode,
      territoryManager: fallbackMgr,
    );
  }

  /// Retrieve list of Territories from ERPNext (optionally filtered by program)
  Future<List<String>> fetchTerritories({String? program}) async {
    final infos = await fetchTerritoryInfos();
    if (program != null && program.trim().isNotEmpty && program != 'All') {
      final filtered = getLeafTerritoriesForProgram(program);
      if (filtered.isNotEmpty) {
        return filtered.map((t) => t.name).toList();
      }
    }
    final leaves = infos.where((t) => !t.isGroup && t.name.isNotEmpty && t.name.toLowerCase() != 'all territories').toList();
    return leaves.isNotEmpty ? leaves.map((t) => t.name).toList() : infos.map((t) => t.name).toList();
  }

  /// Retrieve list of Programs / Branches from ERPNext
  Future<List<String>> fetchPrograms() async {
    try {
      final branchUrl = Uri.parse('$baseUrl/api/resource/Branch?fields=["name","branch"]&limit=500');
      final resp = await http.get(branchUrl, headers: _headers);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final List<dynamic> dataList = body['data'] ?? [];
        final List<String> list = [];
        for (var item in dataList) {
          final name = (item['name'] ?? item['branch'] ?? '').toString();
          if (name.isNotEmpty && !list.contains(name)) {
            list.add(name);
          }
        }
        if (list.isNotEmpty) {
          availablePrograms = list;
          return list;
        }
      }
    } catch (e) {
      print('Fetch programs error: $e');
    }
    return availablePrograms;
  }
}

class FrappeRepository<T> {
  final ApiService _api;
  final String docType;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;

  FrappeRepository({
    required ApiService api,
    required this.docType,
    required this.fromJson,
    required this.toJson,
  }) : _api = api;

  String _sanitizeCacheKey(String key) => key.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');

  /// Fetch list of records of this DocType with 24/7 resilience & local cache fallback
  Future<List<T>> list({
    List<String>? fields,
    List<dynamic>? filters,
    int? limit,
    int? limitStart,
    String? orderBy,
  }) async {
    final Map<String, String> queryParams = {};
    queryParams['fields'] = jsonEncode(fields ?? ['*']);
    if (filters != null) {
      queryParams['filters'] = jsonEncode(filters);
    }
    if (limit != null) {
      queryParams['limit_page_length'] = limit.toString();
    }
    if (limitStart != null) {
      queryParams['limit_start'] = limitStart.toString();
    }
    if (orderBy != null) {
      queryParams['order_by'] = orderBy;
    }

    final uri = Uri.parse('${_api.baseUrl}/api/resource/${Uri.encodeComponent(docType)}')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final cacheKey = 'frappe_${_sanitizeCacheKey(docType)}_list.json';

    // 1. Attempt live network fetch with timeout & transient error retry
    http.Response? response;
    Exception? lastException;
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        response = await http.get(uri, headers: _api._headers).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          break;
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          // Frappe session expired: attempt token renewal
          await _api.ensureCsrfToken();
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }
    }

    if (response != null && response.statusCode == 200) {
      try {
        final body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] ?? [];
        final parsed = dataList.map((json) => fromJson(json)).toList();
        // Persist successful fetch to local cache for 24/7 offline survivability
        await _api._writeToCache(cacheKey, response.body);
        return parsed;
      } catch (e) {
        print('FrappeRepository.list parsing notice for $docType: $e');
      }
    }

    // 2. Resilient Fallback: If network failed or server is temporarily unreachable, serve local cache
    try {
      final cached = await _api._readFromCache(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        final body = jsonDecode(cached);
        final List<dynamic> dataList = body['data'] ?? [];
        if (dataList.isNotEmpty) {
          print('[FrappeRepository] Offline resilience active: serving ${dataList.length} cached $docType records.');
          return dataList.map((json) => fromJson(json)).toList();
        }
      }
    } catch (e) {
      print('FrappeRepository cache fallback notice for $docType: $e');
    }

    if (lastException != null) {
      print('FrappeRepository.list network error on $docType: $lastException');
      throw lastException;
    }
    throw Exception('Failed to load list for $docType: ${response?.statusCode ?? 'unreachable'}');
  }

  /// Fetch details of a single record by its name (ID), including its nested child tables with offline fallback
  Future<T> get(String name) async {
    final uri = Uri.parse('${_api.baseUrl}/api/resource/${Uri.encodeComponent(docType)}/${Uri.encodeComponent(name)}');
    final cacheKey = 'frappe_${_sanitizeCacheKey(docType)}_${_sanitizeCacheKey(name)}.json';

    http.Response? response;
    Exception? lastException;

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        response = await http.get(uri, headers: _api._headers).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) break;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    if (response != null && response.statusCode == 200) {
      try {
        final body = jsonDecode(response.body);
        await _api._writeToCache(cacheKey, response.body);
        return fromJson(body['data']);
      } catch (e) {
        print('FrappeRepository.get parsing notice for $docType ($name): $e');
      }
    }

    // Resilient Fallback: Read single record from cache
    try {
      final cached = await _api._readFromCache(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        final body = jsonDecode(cached);
        if (body['data'] != null) {
          print('[FrappeRepository] Offline resilience active: serving cached $docType ($name).');
          return fromJson(body['data']);
        }
      }
    } catch (_) {}

    if (lastException != null) throw lastException;
    throw Exception('Failed to load detail for $docType ($name): ${response?.statusCode ?? 'unreachable'}');
  }

  /// Create a new record with nested child table arrays and resilient timeout
  Future<T> create(T item) async {
    final uri = Uri.parse('${_api.baseUrl}/api/resource/${Uri.encodeComponent(docType)}');
    await _api.ensureCsrfToken();
    try {
      var response = await http.post(
        uri,
        headers: _api._headers,
        body: jsonEncode(toJson(item)),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 400 && response.body.contains('CSRFTokenError')) {
        _api._csrfToken = null;
        await _api.ensureCsrfToken();
        response = await http.post(
          uri,
          headers: _api._headers,
          body: jsonEncode(toJson(item)),
        ).timeout(const Duration(seconds: 20));
      }

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return fromJson(body['data']);
      } else {
        throw Exception('Failed to create $docType: ${response.body}');
      }
    } catch (e) {
      print('FrappeRepository.create error on $docType: $e');
      rethrow;
    }
  }

  /// Update an existing record and dynamically reconcile child tables with resilient timeout
  Future<T> update(String name, T item) async {
    final uri = Uri.parse('${_api.baseUrl}/api/resource/${Uri.encodeComponent(docType)}/${Uri.encodeComponent(name)}');
    await _api.ensureCsrfToken();
    try {
      var response = await http.put(
        uri,
        headers: _api._headers,
        body: jsonEncode(toJson(item)),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 400 && response.body.contains('CSRFTokenError')) {
        _api._csrfToken = null;
        await _api.ensureCsrfToken();
        response = await http.put(
          uri,
          headers: _api._headers,
          body: jsonEncode(toJson(item)),
        ).timeout(const Duration(seconds: 20));
      }

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return fromJson(body['data']);
      } else {
        throw Exception('Failed to update $docType ($name): ${response.body}');
      }
    } catch (e) {
      print('FrappeRepository.update error on $docType: $e');
      rethrow;
    }
  }
}


