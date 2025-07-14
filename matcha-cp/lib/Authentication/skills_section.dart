import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/Constant.dart';
import '../screen/main_navigation.dart';
import '../service/notification_service.dart';
import 'interests_selection.dart';

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

      // Get and store FCM token
      await NotificationService().storeTokenAfterLogin(userData['uid']);

      // Save to Firestore
      await _firestore.collection("users").doc(userData['uid']).set(userData);

      // Navigate to home page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InterestsSelectionScreen(userData: userData),
        ),
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
      final userData = Map<String, dynamic>.from(widget.userData);
      userData['skills'] = <String>[];

      // Get and store FCM token
      await NotificationService().storeTokenAfterLogin(userData['uid']);

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
        title: Image.asset('Assets/Star.png', height: 100),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "SKILLS",
                      style: TextStyle(
                          color: Color(0xFFFFEC3D),
                          fontSize: 30,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "What skills do you have?",
                      style: GoogleFonts.inter(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Add skills to help others find you",
                      style: GoogleFonts.inter(
                          fontSize: 14, color: Colors.grey[600]),
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
                        fillColor: Colors.transparent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (selectedSkills.isNotEmpty) ...[
                      Text(
                        "Selected Skills (${selectedSkills.length})",
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: selectedSkills
                            .map(
                              (skill) => Chip(
                            label: Text(skill,
                                style: const TextStyle(color: Colors.black)),
                            backgroundColor: Color(0xFFFFEC3D),
                            deleteIcon: const Icon(Icons.close,
                                color: Colors.black, size: 16),
                            onDeleted: () => _toggleSkill(skill),
                          ),
                        )
                            .toList(),
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
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Color(0xFFFFEC3D), width: 2),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        title: Text(skill),
                        trailing: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          color: isSelected ? Colors.green : Colors.grey,
                        ),
                        onTap: () => _toggleSkill(skill),
                        selected: isSelected,

                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 80), // Spacer for button
            ],
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: () {
                final userData = Map<String, dynamic>.from(widget.userData);
                userData['skills'] = selectedSkills;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => InterestsSelectionScreen(userData: userData)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFFEC3D),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("CONTINUE 2/5"),
            ),
          ),
        ],
      ),
    );
  }
}


