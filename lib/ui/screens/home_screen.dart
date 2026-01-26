import 'package:flutter/material.dart';
import 'chats/chats_screen.dart';
import 'calls/calls_screen.dart';
import 'post/post_screen.dart';
import 'shops/shops_screen.dart';
import 'settings/settings_screen.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1; // Default to Chats
  int _totalUnreadCount = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // Method to update unread count from ChatsScreen
  void _updateUnreadCount(int count) {
    if (mounted) {
      setState(() {
        _totalUnreadCount = count;
      });
    }
  }

  // Build the current screen based on index
  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return const ShopsScreen();
      case 1:
        return ChatsScreen(onUnreadCountUpdated: _updateUnreadCount);
      case 2:
        return const PostScreen();
      case 3:
        return const CallsScreen();
      case 4:
        return const SettingsScreen();
      default:
        return ChatsScreen(onUnreadCountUpdated: _updateUnreadCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentScreen(),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        totalUnreadCount: _totalUnreadCount,
      ),
    );
  }
}
