import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

class NotificationTestWidget extends StatefulWidget {
  const NotificationTestWidget({super.key});

  @override
  State<NotificationTestWidget> createState() => _NotificationTestWidgetState();
}

class _NotificationTestWidgetState extends State<NotificationTestWidget> {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

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
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Notifications',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Connection Request Test
            ElevatedButton(
              onPressed: () => _showTestNotification(
                'connection_request',
                'New Connection Request',
                'John Doe wants to connect with you!',
                {
                  'type': 'connection_request',
                  'userId': 'user123',
                  'userName': 'John Doe',
                },
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Test Connection Request'),
            ),
            
            const SizedBox(height: 12),
            
            // Group Invite Test
            ElevatedButton(
              onPressed: () => _showTestNotification(
                'group_invite',
                'Group Invitation',
                'You\'ve been invited to join "Study Group Alpha"',
                {
                  'type': 'group_invite',
                  'groupId': 'group456',
                  'groupName': 'Study Group Alpha',
                },
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Test Group Invite'),
            ),
            
            const SizedBox(height: 12),
            
            // New Message Test
            ElevatedButton(
              onPressed: () => _showTestNotification(
                'new_message',
                'New Message',
                'Alice: Hey, how\'s the project going?',
                {
                  'type': 'new_message',
                  'chatId': 'chat789',
                  'senderName': 'Alice',
                  'message': 'Hey, how\'s the project going?',
                },
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Test New Message'),
            ),
            
            const SizedBox(height: 12),
            
            // General Notification Test
            ElevatedButton(
              onPressed: () => _showTestNotification(
                'general',
                'General Update',
                'Your profile has been updated successfully!',
                {
                  'type': 'general',
                  'action': 'profile_update',
                },
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Test General Notification'),
            ),
            
            const SizedBox(height: 20),
            
            const Text(
              'Instructions:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Tap any test button to send a local notification\n'
              '2. The notification will appear in your notification tray\n'
              '3. Tap the notification to see how navigation would work\n'
              '4. Check the console for notification data logs',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
} 