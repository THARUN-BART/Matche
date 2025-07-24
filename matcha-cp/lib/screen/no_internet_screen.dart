import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:matcha/main.dart';

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AlertDialog(
          title: const Text("⚠ No Internet"),
          content: const Text("Please check your internet connection."),
          actions: [
            TextButton(
              child: const Text("Retry"),
              onPressed: () async {
                final result = await Connectivity().checkConnectivity();
                if (result != ConnectivityResult.none) {
                  // Rebuild app on internet recovery
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const Matcha()),
                  );
                }
              },
            )
          ],
        ),
      ),
    );
  }
}
