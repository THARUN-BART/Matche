import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

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
    try {
      // Request permission for iOS
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');
      } else {
        print('User declined or has not accepted permission');
      }

      // Get FCM token
      String? token = await _messaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        // Store token in Firestore (will be called after login)
      }

      // Handle token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        print('FCM Token refreshed: $newToken');
        // Update token in Firestore
        _updateTokenInFirestore(newToken);
      });

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Load initial badge count
      await _loadBadgeCount();
    } catch (e) {
      print('Error initializing notifications: $e');
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
        print('FCM token stored for user: $userId');
      }
    } catch (e) {
      print('Error storing FCM token: $e');
    }
  }

  // Update token in Firestore
  Future<void> _updateTokenInFirestore(String token) async {
    try {
      // Get current user ID from your auth service
      // This is a placeholder - implement based on your auth system
      String? userId = _getCurrentUserId();
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  // Get current user ID (implement based on your auth system)
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
      
      print('Local notifications initialized successfully');
    } catch (e) {
      print('Error initializing local notifications: $e');
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      _showLocalNotification(message);
    }
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
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
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformChannelSpecifics,
      payload: json.encode(message.data),
    );
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    // Navigate to appropriate screen based on message data
    _navigateToScreen(message.data);
  }

  // Handle local notification tap
  void _onNotificationTap(NotificationResponse response) {
    print('Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      Map<String, dynamic> data = json.decode(response.payload!);
      _navigateToScreen(data);
    }
  }

  // Navigate to appropriate screen
  void _navigateToScreen(Map<String, dynamic> data) {
    // TODO: Implement navigation based on notification type
    // Example:
    // if (data['type'] == 'connection_request') {
    //   // Navigate to connections screen
    // } else if (data['type'] == 'group_invite') {
    //   // Navigate to groups screen
    // }
  }

  // Handle notification tap with navigation
  void handleNotificationTap(Map<String, dynamic> data, BuildContext context) {
    final type = data['type'];
    
    switch (type) {
      case 'connection_request':
        // Navigate to matches screen with requests tab
        Navigator.pushNamed(context, '/matches', arguments: {'tab': 'requests'});
        break;
        
      case 'connection_accepted':
      case 'connection_made':
        // Navigate to matches screen with matches tab
        Navigator.pushNamed(context, '/matches', arguments: {'tab': 'matches'});
        break;
        
      case 'connection_rejected':
        // Navigate to matches screen with suggestions tab
        Navigator.pushNamed(context, '/matches', arguments: {'tab': 'suggestions'});
        break;
        
      case 'message':
        // Navigate to chat screen
        final chatId = data['chatId'];
        final senderId = data['senderId'];
        final senderName = data['senderName'];
        if (chatId != null && senderId != null && senderName != null) {
          Navigator.pushNamed(context, '/chat', arguments: {
            'chatId': chatId,
            'otherUserId': senderId,
            'otherUserName': senderName,
          });
        }
        break;
        
      case 'group_message':
        // Navigate to group chat screen
        final groupId = data['groupId'];
        final groupName = data['groupName'];
        if (groupId != null && groupName != null) {
          Navigator.pushNamed(context, '/group-chat', arguments: {
            'groupId': groupId,
            'groupName': groupName,
          });
        }
        break;
        
      case 'group_invitation':
        // Navigate to group invitations screen
        Navigator.pushNamed(context, '/group-invitations');
        break;
        
      default:
        // Navigate to messages screen for unknown types
        Navigator.pushNamed(context, '/messages');
        break;
    }
  }

  // Subscribe to topics (optional)
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  // Unsubscribe from topics
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  // Clear token on logout
  Future<void> clearTokenOnLogout(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (e) {
      print('Error clearing FCM token: $e');
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

  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'read': true,
    });
    
    // Update badge count
    _badgeCount = _badgeCount > 0 ? _badgeCount - 1 : 0;
    _badgeController.add(_badgeCount);
  }

  Future<void> clearAllNotifications() async {
    if (_auth.currentUser != null) {
      // Mark all notifications as read
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
      
      // Reset badge count
      _badgeCount = 0;
      _badgeController.add(_badgeCount);
    }
  }

  // Send notification to specific user
  Future<void> sendNotificationToUser({
    required String toUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Get user's FCM token
    final userDoc = await _firestore.collection('users').doc(toUserId).get();
    final fcmToken = userDoc.data()?['fcmToken'];
    
    if (fcmToken != null) {
      // Store notification in Firestore
      await _firestore.collection('notifications').add({
        'to': toUserId,
        'title': title,
        'body': body,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
      
      // Note: For actual FCM sending, you'll need a server-side implementation
      // This is just storing the notification locally
    }
  }

  // Public method to show a local notification with title and body
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

  void dispose() {
    _badgeController.close();
  }
} 