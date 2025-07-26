import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:matcha/Authentication/username_selection.dart';
import 'package:matcha/screen/main_navigation.dart';
import 'package:matcha/service/notification_service.dart';
import '../widget/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscureText = true;
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage("Error", "Please enter both email and password");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await NotificationService().storeTokenAfterLogin(userCredential.user!.uid);

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        final data = userDoc.data();
        final needsUsername = data == null ||
            data['username'] == null ||
            (data['username'] as String).trim().isEmpty;

        if (needsUsername) {
          final usernameSet = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => UsernameSelectionScreen(
                userData: data ?? {},
                onUsernameSet: () {},
              ),
            ),
          );

          if (usernameSet != true) {
            await FirebaseAuth.instance.signOut();
            setState(() => _isLoading = false);
            return;
          }
        }

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "Login failed. Please try again.";

      switch (e.code) {
        case 'user-not-found':
          message = "No user found with this email.";
          break;
        case 'wrong-password':
          message = "Wrong password. Please try again.";
          break;
        case 'user-disabled':
          message = "This account has been disabled.";
          break;
        case 'invalid-email':
          message = "Invalid email address.";
          break;
        case 'too-many-requests':
          message = "Too many failed login attempts. Please try again later.";
          break;
      }

      _showMessage("Login Error", message);
    } catch (e) {
      _showMessage("Error", "An unexpected error occurred. Please try again.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                "Enter your email address to receive a password reset link.",
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
              child: const Text("CANCEL"),
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
                final email = _forgotPasswordEmailController.text.trim();
                if (email.isEmpty) {
                  _showMessage("Error", "Please enter your email address");
                  return;
                }

                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                  _showMessage("Error", "Please enter a valid email address");
                  return;
                }

                setDialogState(() => _isResettingPassword = true);
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  if (!mounted) return;
                  Navigator.pop(context);
                  _showMessage(
                    "Reset Link Sent",
                    "If an account exists for this email, you'll receive a password reset link.",
                  );
                } on FirebaseAuthException catch (e) {
                  String message = "Failed to send reset link. Please try again.";
                  switch (e.code) {
                    case 'invalid-email':
                      message = "Please enter a valid email address.";
                      break;
                    case 'user-not-found':
                      message = "If an account exists for this email, you'll receive a reset link.";
                      break;
                    case 'too-many-requests':
                      message = "Too many reset attempts. Please wait before trying again.";
                      break;
                  }
                  _showMessage("Password Reset", message);
                } catch (e) {
                  _showMessage("Error", "An unexpected error occurred.");
                } finally {
                  setDialogState(() => _isResettingPassword = false);
                }
              },
              child: const Text("SEND RESET LINK"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_outlined, size: 30.0),
          onPressed: () => Navigator.pop(context),
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
                  textStyle: const TextStyle(
                    fontSize: 50,
                    color: Color(0xFFFFEC3D),
                  ),
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
                obscureText: _obscureText,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : GradientButton(
                text: "LOGIN",
                onPressed: _login,
              ),
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