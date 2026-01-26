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
  final bool isForwarded; // NEW: Add this property

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
    this.isForwarded = false, // NEW: Default to false
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  static const double _maxDrag = 70;
  static const double _replyTrigger = 45;

  void _handleDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx > 0) {
      setState(() {
        _dragOffset = (_dragOffset + details.delta.dx).clamp(0, _maxDrag);
      });
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragOffset >= _replyTrigger) {
      widget.onReply?.call();
    }

    setState(() {
      _dragOffset = 0;
    });
  }

  void _handleTap() {
    if (widget.onSelect != null) {
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
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Positioned(
          left: 12,
          child: Opacity(
            opacity: (_dragOffset / _replyTrigger).clamp(0, 1),
            child: const Icon(Icons.reply, color: Colors.white70, size: 22),
          ),
        ),

        Transform.translate(
          offset: Offset(_dragOffset, 0),
          child: GestureDetector(
            onHorizontalDragUpdate: _handleDragUpdate,
            onHorizontalDragEnd: _handleDragEnd,
            onTap: _handleTap,
            onLongPress: _handleLongPress,
            child: Row(
              mainAxisAlignment:
                  widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.isMe && widget.showSelectionButtons)
                  _buildSelectionButton(),

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
                                        color: Colors.blue.withOpacity(0.5),
                                        width: 2,
                                      )
                                      : null,
                              boxShadow:
                                  widget.isHighlighted
                                      ? [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.3),
                                          blurRadius: 8,
                                          spreadRadius: 2,
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
                        // NEW: Forwarded indicator
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

                if (widget.isMe && widget.showSelectionButtons)
                  _buildSelectionButton(),
              ],
            ),
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
          width: 25,
          height: 25,
          color: Colors.grey,
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
      onTap: _handleTap,
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
      onLongPress: _handleLongPress,
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
                      widget.isRead
                          ? Colors.blue
                          : Colors.white.withOpacity(0.5),
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
          onLongPress: _handleLongPress,
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
                                  ? Colors.blue
                                  : Colors.white.withOpacity(0.5),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isForwarded) ...[
          _buildForwardedIndicator(),
          const SizedBox(height: 6),
        ],
        AudioPlayerWidget(
          audioUrl: widget.audioUrl!,
          duration: widget.audioDuration ?? Duration.zero,
          time: widget.time,
          isMe: widget.isMe,
          isRead: widget.isRead,
          isPlaying: widget.isPlaying,
          onPlayPressed: widget.onVoicePlayPressed,
          onLongPress: _handleLongPress,
        ),
      ],
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
