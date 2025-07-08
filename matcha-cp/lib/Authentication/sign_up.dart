import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_otp/email_otp.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:matcha/screen/main_navigation.dart';
import '../constants/Constant.dart';

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
    super.dispose();
  }

  bool isValidPhone(String phone) => RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone);
  bool isValidEmail(String email) => RegExp(r'^[\w.%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);

  void showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? Colors.green : Colors.red),
    );
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
    });

    showSnack(sent ? "OTP sent" : "Failed to send OTP", success: sent);
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

      // Prepare user data for skills screen
      userData = {
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "email": _emailController.text.trim(),
        "gender": selectedGender,
        "dob": selectedDOB?.toIso8601String(),
        "age": calculatedAge,
        "uid": userCred.user!.uid,
      };

      setState(() => _isLoading = false);

      // Navigate to skills selection screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SkillsSelectionScreen(userData: userData!),
        ),
      );
    } catch (e) {
      showSnack("Signup failed: ${e.toString()}");
      setState(() => _isLoading = false);
    }
  }

  Widget buildTextField(TextEditingController controller, String label, IconData icon, {bool isEmail = false}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return "Enter $label";
        if (label == "Phone Number" && !isValidPhone(v)) return "Invalid phone number";
        if (isEmail && !isValidEmail(v)) return "Invalid email";
        return null;
      },
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
    );
  }

  Widget buildPasswordField(String labelText, TextEditingController controller, {TextEditingController? compareWith}) {
    return TextFormField(
      controller: controller,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
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
    return TextFormField(
      controller: _otpController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: "Enter 6-digit OTP",
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.sms),
      ),
      validator: (v) => v == null || v.length != 6 ? "Enter valid OTP" : null,
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
          setState(() {
            selectedDOB = picked;
            calculatedAge = now.year - picked.year - ((now.month < picked.month || (now.month == picked.month && now.day < picked.day)) ? 1 : 0);
          });
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date of Birth',
          border: OutlineInputBorder(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("SIGN UP", style: GoogleFonts.salsa(fontSize: 32)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              buildTextField(_nameController, "Full Name", Icons.person),
              const SizedBox(height: 16),
              buildTextField(_phoneController, "Phone Number", Icons.phone),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedGender,
                items: ['Male', 'Female', 'Other']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (val) => setState(() => selectedGender = val!),
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
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
              if (_otpSent) buildOTPField(),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : sendOTP,
                child: _isLoading ? const CircularProgressIndicator() : const Text("Send OTP"),
              ),
              const SizedBox(height: 12),
              if (_otpSent)
                ElevatedButton(
                  onPressed: _isLoading ? null : verifyOTP,
                  child: _isLoading ? const CircularProgressIndicator() : const Text("Verify & Continue"),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Skills Selection Screen
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

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);

    try {
      // Add skills to user data
      final userData = Map<String, dynamic>.from(widget.userData);
      userData['skills'] = selectedSkills;

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