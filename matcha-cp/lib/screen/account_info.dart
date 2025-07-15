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
  List<String> interests = [];
  List<String> filteredInterestOptions = [];


  List<String> _userSkills = [];
  List<String> _filteredSkills = [];

  // Add temp variables for edit mode
  List<String> _tempInterests = [];
  List<String> _tempSkills = [];
  Map<String, List<String>> _tempAvailability = {};

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

          if (_userData?['dob'] != null) {
            if (_userData!['dob'] is Timestamp) {
              _selectedDOB = (_userData!['dob'] as Timestamp).toDate();
            } else if (_userData!['dob'] is String) {
              _selectedDOB = DateTime.tryParse(_userData!['dob']);
            }
          }

          if (_userData?['availability'] != null) {
            final raw = _userData!['availability'] as Map<String, dynamic>;
            availability = raw.map((day, slots) => MapEntry(day, List<String>.from(slots)));
          } else {
            availability = {for (var day in days) day: []};
          }

          if (_userData?['interests'] != null) {
            interests = List<String>.from(_userData!['interests']);
          }

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

      Navigator.pop(context);

      await _fetchUserData();

      _showSnackBar("Profile updated successfully!", Colors.green);
      setState(() => _isEditMode = false);
    } catch (e) {
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

  void _enterEditMode() {
    setState(() {
      _isEditMode = true;
      _tempInterests = List<String>.from(interests);
      _tempSkills = List<String>.from(_userSkills);
      _tempAvailability = {for (var e in availability.entries) e.key: List<String>.from(e.value)};
    });
  }

  void _cancelEditMode() {
    setState(() {
      _isEditMode = false;
      interests = List<String>.from(_tempInterests);
      _userSkills = List<String>.from(_tempSkills);
      availability = {for (var e in _tempAvailability.entries) e.key: List<String>.from(e.value)};
    });
  }

  Widget buildDetail({required IconData icon, required String title, required String? value}) {
    return ListTile(
      leading: Icon(icon, color:Color(0xFFFFEC3D)),
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
            leading: const Icon(Icons.schedule, color: Color(0xFFFFEC3D)),
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
        const Text(
          "Available to connect with peers",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
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
                    color: Color(0xFFFFEC3D),
                    child: Text(
                      slot,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  )),
                ],
              ),
              ...days.map((day) => TableRow(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Color(0xFFFFEC3D),
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  ...timeSlots.map((slot) {
                    final isSelected = availability[day]?.contains(slot) ?? false;
                    return Container(
                      padding: const EdgeInsets.all(4),
                      child: Checkbox(
                        value: isSelected,
                        checkColor: Colors.black,
                        activeColor: Color(0xFFFFEC3D),
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
                      ),
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
    final editList = editable ? _tempInterests : interests;
    if (!editable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.favorite, color: Color(0xFFFFEC3D)),
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
                  backgroundColor: Color(0xFFFFEC3D),
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
              onPressed: () => _showIntrestDialog(editable: true),
              icon: const Icon(Icons.add,color: Color(0xFFFFEC3D),),
              label: const Text("Add Interests",style: TextStyle(color: Color(0xFFFFEC3D)),),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: editList.map((interest) => Chip(
            label: Text(interest),
            backgroundColor: Color(0xFFFFEC3D),
            labelStyle: TextStyle(color: Colors.black),
            deleteIcon: const Icon(Icons.close,color: Colors.black,),
            onDeleted: () => setState(() => editList.remove(interest)),
          )).toList(),
        ),
      ],
    );
  }

  Widget buildSkillsSection(bool editable) {
    final editList = editable ? _tempSkills : _userSkills;
    if (!editable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.star, color: Color(0xFFFFEC3D)),
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
                  backgroundColor: Color(0xFFFFEC3D),
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
              onPressed: () => _showSkillsDialog(editable: true),
              icon: const Icon(Icons.add,color: Color(0xFFFFEC3D),),
              label: const Text("Manage Skills",style: TextStyle(color: Color(0xFFFFEC3D)),),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: editList.map((skill) => Chip(
            label: Text(skill),
            backgroundColor: Color(0xFFFFEC3D),
            labelStyle: TextStyle(color: Colors.black),
            deleteIcon: const Icon(Icons.close,color: Colors.black,),
            onDeleted: () => setState(() => editList.remove(skill)),
          )).toList(),
        ),
      ],
    );
  }

  void _showSkillsDialog({bool editable = false}) {
    List<String> tempSkills = editable ? List.from(_tempSkills) : List.from(_userSkills);

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
                    fillColor: Colors.transparent,
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
                          label: Text(skill, style: const TextStyle(color: Colors.black, fontSize: 12)),
                          backgroundColor: Color(0xFFFFEC3D),
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
                          selectedTileColor: Colors.transparent,
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
              child: const Text("Cancel",style: TextStyle(color: Colors.white),),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (editable) {
                    _tempSkills = tempSkills;
                  } else {
                    _userSkills = tempSkills;
                  }
                });
                _skillSearchController.clear();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFFEC3D)
              ),
              child: const Text("Save",style: TextStyle(color: Colors.black),),
            ),
          ],
        ),
      ),
    );
  }

  void _showIntrestDialog({bool editable = false}) {
    List<String> tempInterests = editable ? List.from(_tempInterests) : List.from(interests);

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
                    fillColor: Colors.transparent,
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
                          label: Text(interest, style: const TextStyle(color: Colors.black, fontSize: 12)),
                          backgroundColor: Color(0xFFFFEC3D),
                          deleteIcon: const Icon(Icons.close, color: Colors.black, size: 16),
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
                          selectedTileColor: Colors.transparent,
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
              child: const Text("Cancel",style: TextStyle(color: Colors.white),),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (editable) {
                    _tempInterests = tempInterests;
                  } else {
                    interests = tempInterests;
                  }
                });
                _interestController.clear();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFFEC3D)
              ),


              child: const Text("Save",style: TextStyle(color: Colors.black),),
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_outlined,size: 30.0),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
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
                    backgroundColor: Color(0xFFFFEC3D),
                    child: Text(
                      _userData?['name'] != null && (_userData?['name'] as String).isNotEmpty
                          ? (_userData!['name'] as String)[0].toUpperCase()
                          : "?",
                      style: const TextStyle(color: Colors.black, fontSize: 32),
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
              buildDetail(icon: Icons.verified_user, title: "UserName", value: _userData?["username"]),
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
                  onPressed: _enterEditMode,
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
                    onPressed: () {
                      setState(() {
                        interests = List<String>.from(_tempInterests);
                        _userSkills = List<String>.from(_tempSkills);
                        availability = {for (var e in _tempAvailability.entries) e.key: List<String>.from(e.value)};
                      });
                      _saveUserProfile();
                    },
                    icon: const Icon(Icons.save),
                    label: const Text("Save Changes"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFFEC3D),
                      foregroundColor: Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelEditMode,
                    child: const Text("Cancel",style: TextStyle(color:Colors.white),),
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