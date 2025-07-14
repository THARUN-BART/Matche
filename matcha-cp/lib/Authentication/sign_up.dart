import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:email_otp/email_otp.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:matcha/screen/main_navigation.dart';
import 'package:matcha/service/notification_service.dart';
import '../constants/Constant.dart';
import 'dart:async';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ConfirmpasswordController = TextEditingController();
  final _otpController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _otpSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isEmailLocked = false;

  // Countdown timer variables
  Timer? _countdownTimer;
  int _countdownSeconds = 0;
  bool _canResendOTP = true;

  String selectedGender = 'Male';
  DateTime? selectedDOB;
  int? calculatedAge;

  // User data to pass to skills screen
  Map<String, dynamic>? userData;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ConfirmpasswordController.dispose();
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  bool isValidPhone(String phone) => RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone);
  bool isValidEmail(String email) => RegExp(r'^[\w.%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);

  void showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? Colors.green : Colors.red),
    );
  }

  void _startCountdown() {
    setState(() {
      _countdownSeconds = 60; // 1 minute countdown
      _canResendOTP = false;
    });

    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        setState(() {
          _canResendOTP = true;
        });
        timer.cancel();
      }
    });
  }

  void _enableEmailEdit() {
    setState(() {
      _isEmailLocked = false;
      _otpSent = false;
      _otpController.clear();
    });
    _countdownTimer?.cancel();
    setState(() {
      _canResendOTP = true;
      _countdownSeconds = 0;
    });
  }

  Future<void> _storeFCMTokenForNewUser(String userId) async {
    try {
      print('Getting FCM token for new user during signup: $userId');

      // Get FCM token
      String? token = await FirebaseMessaging.instance.getToken();

      if (token != null && token.isNotEmpty) {
        print('FCM token obtained during signup: ${token.substring(0, 20)}...');

        // Store token in Firestore immediately
        await _firestore.collection('users').doc(userId).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Also store in notification service
        await NotificationService().storeTokenAfterLogin(userId);

        print('FCM token stored successfully during signup: $userId');
      } else {
        print('FCM token is null or empty during signup: $userId');
      }
    } catch (e) {
      print('Error storing FCM token during signup: $e');
      // Don't throw error to avoid blocking signup process
    }
  }

  Future<bool> isEmailRegistered(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) return true;
      final snap = await _firestore.collection("users").where("email", isEqualTo: email).limit(1).get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();

    if (!isValidEmail(email)) return showSnack("Invalid email");
    if (await isEmailRegistered(email)) return showSnack("Email already registered");

    setState(() => _isLoading = true);

    EmailOTP.config(
      appName: "MATCHE",
      appEmail: "tharunpoongavanam@gmail.com",
      otpLength: 6,
      otpType: OTPType.numeric,
      expiry: 300000,
    );
    final sent = await EmailOTP.sendOTP(email: email);

    setState(() {
      _otpSent = sent;
      _isLoading = false;
      _isEmailLocked = sent;
    });

    if (sent) {
      _startCountdown();
      showSnack("OTP sent successfully", success: true);
    } else {
      showSnack("Failed to send OTP");
    }
  }

  Future<void> resendOTP() async {
    if (!_canResendOTP) return;

    final email = _emailController.text.trim();
    setState(() => _isLoading = true);

    final sent = await EmailOTP.sendOTP(email: email);

    setState(() => _isLoading = false);

    if (sent) {
      _startCountdown();
      showSnack("OTP resent successfully", success: true);
    } else {
      showSnack("Failed to resend OTP");
    }
  }

  Future<void> verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) return showSnack("Enter valid 6-digit OTP");

    setState(() => _isLoading = true);
    final verified = await EmailOTP.verifyOTP(otp: otp);

    if (!verified) {
      setState(() => _isLoading = false);
      return showSnack("Incorrect OTP");
    }

    try {
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _storeFCMTokenForNewUser(userCred.user!.uid);

      // Create userData map here, before using it
      final Map<String, dynamic> userData = {
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "email": _emailController.text.trim(),
        "gender": selectedGender,
        "dob": selectedDOB?.toIso8601String(),
        "age": calculatedAge,
        "uid": userCred.user!.uid,
      };

      // Store it in instance variable for later use if needed
      this.userData = userData;

      setState(() => _isLoading = false);

      // Now pass the userData to RulesScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RulesScreen(userData: userData),
        ),
      );
    } catch (e) {
      showSnack("Signup failed: ${e.toString()}");
      setState(() => _isLoading = false);
    }
  }

  Widget buildTextField(TextEditingController controller, String label, IconData icon, {bool isEmail = false,TextInputType? inputType}) {
    return TextFormField(
      controller: controller,
      enabled: !_isEmailLocked || !isEmail,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.0),
        ),
        prefixIcon: Icon(icon),
        suffixIcon: isEmail && _isEmailLocked ?
        IconButton(
          icon: Icon(Icons.edit, color: Colors.blue),
          onPressed: _enableEmailEdit,
          tooltip: 'Edit Email',
        ) : null,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return "Enter $label";
        if (label == "Phone Number" && !isValidPhone(v)) return "Invalid phone number";
        if (isEmail && !isValidEmail(v)) return "Invalid email";
        return null;
      },
      keyboardType: inputType ?? (isEmail ? TextInputType.emailAddress : TextInputType.text),
    );
  }

  Widget buildPasswordField(String labelText, TextEditingController controller, {TextEditingController? compareWith}) {
    return TextFormField(
      controller: controller,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.0),
        ),
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return "Enter $labelText";
        if (value.length < 6) return "Min 6 characters";
        if (compareWith != null && value != compareWith.text) return "Passwords do not match";
        return null;
      },
    );
  }

  Widget buildOTPField() {
    return Column(
      children: [
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Enter 6-digit OTP",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.0),
            ),
            prefixIcon: Icon(Icons.sms),
          ),
          validator: (v) => v == null || v.length != 6 ? "Enter valid OTP" : null,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _canResendOTP ? "Didn't receive OTP? " : "Resend OTP in ${_countdownSeconds}s",
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (_canResendOTP)
              TextButton(
                onPressed: _isLoading ? null : resendOTP,
                child: Text(
                  "Resend",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget buildDOBPicker() {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(now.year - 18),
          firstDate: DateTime(1900),
          lastDate: now,
        );

        if (picked != null) {
          final age = now.year - picked.year -
              ((now.month < picked.month || (now.month == picked.month && now.day < picked.day)) ? 1 : 0);

          if (age <= 13) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Age Restriction'),
                content: Text('You must be at least 13 years old to use this feature.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('OK'),
                  ),
                ],
              ),
            );
            return;
          }

          setState(() {
            selectedDOB = picked;
            calculatedAge = age;
          });
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date of Birth',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedDOB == null
                  ? 'Select Date'
                  : "${selectedDOB!.day}/${selectedDOB!.month}/${selectedDOB!.year}",
              style: TextStyle(
                color: selectedDOB == null ? Colors.grey[600] : null,
                fontSize: 16,
              ),
            ),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }

  Widget buildStyledButton({
    required String text,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required Color textColor,
    bool isLoading = false,
  }) {
    return Container(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 3,
        ),
        child: isLoading
            ? SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(textColor),
          ),
        )
            : Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('Assets/Star.png', height: 100),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_outlined,size: 30.0),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                buildTextField(_nameController, "Full Name", Icons.person),
                const SizedBox(height: 16),
                buildTextField(_phoneController, "Phone Number", Icons.phone,inputType: TextInputType.number),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  items: ['Male', 'Female', 'Other']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedGender = val!),
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                buildDOBPicker(),
                const SizedBox(height: 16),
                buildTextField(_emailController, "Email Address", Icons.email, isEmail: true),
                const SizedBox(height: 16),
                buildPasswordField('Password', _passwordController),
                const SizedBox(height: 16),
                buildPasswordField('Confirm Password', _ConfirmpasswordController, compareWith: _passwordController),
                const SizedBox(height: 24),
          
                if (_otpSent) ...[
                  buildOTPField(),
                  const SizedBox(height: 16),
                ],
          
                if (!_otpSent)
                  buildStyledButton(
                    text: "Send OTP",
                    onPressed: _isLoading ? null : sendOTP,
                    backgroundColor: Color(0xFFFFEC3D),
                    textColor: Colors.black,
                    isLoading: _isLoading,
                  ),
          
                if (_otpSent) ...[
                  buildStyledButton(
                    text: "Verify & Continue",
                    onPressed: _isLoading ? null : verifyOTP,
                    backgroundColor: Colors.green,
                    textColor: Colors.white,
                    isLoading: _isLoading,
                  ),
                ],
          
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
    );
  }
}

