import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:wrytte/components/user_avatar.dart';

enum _CallType { incoming, outgoing, missed }

class _DummyCall {
  final String name;
  final _CallType type;
  final String time;
  final bool isVideo;

  const _DummyCall({
    required this.name,
    required this.type,
    required this.time,
    this.isVideo = false,
  });
}

const List<_DummyCall> _dummyCalls = [
  _DummyCall(name: 'John Doe', type: _CallType.outgoing, time: 'Today'),
  _DummyCall(name: 'Alice Johnson', type: _CallType.incoming, time: 'Today'),
  _DummyCall(name: 'Bob Martinez', type: _CallType.missed, time: 'Today'),
  _DummyCall(
    name: 'Carol White',
    type: _CallType.outgoing,
    time: 'Yesterday',
    isVideo: true,
  ),
  _DummyCall(name: 'David Kim', type: _CallType.incoming, time: 'Yesterday'),
  _DummyCall(name: 'Emma Clarke', type: _CallType.missed, time: 'Yesterday'),
  _DummyCall(name: 'Frank Osei', type: _CallType.outgoing, time: 'Mon'),
  _DummyCall(
    name: 'Grace Nakamura',
    type: _CallType.incoming,
    time: 'Mon',
    isVideo: true,
  ),
  _DummyCall(name: 'Henry Brooks', type: _CallType.missed, time: 'Mon'),
  _DummyCall(name: 'Isla Fernandez', type: _CallType.outgoing, time: 'Sun'),
  _DummyCall(name: 'James Owusu', type: _CallType.incoming, time: 'Sun'),
  _DummyCall(name: 'Karen Lee', type: _CallType.missed, time: 'Sun'),
  _DummyCall(
    name: 'Liam Patel',
    type: _CallType.outgoing,
    time: 'Sat',
    isVideo: true,
  ),
  _DummyCall(name: 'Mia Dubois', type: _CallType.incoming, time: 'Sat'),
  _DummyCall(name: 'Noah Mensah', type: _CallType.missed, time: 'Fri'),
  _DummyCall(name: 'Olivia Turner', type: _CallType.outgoing, time: 'Fri'),
  _DummyCall(name: 'Paul Nguyen', type: _CallType.incoming, time: 'Thu'),
  _DummyCall(name: 'Quinn Hassan', type: _CallType.missed, time: 'Thu'),
  _DummyCall(
    name: 'Rachel Stone',
    type: _CallType.outgoing,
    time: 'Wed',
    isVideo: true,
  ),
  _DummyCall(name: 'Samuel Addo', type: _CallType.incoming, time: 'Wed'),
];

const double _kSearchBarHeight = 60.0;

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  final ScrollController _scrollController = ScrollController();
  double _searchBarProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final progress = (offset / _kSearchBarHeight).clamp(0.0, 1.0);
    if ((progress - _searchBarProgress).abs() > 0.005) {
      setState(() => _searchBarProgress = progress);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildCallTile(_DummyCall call) {
    final isMissed = call.type == _CallType.missed;
    final nameColor = isMissed ? const Color(0xFFFF453A) : Colors.white;

    IconData directionIcon;
    Color directionColor;
    if (call.type == _CallType.outgoing) {
      directionIcon = Icons.call_made;
      directionColor = const Color(0xFF4DA3FF);
    } else if (call.type == _CallType.incoming) {
      directionIcon = Icons.call_received;
      directionColor = Colors.green;
    } else {
      directionIcon = Icons.call_missed;
      directionColor = const Color(0xFFFF453A);
    }

    final String directionLabel =
        call.type == _CallType.outgoing
            ? 'Outgoing'
            : call.type == _CallType.incoming
            ? 'Incoming'
            : 'Missed';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Avatar
              UserAvatar(size: 60, name: call.name),
              const SizedBox(width: 12),

              // Name + direction
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      call.name,
                      style: TextStyle(
                        color: nameColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(directionIcon, size: 14, color: directionColor),
                        const SizedBox(width: 4),
                        Text(
                          directionLabel,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        if (call.isVideo) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.videocam_outlined,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Time + call button
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    call.time,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    call.isVideo
                        ? Icons.videocam_outlined
                        : Icons.call_outlined,
                    color: const Color(0xFF4DA3FF),
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
        // Divider
        Padding(
          padding: const EdgeInsets.only(left: 80),
          child: Divider(height: 1, color: Colors.white.withOpacity(0.07)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double bottomNavHeight =
        80 + MediaQuery.of(context).padding.bottom + 16;

    const double _kTopBarHeight = kToolbarHeight;
    const double _kRecentLabelHeight = 36.0;

    final double headerHeight =
        statusBarHeight +
        _kTopBarHeight +
        _kSearchBarHeight +
        _kRecentLabelHeight +
        8.0;

    final double searchBarOffset = _kSearchBarHeight * _searchBarProgress;
    final double gradientHeight = headerHeight - searchBarOffset;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      extendBodyBehindAppBar: true,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomNavHeight - 80, right: 0),
        child: FloatingActionButton(
          onPressed: () {},
          backgroundColor: const Color(0xFF4DA3FF),
          child: const Icon(Icons.add_call, color: Colors.black),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          // ── Layer 1: scrollable call list ─────────────────────────────────
          Positioned.fill(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(top: headerHeight, bottom: 120),
              physics: const BouncingScrollPhysics(),
              itemCount: _dummyCalls.length,
              itemBuilder:
                  (context, index) => _buildCallTile(_dummyCalls[index]),
            ),
          ),

          // ── Layer 2: gradient scrim ───────────────────────────────────────
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

          // ── Layer 3: animated header ──────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar — fixed, never moves
                _CallsTopBar(statusBarHeight: statusBarHeight),

                // Search bar — slides up and fades with scroll
                Transform.translate(
                  offset: Offset(0, -searchBarOffset),
                  child: Opacity(
                    opacity: (1.0 - _searchBarProgress).clamp(0.0, 1.0),
                    child: const SizedBox(
                      height: _kSearchBarHeight,
                      child: _CallsSearchBar(),
                    ),
                  ),
                ),

                // "Recent calls" label — slides up with search bar then sticks
                Transform.translate(
                  offset: Offset(0, -searchBarOffset),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 4,
                      bottom: 8,
                    ),
                    child: Text(
                      'Recent calls',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _CallsTopBar extends StatelessWidget {
  final double statusBarHeight;
  const _CallsTopBar({required this.statusBarHeight});

  // Matches TopBar._pillHeight exactly
  static const double _pillHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: statusBarHeight + kToolbarHeight,
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Left & Right controls ───────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ── Edit pill — identical to TopBar edit pill ──────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        height: _pillHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF23262C).withOpacity(0.30),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFF23262C),
                            width: 1.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Edit',
                          style: TextStyle(
                            color: Color(0xFF4DA3FF),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── More vert pill — identical to TopBar icons pill ────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        width: _pillHeight,
                        height: _pillHeight,
                        decoration: BoxDecoration(
                          color: const Color(0xFF23262C).withOpacity(0.30),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFF23262C),
                            width: 1.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.more_vert,
                          color: Color(0xFF4DA3FF),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Perfectly centered title ───────────────────────────────
              const Text(
                'Calls',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _CallsSearchBar extends StatefulWidget {
  const _CallsSearchBar();

  @override
  State<_CallsSearchBar> createState() => _CallsSearchBarState();
}

class _CallsSearchBarState extends State<_CallsSearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _isTyping = _controller.text.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF23262C),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            if (!_isTyping)
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
}
