import 'package:flutter/material.dart';

class ErrorScreen extends StatelessWidget {
  final String errorMessage;

  const ErrorScreen({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 80),
              SizedBox(height: 20),
              Text(
                "Oops! Something went wrong.",
                style: TextStyle(color: Colors.white, fontSize: 22),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                errorMessage,
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Retry"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
