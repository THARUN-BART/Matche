import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String get currentUserId {
    return _auth.currentUser?.uid ?? '';
  }

  /// Get current user data
  Future<DocumentSnapshot> getCurrentUserData() {
    return _firestore.collection('users').doc(currentUserId).get();
  }

  /// Get user data by ID
  Future<DocumentSnapshot> getUserData(String userId) {
    return _firestore.collection('users').doc(userId).get();
  }

  /// Get user by ID
  Future<DocumentSnapshot> getUserById(String userId) {
    return _firestore.collection('users').doc(userId).get();
  }

  /// Get all users except current user
  Stream<QuerySnapshot> getAllUsersExceptCurrent() {
    return _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .snapshots();
  }

  /// Get user connections (matches)
  Stream<QuerySnapshot> getUserConnections() {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('connections')
        .snapshots();
  }

  /// Add mutual connection
  Future<void> addConnection(String targetUserId) async {
    final batch = _firestore.batch();

    batch.set(
      _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('connections')
          .doc(targetUserId),
      {'timestamp': FieldValue.serverTimestamp()},
    );

    batch.set(
      _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('connections')
          .doc(currentUserId),
      {'timestamp': FieldValue.serverTimestamp()},
    );

    await batch.commit();

    // Notify the sender that the request was accepted
    await sendConnectionAcceptedNotification(currentUserId, targetUserId);
  }

  /// Create a group
  Future<void> createGroup(String name, String description) async {
    await _firestore.collection('groups').add({
      'name': name,
      'description': description,
      'members': [currentUserId],
      'admin': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get groups the user is in
  Stream<QuerySnapshot> getUserGroups() {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .snapshots();
  }

  /// Send a message in chat
  Future<void> sendMessage(String chatId, String text) async {
    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUserId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Get messages for a chat
  Stream<QuerySnapshot> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Suggest connections (for now: all except current user)
  Stream<QuerySnapshot> getSuggestedConnections() {
    return _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .snapshots();
  }

  /// Send a connection request
  Future<void> sendConnectionRequest(String fromId, String toId) async {
    // Prevent re-sending if already sent
    final sentSnapshot = await _firestore
        .collection('users')
        .doc(fromId)
        .collection('sentRequests')
        .doc(toId)
        .get();

    if (sentSnapshot.exists) return;

    // Add to global connectionRequests
    await _firestore.collection('connectionRequests').add({
      'from': fromId,
      'to': toId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Track sent request in sender's record
    await _firestore
        .collection('users')
        .doc(fromId)
        .collection('sentRequests')
        .doc(toId)
        .set({'timestamp': FieldValue.serverTimestamp()});
  }

  /// Get sent connection requests
  Stream<QuerySnapshot> getSentConnectionRequests() {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('sentRequests')
        .snapshots();
  }

  /// Get received connection requests
  Stream<QuerySnapshot> getReceivedConnectionRequests() {
    return _firestore
        .collection('connectionRequests')
        .where('to', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Accept a connection request
  Future<void> acceptConnectionRequest(String requestId, String fromUserId) async {
    // Add mutual connection
    await addConnection(fromUserId);

    // Update the request status
    await _firestore.collection('connectionRequests').doc(requestId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reject a connection request
  Future<void> rejectConnectionRequest(String requestId) async {
    await _firestore.collection('connectionRequests').doc(requestId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Send a notification when a connection is accepted
  Future<void> sendConnectionAcceptedNotification(String fromUserId, String toUserId) async {
    await _firestore.collection('notifications').add({
      'type': 'connection_accepted',
      'from': fromUserId,
      'to': toUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  /// Get unread notifications for current user
  Stream<QuerySnapshot> getUnreadNotifications() {
    return _firestore
        .collection('notifications')
        .where('to', isEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'read': true,
    });
  }

  /// Get user's friends (connections)
  Stream<QuerySnapshot> getFriends() {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('connections')
        .snapshots();
  }

  /// Invite a friend to a group
  Future<void> inviteFriendToGroup(String groupId, String friendUserId) async {
    // Check if friendUserId is a friend
    final friendDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('connections')
        .doc(friendUserId)
        .get();
    if (!friendDoc.exists) {
      throw Exception('User is not your friend');
    }
    // Add invite to group_invites collection
    await _firestore.collection('group_invites').add({
      'groupId': groupId,
      'invitedBy': currentUserId,
      'invitedUser': friendUserId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Get group invites for current user
  Stream<QuerySnapshot> getGroupInvites() {
    return _firestore
        .collection('group_invites')
        .where('invitedUser', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Accept group invite
  Future<void> acceptGroupInvite(String inviteId, String groupId) async {
    // Add user to group members
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([currentUserId]),
    });
    // Update invite status
    await _firestore.collection('group_invites').doc(inviteId).update({
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Decline group invite
  Future<void> declineGroupInvite(String inviteId) async {
    await _firestore.collection('group_invites').doc(inviteId).update({
      'status': 'declined',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Send a message in a group chat
  Future<void> sendGroupMessage(String groupId, String text) async {
    await _firestore.collection('groups').doc(groupId).collection('messages').add({
      'senderId': currentUserId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Get messages for a group chat
  Stream<QuerySnapshot> getGroupChatMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Add member to group (admin only)
  Future<void> addMemberToGroup(String groupId, String userId) async {
    // Check if current user is admin
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (groupDoc.data()?['admin'] != currentUserId) {
      throw Exception('Only group admin can add members');
    }
    
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([userId]),
    });
  }

  /// Remove member from group (admin only)
  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    // Check if current user is admin
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (groupDoc.data()?['admin'] != currentUserId) {
      throw Exception('Only group admin can remove members');
    }
    
    // Prevent admin from removing themselves
    if (userId == currentUserId) {
      throw Exception('Admin cannot remove themselves from group');
    }
    
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([userId]),
    });
  }

  /// Transfer admin role to another member (admin only)
  Future<void> transferAdminRole(String groupId, String newAdminId) async {
    // Check if current user is admin
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    final groupData = groupDoc.data();
    if (groupData?['admin'] != currentUserId) {
      throw Exception('Only group admin can transfer admin role');
    }
    
    // Check if new admin is a member
    if (!(groupData?['members'] as List).contains(newAdminId)) {
      throw Exception('New admin must be a group member');
    }
    
    await _firestore.collection('groups').doc(groupId).update({
      'admin': newAdminId,
    });
  }

  /// Get group members with their user data
  Stream<QuerySnapshot> getGroupMembers(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .snapshots();
  }

  /// Check if user is group admin
  Future<bool> isGroupAdmin(String groupId) async {
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    return groupDoc.data()?['admin'] == currentUserId;
  }

  /// Create a club
  Future<void> createClub(String name, String description) async {
    await _firestore.collection('clubs').add({
      'name': name,
      'description': description,
      'members': [currentUserId],
      'admin': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get clubs the user is in
  Stream<QuerySnapshot> getUserClubs() {
    return _firestore
        .collection('clubs')
        .where('members', arrayContains: currentUserId)
        .snapshots();
  }

  /// Add member to club by email (admin only)
  Future<void> addMemberToClubByEmail(String clubId, String email) async {
    // Check if current user is admin
    final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
    if (clubDoc.data()?['admin'] != currentUserId) {
      throw Exception('Only club admin can add members');
    }

    // Find user by email
    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    if (userQuery.docs.isEmpty) {
      throw Exception('User with this email not found');
    }

    final userId = userQuery.docs.first.id;
    
    // Check if user is already a member
    final clubData = clubDoc.data();
    if ((clubData?['members'] as List).contains(userId)) {
      throw Exception('User is already a member of this club');
    }

    // Add user to club
    await _firestore.collection('clubs').doc(clubId).update({
      'members': FieldValue.arrayUnion([userId]),
    });

    // Send notification to the new member
    await sendNotificationToUser(
      toUserId: userId,
      title: 'Club Invitation',
      body: 'You have been added to a club',
      data: {
        'type': 'club_added',
        'clubId': clubId,
      },
    );
  }

  /// Invite member to club by email (admin only)
  Future<void> inviteMemberToClubByEmail(String clubId, String email) async {
    // Check if current user is admin
    final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
    if (clubDoc.data()?['admin'] != currentUserId) {
      throw Exception('Only club admin can invite members');
    }

    // Find user by email
    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    if (userQuery.docs.isEmpty) {
      throw Exception('User with this email not found');
    }

    final userId = userQuery.docs.first.id;
    
    // Check if user is already a member
    final clubData = clubDoc.data();
    if ((clubData?['members'] as List).contains(userId)) {
      throw Exception('User is already a member of this club');
    }

    // Create club invitation
    await _firestore.collection('club_invitations').add({
      'clubId': clubId,
      'invitedBy': currentUserId,
      'invitedUser': userId,
      'email': email,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Send notification to the invited user
    await sendNotificationToUser(
      toUserId: userId,
      title: 'Club Invitation',
      body: 'You have been invited to join a club',
      data: {
        'type': 'club_invitation',
        'clubId': clubId,
      },
    );
  }

  /// Get club invitations for current user
  Stream<QuerySnapshot> getClubInvitations() {
    return _firestore
        .collection('club_invitations')
        .where('invitedUser', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Accept club invitation
  Future<void> acceptClubInvitation(String invitationId, String clubId) async {
    // Add user to club members
    await _firestore.collection('clubs').doc(clubId).update({
      'members': FieldValue.arrayUnion([currentUserId]),
    });

    // Update invitation status
    await _firestore.collection('club_invitations').doc(invitationId).update({
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Decline club invitation
  Future<void> declineClubInvitation(String invitationId) async {
    await _firestore.collection('club_invitations').doc(invitationId).update({
      'status': 'declined',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove member from club (admin only)
  Future<void> removeMemberFromClub(String clubId, String userId) async {
    // Check if current user is admin
    final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
    if (clubDoc.data()?['admin'] != currentUserId) {
      throw Exception('Only club admin can remove members');
    }
    
    // Prevent admin from removing themselves
    if (userId == currentUserId) {
      throw Exception('Admin cannot remove themselves from club');
    }
    
    await _firestore.collection('clubs').doc(clubId).update({
      'members': FieldValue.arrayRemove([userId]),
    });
  }

  /// Delete club (admin only)
  Future<void> deleteClub(String clubId) async {
    // Check if current user is admin
    final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
    if (clubDoc.data()?['admin'] != currentUserId) {
      throw Exception('Only club admin can delete the club');
    }

    // Delete club messages
    final messagesQuery = await _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('messages')
        .get();
    
    final batch = _firestore.batch();
    for (var doc in messagesQuery.docs) {
      batch.delete(doc.reference);
    }

    // Delete club invitations
    final invitationsQuery = await _firestore
        .collection('club_invitations')
        .where('clubId', isEqualTo: clubId)
        .get();
    
    for (var doc in invitationsQuery.docs) {
      batch.delete(doc.reference);
    }

    // Delete the club itself
    batch.delete(_firestore.collection('clubs').doc(clubId));

    await batch.commit();
  }

  /// Check if user is club admin
  Future<bool> isClubAdmin(String clubId) async {
    final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
    return clubDoc.data()?['admin'] == currentUserId;
  }

  /// Get club members with their user data
  Future<List<Map<String, dynamic>>> getClubMembers(String clubId) async {
    final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
    final memberIds = clubDoc.data()?['members'] as List? ?? [];
    
    List<Map<String, dynamic>> members = [];
    for (String memberId in memberIds) {
      final userDoc = await _firestore.collection('users').doc(memberId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        members.add({
          'id': memberId,
          'name': userData['name'] ?? 'Unknown',
          'email': userData['email'] ?? '',
          'isAdmin': memberId == clubDoc.data()?['admin'],
        });
      }
    }
    
    return members;
  }

  /// Send notification to specific user
  Future<void> sendNotificationToUser({
    required String toUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Store notification in Firestore
    await _firestore.collection('notifications').add({
      'to': toUserId,
      'title': title,
      'body': body,
      'data': data,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }
}
