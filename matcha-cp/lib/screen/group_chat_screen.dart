import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../service/realtime_chat_service.dart';
import '../service/firestore_service.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late RealtimeChatService _chatService;
  late FirestoreService _firestoreService;
  
  bool _isTyping = false;
  Timer? _typingTimer;
  Map<String, bool> _typingUsers = {};
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _chatService = Provider.of<RealtimeChatService>(context, listen: false);
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
    _initializeGroupChat();
  }

  Future<void> _initializeGroupChat() async {
    try {
      // Mark all messages as read when opening chat
      await _chatService.markAllMessagesAsRead(widget.groupId, isGroup: true);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing group chat: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.groupName),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.groupName),
            StreamBuilder<Map<String, bool>>(
              stream: _chatService.getTypingStatus(widget.groupId, isGroup: true),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final typingUsers = snapshot.data!;
                  final typingNames = <String>[];
                  
                  typingUsers.forEach((userId, isTyping) {
                    if (isTyping && userId != _firestoreService.currentUserId) {
                      typingNames.add(_userNames[userId] ?? 'Someone');
                    }
                  });
                  
                  if (typingNames.isNotEmpty) {
                    final typingText = typingNames.length == 1 
                        ? '${typingNames.first} is typing...'
                        : '${typingNames.take(2).join(', ')} are typing...';
                    
                    return Text(
                      typingText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: _showGroupInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
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

                _messages = snapshot.data ?? [];
                
                if (_messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        Text(
                          'Start a conversation in the group!',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[_messages.length - 1 - index];
                    final isMe = message.senderId == _firestoreService.currentUserId;
                    
                    return _buildGroupMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          
          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildGroupMessageBubble(ChatMessage message, bool isMe) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestoreService.getUserData(message.senderId),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final senderName = userData?['name'] ?? 'Unknown User';
        final userAvatar = userData?['avatarUrl'];
        
        // Cache user names for typing indicators
        _userNames[message.senderId] = senderName;

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: userAvatar != null ? NetworkImage(userAvatar) : null,
                          child: userAvatar == null
                              ? Text(senderName[0].toUpperCase(), style: const TextStyle(fontSize: 10))
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          senderName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.green : Colors.grey[200],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reply to message (if any)
                      if (message.replyTo != null)
                        _buildReplyPreview(message.replyTo!),
                      
                      // Message text
                      Text(
                        message.text,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black,
                          fontSize: 16,
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Message status and time
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(message.timestamp),
                            style: TextStyle(
                              color: isMe ? Colors.white70 : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            _buildMessageStatus(message),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview(String replyToMessageId) {
    // Find the replied message
    final repliedMessage = _messages.firstWhere(
      (msg) => msg.messageId == replyToMessageId,
      orElse: () => ChatMessage(
        messageId: '',
        senderId: '',
        text: 'Message not found',
        timestamp: DateTime.now(),
        type: 'text',
        status: 'sent',
        readBy: [],
      ),
    );

    return FutureBuilder<DocumentSnapshot>(
      future: _firestoreService.getUserData(repliedMessage.senderId),
      builder: (context, snapshot) {
        final repliedUserName = snapshot.hasData
            ? snapshot.data?.get('name') ?? 'Unknown'
            : 'Unknown';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reply to $repliedUserName',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Text(
                repliedMessage.text,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageStatus(ChatMessage message) {
    if (message.status == 'sent') {
      return const Icon(Icons.check, size: 16, color: Colors.white70);
    } else if (message.status == 'delivered') {
      return const Icon(Icons.done_all, size: 16, color: Colors.white70);
    } else if (message.status == 'read') {
      return const Icon(Icons.done_all, size: 16, color: Colors.blue);
    }
    return const SizedBox.shrink();
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Attachment button
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.grey),
            onPressed: _showAttachmentOptions,
          ),
          
          // Message input field
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                fillColor: Colors.grey[100],
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              maxLines: null,
              onChanged: _onMessageChanged,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Send button
          CircleAvatar(
            backgroundColor: Colors.green,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _onMessageChanged(String text) {
    if (!_isTyping && text.isNotEmpty) {
      _isTyping = true;
      _chatService.setTypingStatus(widget.groupId, true, isGroup: true);
    }
    
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        _chatService.setTypingStatus(widget.groupId, false, isGroup: true);
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _chatService.sendGroupMessage(widget.groupId, _messageController.text.trim());
      _messageController.clear();
      
      // Stop typing indicator
      if (_isTyping) {
        _isTyping = false;
        _chatService.setTypingStatus(widget.groupId, false, isGroup: true);
      }
      
      // Scroll to bottom
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showGroupInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupInfoScreen(groupId: widget.groupId),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image'),
              onTap: () {
                Navigator.pop(context);
                // Handle image attachment
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                // Handle camera
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_copy),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                // Handle document
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    
    if (messageDate == today) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// Group Info Screen
class GroupInfoScreen extends StatelessWidget {
  final String groupId;

  const GroupInfoScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Info'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('groups').doc(groupId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final groupData = snapshot.data!.data() as Map<String, dynamic>?;
          if (groupData == null) {
            return const Center(child: Text('Group not found'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Group avatar and name
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: groupData['avatarUrl'] != null 
                          ? NetworkImage(groupData['avatarUrl'])
                          : null,
                      child: groupData['avatarUrl'] == null
                          ? Text(
                              (groupData['name'] ?? 'G')[0].toUpperCase(),
                              style: const TextStyle(fontSize: 32),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      groupData['name'] ?? 'Unknown Group',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    if (groupData['description'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        groupData['description'],
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Group members
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(groupId)
                    .collection('members')
                    .snapshots(),
                builder: (context, membersSnapshot) {
                  if (!membersSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final members = membersSnapshot.data!.docs;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Members (${members.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ...members.map((memberDoc) {
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(memberDoc.id)
                              .get(),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData) {
                              return const ListTile(
                                leading: CircleAvatar(),
                                title: Text('Loading...'),
                              );
                            }

                            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                            final userName = userData?['name'] ?? 'Unknown User';
                            final isAdmin = groupData['adminId'] == memberDoc.id;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: userData?['avatarUrl'] != null 
                                    ? NetworkImage(userData!['avatarUrl'])
                                    : null,
                                child: userData?['avatarUrl'] == null
                                    ? Text(userName[0].toUpperCase())
                                    : null,
                              ),
                              title: Text(userName),
                              subtitle: isAdmin ? const Text('Admin') : null,
                              trailing: isAdmin 
                                  ? const Icon(Icons.admin_panel_settings, color: Colors.green)
                                  : null,
                            );
                          },
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
} 