// Fixed RulesScreen class with proper userData handling
class RulesScreen extends StatefulWidget {
  final Map<String, dynamic> userData; // Add this parameter

  const RulesScreen({super.key, required this.userData}); // Make it required

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Image.asset('Assets/Star.png', height: 100),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_outlined,
            size: 30.0,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const Text(
                    'Welcome to Matche.',
                    style: TextStyle(
                      color: Color(0xFFFFEC3D),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Adhere to these rules to continue.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Rules list
            Expanded(
              child: Column(
                children: [
                  _buildRuleItem(
                    'Be honest.',
                    'Fill out the Questions honestly to find your best match peer.',
                  ),
                  const SizedBox(height: 30),
                  _buildRuleItem(
                    'Stay safe.',
                    'All your Chats are monitored to protect you.',
                  ),
                  const SizedBox(height: 30),
                  _buildRuleItem(
                    'Chill out.',
                    'Respect others and treat them as you would like to be treated.',
                  ),
                  const SizedBox(height: 30),
                  _buildRuleItem(
                    'Provide Feedback.',
                    'Your valuable feedback enhances your experience.',
                  ),
                ],
              ),
            ),

            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 30),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SkillsSelectionScreen(userData: widget.userData), // Use widget.userData
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEC3D),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'I AGREE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Check icon
        Container(
          margin: const EdgeInsets.only(top: 2),
          child: const Icon(
            Icons.check,
            color: Color(0xFFFFEC3D),
            size: 20,
          ),
        ),
        const SizedBox(width: 15),
        // Text content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFFFEC3D),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class SkillsSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SkillsSelectionScreen({super.key, required this.userData});

