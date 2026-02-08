import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/svg.dart';
import 'package:wrytte/components/message_components/audio_player_widget.dart';

class MessageBubble extends StatefulWidget {
  final String messageId;
  final String text;
  final String time;
  final bool isMe;
  final bool isRead;
  final Map<String, dynamic>? replyData;
  final bool isHighlighted;
  final VoidCallback? onReply;
  final VoidCallback? onReplyTap;
  final String? imageUrl;
  final String? audioUrl;
  final Duration? audioDuration;
  final String messageType;
  final bool? isPlaying;
  final Future<void> Function()? onVoicePlayPressed;
  final bool isSelected;
  final VoidCallback? onSelect;
  final VoidCallback? onLongPress;
  final bool showSelectionButtons;
  final bool isForwarded;
  final String? profileImageUrl;
  final String? userName; // For voice note profile fallback

  const MessageBubble({
    super.key,
    required this.messageId,
    required this.text,
    required this.time,
    required this.isMe,
    this.isRead = false,
    this.replyData,
    this.isHighlighted = false,
    this.onReply,
    this.onReplyTap,
    this.imageUrl,
    this.audioUrl,
    this.audioDuration,
    this.messageType = 'text',
    this.isPlaying,
    this.onVoicePlayPressed,
    this.isSelected = false,
    this.onSelect,
    this.onLongPress,
    this.showSelectionButtons = false,
    this.isForwarded = false,
    this.profileImageUrl,
    this.userName,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  static const double _maxDrag = 70;
  static const double _replyTrigger = 45;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    // Allow dragging in both directions (right and left)
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(0, _maxDrag);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    // Check if velocity is significant and in the left direction
    if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
      // Quick swipe left - reset immediately
      _resetDrag();
    } else if (_dragOffset >= _replyTrigger) {
      // If dragged past trigger point, trigger reply
      widget.onReply?.call();
      _resetDrag();
    } else {
      // If not past trigger, animate back to original position
      _resetDrag();
    }
  }

