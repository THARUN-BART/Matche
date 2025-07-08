import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matcha/Authentication/Login.dart';
import '../constants/Constant.dart';

class AccountInfo extends StatefulWidget {
  const AccountInfo({super.key});

  @override
  State<AccountInfo> createState() => _AccountInfoState();
}

class _AccountInfoState extends State<AccountInfo> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _interestController = TextEditingController();
  final TextEditingController _skillSearchController = TextEditingController();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isEditMode = false;
  String? _selectedGender;
  DateTime? _selectedDOB;

  // Availability system
  final List<String> timeSlots = ["6-8am", "8-10am", "4-6pm", "6-8pm", "8-10pm"];
  final List<String> days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  Map<String, List<String>> availability = {};

  // Interests system
  List<String> interests = [];

  List<String> filteredInterestOptions = [];

  // Skills system
  List<String> _userSkills = [];
  List<String> _filteredSkills = [];

  @override
  void initState() {
    super.initState();
    filteredInterestOptions = allInterestOptions;
    _filteredSkills = allSkills;
    _fetchUserData();
    _interestController.addListener(_filterInterestOptions);
    _skillSearchController.addListener(_filterSkills);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _interestController.dispose();
    _skillSearchController.dispose();
    super.dispose();
  }

  void _filterInterestOptions() {
    final query = _interestController.text.toLowerCase();
    setState(() {
      filteredInterestOptions = allInterestOptions
          .where((i) => i.toLowerCase().contains(query))
          .toList();
    });
  }

  void _filterSkills() {
    final query = _skillSearchController.text.toLowerCase();
    setState(() {
      _filteredSkills = allSkills
          .where((skill) => skill.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snap = await _firestore.collection("users").doc(user.uid).get();
      if (snap.exists) {
        setState(() {
          _userData = snap.data();
          _isLoading = false;
          _nameController.text = _userData?['name'] ?? "";
          _phoneController.text = _userData?['phone'] ?? "";
          _selectedGender = _userData?['gender'];

          // Handle DOB - convert from Timestamp or String
          if (_userData?['dob'] != null) {
            if (_userData!['dob'] is Timestamp) {
              _selectedDOB = (_userData!['dob'] as Timestamp).toDate();
            } else if (_userData!['dob'] is String) {
              _selectedDOB = DateTime.tryParse(_userData!['dob']);
            }
          }

          // Handle availability
          if (_userData?['availability'] != null) {
            final raw = _userData!['availability'] as Map<String, dynamic>;
            availability = raw.map((day, slots) => MapEntry(day, List<String>.from(slots)));
          } else {
            availability = {for (var day in days) day: []};
          }

          // Handle interests
          if (_userData?['interests'] != null) {
            interests = List<String>.from(_userData!['interests']);
          }

          // Handle skills
          if (_userData?['skills'] != null) {
            _userSkills = List<String>.from(_userData!['skills']);
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
    }
  }

  Future<void> _saveUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar("Name is required", Colors.red);
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _firestore.collection("users").doc(user.uid).update({
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "gender": _selectedGender,
        "dob": _selectedDOB != null ? Timestamp.fromDate(_selectedDOB!) : null,
        "availability": availability,
        "interests": interests,
        "skills": _userSkills,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      // Close loading dialog
      Navigator.pop(context);

      // Refresh user data
      await _fetchUserData();

      _showSnackBar("Profile updated successfully!", Colors.green);
      setState(() => _isEditMode = false);
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      _showSnackBar("Failed to update profile: $e", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Not set";
    return "${date.day}/${date.month}/${date.year}";
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? DateTime.now().subtract(const Duration(days: 6570)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: "Select Date of Birth",
    );
    if (picked != null) {
      setState(() {
        _selectedDOB = picked;
      });
    }
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const Login()),
          (route) => false,
    );
  }

  Widget buildDetail({required IconData icon, required String title, required String? value}) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(title),
      subtitle: Text(value ?? "Not provided"),
    );
  }

  Widget buildAvailabilityGrid(bool editable) {
    if (!editable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.schedule, color: Colors.deepPurple),
            title: const Text("Available Timings"),
            subtitle: Text("${availability.values.fold(0, (sum, slots) => sum + slots.length)} slots selected"),
          ),
          if (availability.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: availability.entries.map((e) => e.value.isNotEmpty ? Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text("${e.key}:", style: const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      Expanded(child: Text(e.value.join(', '))),
                    ],
                  ),
                ) : const SizedBox.shrink()).toList(),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text("Available to connect with peers", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            defaultColumnWidth: const FixedColumnWidth(80),
            children: [
              TableRow(
                children: [
                  const SizedBox(),
                  ...timeSlots.map((slot) => Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.blue.shade50,
                    child: Text(slot, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                  )),
                ],
              ),
              ...days.map((day) => TableRow(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.blue.shade50,
                    child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ...timeSlots.map((slot) {
                    final isSelected = availability[day]?.contains(slot) ?? false;
                    return Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          final slots = availability[day] ?? [];
                          if (value == true) {
                            if (!slots.contains(slot)) slots.add(slot);
                          } else {
                            slots.remove(slot);
                          }
                          availability[day] = slots;
                        });
                      },
                    );
                  }).toList(),
                ],
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildInterestsSection(bool editable) {
    if (!editable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.deepPurple),
            title: const Text("Interests"),
            subtitle: Text(interests.isEmpty ? "No interests added" : "${interests.length} interests"),
          ),
          if (interests.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: interests.map((interest) => Chip(
                  label: Text(interest, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.deepPurple.shade100,
                  labelStyle: TextStyle(color: Colors.deepPurple.shade800),
                )).toList(),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Your Interests", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: _showIntrestDialog,
              icon: const Icon(Icons.add),
              label: const Text("Add Interests"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: interests.map((interest) => Chip(
            label: Text(interest),
            backgroundColor: Colors.deepPurple.shade100,
            labelStyle: TextStyle(color: Colors.deepPurple.shade800),
            deleteIcon: const Icon(Icons.close),
            onDeleted: () => setState(() => interests.remove(interest)),
          )).toList(),
        ),
      ],
    );
  }

  Widget buildSkillsSection(bool editable) {
    if (!editable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.star, color: Colors.deepPurple),
            title: const Text("Skills"),
            subtitle: Text(_userSkills.isEmpty ? "No skills added" : "${_userSkills.length} skills"),
          ),
          if (_userSkills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _userSkills.map((skill) => Chip(
                  label: Text(skill, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.blue.shade100,
                  labelStyle: TextStyle(color: Colors.blue.shade800),
                )).toList(),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Your Skills", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: _showSkillsDialog,
              icon: const Icon(Icons.add),
              label: const Text("Manage Skills"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _userSkills.map((skill) => Chip(
            label: Text(skill),
            backgroundColor: Colors.blue.shade100,
            labelStyle: TextStyle(color: Colors.blue.shade800),
            deleteIcon: const Icon(Icons.close),
            onDeleted: () => setState(() => _userSkills.remove(skill)),
          )).toList(),
        ),
      ],
    );
  }

  void _showSkillsDialog() {
    List<String> tempSkills = List.from(_userSkills);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Manage Skills"),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: _skillSearchController,
                  decoration: InputDecoration(
                    hintText: "Search skills...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      _filterSkills();
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (tempSkills.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Selected Skills (${tempSkills.length})",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: tempSkills.map((skill) => Chip(
                          label: Text(skill, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          backgroundColor: Colors.blue,
                          deleteIcon: const Icon(Icons.close, color: Colors.white, size: 16),
                          onDeleted: () {
                            setDialogState(() {
                              tempSkills.remove(skill);
                            });
                          },
                        )).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredSkills.length,
                    itemBuilder: (context, index) {
                      final skill = _filteredSkills[index];
                      final isSelected = tempSkills.contains(skill);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          title: Text(skill, style: const TextStyle(fontSize: 14)),
                          trailing: Icon(
                            isSelected ? Icons.check_circle : Icons.add_circle_outline,
                            color: isSelected ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          onTap: () {
                            setDialogState(() {
                              if (isSelected) {
                                tempSkills.remove(skill);
                              } else {
                                tempSkills.add(skill);
                              }
                            });
                          },
                          selected: isSelected,
                          selectedTileColor: Colors.blue.shade50,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _skillSearchController.clear();
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _userSkills = tempSkills;
                });
                _skillSearchController.clear();
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  void _showIntrestDialog() {
    List<String> tempInterests = List.from(interests);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Manage Interests"),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: _interestController,
                  decoration: InputDecoration(
                    hintText: "Search interests...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      _filterInterestOptions();
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (tempInterests.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Selected Interests (${tempInterests.length})",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: tempInterests.map((interest) => Chip(
                          label: Text(interest, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          backgroundColor: Colors.deepPurple,
                          deleteIcon: const Icon(Icons.close, color: Colors.white, size: 16),
                          onDeleted: () {
                            setDialogState(() {
                              tempInterests.remove(interest);
                            });
                          },
                        )).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredInterestOptions.length,
                    itemBuilder: (context, index) {
                      final interest = filteredInterestOptions[index];
                      final isSelected = tempInterests.contains(interest);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          title: Text(interest, style: const TextStyle(fontSize: 14)),
                          trailing: Icon(
                            isSelected ? Icons.check_circle : Icons.add_circle_outline,
                            color: isSelected ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          onTap: () {
                            setDialogState(() {
                              if (isSelected) {
                                tempInterests.remove(interest);
                              } else {
                                tempInterests.add(interest);
                              }
                            });
                          },
                          selected: isSelected,
                          selectedTileColor: Colors.deepPurple.shade50,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _interestController.clear();
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  interests = tempInterests;
                });
                _interestController.clear();
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Account Info"),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
          ? const Center(child: Text("No user is logged in."))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.deepPurple,
                    child: Text(
                      _userData?['name'] != null && (_userData?['name'] as String).isNotEmpty
                          ? (_userData!['name'] as String)[0].toUpperCase()
                          : "?",
                      style: const TextStyle(color: Colors.white, fontSize: 32),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _userData?['name'] ?? "No Name",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const Divider(height: 32),

            if (!_isEditMode) ...[
              // View Mode
              buildDetail(icon: Icons.email, title: "Email", value: user.email),
              buildDetail(icon: Icons.phone, title: "Phone", value: _userData?["phone"]),
              buildDetail(icon: Icons.wc, title: "Gender", value: _userData?["gender"]),
              buildDetail(
                icon: Icons.calendar_today,
                title: "Date of Birth",
                value: _formatDate(_selectedDOB),
              ),

              buildAvailabilityGrid(false),
              buildInterestsSection(false),
              buildSkillsSection(false),

              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _isEditMode = true),
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit Profile"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ] else ...[
              // Edit Mode
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Name",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: "Phone",
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedGender,
                items: const [
                  DropdownMenuItem(value: "Male", child: Text("Male")),
                  DropdownMenuItem(value: "Female", child: Text("Female")),
                  DropdownMenuItem(value: "Other", child: Text("Other")),
                ],
                onChanged: (value) => setState(() => _selectedGender = value),
                decoration: const InputDecoration(
                  labelText: "Gender",
                  prefixIcon: Icon(Icons.wc),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Date of Birth",
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_formatDate(_selectedDOB)),
                ),
              ),

              buildAvailabilityGrid(true),
              buildInterestsSection(true),
              buildSkillsSection(true),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _saveUserProfile,
                    icon: const Icon(Icons.save),
                    label: const Text("Save Changes"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isEditMode = false),
                    child: const Text("Cancel"),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}