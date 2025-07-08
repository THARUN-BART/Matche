import 'package:flutter/material.dart';

class GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onTap;

  const GroupCard({
    super.key,
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String groupName = group['name'] ?? 'Unnamed Group';
    final String description = group['description'] ?? '';
    final int membersCount = group['memberCount'] ?? 0;
    final int maxMembers = group['maxMembers'] ?? 10;
    final String category = group['category'] ?? 'General';
    final List<String> skills = List<String>.from(group['skills'] ?? []);
    final String userRole = group['userRole'] ?? 'member';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Group icon
              const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.green,
                child: Icon(Icons.group, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),

              // Group info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            groupName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (userRole == 'admin')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.category, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          category,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.people, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '$membersCount/$maxMembers members',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    if (skills.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: skills.take(3).map((skill) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              skill,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
