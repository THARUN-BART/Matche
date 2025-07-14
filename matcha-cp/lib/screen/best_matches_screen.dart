import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../service/matching_service.dart';
import '../service/firestore_service.dart';
import '../widget/skeleton_loading.dart';

class BestMatchesScreen extends StatelessWidget {
  const BestMatchesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final matchingService = Provider.of<MatchingService>(context, listen: false);
    final userId = firestoreService.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Best Peer Matches', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: RefreshIndicator(
          onRefresh: () async {
            // Optionally, you can trigger a reload in your services if needed
            // For now, just wait a moment to simulate refresh
            await Future.delayed(Duration(milliseconds: 500));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SvgPicture.asset('Assets/Group.svg', height: 40),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Best Peer Matches', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Based on your profile and preferences', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder(
                  stream: firestoreService.getUserConnections(),
                  builder: (context, connectionsSnapshot) {
                    final connectedUserIds = <String>{};
                    if (connectionsSnapshot.hasData) {
                      for (var doc in connectionsSnapshot.data?.docs ?? []) {
                        connectedUserIds.add(doc.id);
                      }
                    }
                    return StreamBuilder(
                      stream: firestoreService.getSentConnectionRequests(),
                      builder: (context, sentSnapshot) {
                        final sentRequestUserIds = <String>{};
                        if (sentSnapshot.hasData) {
                          for (var doc in sentSnapshot.data?.docs ?? []) {
                            sentRequestUserIds.add(doc.id);
                          }
                        }
                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: userId != null
                              ? matchingService.getClusterMatches(userId, top: 20)
                              : Future.value([]),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Center(child: Text('Error loading peers'));
                            }
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SkeletonMatchListVertical(itemCount: 5);
                            }
                            final matches = snapshot.data ?? [];
                            final filteredMatches = matches.where((match) {
                              final uid = match['uid'] as String?;
                              return uid != null && !connectedUserIds.contains(uid);
                            }).toList();

                            if (filteredMatches.isEmpty) {
                              return const Center(child: Text('No new compatible peers found.'));
                            }

                            return ListView.separated(
                              itemCount: filteredMatches.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final match = filteredMatches[index];
                                return FutureBuilder<Map<String, dynamic>>(
                                  future: matchingService.getUserDetails(match['uid']),
                                  builder: (context, userSnapshot) {
                                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                                      return Card(child: ListTile(title: Text('Loading...')));
                                    }
                                    if (userSnapshot.hasError || userSnapshot.data == null) {
                                      return Card(child: ListTile(title: Text('Error')));
                                    }
                                    final user = userSnapshot.data!;
                                    return Card(
                                      elevation: 3,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24),side: BorderSide(color: Color(0xFFFFEC3D), width: 2),),
                                      child: ListTile(
                                        leading: GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: Text(user['name'] ?? 'Unknown'),
                                                content: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Gender: ${user['gender'] ?? 'Not specified'}'),
                                                    const SizedBox(height: 8),
                                                    Text('Skills:'),
                                                    if (user['skills'] is List && (user['skills'] as List).isNotEmpty)
                                                      Wrap(
                                                        spacing: 6,
                                                        children: (user['skills'] as List)
                                                            .map<Widget>((skill) => Chip(label: Text(skill.toString())))
                                                            .toList(),
                                                      )
                                                    else
                                                      const Text('No skills listed'),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx),
                                                    child: const Text('Close'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          child: CircleAvatar(
                                            backgroundColor: Color(0xFFFFEC3D),
                                            child: Text(
                                              user['name']?.substring(0, 1).toUpperCase() ?? 'U',
                                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
                                            ),
                                          ),
                                        ),
                                        title: Text(user['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text('Similarity: ${match['similarity']}%'),
                                        trailing: _buildConnectionButton(
                                          context,
                                          user['uid'] ?? '',
                                          user['name'] ?? 'Unknown',
                                          connectedUserIds,
                                          sentRequestUserIds,
                                          firestoreService,
                                        ),
                                        onTap: () {
                                          // Optionally open profile or chat
                                        },
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionButton(BuildContext context, String userId, String userName, Set<String> connectedUserIds, Set<String> sentRequestUserIds, FirestoreService firestoreService) {
    if (connectedUserIds.contains(userId)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
            const SizedBox(width: 4),
            Text(
              'Connected',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    if (sentRequestUserIds.contains(userId)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 4),
            Text(
              'Pending',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    return ElevatedButton(
      onPressed: () async {
        try {
          await firestoreService.sendConnectionRequest(firestoreService.currentUserId, userId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connection request sent to $userName!'), backgroundColor: Colors.green),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sending request: $e'), backgroundColor: Colors.red),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFFFEC3D),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: const Text(
        'Connect',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
} 