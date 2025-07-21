import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:matcha/service/notification_service.dart';
import 'package:matcha/screen/main_navigation.dart';
import '../constants/Constant.dart';
import 'availability_selection.dart';

class InterestsSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const InterestsSelectionScreen({super.key, required this.userData});

  @override
  State<InterestsSelectionScreen> createState() => _InterestsSelectionScreenState();
}

class _InterestsSelectionScreenState extends State<InterestsSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> selectedInterests = [];
  List<String> filteredInterests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    filteredInterests = allInterestOptions;
    _searchController.addListener(_filterInterests);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterInterests() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredInterests = allInterestOptions
          .where((interest) => interest.toLowerCase().contains(query))
          .toList();
    });
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (selectedInterests.contains(interest)) {
        selectedInterests.remove(interest);
      } else {
        selectedInterests.add(interest);
      }
    });
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);
    if (selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select at least one interest."), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
      return;
    }
    try {
      final userData = Map<String, dynamic>.from(widget.userData);
      userData['interests'] = selectedInterests;
      await NotificationService().storeTokenAfterLogin(userData['uid']);
      await _firestore.collection("users").doc(userData['uid']).set(userData, SetOptions(merge: true));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AvailabilitySelectionScreen(userData: userData)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving data: "+e.toString()), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _skipToHome() async {
    setState(() => _isLoading = true);
    try {
      final userData = Map<String, dynamic>.from(widget.userData);
      userData['interests'] = <String>[];
      await NotificationService().storeTokenAfterLogin(userData['uid']);
      await _firestore.collection("users").doc(userData['uid']).set(userData, SetOptions(merge: true));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving data: "+e.toString()), backgroundColor: Colors.red),
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
                      "INTEREST",
                      style: TextStyle(
                          color: Color(0xFFFFEC3D),
                          fontSize: 30,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "What are your interests?",
                      style:
                      GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Add interests to help others find you",
                      style:
                      GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search interests...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.transparent
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (selectedInterests.isNotEmpty) ...[
                      Text(
                        "Selected Interests (${selectedInterests.length})",
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: selectedInterests
                            .map(
                              (interest) => Chip(
                            label: Text(interest,
                                style: const TextStyle(color: Colors.black)),
                            backgroundColor: Color(0xFFFFEC3D),
                            deleteIcon: const Icon(Icons.close,
                                color: Colors.black, size: 16),
                            onDeleted: () => _toggleInterest(interest),
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
                  itemCount: filteredInterests.length,
                  itemBuilder: (context, index) {
                    final interest = filteredInterests[index];
                    final isSelected = selectedInterests.contains(interest);
                    return Card(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Color(0xFFFFEC3D), width: 2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(interest),
                        trailing: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          color: isSelected ? Colors.green : Colors.grey,
                        ),
                        onTap: () => _toggleInterest(interest),
                        selected: isSelected,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveAndContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFFEC3D),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : Text(
                "Continue 3/5",
              ),
            ),
          ),
        ],
      ),
    );
  }
} 