import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../service/firestore_service.dart';
import '../../service/group_service.dart';
import '../../widget/chat_screen.dart';
import '../../widget/common_widget.dart';
import '../../widget/group_card.dart';
import '../../widget/match_card.dart';
import 'group_chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Actions
          Row(
            children: [
              Expanded(
                child: buildQuickActionCard(
                  "Find Partner",
                  Icons.search,
                  Colors.blue,
                      () => _showMatchingDialog(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildQuickActionCard(
                  "Create Group",
                  Icons.group_add,
                  Colors.green,
                      () => _showCreateGroupDialog(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Notifications Section
          buildSectionHeader("Notifications", "Recent activity"),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: firestoreService.getUnreadNotifications(),
            builder: (context, notifSnap) {
              if (notifSnap.hasError) {
                return const Text('Error loading notifications');
              }
              if (notifSnap.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              final docs = notifSnap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text("No new notifications");
              }

              return Column(
                children: docs.map((doc) {
                  final n = doc.data() as Map<String, dynamic>;
                  final fromId = n['from'] as String;
                  final notifId = doc.id;
                  final timestamp = (n['timestamp'] as Timestamp).toDate();

                  return FutureBuilder<DocumentSnapshot>(
                    future: firestoreService.getUserById(fromId),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData) return const SizedBox();
                      final user = userSnap.data!.data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.person_add, color: Colors.deepPurple),
                        title: Text("${user['name']} accepted your connection"),
                        subtitle: Text("${timestamp.toLocal()}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () {
                            FirebaseFirestore.instance
                                .collection('notifications')
                                .doc(notifId)
                                .update({'read': true});
                          },
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          // Suggested Matches Section
          buildSectionHeader("Suggested Matches", "Based on your profile"),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: firestoreService.getAllUsersExceptCurrent(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Error loading matches');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              final users = snapshot.data?.docs ?? [];
              return SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final u = users[index];
                    final user = u.data() as Map<String, dynamic>;
                    return MatchCard(
                      user: user,
                      onConnect: () => _connectWithPeer(context, u.id),
                      onChat: () => _openChat(context, u.id),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Active Groups Section
          buildSectionHeader("Your Groups", "Study groups and projects"),
          const SizedBox(height: 12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Provider.of<GroupService>(context, listen: false).getUserGroups(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Error loading groups');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              final groups = snapshot.data ?? [];
              if (groups.isEmpty) {
                return const Card(
                  child: Padding(
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
                decoration: const InputDecoration(labelText: 'Group Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'Category (e.g., Study, Project, Research)'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: maxMembersCtrl,
                decoration: const InputDecoration(labelText: 'Max Members'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: skillsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Skills (comma-separated)',
                  hintText: 'e.g., Python, Math, Design',
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
