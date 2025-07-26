import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/group_service.dart';
import '../service/firestore_service.dart';

class GroupManagementScreen extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic> group;

  const GroupManagementScreen({
    super.key,
    required this.groupId,
    required this.group,
  });

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _inviteMessageController = TextEditingController();
  String? _joinCode;
  bool _joinCodeEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadJoinCode();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inviteMessageController.dispose();
    super.dispose();
  }

  Future<void> _loadJoinCode() async {
    final groupService = Provider.of<GroupService>(context, listen: false);
    final joinCode = await groupService.getGroupJoinCode(widget.groupId);
    if (mounted) {
      setState(() {
        _joinCode = joinCode;
        _joinCodeEnabled = widget.group['joinCodeEnabled'] ?? true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage ${widget.group['name']}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Members'),
            Tab(text: 'Invite'),
            Tab(text: 'Settings'),
          ],
          indicatorColor: Color(0xFFFFEC3D),
          labelColor: Color(0xFFFFEC3D),
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMembersTab(),
          _buildInviteTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    final groupService = Provider.of<GroupService>(context);
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: groupService.getGroupMembers(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading members'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final members = snapshot.data ?? [];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return _buildMemberCard(member);
          },
        );
      },
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final isAdmin = member['role'] == 'admin';
    final isCurrentUser = member['userId'] == Provider.of<FirestoreService>(context, listen: false).currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAdmin ? Colors.green : Colors.grey,
          child: Text(
            (member['name'] as String).isNotEmpty ? member['name'][0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          member['name'] ?? 'Unknown',
          style: TextStyle(fontWeight: isAdmin ? FontWeight.bold : FontWeight.normal),
        ),
        subtitle: Text(
          isAdmin ? 'Admin' : 'Member',
          style: TextStyle(color: isAdmin ? Colors.green : Colors.grey),
        ),
        trailing: isAdmin || isCurrentUser
            ? null
            : PopupMenuButton<String>(
                onSelected: (value) => _handleMemberAction(value, member),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.remove_circle, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Remove'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'make_admin',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Make Admin'),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInviteTab() {
    final TextEditingController _emailController = TextEditingController();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // Invite Users Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Invite Users',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Search and invite users to join this group',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showUserSearch,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Search Users'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          

        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit Group Details'),
              subtitle: const Text('Change name, description, and settings'),
              onTap: _editGroupDetails,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Group'),
              subtitle: const Text('Permanently delete this group'),
              onTap: _deleteGroup,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMemberAction(String action, Map<String, dynamic> member) {
    switch (action) {
      case 'remove':
        _removeMember(member['userId']);
        break;
      case 'make_admin':
        _makeAdmin(member['userId']);
        break;
    }
  }

  Future<void> _removeMember(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text('Are you sure you want to remove this member from the group?'),
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
        final groupService = Provider.of<GroupService>(context, listen: false);
        final success = await groupService.removeMemberFromGroup(widget.groupId, userId);
        
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

  Future<void> _makeAdmin(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make Admin'),
        content: const Text('Are you sure you want to make this member an admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Make Admin', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final groupService = Provider.of<GroupService>(context, listen: false);
        final success = await groupService.transferAdminRole(widget.groupId, userId);
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admin role transferred successfully')),
          );
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
  }

  Future<void> _copyJoinCode() async {
    if (_joinCode != null) {
      // You can implement clipboard functionality here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Join code copied: $_joinCode')),
      );
    }
  }

  Future<void> _generateNewJoinCode() async {
    try {
      final groupService = Provider.of<GroupService>(context, listen: false);
      final newCode = await groupService.generateNewJoinCode(widget.groupId);
      
      if (newCode != null) {
        setState(() {
          _joinCode = newCode;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New join code generated: $newCode')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate new join code')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _toggleJoinCode() async {
    try {
      final groupService = Provider.of<GroupService>(context, listen: false);
      final success = await groupService.toggleJoinCode(widget.groupId, !_joinCodeEnabled);
      
      if (success) {
        setState(() {
          _joinCodeEnabled = !_joinCodeEnabled;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Join code ${_joinCodeEnabled ? 'enabled' : 'disabled'}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to toggle join code')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showUserSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserSearchScreen(groupId: widget.groupId),
      ),
    );
  }

  void _shareJoinCode() {
    if (_joinCode != null) {
      // You can implement sharing functionality here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share join code: $_joinCode')),
      );
    }
  }

  void _editGroupDetails() {
    final nameCtrl = TextEditingController(text: widget.group['name']);
    final descCtrl = TextEditingController(text: widget.group['description']);
    final memberCountCtrl = TextEditingController(text: (widget.group['maxMembers'] ?? 10).toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: memberCountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Max Members',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel',style: TextStyle(color:Colors.white),)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFFFFEC3D)
    ),
            onPressed: () async {
              await Provider.of<GroupService>(context, listen: false).updateGroup(
                groupId: widget.groupId,
                name: nameCtrl.text,
                description: descCtrl.text,
                maxMembers: int.tryParse(memberCountCtrl.text) ?? 10,
              );
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save',style: TextStyle(color: Colors.black),),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text('Are you sure you want to delete this group? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final groupService = Provider.of<GroupService>(context, listen: false);
        final success = await groupService.deleteGroup(widget.groupId);
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group deleted successfully')),
          );
          Navigator.pop(context);
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
}


class UserSearchScreen extends StatefulWidget {
  final String groupId;

  const UserSearchScreen({super.key, required this.groupId});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  List<String> _invitedUserIds = [];

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Users'),
        leading: IconButton(onPressed: (){
          Navigator.pop(context);
        }, icon: Icon(Icons.arrow_back_ios)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search users',
                hintText: 'Enter name or email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _searchUsers,
                  icon: const Icon(Icons.search),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _searchUsers(),
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return _buildUserCard(user);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isInvited = _invitedUserIds.contains(user['id']);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(0xFFFFEC3D),
          backgroundImage: user['avatarUrl'] != null ? NetworkImage(user['avatarUrl']) : null,
          child: user['avatarUrl'] == null
              ? Text((user['name'] as String).isNotEmpty ? user['name'][0].toUpperCase() : '?',style: TextStyle(color: Colors.black),)
              : null,
        ),
        title: Text(user['name'] ?? 'Unknown'),
        subtitle: Text(user['email'] ?? ''),
        trailing: isInvited
            ? ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Invited'),
              )
            : ElevatedButton(
                onPressed: () => _showInviteDialog(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Invite'),
              ),
      ),
    );
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final groupService = Provider.of<GroupService>(context, listen: false);
      final results = await firestoreService.searchUsers(query);
      // Fetch invited user IDs for this group
      final invitedUserIds = await groupService.getInvitedUserIds(widget.groupId);
      setState(() {
        _searchResults = results;
        _invitedUserIds = invitedUserIds;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching users: $e')),
      );
    }
  }

  void _showInviteDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invite ${user['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add a personal message (optional):'),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Enter your message...',
                border: OutlineInputBorder(),
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
            onPressed: () => _sendInvitation(user),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Send Invitation', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendInvitation(Map<String, dynamic> user) async {
    try {
      final groupService = Provider.of<GroupService>(context, listen: false);
      final success = await groupService.sendGroupInvitationWithNotification(
        groupId: widget.groupId,
        targetUserId: user['id'],
        message: _messageController.text.trim(),
      );

      Navigator.pop(context); // Close dialog

      if (success) {
        setState(() {
          _invitedUserIds.add(user['id']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation sent to ${user['name']}')),
        );
        _messageController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send invitation')),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
} 