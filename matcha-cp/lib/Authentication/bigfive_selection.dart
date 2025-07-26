import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matcha/service/notification_service.dart';
import 'package:matcha/Authentication/username_selection.dart';

class BigFiveSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const BigFiveSelectionScreen({super.key, required this.userData});

  @override
  State<BigFiveSelectionScreen> createState() => _BigFiveSelectionScreenState();
}

class _BigFiveSelectionScreenState extends State<BigFiveSelectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, double> _big5 = {
    'O': 0.5,
    'C': 0.5,
    'E': 0.5,
    'A': 0.5,
    'N': 0.5
  };
  bool _isLoading = false;
  bool _allQuestionsAnswered = false;

  Future<void> _saveAndContinue() async {
    if (!_allQuestionsAnswered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please answer all questions before continuing"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userData = Map<String, dynamic>.from(widget.userData);
      userData['big5'] = _big5;

      await NotificationService().storeTokenAfterLogin(userData['uid']);

      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (context)=>UsernameSelectionScreen(userData: userData)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving data: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onPersonalityUpdated(Map<String, double> newValues) {
    setState(() {
      _big5 = newValues;
      _allQuestionsAnswered = _big5.values.any((value) => value != 0.5);
    });
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Personality Assessment",
                style: TextStyle(
                  color: const Color(0xFFFFEC3D),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Complete this short personality assessment:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              _BigFiveQuiz(
                initial: _big5,
                onChanged: _onPersonalityUpdated,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEC3D),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    "FINISH SETUP",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (!_allQuestionsAnswered)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "Please answer all questions",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
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
    {
      'key': 'O',
      'text': 'I am full of ideas and creative',
      'left': 'Strongly disagree',
      'right': 'Strongly agree'
    },
    {
      'key': 'C',
      'text': 'I am organized and follow schedules',
      'left': 'Strongly disagree',
      'right': 'Strongly agree'
    },
    {
      'key': 'E',
      'text': 'I am outgoing and social',
      'left': 'Strongly disagree',
      'right': 'Strongly agree'
    },
    {
      'key': 'A',
      'text': "I am compassionate and cooperative",
      'left': 'Strongly disagree',
      'right': 'Strongly agree'
    },
    {
      'key': 'N',
      'text': 'I get stressed or nervous easily',
      'left': 'Strongly disagree',
      'right': 'Strongly agree'
    },
  ];

  @override
  void initState() {
    super.initState();
    _ratings = Map<String, int>.fromIterable(
      widget.initial.keys,
      key: (k) => k,
      value: (k) => ((widget.initial[k] ?? 0.5) * 4).round() + 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _questions.map((q) {
        final key = q['key']!;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.grey[900],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q['text']!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      q['left']!,
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      q['right']!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _ratings[key]!.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: _ratings[key].toString(),
                  activeColor: const Color(0xFFFFEC3D),
                  inactiveColor: Colors.grey[700],
                  onChanged: (value) {
                    setState(() {
                      _ratings[key] = value.toInt();
                      widget.onChanged(
                          _ratings.map((k, v) => MapEntry(k, (v - 1) / 4),)
                          );

                      });
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (i) {
                    final isSelected = _ratings[key] == i + 1;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _ratings[key] = i + 1;
                          widget.onChanged(
                              _ratings.map((k, v) => MapEntry(k, (v - 1) / 4),)
                              );
                          });
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFEC3D)
                              : Colors.grey[800],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}