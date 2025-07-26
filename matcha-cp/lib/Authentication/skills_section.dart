import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/Constant.dart';
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
  bool _showError = false;

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
      // Hide error when user selects at least one skill
      if (selectedSkills.isNotEmpty) {
        _showError = false;
      }
    });
  }

  Future<void> _continueToNextScreen() async {
    if (selectedSkills.isEmpty) {
      setState(() => _showError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one skill."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Add skills to user data
      final userData = Map<String, dynamic>.from(widget.userData);
      userData['skills'] = selectedSkills;

      // Get and store FCM token
      await NotificationService().storeTokenAfterLogin(userData['uid']);


      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InterestsSelectionScreen(userData: userData),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: IconButton(onPressed: (){
            Navigator.pop(context);
          }, icon: Icon(Icons.arrow_back_ios)),
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "What skills do you have?",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Add skills to help others find you",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: selectedSkills
                            .map(
                              (skill) => Chip(
                            label: Text(
                              skill,
                              style: const TextStyle(color: Colors.black),
                            ),
                            backgroundColor: Color(0xFFFFEC3D),
                            deleteIcon: const Icon(
                              Icons.close,
                              color: Colors.black,
                              size: 16,
                            ),
                            onDeleted: () => _toggleSkill(skill),
                          ),
                        )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_showError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          "Please select at least one skill",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
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
                          side: BorderSide(
                            color: isSelected ? Colors.green : Color(0xFFFFEC3D),
                            width: 2,
                          ),
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
            child: Column(
              children: [
                if (_showError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      "Please select at least one skill to continue",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _continueToNextScreen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFFEC3D),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("CONTINUE 2/5"),
                ),
                const SizedBox(height: 8),

              ],
            ),
          ),
        ],
      ),
    );
  }
}