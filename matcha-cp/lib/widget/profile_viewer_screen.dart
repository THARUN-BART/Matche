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
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Picture
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundImage: user['avatarUrl'] != null
                    ? NetworkImage(user['avatarUrl'])
                    : null,
                child: user['avatarUrl'] == null 
                    ? Text(
                        (user['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                      ) 
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            
            // Name
            Center(
              child: Text(
                user['name'] ?? 'No name provided',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Email
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.email, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    user['email'] ?? 'No email provided',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Skills Section
            if (user['skills'] != null && (user['skills'] as List).isNotEmpty) ...[
              _buildSectionTitle('Skills'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (user['skills'] as List).map<Widget>((skill) {
                  return Chip(
                    label: Text(skill.toString()),
                    backgroundColor: Colors.green.withOpacity(0.1),
                    side: BorderSide(color: Colors.green.withOpacity(0.3)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
            
            // Interests Section
            if (user['interests'] != null && (user['interests'] as List).isNotEmpty) ...[
              _buildSectionTitle('Interests'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (user['interests'] as List).map<Widget>((interest) {
                  return Chip(
                    label: Text(interest.toString()),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    side: BorderSide(color: Colors.blue.withOpacity(0.3)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
            
            // Availability Section
            if (user['availability'] != null) ...[
              _buildSectionTitle('Availability'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user['availability'].toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Additional Info
            if (user['bio'] != null && user['bio'].toString().isNotEmpty) ...[
              _buildSectionTitle('About'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user['bio'].toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Contact Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement chat functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat functionality coming soon!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.chat),
                label: const Text('Start Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}