  void _resetDrag() {
    if (_dragOffset > 0) {
      _animationController.forward(from: 0);
      _animationController.addListener(() {
        setState(() {
          _dragOffset = _dragOffset * (1 - _animationController.value);
        });
      });

      _animationController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _dragOffset = 0;
          });
          _animationController.removeListener(() {});
          _animationController.removeStatusListener((status) {});
        }
      });
    }
  }

  void _handleTap() {
    // Only trigger selection if selection buttons are shown (selection mode is active)
    if (widget.showSelectionButtons && widget.onSelect != null) {
      widget.onSelect!();
    }
  }

  void _handleLongPress() {
    if (widget.onLongPress != null) {
      widget.onLongPress!();
    } else if (widget.onReply != null) {
      widget.onReply!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selection button for ALL messages (both sent and received) - ALWAYS on the left
        if (widget.showSelectionButtons) _buildSelectionButton(),

        // The message content that can slide
        Expanded(
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Reply icon that fades in as you drag
              Positioned(
                left: widget.showSelectionButtons ? 12 : 0,
                child: Opacity(
                  opacity: (_dragOffset / _replyTrigger).clamp(0, 1),
                  child: Transform.translate(
                    offset: Offset(-10 + (_dragOffset / _maxDrag * 10), 0),
                    child: Transform.scale(
                      scale: 0.8 + (_dragOffset / _maxDrag * 0.2),
                      child: const Icon(
                        Icons.reply,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),

              // The main message bubble that slides
              Transform.translate(
                offset: Offset(_dragOffset, 0),
                child: GestureDetector(
                  onHorizontalDragUpdate: _handleDragUpdate,
                  onHorizontalDragEnd: _handleDragEnd,
                  onTap: _handleTap,
                  onLongPress: _handleLongPress,
                  child: Row(
                    mainAxisAlignment:
                        widget.isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Spacer to push sent messages to the right while keeping them in the same Row
                      if (widget.isMe) Expanded(child: Container()),

                      // Message content container
                      Align(
                        alignment:
                            widget.isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          padding:
                              widget.messageType == 'text'
                                  ? const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  )
                                  : EdgeInsets.zero,
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width *
                                (widget.messageType == 'text' ? 0.75 : 0.65),
                          ),
                          decoration:
                              widget.messageType == 'text'
                                  ? BoxDecoration(
                                    color:
                                        widget.isHighlighted
                                            ? (widget.isMe
                                                ? const Color(0xFF1E6DC7)
                                                : const Color(0xFF404040))
                                            : (widget.isMe
                                                ? const Color(0xFF0078FF)
                                                : const Color(0xFF2C2C2E)),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft:
                                          widget.isMe
                                              ? const Radius.circular(16)
                                              : const Radius.circular(4),
                                      bottomRight:
                                          widget.isMe
                                              ? const Radius.circular(4)
                                              : const Radius.circular(16),
                                    ),
                                    border:
                                        widget.isHighlighted
                                            ? Border.all(
                                              color: Colors.blue.withOpacity(
                                                0.5,
                                              ),
                                              width: 2,
                                            )
                                            : null,
                                    boxShadow:
                                        widget.isHighlighted
                                            ? [
                                              BoxShadow(
                                                color: Colors.blue.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                            : widget.isMe
                                            ? [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                            : null,
                                  )
                                  : null,
                          child: Column(
                            crossAxisAlignment:
                                widget.isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                            children: [
                              // Forwarded indicator
                              if (widget.isForwarded) ...[
                                _buildForwardedIndicator(),
                                const SizedBox(height: 6),
                              ],
                              if (widget.replyData != null) ...[
                                _buildReplyPreview(),
                                if (widget.messageType == 'text')
                                  const SizedBox(height: 8),
                              ],
                              if (widget.messageType == 'text')
                                _buildTextMessage()
                              else if (widget.messageType == 'image')
                                _buildImageMessage(context)
                              else if (widget.messageType == 'audio' &&
                                  widget.audioUrl != null)
                                _buildAudioMessage(),
                            ],
                          ),
                        ),
                      ),

                      // Spacer for received messages
                      if (!widget.isMe) Expanded(child: Container()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForwardedIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/svg/forward.svg',
          width: 22,
          height: 22,
          color: Colors.white.withOpacity(0.7),
        ),
        const SizedBox(width: 4),
        Text(
          'Forwarded',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionButton() {
    return GestureDetector(
      onTap: widget.onSelect,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  widget.isSelected ? Colors.lightBlue : Colors.grey.shade600,
              width: 2,
            ),
            color: widget.isSelected ? Colors.lightBlue : Colors.transparent,
          ),
          child:
              widget.isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
        ),
      ),
    );
  }

  Widget _buildTextMessage() {
    return GestureDetector(
      onTap: _handleTap,
      child: Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.time,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              if (widget.isMe) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.done_all,
                  size: 12,
                  color:
                      widget.isRead ? const Color(0xFF25D366) : Colors.white38,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isForwarded) ...[
          _buildForwardedIndicator(),
          const SizedBox(height: 6),
        ],
        GestureDetector(
          onTap: _handleTap,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl!,
                  width: MediaQuery.of(context).size.width * 0.65,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 12,
                          color:
                              widget.isRead
                                  ? const Color(0xFF25D366)
                                  : Colors.white38,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioMessage() {
    return AudioPlayerWidget(
      audioUrl: widget.audioUrl!,
      duration: widget.audioDuration ?? Duration.zero,
      time: widget.time,
      isMe: widget.isMe,
      isRead: widget.isRead,
      isPlaying: widget.isPlaying,
      onPlayPressed: widget.onVoicePlayPressed,
      onLongPress: _handleLongPress,
      profileImageUrl: widget.profileImageUrl,
      userName: widget.userName, // Pass username
    );
  }

  Widget _buildReplyPreview() {
    final replyText = widget.replyData?['replyToText'] ?? '';
    final senderName = widget.replyData?['replyToSenderName'] ?? 'User';
    return GestureDetector(
      onTap: widget.onReplyTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: widget.isMe ? Colors.white : Colors.blue,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              senderName,
              style: TextStyle(
                color: widget.isMe ? Colors.white : Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              replyText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
