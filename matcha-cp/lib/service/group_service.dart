import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Create a new group
  Future<String> createGroup({
    required String name,
    required String description,
    required List<String> skills,
    required String category,
    required int maxMembers,
    String? imageUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final groupData = {
        'name': name,
        'description': description,
        'skills': skills,
        'category': category,
        'maxMembers': maxMembers,
        'imageUrl': imageUrl,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'memberCount': 1,
      };

      final groupRef = await _firestore.collection('groups').add(groupData);
      
      // Add creator as admin member
      await _firestore.collection('groups').doc(groupRef.id).collection('members').doc(user.uid).set({
        'userId': user.uid,
        'role': 'admin',
        'joinedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      return groupRef.id;
    } catch (e) {
      print('Error creating group: $e');
      rethrow;
    }
  }

  // Get user's groups (created or joined)
  Stream<List<Map<String, dynamic>>> getUserGroups() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('groups')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> userGroups = [];
      
      for (var doc in snapshot.docs) {
        final memberDoc = await _firestore
            .collection('groups')
            .doc(doc.id)
            .collection('members')
            .doc(user.uid)
            .get();
        
        if (memberDoc.exists) {
          final groupData = doc.data();
          groupData['id'] = doc.id;
          groupData['userRole'] = memberDoc.data()?['role'] ?? 'member';
          userGroups.add(groupData);
        }
      }
      
      return userGroups;
    });
  }

  // Get group details
  Future<Map<String, dynamic>?> getGroupDetails(String groupId) async {
    try {
      final doc = await _firestore.collection('groups').doc(groupId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting group details: $e');
      return null;
    }
  }

  // Update group details (admin only)
  Future<bool> updateGroup({
    required String groupId,
    String? name,
    String? description,
    List<String>? skills,
    String? category,
    int? maxMembers,
    String? imageUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if user is admin
      final memberDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(user.uid)
          .get();

      if (!memberDoc.exists || memberDoc.data()?['role'] != 'admin') {
        throw Exception('Only admins can update group details');
      }

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (skills != null) updateData['skills'] = skills;
      if (category != null) updateData['category'] = category;
      if (maxMembers != null) updateData['maxMembers'] = maxMembers;
      if (imageUrl != null) updateData['imageUrl'] = imageUrl;

      await _firestore.collection('groups').doc(groupId).update(updateData);
      return true;
    } catch (e) {
      print('Error updating group: $e');
      return false;
    }
  }

  // Get group members
  Stream<List<Map<String, dynamic>>> getGroupMembers(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> members = [];
      
      for (var doc in snapshot.docs) {
        final userDoc = await _firestore.collection('users').doc(doc.id).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final memberData = doc.data();
          members.add({
            'userId': doc.id,
            'name': userData['name'] ?? 'Unknown',
            'email': userData['email'] ?? '',
            'role': memberData['role'] ?? 'member',
            'joinedAt': memberData['joinedAt'],
            'isActive': memberData['isActive'] ?? true,
          });
        }
      }
      
      return members;
    });
  }

  // Add member to group (admin only)
  Future<bool> addMemberToGroup(String groupId, String userId, {String role = 'member'}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if user is admin
      final memberDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(user.uid)
          .get();

      if (!memberDoc.exists || memberDoc.data()?['role'] != 'admin') {
        throw Exception('Only admins can add members');
      }

      // Check if user is already a member
      final existingMember = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(userId)
          .get();

      if (existingMember.exists) {
        throw Exception('User is already a member of this group');
      }

      // Check group capacity
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final groupData = groupDoc.data()!;
      final currentMembers = groupData['memberCount'] ?? 0;
      final maxMembers = groupData['maxMembers'] ?? 10;

      if (currentMembers >= maxMembers) {
        throw Exception('Group is at maximum capacity');
      }

      // Add member
      await _firestore.collection('groups').doc(groupId).collection('members').doc(userId).set({
        'userId': userId,
        'role': role,
        'joinedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Update member count
      await _firestore.collection('groups').doc(groupId).update({
        'memberCount': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      print('Error adding member to group: $e');
      return false;
    }
  }

  // Remove member from group (admin only)
  Future<bool> removeMemberFromGroup(String groupId, String userId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if user is admin
      final memberDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(user.uid)
          .get();

      if (!memberDoc.exists || memberDoc.data()?['role'] != 'admin') {
        throw Exception('Only admins can remove members');
      }

      // Check if trying to remove admin
      final targetMemberDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(userId)
          .get();

      if (targetMemberDoc.data()?['role'] == 'admin') {
        throw Exception('Cannot remove admin from group');
      }

      // Remove member
      await _firestore.collection('groups').doc(groupId).collection('members').doc(userId).delete();

      // Update member count
      await _firestore.collection('groups').doc(groupId).update({
        'memberCount': FieldValue.increment(-1),
      });

      return true;
    } catch (e) {
      print('Error removing member from group: $e');
      return false;
    }
  }

  // Send group invitation
  Future<bool> sendGroupInvitation({
    required String groupId,
    required String targetUserId,
    String? message,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if user is admin
      final memberDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(user.uid)
          .get();

      if (!memberDoc.exists || memberDoc.data()?['role'] != 'admin') {
        throw Exception('Only admins can send invitations');
      }

      // Get group details
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final groupData = groupDoc.data()!;

      // Create invitation
      await _firestore.collection('group_invitations').add({
        'groupId': groupId,
        'groupName': groupData['name'],
        'invitedBy': user.uid,
        'invitedTo': targetUserId,
        'message': message ?? 'You have been invited to join this group!',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
      });

      return true;
    } catch (e) {
      print('Error sending group invitation: $e');
      return false;
    }
  }

  // Get pending invitations for user
  Stream<List<Map<String, dynamic>>> getUserInvitations() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('group_invitations')
        .where('invitedTo', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList());
  }

  // Accept group invitation
  Future<bool> acceptGroupInvitation(String invitationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final invitationDoc = await _firestore.collection('group_invitations').doc(invitationId).get();
      if (!invitationDoc.exists) throw Exception('Invitation not found');

      final invitationData = invitationDoc.data()!;
      final groupId = invitationData['groupId'];

      // Check if invitation is still valid
      if (invitationData['status'] != 'pending' || 
          invitationData['expiresAt'].toDate().isBefore(DateTime.now())) {
        throw Exception('Invitation has expired or is no longer valid');
      }

      // Add user to group
      final success = await addMemberToGroup(groupId, user.uid);
      if (success) {
        // Update invitation status
        await _firestore.collection('group_invitations').doc(invitationId).update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error accepting group invitation: $e');
      return false;
    }
  }

  // Decline group invitation
  Future<bool> declineGroupInvitation(String invitationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _firestore.collection('group_invitations').doc(invitationId).update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error declining group invitation: $e');
      return false;
    }
  }

  // Leave group
  Future<bool> leaveGroup(String groupId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if user is admin
      final memberDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(user.uid)
          .get();

      if (!memberDoc.exists) throw Exception('User is not a member of this group');

      if (memberDoc.data()?['role'] == 'admin') {
        throw Exception('Admins cannot leave the group. Transfer admin role first.');
      }

      // Remove member
      await _firestore.collection('groups').doc(groupId).collection('members').doc(user.uid).delete();

      // Update member count
      await _firestore.collection('groups').doc(groupId).update({
        'memberCount': FieldValue.increment(-1),
      });

      return true;
    } catch (e) {
      print('Error leaving group: $e');
      return false;
    }
  }

  // Transfer admin role
  Future<bool> transferAdminRole(String groupId, String newAdminUserId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if current user is admin
      final memberDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(user.uid)
          .get();

      if (!memberDoc.exists || memberDoc.data()?['role'] != 'admin') {
        throw Exception('Only admins can transfer admin role');
      }

      // Check if new admin is a member
      final newAdminDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(newAdminUserId)
          .get();

      if (!newAdminDoc.exists) {
        throw Exception('User must be a member to become admin');
      }

      // Transfer admin role
      await _firestore.collection('groups').doc(groupId).collection('members').doc(user.uid).update({
        'role': 'member',
      });

      await _firestore.collection('groups').doc(groupId).collection('members').doc(newAdminUserId).update({
        'role': 'admin',
      });

      return true;
    } catch (e) {
      print('Error transferring admin role: $e');
      return false;
    }
  }

  // Delete group (admin only)
  Future<bool> deleteGroup(String groupId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if user is admin
      final memberDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(user.uid)
          .get();

      if (!memberDoc.exists || memberDoc.data()?['role'] != 'admin') {
        throw Exception('Only admins can delete groups');
      }

      // Soft delete - mark as inactive
      await _firestore.collection('groups').doc(groupId).update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': user.uid,
      });

      return true;
    } catch (e) {
      print('Error deleting group: $e');
      return false;
    }
  }

  // Search groups
  Stream<List<Map<String, dynamic>>> searchGroups({
    String? query,
    String? category,
    List<String>? skills,
  }) {
    Query groupsQuery = _firestore.collection('groups').where('isActive', isEqualTo: true);

    if (query != null && query.isNotEmpty) {
      groupsQuery = groupsQuery.where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + '\uf8ff');
    }

    if (category != null && category.isNotEmpty) {
      groupsQuery = groupsQuery.where('category', isEqualTo: category);
    }

    return groupsQuery.snapshots().map((snapshot) {
      List<Map<String, dynamic>> groups = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Filter by skills if specified
        if (skills != null && skills.isNotEmpty) {
          final groupSkills = List<String>.from(data['skills'] ?? []);
          final hasMatchingSkills = skills.any((skill) => groupSkills.contains(skill));
          if (hasMatchingSkills) {
            groups.add(data);
          }
        } else {
          groups.add(data);
        }
      }
      
      return groups;
    });
  }
}