  @override
  State<SkillsSelectionScreen> createState() => _SkillsSelectionScreenState();
}

class _SkillsSelectionScreenState extends State<SkillsSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> selectedSkills = [];
  List<String> filteredSkills = [];
  bool _isLoading = false;



  @override
  void initState() {
    super.initState();
    filteredSkills = allSkills;
    _searchController.addListener(_filterSkills);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSkills() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredSkills = allSkills
          .where((skill) => skill.toLowerCase().contains(query))
          .toList();
    });
  }

  void _toggleSkill(String skill) {
    setState(() {
      if (selectedSkills.contains(skill)) {
        selectedSkills.remove(skill);
      } else {
        selectedSkills.add(skill);
      }
    });
  }

  Future<void> _storeFCMToken(String userId) async {
    try {
      print('Getting FCM token for new user: $userId');
      
      // Get FCM token
      String? token = await FirebaseMessaging.instance.getToken();
      
      if (token != null && token.isNotEmpty) {
        print('FCM token obtained for new user: ${token.substring(0, 20)}...');
        
        // Store token in Firestore
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        
        // Also store in notification service
        await NotificationService().storeTokenAfterLogin(userId);
        
        print('FCM token stored successfully for new user: $userId');
      } else {
        print('FCM token is null or empty for new user: $userId');
      }
    } catch (e) {
      print('Error storing FCM token for new user: $e');
      // Don't throw error to avoid blocking signup process
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);

    try {
      // Add skills to user data
      final userData = Map<String, dynamic>.from(widget.userData);
      userData['skills'] = selectedSkills;

      // Get and store FCM token
      await _storeFCMToken(userData['uid']);

      // Save to Firestore
      await _firestore.collection("users").doc(userData['uid']).set(userData);

      // Navigate to home page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
            (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving data: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _skipToHome() async {
    setState(() => _isLoading = true);

    try {
      // Save user data without skills
      final userData = Map<String, dynamic>.from(widget.userData);
      userData['skills'] = <String>[];

      // Get and store FCM token
      await _storeFCMToken(userData['uid']);

      await _firestore.collection("users").doc(userData['uid']).set(userData);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
            (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving data: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Skills", style: GoogleFonts.salsa(fontSize: 24, color: Colors.black)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "What skills do you have?",
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  "Add skills to help others find you (optional)",
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search skills...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),
                if (selectedSkills.isNotEmpty) ...[
                  Text(
                    "Selected Skills (${selectedSkills.length})",
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: selectedSkills.map((skill) => Chip(
                      label: Text(skill, style: const TextStyle(color: Colors.white)),
                      backgroundColor: Colors.blue,
                      deleteIcon: const Icon(Icons.close, color: Colors.white, size: 16),
                      onDeleted: () => _toggleSkill(skill),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredSkills.length,
              itemBuilder: (context, index) {
                final skill = filteredSkills[index];
                final isSelected = selectedSkills.contains(skill);

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(skill),
                    trailing: Icon(
                      isSelected ? Icons.check_circle : Icons.add_circle_outline,
                      color: isSelected ? Colors.green : Colors.grey,
                    ),
                    onTap: () => _toggleSkill(skill),
                    selected: isSelected,
                    selectedTileColor: Colors.blue.shade50,
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _skipToHome,
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text("Skip"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveAndContinue,
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : Text("Continue${selectedSkills.isNotEmpty ? ' (${selectedSkills.length})' : ''}"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}