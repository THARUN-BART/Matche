import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../service/realtime_chat_service.dart';
import '../service/firestore_service.dart';
import 'realtime_chat_screen.dart';
import 'group_chat_screen.dart';
import '../widget/group_card.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late RealtimeChatService _chatService;
  late FirestoreService _firestoreService;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService = Provider.of<RealtimeChatService>(context, listen: false);
      _firestoreService = Provider.of<FirestoreService>(context, listen: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chats'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Individual'),
              Tab(text: 'Groups'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [
            _buildIndividualChats(),
            _buildGroupChats(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showNewChatOptions,
          backgroundColor: Colors.green,
          child: const Icon(Icons.chat, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildIndividualChats() {
    return StreamBuilder<List<ChatRoom>>(
      stream: _chatService.getChatRooms(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading chats'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chatRooms = snapshot.data ?? [];
        final individualChats = chatRooms.where((chat) => chat.type == 'individual').toList();

        if (individualChats.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No individual chats yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                Text(
                  'Start a conversation with someone!',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: individualChats.length,
          itemBuilder: (context, index) {
            final chatRoom = individualChats[index];
            return _buildIndividualChatTile(chatRoom);
          },
        );
      },
    );
  }

  Widget _buildIndividualChatTile(ChatRoom chatRoom) {
    // Get the other user's ID (not current user)
    final otherUserId = chatRoom.participants
        .firstWhere((id) => id != _firestoreService.currentUserId);

    return FutureBuilder<DocumentSnapshot>(
      future: _firestoreService.getUserData(otherUserId),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final userName = userData?['name'] ?? 'Unknown User';
        final userAvatar = userData?['avatarUrl'];
        final isOnline = userData?['isOnline'] ?? false;

        final unreadCount = chatRoom.unreadCount[_firestoreService.currentUserId] ?? 0;

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: userAvatar != null ? NetworkImage(userAvatar) : null,
                child: userAvatar == null
                    ? Text(userName[0].toUpperCase())
                    : null,
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            userName,
            style: TextStyle(
              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chatRoom.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unreadCount > 0 ? Colors.black : Colors.grey[600],
                  fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    _formatLastMessageTime(chatRoom.lastMessageTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: unreadCount > 0 ? Colors.green : Colors.grey[500],
                    ),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RealtimeChatScreen(
                  otherUserId: otherUserId,
                  otherUserName: userName,
                  chatId: chatRoom.chatId,
                ),
              ),
            );
          },
          onLongPress: () => _showChatOptions(chatRoom, userName),
        );
      },
    );
  }

  Widget _buildGroupChats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getUserGroups(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading groups'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data?.docs ?? [];

        if (groups.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No group chats yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                Text(
                  'Join or create a group to start chatting!',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final groupData = groups[index].data() as Map<String, dynamic>;
            final groupMap = {
              'id': groups[index].id,
              'name': groupData['name'] ?? 'Unknown Group',
              'description': groupData['description'] ?? '',
              'memberCount': groupData['memberCount'] ?? 0,
              'maxMembers': groupData['maxMembers'] ?? 10,
              'category': groupData['category'] ?? 'General',
              'skills': groupData['skills'] ?? [],
              'userRole': groupData['adminId'] == _firestoreService.currentUserId ? 'admin' : 'member',
            };
            
            return GroupCard(
              group: groupMap,
              onTap: () {
                // Navigate to group chat
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupChatScreen(
                      groupId: groups[index].id,
                      groupName: groupData['name'] ?? 'Unknown Group',
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

  void _showNewChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('New Individual Chat'),
              onTap: () {
                Navigator.pop(context);
                _showUserList();
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Create New Group'),
              onTap: () {
                Navigator.pop(context);
                _showCreateGroup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Join Group'),
              onTap: () {
                Navigator.pop(context);
                _showJoinGroup();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUserList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserListScreen(),
      ),
    );
  }

  void _showCreateGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateGroupScreen(),
      ),
    );
  }

  void _showJoinGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JoinGroupScreen(),
      ),
    );
  }

  void _showChatOptions(ChatRoom chatRoom, String userName) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: Text('View ${userName}\'s Profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Clear Chat'),
              onTap: () {
                Navigator.pop(context);
                _showClearChatConfirmation(chatRoom.chatId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Block User'),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation(userName);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearChatConfirmation(String chatId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all messages? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle clear chat
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat cleared')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBlockConfirmation(String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle block user
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$userName has been blocked')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatLastMessageTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    
    if (messageDate == today) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${time.day}/${time.month}';
    }
  }
}

// Placeholder screens - you can implement these later
class UserListScreen extends StatelessWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select User')),
      body: const Center(child: Text('User list coming soon...')),
    );
  }
}

class CreateGroupScreen extends StatelessWidget {
  const CreateGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Group')),
      body: const Center(child: Text('Create group coming soon...')),
    );
  }
}

class JoinGroupScreen extends StatelessWidget {
  const JoinGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Group')),
      body: const Center(child: Text('Join group coming soon...')),
    );
  }
}

class GroupChatScreen extends StatelessWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('Group chat coming soon...')),
    );
  }
} 