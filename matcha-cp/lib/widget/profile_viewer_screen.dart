import 'package:flutter/material.dart';

class ProfileViewScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final String userId;

  const ProfileViewScreen({super.key, required this.user, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile Info"),
        leading: IconButton(onPressed: (){
          Navigator.pop(context);
        }, icon: Icon(Icons.arrow_back_ios)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                backgroundColor: Color(0xFFFFEC3D),
                radius: 60,
                backgroundImage: user['avatarUrl'] != null
                    ? NetworkImage(user['avatarUrl'])
                    : null,
                child: user['avatarUrl'] == null 
                    ? Text(
                        (user['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold,color: Colors.black),
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
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
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
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
            
            // Availability Section
            if (user['availability'] != null) ...[
              _buildSectionTitle('Availability'),
              const SizedBox(height: 8),
              _buildAvailabilitySection(context, user['availability']),
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
      ),
    );
  }

  Widget _buildAvailabilitySection(BuildContext context, dynamic availabilityData) {
    try {
      // Handle the availability data structure
      Map<String, dynamic> availability;
      if (availabilityData is Map<String, dynamic>) {
        availability = availabilityData;
      } else {
        // Fallback for string or other formats
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            availabilityData.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      }

      // Count total slots
      int totalSlots = 0;
      availability.forEach((day, slots) {
        if (slots is List) {
          totalSlots += slots.length;
        }
      });

      if (totalSlots == 0) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'No availability set',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(

          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Available Times ($totalSlots slots)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...availability.entries.map((entry) {
              final day = entry.key;
              final slots = entry.value;
              
              if (slots is! List || slots.isEmpty) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: slots.map<Widget>((slot) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[300]!),
                            ),
                            child: Text(
                              slot.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue[700],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    } catch (e) {
      // Fallback for any parsing errors
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Availability: ${availabilityData.toString()}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
  }
}
