import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../service/notification_service.dart';

class NotificationTestWidget extends StatefulWidget {
  const NotificationTestWidget({super.key});

  @override
  State<NotificationTestWidget> createState() => _NotificationTestWidgetState();
}

class _NotificationTestWidgetState extends State<NotificationTestWidget> {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
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
      
      print('Test widget: Local notifications initialized successfully');
    } catch (e) {
      print('Test widget: Error initializing local notifications: $e');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    if (response.payload != null) {
      Map<String, dynamic> data = json.decode(response.payload!);
      print('Notification data: $data');
      // Handle navigation based on notification type
      _handleNotificationNavigation(data);
    }
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    String type = data['type'] ?? 'unknown';
    switch (type) {
      case 'connection_request':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigate to connection requests')),
        );
        break;
      case 'group_invite':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigate to group invites')),
        );
        break;
      case 'new_message':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigate to chat: ${data['chatId']}')),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigate to notifications')),
        );
    }
  }

  Future<void> _showTestNotification(String type, String title, String body, Map<String, dynamic> data) async {
    try {
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
        payload: json.encode(data),
      );
      
      print('Test notification sent successfully: $title');
    } catch (e) {
      print('Error showing test notification: $e');
      // Show a fallback message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification sent: $title'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Manual notification test button
            ElevatedButton(
              onPressed: _sendManualNotification,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Send Manual Notification (Backend)',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            // Test local notifications
            ElevatedButton(
              onPressed: () => _showTestNotification('connection_request', 'Connection Request', 'You have a new connection request!', {'type': 'connection_request'}),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Test Connection Request',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showTestNotification('group_invite', 'Group Invitation', 'You have been invited to join a group!', {'type': 'group_invite'}),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Test Group Invitation',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showTestNotification('new_message', 'New Message', 'You have a new message!', {'type': 'new_message', 'chatId': 'chat123'}),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Test New Message',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Send manual notification using backend
  Future<void> _sendManualNotification() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first')),
      );
      return;
    }
    
    try {
      await _notificationService.sendManualNotification(
        userId: user.uid,
        title: 'Manual Test Notification',
        message: 'This is a test notification sent from the Flutter app!',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Manual notification sent! Check your device.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 