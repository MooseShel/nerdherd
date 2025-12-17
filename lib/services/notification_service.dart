import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart'; // For MaterialPageRoute
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  print("Handling a background message: ${message.messageId}");
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

    // Request permissions (Local + FCM)
    await _requestPermissions();

    // Init FCM
    await _initFCM();

    _initialized = true;
    logger.info('📬 Notification service initialized');
  }

  /// Initialize Firebase Cloud Messaging
  Future<void> _initFCM() async {
    try {
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
      if (Platform.isIOS) {
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

      // Set background handler (needs to be static or top-level)
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    } catch (e) {
      logger.error(
          'Error initializing FCM (likely due to missing config or Web/Emulator environment)',
          error: e);
    }
  }

  /// Save FCM token to Supabase profiles
  Future<void> _saveTokenToDatabase(String token) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Call the RPC function we created
      await supabase.rpc('update_fcm_token', params: {'token': token});
      logger.info('✅ FCM Token saved to database');
    } catch (e) {
      logger.error('Error saving FCM token', error: e);
      // Fallback: Try direct update if RPC fails (though RPC is preferred for security)
      try {
        await supabase
            .from('profiles')
            .update({'fcm_token': token}).eq('user_id', userId);
      } catch (e2) {
        logger.error('Fallback update also failed', error: e2);
      }
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
    final payload = response.payload;
    if (payload == null) return;

    logger.info('🔔 Notification tapped with payload: $payload');
    final parts = payload.split(':');
    final type = parts[0];
    final id = parts.length > 1 ? parts[1] : null;

    if (navigatorKey.currentState == null) {
      logger.warning('⚠️ Navigator key not attached to context');
      return;
    }

    try {
      if (type == 'chat_message' && id != null) {
        // Fetch user profile and navigate to chat
        final profileData = await supabase
            .from('profiles')
            .select()
            .eq('user_id', id)
            .maybeSingle();

        if (profileData != null) {
          final profile = UserProfile.fromJson(profileData);
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => ChatPage(otherUser: profile),
            ),
          );
        }
      } else if (type == 'collab_request') {
        // Navigate to RequestsPage
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => const RequestsPage(),
          ),
        );
      }
    } catch (e) {
      logger.error('Error handling notification navigation', error: e);
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
    await _notifications.show(
      id.hashCode, // Use notification ID hash as int ID
      title,
      body,
      details,
      payload: type, // Pass type as payload for handling taps
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
