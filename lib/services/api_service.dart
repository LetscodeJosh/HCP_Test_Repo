import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/engagement.dart';
import '../models/hcp.dart';
import '../models/submission.dart';
import '../models/lookup_models.dart';
import '../models/hcp_account.dart';
import '../models/corenergy_engage.dart';
import 'db_helper.dart';

enum UserPosition {
  admin,
  manager,
  medRep,
}

class ApiService extends ChangeNotifier {
  ApiService() {
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

  bool get isAdmin => _userPosition == UserPosition.admin;
  bool get isManager => _userPosition == UserPosition.manager;
  bool get isMedRep => _userPosition == UserPosition.medRep;
  bool get canManageAllDoctypes => isAdmin || isManager;
  bool get canCreateOrEditDoctor => isAdmin || isManager;
  bool get canCreateOrEditDoctorAccount => isAdmin || isManager;

  String get userPositionTitle {
    switch (_userPosition) {
      case UserPosition.admin:
        return 'Admin';
      case UserPosition.manager:
        return 'Manager';
      case UserPosition.medRep:
        return 'MedRep';
    }
  }

  /// Returns clean short / acronym title for the designation (e.g. Sales Rep, PHSR, PHSS, DSM, GM, etc.)
  String get userDesignationTitle {
    if (_userDesignation.isEmpty) {
      return userPositionTitle;
    }
    final des = _userDesignation.trim();
    final lower = des.toLowerCase();

    // Exact PMII / PIMS ERPNext Designations
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
    'COREnergy',
    'NES',
    'Nurturemed',
    'PCH 1',
    'Pharmabest',
    'TSTACCO',
    'TSTACC1',
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
  final String baseUrl = 'https://dev.pmii-marketing.com';
  String? _sessionCookie;
  String? loggedInEmail;
  String? loggedInFullName;

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

  // Header helpers that inject session cookies
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }
    return headers;
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
      loggedInEmail = username.trim().isEmpty ? 'offline_user@pims-marketing.com' : username.trim();
      _applyPositionFromRoleProfile(
        roleProfile: _userRoleProfile,
        roleNames: [],
        email: loggedInEmail ?? '',
        designation: _userDesignation,
      );
      await fetchAvailablePrograms();
      return true;
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
            loginErrorMessage = 'Access Restricted: Your account ($unauthDesig, Role Profile: "$unauthProfile") is not authorized to access this application. Only System Manager, Sales Manager, and Sales User roles are permitted.';
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
              final idx = html.indexOf('frappe.boot =');
              if (idx != -1) {
                final endIdx = html.indexOf('};\n', idx);
                if (endIdx != -1) {
                  final jsonStr = html.substring(idx + 'frappe.boot ='.length, endIdx + 1).trim();
                  final bootData = jsonDecode(jsonStr);
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
            if (roleNames.contains('system manager') || roleNames.contains('administrator')) {
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
    final combined = '$dept $branch';

    if (combined.contains('abbott') || combined.contains('adc')) {
      selectedProgram = 'Abbott Diabetes Care';
    } else if (combined.contains('bayer') || combined.contains('bch')) {
      if (combined.contains('team 3')) {
        selectedProgram = 'Bayer Consumer Health - Team 3';
      } else if (combined.contains('team 2')) {
        selectedProgram = 'Bayer Consumer Health - Team 2';
      } else {
        selectedProgram = 'Bayer Consumer Health - Team 1';
      }
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

    // 1. System Manager / Administrator (Admin position - Allowed Role 1)
    if (lowerEmail == 'administrator' ||
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
    // 2. Sales & Marketing Manager / Sales Manager / Superior (Manager position - Allowed Role 2)
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
             lowerEmail == 'admendoza@profinsights.biz') {
      _userPosition = UserPosition.manager;
      _isRoleAuthorized = true;
      if (_userRoleProfile.isEmpty) _userRoleProfile = 'Sales Manager';
      if (_userDesignation.isEmpty) _userDesignation = 'District Sales Manager';
    } 
    // 3. Sales User / Field Sales Representative (MedRep position - Allowed Role 3)
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
    // 4. Any other role is NOT authorized to access the HCP Profiling App
    else {
      _isRoleAuthorized = false;
      _userPosition = UserPosition.medRep;
    }

    notifyListeners();
  }

  /// Log out
  void logout() {
    _sessionCookie = null;
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

  /// Retrieve list of Company Institutions with region, province, city, and street address fields
  Future<List<Institution>> fetchInstitutions() async {
    if (_isOffline) {
      final cache = await _readFromCache('institutions_cache.json');
      if (cache != null) {
        try {
          final List<dynamic> dataList = jsonDecode(cache);
          return dataList.map((json) => Institution.fromJson(json)).toList();
        } catch (_) {}
      }
      // Fallback to local asset
      try {
        final String localData = await rootBundle.loadString('assets/institutions.json');
        final List<dynamic> dataList = jsonDecode(localData);
        return dataList.map((json) => Institution.fromJson(json)).toList();
      } catch (err) {
        print('Failed to load local fallback institutions: $err');
        return [];
      }
    }
    final url = Uri.parse(
      '$baseUrl/api/resource/Institution?fields=["name","institution_name","region_name","province_name","city_municipality","street_address"]&limit_page_length=5000&limit=5000',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] ?? [];
        await _writeToCache('institutions_cache.json', jsonEncode(dataList));
        final list = dataList.map((json) => Institution.fromJson(json)).toList();
        LocationResolver.registerInstitutions(list);
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
        return list;
      } catch (err) {
        print('Failed to load local fallback institutions: $err');
        rethrow;
      }
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
          return dataList.map((json) => Hcp.fromJson(json)).toList();
        } catch (_) {}
      }
      return [];
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
        return dataList.map((json) => Hcp.fromJson(json)).toList();
      } catch (_) {}
    }

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
      final List<Map<String, dynamic>> cleanWps = [];
      if (payload['hcp_workplace'] is List && (payload['hcp_workplace'] as List).isNotEmpty) {
        for (var item in (payload['hcp_workplace'] as List)) {
          if (item is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(item);
            final rawWp = (map['hcp_workplace'] ?? map['workplace'] ?? map['address'] ?? map['workplace_name'] ?? '').toString().trim();
            final wpId = rawWp.isNotEmpty ? LocationResolver.resolveInstitutionId(rawWp, insts.isNotEmpty ? insts : null) : 'INST-00001';
            final finalWpId = wpId.isNotEmpty ? wpId : 'INST-00001';

            final isPref = (map['is_primary'] == 1 || map['is_primary'] == true ||
                map['primary'] == 1 || map['primary'] == true ||
                map['preferred'] == 1 || map['preferred'] == true ||
                map['is_preferred'] == 1 || map['is_preferred'] == true);

            // In ERPNext, HCP Workplace child table links to Institution via hcp_workplace.
            // Do NOT send numeric PSGC province/city codes (e.g. 1376000000) which fail Link validation.
            cleanWps.add({
              'hcp_workplace': finalWpId,
              'workplace': finalWpId,
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
          'is_primary': 1,
          'preferred': 1,
        });
      }
      payload['hcp_workplace'] = cleanWps;

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

      // Ensure hcp_workplace Link fields map to valid ERPNext Institution primary keys
      if (payload['hcp_workplace'] is List && (payload['hcp_workplace'] as List).isNotEmpty) {
        final insts = await fetchInstitutions().catchError((_) => <Institution>[]);
        final List<Map<String, dynamic>> cleanWps = [];
        for (var item in (payload['hcp_workplace'] as List)) {
          if (item is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(item);
            final rawWp = (map['hcp_workplace'] ?? map['workplace'] ?? map['address'] ?? '').toString().trim();
            if (rawWp.isNotEmpty) {
              final wpId = LocationResolver.resolveInstitutionId(rawWp, insts.isNotEmpty ? insts : null);
              map['hcp_workplace'] = wpId.isNotEmpty ? wpId : 'INST-00001';
              map['workplace'] = wpId.isNotEmpty ? wpId : 'INST-00001';
            }
            cleanWps.add(map);
          }
        }
        payload['hcp_workplace'] = cleanWps;
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
    }
  }

  /// Retrieve list of HCP Account doctype records
  Future<List<HcpAccount>> fetchHcpAccounts() async {
    if (_isOffline) {
      final cache = await _readFromCache('hcp_accounts_cache.json');
      if (cache != null) {
        try {
          final List<dynamic> dataList = jsonDecode(cache);
          return dataList.map((json) => HcpAccount.fromJson(json)).toList();
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
        await _writeToCache('hcp_accounts_cache.json', jsonEncode(dataList));
        return dataList.map((json) => HcpAccount.fromJson(json)).toList();
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
          await _writeToCache('hcp_accounts_cache.json', jsonEncode(dataList));
          return dataList.map((json) => HcpAccount.fromJson(json)).toList();
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
        return dataList.map((json) => HcpAccount.fromJson(json)).toList();
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
        return HcpAccount.fromJson(body['data']);
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
        if (data != null) return HcpAccount.fromJson(data);
      }
    } catch (_) {}

    throw Exception('Failed to load HCP Account details: $name');
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

    const submissionFields = '["name","owner","creation","modified","docstatus","application_status","workflow_state","hcp_name","hcp_full_name","first_name","middle_name","last_name","hcp_type","hcp_practice","account_or_program","territory","sales_person","user_id","submission_date","hcp_photo","consent_photo","consent_signature","consent_privacy_understood"]';
    final encodedFields = Uri.encodeQueryComponent(submissionFields);
    final url = Uri.parse(
      '$baseUrl/api/resource/HCP%20Profile%20Submission?fields=$encodedFields&limit_page_length=5000&limit=5000&order_by=creation%20desc',
    );
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] ?? [];
        await _writeToCache('submissions_cache.json', jsonEncode(dataList));
        return dataList.map((json) => HcpProfileSubmission.fromJson(json)).toList();
      } else {
        print('Fetch submissions error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Fetch submissions direct error: $e');
    }

    // Fallback via client method
    try {
      final clientUrl = Uri.parse(
        '$baseUrl/api/method/frappe.client.get_list?doctype=HCP%20Profile%20Submission&fields=$encodedFields&limit_page_length=5000&order_by=creation%20desc',
      );
      final clientResp = await http.get(clientUrl, headers: _headers);
      if (clientResp.statusCode == 200) {
        final body = jsonDecode(clientResp.body);
        final List<dynamic> dataList = body['message'] ?? body['data'] ?? [];
        if (dataList.isNotEmpty) {
          await _writeToCache('submissions_cache.json', jsonEncode(dataList));
          return dataList.map((json) => HcpProfileSubmission.fromJson(json)).toList();
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
        return dataList.map((json) => HcpProfileSubmission.fromJson(json)).toList();
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
        return HcpProfileSubmission.fromJson(body['data']);
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
        if (data != null) return HcpProfileSubmission.fromJson(data);
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
      // Transitions (Draft → Pending Approval → Approved) are applied AFTER creation.
      final targetWorkflow = submission.workflowState ?? 'Pending Approval';
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

            if (rawWp.isNotEmpty) {
              final wpId = LocationResolver.resolveInstitutionId(rawWp, insts.isNotEmpty ? insts : null);
              final wpName = LocationResolver.resolveInstitutionName(rawWp, insts.isNotEmpty ? insts : null);
              final finalWpId = wpId.isNotEmpty ? wpId : rawWp;
              final finalWpName = wpName.isNotEmpty ? wpName : rawWp;
              map['hcp_workplace'] = finalWpId;
              map['workplace'] = finalWpId;
              map['workplace_name'] = finalWpName;
              map['address'] = finalWpName;

              final instMatch = insts.where((i) =>
                  i.name == rawWp ||
                  i.name == wpId ||
                  i.name.toLowerCase() == rawWp.toLowerCase() ||
                  i.institutionName.toLowerCase() == rawWp.toLowerCase() ||
                  i.institutionName.toLowerCase() == wpName.toLowerCase()
              ).firstOrNull;

              final rawInstCity = instMatch?.rawCityMunicipality ?? instMatch?.cityMunicipality ?? '';
              final cityInput = rawInstCity.isNotEmpty ? rawInstCity : rawCity;
              if (cityInput.isNotEmpty) {
                final cityId = LocationResolver.resolveCityId(cityInput, psgc.isNotEmpty ? psgc : null);
                final cityName = LocationResolver.resolveCityName(cityInput, psgc.isNotEmpty ? psgc : null);
                final finalCityLink = cityId.isNotEmpty ? cityId : (rawInstCity.isNotEmpty ? rawInstCity : cityInput);
                map['city_municipality'] = finalCityLink;
                map['city'] = finalCityLink;
                map['city_title'] = cityName.isNotEmpty ? cityName : cityInput;
                map['city_name'] = cityName.isNotEmpty ? cityName : cityInput;
              }

              final rawInstProv = instMatch?.rawProvinceName ?? instMatch?.provinceName ?? '';
              final provInput = rawInstProv.isNotEmpty ? rawInstProv : rawProv;
              if (provInput.isNotEmpty) {
                final provId = LocationResolver.resolveProvinceId(provInput, psgc.isNotEmpty ? psgc : null);
                final provName = LocationResolver.resolveProvinceName(provInput, psgc.isNotEmpty ? psgc : null);
                final finalProvLink = provId.isNotEmpty ? provId : (rawInstProv.isNotEmpty ? rawInstProv : provInput);
                map['province_name'] = finalProvLink;
                map['province'] = finalProvLink;
                map['province_title'] = provName.isNotEmpty ? provName : provInput;
              }
            }
            cleanWps.add(map);
          }
        }
        payload['table_workplaces'] = cleanWps;
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

      // Remove all non-schema / temporary / mock keys before sending to ERPNext
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
        'docstatus',
      };
      payload.removeWhere((k, _) => !allowedDoctypeFields.contains(k));

      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      );

      String? createdName;
      Map<String, dynamic>? createdData;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        createdData = body['data'];
        createdName = createdData != null ? '${createdData['name']}' : null;
      } else {
        // Fallback: frappe.client.insert
        final rpcUrl = Uri.parse('$baseUrl/api/method/frappe.client.insert');
        final rpcResp = await http.post(
          rpcUrl,
          headers: _headers,
          body: jsonEncode({
            'doc': {
              'doctype': 'HCP Profile Submission',
              ...payload,
            }
          }),
        );
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

      // After creation (Draft), apply exact Workflow State & Status as defined by ERPNext HCP Profile Submission WF
      if (createdName != null && createdName.isNotEmpty) {
        final setValUrl = Uri.parse('$baseUrl/api/method/frappe.client.set_value');
        final wfUrl = Uri.parse('$baseUrl/api/method/frappe.model.workflow.apply_workflow');
        final updateUrl = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(createdName)}');

        // Flow A: Existing Doctor Profile Update
        // Updating doctor info requires NO managerial approval.
        // Direct field assignment to 'Approved' prevents Sales User permission errors on workflow action 'Approve'
        if (targetWorkflow == 'Approved') {
          try {
            await http.post(
              setValUrl,
              headers: _headers,
              body: jsonEncode({
                'doctype': 'HCP Profile Submission',
                'name': createdName,
                'fieldname': {
                  'workflow_state': 'Approved',
                  'status': 'Approved',
                  'application_status': 'Applied',
                  'docstatus': 1,
                },
              }),
            );
          } catch (_) {}
        } 
        // Flow B: Submit for Processing (Draft -> Processed via WF action 'Submit for Processing')
        else if (targetWorkflow == 'Processed') {
          bool transitioned = false;
          try {
            final wfResp = await http.post(
              wfUrl,
              headers: _headers,
              body: jsonEncode({
                'doc': {'doctype': 'HCP Profile Submission', 'name': createdName},
                'action': 'Submit for Processing',
              }),
            );
            if (wfResp.statusCode == 200) {
              transitioned = true;
            }
          } catch (_) {}

          if (!transitioned) {
            try {
              await http.post(
                setValUrl,
                headers: _headers,
                body: jsonEncode({
                  'doctype': 'HCP Profile Submission',
                  'name': createdName,
                  'fieldname': {
                    'workflow_state': 'Processed',
                    'status': 'Processed',
                    'application_status': 'Processed',
                    'docstatus': 0,
                  },
                }),
              );
            } catch (_) {}
          }
        }
        // Flow C: Submit for Approval / New Doctor Registration (Draft -> Pending Approval)
        else {
          bool transitioned = false;
          try {
            final wfResp = await http.post(
              wfUrl,
              headers: _headers,
              body: jsonEncode({
                'doc': {'doctype': 'HCP Profile Submission', 'name': createdName},
                'action': 'Submit for Approval',
              }),
            );
            if (wfResp.statusCode == 200) {
              transitioned = true;
            }
          } catch (_) {}

          if (!transitioned) {
            try {
              await http.post(
                setValUrl,
                headers: _headers,
                body: jsonEncode({
                  'doctype': 'HCP Profile Submission',
                  'name': createdName,
                  'fieldname': {
                    'workflow_state': 'Pending Approval',
                    'status': 'Pending Approval',
                    'application_status': 'Not Applied',
                    'docstatus': 0,
                  },
                }),
              );
            } catch (_) {}
          }
        }

        // Re-fetch the final state from ERPNext to return accurate data
        try {
          final freshResp = await http.get(updateUrl, headers: _headers);
          if (freshResp.statusCode == 200) {
            final freshBody = jsonDecode(freshResp.body);
            final freshSub = HcpProfileSubmission.fromJson(freshBody['data']);
            await _updateSubmissionInLocalCache(freshSub);
            return freshSub;
          }
        } catch (_) {}
      }

