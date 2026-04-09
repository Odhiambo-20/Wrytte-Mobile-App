import 'package:flutter/material.dart';
import 'package:wrytte/models/chat_models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final String content;
  final String time;
  final bool isMine;
  final bool showTail;
  final MessageStatus? status;

  static const Color _blue = Color(0xFF4DA3FF);
  static const Color _incoming = Color(0xFF23262C);
  static const Color _readGreen = Color(0xFF4CAF50);

  const MessageBubble({
    super.key,
    required this.content,
    required this.time,
    required this.isMine,
    this.showTail = true,
    this.status,
  });

  // ── Tail width / height ────────────────────────────────────────────────────
  static const double _tailW = 8.0;
  static const double _tailH = 10.0;

  @override
  Widget build(BuildContext context) {
    final Color bubbleColor = isMine ? _blue : _incoming;

    // The time+status widget that floats inline
    final Widget timeWidget = _buildTimeRow();

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // ── Tail (shown only on the first bubble of a group) ───────────
          if (!isMine && showTail) _buildTail(bubbleColor, incoming: true),

          // ── Bubble body ────────────────────────────────────────────────
          Flexible(
            child: Container(
              margin: EdgeInsets.only(
                // Leave room for tail on the opposite side
                left: (!isMine && showTail) ? 0 : (isMine ? 0 : _tailW),
                right: (isMine && showTail) ? 0 : (isMine ? _tailW : 0),
                top: showTail ? 6 : 2,
                bottom: 2,
              ),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(
                    isMine ? 18 : (showTail ? 2 : 18),
                  ),
                  bottomRight: Radius.circular(
                    isMine ? (showTail ? 2 : 18) : 18,
                  ),
                ),
              ),
              // ── WhatsApp trick: stack the time ghost under real text ───
              child: _BubbleContent(content: content, timeWidget: timeWidget),
            ),
          ),

          // ── Tail on the right (mine) ───────────────────────────────────
          if (isMine && showTail) _buildTail(bubbleColor, incoming: false),
        ],
      ),
    );
  }

  // ── Pointy tail clipped with a CustomClipper ──────────────────────────────

  Widget _buildTail(Color color, {required bool incoming}) {
    return ClipPath(
      clipper: _TailClipper(incoming: incoming),
      child: Container(width: _tailW, height: _tailH, color: color),
    );
  }

  // ── Time + status row ──────────────────────────────────────────────────────

  Widget _buildTimeRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          time,
          style: TextStyle(
            color: Colors.white.withOpacity(isMine ? 0.65 : 0.45),
            fontSize: 11,
            height: 1,
          ),
        ),
        if (isMine) ...[const SizedBox(width: 3), _buildStatusIcon()],
      ],
    );
  }

  Widget _buildStatusIcon() {
    switch (status) {
      case MessageStatus.sending:
        return Icon(
          Icons.access_time_rounded,
          size: 13,
          color: Colors.white.withOpacity(0.55),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.done,
          size: 14,
          color: Colors.white.withOpacity(0.65),
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 14,
          color: Colors.white.withOpacity(0.65),
        );
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 14, color: _readGreen);
      default:
        // fallback — treat as sent (double tick, white)
        return Icon(
          Icons.done_all,
          size: 14,
          color: Colors.white.withOpacity(0.65),
        );
    }
  }
}

// ── BubbleContent ─────────────────────────────────────────────────────────────
//
// The WhatsApp trick: paint an invisible "ghost" of the time row at the END
// of the text so the real text naturally wraps away from it, then overlay
// the real time row in the bottom-right corner.
//
// This makes short messages like "Hi" stay compact — the ghost forces the
// bubble just wide enough to fit the time on the same visual line.

class _BubbleContent extends StatelessWidget {
  final String content;
  final Widget timeWidget;

  const _BubbleContent({required this.content, required this.timeWidget});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Real text with invisible ghost appended ──────────────────────
        Padding(
          // bottom padding reserves space for the time row so it never
          // covers the last line when the message is very long
          padding: const EdgeInsets.only(bottom: 0),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                // Invisible spacer — same width/height as the time row so
                // the text wraps before it would overlap the timestamp.
                WidgetSpan(
                  child: Opacity(
                    opacity: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: timeWidget,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Real time row pinned bottom-right ────────────────────────────
        Positioned(bottom: 0, right: 0, child: timeWidget),
      ],
    );
  }
}

// ── Tail clipper ──────────────────────────────────────────────────────────────

class _TailClipper extends CustomClipper<Path> {
  final bool incoming;
  const _TailClipper({required this.incoming});

  @override
  Path getClip(Size size) {
    final path = Path();
    if (incoming) {
      // Points LEFT (incoming)
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
    } else {
      // Points RIGHT (mine / outgoing)
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(_TailClipper old) => old.incoming != incoming;
}
