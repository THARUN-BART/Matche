import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../account_info.dart';
import '../group_invitations_screen.dart';
import '../../widget/notification_test_widget.dart';
import '../../service/firestore_service.dart';
import '../../service/notification_service.dart';
import '../../Authentication/Login.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _profileVisible = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snap = await _firestore.collection("users").doc(user.uid).get();
      if (snap.exists) {
        setState(() {
          _userData = snap.data();
          _isLoading = false;
          _notificationsEnabled = _userData?['notificationsEnabled'] ?? true;
          _profileVisible = _userData?['profileVisible'] ?? true;
        });
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection("users").doc(user.uid).update({
        key: value,
        "updatedAt": FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _userData?[key] = value;
      });
      
      _showSnackBar("Setting updated successfully!", Colors.green);
    } catch (e) {
      _showSnackBar("Failed to update setting: $e", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileSection(),
          _buildPrivacySection(),
          _buildNotificationSection(),
          _buildGroupsSection(),
          _buildAccountSection(),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return _buildSettingsSection("Profile", [
      _buildSettingsItem(
        "Edit Profile", 
        Icons.edit, 
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AccountInfo()),
        ),
      ),
      _buildSettingsItem(
        "About Myself",
        Icons.person,
        () => _showAboutMyselfDialog(),
      ),
      _buildSettingsItem(
        "Skills & Interests", 
        Icons.star, 
        () => _showSkillsInterestsDialog(),
      ),
    ]);
  }

  Widget _buildPrivacySection() {
    return _buildSettingsSection("Privacy", [
      _buildSwitchTile(
        "Profile Visibility",
        Icons.visibility,
        _profileVisible,
        (value) {
          setState(() => _profileVisible = value);
          _updateSetting('profileVisible', value);
        },
      ),
      _buildSettingsItem(
        "Blocked Users", 
        Icons.block, 
        () => _showBlockedUsersDialog(),
      ),
      _buildSettingsItem(
        "Data & Privacy", 
        Icons.security, 
        () => _showDataPrivacyDialog(),
      ),
    ]);
  }

  Widget _buildNotificationSection() {
    return _buildSettingsSection("Notifications", [
      _buildSwitchTile(
        "Push Notifications",
        Icons.notifications,
        _notificationsEnabled,
        (value) {
          setState(() => _notificationsEnabled = value);
          _updateSetting('notificationsEnabled', value);
        },
      ),
      _buildSettingsItem(
        "Notification Settings", 
        Icons.settings, 
        () => _showNotificationSettingsDialog(),
      ),
      _buildSettingsItem(
        "Test Notifications", 
        Icons.notifications_active,
        () => _showTestNotificationDialog(),
      ),
    ]);
  }

  Widget _buildGroupsSection() {
    return _buildSettingsSection("Groups", [
      _buildSettingsItem(
        "Group Invitations", 
        Icons.group_add, 
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GroupInvitationsScreen()),
        ),
      ),
      _buildSettingsItem(
        "My Groups", 
        Icons.group, 
        () => _showMyGroupsDialog(),
      ),
      _buildSettingsItem(
        "Group Settings", 
        Icons.settings, 
        () => _showGroupSettingsDialog(),
      ),
    ]);
  }

  Widget _buildAccountSection() {
    return _buildSettingsSection("Account", [
      _buildSettingsItem(
        "Change Password", 
        Icons.lock, 
        () => _showChangePasswordDialog(),
      ),
      _buildSettingsItem(
        "Delete Account", 
        Icons.delete_forever, 
        () => _showDeleteAccountDialog(),
      ),
      _buildSettingsItem(
        "Logout", 
        Icons.logout, 
        () => _logout(),
        isDestructive: true,
      ),
    ]);
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ),
        Card(
          elevation: 2,
          child: Column(children: children),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSettingsItem(String title, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : Colors.green,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : null,
          fontWeight: isDestructive ? FontWeight.w500 : null,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(String title, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.green,
      ),
    );
  }

  // Dialog methods
  void _showAboutMyselfDialog() {
    showDialog(
      context: context,
      builder: (context) => AboutMyselfDialog(
        userData: _userData ?? {},
        onSave: (aboutData) async {
          final user = _auth.currentUser;
          if (user == null) return;
          try {
            await _firestore.collection("users").doc(user.uid).update(aboutData);
            setState(() {
              _userData?.addAll(aboutData);
            });
            _showSnackBar("About Myself updated!", Colors.green);
          } catch (e) {
            _showSnackBar("Failed to update: $e", Colors.red);
          }
        },
      ),
    );
  }

  void _showSkillsInterestsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skills & Interests'),
        content: const Text('Skills and interests functionality coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBlockedUsersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Blocked Users'),
        content: const Text('No blocked users'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDataPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data & Privacy'),
        content: const Text('Your data is protected and never shared with third parties.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: const Text('Detailed notification settings coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTestNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Notifications'),
        content: const Text('Send a test notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              NotificationService().showLocalNotification(
                title: 'Test Notification',
                body: 'This is a test notification from Matcha!',
              );
            },
            child: const Text('Send Test'),
          ),
        ],
      ),
    );
  }

  void _showMyGroupsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Groups'),
        content: const Text('Group management coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showGroupSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Group Settings'),
        content: const Text('Group settings functionality coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: const Text('Password change functionality coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Account deletion coming soon!', Colors.orange);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Login()),
          (route) => false,
        );
      }
    } catch (e) {
      _showSnackBar('Error logging out: $e', Colors.red);
    }
  }
}

