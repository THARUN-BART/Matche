import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:matcha/Authentication/Login.dart';
import 'package:matcha/screen/main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAppAndCheckAuth();
  }

  Future<void> _initializeAppAndCheckAuth() async {
    try {
      // Standard splash screen delay
      await Future.delayed(Duration(milliseconds: 1000));

      // Check authentication state
      _checkAuthState();
    } catch (e) {
      print('Error during app initialization: $e');
      _checkAuthState();
    }
  }

  Future<void> _checkAuthState() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        // Get user data from Firestore
        DocumentSnapshot userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          // Store FCM token for background notifications
          await _storeFCMToken(user.uid);
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainNavigation()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => Login()),
          );
        }
      } catch (e) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Login()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Login()),
      );
    }
  }

  Future<void> _storeFCMToken(String userId) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'fcmToken': token});
      }
    } catch (e) {
      print('Error storing FCM token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'Assets/Matche_Ic.png',
              width: 450,
              height: 450,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}