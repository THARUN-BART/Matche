import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../service/firestore_service.dart';
import '../group_management_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic> group;

  const GroupChatScreen({super.key, required this.groupId, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final currentUserId = firestoreService.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group['name'],style: TextStyle(color: Color(0xFFFFEC3D),fontWeight: FontWeight.bold),),
        leading: IconButton(onPressed: (){
          Navigator.pop(context);
        }, icon: Icon(Icons.arrow_back_ios)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () => _showGroupInfo(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openGroupManagement(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.groupId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == currentUserId;

                    return _buildGroupMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildGroupMessageBubble(Map<String, dynamic> message, bool isMe) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(message['senderId'])
          .get(),
      builder: (context, snapshot) {
        final senderName = snapshot.hasData
            ? snapshot.data?.get('name') ?? 'Unknown'
            : 'Loading...';

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? Colors.deepPurple : Colors.grey[200],
              borderRadius: BorderRadius.circular(18),
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Text(
                    senderName,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (!isMe) const SizedBox(height: 4),
                Text(
                  message['text'] ?? '',
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(message['timestamp'] as Timestamp?),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),

        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: Colors.white,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Color(0xFFFFEC3D),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.black),
                onPressed: () {
                  if (_messageController.text.isNotEmpty) {
                    FirebaseFirestore.instance
                        .collection('groups')
                        .doc(widget.groupId)
                        .collection('messages')
                        .add({
                      'senderId': firestoreService.currentUserId,
                      'text': _messageController.text,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    _messageController.clear();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupInfo(BuildContext context) {
    final memberIds = (widget.group['members'] as List?) ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.group['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Description: ${widget.group['description']}"),
            const SizedBox(height: 12),
            const Text("Members:"),
            if (memberIds.isEmpty)
              const Text("No members.")
            else
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .where(FieldPath.documentId, whereIn: memberIds)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: CircularProgressIndicator(),
                    );
                  }

                  final members = snapshot.data?.docs ?? [];
                  return Column(
                    children: members.map((doc) {
                      final member = doc.data() as Map<String, dynamic>;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(0xFFFFEC3D),
                          child: Text(member['name'][0],style: TextStyle(color: Colors.black),),
                        ),
                        title: Text(member['name']),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close",style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate();
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _openGroupManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupManagementScreen(
          groupId: widget.groupId,
          group: widget.group,
        ),
      ),
    );
  }
}
