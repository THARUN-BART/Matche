import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:matcha/firebase_options.dart';
import 'package:matcha/service/firestore_service.dart';
import 'package:matcha/service/notification_service.dart';
import 'package:matcha/service/matching_service.dart';
import 'package:matcha/service/group_service.dart';
import 'package:matcha/service/realtime_chat_service.dart';
import 'package:matcha/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> initializeFirebaseIfNeeded() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      print('Firebase initialized successfully');
    } else {
      print('Firebase already initialized');
      // Optionally, you can get the default app to ensure it's working
      Firebase.app();
    }
  } catch (e) {
    print('Error initializing Firebase: $e');
    // Handle specific Firebase initialization errors
    if (e.toString().contains('duplicate-app')) {
      print('Firebase app already exists, continuing...');
      // This is not necessarily an error, just log and continue
    } else {
      // Re-throw other errors as they might be critical
      rethrow;
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await initializeFirebaseIfNeeded();

    // Set Firebase Database URL if not already set
    if (FirebaseDatabase.instance.databaseURL == null) {
      FirebaseDatabase.instance.databaseURL = 'https://matche-39f37-default-rtdb.firebaseio.com';
    }

    print('Handling a background message: ${message.messageId}');
    print('Message data: ${message.data}');
    print('Message notification: ${message.notification?.title}');

    await _showBackgroundNotification(message);
  } catch (e) {
    print('Error in background message handler: $e');
  }
}

@pragma('vm:entry-point')
Future<void> _showBackgroundNotification(RemoteMessage message) async {
  try {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'matcha_notifications',
      'Matcha Notifications',
      channelDescription: 'Notifications for Matcha app',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'New Message',
      message.notification?.body ?? 'You have a new message',
      platformDetails,
      payload: json.encode(message.data),
    );
  } catch (e) {
    print('Error showing background notification: $e');
  }
}

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase with error handling
    await initializeFirebaseIfNeeded();

    // Set Firebase Database URL
    FirebaseDatabase.instance.databaseURL = 'https://matche-39f37-default-rtdb.firebaseio.com';

    // Initialize OneSignal
    OneSignal.initialize('8021659f-9f75-426b-8b81-6656c45b229a');
    await OneSignal.Notifications.requestPermission(true);

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize notification service
    await NotificationService().initialize();

    runApp(
      MultiProvider(
        providers: [
          Provider<FirestoreService>(create: (_) => FirestoreService()),
          Provider<NotificationService>(create: (_) => NotificationService()),
          Provider<MatchingService>(create: (_) => MatchingService()),
          Provider<GroupService>(create: (_) => GroupService()),
          Provider<RealtimeChatService>(create: (_) => RealtimeChatService()),
        ],
        child: const Matcha(),
      ),
    );
  } catch (e) {
    print('Error in main: $e');
    // You might want to show an error screen or handle this differently
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('App initialization failed'),
                SizedBox(height: 8),
                Text('Please restart the app'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Matcha extends StatefulWidget {
  const Matcha({super.key});

  @override
  State<Matcha> createState() => _MatchaState();
}

class _MatchaState extends State<Matcha> with WidgetsBindingObserver {
  late RealtimeChatService _chatService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatService = RealtimeChatService();
    _setOnlineStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _setOnlineStatus(true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _setOnlineStatus(false);
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _setOnlineStatus(bool isOnline) async {
    try {
      await _chatService.setOnlineStatus(isOnline);
    } catch (e) {
      print('Error setting online status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
      theme: ThemeData.dark(useMaterial3: true),
    );
  }
}