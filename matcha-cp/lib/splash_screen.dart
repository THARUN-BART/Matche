import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:matcha/screen/error_screen.dart';
import 'package:matcha/screen/main_navigation.dart';
import 'package:matcha/service/notification_service.dart';
import 'package:matcha/screen/no_internet_screen.dart';
import 'Authentication/welcome_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _initializationCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivityAndInitialize();

    // Timeout fallback
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && !_initializationCompleted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const welcome_page()),
        );
      }
    });
  }

  Future<void> _checkConnectivityAndInitialize() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();

      if (connectivity == ConnectivityResult.none) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const NoInternetScreen()),
          );
        }
        return;
      }

      await _testInternetConnectivity();
      await _initializeAppAndCheckAuth();

    } catch (e) {
      print('Connectivity check failed: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NoInternetScreen()),
        );
      }
    }
  }

  Future<void> _testInternetConnectivity() async {
    try {
      await FirebaseFirestore.instance
          .collection('test')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      throw Exception('No internet connectivity');
    }
  }

  Future<void> _initializeAppAndCheckAuth() async {
    try {
      await _initializeNotifications();
      await Future.delayed(const Duration(milliseconds: 1000));
      await _checkAuthState();
      _initializationCompleted = true;
    } catch (e) {
      _navigateToErrorScreen('Initialization failed: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await NotificationService().initialize();
      } else {
        print('Notification permission denied - continuing without notifications');
      }
    } catch (e) {
      print('Notification setup error: $e');
    }
  }

  Future<void> _checkAuthState() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          await _storeFCMToken(user.uid);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigation()),
            );
          }
        } else {
          _navigateToLogin();
        }
      } else {
        _navigateToLogin();
      }
    } catch (e) {
      print('Auth check failed: $e');
      _navigateToLogin();
    }
  }

  Future<void> _storeFCMToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });

        await NotificationService().storeTokenAfterLogin(userId);
      }
    } catch (e) {
      print('Failed to store FCM token: $e');
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const welcome_page()),
      );
    }
  }

  void _navigateToErrorScreen(String message) {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ErrorScreen(errorMessage: message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image(image: AssetImage('Assets/Main_IC.png'), width: 250),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}