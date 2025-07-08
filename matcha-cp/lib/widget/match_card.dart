import 'package:flutter/material.dart';

class MatchCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onConnect;
  final VoidCallback onChat;

  const MatchCard({
    super.key,
    required this.user,
    required this.onConnect,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = user['isConnected'] ?? false;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.deepPurple[100],
                    child: Text(
                      user['name'][0],
                      style: const TextStyle(color: Colors.deepPurple),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${user['matchScore'] ?? 0}% Match',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Skills: ${(user['skills'] as List<dynamic>?)?.join(', ') ?? ''}',
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Gender: ${user['gender'] ?? 'NONE'}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                'Interests: ${(user['interests'] as List<dynamic>?)?.join(', ') ?? 'NONE'}',
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isConnected ? onChat : onConnect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConnected
                            ? Colors.green
                            : Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        isConnected ? 'Chat' : 'Connect',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}