import 'package:flutter/material.dart';

class ProfileViewScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final String userId;

  const ProfileViewScreen({super.key, required this.user, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(user['name'] ?? 'Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: user['photoUrl'] != null
                    ? NetworkImage(user['photoUrl'])
                    : null,
                child: user['photoUrl'] == null ? const Icon(Icons.person, size: 50) : null,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              user['name'] ?? 'No name',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              user['age'] ?? 'No age provided.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.email),
                const SizedBox(width: 8),
                Text(user['email'] ?? 'No email'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.location_on),
                const SizedBox(width: 8),
                Text(user['gender'] ?? 'Gender not available'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
