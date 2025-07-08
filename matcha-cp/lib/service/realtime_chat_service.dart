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

  // Get current user ID
  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Create or get individual chat room
  Future<String> createOrGetChatRoom(String otherUserId) async {
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
  }

  // Send individual message
  Future<void> sendMessage(String chatId, String message, {String? replyTo}) async {
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
  }

  // Send group message
  Future<void> sendGroupMessage(String groupId, String message, {String? replyTo}) async {
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
  }

  // Get real-time messages for individual chat
  Stream<List<ChatMessage>> getChatMessages(String chatId) {
    if (!_chatControllers.containsKey(chatId)) {
      _chatControllers[chatId] = StreamController<List<ChatMessage>>.broadcast();
      
      _database.ref('messages/$chatId')
          .orderByChild('timestamp')
          .onValue
          .listen((event) {
        if (event.snapshot.exists) {
          final messages = <ChatMessage>[];
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          
          data.forEach((key, value) {
            final messageData = value as Map<dynamic, dynamic>;
            messages.add(ChatMessage.fromMap(Map<String, dynamic>.from(messageData)));
          });
          
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          _chatControllers[chatId]!.add(messages);
        } else {
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
        if (event.snapshot.exists) {
          final messages = <ChatMessage>[];
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          
          data.forEach((key, value) {
            final messageData = value as Map<dynamic, dynamic>;
            messages.add(ChatMessage.fromMap(Map<String, dynamic>.from(messageData)));
          });
          
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          _groupChatControllers[groupId]!.add(messages);
        } else {
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
      if (event.snapshot.exists) {
        final chatRooms = <ChatRoom>[];
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        
        data.forEach((key, value) {
          final chatRoomData = value as Map<dynamic, dynamic>;
          final participants = List<String>.from(chatRoomData['participants'] ?? []);
          
          // Only include chat rooms where current user is a participant
          if (participants.contains(currentUserId)) {
            chatRooms.add(ChatRoom.fromMap(Map<String, dynamic>.from(chatRoomData)));
          }
        });
        
        chatRooms.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _chatRoomsController.add(chatRooms);
      } else {
        _chatRoomsController.add([]);
      }
    });
    
    return _chatRoomsController.stream;
  }

  // Mark message as read
  Future<void> markMessageAsRead(String chatId, String messageId, {bool isGroup = false}) async {
    final messageRef = isGroup 
        ? _database.ref('groupMessages/$chatId/$messageId')
        : _database.ref('messages/$chatId/$messageId');
    
    await messageRef.child('readBy/$currentUserId').set(ServerValue.timestamp);
    
    // Update message status to 'read'
    await messageRef.child('status').set('read');
    
    // Reset unread count for this chat
    await _resetUnreadCount(chatId, isGroup);
  }

  // Mark all messages as read in a chat
  Future<void> markAllMessagesAsRead(String chatId, {bool isGroup = false}) async {
    final messagesRef = isGroup 
        ? _database.ref('groupMessages/$chatId')
        : _database.ref('messages/$chatId');
    
    final snapshot = await messagesRef.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      
      for (String messageId in data.keys) {
        await markMessageAsRead(chatId, messageId, isGroup: isGroup);
      }
    }
  }

  // Update typing status
  Future<void> setTypingStatus(String chatId, bool isTyping, {bool isGroup = false}) async {
    final typingRef = isGroup 
        ? _database.ref('groupTyping/$chatId/$currentUserId')
        : _database.ref('typing/$chatId/$currentUserId');
    
    if (isTyping) {
      await typingRef.set({
        'isTyping': true,
        'timestamp': ServerValue.timestamp,
      });
    } else {
      await typingRef.remove();
    }
  }

  // Get typing status
  Stream<Map<String, bool>> getTypingStatus(String chatId, {bool isGroup = false}) {
    final typingRef = isGroup 
        ? _database.ref('groupTyping/$chatId')
        : _database.ref('typing/$chatId');
    
    return typingRef.onValue.map((event) {
      final typingUsers = <String, bool>{};
      
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final typingData = value as Map<dynamic, dynamic>;
          if (key != currentUserId) { // Don't show own typing status
            typingUsers[key.toString()] = typingData['isTyping'] ?? false;
          }
        });
      }
      
      return typingUsers;
    });
  }

  // Delete message
  Future<void> deleteMessage(String chatId, String messageId, {bool isGroup = false}) async {
    final messageRef = isGroup 
        ? _database.ref('groupMessages/$chatId/$messageId')
        : _database.ref('messages/$chatId/$messageId');
    
    final snapshot = await messageRef.get();
    if (snapshot.exists) {
      final messageData = snapshot.value as Map<dynamic, dynamic>;
      
      // Only allow sender to delete message
      if (messageData['senderId'] == currentUserId) {
        await messageRef.remove();
      }
    }
  }

  // Reply to message
  Future<void> replyToMessage(String chatId, String messageId, String replyText, {bool isGroup = false}) async {
    await sendMessage(chatId, replyText, replyTo: messageId);
  }

  // Update unread count
  Future<void> _updateUnreadCount(String chatId, String senderId) async {
    final chatRoomRef = _database.ref('chatRooms/$chatId');
    final snapshot = await chatRoomRef.get();
    
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
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

  // Reset unread count
  Future<void> _resetUnreadCount(String chatId, bool isGroup) async {
    final chatRoomRef = isGroup 
        ? _database.ref('groupChatRooms/$chatId')
        : _database.ref('chatRooms/$chatId');
    
    await chatRoomRef.child('unreadCount/$currentUserId').set(0);
  }

  // Send message notification
  Future<void> _sendMessageNotification(String chatId, String message) async {
    final chatRoomRef = _database.ref('chatRooms/$chatId');
    final snapshot = await chatRoomRef.get();
    
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
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
            'title': senderName,
            'body': message,
            'type': 'message',
            'chatId': chatId,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
      }
    }
  }

  // Send group message notification
  Future<void> _sendGroupMessageNotification(String groupId, String message) async {
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
          'body': message,
          'type': 'group_message',
          'groupId': groupId,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    }
  }

  // Generate chat ID
  String _generateChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  // Dispose resources
  void dispose() {
    for (var controller in _chatControllers.values) {
      controller.close();
    }
    for (var controller in _groupChatControllers.values) {
      controller.close();
    }
    _chatRoomsController.close();
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