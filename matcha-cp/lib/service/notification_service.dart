import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../constants/Constant.dart';
import '../main.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const bool useOneSignal = true;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Badge count for app bar
  int _badgeCount = 0;
  int get badgeCount => _badgeCount;

  // Stream controller for badge updates
  final StreamController<int> _badgeController = StreamController<int>.broadcast();
  Stream<int> get badgeStream => _badgeController.stream;

  // Initialize notification service
  Future<void> initialize() async {
    if (useOneSignal) {
      await _initializeOneSignal();
      // Add OneSignal notification event handlers
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('OneSignal notification clicked: ${event.notification.title}');
        // Handle notification tap (navigate, etc.)
      });
    }
    try {
      // Request permission for iOS
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: true,
        carPlay: true,
        criticalAlert: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
      } else {
        debugPrint('User declined or has not accepted notification permission: ${settings.authorizationStatus}');
      }

      // Get FCM token and store in Firestore if logged in
      String? token = await _messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        if (useOneSignal) {
          await OneSignal.login(token);
          debugPrint('Set OneSignal external user ID to FCM token using OneSignal.login');
        }
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          await storeTokenAfterLogin(currentUser.uid);
        }
      }

      // Handle token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('FCM Token refreshed: $newToken');
        if (useOneSignal) {
          await OneSignal.login(newToken);
          debugPrint('Updated OneSignal external user ID to new FCM token using OneSignal.login');
        }
        _updateTokenInFirestore(newToken);
      });

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Initial notification when app is opened from terminated state
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App opened from terminated state with notification: ${initialMessage.data}');
        _handleNotificationTap(initialMessage);
      }

      // Load initial badge count
      await _loadBadgeCount();

      debugPrint('Notification service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  // Store FCM token in Firestore after login
  Future<void> storeTokenAfterLogin(String userId) async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        debugPrint('FCM token stored for user: $userId');
      }
    } catch (e) {
      debugPrint('Error storing FCM token: $e');
    }
  }

  // Update token in Firestore
  Future<void> _updateTokenInFirestore(String token) async {
    try {
      String? userId = _getCurrentUserId();
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  // Get current user ID
  String? _getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      await _createNotificationChannel();
      debugPrint('Local notifications initialized successfully');
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  // Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'matcha_notifications',
      'Matcha Notifications',
      description: 'Notifications for Matcha app',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Got a message whilst in the foreground!');
    debugPrint('Message data: ${message.data}');
    debugPrint('Message notification: ${message.notification?.title} - ${message.notification?.body}');
    _showLocalNotification(message);
    _badgeCount++;
    _badgeController.add(_badgeCount);
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'matcha_notifications',
        'Matcha Notifications',
        channelDescription: 'Notifications for Matcha app',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF2196F3),
      );
      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
      );
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );
      final notificationId = message.hashCode;
      final title = message.notification?.title ?? message.data['title'] ?? 'New Message';
      final body = message.notification?.body ?? message.data['body'] ?? 'You have a new message';
      await _localNotifications.show(
        notificationId,
        title,
        body,
        platformChannelSpecifics,
        payload: json.encode(message.data),
      );
      debugPrint('Local notification shown: $title - $body');
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  // Handle notification tap (background/terminated)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
    final data = message.data;
    final type = data['type'];
    switch (type) {
      case 'connection_request':
        _showNotificationSnackbar('You have a new connection request!');
        break;
      case 'connection_accepted':
        _showNotificationSnackbar('Your connection request was accepted!');
        break;
      case 'group_invitation':
        _showNotificationSnackbar('You have a new group invitation!');
        break;
      default:
        // Ignore other types
        break;
    }
  }

  // Handle local notification tap (foreground)
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      Map<String, dynamic> data = json.decode(response.payload!);
      final type = data['type'];
      switch (type) {
        case 'connection_request':
          _showNotificationSnackbar('You have a new connection request!');
          break;
        case 'connection_accepted':
          _showNotificationSnackbar('Your connection request was accepted!');
          break;
        case 'group_invitation':
          _showNotificationSnackbar('You have a new group invitation!');
          break;
        default:
          // Ignore other types
          break;
      }
    }
  }

  void _showNotificationSnackbar(String message) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // Mark a notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'read': true,
    });
    _badgeCount = _badgeCount > 0 ? _badgeCount - 1 : 0;
    _badgeController.add(_badgeCount);
  }

  // Mark all notifications as read
  Future<void> clearAllNotifications() async {
    if (_auth.currentUser != null) {
      final batch = _firestore.batch();
      final unreadQuery = await _firestore
          .collection('notifications')
          .where('to', isEqualTo: _auth.currentUser!.uid)
          .where('read', isEqualTo: false)
          .get();
      for (var doc in unreadQuery.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
      _badgeCount = 0;
      _badgeController.add(_badgeCount);
    }
  }

  // Send notification to a specific user (stores in Firestore)
  Future<void> sendNotificationToUser({
    required String toUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final userDoc = await _firestore.collection('users').doc(toUserId).get();
    final fcmToken = userDoc.data()?['fcmToken'];
    if (fcmToken != null) {
      await _firestore.collection('notifications').add({
        'to': toUserId,
        'title': title,
        'body': body,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
      // Note: For actual FCM sending, you'll need a server-side implementation
    }
  }

  // Show a local notification with title and body
  Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'matcha_notifications',
      'Matcha Notifications',
      channelDescription: 'Notifications for Matcha app',
      importance: Importance.max,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  // Send an FCM notification (requires server key)
  Future<void> sendFCMNotification({
    required String token,
    required String title,
    required String body,
  }) async {
    const serverKey = 'YOUR_SERVER_KEY'; // Replace with your FCM server key
    await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
      body: jsonEncode({
        'to': token,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      }),
    );
  }

  // Test notification function for debugging
  Future<void> testNotification() async {
    try {
      debugPrint('Testing local notification...');
      await showLocalNotification(
        title: 'Test Notification',
        body: 'This is a test notification from Matcha!',
      );
      debugPrint('Test notification sent successfully');
    } catch (e) {
      debugPrint('Error sending test notification: $e');
    }
  }

  // Get current FCM token for debugging
  Future<String?> getCurrentFCMToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('Current FCM token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  // OneSignal initialization
  Future<void> _initializeOneSignal() async {
    OneSignal.initialize('8021659f-9f75-426b-8b81-6656c45b229a');
    OneSignal.Notifications.requestPermission(true);
    // No navigation logic needed
  }

  // Get the OneSignal player ID for this device (for backend targeting)
  Future<String?> getOneSignalPlayerId() async {
    if (!useOneSignal) return null;
    return await OneSignal.User.pushSubscription.id;
  }

  // Helper to log out from OneSignal (call on user logout)
  Future<void> logoutFromOneSignal() async {
    if (useOneSignal) {
      await OneSignal.logout();
      debugPrint('Logged out from OneSignal (external user ID cleared)');
    }
  }

  // Manual notification test using deployed backend
  Future<void> sendManualNotification({
    required String userId,
    required String title,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(' $backendBaseUrl/notify-user'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'title': title,
          'message': message,
        }),
      );
      
      if (response.statusCode == 200) {
        debugPrint('Manual notification sent successfully');
      } else {
        debugPrint('Failed to send manual notification: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending manual notification: $e');
    }
  }

  Future<void> _loadBadgeCount() async {
    if (_auth.currentUser != null) {
      final unreadQuery = await _firestore
          .collection('notifications')
          .where('to', isEqualTo: _auth.currentUser!.uid)
          .where('read', isEqualTo: false)
          .get();
      _badgeCount = unreadQuery.docs.length;
      _badgeController.add(_badgeCount);
    }
  }

  void dispose() {
    _badgeController.close();
  }
}