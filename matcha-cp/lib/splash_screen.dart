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
  @override
  void initState() {
    super.initState();
    print('SplashScreen: initState called');
    _checkConnectivityAndInitialize();

    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        print('SplashScreen: Timeout reached, forcing navigation to Login');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const welcome_page()),
        );
      }
    });
  }

  Future<void> _checkConnectivityAndInitialize() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const NoInternetScreen()),
      );
      return;
    }

    await _initializeAppAndCheckAuth();
  }

  Future<void> _initializeAppAndCheckAuth() async {
    try {
      await _initializeNotifications();
      await Future.delayed(const Duration(milliseconds: 1000));
      await _checkAuthState();
    } catch (e) {
      _navigateToErrorScreen('Initialization failed: $e');
    }
  }

  /// Requests notification permission and sets up Firebase Messaging
  Future<void> _initializeNotifications() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Notification permission granted');
        await NotificationService().initialize();
      } else {
        _navigateToErrorScreen('Notification permission denied');
      }
    } catch (e) {
      _navigateToErrorScreen('Notification setup error: $e');
    }
  }

  /// Checks if the user is logged in and navigates accordingly
  Future<void> _checkAuthState() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      print('SplashScreen: Current user: ${user?.uid ?? "null"}');

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
        print('FCM token stored');
      } else {
        print('FCM token is null');
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
            Image(
              image: AssetImage('Assets/Main_IC.png'),
              width: 250,
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
