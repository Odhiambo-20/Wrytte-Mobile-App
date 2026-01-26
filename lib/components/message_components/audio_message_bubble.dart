import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioMessageBubble extends StatefulWidget {
  final String audioUrl;
  final String time;
  final bool isMe;
  final bool isRead;
  final Duration duration;
  final Map<String, dynamic>? replyData;

  const AudioMessageBubble({
    super.key,
    required this.audioUrl,
    required this.time,
    required this.isMe,
    this.isRead = false,
    required this.duration,
    this.replyData,
  });

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.audioUrl));
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  double get _progress {
    if (widget.duration.inMilliseconds == 0) return 0;
    return _currentPosition.inMilliseconds / widget.duration.inMilliseconds;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        child: Column(
          crossAxisAlignment:
              widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Reply preview if exists
            if (widget.replyData != null) ...[
              _buildReplyPreview(),
              const SizedBox(height: 8),
            ],

            // Audio player container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:
                    widget.isMe
                        ? const Color(0xFF0078FF)
                        : const Color(0xFF2C2C2C),
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
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Play/Pause button
                  IconButton(
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Progress bar and time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150,
                        child: LinearProgressIndicator(
                          value: _progress,
                          // ignore: deprecated_member_use
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatDuration(_currentPosition)} / ${_formatDuration(widget.duration)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Time and read receipt
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.time,
                        style: TextStyle(
                          fontSize: 11,
                          // ignore: deprecated_member_use
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      if (widget.isMe) ...[
                        const SizedBox(height: 2),
                        Icon(
                          Icons.done_all,
                          size: 12,
                          color:
                              widget.isRead
                                  ? Colors.blue
                                  // ignore: deprecated_member_use
                                  : Colors.white.withOpacity(0.5),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    final senderName = widget.replyData?['replyToSenderName'] ?? 'User';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
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
            'Voice message',
            style: TextStyle(
              // ignore: deprecated_member_use
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
