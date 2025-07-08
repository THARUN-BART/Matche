import 'package:flutter/material.dart';
import '../account_info.dart';
import '../group_invitations_screen.dart';
import '../../widget/notification_test_widget.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsSection("Profile", [
          _buildSettingsItem("Edit Profile", Icons.edit, () {
            _showSnack(context, "Edit Profile tapped");
          }),
          _buildSettingsItem("Skills & Interests", Icons.star, () {
            _showSnack(context, "Skills & Interests tapped");
          }),
          _buildSettingsItem("Availability", Icons.schedule, () {
            _showSnack(context, "Availability tapped");
          }),
          _buildSettingsItem("Account Information", Icons.account_circle, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AccountInfo()),
            );
          }),
        ]),
        _buildSettingsSection("Matching Preferences", [
          _buildSettingsItem("Personality Quiz", Icons.psychology, () {
            _showSnack(context, "Launching personality quiz...");
          }),
          _buildSettingsItem("Matching Criteria", Icons.tune, () {
            _showSnack(context, "Configure matching criteria");
          }),
          _buildSettingsItem("Distance Range", Icons.location_on, () {
            _showSnack(context, "Adjust distance range");
          }),
        ]),
        _buildSettingsSection("Groups & Invitations", [
          _buildSettingsItem("Manage Groups", Icons.group, () {
            _showSnack(context, "Manage your groups here");
          }),
          _buildSettingsItem("Group Invitations", Icons.mail, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GroupInvitationsScreen()),
            );
          }),
          _buildSettingsItem("Blocked Users", Icons.block, () {
            _showSnack(context, "View or unblock users");
          }),
        ]),
        _buildSettingsSection("Account", [
          _buildSettingsItem("Test Notifications", Icons.notifications, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationTestWidget()),
            );
          }),
          _buildSettingsItem("Privacy Settings", Icons.privacy_tip, () {
            _showSnack(context, "Privacy Settings tapped");
          }),
          _buildSettingsItem("Help & Support", Icons.help, () {
            _showSnack(context, "Opening Help & Support");
          }),
          _buildSettingsItem("Logout", Icons.logout, () {
            _showLogoutConfirmation(context);
          }, color: Colors.red),
        ]),
      ],
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(child: Column(children: items)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSettingsItem(String title, IconData icon, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.deepPurple),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(BuildContext context, String title, IconData icon, bool initialValue, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.deepPurple),
      title: Text(title),
      value: initialValue,
      onChanged: onChanged,
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              // Add logout logic here
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Logged out")),
              );
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
