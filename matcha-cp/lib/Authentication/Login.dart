import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:matcha/Authentication/username_selection.dart';
import 'package:matcha/screen/main_navigation.dart';
import 'package:matcha/service/notification_service.dart';

import '../widget/gradient_button.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool _obsecureText = true;
  bool _isLoading = false;
  bool _isResettingPassword = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _forgotPasswordEmailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _forgotPasswordEmailController.dispose();
    super.dispose();
  }

  void _showMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage("Error", "Please enter both email and password");
      return;
    }

    try {
      setState(() => _isLoading = true);

      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await NotificationService().storeTokenAfterLogin(userCredential.user!.uid);
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
        final data = userDoc.data();
        bool needsUsername = data == null || data['username'] == null || (data['username'] as String).trim().isEmpty;
        if (needsUsername) {
          // Wait for username to be set
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => UsernameSelectionScreen()),
          );

          final updatedDoc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
          final updatedData = updatedDoc.data();
          if (updatedData == null || updatedData['username'] == null || (updatedData['username'] as String).trim().isEmpty) {
            // Still no username, show error and return
            _showMessage("Username Required", "You must set a username to continue.");
            setState(() => _isLoading = false);
            return;
          }
        }
        // Only now proceed to main app
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MainNavigation()),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "Login failed. Please try again.";

      if (e.code == 'user-not-found') {
        message = "No user found with this email.";
      } else if (e.code == 'wrong-password') {
        message = "Wrong password. Please try again.";
      } else if (e.code == 'user-disabled') {
        message = "This account has been disabled.";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email address.";
      } else if (e.code == 'too-many-requests') {
        message = "Too many failed login attempts. Please try again later.";
      }

      _showMessage("Login Error", message);
    } catch (e) {
      _showMessage("Error", "An unexpected error occurred. Please try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    _forgotPasswordEmailController.text = _emailController.text;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Reset Password"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Enter your email address and we'll send you a link to reset your password.",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _forgotPasswordEmailController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Email",
                  hintText: 'Enter your email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: _isResettingPassword ? null : () => Navigator.pop(context),
                child: const Text("CANCEL")
            ),
            _isResettingPassword
                ? const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : TextButton(
              onPressed: () async {
                setDialogState(() => _isResettingPassword = true);
                final email = _forgotPasswordEmailController.text.trim();

                // Basic email validation
                if (email.isEmpty) {
                  setDialogState(() => _isResettingPassword = false);
                  _showMessage("Error", "Please enter your email address");
                  return;
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}').hasMatch(email)) {
                  setDialogState(() => _isResettingPassword = false);
                  _showMessage("Error", "Please enter a valid email address");
                  return;
                }

                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  setDialogState(() => _isResettingPassword = false);
                  Navigator.pop(context); // Only close if successful
                  _showMessage(
                    "Reset Link Sent",
                    "If an account with this email exists, you'll receive a password reset link shortly. Please check your inbox and spam folder."
                  );
                } on FirebaseAuthException catch (e) {
                  setDialogState(() => _isResettingPassword = false);
                  String message = "Failed to send reset link. Please try again.";
                  switch (e.code) {
                    case 'invalid-email':
                      message = "Please enter a valid email address.";
                      break;
                    case 'user-not-found':
                      message = "If an account with this email exists, you'll receive a password reset link shortly.";
                      break;
                    case 'too-many-requests':
                      message = "Too many reset attempts. Please wait before trying again.";
                      break;
                    default:
                      message = "Failed to send reset link. Please try again later.";
                  }
                  _showMessage("Password Reset", message);
                  // Do NOT close the dialog here, so user can correct the email
                } catch (e) {
                  setDialogState(() => _isResettingPassword = false);
                  _showMessage("Error", "An unexpected error occurred. Please try again.");
                }
              },
              child: const Text("SEND RESET LINK"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _forgotPasswordEmailController.text.trim();

    if (email.isEmpty) {
      _showMessage("Error", "Please enter your email address");
      return;
    }

    // Basic email validation
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showMessage("Error", "Please enter a valid email address");
      return;
    }

    try {
      // Send password reset email directly without checking Firestore
      // Firebase Auth will handle whether the user exists or not
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      _showMessage(
          "Reset Link Sent",
          "If an account with this email exists, you'll receive a password reset link shortly. Please check your inbox and spam folder."
      );
    } on FirebaseAuthException catch (e) {
      String message = "Failed to send reset link. Please try again.";

      switch (e.code) {
        case 'invalid-email':
          message = "Please enter a valid email address.";
          break;
        case 'user-not-found':
        // For security, we don't want to reveal if a user exists or not
          message = "If an account with this email exists, you'll receive a password reset link shortly.";
          break;
        case 'too-many-requests':
          message = "Too many reset attempts. Please wait before trying again.";
          break;
        default:
          message = "Failed to send reset link. Please try again later.";
      }

      _showMessage("Password Reset", message);
    } catch (e) {
      print("Password reset error: $e"); // For debugging
      _showMessage("Error", "An unexpected error occurred. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_outlined, size: 30.0),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            children: [
              Image.asset('Assets/Main_IC.png', width: 300),
              Text(
                'Sign In',
                style: GoogleFonts.salsa(
                  textStyle: const TextStyle(fontSize: 50, color: Color(0xFFFFEC3D)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  labelText: "Email",
                  hintText: 'abc@gmail.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obsecureText,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(_obsecureText ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obsecureText = !_obsecureText),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : GradientButton(text: "LOGIN", onPressed: _login),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _showForgotPasswordDialog,
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}