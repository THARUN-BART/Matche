import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../service/firestore_service.dart';
import '../../widget/chat_screen.dart';
import '../../widget/connection_card.dart';
import '../../widget/profile_viewer_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Set<String> _connectedUserIds = {};
  Set<String> _sentRequestUserIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchConnectionsAndRequests();
  }

  Future<void> _fetchConnectionsAndRequests() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    // Listen to connections
    firestoreService.getUserConnections().listen((snapshot) {
      setState(() {
        _connectedUserIds = snapshot.docs.map((doc) => doc.id).toSet();
      });
    });

    // Listen to sent requests
    firestoreService.getSentConnectionRequests().listen((snapshot) {
      setState(() {
        _sentRequestUserIds = snapshot.docs.map((doc) => doc.id).toSet();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Matches'),
            Tab(text: 'Suggestions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMatchesTab(),
          _buildSuggestionsTab(),
        ],
      ),
    );
  }

  /// Builds the "Matches" tab
  Widget _buildMatchesTab() {
    final firestoreService = Provider.of<FirestoreService>(context);

    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.getUserConnections(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final connections = snapshot.data?.docs ?? [];

        if (connections.isEmpty) {
          return const Center(child: Text('No matches yet'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: connections.length,
          itemBuilder: (context, index) {
            final connectionId = connections[index].id;
            return FutureBuilder<DocumentSnapshot>(
              future: firestoreService.getUserById(connectionId),
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

                return ConnectionCard(
                  user: user,
                  isConnected: true,
                  onTap: () => _openProfile(context, user, connectionId.toString()),
                  onMessage: () => _openChat(context, connectionId.toString()),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Builds the "Suggestions" tab
  Widget _buildSuggestionsTab() {
    final firestoreService = Provider.of<FirestoreService>(context);

    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.getSuggestedConnections(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final suggestions = snapshot.data?.docs ?? [];

        if (suggestions.isEmpty) {
          return const Center(child: Text('No suggestions available'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestionId = suggestions[index].id;

            // Skip if user is already connected or is the current user
            if (_connectedUserIds.contains(suggestionId) || suggestionId == firestoreService.currentUserId) {
              return const SizedBox.shrink();
            }

            return FutureBuilder<DocumentSnapshot>(
              future: firestoreService.getUserById(suggestionId),
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

                final hasSentRequest = _sentRequestUserIds.contains(suggestionId);

                return ConnectionCard(
                  user: user,
                  isConnected: false,
                  hasSentRequest: hasSentRequest,
                  onTap: () => _openProfile(context, user, suggestionId.toString()),
                  onConnect: hasSentRequest
                      ? null
                      : () => _sendConnectionRequest(context, suggestionId.toString()),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Opens profile view screen
  void _openProfile(BuildContext context, Map<String, dynamic> user, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileViewScreen(
          user: user, 
          userId: userId.toString(),
        ),
      ),
    );
  }

  /// Opens chat screen
  void _openChat(BuildContext context, String userId) {
    final currentUserId = Provider.of<FirestoreService>(context, listen: false).currentUserId;
    final chatId = _generateChatId(currentUserId, userId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(chatId: chatId),
      ),
    );
  }

  /// Generates consistent chat ID between two users
  String _generateChatId(String user1, String user2) {
    final sortedIds = [user1, user2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  /// Sends a connection request
  Future<void> _sendConnectionRequest(BuildContext context, String recipientId) async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final currentUserId = firestoreService.currentUserId;

    try {
      await firestoreService.sendConnectionRequest(currentUserId, recipientId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection request sent')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $e')),
      );
    }
  }
}
