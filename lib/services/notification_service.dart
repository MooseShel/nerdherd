import 'package:flutter/material.dart'; // For MaterialPageRoute
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger_service.dart';
import '../config/navigation.dart'; // For navigatorKey
import '../chat_page.dart';
import '../requests_page.dart'; // For RequestsPage navigation
import '../models/user_profile.dart';

/// Service to handle local notifications and real-time alerts.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final supabase = Supabase.instance.client;

  bool _initialized = false;
  RealtimeChannel? _notificationChannel;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

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

    // Initialize
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();

    _initialized = true;
    logger.info('📬 Notification service initialized');
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
