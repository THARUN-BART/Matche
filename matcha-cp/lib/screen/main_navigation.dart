import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'NavigationScreen/home_screen.dart';
import 'NavigationScreen/matches_screen.dart';
import 'NavigationScreen/messages_screen.dart';
import 'NavigationScreen/settings.dart';
import 'account_info.dart';
import '../service/notification_service.dart';
import '../service/firestore_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MatchesScreen(),
    const MessagesScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final notificationService = Provider.of<NotificationService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("MATCHE", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AccountInfo()),
            );
          },
          icon: const Icon(Icons.account_circle, size: 30),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: () => _showNotifications(context),
                icon: const Icon(Icons.notifications, size: 30),
              ),
              StreamBuilder<int>(
                stream: notificationService.badgeStream,
                builder: (context, snapshot) {
                  final badgeCount = snapshot.data ?? 0;
                  if (badgeCount == 0) return const SizedBox();
                  
                  return Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    notificationService.clearAllNotifications();
                    Navigator.pop(context);
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder(
                stream: firestoreService.getUnreadNotifications(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading notifications'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final notifications = snapshot.data?.docs ?? [];
                  if (notifications.isEmpty) {
                    return const Center(child: Text('No notifications'));
                  }

                  return ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index].data() as Map<String, dynamic>;
                      final notificationId = notifications[index].id;
                      
                      return ListTile(
                        leading: const Icon(Icons.notifications, color: Colors.deepPurple),
                        title: Text(notification['title'] ?? 'Notification'),
                        subtitle: Text(notification['body'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () {
                            notificationService.markNotificationAsRead(notificationId);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}