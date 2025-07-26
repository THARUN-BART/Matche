import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:matcha/constants/Constant.dart';
import '../service/matching_service.dart';
import '../service/firestore_service.dart';
import '../widget/filter_function.dart';
import '../widget/skeleton_loading.dart';

class BestMatchesScreen extends StatefulWidget {
  const BestMatchesScreen({Key? key}) : super(key: key);

  @override
  State<BestMatchesScreen> createState() => _BestMatchesScreenState();
}

class _BestMatchesScreenState extends State<BestMatchesScreen> {
  final FilterManager _filterManager = FilterManager();
  bool _isLoading = false;
  bool _hasError = false;
  bool _isOffline = false;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _isOffline = false;
    });

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (!mounted) return;
        setState(() {
          _isOffline = true;
          _hasError = true;
          _isLoading = false;
        });
        return;
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _refreshKey++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _retryLoading() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _isOffline = false;
    });

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (!mounted) return;
        setState(() {
          _isOffline = true;
          _hasError = true;
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No internet connection'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Simulate network request delay
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = false;
        _refreshKey++; // Force FutureBuilder to rebuild with fresh data
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isOffline ? Icons.wifi_off : Icons.error_outline,
            size: 48,
            color: _isOffline ? Colors.orange : Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            _isOffline ? 'No internet connection' : 'Failed to load matches',
            style: TextStyle(
              color: _isOffline ? Colors.orange : Colors.red,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _retryLoading,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFEC3D),
              foregroundColor: Colors.black,
            ),
            child: const Text('Retry'),
          ),
        ],
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

  void _onFilterApplied(FilterCriteria filter) {
    setState(() {
      // This will trigger a rebuild with new filters
    });
  }

  void _deleteAvailabilityFilter(String day, String? slot) {
    final currentAvailability = Map<String, List<String>>.from(_filterManager.currentFilter.availability);
    if (slot != null) {
      currentAvailability[day]?.remove(slot);
      if (currentAvailability[day]!.isEmpty) {
        currentAvailability.remove(day);
      }
    }
    _filterManager.updateFilter(_filterManager.currentFilter.copyWith(availability: currentAvailability));
    setState(() {});
  }

  void _deleteSkillFilter(String skill) {
    final currentSkills = List<String>.from(_filterManager.currentFilter.skills);
    currentSkills.remove(skill);
    _filterManager.updateFilter(_filterManager.currentFilter.copyWith(skills: currentSkills));
    setState(() {});
  }

  void _deleteInterestFilter(String interest) {
    final currentInterests = List<String>.from(_filterManager.currentFilter.interests);
    currentInterests.remove(interest);
    _filterManager.updateFilter(_filterManager.currentFilter.copyWith(interests: currentInterests));
    setState(() {});
  }

  void _clearAllFilters() {
    _filterManager.clearFilters();
    setState(() {});
  }

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
            onPressed: () => _filterManager.showFilterDialog(
              context,
              onFilterApplied: _onFilterApplied,
            ),
            icon: const Icon(Icons.filter_list_sharp),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadMatches();
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
              if (_filterManager.currentFilter.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _filterManager.buildFilterChips(
                      onDeleteAvailability: _deleteAvailabilityFilter,
                      onDeleteSkill: _deleteSkillFilter,
                      onDeleteInterest: _deleteInterestFilter,
                      onClearAll: _clearAllFilters,
                    ),
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

                        // Use the refresh key to force FutureBuilder to rebuild
                        return FutureBuilder<List<Map<String, dynamic>>>(
                          key: ValueKey(_refreshKey), // This forces rebuild when key changes
                          future: userId != null
                              ? matchingService.getClusterMatches(
                            userId,
                            top: 20,
                          )
                              : Future.value([]),
                          builder: (context, snapshot) {
                            // Show loading during retry
                            if (_isLoading) {
                              return const SkeletonMatchListVertical(itemCount: 5);
                            }

                            if (_hasError || snapshot.hasError) {
                              return _buildErrorWidget();
                            }

                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SkeletonMatchListVertical(itemCount: 5);
                            }

                            final matches = snapshot.data ?? [];

                            // Apply filters using FilterManager
                            final filteredMatches = _filterManager.applyFilters(matches, connectedUserIds);

                            if (filteredMatches.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('No matches found'),
                                    if (_filterManager.currentFilter.isNotEmpty)
                                      TextButton(
                                        onPressed: _clearAllFilters,
                                        child: const Text('Clear filters'),
                                      ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              itemCount: filteredMatches.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final match = filteredMatches[index];
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
}