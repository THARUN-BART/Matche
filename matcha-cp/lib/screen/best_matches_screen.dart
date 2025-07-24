import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:matcha/constants/Constant.dart';
import '../service/matching_service.dart';
import '../service/firestore_service.dart';
import '../widget/skeleton_loading.dart';

class BestMatchesScreen extends StatefulWidget {
  const BestMatchesScreen({Key? key}) : super(key: key);

  @override
  State<BestMatchesScreen> createState() => _BestMatchesScreenState();
}

class _BestMatchesScreenState extends State<BestMatchesScreen> {
  Map<String, List<String>> selectedAvailabilityMap = {};
  List<String> selectedSkills = [];
  List<String> selectedInterests = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final matchingService = Provider.of<MatchingService>(context, listen: false);
    final userId = firestoreService.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Best Peer Matches', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios)
        ),
        actions: [
          IconButton(
            onPressed: _showCustomFilterDialog,
            icon: const Icon(Icons.filter_list_sharp),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SvgPicture.asset('Assets/Group.svg', height: 40),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Best Peer Matches', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Based on your profile and preferences',
                          style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filter chips
              if (selectedAvailabilityMap.isNotEmpty ||
                  selectedSkills.isNotEmpty ||
                  selectedInterests.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...selectedAvailabilityMap.entries.expand((entry) {
                        final day = entry.key;
                        return entry.value.map((slot) => Chip(
                          label: Text('$day - $slot'),
                          onDeleted: () {
                            setState(() {
                              selectedAvailabilityMap[day]?.remove(slot);
                              if (selectedAvailabilityMap[day]!.isEmpty) {
                                selectedAvailabilityMap.remove(day);
                              }
                            });
                          },
                        ));
                      }).toList(),
                      ...selectedSkills.map((skill) => Chip(
                        label: Text('Skill: $skill'),
                        onDeleted: () => setState(() => selectedSkills.remove(skill)),
                      )),
                      ...selectedInterests.map((interest) => Chip(
                        label: Text('Interest: $interest'),
                        onDeleted: () => setState(() => selectedInterests.remove(interest)),
                      )),
                      if (selectedAvailabilityMap.isNotEmpty ||
                          selectedSkills.isNotEmpty ||
                          selectedInterests.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() {
                            selectedAvailabilityMap.clear();
                            selectedSkills.clear();
                            selectedInterests.clear();
                          }),
                          child: const Text('Clear all', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              Expanded(
                child: StreamBuilder(
                  stream: firestoreService.getUserConnections(),
                  builder: (context, connectionsSnapshot) {
                    final connectedUserIds = <String>{};
                    if (connectionsSnapshot.hasData) {
                      for (var doc in connectionsSnapshot.data?.docs ?? []) {
                        connectedUserIds.add(doc.id);
                      }
                    }
                    return StreamBuilder(
                      stream: firestoreService.getSentConnectionRequests(),
                      builder: (context, sentSnapshot) {
                        final sentRequestUserIds = <String>{};
                        if (sentSnapshot.hasData) {
                          for (var doc in sentSnapshot.data?.docs ?? []) {
                            sentRequestUserIds.add(doc.id);
                          }
                        }
                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: userId != null
                              ? matchingService.getClusterMatches(
                            userId,
                            top: 20,
                          )
                              : Future.value([]),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error loading peers: ${snapshot.error}'),
                              );
                            }
                            if (snapshot.connectionState == ConnectionState.waiting && !_isLoading) {
                              return const SkeletonMatchListVertical(itemCount: 5);
                            }
                            final matches = snapshot.data ?? [];

                            for (var m in matches) {
                              print("=== MATCH ===");
                              print("UID: ${m['uid']}");
                              print("Skills: ${m['skills']}");
                              print("Interests: ${m['interests']}");
                              print("Availability: ${m['availability']}");
                            }


                            final notConnected = matches.where((match) {
                              final uid = match['uid'] as String?;
                              if (uid == null || connectedUserIds.contains(uid)) return false;


                              final userSkills = ((match['skills'] ?? []) as List)
                                  .map((s) => s.toString().toLowerCase())
                                  .toList();

                              final userInterests = ((match['interests'] ?? []) as List)
                                  .map((i) => i.toString().toLowerCase())
                                  .toList();

                              final userAvailability = (match['availability'] as Map?)?.map((key, value) {
                                return MapEntry(key.toString(), List<String>.from(value));
                              }) ?? {};


                              if (selectedSkills.isNotEmpty) {
                                final selectedLower = selectedSkills.map((e) => e.toLowerCase());
                                if (!selectedLower.any((skill) => userSkills.contains(skill))) {
                                  print("Filtered out $uid due to skills mismatch");
                                  return false;
                                }
                              }


                              if (selectedInterests.isNotEmpty) {
                                final selectedLower = selectedInterests.map((e) => e.toLowerCase());
                                if (!selectedLower.any((interest) => userInterests.contains(interest))) {
                                  print("Filtered out $uid due to interests mismatch");
                                  return false;
                                }
                              }


                              if (selectedAvailabilityMap.isNotEmpty) {
                                bool hasMatch = false;
                                for (final entry in selectedAvailabilityMap.entries) {
                                  final day = entry.key;
                                  final selectedSlots = entry.value;
                                  final userSlots = userAvailability[day] ?? [];

                                  if (selectedSlots.any((slot) => userSlots.contains(slot))) {
                                    hasMatch = true;
                                    break;
                                  }
                                }
                                if (!hasMatch) {
                                  print("Filtered out $uid due to availability mismatch");
                                  return false;
                                }
                              }

                              return true;
                            }).toList();


                            if (notConnected.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('No matches found'),
                                    if (selectedAvailabilityMap.isNotEmpty ||
                                        selectedSkills.isNotEmpty ||
                                        selectedInterests.isNotEmpty)
                                      TextButton(
                                        onPressed: () => setState(() {
                                          selectedAvailabilityMap.clear();
                                          selectedSkills.clear();
                                          selectedInterests.clear();
                                        }),
                                        child: const Text('Clear filters'),
                                      ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              itemCount: notConnected.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final match = notConnected[index];
                                return FutureBuilder<Map<String, dynamic>>(
                                  future: matchingService.getUserDetails(match['uid']),
                                  builder: (context, userSnapshot) {
                                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                                      return const Card(child: ListTile(title: Text('Loading...')));
                                    }
                                    if (userSnapshot.hasError || userSnapshot.data == null) {
                                      return const Card(child: ListTile(title: Text('Error loading user')));
                                    }
                                    final user = userSnapshot.data!;
                                    return Card(
                                      elevation: 3,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        side: const BorderSide(color: Color(0xFFFFEC3D), width: 2),
                                      ),
                                      child: ListTile(
                                        leading: GestureDetector(
                                          onTap: () => _showUserDetailsDialog(context, user),
                                          child: CircleAvatar(
                                            backgroundColor: Color(0xFFFFEC3D),
                                            child: Text(
                                              user['name']?.substring(0, 1).toUpperCase() ?? 'U',
                                              style: const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20
                                              ),
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                            user['name'] ?? 'Unknown',
                                            style: const TextStyle(fontWeight: FontWeight.bold)
                                        ),
                                        subtitle: Text('Similarity: ${match['similarity']}%'),
                                        trailing: _buildConnectionButton(
                                          context,
                                          user['uid'] ?? '',
                                          user['name'] ?? '',
                                          connectedUserIds,
                                          sentRequestUserIds,
                                          firestoreService,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserDetailsDialog(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFFFEC3D),
                    radius: 25,
                    child: Text(
                      user['name']?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Gender: ${user['gender'] ?? 'Not specified'}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Skills Section
              const Text(
                'Skills:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (user['skills'] is List && (user['skills'] as List).isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (user['skills'] as List)
                      .map<Widget>((skill) => Chip(
                      label: Text(skill.toString(), style: TextStyle(color: Colors.black)),
                      backgroundColor: Color(0xFFFFEC3D)
                  ))
                      .toList(),
                )
              else
                const Text('No skills listed'),

              const SizedBox(height: 20),

              const Text(
                'Availability Schedule:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: _buildAvailabilityTable(user['availability']),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityTable(dynamic availabilityData) {
    if (availabilityData == null) {
      return const Center(
        child: Text(
          'No availability information',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    Map<String, List<String>> availability = {};
    if (availabilityData is Map) {
      availabilityData.forEach((key, value) {
        if (value is List) {
          availability[key.toString()] = value.map((e) => e.toString()).toList();
        }
      });
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          defaultColumnWidth: const FixedColumnWidth(70),
          children: [
            // Header row
            TableRow(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Color(0xFFFFEC3D),
                  child: const Text(
                    'Day',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 12,
                    ),
                  ),
                ),
                ...timeSlots.map(
                      (slot) => Container(
                    padding: const EdgeInsets.all(8),
                    color: Color(0xFFFFEC3D),
                    child: Text(
                      slot,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Data rows
            ...days.map((day) => TableRow(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Color(0xFFFFEC3D),
                  child: Text(
                    day.substring(0, 3),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 11,
                    ),
                  ),
                ),
                ...timeSlots.map((slot) {
                  final isAvailable = availability[day]?.contains(slot) ?? false;
                  return Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      isAvailable ? Icons.check_circle : Icons.cancel,
                      color: isAvailable
                          ? Colors.green
                          : Colors.red.withOpacity(0.3),
                      size: 16,
                    ),
                  );
                }).toList(),
              ],
            )),
          ],
        ),
      ),
    );
  }

  void _showCustomFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.yellow, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Filter Match Based on', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                _buildFilterOptionButton('Skills', _selectSkills),
                const SizedBox(height: 16),
                _buildFilterOptionButton('Interests', _selectInterests),
                const SizedBox(height: 16),
                _buildFilterOptionButton('Availability', _selectAvailability),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterOptionButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: () {
        Navigator.pop(context);
        onTap();
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        side: const BorderSide(color: Colors.yellow, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Text(label, style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  void _selectSkills() {
    final tempSkills = List<String>.from(selectedSkills);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Column(
                  children: [
                    const Text(
                      'Select Skills',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),

                    Expanded(
                      child: ListView(
                        children: allSkills.map((skill) {
                          return CheckboxListTile(
                            checkColor: const Color(0xFFFFEC3D),
                            value: tempSkills.contains(skill),
                            title: Text(skill),
                            onChanged: (value) {
                              setModalState(() {
                                value!
                                    ? tempSkills.add(skill)
                                    : tempSkills.remove(skill);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child:ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFEC3D),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 4,
                              ),
                              onPressed: () {
                                setState(() => selectedSkills = List.from(tempSkills));
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Apply',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            )
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _selectInterests() {
    final tempInterests = List<String>.from(selectedInterests);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Column(
                  children: [
                    const Text(
                      'Select Interests',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView(
                        children: allInterestOptions.map((interest) {
                          return CheckboxListTile(
                            value: tempInterests.contains(interest),
                            title: Text(interest),
                            onChanged: (value) {
                              setModalState(() {
                                value!
                                    ? tempInterests.add(interest)
                                    : tempInterests.remove(interest);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child:ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFEC3D),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 4,
                              ),
                              onPressed: () {
                                setState(() => selectedInterests = List.from(tempInterests));
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Apply',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            )
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _selectAvailability() {
    Map<String, List<String>> tempAvailability = {};

    for (String day in days) {
      tempAvailability[day] = List<String>.from(
        (selectedAvailabilityMap[day] ?? []),
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      const Text('Select Availability', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Table(
                          border: TableBorder.all(color: Colors.grey.shade300),
                          defaultColumnWidth: const FixedColumnWidth(70),
                          children: [
                      // Header Row
                      TableRow(
                      children: [
                      const SizedBox.shrink(), // Empty cell for day label
                      ...timeSlots.map(
                      (slot) => Center(child: Text(slot, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                      )],
              ),
              // Days Rows
              ...days.map(
              (day) => TableRow(
              children: [
              Padding(
              padding: const EdgeInsets.all(6.0),
              child: Text(day.substring(0, 3), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              ...timeSlots.map((slot) {
              final isSelected = tempAvailability[day]?.contains(slot) ?? false;
              return GestureDetector(
              onTap: () {
              setModalState(() {
              if (isSelected) {
              tempAvailability[day]?.remove(slot);
              } else {
              tempAvailability[day]?.add(slot);
              }
              });
              },
              child: Container(
              height: 32,
              color: isSelected ? Colors.yellow.shade700 : Colors.grey.shade200,
              child: Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: isSelected ? Colors.green : Colors.grey,
                ),
              ),
              );
              }).toList(),
              ],
              ),
              ),
              ],
              ),
              ),
              const SizedBox(height: 16),
              Row(
              children: [
              Expanded(
              child: OutlinedButton(
              onPressed: () {
              Navigator.pop(context);
              },
              child: const Text('Cancel'),
              ),
              ),
              const SizedBox(width: 12),
              Expanded(
              child: ElevatedButton(
              style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFEC3D),
              foregroundColor: Colors.black,
              ),
              onPressed: () {
              setState(() {
              selectedAvailabilityMap = tempAvailability;
              });
              Navigator.pop(context);
              },
              child: const Text('Apply'),
              ),
              ),
              ],
              )
              ],
              ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildConnectionButton(
      BuildContext context,
      String userId,
      String userName,
      Set<String> connectedUserIds,
      Set<String> sentRequestUserIds,
      FirestoreService firestoreService,
      ) {
    if (connectedUserIds.contains(userId)) {
      return const Text('Connected');
    }
    if (sentRequestUserIds.contains(userId)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.orange, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.hourglass_bottom, color: Colors.orange, size: 16),
            SizedBox(width: 6),
            Text(
              'Pending',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    return ElevatedButton(
      onPressed: () async {
        try {
          await firestoreService.sendConnectionRequest(firestoreService.currentUserId, userId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connection request sent to $userName!'), backgroundColor: Colors.green),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sending request: $e'), backgroundColor: Colors.red),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFEC3D),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: const Text('Connect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

