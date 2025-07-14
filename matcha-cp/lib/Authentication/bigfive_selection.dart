import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:matcha/service/notification_service.dart';
import 'package:matcha/screen/main_navigation.dart';

class BigFiveSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const BigFiveSelectionScreen({super.key, required this.userData});

  @override
  State<BigFiveSelectionScreen> createState() => _BigFiveSelectionScreenState();
}

class _BigFiveSelectionScreenState extends State<BigFiveSelectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, double> _big5 = {'O': 0.5, 'C': 0.5, 'E': 0.5, 'A': 0.5, 'N': 0.5};
  bool _isLoading = false;

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);
    try {
      final userData = Map<String, dynamic>.from(widget.userData);
      userData['big5'] = _big5;
      await NotificationService().storeTokenAfterLogin(userData['uid']);
      await _firestore.collection("users").doc(userData['uid']).set(userData, SetOptions(merge: true));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
            (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving data: $e"), backgroundColor: Colors.red),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Personality Assessment",
                style: TextStyle(color: Color(0xFFFFEC3D), fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Personality Quiz (Big Five OCEAN):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 16),
            Expanded(
              child: _BigFiveQuiz(
                initial: _big5,
                onChanged: (b5) => setState(() => _big5 = b5),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEC3D),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text("Finish Setup",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigFiveQuiz extends StatefulWidget {
  final Map<String, double> initial;
  final void Function(Map<String, double>) onChanged;
  const _BigFiveQuiz({required this.initial, required this.onChanged});

  @override
  State<_BigFiveQuiz> createState() => _BigFiveQuizState();
}

class _BigFiveQuizState extends State<_BigFiveQuiz> {
  late Map<String, int> _ratings;
  final List<Map<String, String>> _questions = [
    {'key': 'O', 'text': 'I am Full of Ideas', 'left': 'Disagree', 'right': 'Agree'},
    {'key': 'C', 'text': 'I follow a schedule', 'left': 'Disagree', 'right': 'Agree'},
    {'key': 'E', 'text': 'I love socializing with others', 'left': 'Worst', 'right': 'Best'},
    {'key': 'A', 'text': "I sympathize with other's feelings", 'left': 'Worst', 'right': 'Best'},
    {'key': 'N', 'text': 'I get stressed out easily', 'left': 'Worst', 'right': 'Best'},
  ];

  @override
  void initState() {
    super.initState();
    _ratings = Map<String, int>.fromIterable(widget.initial.keys,
        key: (k) => k, value: (k) => ((widget.initial[k] ?? 0.5) * 4).round() + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _questions.map((q) {
        final key = q['key']!;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(q['text']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(q['left']!, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    ...List.generate(5, (i) {
                      final isSelected = _ratings[key] == i + 1;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFFFFEC3D),
                          onSelected: (selected) {
                            setState(() {
                              _ratings[key] = i + 1;
                              widget.onChanged(
                                _ratings.map((k, v) => MapEntry(k, (v - 1) / 4)),
                              );
                            });
                          },
                          avatar: isSelected
                              ? const Icon(Icons.check, color: Colors.black, size: 16)
                              : null,
                        ),
                      );
                    }),
                    const SizedBox(width: 12),
                    Text(q['right']!, style: const TextStyle(fontSize: 12, color: Colors.white)),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}