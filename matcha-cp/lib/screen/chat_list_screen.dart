import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../service/realtime_chat_service.dart';
import '../service/firestore_service.dart';
import '../service/group_service.dart';
import 'realtime_chat_screen.dart';
import 'group_chat_screen.dart';
import 'join_group_screen.dart';
import '../widget/group_card.dart';
import '../widget/online_avatar.dart'; // Added import for OnlineAvatar

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
    _chatService = Provider.of<RealtimeChatService>(context, listen: false);
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
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
          print('Error loading individual chats: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Error loading chats'),
                const SizedBox(height: 8),
                Text('${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chatRooms = snapshot.data ?? [];
        final individualChats = chatRooms.where((chat) => chat.type == 'individual').toList();

        print('Found ${individualChats.length} individual chats');

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

        final unreadCount = chatRoom.unreadCount[_firestoreService.currentUserId] ?? 0;

        return StreamBuilder<bool>(
          stream: _chatService.getUserOnlineStatus(otherUserId),
          builder: (context, onlineSnapshot) {
            final isOnline = onlineSnapshot.data ?? false;

            return ListTile(
              leading: OnlineAvatar(
                imageUrl: userAvatar,
                name: userName,
                radius: 25,
                isOnline: isOnline,
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
              leading: const Icon(Icons.email),
              title: const Text('Start Chat by Email'),
              onTap: () {
                Navigator.pop(context);
                _showStartChatByEmailDialog();
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

  void _showStartChatByEmailDialog() {
    final _emailController = TextEditingController();
    bool _isLoading = false;
    String? _errorMessage;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Start Chat by Email'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'User Email',
                      errorText: _errorMessage,
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          try {
                            final userSnap = await _firestoreService.getUserByEmail(_emailController.text.trim());
                            if (userSnap == null || !userSnap.exists) {
                              setState(() {
                                _errorMessage = 'No user found with that email.';
                                _isLoading = false;
                              });
                              return;
                            }
                            final userData = userSnap.data() as Map<String, dynamic>?;
                            if (userData == null) {
                              setState(() {
                                _errorMessage = 'No user found with that email.';
                                _isLoading = false;
                              });
                              return;
                            }
                            final otherUserId = userSnap.id;
                            final otherUserName = userData['name'] ?? 'Unknown User';
                            Navigator.pop(context); // Close dialog
                            // Start chat
                            final chatId = await _chatService.createOrGetChatRoom(otherUserId);
                            if (mounted) {
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
                            setState(() {
                              _errorMessage = 'Error: $e';
                              _isLoading = false;
                            });
                          }
                        },
                  child: const Text('Start Chat'),
                ),
              ],
            );
          },
        );
      },
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
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatService.clearChat(chatId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat cleared successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear chat: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
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
        content: Text('Are you sure you want to block $userName? You won\'t be able to send or receive messages from them.'),
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
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to block user: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
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
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
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
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createGroup,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Create',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
            backgroundColor: Colors.green,
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

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  late RealtimeChatService _chatService;
  late FirestoreService _firestoreService;
  late GroupService _groupService;
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _chatService = Provider.of<RealtimeChatService>(context, listen: false);
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
    _groupService = Provider.of<GroupService>(context, listen: false);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showGroupInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getGroupChatMessages(widget.groupId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final isMyMessage = message.senderId == _firestoreService.currentUserId;

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestoreService.getUserById(message.senderId),
                      builder: (context, userSnapshot) {
                        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                        final senderName = userData?['name'] ?? 'Unknown User';
                        final senderAvatar = userData?['avatarUrl'];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: isMyMessage
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            children: [
                              if (!isMyMessage) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: senderAvatar != null
                                      ? NetworkImage(senderAvatar)
                                      : null,
                                  child: senderAvatar == null
                                      ? Text(senderName[0].toUpperCase())
                                      : null,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMyMessage
                                        ? Colors.green
                                        : Colors.grey[300],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMyMessage
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      if (!isMyMessage)
                                        Text(
                                          senderName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      Text(
                                        message.text,
                                        style: TextStyle(
                                          color: isMyMessage
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      Text(
                                        _formatMessageTime(message.timestamp),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMyMessage
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isMyMessage) ...[
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: senderAvatar != null
                                      ? NetworkImage(senderAvatar)
                                      : null,
                                  child: senderAvatar == null
                                      ? Text(senderName[0].toUpperCase())
                                      : null,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(25)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _chatService.sendGroupMessage(widget.groupId, message);
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
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

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.groupName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<DocumentSnapshot>(
              stream: _firestoreService.getGroupById(widget.groupId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final groupData = snapshot.data!.data() as Map<String, dynamic>?;
                if (groupData == null) {
                  return const Center(child: Text('Group not found'));
                }

                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.description),
                      title: const Text('Description'),
                      subtitle: Text(groupData['description'] ?? 'No description'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.people),
                      title: const Text('Members'),
                      subtitle: Text('${groupData['memberCount'] ?? 0}/${groupData['maxMembers'] ?? 10}'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.category),
                      title: const Text('Category'),
                      subtitle: Text(groupData['category'] ?? 'General'),
                    ),
                    if (groupData['skills'] != null && (groupData['skills'] as List).isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.psychology),
                        title: const Text('Skills'),
                        subtitle: Wrap(
                          children: (groupData['skills'] as List)
                              .map((skill) => Chip(label: Text(skill.toString())))
                              .toList(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    
    if (messageDate == today) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
} 