class AboutMyselfDialog extends StatefulWidget {
  final Map<String, dynamic> userData;
  final void Function(Map<String, dynamic>) onSave;
  const AboutMyselfDialog({super.key, required this.userData, required this.onSave});

  @override
  State<AboutMyselfDialog> createState() => _AboutMyselfDialogState();
}

class _AboutMyselfDialogState extends State<AboutMyselfDialog> {
  Map<String, double> _big5 = {'O': 0.5, 'C': 0.5, 'E': 0.5, 'A': 0.5, 'N': 0.5};

  @override
  void initState() {
    super.initState();
    if (widget.userData['big5'] is Map) {
      final b5 = widget.userData['big5'] as Map;
      for (final k in _big5.keys) {
        final v = b5[k];
        if (v is num) _big5[k] = v.toDouble();
        else if (v is String) _big5[k] = double.tryParse(v) ?? 0.5;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('About Myself'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Personality Quiz (Big Five):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _BigFiveQuiz(
              initial: _big5,
              onChanged: (b5) => setState(() => _big5 = b5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onSave({'big5': _big5});
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _BigFiveQuiz extends StatefulWidget {
  final Map<String, double> initial;
  final void Function(Map<String, double>) onChanged;
  const _BigFiveQuiz({required this.initial, required this.onChanged});

  @override
  State<_BigFiveQuiz> createState() => _BigFiveQuizState();
}

class _BigFiveQuizState extends State<_BigFiveQuiz> {
  late Map<String, int> _ratings;
  final List<Map<String, String>> _questions = [
    {'key': 'O', 'text': 'I am Full of Ideas', 'left': 'Disagree', 'right': 'Agree'},
    {'key': 'C', 'text': 'I follow a schedule', 'left': 'Disagree', 'right': 'Agree'},
    {'key': 'E', 'text': 'I love socializing with others', 'left': 'Worst', 'right': 'Best'},
    {'key': 'A', 'text': "I sympathize with other's feelings", 'left': 'Worst', 'right': 'Best'},
    {'key': 'N', 'text': 'I get stressed out easily', 'left': 'Worst', 'right': 'Best'},
  ];

  @override
  void initState() {
    super.initState();
    _ratings = Map<String, int>.fromIterable(widget.initial.keys,
      key: (k) => k,
      value: (k) => ((widget.initial[k] ?? 0.5) * 4).round() + 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _questions.map((q) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q['text']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(q['left']!, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  ...List.generate(5, (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text('${i + 1}'),
                      selected: _ratings[q['key']] == i + 1,
                      onSelected: (selected) {
                        setState(() {
                          _ratings[q['key']!] = i + 1;
                          widget.onChanged(_ratings.map((k, v) => MapEntry(k, (v - 1) / 4)));
                        });
                      },
                    ),
                  )),
                  const SizedBox(width: 8),
                  Text(q['right']!, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}

