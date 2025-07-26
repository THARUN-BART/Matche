import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../service/firestore_service.dart';
import '../../widget/chat_screen.dart';
import '../../widget/connection_card.dart';
import '../../widget/filter_function.dart';
import '../../widget/profile_viewer_screen.dart';
import '../../widget/skeleton_loading.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Set<String> _connectedUserIds = {};
  Set<String> _sentRequestUserIds = {};
  Set<String> _rejectedRequestUserIds = {};
  List<StreamSubscription> _subscriptions = [];

  // Search controller and query state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // FilterManager instance
  final FilterManager _filterManager = FilterManager();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchConnectionsAndRequests();

    // Check if we need to navigate to a specific tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTabArguments();
    });
  }

  void _checkTabArguments() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      final tab = args['tab'] as String?;
      if (tab != null) {
        int tabIndex = 0;
        switch (tab) {
          case 'requests':
            tabIndex = 2;
            break;
          case 'suggestions':
            tabIndex = 1;
            break;
          case 'matches':
            tabIndex = 0;
            break;
        }
        _tabController.animateTo(tabIndex);
      }
    }
  }

  Future<void> _fetchConnectionsAndRequests() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    final connectionsSubscription = firestoreService.getUserConnections().listen((snapshot) {
      if (mounted) {
        setState(() {
          _connectedUserIds = snapshot.docs.map((doc) => doc.id).toSet();
        });
      }
    });
    _subscriptions.add(connectionsSubscription);

    // Listen to sent requests
    final sentRequestsSubscription = firestoreService.getSentConnectionRequests().listen((snapshot) {
      if (mounted) {
        setState(() {
          _sentRequestUserIds = snapshot.docs.map((doc) => doc.id).toSet();
        });
      }
    });
    _subscriptions.add(sentRequestsSubscription);

    // Listen to rejected requests
    _listenToRejectedRequests();
  }

  void _listenToRejectedRequests() {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    final rejectedRequestsSubscription = firestoreService.getRejectedConnectionRequests().listen((snapshot) {
      if (mounted) {
        setState(() {
          _rejectedRequestUserIds = snapshot.docs.map((doc) => doc.id).toSet();
        });
      }
    });
    _subscriptions.add(rejectedRequestsSubscription);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  // Filter methods for FilterManager integration
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

  // Helper method to check if user matches filter criteria
  bool _matchesFilter(Map<String, dynamic> user) {
    if (_filterManager.currentFilter.isEmpty) return true;

    final userSkills = ((user['skills'] ?? []) as List)
        .map((s) => s.toString().toLowerCase())
        .toList();

    final userInterests = ((user['interests'] ?? []) as List)
        .map((i) => i.toString().toLowerCase())
        .toList();

    final userAvailability = (user['availability'] as Map?)?.map((key, value) {
      return MapEntry(key.toString(), List<String>.from(value));
    }) ?? {};

    // Skills filter
    if (_filterManager.currentFilter.skills.isNotEmpty) {
      final selectedLower = _filterManager.currentFilter.skills.map((e) => e.toLowerCase());
      if (!selectedLower.any((skill) => userSkills.contains(skill))) {
        return false;
      }
    }

    // Interests filter
    if (_filterManager.currentFilter.interests.isNotEmpty) {
      final selectedLower = _filterManager.currentFilter.interests.map((e) => e.toLowerCase());
      if (!selectedLower.any((interest) => userInterests.contains(interest))) {
        return false;
      }
    }

    // Availability filter
    if (_filterManager.currentFilter.availability.isNotEmpty) {
      bool hasMatch = false;
      for (final entry in _filterManager.currentFilter.availability.entries) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Connections',
          style: TextStyle(fontWeight: FontWeight.bold,color: Color(0xFFFFEC3D)),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFFEC3D),
          indicatorColor: const Color(0xFFFFEC3D),
          tabs: const [
            Tab(text: 'Connected'),
            Tab(text: 'Suggestions'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMatchesTab(),
          _buildSuggestionsTab(),
          _buildRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildMatchesTab() {
    final firestoreService = Provider.of<FirestoreService>(context);

    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.getUserConnections(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonList(itemCount: 5);
        }

        final connections = snapshot.data?.docs ?? [];

        if (connections.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No matches yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: connections.length,
          itemBuilder: (context, index) {
            final connectionId = connections[index].id;
            return FutureBuilder<DocumentSnapshot>(
              future: firestoreService.getUserById(connectionId),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    leading: CircleAvatar(),
                    title: Text('Loading...'),
                  );
                }

                if (!userSnapshot.hasData || userSnapshot.data?.data() == null) {
                  return const ListTile(
                    title: Text('User not found'),
                  );
                }

                final user = userSnapshot.data!.data() as Map<String, dynamic>;

                return ConnectionCard(
                  user: user,
                  isConnected: true,
                  hasSentRequest: false,
                  onTap: () => _openProfile(context, user, connectionId),
                  onAvatarTap: () => _openProfile(context, user, connectionId),
                  onMessage: () => _openChat(context, connectionId, user['name']),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSuggestionsTab() {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Column(
      children: [
        // Search and Filter Section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by username',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                    contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
              SizedBox(width: 8),
              TextButton(
                onPressed: () => _filterManager.showFilterDialog(
                  context,
                  onFilterApplied: _onFilterApplied,
                ),
                child: Icon(Icons.filter_list_sharp, size: 30),
              ),
            ],
          ),
        ),

        // Filter Chips Section
        if (_filterManager.currentFilter.isNotEmpty)
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterManager.buildFilterChips(
                  onDeleteAvailability: _deleteAvailabilityFilter,
                  onDeleteSkill: _deleteSkillFilter,
                  onDeleteInterest: _deleteInterestFilter,
                  onClearAll: _clearAllFilters,
                ),
              ),
            ),
          ),

        // Suggestions List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: firestoreService.getSuggestedConnections(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SkeletonList(itemCount: 5);
              }

              final suggestions = snapshot.data?.docs ?? [];

              // Filter suggestions by username and filters
              final filtered = suggestions.where((doc) {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null) return false;

                final username = (data['username'] ?? data['name'] ?? '').toString().toLowerCase();

                // Apply search filter
                if (_searchQuery.isNotEmpty && !username.contains(_searchQuery)) {
                  return false;
                }

                // Apply advanced filters
                if (!_matchesFilter(data)) {
                  return false;
                }

                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_search, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty || _filterManager.currentFilter.isNotEmpty
                            ? 'No matches found for your criteria'
                            : 'No suggestions available',
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      if (_filterManager.currentFilter.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _clearAllFilters,
                          child: const Text('Clear filters'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final suggestionId = filtered[index].id;

                  // Skip if user is already connected or is the current user
                  if (_connectedUserIds.contains(suggestionId) ||
                      suggestionId == firestoreService.currentUserId) {
                    return const SizedBox.shrink();
                  }

                  return FutureBuilder<DocumentSnapshot>(
                    future: firestoreService.getUserById(suggestionId),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return const ListTile(
                          leading: CircleAvatar(),
                          title: Text('Loading...'),
                        );
                      }

                      if (!userSnapshot.hasData || userSnapshot.data?.data() == null) {
                        return const ListTile(
                          title: Text('User not found'),
                        );
                      }

                      final user = userSnapshot.data!.data() as Map<String, dynamic>;
                      final hasSentRequest = _sentRequestUserIds.contains(suggestionId);
                      final hasRejectedRequest = _rejectedRequestUserIds.contains(suggestionId);

                      return ConnectionCard(
                        user: user,
                        isConnected: false,
                        hasSentRequest: hasSentRequest,
                        onTap: () => _showUserPreview(context, user, suggestionId),
                        onAvatarTap: () {
                          final name = user['name'] ?? 'Unknown';
                          final skills = (user['skills'] is List && user['skills'].isNotEmpty)
                              ? (user['skills'] as List).join(', ')
                              : 'Not specified';
                          final gender = user['gender'] ?? 'Not specified';
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(name),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Skills: $skills'),
                                  SizedBox(height: 8),
                                  Text('Gender: $gender'),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                        onConnect: (hasSentRequest || hasRejectedRequest)
                            ? null
                            : () => _sendConnectionRequest(context, suggestionId),
                        onResend: hasRejectedRequest
                            ? () => _resendConnectionRequest(context, suggestionId)
                            : null,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsTab() {
    final firestoreService = Provider.of<FirestoreService>(context);

    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.getReceivedConnectionRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonList(itemCount: 5);
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notification_important_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final requestData = request.data() as Map<String, dynamic>;
            final fromUserId = requestData['from'] as String;

            return FutureBuilder<DocumentSnapshot>(
              future: firestoreService.getUserById(fromUserId),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    leading: CircleAvatar(),
                    title: Text('Loading...'),
                  );
                }

                if (!userSnapshot.hasData || userSnapshot.data?.data() == null) {
                  return const ListTile(
                    title: Text('User not found'),
                  );
                }

                final user = userSnapshot.data!.data() as Map<String, dynamic>;

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFFFEC3D),
                        width: 1.2,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFFEC3D),
                        backgroundImage: user['avatarUrl'] != null
                            ? NetworkImage(user['avatarUrl'])
                            : null,
                        child: user['avatarUrl'] == null
                            ? Text(
                          user['name']?[0]?.toUpperCase() ?? '?',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                            : null,
                      ),
                      title: Text(
                        user['name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(user['email'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _declineConnectionRequest(request.id),
                            tooltip: 'Decline',
                          ),
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _acceptConnectionRequest(request.id, fromUserId),
                            tooltip: 'Accept',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Shows a preview of the user profile for suggestions
  void _showUserPreview(BuildContext context, Map<String, dynamic> user, String userId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFFFFEC3D),
                backgroundImage: user['avatarUrl'] != null
                    ? NetworkImage(user['avatarUrl'])
                    : null,
                child: user['avatarUrl'] == null
                    ? Text(
                  user['name']?[0]?.toUpperCase() ?? '?',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                user['name'] ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user['email'] ?? '',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _sendConnectionRequest(context, userId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFEC3D),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Connect'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens profile view screen (only for connected users)
  void _openProfile(BuildContext context, Map<String, dynamic> user, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileViewScreen(
          user: user,
          userId: userId,
        ),
      ),
    );
  }

  /// Opens chat screen
  void _openChat(BuildContext context, String userId, [String? userName]) {
    final currentUserId = Provider.of<FirestoreService>(context, listen: false).currentUserId;
    final chatId = _generateChatId(currentUserId, userId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatId,
          otherUserId: userId,
          otherUserName: userName,
        ),
      ),
    );
  }

  /// Generates consistent chat ID between two users
  String _generateChatId(String user1, String user2) {
    final sortedIds = [user1, user2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  /// Sends a connection request
  Future<bool> _sendConnectionRequest(BuildContext context, String recipientId) async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final currentUserId = firestoreService.currentUserId;

    setState(() {
      _sentRequestUserIds.add(recipientId);
    });

    try {
      await firestoreService.sendConnectionRequest(currentUserId, recipientId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection request sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _sentRequestUserIds.remove(recipientId);
        });
      }
      return false;
    }
  }

  Future<void> _acceptConnectionRequest(String requestId, String fromUserId) async {
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.acceptConnectionRequest(
        requestId: requestId,
        fromUserId: fromUserId,
        toUserId: firestoreService.currentUserId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection accepted!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept connection: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineConnectionRequest(String requestId) async {
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.rejectConnectionRequest(requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection declined'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline connection: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _resendConnectionRequest(BuildContext context, String recipientId) async {
    setState(() {
      _sentRequestUserIds.add(recipientId);
      _rejectedRequestUserIds.remove(recipientId);
    });

    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.sendConnectionRequest(
        firestoreService.currentUserId,
        recipientId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection request sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend request: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _sentRequestUserIds.remove(recipientId);
          _rejectedRequestUserIds.add(recipientId);
        });
      }
      return false;
    }
  }
}