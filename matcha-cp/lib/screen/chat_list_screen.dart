import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../service/realtime_chat_service.dart';
import '../service/firestore_service.dart';
import '../service/group_service.dart';
import 'NavigationScreen/group_chat_screen.dart';
import 'realtime_chat_screen.dart';
import 'group_invitations_screen.dart';
import '../widget/group_card.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late RealtimeChatService _chatService;
  late FirestoreService _firestoreService;
  late GroupService _groupService;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _chatService = Provider.of<RealtimeChatService>(context, listen: false);
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
    _groupService = Provider.of<GroupService>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Group Chats',

          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Color(0xFFFFEC3D)
          ),
        ),
        centerTitle: true,
      ),
      body: _buildGroupChats(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatOptions,
        backgroundColor: Color(0xFFFFEC3D),
        elevation: 8,
        child: const Icon(Icons.chat, color: Colors.black, size: 28),
      ),
    );
  }

  Widget _buildGroupChats() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _groupService.getUserGroups(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget('Error loading groups', snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        }

        final groups = snapshot.data ?? [];

        if (groups.isEmpty) {
          return _buildEmptyState(
            icon: Icons.group_outlined,
            title: 'No group chats yet',
            subtitle: 'Join or create a group to start chatting!',
            actionText: 'Create Group',
            onAction: _showCreateGroup,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: GroupCard(
                group: group,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupChatScreen(
                        groupId: group['id'],
                        group: group,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFEC3D)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading chats...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String title, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFFEC3D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add),
            label: Text(actionText),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFFEC3D),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNewChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Group Options',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildOptionTile(
                icon: Icons.group_add,
                title: 'Create New Group',
                subtitle: 'Create a new group chat',
                onTap: () {
                  Navigator.pop(context);
                  _showCreateGroup();
                },
              ),
              _buildOptionTile(
                icon: Icons.mail,
                title: 'Group Invitations',
                subtitle: 'View pending group invitations',
                onTap: () {
                  Navigator.pop(context);
                  _showGroupInvitations();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFFFFEC3D),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.black, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showGroupInvitations() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GroupInvitationsScreen(),
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

  void _showChatOptions(ChatRoom chatRoom, String userName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chat Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            _buildOptionTile(
              icon: Icons.person,
              title: 'View ${userName}\'s Profile',
              subtitle: 'See their profile information',
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile
              },
            ),
            _buildOptionTile(
              icon: Icons.delete_outline,
              title: 'Clear Chat',
              subtitle: 'Delete all messages',
              onTap: () {
                Navigator.pop(context);
                _showClearChatConfirmation(chatRoom.chatId);
              },
            ),
            _buildOptionTile(
              icon: Icons.block,
              title: 'Block User',
              subtitle: 'Block this user',
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation(userName);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showClearChatConfirmation(String chatId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Clear Chat',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to clear all messages? This action cannot be undone.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatService.clearChat(chatId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat cleared successfully'),
                      backgroundColor: Color(0xFFFFEC3D),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear chat: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showBlockConfirmation(String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Block User',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to block $userName? You won\'t be able to send or receive messages from them.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // TODO: Implement block user functionality
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$userName has been blocked'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to block user: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Block'),
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
class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  late FirestoreService _firestoreService;
  late RealtimeChatService _chatService;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
    _chatService = Provider.of<RealtimeChatService>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select User'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.getUserConnections(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading users'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                          'No connections yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        Text(
                          'Connect with people to start chatting!',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Filter connections based on search query
                final filteredConnections = connections.where((doc) {
                  // We'll need to get user data to filter by name
                  return true; // For now, show all connections
                }).toList();

                return ListView.builder(
                  itemCount: filteredConnections.length,
                  itemBuilder: (context, index) {
                    final connectionId = filteredConnections[index].id;
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestoreService.getUserById(connectionId),
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
                        final userName = user['name'] ?? 'Unknown User';
                        final userEmail = user['email'] ?? '';
                        final userAvatar = user['avatarUrl'];

                        // Filter by search query
                        if (_searchQuery.isNotEmpty) {
                          if (!userName.toLowerCase().contains(_searchQuery.toLowerCase()) &&
                              !userEmail.toLowerCase().contains(_searchQuery.toLowerCase())) {
                            return const SizedBox.shrink();
                          }
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: userAvatar != null ? NetworkImage(userAvatar) : null,
                            child: userAvatar == null
                                ? Text(userName[0].toUpperCase())
                                : null,
                          ),
                          title: Text(userName),
                          subtitle: Text(userEmail),
                          trailing: const Icon(Icons.chat_bubble_outline),
                          onTap: () => _startChat(connectionId, userName),
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
    );
  }

  Future<void> _startChat(String otherUserId, String otherUserName) async {
    try {
      print('Starting chat with user: $otherUserId ($otherUserName)');
      
      // Create or get chat room
      final chatId = await _chatService.createOrGetChatRoom(otherUserId);
      print('Chat room created/retrieved: $chatId');
      
      if (mounted) {
        Navigator.pop(context); // Close user list
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RealtimeChatScreen(
              otherUserId: otherUserId,
              otherUserName: otherUserName,
              chatId: chatId,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error starting chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _startChat(otherUserId, otherUserName),
            ),
          ),
        );
      }
    }
  }
}

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxMembersController = TextEditingController(text: '10');
  String _selectedCategory = 'General';
  List<String> _selectedSkills = [];
  bool _isLoading = false;

  final List<String> _categories = [
    'General',
    'Technology',
    'Business',
    'Education',
    'Health',
    'Sports',
    'Entertainment',
    'Other'
  ];

  final List<String> _availableSkills = [
    'Programming',
    'Design',
    'Marketing',
    'Sales',
    'Management',
    'Communication',
    'Leadership',
    'Problem Solving',
    'Creativity',
    'Analytics'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxMembersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        backgroundColor: Color(0xFFFFEC3D),
        foregroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createGroup,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text(
                    'Create',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a group name';
                }
                if (value.trim().length < 3) {
                  return 'Group name must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxMembersController,
              decoration: const InputDecoration(
                labelText: 'Max Members',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter max members';
                }
                final number = int.tryParse(value);
                if (number == null || number < 2 || number > 100) {
                  return 'Please enter a valid number between 2 and 100';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Skills (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _availableSkills.map((skill) {
                final isSelected = _selectedSkills.contains(skill);
                return FilterChip(
                  label: Text(skill),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSkills.add(skill);
                      } else {
                        _selectedSkills.remove(skill);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final groupService = Provider.of<GroupService>(context, listen: false);

      final groupId = await groupService.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        skills: _selectedSkills,
        maxMembers: int.parse(_maxMembersController.text),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group created successfully!'),
            backgroundColor: Color(0xFFFFEC3D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// This is now imported from join_group_screen.dart