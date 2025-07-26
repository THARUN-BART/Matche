import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:email_otp/email_otp.dart';
import 'package:matcha/Authentication/skills_section.dart';
import 'package:matcha/service/notification_service.dart';
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
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _otpSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isEmailLocked = false;

  // Countdown timer variables
  Timer? _countdownTimer;
  int _countdownSeconds = 0;
  bool _canResendOTP = true;

  String selectedGender = 'Male';
  DateTime? selectedDOB;
  int? calculatedAge;
  bool _showAgeError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  bool isValidPhone(String phone) => RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone);
  bool isValidEmail(String email) => RegExp(r'^[\w.%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);

  String? passwordValidator(String? value, String labelText, {TextEditingController? compareWith}) {
    if (value == null || value.isEmpty) return "Enter $labelText";
    if (value.length < 6) return "Min 6 characters";
    if (!RegExp(r'[A-Z]').hasMatch(value)) return "Include at least one uppercase letter";
    if (!RegExp(r'[0-9]').hasMatch(value)) return "Include at least one number";
    if (!RegExp(r'[!@#\$&*~]').hasMatch(value)) return "Include at least one symbol";
    if (compareWith != null && value != compareWith.text) return "Passwords do not match";
    return null;
  }

  void showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startCountdown() {
    setState(() {
      _countdownSeconds = 60;
      _canResendOTP = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        setState(() => _countdownSeconds--);
      } else {
        setState(() => _canResendOTP = true);
        timer.cancel();
      }
    });
  }

  void _enableEmailEdit() {
    setState(() {
      _isEmailLocked = false;
      _otpSent = false;
      _otpController.clear();
      _canResendOTP = true;
      _countdownSeconds = 0;
    });
    _countdownTimer?.cancel();
  }

  Future<void> _storeFCMTokenForNewUser(String userId) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();

      if (token != null && token.isNotEmpty) {
        await _firestore.collection('users').doc(userId).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await NotificationService().storeTokenAfterLogin(userId);
      }
    } catch (e) {
      print('Error storing FCM token: $e');
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

    if (!isValidEmail(email)) {
      showSnack("Please enter a valid email address");
      return;
    }

    if (await isEmailRegistered(email)) {
      showSnack("This email is already registered");
      return;
    }

    setState(() => _isLoading = true);

    EmailOTP.config(
      appName: "MATCHE",
      appEmail: "tharunpoongavanam@gmail.com",
      otpLength: 6,
      otpType: OTPType.numeric,
      expiry: 300000,
    );

    try {
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
    } catch (e) {
      setState(() => _isLoading = false);
      showSnack("Error sending OTP: ${e.toString()}");
    }
  }

  Future<void> resendOTP() async {
    if (!_canResendOTP) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();

    try {
      final sent = await EmailOTP.sendOTP(email: email);
      setState(() => _isLoading = false);

      if (sent) {
        _startCountdown();
        showSnack("OTP resent successfully", success: true);
      } else {
        showSnack("Failed to resend OTP");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      showSnack("Error resending OTP: ${e.toString()}");
    }
  }

  Future<void> verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      showSnack("Please enter a valid 6-digit OTP");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final verified = await EmailOTP.verifyOTP(otp: otp);

      if (!verified) {
        setState(() => _isLoading = false);
        showSnack("Incorrect OTP. Please try again.");
        return;
      }

      final userCred = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _storeFCMTokenForNewUser(userCred.user!.uid);

      final userData = {
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "email": _emailController.text.trim(),
        "gender": selectedGender,
        "dob": selectedDOB?.toIso8601String(),
        "age": calculatedAge,
        "uid": userCred.user!.uid,
      };

      setState(() => _isLoading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RulesScreen(userData: userData),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      showSnack("Signup failed: ${e.toString()}");
    }
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFFEC3D),
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final age = now.year - picked.year -
          ((now.month < picked.month || (now.month == picked.month && now.day < picked.day)) ? 1 : 0);

      if (age <= 13) {
        setState(() {
          selectedDOB = null;
          calculatedAge = null;
          _showAgeError = true;
        });
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Age Restriction'),
            content: const Text('You must be at least 13 years old to use this app.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      setState(() {
        selectedDOB = picked;
        calculatedAge = age;
        _showAgeError = false;
      });
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isEmail = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isEmailLocked || !isEmail,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: Icon(icon),
        suffixIcon: isEmail && _isEmailLocked
            ? IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          onPressed: _enableEmailEdit,
          tooltip: 'Edit Email',
        )
            : null,
      ),
      keyboardType: keyboardType,
      validator: validator ?? (v) {
        if (v == null || v.trim().isEmpty) return "Enter $label";
        if (label.contains("Phone") && !isValidPhone(v)) return "Invalid phone number";
        if (isEmail && !isValidEmail(v)) return "Invalid email";
        return null;
      },
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggleVisibility,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildOTPField() {
    return Column(
      children: [
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Enter 6-digit OTP",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.sms),
          ),
          validator: (v) => v == null || v.length != 6 ? "Enter valid OTP" : null,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _canResendOTP ? "Didn't receive OTP? " : "Resend OTP in $_countdownSeconds",
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (_canResendOTP)
              TextButton(
                onPressed: _isLoading ? null : resendOTP,
                child: const Text(
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

  Widget _buildDateOfBirthField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _selectDateOfBirth,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Date of Birth',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              errorText: _showAgeError ? 'You must be at least 13 years old' : null,
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
                  ),
                ),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
        ),
        if (calculatedAge != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Age: $calculatedAge',
              style: const TextStyle(color: Colors.green),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Text(
          text,
          style: const TextStyle(
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
          icon: const Icon(Icons.arrow_back_ios_outlined, size: 30.0),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(
                controller: _nameController,
                label: "Full Name",
                icon: Icons.person,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                label: "Phone Number",
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedGender,
                items: ['Male', 'Female', 'Other']
                    .map((g) => DropdownMenuItem(
                  value: g,
                  child: Text(g),
                ))
                    .toList(),
                onChanged: (val) => setState(() => selectedGender = val!),
                decoration: InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildDateOfBirthField(),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: "Email Address",
                icon: Icons.email,
                isEmail: true,
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _passwordController,
                label: 'Password',
                obscureText: _obscurePassword,
                onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                validator: (v) => passwordValidator(v, 'Password'),
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                obscureText: _obscureConfirmPassword,
                onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                validator: (v) => passwordValidator(v, 'Confirm Password', compareWith: _passwordController),
              ),
              const SizedBox(height: 24),

              if (_otpSent) ...[
                _buildOTPField(),
                const SizedBox(height: 16),
              ],

              if (!_otpSent)
                _buildActionButton(
                  text: "Send OTP",
                  onPressed: _isLoading ? null : sendOTP,
                  backgroundColor: const Color(0xFFFFEC3D),
                  isLoading: _isLoading,
                ),

              if (_otpSent)
                _buildActionButton(
                  text: "Verify & Continue",
                  onPressed: _isLoading ? null : verifyOTP,
                  backgroundColor: Colors.green,
                  isLoading: _isLoading,
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class RulesScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const RulesScreen({super.key, required this.userData});

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
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
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

            Expanded(
              child: ListView(
                children: const [
                  _RuleItem(
                    icon: Icons.check,
                    title: 'Be honest.',
                    description: 'Fill out the Questions honestly to find your best match peer.',
                  ),
                  SizedBox(height: 30),
                  _RuleItem(
                    icon: Icons.security,
                    title: 'Stay safe.',
                    description: 'All your Chats are monitored to protect you.',
                  ),
                  SizedBox(height: 30),
                  _RuleItem(
                    icon: Icons.people,
                    title: 'Chill out.',
                    description: 'Respect others and treat them as you would like to be treated.',
                  ),
                  SizedBox(height: 30),
                  _RuleItem(
                    icon: Icons.feedback,
                    title: 'Provide Feedback.',
                    description: 'Your valuable feedback enhances your experience.',
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
                      builder: (context) => SkillsSelectionScreen(userData: widget.userData),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 0,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.black, Color(0xFFFFEC3D)],
                      begin: Alignment.centerRight,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    child: const Text(
                      'I AGREE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _RuleItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            color: const Color(0xFFFFEC3D),
            size: 20,
          ),
        ),
        const SizedBox(width: 15),
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