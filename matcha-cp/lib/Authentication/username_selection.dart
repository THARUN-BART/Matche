import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screen/main_navigation.dart';

class UsernameSelectionScreen extends StatefulWidget {
  final VoidCallback? onUsernameSet;
  final Map<String, dynamic> userData;

  const UsernameSelectionScreen({
    Key? key,
    this.onUsernameSet,
    required this.userData,
  }) : super(key: key);

  @override
  State<UsernameSelectionScreen> createState() => _UsernameSelectionScreenState();
}

class _UsernameSelectionScreenState extends State<UsernameSelectionScreen> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  String? _lastCheckedUsername;

  Future<bool> _isUsernameTaken(String username) async {
    try {
      final lowerUsername = username.toLowerCase();

      if (_lastCheckedUsername == lowerUsername) {
        return false;
      }

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username_lowercase', isEqualTo: lowerUsername)
          .limit(1)
          .get();

      _lastCheckedUsername = lowerUsername;

      return snap.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking username: $e');
      return true;
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final username = _controller.text.trim();
    setState(() {
      _error = null;
      _isLoading = true;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Check username availability
      final isTaken = await _isUsernameTaken(username);
      if (isTaken) {
        setState(() => _error = 'Username already taken');
        return;
      }

      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _error = 'User not authenticated');
        return;
      }

      final userData = {
        ...widget.userData,
        'username': username,
        'username_lowercase': username.toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      };


      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));

      if (mounted) {
        widget.onUsernameSet?.call();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
              (route) => false,
        );
      }
    } catch (e) {
      setState(() => _error = 'Error: ${e.toString()}');
      debugPrint('Error saving username: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a username';
    }
    final username = value.trim();
    if (username.length < 3 || username.length > 20) {
      return '3-20 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_@]+$').hasMatch(username)) {
      return 'Letters, numbers, @, _ only';
    }
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('Assets/Star.png', height: 100),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('Assets/Main_IC.png'),
              const SizedBox(height: 16),
              const Text(
                'Pick a unique username to use in the app',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: _validate,
                enabled: !_isLoading,
                autofocus: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEC3D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                      : const Text(
                    'CONTINUE',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}