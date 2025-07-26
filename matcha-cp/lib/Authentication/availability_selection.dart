import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:matcha/service/notification_service.dart';
import 'package:matcha/Authentication/bigfive_selection.dart';
import '../constants/Constant.dart';

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
  Map<String, List<String>> availability = {};
  bool _isLoading = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    // Initialize availability map with all days and empty time slots
    availability = {for (var day in days) day: []};
  }

  Future<void> _saveAndContinue() async {
    // Check if at least one time slot is selected
    final hasSelection = availability.values.any((slots) => slots.isNotEmpty);
    if (!hasSelection) {
      setState(() => _showError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one available time slot."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _showError = false;
    });

    try {
      final userData = Map<String, dynamic>.from(widget.userData);
      userData['availability'] = availability;

      // Save data to Firestore
      await NotificationService().storeTokenAfterLogin(userData['uid']);
      await _firestore.collection("users")
          .doc(userData['uid'])
          .set(userData, SetOptions(merge:true));

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BigFiveSelectionScreen(userData: userData),
        ),
      );
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
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Availability Timings",
                  style: TextStyle(
                    color: Color(0xFFFFEC3D),
                    fontWeight: FontWeight.bold,
                    fontSize: 30,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const Text(
                      "When are you available to connect with peers?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_showError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          "Please select at least one time slot",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Table(
                      border: TableBorder.symmetric(
                        inside: BorderSide(color: Colors.grey.shade300),
                      ),
                      defaultColumnWidth: const FixedColumnWidth(80),
                      children: [
                        // Header row with time slots
                        TableRow(
                          decoration: BoxDecoration(
                            color: Color(0xFFFFEC3D),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          children: [
                            const SizedBox(), // Empty cell for day column
                            ...timeSlots.map((slot) => Container(
                              padding: const EdgeInsets.all(8),
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
                        // Rows for each day
                        ...days.map((day) => TableRow(
                          children: [
                            // Day cell
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
                            // Time slot checkboxes
                            ...timeSlots.map((slot) {
                              final isSelected = availability[day]?.contains(slot) ?? false;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    final slots = availability[day] ?? [];
                                    if (isSelected) {
                                      slots.remove(slot);
                                    } else {
                                      slots.add(slot);
                                    }
                                    availability[day] = slots;
                                    if (slots.isNotEmpty) {
                                      _showError = false;
                                    }
                                  });
                                },
                                child: Container(
                                  color: isSelected
                                      ? Color(0xFFFFEC3D).withOpacity(0.3)
                                      : Colors.transparent,
                                  child: Checkbox(
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
                                        if (slots.isNotEmpty) {
                                          _showError = false;
                                        }
                                      });
                                    },
                                    fillColor: WidgetStateProperty.resolveWith<Color>(
                                          (states) {
                                        if (states.contains(WidgetState.selected)) {
                                          return Color(0xFFFFEC3D);
                                        }
                                        return Colors.grey.shade300;
                                      },
                                    ),
                                    checkColor: Colors.black,
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        )),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 80),
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
                      "Please select at least one time slot to continue",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                    backgroundColor: Color(0xFFFFEC3D),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
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
                    "CONTINUE 4/5",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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