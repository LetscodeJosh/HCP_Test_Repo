import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lookup_models.dart';
import 'app_logger.dart';

/// Production notification service managing system lockscreen/homescreen alerts
/// for institution proposal workflows, rejections, and SFE remappings.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static const String _channelId = 'hcp_institution_channel';
  static const String _channelName = 'Institution & Profiling Alerts';
  static const String _channelDescription =
      'Heads-up alerts when institutions are rejected, approved, or remapped by SFE';

  static const String _prefKeyNotifiedIds = 'notified_rejected_institution_ids';
  static const String _prefKeyLastUser = 'last_active_medrep_user';

  /// Initialize local notification plugin and setup public lockscreen channel
  static Future<void> init() async {
    if (_initialized) return;

    try {
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const DarwinInitializationSettings darwinInit =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const LinuxInitializationSettings linuxInit =
          LinuxInitializationSettings(defaultActionName: 'Open HCP App');

      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
        linux: linuxInit,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create Android Channel with Maximum Importance and Public Visibility for Lockscreen
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

        await androidImplementation.createNotificationChannel(channel);
        await androidImplementation.requestNotificationsPermission();
      }

      _initialized = true;
      AppLogger.i('NotificationService', 'Local notification service initialized successfully.');
    } catch (e, st) {
      AppLogger.e('NotificationService', 'Failed to initialize notification plugin: $e', e, st);
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    AppLogger.i('NotificationService', 'Notification tapped with payload: ${response.payload}');
  }

  /// Displays high-priority pop-up notification on the lockscreen & homescreen
  /// when an institution proposed by the MedRep is rejected.
  static Future<void> showInstitutionRejectedNotification({
    required String institutionName,
    required String reason,
    String? submittedBy,
    String? institutionId,
  }) async {
    try {
      await init();

      final cleanReason = reason.trim().isNotEmpty ? reason.trim() : 'Proposal rejected by SFE';
      final int notifId = (institutionName.hashCode + DateTime.now().millisecond).abs() % 100000;

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public, // Public visibility = Pop-up on Lockscreen!
        ticker: 'Institution Rejected',
        icon: '@mipmap/launcher_icon',
        color: const Color(0xFFDC2626),
        styleInformation: BigTextStyleInformation(
          'Your submitted institution "$institutionName" was REJECTED by SFE.\n\nReason: $cleanReason\n\nThis institution cannot be used for HCP profiling. SFE may correct or remap it.',
          contentTitle: '⚠️ Institution Proposal Rejected',
          summaryText: 'HCP Profiling Alert',
        ),
      );

      const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        subtitle: 'Institution Proposal Rejected',
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _plugin.show(
        notifId,
        '⚠️ Institution Proposal Rejected',
        '"$institutionName" was rejected by SFE: $cleanReason. Cannot be used for profiling.',
        details,
        payload: jsonEncode({
          'type': 'institution_rejected',
          'institution_id': institutionId ?? institutionName,
          'institution_name': institutionName,
          'rejection_reason': cleanReason,
          'submitted_by': submittedBy,
        }),
      );

      if (institutionId != null && institutionId.isNotEmpty) {
        await markRejectionNotified(institutionId);
      }
      AppLogger.w('NotificationService', 'Posted lockscreen rejection alert for: $institutionName (Reason: $cleanReason)');
    } catch (e, st) {
      AppLogger.e('NotificationService', 'Error showing rejected notification: $e', e, st);
    }
  }

  /// Displays lockscreen alert when SFE resolves/remaps a rejected institution
  /// allowing MedRep to continue profiling.
  static Future<void> showInstitutionRemappedNotification({
    required String oldInstitutionName,
    required String newInstitutionName,
    String? reason,
  }) async {
    try {
      await init();

      final int notifId = (oldInstitutionName.hashCode + DateTime.now().millisecond).abs() % 100000;

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        ticker: 'Institution Corrected',
        icon: '@mipmap/launcher_icon',
        color: const Color(0xFF10B981),
        styleInformation: BigTextStyleInformation(
          'Rejected institution "$oldInstitutionName" was corrected by SFE to "$newInstitutionName".\n\nYou can now proceed with HCP profiling for this institution.',
          contentTitle: '✅ Institution Corrected by SFE',
          summaryText: 'Profiling Unblocked',
        ),
      );

      final NotificationDetails details = NotificationDetails(android: androidDetails);

      await _plugin.show(
        notifId,
        '✅ Institution Corrected by SFE',
        '"$oldInstitutionName" corrected to "$newInstitutionName". Profiling is now unblocked.',
        details,
        payload: jsonEncode({
          'type': 'institution_remapped',
          'old_institution': oldInstitutionName,
          'new_institution': newInstitutionName,
        }),
      );
      AppLogger.i('NotificationService', 'Posted remapped alert: $oldInstitutionName -> $newInstitutionName');
    } catch (e, st) {
      AppLogger.e('NotificationService', 'Error showing remapped notification: $e', e, st);
    }
  }

  /// Checks cached or newly fetched institutions for any rejected facilities
  /// submitted by the current or last logged-in MedRep, and triggers lockscreen
  /// notifications even when logged out.
  static Future<void> checkAndNotifyPendingRejections(
    List<Institution> institutions, {
    String? userEmail,
  }) async {
    try {
      final targetUser = (userEmail != null && userEmail.trim().isNotEmpty)
          ? userEmail.trim().toLowerCase()
          : (await getLastActiveUser())?.toLowerCase();

      final notifiedIds = await getNotifiedRejectionIds();

      final rejectedList = institutions.where((i) => i.isRejected).toList();
      for (final inst in rejectedList) {
        final instKey = '${inst.name}_${inst.rejectionReason ?? ''}';
        if (notifiedIds.contains(instKey)) continue;

        final owner = (inst.owner ?? '').trim().toLowerCase();
        // If owner matches, or if no target user specified, notify
        bool isMatch = false;
        if (targetUser != null && targetUser.isNotEmpty) {
          isMatch = owner.isEmpty || owner == targetUser || owner.contains(targetUser) || targetUser.contains(owner);
        } else {
          isMatch = true;
        }

        if (isMatch) {
          await showInstitutionRejectedNotification(
            institutionName: inst.institutionName,
            reason: inst.rejectionReason ?? 'Proposal rejected by SFE',
            submittedBy: inst.owner,
            institutionId: instKey,
          );
        }
      }
    } catch (e, st) {
      AppLogger.e('NotificationService', 'Error checking pending rejections: $e', e, st);
    }
  }

  /// Quick test method to simulate lockscreen & homescreen notification
  static Future<void> simulateRejectionNotification({
    String institutionName = 'St. Lukes Hospital - BGC Annex',
    String reason = 'Facility already exists in Masterlist under "St. Luke\'s Medical Center - Global City". SFE will correct.',
  }) async {
    await showInstitutionRejectedNotification(
      institutionName: institutionName,
      reason: reason,
      submittedBy: 'medrep@profinsights.biz',
    );
  }

  // Persistent storage helpers for tracking notified alerts across app restarts & logout
  static Future<void> saveLastActiveUser(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyLastUser, email.trim());
    } catch (_) {}
  }

  static Future<String?> getLastActiveUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKeyLastUser);
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>> getNotifiedRejectionIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_prefKeyNotifiedIds) ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> markRejectionNotified(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefKeyNotifiedIds) ?? [];
      if (!list.contains(key)) {
        list.add(key);
        // Keep list bounded to last 100 entries
        if (list.length > 100) list.removeAt(0);
        await prefs.setStringList(_prefKeyNotifiedIds, list);
      }
    } catch (_) {}
  }

  static Future<void> clearNotifiedRejections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyNotifiedIds);
    } catch (_) {}
  }
}
