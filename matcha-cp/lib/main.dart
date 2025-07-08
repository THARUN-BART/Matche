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

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseDatabase.instance.databaseURL = 'https://matche-39f37-default-rtdb.firebaseio.com';
  // Handle background message
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize Firebase Realtime Database
  FirebaseDatabase.instance.databaseURL = 'https://matche-39f37-default-rtdb.firebaseio.com';
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService().initialize();
  runApp(MultiProvider(
    providers: [
      Provider<FirestoreService>(create: (_) => FirestoreService()),
      Provider<NotificationService>(create: (_) => NotificationService()),
      Provider<MatchingService>(create: (context) => MatchingService(context.read<FirestoreService>())),
      Provider<GroupService>(create: (_) => GroupService()),
      Provider<RealtimeChatService>(create: (_) => RealtimeChatService()),
    ],
    child: const Matcha(),
  ),
  );
}

class Matcha extends StatelessWidget {
  const Matcha({super.key});

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