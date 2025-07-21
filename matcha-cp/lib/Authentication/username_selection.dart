import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UsernameSelectionScreen extends StatefulWidget {
  final VoidCallback? onUsernameSet;
  const UsernameSelectionScreen({Key? key, this.onUsernameSet}) : super(key: key);

  @override
  State<UsernameSelectionScreen> createState() => _UsernameSelectionScreenState();
}

class _UsernameSelectionScreenState extends State<UsernameSelectionScreen> {
  final TextEditingController _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;

  Future<bool> _isUsernameTaken(String username) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> _submit() async {
    final username = _controller.text.trim();
    setState(() { _error = null; });
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });
    try {
      if (await _isUsernameTaken(username)) {
        setState(() { _error = 'Username already taken'; _isLoading = false; });
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() { _error = 'Not logged in. Please sign in again.'; _isLoading = false; });
        // Optionally, you could navigate to the login screen here
        return;
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'username': username,
      }, SetOptions(merge: true));
      if (widget.onUsernameSet != null) {
        widget.onUsernameSet!();
        return;
      } else if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() { _error = 'Error: $e'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  String? _validate(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter a username';
    final username = value.trim();
    if (!RegExp(r'^[a-zA-Z0-9_@]+$').hasMatch(username)) {
      return '3-20 chars, letters, numbers, @ and _ only';
    }
    return null;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Image.asset('Assets/Star.png', height: 100),
        centerTitle: true,
      leading: IconButton(onPressed: (){
        Navigator.pop(context);
      }, icon: Icon(Icons.arrow_back_ios)),),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('Assets/Main_IC.png'),
              Text('Pick a unique username to use in the app.', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  errorText: _error,
                ),
                validator: _validate,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFFEC3D)
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading ? CircularProgressIndicator() : Text('Continue',style: TextStyle(color: Colors.black),),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 