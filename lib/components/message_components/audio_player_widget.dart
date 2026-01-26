import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final Duration duration;
  final String time;
  final bool isMe;
  final bool isRead;
  final bool? isPlaying; // New: for external control
  final Future<void> Function()? onPlayPressed; // New: for external control

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.duration,
    required this.time,
    required this.isMe,
    required this.isRead,
    this.isPlaying,
    this.onPlayPressed,
    required void Function() onLongPress,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
    _isPlaying = widget.isPlaying ?? false;
  }

  @override
  void didUpdateWidget(covariant AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update playing state if controlled externally
    if (oldWidget.isPlaying != widget.isPlaying) {
      setState(() {
        _isPlaying = widget.isPlaying ?? false;
      });
    }
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      // Only update if not externally controlled
      if (widget.onPlayPressed == null) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _currentPosition = Duration.zero;
        if (widget.onPlayPressed == null) {
          _isPlaying = false;
        }
      });
    });
  }

  Future<void> _togglePlayPause() async {
    // If external control is provided, use it
    if (widget.onPlayPressed != null) {
      await widget.onPlayPressed!();
      return;
    }

    // Otherwise use internal audio player
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (!_isInitialized) {
        await _audioPlayer.setSource(UrlSource(widget.audioUrl));
        _isInitialized = true;
      }
      await _audioPlayer.resume();
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
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isMe ? const Color(0xFF404040) : const Color(0xFF404040),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
          bottomLeft:
              widget.isMe ? const Radius.circular(8) : const Radius.circular(0),
          bottomRight:
              widget.isMe ? const Radius.circular(0) : const Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play/Pause Button
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.isMe ? const Color(0xFF0078FF) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 8),
              // Waveform and Progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Waveform visualization (simplified as bars)
                    SizedBox(
                      height: 24,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(30, (index) {
                          final heights = [
                            0.3,
                            0.6,
                            0.8,
                            0.5,
                            0.9,
                            0.4,
                            0.7,
                            0.6,
                            0.5,
                            0.8,
                            0.7,
                            0.4,
                            0.6,
                            0.9,
                            0.5,
                            0.7,
                            0.6,
                            0.4,
                            0.8,
                            0.5,
                            0.7,
                            0.6,
                            0.9,
                            0.4,
                            0.7,
                            0.5,
                            0.8,
                            0.6,
                            0.4,
                            0.7,
                          ];
                          final isPlayed = (index / 30) <= _progress;
                          return Container(
                            width: 2,
                            height: 24 * heights[index % heights.length],
                            decoration: BoxDecoration(
                              color:
                                  isPlayed
                                      ? (widget.isMe
                                          ? const Color(0xFF0078FF)
                                          : Colors.white)
                                      : (widget.isMe
                                          ? const Color(
                                            0xFF87CEEB,
                                          ).withOpacity(0.4)
                                          : Colors.grey.withOpacity(0.4)),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Duration
                    Text(
                      _isPlaying || _currentPosition.inSeconds > 0
                          ? _formatDuration(_currentPosition)
                          : _formatDuration(widget.duration),
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isMe ? Colors.white : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Time and Read Status
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                widget.time,
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isMe ? Colors.white : Colors.white,
                ),
              ),
              if (widget.isMe) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.done_all,
                  size: 14,
                  color:
                      widget.isRead
                          ? const Color(0xFF53BDEB)
                          : Colors.grey[500],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
