import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wrytte/components/contact_components/firebase_new_chat_item.dart';
import 'package:wrytte/models/user_models/user_profile_service.dart';
import 'package:wrytte/services/chat/firebase_chat_service.dart';
import 'package:wrytte/ui/screens/chats/chat_screen.dart';
import 'package:wrytte/ui/screens/new_contact_screen.dart';

class FirebaseNewChatScreen extends StatefulWidget {
  const FirebaseNewChatScreen({super.key});

  @override
  State<FirebaseNewChatScreen> createState() => _FirebaseNewChatScreenState();
}

class _FirebaseNewChatScreenState extends State<FirebaseNewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<UserProfile> _allUsers = [];
  List<UserProfile> _filteredUsers = [];
  bool _isLoading = true;
  String _error = '';
  double _searchBarProgress = 0.0;

  static const double _kSearchBarHeight = 60.0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final progress = (offset / _kSearchBarHeight).clamp(0.0, 1.0);
    if ((progress - _searchBarProgress).abs() > 0.005) {
      setState(() => _searchBarProgress = progress);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers =
          _allUsers.where((u) {
            return u.displayName.toLowerCase().contains(query) ||
                u.phone.toLowerCase().contains(query) ||
                u.username.toLowerCase().contains(query);
          }).toList();
    });
  }

  // ── Fetch all users from Firestore, excluding the current user ────────────

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();

      final users =
          snapshot.docs
              .where((doc) => doc.id != currentUid)
              .map((doc) => UserProfile.fromMap(doc.id, doc.data()))
              .toList();

      users.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Navigate to chat using FirebaseChatService ────────────────────────────

  Future<void> _navigateToChat(UserProfile user) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null || currentUserId.isEmpty) {
      debugPrint('Cannot open chat: no authenticated Firebase user');
      return;
    }

    // Build deterministic conversation ID the same way FirebaseChatService does
    final conversationId = FirebaseChatService.buildConversationId(
      currentUserId,
      user.uid,
    );

    if (!mounted) return;

    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ChatScreen(
              conversationId: conversationId,
              receiverId: user.uid,
              currentUserId: currentUserId,
              title: user.displayName,
              avatarUrl: user.hasProfileImage ? user.profileImage : null,
              // chatState intentionally omitted → Firebase mode activated
            ),
      ),
    );
  }

  // ── Group users by first letter of display name ───────────────────────────

  Map<String, List<UserProfile>> _groupByAlphabet(List<UserProfile> users) {
    final Map<String, List<UserProfile>> grouped = {};
    for (final user in users) {
      final letter =
          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '#';
      grouped.putIfAbsent(letter, () => []).add(user);
    }
    final keys = grouped.keys.toList()..sort();
    return Map.fromEntries(keys.map((k) => MapEntry(k, grouped[k]!)));
  }

  // ── User list slivers ─────────────────────────────────────────────────────

  List<Widget> _buildUserSlivers() {
    if (_isLoading) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF4DA3FF)),
                  SizedBox(height: 16),
                  Text(
                    'Loading Wrytte users...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    if (_error.isNotEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
              child: Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ];
    }

    if (_filteredUsers.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(
              child: Text(
                'No users found',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ),
        ),
      ];
    }

    final slivers = <Widget>[];
    final grouped = _groupByAlphabet(_filteredUsers);

    for (final entry in grouped.entries) {
      slivers.add(SliverToBoxAdapter(child: _sectionHeader(entry.key)));
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => FirebaseNewChatItem(
              user: entry.value[i],
              onTap: () => _navigateToChat(entry.value[i]),
            ),
            childCount: entry.value.length,
          ),
        ),
      );
    }

    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double headerHeight =
        statusBarHeight + kToolbarHeight + _kSearchBarHeight + 8.0;

    final double searchBarOffset = _kSearchBarHeight * _searchBarProgress;
    final double gradientHeight = headerHeight - searchBarOffset;

    return Scaffold(
      backgroundColor: const Color(0xFF08090B),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Layer 1: scrollable content ───────────────────────────────────
          Positioned.fill(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: headerHeight)),

                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _actionItem(Icons.group_outlined, 'New group'),
                      _actionItem(Icons.person_add_outlined, 'New contact'),
                      _actionItem(Icons.campaign_outlined, 'New channel'),
                    ],
                  ),
                ),

                ..._buildUserSlivers(),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),

          // ── Layer 2: gradient ─────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: gradientHeight,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.6, 1.0],
                    colors: [
                      const Color(0xFF08090B).withOpacity(0.95),
                      const Color(0xFF08090B).withOpacity(0.75),
                      const Color(0xFF08090B).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Layer 3: floating header ──────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTopBar(statusBarHeight),
                Transform.translate(
                  offset: Offset(0, -searchBarOffset),
                  child: Opacity(
                    opacity: (1.0 - _searchBarProgress).clamp(0.0, 1.0),
                    child: SizedBox(
                      height: _kSearchBarHeight,
                      child: _buildSearchBar(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(double statusBarHeight) {
    return SizedBox(
      height: statusBarHeight + kToolbarHeight,
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1013),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'New chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
        ),
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF23262C),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            if (_searchController.text.isEmpty)
              IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.search, color: Colors.grey, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Action item ───────────────────────────────────────────────────────────

  Widget _actionItem(IconData icon, String title) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: const Color(0xFF4DA3FF), size: 28),
          title: Text(
            title,
            style: const TextStyle(color: Color(0xFF4DA3FF), fontSize: 18),
          ),
          onTap: () {
            if (title == 'New contact') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => const NewContactPage(token: '<YOUR_BEARER_TOKEN>'),
                ),
              );
            }
          },
        ),
        const Padding(
          padding: EdgeInsets.only(left: 72),
          child: Divider(height: 1, color: Color(0xFF2A2A2A)),
        ),
      ],
    );
  }

  // ── Section header ────────────────────────────────────────────────────────

  Widget _sectionHeader(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: const Color(0xFF1A1A1A),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}
