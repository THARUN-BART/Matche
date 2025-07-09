import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../service/firestore_service.dart';
import '../../service/group_service.dart';
import '../../widget/chat_screen.dart';
import '../../widget/common_widget.dart';
import '../../widget/group_card.dart';
import '../../widget/match_card.dart';
import '../../widget/skeleton_loading.dart';
import 'group_chat_screen.dart';
import '../../service/matching_service.dart';
import 'settings.dart' show AboutMyselfDialog;
import '../../widget/connection_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<String> _sentRequestUserIds = {};
  int _unreadNotifCount = 0;
  bool _checkingProfile = true;
  bool _profileComplete = false;
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();
    _checkProfileCompleteness();
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
    final hasSkills = (data['skills'] is List && (data['skills'] as List).isNotEmpty);
    final hasInterests = (data['interests'] is List && (data['interests'] as List).isNotEmpty);
    final hasAvailability = data['availability'] != null && data['availability'].toString().isNotEmpty;
    final big5 = data['big5'];
    final hasBig5 = big5 is Map && ['O','C','E','A','N'].every((k) => big5[k] != null);
    final complete = hasSkills && hasInterests && hasAvailability && hasBig5;
    setState(() {
      _checkingProfile = false;
      _profileComplete = complete;
    });
    if (!complete) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AboutMyselfDialog(
            userData: data,
            onSave: (newData) async {
              await firestoreService.updateUserProfile(newData);
              if (!mounted) return;
              setState(() {
                _profileComplete = true;
                _userData = {..._userData, ...newData};
              });
            },
          ),
        );
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final matchingService = Provider.of<MatchingService>(context, listen: false);
    final userId = firestoreService.currentUserId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [],
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: _checkingProfile
          ? const Center(child: CircularProgressIndicator())
          : !_profileComplete
              ? const Center(child: Text('Please complete your profile to see matches.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Best Peer Matches Section
                      buildSectionHeader("Best Peer Matches", "Based on your profile and preferences"),
                      const SizedBox(height: 12),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: userId != null
                            ? matchingService.getClusterMatches(userId, top: 5)
                            : Future.value([]),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            print('Error loading peers:  [31m [1m [4m [7m [5m${snapshot.error} [0m');
                            return const Text('Error loading peers');
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SkeletonMatchList(itemCount: 5);
                          }
                          final matches = snapshot.data ?? [];
                          if (matches.isEmpty) {
                            return const Text('No compatible peers found.');
                          }
                          return SizedBox(
                            height: 220,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: matches.length,
                              separatorBuilder: (context, index) => SizedBox(width: 16),
                              itemBuilder: (context, index) {
                                final match = matches[index];
                                return FutureBuilder<Map<String, dynamic>>(
                                  future: matchingService.getUserDetails(match['uid']),
                                  builder: (context, userSnapshot) {
                                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                                      return SizedBox(
                                        width: 180,
                                        child: Card(child: Center(child: CircularProgressIndicator())),
                                      );
                                    }
                                    if (userSnapshot.hasError || userSnapshot.data == null) {
                                      return SizedBox(
                                        width: 180,
                                        child: Card(child: Center(child: Text('Error'))),
                                      );
                                    }
                                    final user = userSnapshot.data!;
                                    return SizedBox(
                                      width: 180,
                                      child: Card(
                                        elevation: 4,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(user['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              SizedBox(height: 8),
                                              Text('Similarity: ${match['similarity']}%', style: TextStyle(color: Colors.grey[700])),
                                              SizedBox(height: 8),
                                              ElevatedButton(
                                                onPressed: () {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Connect request sent to ${user['name'] ?? 'user'}!')),
                                                  );
                                                },
                                                child: Text('Connect'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      // Group Management Section
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGroupDialog(context),
        icon: const Icon(Icons.group_add),
        label: const Text('Create Group'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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

  void _showCreateGroupDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final maxMembersCtrl = TextEditingController(text: '10');
    final skillsCtrl = TextEditingController();
    final groupService = Provider.of<GroupService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create Study Group"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category (e.g., Study, Project, Research)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: maxMembersCtrl,
                decoration: const InputDecoration(
                  labelText: 'Max Members',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: skillsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Skills (comma-separated)',
                  hintText: 'e.g., Python, Math, Design',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || descCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all required fields')),
                );
                return;
              }

              try {
                final skills = skillsCtrl.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                await groupService.createGroup(
                  name: nameCtrl.text,
                  description: descCtrl.text,
                  skills: skills,
                  category: categoryCtrl.text.isEmpty ? 'General' : categoryCtrl.text,
                  maxMembers: int.tryParse(maxMembersCtrl.text) ?? 10,
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Group created successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating group: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text("Create"),
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
      MaterialPageRoute(builder: (_) => ChatScreen(chatId: '${chatId[0]}_${chatId[1]}')),
    );
  }

  void _openGroupChat(BuildContext context, String groupId, Map<String, dynamic> group) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: groupId, group: group)),
    );
  }
}
