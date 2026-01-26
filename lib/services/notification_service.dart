import 'package:flutter/foundation.dart'; // For kIsWeb
import 'dart:convert'; // Add this for JSON encoding
import 'package:shared_preferences/shared_preferences.dart'; // Add this
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart'; // Required for Firebase.apps check
import 'package:flutter/material.dart'; // For MaterialPageRoute
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart'; // Add this
import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger_service.dart';
import '../config/navigation.dart'; // For navigatorKey
import '../chat_page.dart';
import '../requests_page.dart'; // For RequestsPage navigation
import '../models/user_profile.dart';

// Top-level background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  // await Firebase.initializeApp();
  logger.info("Handling a background message: ${message.messageId}");
}

/// Service to handle local notifications and real-time alerts.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final supabase = Supabase.instance.client;
  // REMOVED: final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  // We access instance lazily to avoid crashes if Firebase init failed.

  bool _initialized = false;
  RealtimeChannel? _notificationChannel;
  bool _pushDisabled =
      false; // Internal flag, synced via updatePushPermission or init

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Set background handler - moved to _initFCM to be safe

    // Android initialization settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize Local Notifications
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Check shared preference for push status
    // If disabled, we do NOT init FCM or request permissions to avoid prompting user
    // or generating tokens that shouldn't exist.
    // However, for in-app logic, we might still want local permissions?
    // Let's assume "Push Notifications" toggle controls BOTH system-level permission request AND token sync.

    // Actually, "Push Notifications" usually implies remote.
    // Local notifications are often needed for things like "Timer finished".
    // But here the user implies "Silence".

    // Better approach: Always init local notifications (done above).
    // Only init FCM if enabled.

    // Load preference
    final prefs = await SharedPreferences.getInstance();
    _pushDisabled = !(prefs.getBool('notifications_enabled') ?? true);

    // Request permissions (Local + FCM)
    await _requestPermissions();

    // Init FCM only if enabled (or if we have a token already, we might want to refresh)
    // Actually, if disabled, we skip FCM init to avoid registering token.
    if (!_pushDisabled) {
      await _initFCM();
    }

    // Reset badge on app start
    await resetBadge();

    _initialized = true;
    logger.info(
        '📬 Notification service initialized (Push Disabled: $_pushDisabled)');
  }

  /// Initialize Firebase Cloud Messaging
  Future<void> _initFCM() async {
    try {
      // Check Preference
      // We use SharedPreferences directly here to ensure single source of truth
      // without circular dependency on Riverpod or passing params around deeply.
      // (Though cleaner to pass it in, this is a singleton service).
      // Note: We need SharedPreferences instance.
      // Using a quick creating instance here is fine for occasional calls.
      try {
        // Dynamic import workaround or just use package (it is imported in settings, not here yet... wait, not imported here)
        // We need to import shared_preferences.
        // Since I cannot add imports easily with multi_replace without breaking line numbers if I am not careful with top of file,
        // I will rely on the caller `updatePushPermission` to handle the heavy lifting,
        // and here I will just default to TRUE for initialization if I can't check easily,
        // OR better: I will add the import.
      } catch (e) {
        // ignore
      }

      // Guard: If Firebase didn't initialize (e.g. on Desktop), skip FCM

      if (Firebase.apps.isEmpty) {
        logger.warning('Skipping FCM: No Firebase App initialized');
        return;
      }

      // Lazy access - will throw here if Firebase.initializeApp failed, but we catch it.
      final messaging = FirebaseMessaging.instance;

      // 1. Request Permission
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      logger.info('User granted permission: ${settings.authorizationStatus}');

      // 2. Get Token
      // On iOS, we need to wait for APNs token first
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          await Future.delayed(const Duration(seconds: 3));
          apnsToken = await messaging.getAPNSToken();
        }
      }

      final fcmToken = await messaging.getToken();
      logger.info('FCM Token: $fcmToken');

      if (fcmToken != null) {
        await _saveTokenToDatabase(fcmToken);
      }

      // 3. Listen for token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToDatabase(newToken);
      });

      // 4. Foreground Message Handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        logger.info('Got a message whilst in the foreground!');
        logger.info('Message data: ${message.data}');

        if (message.notification != null) {
          logger.info(
              'Message also contained a notification: ${message.notification}');

          // Show local notification using existing logic
          // We assume the payload 'type' is passed in data for navigation
          final type = message.data['type'] ?? 'message';

          _showNotification(
            message.messageId ?? DateTime.now().toString(),
            type,
            message.notification!.title ?? 'New Notification',
            message.notification!.body ?? '',
            message.data,
          );
        }
      });

      // 5. Background Application Opened Handler (When clicking a notification while app is backgrounded/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        logger.info('A new onMessageOpenedApp event was published!');

        // This is THE handler for "Push Notification Click" from background
        _handleNavigation(message.data);
      });

      // Set background handler (needs to be static or top-level)
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    } catch (e) {
      logger.warning(
          'FCM not initialized (Expected if missing firebase_options.dart or on Web/Windows without config). Notification features will be local-only.');
    }
  }

  /// Update Push Permission (Toggle)
  /// If enabled: Initialize FCM, get token, save to DB.
  /// If disabled: Delete token from DB (set to NULL).
  Future<void> updatePushPermission(bool enabled) async {
    _pushDisabled = !enabled; // Update local flag immediately

    // Always reset badge if user is toggling things, good cleanup
    if (!enabled) await resetBadge();

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (enabled) {
      logger.info("🔔 Enabling Push Notifications...");
      // Re-run init to ensure we have permission and token
      await _initFCM();
      // Force sync
      await syncToken();
    } else {
      logger.info("🔕 Disabling Push Notifications...");
      // Remove token from DB so server stops sending
      try {
        await supabase
            .from('profiles')
            .update({'fcm_token': null}).eq('user_id', userId);
        logger.info('✅ FCM Token cleared from database');

        // Optional: Delete instance ID (uncommon, usually just unlinking enough)
        // await FirebaseMessaging.instance.deleteToken();
      } catch (e) {
        logger.error('Error clearing FCM token', error: e);
      }
    }
  }

  /// Manually trigger a token sync (useful after login)
  Future<void> syncToken() async {
    try {
      if (Firebase.apps.isEmpty) return;
      final messaging = FirebaseMessaging.instance;

      // On iOS, we need to wait for APNs token first
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          logger.info('Waiting for APNs token before FCM sync...');
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      // Get token (FCM handles permissions internally or via initialize)
      final token = await messaging.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
      }
    } catch (e) {
      logger.warning('FCM Manual Sync failed: $e');
    }
  }

  /// Save FCM token to Supabase profiles
  Future<void> _saveTokenToDatabase(String token) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Use direct update instead of RPC to avoid "updated_at" column errors in the DB function
    try {
      await supabase
          .from('profiles')
          .update({'fcm_token': token}).eq('user_id', userId);
      logger.info('✅ FCM Token saved to database (Direct)');
    } catch (e) {
      logger.error('Error saving FCM token', error: e);
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    // Android 13+ requires runtime permission
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    // iOS permissions
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    // Also reset badge if app was opened from terminated state
    await resetBadge();

    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Handle notification tap
  Future<void> _onNotificationTapped(NotificationResponse response) async {
    // When user taps a notification, we assume they "saw" things.
    // Reset badge.
    await resetBadge();

    final payload = response.payload;
    // Map payload string (type) back to useful data if needed,
    // BUT local notifications might have minimal data.
    // Ideally we pass the FULL data map as a JSON string in payload, but simple is ok.

    // For local notifications, we rely on the payload being just the "type".
    // But wait - we need the ID (match_id, user_id) to navigate!
    // The current _showNotification implementation passes `type` as payload.
    // That's insufficient for navigation. It needs "type:id" or similar.

    // Changing _onNotificationTapped to just parse the simple string is weak.
    // Let's rely on _handleNavigation which expects a Map.
    // If we only have a string payload, we try to reconstruct a partial map.

    if (payload != null) {
      logger.info('🔔 Notification tapped with payload: $payload');

      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        _handleNavigation(data);
      } catch (e) {
        logger.warning(
            'Failed to parse notification payload as JSON: $payload. Attempting legacy parsing.');
        // Legacy parsing for "type" or "type:id"
        final parts = payload.split(':');
        final type = parts[0];
        final id = parts.length > 1 ? parts[1] : null;

        final data = <String, dynamic>{'type': type};
        if (id != null) {
          if (type == 'chat_message') data['sender_id'] = id;
        }
        _handleNavigation(data);
      }
    }
  }

  /// Centralized Navigation Logic
  void _handleNavigation(Map<String, dynamic> data) async {
    final type = data['type'];
    logger.info('🧭 Handling navigation for type: $type');

    if (navigatorKey.currentState == null) {
      logger.warning(
          '⚠️ Navigator key not attached to context - cannot navigate');
      return;
    }

    try {
      if (type == 'chat_message') {
        final senderId = data['sender_id']; // from data payload
        if (senderId != null) {
          // Fetch profile to navigate
          final profileData = await supabase
              .from('profiles')
              .select()
              .eq('user_id', senderId)
              .maybeSingle();

          if (profileData != null) {
            final profile = UserProfile.fromJson(profileData);
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => ChatPage(otherUser: profile),
              ),
            );
          }
        }
      } else if (type == 'match_request' || type == 'collab_request') {
        // Go to Requests Page
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => const RequestsPage(),
          ),
        );
      } else if (type == 'friend_sos') {
        // Auto-Connected Friend SOS -> Go straight to Chat
        final senderId = data['sender_id'];
        if (senderId != null) {
          final profileData = await supabase
              .from('profiles')
              .select()
              .eq('user_id', senderId)
              .maybeSingle();

          if (profileData != null) {
            final profile = UserProfile.fromJson(profileData);
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => ChatPage(otherUser: profile),
              ),
            );
          }
        }
      } else if (type == 'match_accepted' || type == 'match_confirmed') {
        // Maybe go to Chat or Connections?
        // For now, let's go to Connections page or Chat
        final accepterId = data['accepter_id'];
        if (accepterId != null) {
          final profileData = await supabase
              .from('profiles')
              .select()
              .eq('user_id', accepterId)
              .maybeSingle();

          if (profileData != null) {
            final profile = UserProfile.fromJson(profileData);
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => ChatPage(otherUser: profile),
              ),
            );
          }
        }
      }
    } catch (e) {
      logger.error('Error handling navigation', error: e);
    }
  }

  /// Subscribe to realtime notifications from Supabase
  Future<void> subscribeToNotifications() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      logger.warning('Cannot subscribe to notifications: user not logged in');
      return;
    }

    // Unsubscribe from previous channel if exists
    await _notificationChannel?.unsubscribe();

    _notificationChannel = supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final notification = payload.newRecord;
            if (notification['user_id'] == userId) {
              _showNotification(
                notification['id'],
                notification['type'],
                notification['title'],
                notification['body'],
                notification['data'],
              );
            }
          },
        )
        .subscribe();

    logger.info('📡 Subscribed to notifications for user: $userId');
  }

  /// Unsubscribe from notifications
  Future<void> unsubscribe() async {
    await _notificationChannel?.unsubscribe();
    _notificationChannel = null;
    logger.info('📴 Unsubscribed from notifications');
  }

  /// Show a local notification
  Future<void> _showNotification(
    String id,
    String type,
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    // 1. Check Preference: Is Push (System) Notification enabled?
    // We do this check locally to suppress the "Pop-up" / Tray notification
    // if the user turned it off.
    // Note: This relies on the caller ensuring we only get here for valid reasons.
    // But for "Background" messages that wake the app up (data-only), we might still be here.
    // However, `updatePushPermission(false)` clears the token, so we shouldn't receive them strictly speaking.
    // BUT, broadcast messages or other triggers might still occur, or race conditions.
    // So masking here is good double-protection.

    // Since we don't have SharedPreferences imported, and I want to avoid adding an import if I can avoid it
    // (to keep diff small), I will assume if the user cleared the token, they won't get the message.
    // BUT, for LOCAL notifications (triggered by app logic, e.g. "Timer Done"), they might still want them?
    // User said: "if someone has it turned off they will not receive push notifications, just in app notifications"
    // "In App" usually means UI (Red Dot). "Push" means System Tray.
    // So `_showNotification` (which posts to System Tray) should be gated.

    // Let's imply we check a flag. I'll add a boolean `_suppressSystemTray` to the service,
    // which `updatePushPermission` updates.
    // Actually, `updatePushPermission` is async and called from settings.
    // I can stick a static flag or singleton field here.
    if (_pushDisabled) {
      logger.info("🔕 Suppressing system notification: $title");
      return;
    }

    // Notification details
    const androidDetails = AndroidNotificationDetails(
      'nerd_herd_channel',
      'Nerd Herd Notifications',
      channelDescription:
          'Notifications for collaboration requests and messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show notification
    // Encode the full data map as the payload so we don't lose context on tap
    final payloadMap = data ?? {'type': type};
    if (!payloadMap.containsKey('type')) payloadMap['type'] = type;

    await _notifications.show(
      id.hashCode, // Use notification ID hash as int ID
      title,
      body,
      details,
      payload: jsonEncode(payloadMap),
    );

    logger.info('📬 Notification shown: $title');
  }

  /// Manually show a notification (for testing or custom triggers)
  Future<void> showCustomNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'nerd_herd_channel',
      'Nerd Herd Notifications',
      channelDescription:
          'Notifications for collaboration requests and messages',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Reset the app icon badge
  Future<void> resetBadge() async {
    // Badge is only supported on mobile/macOS, not Web or Windows/Linux
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }

    try {
      if (await FlutterAppBadger.isAppBadgeSupported()) {
        await FlutterAppBadger.removeBadge();
        logger.info("✅ App Badge Reset");
      }
    } catch (e) {
      logger
          .warning("Could not reset badge (platform might not support it): $e");
    }
  }

  /// Mark notification as read in database
  Future<void> markAsRead(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'read': true}).eq('id', notificationId);
    } catch (e) {
      logger.error('Error marking notification as read', error: e);
    }
  }

  /// Fetch unread notification count
  Future<int> getUnreadCount() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final data = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false);

      return data.length;
    } catch (e) {
      logger.error('Error fetching unread count', error: e);
      return 0;
    }
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    await _notifications.cancelAll();
  }
}

// Global instance
final notificationService = NotificationService();
