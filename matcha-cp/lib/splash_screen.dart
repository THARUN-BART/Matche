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
    print('SplashScreen: initState called');
    _initializeAppAndCheckAuth();
    
    // Add a timeout to prevent getting stuck
    Future.delayed(Duration(seconds: 10), () {
      if (mounted) {
        print('SplashScreen: Timeout reached, forcing navigation to Login');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Login()),
        );
      }
    });
  }

  Future<void> _initializeAppAndCheckAuth() async {
    try {
      print('SplashScreen: Starting initialization...');
      // Standard splash screen delay
      await Future.delayed(Duration(milliseconds: 1000));
      print('SplashScreen: Delay completed');

      // Check authentication state
      await _checkAuthState();
    } catch (e) {
      print('SplashScreen: Error during app initialization: $e');
      // Even if there's an error, try to check auth state
      try {
        await _checkAuthState();
      } catch (authError) {
        print('SplashScreen: Error in auth check: $authError');
        // If all else fails, go to login
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => Login()),
          );
        }
      }
    }
  }

  Future<void> _checkAuthState() async {
    try {
      print('SplashScreen: Checking auth state...');
      User? user = FirebaseAuth.instance.currentUser;
      print('SplashScreen: Current user: ${user?.uid ?? 'null'}');

      if (user != null) {
        try {
          print('SplashScreen: User exists, checking Firestore...');
          // Get user data from Firestore
          DocumentSnapshot userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          print('SplashScreen: Firestore document exists: ${userDoc.exists}');

          if (userDoc.exists) {
            // Store FCM token for background notifications
            print('SplashScreen: Storing FCM token...');
            await _storeFCMToken(user.uid);
            
            print('SplashScreen: Navigating to MainNavigation...');
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation()),
              );
            }
          } else {
            print('SplashScreen: User doc not found, navigating to Login...');
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => Login()),
              );
            }
          }
        } catch (e) {
          print('SplashScreen: Error checking user doc: $e');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => Login()),
            );
          }
        }
      } else {
        print('SplashScreen: No user, navigating to Login...');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => Login()),
          );
        }
      }
    } catch (e) {
      print('SplashScreen: Error in _checkAuthState: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Login()),
        );
      }
    }
  }

  Future<void> _storeFCMToken(String userId) async {
    try {
      print('SplashScreen: Getting FCM token...');
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        print('SplashScreen: FCM token obtained, storing...');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'fcmToken': token});
        print('SplashScreen: FCM token stored successfully');
      } else {
        print('SplashScreen: FCM token is null');
      }
    } catch (e) {
      print('SplashScreen: Error storing FCM token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('SplashScreen: Building UI...');
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