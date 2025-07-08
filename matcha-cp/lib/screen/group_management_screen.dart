import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../service/group_service.dart';
import '../service/firestore_service.dart';

class GroupManagementScreen extends StatefulWidget {
  final String groupId;
  
  const GroupManagementScreen({super.key, required this.groupId});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  late GroupService _groupService;
  late FirestoreService _firestoreService;
  
  Map<String, dynamic>? _groupDetails;
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _groupService = Provider.of<GroupService>(context, listen: false);
      _firestoreService = Provider.of<FirestoreService>(context, listen: false);
      _loadGroupDetails();
    });
  }

  Future<void> _loadGroupDetails() async {
    try {
      final groupDetails = await _groupService.getGroupDetails(widget.groupId);
      if (groupDetails != null) {
        setState(() {
          _groupDetails = groupDetails;
        });
        
        // Check if current user is admin
        _checkAdminStatus();
      }
    } catch (e) {
      print('Error loading group details: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAdminStatus() async {
    final currentUser = _firestoreService.currentUserId;
    final memberDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('members')
        .doc(currentUser)
        .get();
    
    if (mounted) {
      setState(() {
        _isAdmin = memberDoc.data()?['role'] == 'admin';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_groupDetails == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Management')),
        body: const Center(child: Text('Group not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_groupDetails!['name']),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (_isAdmin)
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit Group'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'invite',
                  child: Row(
                    children: [
                      Icon(Icons.person_add),
                      SizedBox(width: 8),
                      Text('Send Invite'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'transfer_admin',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz),
                      SizedBox(width: 8),
                      Text('Transfer Admin'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Group', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _groupDetails!['name'],
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _groupDetails!['description'],
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.category, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('Category: ${_groupDetails!['category']}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.people, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text('Members: ${_groupDetails!['memberCount']}/${_groupDetails!['maxMembers']}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: (_groupDetails!['skills'] as List<dynamic>).map((skill) {
                        return Chip(
                          label: Text(skill.toString()),
                          backgroundColor: Colors.green.withOpacity(0.1),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Members Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Members',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (_isAdmin)
                  ElevatedButton.icon(
                    onPressed: _showAddMemberDialog,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Member'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Members List
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _groupService.getGroupMembers(widget.groupId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Error loading members');
                }
                
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final members = snapshot.data!;
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(member['name'][0].toUpperCase()),
                        ),
                        title: Text(member['name']),
                        subtitle: Text(member['email']),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (member['role'] == 'admin')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Admin',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            if (_isAdmin && member['role'] != 'admin')
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () => _removeMember(member['userId']),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _showEditGroupDialog();
        break;
      case 'invite':
        _showSendInviteDialog();
        break;
      case 'transfer_admin':
        _showTransferAdminDialog();
        break;
      case 'delete':
        _showDeleteGroupDialog();
        break;
    }
  }

  void _showEditGroupDialog() {
    final nameController = TextEditingController(text: _groupDetails!['name']);
    final descriptionController = TextEditingController(text: _groupDetails!['description']);
    final maxMembersController = TextEditingController(text: _groupDetails!['maxMembers'].toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Group Name'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              TextField(
                controller: maxMembersController,
                decoration: const InputDecoration(labelText: 'Max Members'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateGroup(
                name: nameController.text,
                description: descriptionController.text,
                maxMembers: int.tryParse(maxMembersController.text),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateGroup({
    String? name,
    String? description,
    int? maxMembers,
  }) async {
    try {
      final success = await _groupService.updateGroup(
        groupId: widget.groupId,
        name: name,
        description: description,
        maxMembers: maxMembers,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group updated successfully')),
        );
        _loadGroupDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update group')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showAddMemberDialog() {
    final emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'User Email',
                hintText: 'Enter user email',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _addMemberByEmail(emailController.text);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addMemberByEmail(String email) async {
    try {
      // Find user by email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
        return;
      }
      
      final userId = userQuery.docs.first.id;
      final success = await _groupService.addMemberToGroup(widget.groupId, userId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member added successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add member')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _removeMember(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text('Are you sure you want to remove this member?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final success = await _groupService.removeMemberFromGroup(widget.groupId, userId);
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member removed successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to remove member')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showSendInviteDialog() {
    final emailController = TextEditingController();
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Invitation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'User Email',
                hintText: 'Enter user email',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
                hintText: 'Add a personal message',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendInvitation(emailController.text, messageController.text);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendInvitation(String email, String message) async {
    try {
      // Find user by email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
        return;
      }
      
      final userId = userQuery.docs.first.id;
      final success = await _groupService.sendGroupInvitation(
        groupId: widget.groupId,
        targetUserId: userId,
        message: message.isEmpty ? null : message,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send invitation')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showTransferAdminDialog() {
    // Get current members for selection
    StreamBuilder<List<Map<String, dynamic>>>(
      stream: _groupService.getGroupMembers(widget.groupId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AlertDialog(
            content: Center(child: CircularProgressIndicator()),
          );
        }
        
        final members = snapshot.data!.where((m) => m['role'] != 'admin').toList();
        
        return AlertDialog(
          title: const Text('Transfer Admin Role'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return ListTile(
                  title: Text(member['name']),
                  subtitle: Text(member['email']),
                  onTap: () async {
                    Navigator.pop(context);
                    await _transferAdminRole(member['userId']);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _transferAdminRole(String newAdminUserId) async {
    try {
      final success = await _groupService.transferAdminRole(widget.groupId, newAdminUserId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin role transferred successfully')),
        );
        _checkAdminStatus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to transfer admin role')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showDeleteGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'Are you sure you want to delete this group? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteGroup();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup() async {
    try {
      final success = await _groupService.deleteGroup(widget.groupId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group deleted successfully')),
        );
        Navigator.pop(context); // Go back to previous screen
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete group')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
} 