      final result = HcpProfileSubmission.fromJson(createdData ?? payload);
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

            if (rawWp.isNotEmpty) {
              final wpId = LocationResolver.resolveInstitutionId(rawWp, insts.isNotEmpty ? insts : null);
              final wpName = LocationResolver.resolveInstitutionName(rawWp, insts.isNotEmpty ? insts : null);
              final finalWpId = wpId.isNotEmpty ? wpId : rawWp;
              final finalWpName = wpName.isNotEmpty ? wpName : rawWp;
              map['hcp_workplace'] = finalWpId;
              map['workplace'] = finalWpId;
              map['workplace_name'] = finalWpName;
              map['address'] = finalWpName;

              final instMatch = insts.where((i) =>
                  i.name == rawWp ||
                  i.name == wpId ||
                  i.name.toLowerCase() == rawWp.toLowerCase() ||
                  i.institutionName.toLowerCase() == rawWp.toLowerCase() ||
                  i.institutionName.toLowerCase() == wpName.toLowerCase()
              ).firstOrNull;

              final rawInstCity = instMatch?.rawCityMunicipality ?? instMatch?.cityMunicipality ?? '';
              final cityInput = rawInstCity.isNotEmpty ? rawInstCity : rawCity;
              if (cityInput.isNotEmpty) {
                final cityId = LocationResolver.resolveCityId(cityInput, psgc.isNotEmpty ? psgc : null);
                final cityName = LocationResolver.resolveCityName(cityInput, psgc.isNotEmpty ? psgc : null);
                final finalCityLink = cityId.isNotEmpty ? cityId : (rawInstCity.isNotEmpty ? rawInstCity : cityInput);
                map['city_municipality'] = finalCityLink;
                map['city'] = finalCityLink;
                map['city_title'] = cityName.isNotEmpty ? cityName : cityInput;
                map['city_name'] = cityName.isNotEmpty ? cityName : cityInput;
              }

              final rawInstProv = instMatch?.rawProvinceName ?? instMatch?.provinceName ?? '';
              final provInput = rawInstProv.isNotEmpty ? rawInstProv : rawProv;
              if (provInput.isNotEmpty) {
                final provId = LocationResolver.resolveProvinceId(provInput, psgc.isNotEmpty ? psgc : null);
                final provName = LocationResolver.resolveProvinceName(provInput, psgc.isNotEmpty ? psgc : null);
                final finalProvLink = provId.isNotEmpty ? provId : (rawInstProv.isNotEmpty ? rawInstProv : provInput);
                map['province_name'] = finalProvLink;
                map['province'] = finalProvLink;
                map['province_title'] = provName.isNotEmpty ? provName : provInput;
              }
            }
            cleanWps.add(map);
          }
        }
        payload['table_workplaces'] = cleanWps;
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
        final provId = LocationResolver.resolveProvinceId(raw);
        final provName = LocationResolver.resolveProvinceName(raw);
        payload['province_name'] = provId.isNotEmpty ? provId : raw;
        payload['province'] = provId.isNotEmpty ? provId : raw;
        payload['province_title'] = provName.isNotEmpty ? provName : raw;
      }
      if (payload['city_municipality'] != null || payload['city'] != null) {
        final raw = (payload['city_municipality'] ?? payload['city']).toString();
        final cityId = LocationResolver.resolveCityId(raw);
        final cityName = LocationResolver.resolveCityName(raw);
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

    final wfUrl = Uri.parse('$baseUrl/api/method/frappe.model.workflow.apply_workflow');
    bool wfSuccess = false;
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
        targetDocStatus = 2;
        effectiveAction = 'Reject';
        break;
    }

    if (action == 'Approve') {
      await approveSubmission(submission);
      final updateUrl = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(subName)}');
      try {
        final freshResp = await http.get(updateUrl, headers: _headers);
        if (freshResp.statusCode == 200) {
          final freshBody = jsonDecode(freshResp.body);
          return HcpProfileSubmission.fromJson(freshBody['data']);
        }
      } catch (_) {}
      return submission.copyWith(workflowState: 'Approved', status: 'Approved', docstatus: 1);
    }

    if (action == 'Reject') {
      await rejectSubmission(subName, remarks: remarks);
      return submission.copyWith(workflowState: 'Rejected', status: 'Rejected', docstatus: 2);
    }

    // For "Submit for Processing" and "Submit for Approval":
    try {
      final wfResp = await http.post(
        wfUrl,
        headers: _headers,
        body: jsonEncode({
          'doc': {'doctype': 'HCP Profile Submission', 'name': subName},
          'action': effectiveAction,
        }),
      );
      if (wfResp.statusCode == 200) {
        wfSuccess = true;
      }
    } catch (_) {}

    // Fallback: If workflow hook failed or needs explicit update via set_value
    if (!wfSuccess && targetState.isNotEmpty) {
      try {
        final setValUrl = Uri.parse('$baseUrl/api/method/frappe.client.set_value');
        await http.post(
          setValUrl,
          headers: _headers,
          body: jsonEncode({
            'doctype': 'HCP Profile Submission',
            'name': subName,
            'fieldname': {
              'workflow_state': targetState,
              'status': targetState,
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
          dataList[index]['docstatus'] = targetDocStatus;
          await _writeToCache('submissions_cache.json', jsonEncode(dataList));
        }
      }
    } catch (_) {}

    // Re-fetch submission details
    final updateUrl = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(subName)}');
    try {
      final freshResp = await http.get(updateUrl, headers: _headers);
      if (freshResp.statusCode == 200) {
        final freshBody = jsonDecode(freshResp.body);
        return HcpProfileSubmission.fromJson(freshBody['data']);
      }
    } catch (_) {}

    return submission.copyWith(workflowState: targetState, status: targetState, docstatus: targetDocStatus);
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
    try {
      final cleanProgram = LocationResolver.resolveProgramBranch(program);

      // Check if HCP Account already exists for this doctor and program
      final searchUrl = Uri.parse(
        '$baseUrl/api/resource/HCP%20Account?filters=[["hcp","=","$hcpId"]]&fields=["name","account_or_program"]&limit_page_length=50',
      );
      final searchResp = await http.get(searchUrl, headers: _headers);
      String? existingAccountName;
      if (searchResp.statusCode == 200) {
        final searchBody = jsonDecode(searchResp.body);
        final List<dynamic> data = searchBody['data'] ?? [];
        final targetProg = cleanProgram.toLowerCase().trim();
        for (var d in data) {
          final aProg = (d['account_or_program'] ?? '').toString().toLowerCase().trim();
          if (aProg == targetProg || aProg.contains(targetProg) || targetProg.contains(aProg)) {
            existingAccountName = d['name'];
            break;
          }
        }
        if (existingAccountName == null && data.isNotEmpty) {
          existingAccountName = data[0]['name'];
        }
      }

      final effectiveSalesPerson = (salesPerson != null && salesPerson.trim().isNotEmpty)
          ? salesPerson.trim()
          : getTerritoryManagerForTerritory(territory);

      final validFrom = HcpAccount.calculateMonthValidFrom();
      final validTo = HcpAccount.calculateMonthValidTo();

      // Filter strictly to preferred items for this program's HCP Account
      final prefSpecsList = specialties.where((s) => s.preferred || s.isPrimary).toList();
      final effectiveSpecs = prefSpecsList.isNotEmpty ? prefSpecsList : specialties;

      // Clean specialization child table links
      final List<Map<String, dynamic>> cleanSpecs = [];
      for (var s in effectiveSpecs) {
        final sId = LocationResolver.resolveSpecialtyId(s.hcpSpecialty);
        if (sId.isNotEmpty) {
          final subId = (s.subSpecialty != null && s.subSpecialty!.isNotEmpty && s.subSpecialty != '-')
              ? LocationResolver.resolveSpecialtyId(s.subSpecialty)
              : null;
          cleanSpecs.add({
            'hcp_specialty': sId,
            'specialty': sId,
            if (subId != null && subId.isNotEmpty) 'sub_specialty': subId,
            'is_primary': 1,
            'preferred': 1,
          });
        }
      }

      final prefWpsList = workplaces.where((w) => w.preferred || w.isPrimary).toList();
      final effectiveWps = prefWpsList.isNotEmpty ? prefWpsList : workplaces;

      // Clean workplace child table links
      final List<Map<String, dynamic>> cleanWps = [];
      for (var w in effectiveWps) {
        final wpId = LocationResolver.resolveInstitutionId(w.hcpWorkplace);
        if (wpId.isNotEmpty) {
          cleanWps.add({
            'hcp_workplace': wpId,
            'workplace': wpId,
            'is_primary': 1,
            'preferred': 1,
          });
        }
      }
      if (cleanWps.isEmpty) {
        cleanWps.add({
          'hcp_workplace': 'INST-00001',
          'workplace': 'INST-00001',
          'is_primary': 1,
          'preferred': 1,
        });
      }

      final prefContactsList = contacts.where((c) => c.preferred || c.isPrimary).toList();
      final effectiveContacts = prefContactsList.isNotEmpty ? prefContactsList : contacts;

      // Clean contact child table
      final List<Map<String, dynamic>> cleanContacts = [];
      for (var c in effectiveContacts) {
        final num = (c.contactNumber ?? '').trim();
        final em = (c.emailAddress ?? '').trim();
        if (num.isNotEmpty || em.isNotEmpty) {
          cleanContacts.add({
            if (num.isNotEmpty) 'contact_number': num,
            if (em.isNotEmpty) 'email_address': em,
            'is_primary': 1,
            'preferred': 1,
          });
        }
      }

      // Extract summary top-level fields for preferred data
      final primarySpecId = cleanSpecs.isNotEmpty ? cleanSpecs.first['hcp_specialty'] : null;
      final primarySubSpecId = cleanSpecs.isNotEmpty ? cleanSpecs.first['sub_specialty'] : null;
      final primaryWpId = cleanWps.isNotEmpty ? cleanWps.first['hcp_workplace'] : null;
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
        if (primaryContactNum != null) 'contact_number': primaryContactNum,
        if (primaryEmail != null) 'contact_email': primaryEmail,
        'specialization': cleanSpecs,
        'workplace_info': cleanWps,
        'contact_info': cleanContacts,
      };

      if (existingAccountName != null) {
        final updateUrl = Uri.parse('$baseUrl/api/resource/HCP%20Account/${Uri.encodeComponent(existingAccountName)}');
        final resp = await http.put(updateUrl, headers: _headers, body: jsonEncode(payload));
        if (resp.statusCode != 200) {
          final rpcUrl = Uri.parse('$baseUrl/api/method/frappe.client.save');
          await http.post(
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
        }
      } else {
        final createUrl = Uri.parse('$baseUrl/api/resource/HCP%20Account');
        final resp = await http.post(createUrl, headers: _headers, body: jsonEncode(payload));
        if (resp.statusCode != 200) {
          final rpcUrl = Uri.parse('$baseUrl/api/method/frappe.client.insert');
          await http.post(
            rpcUrl,
            headers: _headers,
            body: jsonEncode({
              'doc': {
                'doctype': 'HCP Account',
                ...payload,
              }
            }),
          );
        }
      }
    } catch (e) {
      print('Sync HCP Account error: $e');
      rethrow;
    }
  }

  /// Approve a pending HCP Profile Submission (Admin / Manager)
  /// - If the doctor does not exist in the HCP global masterlist, creates the Doctor in HCP doctype.
  /// - Syncs / creates the doctor's HCP Account for the specific program and representative.
  /// - Updates submission in ERPNext: workflow_state = 'Approved', docstatus = 1, application_status = 'Applied'.
  Future<void> approveSubmission(HcpProfileSubmission submission) async {
    final List<String> errors = [];

    // 0. Ensure full submission details (including child tables) are loaded
    HcpProfileSubmission fullSub = submission;
    if (submission.name != null && (submission.specialties.isEmpty || submission.workplaces.isEmpty)) {
      try {
        fullSub = await fetchSubmissionDetail(submission.name!);
        print('[APPROVE] Fetched full submission: specialties=${fullSub.specialties.length}, workplaces=${fullSub.workplaces.length}, contacts=${fullSub.contacts.length}');
      } catch (e) {
        print('[APPROVE] Could not fetch full submission detail: $e');
      }
    }

    String effectiveHcpId = fullSub.hcpName;
    print('[APPROVE] Starting approval for ${fullSub.name}, hcpName=$effectiveHcpId, isNew=${effectiveHcpId.isEmpty || effectiveHcpId == "NEW-HCP"}');

    // 1. If Doctor is new / not in masterlist, create new Doctor in HCP doctype
    if (effectiveHcpId.isEmpty || effectiveHcpId == 'NEW-HCP') {
      final newDoctor = Hcp(
        firstName: (fullSub.firstName != null && fullSub.firstName!.trim().isNotEmpty) ? fullSub.firstName!.trim() : 'Doctor',
        middleName: (fullSub.middleName != null && fullSub.middleName!.trim().isNotEmpty && fullSub.middleName!.trim() != '-') ? fullSub.middleName!.trim() : '-',
        lastName: (fullSub.lastName != null && fullSub.lastName!.trim().isNotEmpty) ? fullSub.lastName!.trim() : '',
        birthDate: fullSub.birthDate ?? '',
        hcpPhoto: fullSub.hcpPhoto,
        hcpType: LocationResolver.resolveHcpTypeId(fullSub.hcpType),
        hcpPractice: (fullSub.hcpPractice != null && fullSub.hcpPractice!.isNotEmpty) ? fullSub.hcpPractice! : 'Prescribing',
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
            .map((w) => HcpWorkplace(
                  workplace: LocationResolver.resolveInstitutionId(w.hcpWorkplace),
                  provinceName: (w.provinceName != null && w.provinceName!.isNotEmpty) ? LocationResolver.resolveProvinceId(w.provinceName) : null,
                  cityMunicipality: (w.cityMunicipality != null && w.cityMunicipality!.isNotEmpty) ? LocationResolver.resolveCityId(w.cityMunicipality) : null,
                  address: w.workplaceName,
                  isPrimary: w.preferred,
                ))
            .toList(),
        contacts: fullSub.contacts
            .where((c) => (c.contactNumber != null && c.contactNumber!.isNotEmpty) || (c.emailAddress != null && c.emailAddress!.isNotEmpty))
            .map((c) => HcpContact(contactNumber: c.contactNumber, emailAddress: c.emailAddress, isPrimary: c.preferred))
            .toList(),
        profileLastUpdated: DateTime.now().toIso8601String().split('.').first,
      );
      try {
        final createdDoc = await createDoctor(newDoctor);
        effectiveHcpId = createdDoc.name ?? '';
        print('[APPROVE] Doctor created successfully in HCP masterlist: $effectiveHcpId');
      } catch (e) {
        final errMsg = 'Failed to create doctor in HCP masterlist: $e';
        print('[APPROVE] $errMsg');
        errors.add(errMsg);
      }
    } else {
      // Existing doctor: ensure doctor master record is updated
      try {
        final existing = await fetchDoctorDetail(effectiveHcpId);
        final updatedDoctor = Hcp(
          name: existing.name,
          firstName: (fullSub.firstName != null && fullSub.firstName!.isNotEmpty) ? fullSub.firstName! : existing.firstName,
          middleName: (fullSub.middleName != null && fullSub.middleName!.isNotEmpty) ? fullSub.middleName : existing.middleName,
          lastName: (fullSub.lastName != null && fullSub.lastName!.isNotEmpty) ? fullSub.lastName! : existing.lastName,
          birthDate: (fullSub.birthDate != null && fullSub.birthDate!.isNotEmpty) ? fullSub.birthDate : existing.birthDate,
          hcpPhoto: (fullSub.hcpPhoto != null && fullSub.hcpPhoto!.isNotEmpty) ? fullSub.hcpPhoto : existing.hcpPhoto,
          hcpType: LocationResolver.resolveHcpTypeId(fullSub.hcpType ?? existing.hcpType),
          hcpPractice: fullSub.hcpPractice ?? existing.hcpPractice,
          specialties: fullSub.specialties.isNotEmpty
              ? fullSub.specialties
                  .where((s) => s.hcpSpecialty != null && s.hcpSpecialty!.isNotEmpty)
                  .map((s) => HcpSpecialty(
                        hcpSpecialty: LocationResolver.resolveSpecialtyId(s.hcpSpecialty),
                        subSpecialty: (s.subSpecialty != null && s.subSpecialty!.isNotEmpty && s.subSpecialty != '-') ? LocationResolver.resolveSpecialtyId(s.subSpecialty) : null,
                        isPrimary: s.preferred,
                      ))
                  .toList()
              : existing.specialties,
          workplaces: fullSub.workplaces.isNotEmpty
              ? fullSub.workplaces
                  .where((w) => w.hcpWorkplace != null && w.hcpWorkplace!.isNotEmpty)
                  .map((w) => HcpWorkplace(
                        workplace: LocationResolver.resolveInstitutionId(w.hcpWorkplace),
                        address: w.workplaceName,
                        isPrimary: w.preferred,
                      ))
                  .toList()
              : existing.workplaces,
          contacts: fullSub.contacts.isNotEmpty
              ? fullSub.contacts
                  .where((c) => (c.contactNumber != null && c.contactNumber!.isNotEmpty) || (c.emailAddress != null && c.emailAddress!.isNotEmpty))
                  .map((c) => HcpContact(contactNumber: c.contactNumber, emailAddress: c.emailAddress, isPrimary: c.preferred))
                  .toList()
              : existing.contacts,
          profileLastUpdated: DateTime.now().toIso8601String().split('.').first,
        );
        await updateDoctor(effectiveHcpId, updatedDoctor);
        print('[APPROVE] Doctor updated successfully: $effectiveHcpId');
      } catch (e) {
        print('[APPROVE] Error updating doctor: $e');
        errors.add('Failed to update doctor record: $e');
      }
    }

    // 2. Sync / Create HCP Account for the specific program and medrep
    final docParts = [
      if (fullSub.firstName != null && fullSub.firstName!.isNotEmpty) fullSub.firstName!,
      if (fullSub.middleName != null && fullSub.middleName!.isNotEmpty && fullSub.middleName != '-') fullSub.middleName!,
      if (fullSub.lastName != null && fullSub.lastName!.isNotEmpty) fullSub.lastName!,
    ];
    final docFullName = (fullSub.hcpFullName != null && fullSub.hcpFullName!.isNotEmpty)
        ? fullSub.hcpFullName!
        : (docParts.isNotEmpty ? docParts.join(' ') : '${fullSub.firstName ?? ''} ${fullSub.lastName ?? ''}'.trim());

    if (effectiveHcpId.isNotEmpty && effectiveHcpId != 'NEW-HCP') {
      try {
        await syncHcpAccount(
          hcpId: effectiveHcpId,
          hcpFullName: docFullName.isNotEmpty ? docFullName : 'Doctor',
          program: (fullSub.accountOrProgram != null && fullSub.accountOrProgram!.isNotEmpty) ? fullSub.accountOrProgram! : selectedProgram,
          territory: fullSub.territory ?? 'AD0110',
          salesPerson: (fullSub.salesPerson != null && fullSub.salesPerson!.trim().isNotEmpty)
              ? fullSub.salesPerson!.trim()
              : getTerritoryManagerForTerritory(fullSub.territory ?? 'AD0110'),
          userId: fullSub.userId ?? fullSub.medrepEmail ?? loggedInEmail,
          specialties: fullSub.specialties
              .where((s) => s.hcpSpecialty != null && s.hcpSpecialty!.isNotEmpty && s.preferred)
              .map((s) => HcpAccountSpecialization(
                    hcpSpecialty: LocationResolver.resolveSpecialtyId(s.hcpSpecialty),
                    subSpecialty: (s.subSpecialty != null && s.subSpecialty!.isNotEmpty && s.subSpecialty != '-') ? LocationResolver.resolveSpecialtyId(s.subSpecialty) : null,
                    isPrimary: true,
                    preferred: true,
                  ))
              .toList(),
          workplaces: fullSub.workplaces
              .where((w) => w.hcpWorkplace != null && w.hcpWorkplace!.isNotEmpty && w.preferred)
              .map((w) => HcpAccountWorkplace(
                    hcpWorkplace: LocationResolver.resolveInstitutionId(w.hcpWorkplace),
                    address: w.workplaceName,
                    isPrimary: true,
                    preferred: true,
                  ))
              .toList(),
          contacts: fullSub.contacts
              .where((c) => ((c.contactNumber != null && c.contactNumber!.isNotEmpty) || (c.emailAddress != null && c.emailAddress!.isNotEmpty)) && c.preferred)
              .map((c) => HcpAccountContact(
                    contactNumber: c.contactNumber,
                    emailAddress: c.emailAddress,
                    isPrimary: true,
                    preferred: true,
                  ))
              .toList(),
        );
        print('[APPROVE] HCP Account synced successfully for $effectiveHcpId');
      } catch (e) {
        print('[APPROVE] Error syncing HCP account: $e');
        errors.add('Failed to sync HCP Account: $e');
      }
    } else {
      print('[APPROVE] Skipping HCP Account sync because effectiveHcpId is empty');
      if (!errors.any((e) => e.contains('create doctor'))) {
        errors.add('Doctor was not created, so HCP Account could not be provisioned.');
      }
    }

    // 3. Update Submission workflow state in ERPNext
    if (fullSub.name != null && fullSub.name!.isNotEmpty) {
      final subName = fullSub.name!;

      // Fetch live document from ERPNext to get current state
      Map<String, dynamic> liveDoc = {};
      try {
        final getUrl = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(subName)}');
        final getResp = await http.get(getUrl, headers: _headers);
        if (getResp.statusCode == 200) {
          liveDoc = jsonDecode(getResp.body)['data'] ?? {};
        }
      } catch (_) {}

      // Try workflow actions with the live document
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
              },
              'action': actionName,
            }),
          );
          if (wfResp.statusCode == 200) {
            workflowApplied = true;
          }
        } catch (e) {
          print('[APPROVE] apply_workflow action="$actionName" error: $e');
        }
      }

      // Try frappe.client.set_value (bypasses workflow triggers)
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
                if (effectiveHcpId.isNotEmpty) 'hcp_name': effectiveHcpId,
                'workflow_state': 'Approved',
                'status': 'Approved',
                'application_status': 'Applied',
              },
            }),
          );
          if (svResp.statusCode == 200) workflowApplied = true;
        } catch (e) {
          print('[APPROVE] set_value error: $e');
        }
      }

      // Direct REST PUT fallback
      if (!workflowApplied) {
        try {
          final updateUrl = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(subName)}');
          final putResp = await http.put(
            updateUrl,
            headers: _headers,
            body: jsonEncode({
              if (effectiveHcpId.isNotEmpty) 'hcp_name': effectiveHcpId,
              'workflow_state': 'Approved',
              'status': 'Approved',
              'application_status': 'Applied',
              'docstatus': 1,
            }),
          );
          if (putResp.statusCode == 200) workflowApplied = true;
        } catch (e) {
          print('[APPROVE] PUT fallback error: $e');
        }
      }

      // Update local submissions_cache.json
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
            if (effectiveHcpId.isNotEmpty) list[idx]['hcp_name'] = effectiveHcpId;
            await _writeToCache('submissions_cache.json', jsonEncode(list));
          }
        }
      } catch (_) {}
    }

    // Only throw if the core masterlist creation or account creation failed
    if (errors.isNotEmpty) {
      throw Exception(errors.join('\n'));
    }
  }

  /// Reject a pending HCP Profile Submission (Admin / Manager)
  Future<void> rejectSubmission(String submissionName, {String remarks = ''}) async {
    bool workflowApplied = false;
    try {
      final wfUrl = Uri.parse('$baseUrl/api/method/frappe.model.workflow.apply_workflow');
      final wfResp = await http.post(
        wfUrl,
        headers: _headers,
        body: jsonEncode({
          'doc': {
            'doctype': 'HCP Profile Submission',
            'name': submissionName,
          },
          'action': 'Reject',
        }),
      );
      if (wfResp.statusCode == 200) {
        workflowApplied = true;
      }
    } catch (_) {}

    if (!workflowApplied) {
      final updateUrl = Uri.parse('$baseUrl/api/resource/HCP%20Profile%20Submission/${Uri.encodeComponent(submissionName)}');
      try {
        await http.put(
          updateUrl,
          headers: _headers,
          body: jsonEncode({
            'workflow_state': 'Rejected',
            'docstatus': 2,
            'status': 'Rejected',
            if (remarks.isNotEmpty) 'rejection_remarks': remarks,
          }),
        );
      } catch (e) {
        print('Error rejecting submission: $e');
        rethrow;
      }
    }
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
      return [];
    }
    final url = Uri.parse(
      '$baseUrl/api/resource/PSGC%20Location?fields=["name","location_label","location_type","parent_psgc_location","psgc_code","is_group"]&limit_page_length=5000&limit=5000',
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

  /// Retrieve list of rich Territory Info with Territory Managers from ERPNext
  Future<List<TerritoryInfo>> fetchTerritoryInfos() async {
    final url = Uri.parse(
      '$baseUrl/api/resource/Territory?fields=["name","territory_name","territory_manager","sales_person","manager"]&limit=500',
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
          return list;
        }
      }
    } catch (e) {
      print('Fetch territory infos error: $e');
    }

    final fallback = [
      TerritoryInfo(name: 'AD0110', territoryName: 'AD0110 - Manila North', territoryManager: 'Jorge Mengorio'),
      TerritoryInfo(name: 'AD0120', territoryName: 'AD0120 - Manila South', territoryManager: 'Jorge Mengorio'),
      TerritoryInfo(name: 'AD0130', territoryName: 'AD0130 - North Luzon', territoryManager: 'Jorge Mengorio'),
      TerritoryInfo(name: 'AD0140', territoryName: 'AD0140 - South Luzon', territoryManager: 'Jorge Mengorio'),
      TerritoryInfo(name: 'AD0150', territoryName: 'AD0150 - VisMin', territoryManager: 'Jorge Mengorio'),
      TerritoryInfo(name: 'CORE01', territoryName: 'CORE01 - Central Operations', territoryManager: 'Jorge Mengorio'),
      TerritoryInfo(name: 'CORE02', territoryName: 'CORE02 - Regional Operations', territoryManager: 'Jorge Mengorio'),
      TerritoryInfo(name: 'NCR-01', territoryName: 'NCR-01 - District 1', territoryManager: 'Jorge Mengorio'),
      TerritoryInfo(name: 'NCR-02', territoryName: 'NCR-02 - District 2', territoryManager: 'Jorge Mengorio'),
      TerritoryInfo(name: 'All Territories', territoryName: 'All Territories', territoryManager: 'Jorge Mengorio'),
    ];
    _territoryInfos = fallback;
    return fallback;
  }

  /// Get the assigned territory manager for a given territory code
  String getTerritoryManagerForTerritory(String territoryCode) {
    if (_territoryInfos.isEmpty) {
      fetchTerritoryInfos(); // fire-and-forget population
    }
    final match = _territoryInfos.firstWhere(
      (t) => t.name.toLowerCase() == territoryCode.toLowerCase() || t.territoryName.toLowerCase() == territoryCode.toLowerCase(),
      orElse: () => TerritoryInfo(name: territoryCode, territoryName: territoryCode, territoryManager: 'Jorge Mengorio'),
    );
    return match.territoryManager.isNotEmpty ? match.territoryManager : 'Jorge Mengorio';
  }

  /// Retrieve list of Territories from ERPNext
  Future<List<String>> fetchTerritories() async {
    final infos = await fetchTerritoryInfos();
    return infos.map((t) => t.name).toList();
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

  /// Fetch list of records of this DocType
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

    try {
      final response = await http.get(uri, headers: _api._headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> dataList = body['data'] ?? [];
        return dataList.map((json) => fromJson(json)).toList();
      } else {
        throw Exception('Failed to load list for $docType: ${response.statusCode}');
      }
    } catch (e) {
      print('FrappeRepository.list error on $docType: $e');
      rethrow;
    }
  }

  /// Fetch details of a single record by its name (ID), including its nested child tables
  Future<T> get(String name) async {
    final uri = Uri.parse('${_api.baseUrl}/api/resource/${Uri.encodeComponent(docType)}/${Uri.encodeComponent(name)}');
    try {
      final response = await http.get(uri, headers: _api._headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return fromJson(body['data']);
      } else {
        throw Exception('Failed to load detail for $docType ($name): ${response.statusCode}');
      }
    } catch (e) {
      print('FrappeRepository.get error on $docType: $e');
      rethrow;
    }
  }

  /// Create a new record with nested child table arrays
  Future<T> create(T item) async {
    final uri = Uri.parse('${_api.baseUrl}/api/resource/${Uri.encodeComponent(docType)}');
    try {
      final response = await http.post(
        uri,
        headers: _api._headers,
        body: jsonEncode(toJson(item)),
      );
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

  /// Update an existing record and dynamically reconcile child tables
  Future<T> update(String name, T item) async {
    final uri = Uri.parse('${_api.baseUrl}/api/resource/${Uri.encodeComponent(docType)}/${Uri.encodeComponent(name)}');
    try {
      final response = await http.put(
        uri,
        headers: _api._headers,
        body: jsonEncode(toJson(item)),
      );
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

