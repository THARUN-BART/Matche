import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../service/firestore_service.dart';
import '../../service/group_service.dart';
import '../../widget/chat_screen.dart';
import '../../widget/common_widget.dart';
import '../../widget/group_card.dart';
import '../../widget/skeleton_loading.dart';
import 'group_chat_screen.dart';
import '../../service/matching_service.dart';
import '../account_info.dart';
import '../best_matches_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int _unreadNotifCount = 0;
  bool _checkingProfile = true;
  bool _profileComplete = false;
  Map<String, dynamic> _userData = {};
  Set<String> _sentRequestUserIds = {};
  Set<String> _pendingRequestUserIds = {};
  Set<String> _connectedUserIds = {};

  @override
  void initState() {
    super.initState();
    _checkProfileCompleteness();
    _loadConnectionRequests();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh connection requests when dependencies change (e.g., when returning from other screens)
    if (_profileComplete) {
      _loadConnectionRequests();
    }
  }



  Future<void> _checkProfileCompleteness() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final userSnap = await firestoreService.getCurrentUserData();
    if (!userSnap.exists) {
      setState(() {
        _checkingProfile = false;
        _profileComplete = false;
      });
      return;
    }
    final data = userSnap.data() as Map<String, dynamic>;
    _userData = data;
    
    // Check each profile section
    final missingSections = _getMissingProfileSections(data);
    final complete = missingSections.isEmpty;
    
    setState(() {
      _checkingProfile = false;
      _profileComplete = complete;
    });
    
    if (!complete) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showProfileCompletionDialog(missingSections, data);
      });
    }
  }

  List<String> _getMissingProfileSections(Map<String, dynamic> data) {
    final missingSections = <String>[];
    
    // Check Skills
    final hasSkills = (data['skills'] is List && (data['skills'] as List).isNotEmpty);
    if (!hasSkills) missingSections.add('Skills');
    
    // Check Interests
    final hasInterests = (data['interests'] is List && (data['interests'] as List).isNotEmpty);
    if (!hasInterests) missingSections.add('Interests');

    final hasAvailability = data['availability'] != null && 
                           data['availability'].toString().isNotEmpty &&
                           data['availability'] != '[]';
    if (!hasAvailability) missingSections.add('Availability');
    
    // Check Big5 Personality
    final big5 = data['big5'];
    final hasBig5 = big5 is Map && 
                   ['O','C','E','A','N'].every((k) => big5[k] != null && big5[k] is num);
    if (!hasBig5) missingSections.add('Personality Assessment');
    
    return missingSections;
  }

  void _showProfileCompletionDialog(List<String> missingSections, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Your Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To see matching peers, please complete your profile information.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Missing sections:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...missingSections.map((section) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(section),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountInfo(),
                ),
              ).then((_) {
                // Refresh profile completeness after returning from account info
                _checkProfileCompleteness();
              });
            },
            child: const Text('Complete Profile'),
          ),
        ],
      ),
    );
  }

  void _showNotificationsModal(BuildContext context, List<QueryDocumentSnapshot> notifications) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (notifications.isEmpty)
                const Text('No new notifications'),
              ...notifications.map((doc) {
                final n = doc.data() as Map<String, dynamic>;
                final fromId = n['from'] as String?;
                final notifId = doc.id;
                final timestamp = (n['timestamp'] as Timestamp?)?.toDate();
                return ListTile(
                  leading: const Icon(Icons.notifications, color: Colors.deepPurple),
                  title: Text(n['title'] ?? 'Notification'),
                  subtitle: Text(timestamp != null ? '${timestamp.toLocal()}' : ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(notifId)
                          .update({'read': true});
                      Navigator.pop(context);
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadConnectionRequests() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final currentUserId = firestoreService.currentUserId;
    
    if (currentUserId.isEmpty) return;

    try {
      // Load sent requests
      final sentRequestsQuery = await firestoreService.getSentConnectionRequests().first;
      final sentUserIds = sentRequestsQuery.docs.map((doc) => doc.id).toSet();
      
      // Load pending requests (requests sent to current user)
      final receivedRequestsQuery = await firestoreService.getReceivedConnectionRequests().first;
      final pendingUserIds = receivedRequestsQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['from'] as String;
      }).toSet();

      // Load existing connections
      final connectionsQuery = await firestoreService.getUserConnections().first;
      final connectedUserIds = connectionsQuery.docs.map((doc) => doc.id).toSet();

      setState(() {
        _sentRequestUserIds = sentUserIds;
        _pendingRequestUserIds = pendingUserIds;
        _connectedUserIds = connectedUserIds;
      });
    } catch (e) {
      print('Error loading connection requests: $e');
    }
  }

  Future<void> _sendConnectionRequest(String targetUserId, String userName) async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final currentUserId = firestoreService.currentUserId;
    
    try {
      await firestoreService.sendConnectionRequest(currentUserId, targetUserId);
      
      setState(() {
        _sentRequestUserIds.add(targetUserId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection request sent to $userName!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildConnectionButton(String userId, String userName) {
    final isSent = _sentRequestUserIds.contains(userId);
    final isPending = _pendingRequestUserIds.contains(userId);
    final isConnected = _connectedUserIds.contains(userId);
    
    if (isConnected) {
      return PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'chat':
              _openChatWithUser(userId, userName);
              break;
            case 'block':
              _showBlockUserDialog(userId, userName);
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'chat',
            child: Row(
              children: [
                Icon(Icons.chat, color: Colors.blue),
                SizedBox(width: 8),
                Text('Chat'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'block',
            child: Row(
              children: [
                Icon(Icons.block, color: Colors.red),
                SizedBox(width: 8),
                Text('Block'),
              ],
            ),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
              const SizedBox(width: 4),
              Text(
                'Connected',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 16, color: Colors.green.shade700),
            ],
          ),
        ),
      );
    }
    
    if (isSent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 4),
            Text(
              'Pending',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    
    if (isPending) {
      return InkWell(
        onTap: () => _showRespondToRequestDialog(userId, userName),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 4),
              Text(
                'Respond',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return ElevatedButton(
      onPressed: () => _sendConnectionRequest(userId, userName),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: const Text(
        'Connect',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  void _showRespondToRequestDialog(String fromUserId, String fromUserName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Request'),
        content: Text('$fromUserName wants to connect with you. Would you like to accept or decline?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToConnectionRequest(fromUserId, false);
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToConnectionRequest(fromUserId, true);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _respondToConnectionRequest(String fromUserId, bool accept) async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    
    try {
      // Find the request document
      final requestsQuery = await firestoreService.getReceivedConnectionRequests().first;
      final requestDoc = requestsQuery.docs.firstWhere(
        (doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['from'] == fromUserId;
        },
      );
      
      if (accept) {
        await firestoreService.acceptConnectionRequest(
          requestId: requestDoc.id,
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
      } else {
        await firestoreService.rejectConnectionRequest(requestDoc.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection declined.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      
      // Refresh connection requests
      _loadConnectionRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error responding to request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openChatWithUser(String userId, String userName) {
    final currentUserId = Provider.of<FirestoreService>(context, listen: false).currentUserId;
    final chatId = [currentUserId, userId]..sort();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: '${chatId[0]}_${chatId[1]}',
          otherUserId: userId,
          otherUserName: userName,
        ),
      ),
    );
  }

  void _showBlockUserDialog(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block $userName? This will:\n\n• Remove your connection\n• Prevent future messages\n• Hide them from your matches'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _blockUser(userId, userName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser(String userId, String userName) async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final currentUserId = firestoreService.currentUserId;
    
    try {
      // Remove connection from both users
      await firestoreService.removeConnection(currentUserId, userId);
      
      // Add to blocked users list
      await firestoreService.blockUser(currentUserId, userId);
      
      // Update local state
      setState(() {
        _connectedUserIds.remove(userId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userName has been blocked'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error blocking user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final matchingService = Provider.of<MatchingService>(context, listen: false);
    final userId = firestoreService.currentUserId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home', style: TextStyle(fontWeight: FontWeight.bold,color: Color(0xFFFFEC3D))),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _checkingProfile
          ? const Center(child: CircularProgressIndicator())
          : !_profileComplete
              ? _buildProfileIncompleteView()
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadConnectionRequests();
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BestMatchesScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Color(0xFFFFEC3D),
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                              side: BorderSide(
                                color: Colors.white,
                                width: 5,
                              ),
                            ),
                            elevation: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Find my Best Matches ",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SvgPicture.asset(
                                'Assets/match.svg',
                                height: 50,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_connectedUserIds.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildSectionHeader("Your Connections", "People you're connected with"),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 120,
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: firestoreService.getUserConnections(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return const Text('Error loading connections');
                                    }
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const SkeletonList(itemCount: 3, itemHeight: 100);
                                    }
                                    final connections = snapshot.data?.docs ?? [];
                                    if (connections.isEmpty) {
                                      return const Text('No connections yet.');
                                    }
                                    return ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: connections.length,
                                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                                      itemBuilder: (context, index) {
                                        final connectionId = connections[index].id;
                                        return FutureBuilder<DocumentSnapshot>(
                                          future: firestoreService.getUserById(connectionId),
                                          builder: (context, userSnapshot) {
                                            if (userSnapshot.connectionState == ConnectionState.waiting) {
                                              return SizedBox(
                                                width: 100,
                                                child: Card(child: Center(child: CircularProgressIndicator())),
                                              );
                                            }
                                            if (userSnapshot.hasError || userSnapshot.data == null) {
                                              return const SizedBox.shrink();
                                            }
                                            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                                            if (userData == null) return const SizedBox.shrink();

                                            return SizedBox(
                                              width: 100,
                                              child: Card(
                                                elevation: 2,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                  side: BorderSide(color: Colors.transparent, width: 3),
                                                ),
                                                child: InkWell(
                                                  onTap: () => _openChatWithUser(
                                                    connectionId,
                                                    userData['name'] ?? 'Unknown',
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(8.0),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        CircleAvatar(
                                                          backgroundColor: Colors.green.shade100,
                                                          child: Text(
                                                            (userData['name'] ?? 'U').substring(0, 1).toUpperCase(),
                                                            style: TextStyle(
                                                              color: Colors.green.shade700,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          userData['name'] ?? 'Unknown',
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
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
                        const SizedBox(height: 24),
                      ],


                      buildSectionHeader("Your Groups", "Study groups and projects"),
                      const SizedBox(height: 12),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: Provider.of<GroupService>(context, listen: false).getUserGroups(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Text('Error loading groups');
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SkeletonList(itemCount: 2, itemHeight: 100);
                          }
                          final groups = snapshot.data ?? [];
                          if (groups.isEmpty) {
                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No groups yet. Create your first study group!',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: groups.map((group) {
                              return GroupCard(
                                group: group,
                                onTap: () => _openGroupChat(context, group['id'], group),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildProfileIncompleteView() {
    final missingSections = _getMissingProfileSections(_userData);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Complete Your Profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'To see matching peers, please complete your profile information.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            if (missingSections.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Missing sections:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...missingSections.map((section) => Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.orange.shade600),
                          const SizedBox(width: 8),
                          Text(
                            section,
                            style: TextStyle(color: Colors.orange.shade700),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountInfo(),
                  ),
                ).then((_) {
                  // Refresh profile completeness after returning from account info
                  _checkProfileCompleteness();
                });
              },
              icon: const Icon(Icons.edit),
              label: const Text('Complete Profile'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMatchingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Find Study Partner"),
        content: const Text("Searching for compatible study partners based on your profile..."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Searching for matches...")),
              );
            },
            child: const Text("Search"),
          ),
        ],
      ),
    );
  }


  void _connectWithPeer(BuildContext context, String userId) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    firestoreService.addConnection(userId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Connection created"), backgroundColor: Colors.green),
    );
  }

  void _openChat(BuildContext context, String userId) {
    final currentUserId = Provider.of<FirestoreService>(context, listen: false).currentUserId;
    final chatId = [currentUserId, userId]..sort();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(
        chatId: '${chatId[0]}_${chatId[1]}',
        otherUserId: userId,
      )),
    );
  }

  void _openGroupChat(BuildContext context, String groupId, Map<String, dynamic> group) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: groupId, group: group)),
    );
  }
}


