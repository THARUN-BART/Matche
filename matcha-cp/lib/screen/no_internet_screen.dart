import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../splash_screen.dart';

class NoInternetScreen extends StatefulWidget {
  const NoInternetScreen({super.key});

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen> {
  bool _isRetrying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 80, color: Colors.white70),
              const SizedBox(height: 20),
              const Text(
                "No Internet Connection",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Please check your connection and try again.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 30),
              _isRetrying
                  ? const Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFFFFEC3D)),
                  SizedBox(height: 12),
                  Text(
                    "Checking connection...",
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              )
                  : ElevatedButton.icon(
                onPressed: _retryConnection,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry",style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFEC3D),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retryConnection() async {
    setState(() {
      _isRetrying = true;
    });

    try {
      // Optional: short delay for loading UX
      await Future.delayed(const Duration(milliseconds: 300));

      final connectivity = await Connectivity().checkConnectivity();

      if (connectivity != ConnectivityResult.none) {
        final hasInternet = await _hasInternetAccess();
        if (hasInternet && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SplashScreen()),
          );
          return;
        }
      }

      if (mounted) {
        _showRetryMessage("Still no internet connection. Please check your network settings.");
      }
    } catch (e) {
      if (mounted) {
        _showRetryMessage("Error checking connection. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  Future<bool> _hasInternetAccess() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('test').limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _showRetryMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
