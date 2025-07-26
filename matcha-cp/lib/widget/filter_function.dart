import 'package:flutter/material.dart';
import 'package:matcha/constants/Constant.dart';

class FilterCriteria {
  final List<String> skills;
  final List<String> interests;
  final Map<String, List<String>> availability;

  FilterCriteria({
    this.skills = const [],
    this.interests = const [],
    this.availability = const {},
  });

  FilterCriteria copyWith({
    List<String>? skills,
    List<String>? interests,
    Map<String, List<String>>? availability,
  }) {
    return FilterCriteria(
      skills: skills ?? this.skills,
      interests: interests ?? this.interests,
      availability: availability ?? this.availability,
    );
  }

  bool get isEmpty => skills.isEmpty && interests.isEmpty && availability.isEmpty;

  bool get isNotEmpty => !isEmpty;

  void clear() {
    skills.clear();
    interests.clear();
    availability.clear();
  }
}

class FilterManager {
  static FilterManager? _instance;
  FilterManager._internal();

  factory FilterManager() {
    _instance ??= FilterManager._internal();
    return _instance!;
  }

  FilterCriteria _currentFilter = FilterCriteria();

  FilterCriteria get currentFilter => _currentFilter;

  void updateFilter(FilterCriteria newFilter) {
    _currentFilter = newFilter;
  }

  void clearFilters() {
    _currentFilter = FilterCriteria();
  }

  // Show main filter dialog
  Future<void> showFilterDialog(BuildContext context, {
    required Function(FilterCriteria) onFilterApplied,
  }) async {
    return showDialog(
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
                const Text(
                  'Filter Match Based on',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildFilterOptionButton(
                  'Skills',
                      () => _showSkillsFilter(context, onFilterApplied),
                ),
                const SizedBox(height: 16),
                _buildFilterOptionButton(
                  'Interests',
                      () => _showInterestsFilter(context, onFilterApplied),
                ),
                const SizedBox(height: 16),
                _buildFilterOptionButton(
                  'Availability',
                      () => _showAvailabilityFilter(context, onFilterApplied),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterOptionButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        side: const BorderSide(color: Colors.yellow, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.yellow,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  // Skills filter
  void _showSkillsFilter(BuildContext context, Function(FilterCriteria) onFilterApplied) {
    Navigator.pop(context); // Close main dialog

    final tempSkills = List<String>.from(_currentFilter.skills);

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
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFEC3D),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 4,
                            ),
                            onPressed: () {
                              _currentFilter = _currentFilter.copyWith(skills: tempSkills);
                              onFilterApplied(_currentFilter);
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Apply',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
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

  // Interests filter
  void _showInterestsFilter(BuildContext context, Function(FilterCriteria) onFilterApplied) {
    Navigator.pop(context); // Close main dialog

    final tempInterests = List<String>.from(_currentFilter.interests);

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
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFEC3D),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 4,
                            ),
                            onPressed: () {
                              _currentFilter = _currentFilter.copyWith(interests: tempInterests);
                              onFilterApplied(_currentFilter);
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Apply',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
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

  // Availability filter
  void _showAvailabilityFilter(BuildContext context, Function(FilterCriteria) onFilterApplied) {
    Navigator.pop(context); // Close main dialog

    Map<String, List<String>> tempAvailability = {};
    for (String day in days) {
      tempAvailability[day] = List<String>.from(_currentFilter.availability[day] ?? []);
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
                    const Text(
                      'Select Availability',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
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
                              const SizedBox.shrink(),
                              ...timeSlots.map(
                                    (slot) => Center(
                                  child: Text(
                                    slot,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Days Rows
                          ...days.map(
                                (day) => TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(6.0),
                                  child: Text(
                                    day.substring(0, 3),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
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
                                      color: isSelected
                                          ? Colors.yellow.shade700
                                          : Colors.grey.shade200,
                                      child: Icon(
                                        isSelected
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
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
                            onPressed: () => Navigator.pop(context),
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
                              _currentFilter = _currentFilter.copyWith(availability: tempAvailability);
                              onFilterApplied(_currentFilter);
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

  // Apply filters to a list of matches
  List<Map<String, dynamic>> applyFilters(
      List<Map<String, dynamic>> matches,
      Set<String> connectedUserIds,
      ) {
    return matches.where((match) {
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

      // Skills filter
      if (_currentFilter.skills.isNotEmpty) {
        final selectedLower = _currentFilter.skills.map((e) => e.toLowerCase());
        if (!selectedLower.any((skill) => userSkills.contains(skill))) {
          return false;
        }
      }

      // Interests filter
      if (_currentFilter.interests.isNotEmpty) {
        final selectedLower = _currentFilter.interests.map((e) => e.toLowerCase());
        if (!selectedLower.any((interest) => userInterests.contains(interest))) {
          return false;
        }
      }

      // Availability filter
      if (_currentFilter.availability.isNotEmpty) {
        bool hasMatch = false;
        for (final entry in _currentFilter.availability.entries) {
          final day = entry.key;
          final selectedSlots = entry.value;
          final userSlots = userAvailability[day] ?? [];

          if (selectedSlots.any((slot) => userSlots.contains(slot))) {
            hasMatch = true;
            break;
          }
        }
        if (!hasMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // Generate filter chips
  List<Widget> buildFilterChips({
    required Function(String, String?) onDeleteAvailability,
    required Function(String) onDeleteSkill,
    required Function(String) onDeleteInterest,
    required VoidCallback onClearAll,
  }) {
    List<Widget> chips = [];

    // Availability chips
    for (final entry in _currentFilter.availability.entries) {
      final day = entry.key;
      for (final slot in entry.value) {
        chips.add(
          Chip(
            label: Text('$day - $slot'),
            onDeleted: () => onDeleteAvailability(day, slot),
          ),
        );
      }
    }

    // Skills chips
    for (final skill in _currentFilter.skills) {
      chips.add(
        Chip(
          label: Text('Skill: $skill'),
          onDeleted: () => onDeleteSkill(skill),
        ),
      );
    }

    // Interests chips
    for (final interest in _currentFilter.interests) {
      chips.add(
        Chip(
          label: Text('Interest: $interest'),
          onDeleted: () => onDeleteInterest(interest),
        ),
      );
    }

    // Clear all button
    if (_currentFilter.isNotEmpty) {
      chips.add(
        TextButton(
          onPressed: onClearAll,
          child: const Text('Clear all', style: TextStyle(color: Colors.red)),
        ),
      );
    }

    return chips;
  }
}