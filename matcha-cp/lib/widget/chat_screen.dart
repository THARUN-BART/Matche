import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'profile_viewer_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String? otherUserId;
  final String? otherUserName;
  
  const ChatScreen({
    super.key, 
    required this.chatId, 
    this.otherUserId,
    this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  bool _showEmojiPicker = false;
  bool _isKeyboardVisible = false;
  
  // Reply functionality
  Map<String, dynamic>? _replyingToMessage;
  final TextEditingController _replyController = TextEditingController();
  
  // User info
  String _otherUserName = 'User';
  bool _isLoadingUser = true;

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      final messageData = {
        'text': message,
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Add reply data if replying to a message
      if (_replyingToMessage != null) {
        messageData['replyTo'] = {
          'messageId': _replyingToMessage!['messageId'],
          'text': _replyingToMessage!['text'],
          'senderId': _replyingToMessage!['senderId'],
        };
      }

      FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add(messageData);

      _messageController.clear();
      _cancelReply();
      
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
    });
    _replyController.clear();
  }

  void _replyToMessage(Map<String, dynamic> message, String messageId) {
    setState(() {
      _replyingToMessage = {
        'messageId': messageId,
        'text': message['text'],
        'senderId': message['senderId'],
      };
    });
    _replyController.text = message['text'];
    FocusScope.of(context).requestFocus(FocusNode());
  }

  bool _canDeleteMessage(Timestamp timestamp) {
    final messageTime = timestamp.toDate();
    final currentTime = DateTime.now();
    final difference = currentTime.difference(messageTime);
    return difference.inMinutes <= 10;
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final currentText = _messageController.text;
    final selection = _messageController.selection;
    final newText = currentText.replaceRange(
      selection.start,
      selection.end,
      emoji.emoji,
    );
    _messageController.text = newText;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: selection.start + emoji.emoji.length),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, String messageId, bool isMe, Timestamp timestamp) {
    final time = timestamp.toDate();
    final timeString = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    final canDelete = isMe && _canDeleteMessage(timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(message, messageId, isMe, canDelete),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: isMe ? Colors.blueAccent : Colors.grey.shade300,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: isMe ? Radius.circular(12) : Radius.zero,
              bottomRight: isMe ? Radius.zero : Radius.circular(12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reply preview if this message is a reply
              if (message['replyTo'] != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Replying to ${message['replyTo']['senderId'] == currentUserId ? 'yourself' : 'message'}',
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.black54,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message['replyTo']['text'],
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.black54,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
              Text(
                message['text'] ?? '',
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeString,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  if (canDelete) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: isMe ? Colors.white70 : Colors.black54,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> message, String messageId, bool isMe, bool canDelete) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _replyToMessage(message, messageId);
              },
            ),
            if (isMe && canDelete)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId);
                },
              ),
            if (isMe && !canDelete)
              ListTile(
                leading: const Icon(Icons.access_time, color: Colors.grey),
                title: const Text('Delete (10 min limit)', style: TextStyle(color: Colors.grey)),
                enabled: false,
              ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadOtherUserInfo();
    // Listen to keyboard visibility changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
      _isKeyboardVisible = keyboardHeight > 0;
    });
  }

  Future<void> _loadOtherUserInfo() async {
    // If other user name is provided, use it
    if (widget.otherUserName != null) {
      setState(() {
        _otherUserName = widget.otherUserName!;
        _isLoadingUser = false;
      });
      return;
    }

    // If other user ID is provided, fetch user info
    if (widget.otherUserId != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.otherUserId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _otherUserName = userData['name'] ?? 'User';
            _isLoadingUser = false;
          });
        } else {
          setState(() {
            _otherUserName = 'User';
            _isLoadingUser = false;
          });
        }
      } catch (e) {
        setState(() {
          _otherUserName = 'User';
          _isLoadingUser = false;
        });
      }
      return;
    }

    // Try to extract user ID from chat ID and fetch user info
    try {
      // Chat ID format: "user1_user2" (sorted alphabetically)
      final chatParts = widget.chatId.split('_');
      if (chatParts.length == 2) {
        final user1Id = chatParts[0];
        final user2Id = chatParts[1];
        
        // Determine which user is not the current user
        String otherUserId;
        if (user1Id == currentUserId) {
          otherUserId = user2Id;
        } else {
          otherUserId = user1Id;
        }
        
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _otherUserName = userData['name'] ?? 'User';
            _isLoadingUser = false;
          });
        } else {
          setState(() {
            _otherUserName = 'User';
            _isLoadingUser = false;
          });
        }
      } else {
        setState(() {
          _otherUserName = 'User';
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      setState(() {
        _otherUserName = 'User';
        _isLoadingUser = false;
      });
    }
  }

  void _showUserOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: Text('View ${_otherUserName}\'s Profile'),
              onTap: () {
                Navigator.pop(context);
                _openUserProfile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Block User', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showBlockUserDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openUserProfile() async {
    if (widget.otherUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load user profile'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Fetch user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();

      if (!userDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileViewScreen(
              user: userData,
              userId: widget.otherUserId!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _makePhoneCall() async {
    if (widget.otherUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get user information'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Fetch user data to get phone number
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();

      if (!userDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final phoneNumber = userData['phone'];

      if (phoneNumber == null || phoneNumber.toString().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Phone number not available for this user'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Format phone number for calling
      String formattedNumber = phoneNumber.toString();
      if (!formattedNumber.startsWith('tel:')) {
        formattedNumber = 'tel:$formattedNumber';
      }

      // Launch phone dialer
      final Uri phoneUri = Uri.parse(formattedNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open phone dialer'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error making call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBlockUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block $_otherUserName? This will:\n\n• Remove your connection\n• Prevent future messages\n• Hide them from your matches'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _blockUser();
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

  Future<void> _blockUser() async {
    try {
      // Extract other user ID from chat ID
      final chatParts = widget.chatId.split('_');
      if (chatParts.length == 2) {
        final user1Id = chatParts[0];
        final user2Id = chatParts[1];
        
        String otherUserId;
        if (user1Id == currentUserId) {
          otherUserId = user2Id;
        } else {
          otherUserId = user1Id;
        }
        
        // Remove connection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('connections')
            .doc(otherUserId)
            .delete();
            
        await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .collection('connections')
            .doc(currentUserId)
            .delete();
        
        // Add to blocked users
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('blockedUsers')
            .doc(otherUserId)
            .set({
          'blockedAt': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$_otherUserName has been blocked'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context); // Go back to previous screen
        }
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
    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp');

    return Scaffold(
      appBar: AppBar(
        title: _isLoadingUser
            ? const Text("Loading...")
            : Text(_otherUserName, style: GoogleFonts.salsa()),
        actions: [
          IconButton(
            onPressed: () => _makePhoneCall(),
            icon: const Icon(Icons.call),
            tooltip: 'Call',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showUserOptions();
            },
          ),

        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messagesRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading messages"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == currentUserId;
                    return _buildMessageBubble(
                      msg,
                      messages[index].id,
                      isMe,
                      msg['timestamp'] ?? Timestamp.now(),
                    );
                  },
                );
              },
            ),
          ),

          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: _onEmojiSelected,
                config: Config(
                  height: 250,
                  emojiViewConfig: EmojiViewConfig(
                    emojiSizeMax: 28 * (defaultTargetPlatform == TargetPlatform.iOS ? 1.20 : 1.0),
                    verticalSpacing: 0,
                    horizontalSpacing: 0,
                    gridPadding: EdgeInsets.zero,
                    recentsLimit: 28,
                    replaceEmojiOnLimitExceed: false,
                    noRecents: const Text(
                      'No Recents',
                      style: TextStyle(fontSize: 20, color: Colors.black26),
                      textAlign: TextAlign.center,
                    ),
                    loadingIndicator: const SizedBox.shrink(),
                    buttonMode: ButtonMode.MATERIAL,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: Colors.white,
                    hintText: "Search emoji...",
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: Colors.white,
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor: Colors.white,
                    showSearchViewButton: true,
                  ),
                  skinToneConfig: const SkinToneConfig(),
                ),
              ),
            ),

          // Reply preview
          if (_replyingToMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${_replyingToMessage!['senderId'] == currentUserId ? 'yourself' : 'message'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyingToMessage!['text'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _cancelReply,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(

                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                      color: _showEmojiPicker ? Colors.blue : Colors.orange,
                    ),
                    onPressed: () {
                      setState(() {
                        _showEmojiPicker = !_showEmojiPicker;
                      });
                      // Hide keyboard when emoji picker is shown
                      if (_showEmojiPicker) {
                        FocusScope.of(context).unfocus();
                      }
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "Type your message...",
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      onTap: () {

                        if (_showEmojiPicker) {
                          setState(() {
                            _showEmojiPicker = false;
                          });
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: Colors.blue),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}