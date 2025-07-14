import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:matcha/service/notification_service.dart';
import 'package:matcha/screen/main_navigation.dart';
import 'package:matcha/Authentication/bigfive_selection.dart';

class AvailabilitySelectionScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AvailabilitySelectionScreen({super.key, required this.userData});

  @override
  State<AvailabilitySelectionScreen> createState() =>
      _AvailabilitySelectionScreenState();
}

class _AvailabilitySelectionScreenState
    extends State<AvailabilitySelectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> timeSlots = [
    "6-8am",
    "8-10am",
    "4-6pm",
    "6-8pm",
    "8-10pm"
  ];
  final List<String> days = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday"
  ];
  Map<String, List<String>> availability = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    availability = {for (var day in days) day: []};
  }

  Future<void> _storeFCMToken(String userId) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        await NotificationService().storeTokenAfterLogin(userId);
      }
    } catch (e) {
      debugPrint("FCM token error: $e");
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isLoading = true);
    try {
      final userData = Map<String, dynamic>.from(widget.userData);
      userData['availability'] = availability;
      await _storeFCMToken(userData['uid']);
      await _firestore
          .collection("users")
          .doc(userData['uid'])
          .set(userData, SetOptions(merge: true));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BigFiveSelectionScreen(userData: userData)),
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
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Availability Timings",
                  style: TextStyle(
                      color: Color(0xFFFFEC3D),
                      fontWeight: FontWeight.bold,
                      fontSize: 30),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "When are you available to connect with peers?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    defaultColumnWidth: const FixedColumnWidth(80),
                    children: [
                      TableRow(
                        children: [
                          const SizedBox(),
                          ...timeSlots.map(
                                (slot) => Container(
                              padding: const EdgeInsets.all(8),
                              color: Color(0xFFFFEC3D),
                              child: Text(
                                slot,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                              ),
                            ),
                          ),
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
                                  color: Colors.black),
                            ),
                          ),
                          ...timeSlots.map((slot) {
                            final isSelected =
                                availability[day]?.contains(slot) ?? false;
                            return Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  final slots = availability[day] ?? [];
                                  if (value == true) {
                                    if (!slots.contains(slot)) {
                                      slots.add(slot);
                                    }
                                  } else {
                                    slots.remove(slot);
                                  }
                                  availability[day] = slots;
                                });
                              },
                              fillColor:
                              MaterialStateProperty.resolveWith<Color>(
                                      (states) {
                                    if (states
                                        .contains(MaterialState.selected)) {
                                      return Color(0xFFFFEC3D);
                                    }
                                    return Colors.grey.shade300;
                                  }),
                              checkColor: Colors.black,
                            );
                          }).toList(),
                        ],
                      )),
                    ],
                  ),
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
              onPressed: _isLoading ? null : _saveAndContinue,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
                elevation: 0,
                backgroundColor: Color(0xFFFFEC3D),
                foregroundColor: Colors.black,
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text(
                "CONTINUE 4/5",
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}