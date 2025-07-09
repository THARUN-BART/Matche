import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RealtimeChatService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Stream controllers for real-time updates
  final Map<String, StreamController<List<ChatMessage>>> _chatControllers = {};
  final Map<String, StreamController<List<ChatMessage>>> _groupChatControllers = {};
  final StreamController<List<ChatRoom>> _chatRoomsController = StreamController<List<ChatRoom>>.broadcast();
  final Map<String, StreamController<Map<String, TypingStatus>>> _typingControllers = {};
  final Map<String, StreamController<Map<String, bool>>> _onlineStatusControllers = {};

  // Get current user ID
  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Create or get individual chat room
  Future<String> createOrGetChatRoom(String otherUserId) async {
    try {
      final chatId = _generateChatId(currentUserId, otherUserId);
      
      // Check if chat room exists
      final chatRoomRef = _database.ref('chatRooms/$chatId');
      final snapshot = await chatRoomRef.get();
      
      if (!snapshot.exists) {
        // Create new chat room
        await chatRoomRef.set({
          'chatId': chatId,
          'type': 'individual',
          'participants': [currentUserId, otherUserId],
          'lastMessage': '',
          'lastMessageTime': ServerValue.timestamp,
          'lastMessageSender': '',
          'unreadCount': {
            currentUserId: 0,
            otherUserId: 0,
          },
          'createdAt': ServerValue.timestamp,
          'updatedAt': ServerValue.timestamp,
        });
      }
      
      return chatId;
    } catch (e) {
      print('Error creating/getting chat room: $e');
      rethrow;
    }
  }

  // Send individual message
  Future<void> sendMessage(String chatId, String message, {String? replyTo}) async {
    try {
      final messageId = _database.ref('messages/$chatId').push().key!;
      final timestamp = ServerValue.timestamp;
      
      final messageData = {
        'messageId': messageId,
        'senderId': currentUserId,
        'text': message,
        'timestamp': timestamp,
        'type': 'text',
        'status': 'sent',
        'replyTo': replyTo,
        'readBy': [currentUserId],
      };

      // Add message to messages node
      await _database.ref('messages/$chatId/$messageId').set(messageData);
      
      // Update chat room
      await _database.ref('chatRooms/$chatId').update({
        'lastMessage': message,
        'lastMessageTime': timestamp,
        'lastMessageSender': currentUserId,
        'updatedAt': timestamp,
      });

      // Update unread count for other participants
      await _updateUnreadCount(chatId, currentUserId);
      
      // Send push notification to other user
      await _sendMessageNotification(chatId, message);
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Send group message
  Future<void> sendGroupMessage(String groupId, String message, {String? replyTo}) async {
    try {
      final messageId = _database.ref('groupMessages/$groupId').push().key!;
      final timestamp = ServerValue.timestamp;
      
      final messageData = {
        'messageId': messageId,
        'senderId': currentUserId,
        'text': message,
        'timestamp': timestamp,
        'type': 'text',
        'status': 'sent',
        'replyTo': replyTo,
        'readBy': [currentUserId],
      };

      // Add message to group messages node
      await _database.ref('groupMessages/$groupId/$messageId').set(messageData);
      
      // Update group chat room
      await _database.ref('groupChatRooms/$groupId').update({
        'lastMessage': message,
        'lastMessageTime': timestamp,
        'lastMessageSender': currentUserId,
        'updatedAt': timestamp,
      });

      // Send push notification to group members
      await _sendGroupMessageNotification(groupId, message);
    } catch (e) {
      print('Error sending group message: $e');
      rethrow;
    }
  }

  // Get real-time messages for individual chat
  Stream<List<ChatMessage>> getChatMessages(String chatId) {
    if (!_chatControllers.containsKey(chatId)) {
      _chatControllers[chatId] = StreamController<List<ChatMessage>>.broadcast();
      
      _database.ref('messages/$chatId')
          .orderByChild('timestamp')
          .onValue
          .listen((event) {
        try {
          if (event.snapshot.exists) {
            final messages = <ChatMessage>[];
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            
            if (data != null) {
              data.forEach((key, value) {
                try {
                  final messageData = value as Map<dynamic, dynamic>;
                  messages.add(ChatMessage.fromMap(Map<String, dynamic>.from(messageData)));
                } catch (e) {
                  print('Error parsing message $key: $e');
                }
              });
            }
            
            messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            _chatControllers[chatId]!.add(messages);
          } else {
            _chatControllers[chatId]!.add([]);
          }
        } catch (e) {
          print('Error in chat messages stream: $e');
          _chatControllers[chatId]!.add([]);
        }
      });
    }
    
    return _chatControllers[chatId]!.stream;
  }

  // Get real-time messages for group chat
  Stream<List<ChatMessage>> getGroupChatMessages(String groupId) {
    if (!_groupChatControllers.containsKey(groupId)) {
      _groupChatControllers[groupId] = StreamController<List<ChatMessage>>.broadcast();
      
      _database.ref('groupMessages/$groupId')
          .orderByChild('timestamp')
          .onValue
          .listen((event) {
        try {
          if (event.snapshot.exists) {
            final messages = <ChatMessage>[];
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            
            if (data != null) {
              data.forEach((key, value) {
                try {
                  final messageData = value as Map<dynamic, dynamic>;
                  messages.add(ChatMessage.fromMap(Map<String, dynamic>.from(messageData)));
                } catch (e) {
                  print('Error parsing group message $key: $e');
                }
              });
            }
            
            messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            _groupChatControllers[groupId]!.add(messages);
          } else {
            _groupChatControllers[groupId]!.add([]);
          }
        } catch (e) {
          print('Error in group chat messages stream: $e');
          _groupChatControllers[groupId]!.add([]);
        }
      });
    }
    
    return _groupChatControllers[groupId]!.stream;
  }

  // Get real-time chat rooms
  Stream<List<ChatRoom>> getChatRooms() {
    _database.ref('chatRooms')
        .orderByChild('updatedAt')
        .onValue
        .listen((event) {
      try {
        if (event.snapshot.exists) {
          final chatRooms = <ChatRoom>[];
          final data = event.snapshot.value as Map<dynamic, dynamic>?;
          
          if (data != null) {
            data.forEach((key, value) {
              try {
                final chatRoomData = value as Map<dynamic, dynamic>;
                final participants = List<String>.from(chatRoomData['participants'] ?? []);
                
                // Only include chat rooms where current user is a participant
                if (participants.contains(currentUserId)) {
                  chatRooms.add(ChatRoom.fromMap(Map<String, dynamic>.from(chatRoomData)));
                }
              } catch (e) {
                print('Error parsing chat room $key: $e');
              }
            });
          }
          
          chatRooms.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          _chatRoomsController.add(chatRooms);
        } else {
          _chatRoomsController.add([]);
        }
      } catch (e) {
        print('Error in chat rooms stream: $e');
        _chatRoomsController.add([]);
      }
    });
    
    return _chatRoomsController.stream;
  }

  // Enhanced typing status with 3 dots animation
  Future<void> setTypingStatus(String chatId, bool isTyping, {bool isGroup = false}) async {
    try {
      final typingRef = isGroup 
          ? _database.ref('groupTyping/$chatId/$currentUserId')
          : _database.ref('typing/$chatId/$currentUserId');
      
      if (isTyping) {
        await typingRef.set({
          'isTyping': true,
          'timestamp': ServerValue.timestamp,
          'startTime': ServerValue.timestamp,
        });
      } else {
        await typingRef.remove();
      }
    } catch (e) {
      print('Error setting typing status: $e');
      rethrow;
    }
  }

  // Get enhanced typing status with 3 dots animation
  Stream<Map<String, TypingStatus>> getTypingStatus(String chatId, {bool isGroup = false}) {
    if (!_typingControllers.containsKey(chatId)) {
      _typingControllers[chatId] = StreamController<Map<String, TypingStatus>>.broadcast();
      
      final typingRef = isGroup 
          ? _database.ref('groupTyping/$chatId')
          : _database.ref('typing/$chatId');
      
      typingRef.onValue.listen((event) {
        try {
          final typingUsers = <String, TypingStatus>{};
          
          if (event.snapshot.exists) {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data != null) {
              data.forEach((key, value) {
                try {
                  final typingData = value as Map<dynamic, dynamic>;
                  if (key != currentUserId) { // Don't show own typing status
                    final startTime = typingData['startTime'] ?? 0;
                    final timestamp = typingData['timestamp'] ?? 0;
                    typingUsers[key.toString()] = TypingStatus(
                      isTyping: typingData['isTyping'] ?? false,
                      startTime: DateTime.fromMillisecondsSinceEpoch(startTime),
                      lastUpdate: DateTime.fromMillisecondsSinceEpoch(timestamp),
                    );
                  }
                } catch (e) {
                  print('Error parsing typing data for $key: $e');
                }
              });
            }
          }
          
          _typingControllers[chatId]!.add(typingUsers);
        } catch (e) {
          print('Error in typing status stream: $e');
          _typingControllers[chatId]!.add({});
        }
      });
    }
    
    return _typingControllers[chatId]!.stream;
  }

  // Set user online status
  Future<void> setOnlineStatus(bool isOnline) async {
    try {
      final userRef = _database.ref('onlineStatus/$currentUserId');
      
      if (isOnline) {
        await userRef.set({
          'isOnline': true,
          'lastSeen': ServerValue.timestamp,
          'timestamp': ServerValue.timestamp,
        });
      } else {
        await userRef.update({
          'isOnline': false,
          'lastSeen': ServerValue.timestamp,
        });
      }
    } catch (e) {
      print('Error setting online status: $e');
      rethrow;
    }
  }

  // Get online status for a specific user
  Stream<bool> getUserOnlineStatus(String userId) {
    return _database.ref('onlineStatus/$userId/isOnline')
        .onValue
        .map((event) {
      try {
        return event.snapshot.value as bool? ?? false;
      } catch (e) {
        print('Error getting online status: $e');
        return false;
      }
    });
  }

  // Get online status for multiple users (for chat list)
  Stream<Map<String, bool>> getUsersOnlineStatus(List<String> userIds) {
    if (!_onlineStatusControllers.containsKey('multiple')) {
      _onlineStatusControllers['multiple'] = StreamController<Map<String, bool>>.broadcast();
      
      // Maintain a local cache for online statuses
      final Map<String, bool> currentStatus = {};
      for (String userId in userIds) {
        _database.ref('onlineStatus/$userId/isOnline')
            .onValue
            .listen((event) {
          try {
            currentStatus[userId] = event.snapshot.value as bool? ?? false;
            _onlineStatusControllers['multiple']!.add(Map<String, bool>.from(currentStatus));
          } catch (e) {
            print('Error updating online status for $userId: $e');
          }
        });
      }
    }
    
    return _onlineStatusControllers['multiple']!.stream;
  }

  // Mark message as read
  Future<void> markMessageAsRead(String chatId, String messageId, {bool isGroup = false}) async {
    try {
      final messageRef = isGroup 
          ? _database.ref('groupMessages/$chatId/$messageId')
          : _database.ref('messages/$chatId/$messageId');
      
      await messageRef.child('readBy/$currentUserId').set(ServerValue.timestamp);
      
      // Update message status to 'read'
      await messageRef.child('status').set('read');
      
      // Reset unread count for this chat
      await _resetUnreadCount(chatId, isGroup);
    } catch (e) {
      print('Error marking message as read: $e');
      rethrow;
    }
  }

  // Mark all messages as read in a chat
  Future<void> markAllMessagesAsRead(String chatId, {bool isGroup = false}) async {
    try {
      final messagesRef = isGroup 
          ? _database.ref('groupMessages/$chatId')
          : _database.ref('messages/$chatId');
      
      final snapshot = await messagesRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          for (String messageId in data.keys) {
            await markMessageAsRead(chatId, messageId, isGroup: isGroup);
          }
        }
      }
    } catch (e) {
      print('Error marking all messages as read: $e');
      rethrow;
    }
  }

  // Delete message
  Future<void> deleteMessage(String chatId, String messageId, {bool isGroup = false}) async {
    try {
      final messageRef = isGroup 
          ? _database.ref('groupMessages/$chatId/$messageId')
          : _database.ref('messages/$chatId/$messageId');
      
      final snapshot = await messageRef.get();
      if (snapshot.exists) {
        final messageData = snapshot.value as Map<dynamic, dynamic>?;
        if (messageData != null) {
          // Only allow sender to delete message
          if (messageData['senderId'] == currentUserId) {
            await messageRef.remove();
          }
        }
      }
    } catch (e) {
      print('Error deleting message: $e');
      rethrow;
    }
  }

  // Reply to message
  Future<void> replyToMessage(String chatId, String messageId, String replyText, {bool isGroup = false}) async {
    await sendMessage(chatId, replyText, replyTo: messageId);
  }

  // Update unread count
  Future<void> _updateUnreadCount(String chatId, String senderId) async {
    try {
      final chatRoomRef = _database.ref('chatRooms/$chatId');
      final snapshot = await chatRoomRef.get();
      
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          final participants = List<String>.from(data['participants'] ?? []);
          
          for (String participantId in participants) {
            if (participantId != senderId) {
              await chatRoomRef.child('unreadCount/$participantId').set(
                ServerValue.increment(1)
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error updating unread count: $e');
      rethrow;
    }
  }

  // Reset unread count
  Future<void> _resetUnreadCount(String chatId, bool isGroup) async {
    try {
      final chatRoomRef = isGroup 
          ? _database.ref('groupChatRooms/$chatId')
          : _database.ref('chatRooms/$chatId');
      
      await chatRoomRef.child('unreadCount/$currentUserId').set(0);
    } catch (e) {
      print('Error resetting unread count: $e');
      rethrow;
    }
  }

  // Send message notification
  Future<void> _sendMessageNotification(String chatId, String message) async {
    try {
      final chatRoomRef = _database.ref('chatRooms/$chatId');
      final snapshot = await chatRoomRef.get();
      
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          final participants = List<String>.from(data['participants'] ?? []);
          
          for (String participantId in participants) {
            if (participantId != currentUserId) {
              // Get sender info
              final userDoc = await _firestore.collection('users').doc(currentUserId).get();
              final senderName = userDoc.data()?['name'] ?? 'Unknown';
              
              // Create notification
              await _firestore.collection('notifications').add({
                'to': participantId,
                'from': currentUserId,
                'title': 'New Message from $senderName',
                'body': message.length > 50 ? '${message.substring(0, 50)}...' : message,
                'type': 'message',
                'chatId': chatId,
                'timestamp': FieldValue.serverTimestamp(),
                'read': false,
                'data': {
                  'chatId': chatId,
                  'senderId': currentUserId,
                  'senderName': senderName,
                },
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error sending message notification: $e');
      // Don't rethrow as notification failure shouldn't break the chat
    }
  }

  // Send group message notification
  Future<void> _sendGroupMessageNotification(String groupId, String message) async {
    try {
      // Get group members
      final groupMembersRef = _firestore.collection('groups').doc(groupId).collection('members');
      final membersSnapshot = await groupMembersRef.get();
      
      for (var memberDoc in membersSnapshot.docs) {
        final memberId = memberDoc.id;
        if (memberId != currentUserId) {
          // Get sender and group info
          final userDoc = await _firestore.collection('users').doc(currentUserId).get();
          final groupDoc = await _firestore.collection('groups').doc(groupId).get();
          
          final senderName = userDoc.data()?['name'] ?? 'Unknown';
          final groupName = groupDoc.data()?['name'] ?? 'Group';
          
          // Create notification
          await _firestore.collection('notifications').add({
            'to': memberId,
            'from': currentUserId,
            'title': '$senderName in $groupName',
            'body': message.length > 50 ? '${message.substring(0, 50)}...' : message,
            'type': 'group_message',
            'groupId': groupId,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'data': {
              'groupId': groupId,
              'senderId': currentUserId,
              'senderName': senderName,
              'groupName': groupName,
            },
          });
        }
      }
    } catch (e) {
      print('Error sending group message notification: $e');
      // Don't rethrow as notification failure shouldn't break the chat
    }
  }

  // Generate chat ID
  String _generateChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  // Clear chat messages
  Future<void> clearChat(String chatId) async {
    try {
      // Delete all messages in the chat
      await _database.ref('messages/$chatId').remove();
      
      // Reset chat room
      await _database.ref('chatRooms/$chatId').update({
        'lastMessage': '',
        'lastMessageTime': ServerValue.timestamp,
        'lastMessageSender': '',
        'unreadCount': {
          currentUserId: 0,
        },
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error clearing chat: $e');
      rethrow;
    }
  }

  // Dispose resources
  void dispose() {
    for (var controller in _chatControllers.values) {
      controller.close();
    }
    for (var controller in _groupChatControllers.values) {
      controller.close();
    }
    for (var controller in _typingControllers.values) {
      controller.close();
    }
    for (var controller in _onlineStatusControllers.values) {
      controller.close();
    }
    _chatRoomsController.close();
  }
}

// Enhanced Typing Status Model
class TypingStatus {
  final bool isTyping;
  final DateTime startTime;
  final DateTime lastUpdate;

  TypingStatus({
    required this.isTyping,
    required this.startTime,
    required this.lastUpdate,
  });

  bool get shouldShowTyping {
    if (!isTyping) return false;
    // Show typing for 10 seconds after last update
    return DateTime.now().difference(lastUpdate).inSeconds < 10;
  }
}

// Chat Message Model
class ChatMessage {
  final String messageId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final String type;
  final String status;
  final String? replyTo;
  final List<String> readBy;

  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.type,
    required this.status,
    this.replyTo,
    required this.readBy,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      type: map['type'] ?? 'text',
      status: map['status'] ?? 'sent',
      replyTo: map['replyTo'],
      readBy: List<String>.from(map['readBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'type': type,
      'status': status,
      'replyTo': replyTo,
      'readBy': readBy,
    };
  }
}

// Chat Room Model
class ChatRoom {
  final String chatId;
  final String type;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastMessageSender;
  final Map<String, int> unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatRoom({
    required this.chatId,
    required this.type,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSender,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatRoom.fromMap(Map<String, dynamic> map) {
    return ChatRoom(
      chatId: map['chatId'] ?? '',
      type: map['type'] ?? 'individual',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: DateTime.fromMillisecondsSinceEpoch(map['lastMessageTime'] ?? 0),
      lastMessageSender: map['lastMessageSender'] ?? '',
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'type': type,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.millisecondsSinceEpoch,
      'lastMessageSender': lastMessageSender,
      'unreadCount': unreadCount,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }
} 