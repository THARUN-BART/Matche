import 'package:flutter/material.dart';

class ConnectionCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isConnected;
  final bool hasSentRequest;
  final VoidCallback? onTap;
  final VoidCallback? onMessage;
  final VoidCallback? onConnect;

  const ConnectionCard({
    super.key,
    required this.user,
    this.isConnected = false,
    this.hasSentRequest = false,
    this.onTap,
    this.onMessage,
    this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(user['name'][0]),
        ),
        title: Text(user['name']),
        subtitle: Text(user['bio'] ?? ''),
        onTap: onTap,
        trailing: isConnected
            ? IconButton(
          icon: const Icon(Icons.message, color: Colors.deepPurple),
          onPressed: onMessage,
        )
            : ElevatedButton(
          onPressed: hasSentRequest ? null : onConnect,
          style: ElevatedButton.styleFrom(
            backgroundColor: hasSentRequest ? Colors.grey : Colors.deepPurple,
          ),
          child: Text(
            hasSentRequest ? 'Requested' : 'Connect',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
