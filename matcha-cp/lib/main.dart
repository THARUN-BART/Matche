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
import 'package:firebase_auth/firebase_auth.dart';

// This needs to be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  
  // Initialize Firebase Realtime Database
  FirebaseDatabase.instance.databaseURL = 'https://matche-39f37-default-rtdb.firebaseio.com';
  
  print('Handling a background message: ${message.messageId}');
  print('Message data: ${message.data}');
  print('Message notification: ${message.notification?.title}');
  
  // Show local notification for background messages
  await _showBackgroundNotification(message);
}

// Show notification when app is in background
@pragma('vm:entry-point')
Future<void> _showBackgroundNotification(RemoteMessage message) async {
  try {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

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

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

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
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'New Message',
      message.notification?.body ?? 'You have a new message',
      platformChannelSpecifics,
      payload: json.encode(message.data),
    );
  } catch (e) {
    print('Error showing background notification: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    
    // Initialize Firebase Realtime Database
    FirebaseDatabase.instance.databaseURL = 'https://matche-39f37-default-rtdb.firebaseio.com';
    
    // Register background message handler after Firebase is initialized
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Initialize notification service
    await NotificationService().initialize();
    await FirebaseMessaging.instance.requestPermission();

    // Save FCM token to Firestore (after login)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await FirebaseMessaging.instance.getToken();
      await FirestoreService().saveFcmToken(user.uid, token);
    }

    runApp(MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<NotificationService>(create: (_) => NotificationService()),
        Provider<MatchingService>(create: (_) => MatchingService(apiBaseUrl: 'https://backend-u5oi.onrender.com')),
        Provider<GroupService>(create: (_) => GroupService()),
        Provider<RealtimeChatService>(create: (_) => RealtimeChatService()),
      ],
      child: const Matcha(),
    ));
  } catch (e) {
    print('Error initializing Firebase: $e');
    // Run app even if Firebase fails to initialize
    runApp(MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<NotificationService>(create: (_) => NotificationService()),
        Provider<MatchingService>(create: (_) => MatchingService(apiBaseUrl: 'https://backend-u5oi.onrender.com')),
        Provider<GroupService>(create: (_) => GroupService()),
        Provider<RealtimeChatService>(create: (_) => RealtimeChatService()),
      ],
      child: const Matcha(),
    ));
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
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
      theme: ThemeData.dark(useMaterial3: true)
    );
  }
}