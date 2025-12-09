import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/notification_settings.dart' as app_notifications;
import 'firebase_service.dart';
import 'streak_service.dart';

// Type alias for our app's notification settings
typedef AppNotificationSettings = app_notifications.NotificationSettings;

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');
  // Handle background message (data processing only, no UI)
}

/// Central notification service handling FCM and local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static bool _initialized = false;

  // Firebase Messaging instance
  late FirebaseMessaging _messaging;

  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Notification channel IDs
  static const String _streakChannelId = 'streak_reminders';
  static const String _streakChannelName = 'Streak Reminders';
  static const String _streakChannelDesc =
      'Daily reminders to maintain your streak';

  static const String _contentChannelId = 'new_content';
  static const String _contentChannelName = 'New Content';
  static const String _contentChannelDesc =
      'Notifications about new decks and content';

  static const String _challengeChannelId = 'challenges';
  static const String _challengeChannelName = 'Challenges';
  static const String _challengeChannelDesc =
      'Daily and weekly challenge notifications';

  static const String _generalChannelId = 'general';
  static const String _generalChannelName = 'General';
  static const String _generalChannelDesc = 'General app notifications';

  // Notification IDs
  static const int _streakReminderId = 1001;
  static const int _streakExpiringId = 1002;
  static const int _inactivityReminderId = 1003;
  static const int _challengeReminderId = 1004;

  // Preferences keys
  static const String _settingsKey = 'notification_settings';
  static const String _fcmTokenKey = 'fcm_token';

  // Stream controller for notification taps
  final StreamController<String?> _notificationTapController =
      StreamController<String?>.broadcast();
  Stream<String?> get onNotificationTap => _notificationTapController.stream;

  // Settings cache
  AppNotificationSettings? _settings;
  AppNotificationSettings get settings =>
      _settings ?? AppNotificationSettings.defaults();

  /// Check if service is initialized
  static bool get isInitialized => _initialized;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('⚠️ NotificationService already initialized');
      return;
    }

    final instance = NotificationService();
    await instance._init();
    _initialized = true;
    debugPrint('✅ NotificationService initialized');
  }

  Future<void> _init() async {
    // Initialize timezone
    tz_data.initializeTimeZones();

    // Initialize Firebase Messaging
    _messaging = FirebaseMessaging.instance;

    // Load settings
    await _loadSettings();

    // Initialize local notifications
    await _initLocalNotifications();

    // Set up FCM handlers
    _setupFCMHandlers();

    // NOTE: Do NOT request permission here - let the dedicated permission screen handle it
    // Only check if permission was already granted
    final hasPermission = await _checkPermissionStatus();
    
    if (hasPermission) {
      // Get and save FCM token only if permission granted
      await _handleFCMToken();

      // Schedule notifications based on settings
      await scheduleNotificationsBasedOnSettings();
    }
  }
  
  /// Check permission status without requesting
  Future<bool> _checkPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Initialize local notifications plugin
  Future<void> _initLocalNotifications() async {
    // Android initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Streak channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _streakChannelId,
          _streakChannelName,
          description: _streakChannelDesc,
          importance: Importance.high,
        ),
      );

      // Content channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _contentChannelId,
          _contentChannelName,
          description: _contentChannelDesc,
          importance: Importance.defaultImportance,
        ),
      );

      // Challenge channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _challengeChannelId,
          _challengeChannelName,
          description: _challengeChannelDesc,
          importance: Importance.defaultImportance,
        ),
      );

      // General channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _generalChannelId,
          _generalChannelName,
          description: _generalChannelDesc,
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  /// Set up FCM message handlers
  void _setupFCMHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background/terminated message taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check for initial message (app opened from terminated state)
    _checkInitialMessage();
  }

  /// Handle foreground FCM messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('🔔 Foreground message: ${message.notification?.title}');

    // Show local notification for foreground messages
    if (message.notification != null) {
      await showLocalNotification(
        title: message.notification!.title ?? 'Heads Up!',
        body: message.notification!.body ?? '',
        payload: jsonEncode(message.data),
        channelId: _getChannelForMessage(message),
      );
    }
  }

  /// Handle message tap when app is in background
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔔 Message opened app: ${message.data}');
    _notificationTapController.add(jsonEncode(message.data));
  }

  /// Check for initial message when app was terminated
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🔔 Initial message: ${initialMessage.data}');
      // Delay to ensure navigation is ready
      Future.delayed(const Duration(seconds: 1), () {
        _notificationTapController.add(jsonEncode(initialMessage.data));
      });
    }
  }

  /// Determine which channel to use for a message
  String _getChannelForMessage(RemoteMessage message) {
    final type = message.data['type'] as String?;
    switch (type) {
      case 'streak':
        return _streakChannelId;
      case 'new_content':
        return _contentChannelId;
      case 'challenge':
        return _challengeChannelId;
      default:
        return _generalChannelId;
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    _notificationTapController.add(response.payload);
  }

  /// Request notification permission with rationale
  /// This is the main method to request permission - called from the permission screen
  Future<bool> requestPermission({BuildContext? context}) async {
    // Check current status
    final currentSettings = await _messaging.getNotificationSettings();

    if (currentSettings.authorizationStatus == AuthorizationStatus.authorized) {
      // Already authorized, ensure everything is set up
      await _onPermissionGranted();
      return true;
    }

    if (currentSettings.authorizationStatus == AuthorizationStatus.denied) {
      // Permission was previously denied, need to go to settings
      debugPrint('🔔 Permission previously denied, need to open settings');
      return false;
    }

    // Request permission from the system
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized;

    debugPrint('🔔 Notification permission: ${granted ? "granted" : "denied"}');

    if (granted) {
      await _onPermissionGranted();
    }

    return granted;
  }
  
  /// Called when notification permission is granted
  /// Sets up FCM token and schedules notifications
  Future<void> _onPermissionGranted() async {
    // Update settings
    if (_settings != null) {
      _settings = _settings!.copyWith(enabled: true);
      await _saveSettings();
    }
    
    // Get and save FCM token
    await _handleFCMToken();

    // Schedule notifications based on settings
    await scheduleNotificationsBasedOnSettings();
    
    debugPrint('🔔 Notification setup complete after permission granted');
  }

  /// Handle FCM token
  Future<void> _handleFCMToken() async {
    try {
      // Get current token
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveFCMToken(token);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_saveFCMToken);
    } catch (e) {
      debugPrint('Error handling FCM token: $e');
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveFCMToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString(_fcmTokenKey);

      if (oldToken != token) {
        await prefs.setString(_fcmTokenKey, token);

        // Save to Firebase (will be handled by FirebaseService)
        await FirebaseService().saveFCMToken(token);
        debugPrint('🔔 FCM token saved: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Get current FCM token
  Future<String?> getFCMToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  // ============================================
  // LOCAL NOTIFICATION SCHEDULING
  // ============================================

  /// Show an immediate local notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = _generalChannelId,
  }) async {
    if (!settings.enabled) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Schedule streak reminder notification
  Future<void> scheduleStreakReminder() async {
    if (!settings.enabled || !settings.streakReminders) {
      await cancelStreakReminder();
      return;
    }

    // Check if user has played today
    final streakService = StreakService();
    final hasPlayedToday = await streakService.hasPlayedToday();

    if (hasPlayedToday) {
      debugPrint('🔔 User played today, skipping streak reminder');
      return;
    }

    // Schedule for the preferred time
    final now = DateTime.now();
    var scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      settings.streakReminderHour,
      settings.streakReminderMinute,
    );

    // If time has passed, don't schedule for today
    if (scheduledTime.isBefore(now)) {
      debugPrint('🔔 Streak reminder time passed for today');
      return;
    }

    final currentStreak = await streakService.getCurrentStreak();
    final streakText =
        currentStreak > 0 ? 'Your $currentStreak-day streak is waiting!' : '';

    await _scheduleNotification(
      id: _streakReminderId,
      title: "Don't forget to play! 🎮",
      body:
          streakText.isNotEmpty
              ? streakText
              : 'Keep the fun going - play a quick round!',
      scheduledTime: scheduledTime,
      channelId: _streakChannelId,
      payload: '{"type": "streak_reminder"}',
    );

    debugPrint('🔔 Streak reminder scheduled for $scheduledTime');
  }

  /// Schedule streak expiring notification (2 hours before midnight)
  Future<void> scheduleStreakExpiringReminder() async {
    if (!settings.enabled || !settings.streakReminders) {
      await cancelStreakExpiringReminder();
      return;
    }

    final streakService = StreakService();
    final hasPlayedToday = await streakService.hasPlayedToday();
    final currentStreak = await streakService.getCurrentStreak();

    if (hasPlayedToday || currentStreak == 0) {
      debugPrint('🔔 No streak to protect or already played');
      return;
    }

    final now = DateTime.now();
    final scheduledTime = DateTime(now.year, now.month, now.day, 22, 0); // 10 PM

    if (scheduledTime.isBefore(now)) {
      debugPrint('🔔 Streak expiring time passed');
      return;
    }

    await _scheduleNotification(
      id: _streakExpiringId,
      title: '⚠️ Streak Alert!',
      body:
          'Your $currentStreak-day streak expires at midnight! Play now to save it!',
      scheduledTime: scheduledTime,
      channelId: _streakChannelId,
      payload: '{"type": "streak_expiring"}',
    );

    debugPrint('🔔 Streak expiring reminder scheduled for $scheduledTime');
  }

  /// Schedule inactivity reminder (after 3 days)
  Future<void> scheduleInactivityReminder() async {
    if (!settings.enabled || !settings.inactivityReminders) {
      await cancelInactivityReminder();
      return;
    }

    final streakService = StreakService();
    final hasPlayedToday = await streakService.hasPlayedToday();

    if (hasPlayedToday) {
      // Cancel any existing inactivity reminder
      await cancelInactivityReminder();
      // Reschedule for 3 days from now
      final scheduledTime = DateTime.now().add(const Duration(days: 3));

      await _scheduleNotification(
        id: _inactivityReminderId,
        title: 'We miss you! 🎯',
        body: "It's been a while - come back and check out new decks!",
        scheduledTime: scheduledTime,
        channelId: _generalChannelId,
        payload: '{"type": "inactivity"}',
      );

      debugPrint('🔔 Inactivity reminder scheduled for $scheduledTime');
    }
  }

  /// Schedule challenge reminder
  Future<void> scheduleChallengeReminder({
    required String challengeTitle,
    required DateTime challengeEndTime,
  }) async {
    if (!settings.enabled || !settings.challengeReminders) return;

    // Remind 2 hours before challenge ends
    final reminderTime = challengeEndTime.subtract(const Duration(hours: 2));

    if (reminderTime.isBefore(DateTime.now())) return;

    await _scheduleNotification(
      id: _challengeReminderId,
      title: 'Challenge ending soon! ⏰',
      body: '$challengeTitle ends in 2 hours. Complete it now!',
      scheduledTime: reminderTime,
      channelId: _challengeChannelId,
      payload: '{"type": "challenge", "title": "$challengeTitle"}',
    );
  }

  /// Internal method to schedule a notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String channelId,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  // ============================================
  // CANCEL NOTIFICATIONS
  // ============================================

  /// Cancel streak reminder
  Future<void> cancelStreakReminder() async {
    await _localNotifications.cancel(_streakReminderId);
  }

  /// Cancel streak expiring reminder
  Future<void> cancelStreakExpiringReminder() async {
    await _localNotifications.cancel(_streakExpiringId);
  }

  /// Cancel inactivity reminder
  Future<void> cancelInactivityReminder() async {
    await _localNotifications.cancel(_inactivityReminderId);
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // ============================================
  // SETTINGS MANAGEMENT
  // ============================================

  /// Load notification settings from storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson != null) {
        _settings = AppNotificationSettings.fromJson(jsonDecode(settingsJson));
      } else {
        _settings = AppNotificationSettings.defaults();
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      _settings = AppNotificationSettings.defaults();
    }
  }

  /// Save notification settings to storage
  Future<void> _saveSettings() async {
    if (_settings == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, jsonEncode(_settings!.toJson()));
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }

  /// Update notification settings
  Future<void> updateSettings(AppNotificationSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();
    await scheduleNotificationsBasedOnSettings();
  }

  /// Enable or disable all notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_settings != null) {
      _settings = _settings!.copyWith(enabled: enabled);
      await _saveSettings();

      if (!enabled) {
        await cancelAllNotifications();
      } else {
        await scheduleNotificationsBasedOnSettings();
      }
    }
  }

  /// Set streak reminder time
  Future<void> setStreakReminderTime(int hour, int minute) async {
    if (_settings != null) {
      _settings = _settings!.copyWith(
        streakReminderHour: hour,
        streakReminderMinute: minute,
      );
      await _saveSettings();
      await scheduleStreakReminder();
    }
  }

  /// Schedule all notifications based on current settings
  Future<void> scheduleNotificationsBasedOnSettings() async {
    if (!settings.enabled) {
      await cancelAllNotifications();
      return;
    }

    // Schedule streak reminders
    if (settings.streakReminders) {
      await scheduleStreakReminder();
      await scheduleStreakExpiringReminder();
    } else {
      await cancelStreakReminder();
      await cancelStreakExpiringReminder();
    }

    // Schedule inactivity reminder
    if (settings.inactivityReminders) {
      await scheduleInactivityReminder();
    } else {
      await cancelInactivityReminder();
    }
  }

  /// Called after a game is played to reschedule notifications
  Future<void> onGamePlayed() async {
    // Cancel today's streak reminders since user played
    await cancelStreakReminder();
    await cancelStreakExpiringReminder();

    // Reschedule inactivity reminder for 3 days from now
    await scheduleInactivityReminder();
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  String _getChannelName(String channelId) {
    switch (channelId) {
      case _streakChannelId:
        return _streakChannelName;
      case _contentChannelId:
        return _contentChannelName;
      case _challengeChannelId:
        return _challengeChannelName;
      default:
        return _generalChannelName;
    }
  }

  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case _streakChannelId:
        return _streakChannelDesc;
      case _contentChannelId:
        return _contentChannelDesc;
      case _challengeChannelId:
        return _challengeChannelDesc;
      default:
        return _generalChannelDesc;
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationTapController.close();
  }
}

