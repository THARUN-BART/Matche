import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:matcha/firebase_options.dart';
import 'package:matcha/service/firestore_service.dart';
import 'package:matcha/service/notification_service.dart';
import 'package:matcha/service/matching_service.dart';
import 'package:matcha/service/group_service.dart';
import 'package:matcha/service/realtime_chat_service.dart';
import 'package:matcha/widget/network_aware_widget.dart';
import 'package:matcha/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
bool _firebaseInitialized = false;

Future<void> initializeFirebaseIfNeeded() async {
  if (_firebaseInitialized) return;

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      print('Firebase initialized');
    } else {
      print('Firebase already initialized');
    }
    _firebaseInitialized = true;
  } catch (e) {
    if (e.toString().contains('[core/duplicate-app]')) {
      print('Duplicate app detected, ignoring');
    } else {
      print('Firebase init error: $e');
      rethrow;
    }
  }
}

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebaseIfNeeded();

  FirebaseDatabase.instance.databaseURL = 'https://matche-39f37-default-rtdb.firebaseio.com';

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => FirestoreService()),
        Provider(create: (_) => NotificationService()),
        Provider(create: (_) => MatchingService()),
        Provider(create: (_) => GroupService()),
        Provider(create: (_) => RealtimeChatService()),
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
      navigatorKey: navigatorKey,
      theme: ThemeData.dark(useMaterial3: true),
      home: const NetworkAwareWidget(
        child: SplashScreen(),
      ),
    );
  }
}

