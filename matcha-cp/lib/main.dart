import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:matcha/firebase_options.dart';
import 'package:matcha/service/firestore_service.dart';
import 'package:matcha/service/notification_service.dart';
import 'package:matcha/service/matching_service.dart';
import 'package:matcha/service/group_service.dart';
import 'package:matcha/service/realtime_chat_service.dart';
import 'package:matcha/splash_screen.dart';
import 'package:provider/provider.dart';

Future _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  FirebaseDatabase.instance.databaseURL = 'https://matche-39f37-default-rtdb.firebaseio.com';
  // Handle background message
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase only if not already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    
    // Initialize Firebase Realtime Database
    FirebaseDatabase.instance.databaseURL = 'https://matche-39f37-default-rtdb.firebaseio.com';
    
    // Register background message handler after Firebase is initialized
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Initialize notification service
    await NotificationService().initialize();
    
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
        // Handle hidden state if needed
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
    );
  }
}