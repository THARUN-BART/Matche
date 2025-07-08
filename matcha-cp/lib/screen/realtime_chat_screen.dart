import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../service/realtime_chat_service.dart';
import '../service/firestore_service.dart';

class RealtimeChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? chatId;

  const RealtimeChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.chatId,
  });

  @override
  State<RealtimeChatScreen> createState() => _RealtimeChatScreenState();
}

class _RealtimeChatScreenState extends State<RealtimeChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late RealtimeChatService _chatService;
  late FirestoreService _firestoreService;
  
  String? _currentChatId;
  bool _isTyping = false;
  Timer? _typingTimer;
  Map<String, bool> _typingUsers = {};
  List<ChatMessage> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService = Provider.of<RealtimeChatService>(context, listen: false);
      _firestoreService = Provider.of<FirestoreService>(context, listen: false);
      _initializeChat();
    });
  }

  Future<void> _initializeChat() async {
    try {
      // Get or create chat room
      _currentChatId = widget.chatId ?? await _chatService.createOrGetChatRoom(widget.otherUserId);
      
      // Mark all messages as read when opening chat
      await _chatService.markAllMessagesAsRead(_currentChatId!);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing chat: $e');
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
          title: Text(widget.otherUserName),
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
            Text(widget.otherUserName),
            StreamBuilder<Map<String, bool>>(
              stream: _chatService.getTypingStatus(_currentChatId!),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return Text(
                    'typing...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  );
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
            icon: const Icon(Icons.more_vert),
            onPressed: _showChatOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getChatMessages(_currentChatId!),
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
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        Text(
                          'Start a conversation!',
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
                    
                    return _buildMessageBubble(message, isMe);
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

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestoreService.getUserData(message.senderId),
      builder: (context, snapshot) {
        final senderName = snapshot.hasData
            ? snapshot.data?.get('name') ?? 'Unknown'
            : 'Loading...';

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
                    child: Text(
                      senderName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
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
            'Reply to ${repliedMessage.senderId == _firestoreService.currentUserId ? 'you' : 'message'}',
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
      _chatService.setTypingStatus(_currentChatId!, true);
    }
    
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        _chatService.setTypingStatus(_currentChatId!, false);
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _chatService.sendMessage(_currentChatId!, _messageController.text.trim());
      _messageController.clear();
      
      // Stop typing indicator
      if (_isTyping) {
        _isTyping = false;
        _chatService.setTypingStatus(_currentChatId!, false);
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

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Block User'),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Clear Chat'),
              onTap: () {
                Navigator.pop(context);
                _showClearChatConfirmation();
              },
            ),
          ],
        ),
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

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block ${widget.otherUserName}?'),
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
                SnackBar(content: Text('${widget.otherUserName} has been blocked')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showClearChatConfirmation() {
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