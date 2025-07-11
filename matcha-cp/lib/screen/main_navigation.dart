import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'NavigationScreen/home_screen.dart';
import 'NavigationScreen/matches_screen.dart';
import 'NavigationScreen/messages_screen.dart';
import 'NavigationScreen/settings.dart';
import 'account_info.dart';
import '../service/notification_service.dart';
import '../service/firestore_service.dart';
import '../widget/common_widget.dart';

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
  void initState() {
    super.initState();
    // Check if we need to navigate to a specific tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNavigationArguments();
    });
  }

  void _checkNavigationArguments() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      final tab = args['tab'] as String?;
      if (tab != null) {
        switch (tab) {
          case 'matches':
            setState(() => _currentIndex = 1);
            break;
          case 'messages':
            setState(() => _currentIndex = 2);
            break;
          case 'settings':
            setState(() => _currentIndex = 3);
            break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = Provider.of<NotificationService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "MATCHE",
          style: GoogleFonts.salsa(
            color: Color(0xFFFFEC3D),
            fontSize: 35,
            fontWeight: FontWeight.bold,
          ),
        ),
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
          StreamBuilder(
            stream: Provider.of<FirestoreService>(context, listen: false).getUnreadNotifications(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final unreadCount = docs.length;
              return IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications, size: 30),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => _showNotifications(context),
                tooltip: 'Notifications',
              );
            },
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
                  // Filter for unique group invitations by groupId
                  final uniqueInvites = <String, Map<String, dynamic>>{};
                  final uniqueOther = <String, Map<String, dynamic>>{};
                  for (var doc in notifications) {
                    final n = doc.data() as Map<String, dynamic>;
                    if (n['type'] == 'group_invite' && n['groupId'] != null) {
                      uniqueInvites[n['groupId']] = n;
                    } else if (n['type'] != 'group_invite') {
                      uniqueOther[doc.id] = n;
                    }
                  }
                  if (uniqueInvites.isEmpty && uniqueOther.isEmpty) {
                    return const Center(child: Text('No notifications'));
                  }
                  return ListView(
                    children: [
                      // Show unique group invitations first
                      ...uniqueInvites.values.map((n) => ListTile(
                        leading: const Icon(Icons.group_add, color: Colors.deepPurple),
                        title: Text(n['title'] ?? 'Group Invitation'),
                        subtitle: Text(n['body'] ?? ''),
                        trailing: Icon(Icons.group, color: Colors.green),
                      )),
                      // Show other unique notifications
                      ...uniqueOther.values.map((n) => ListTile(
                        leading: const Icon(Icons.notifications, color: Colors.deepPurple),
                        title: Text(n['title'] ?? 'Notification'),
                        subtitle: Text(n['body'] ?? ''),
                        trailing: Icon(Icons.check, color: Colors.green),
                      )),
                    ],
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