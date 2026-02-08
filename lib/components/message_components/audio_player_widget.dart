import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final Duration duration;
  final String time;
  final bool isMe;
  final bool isRead;
  final bool? isPlaying;
  final Future<void> Function()? onPlayPressed;
  final VoidCallback onLongPress;
  final String? profileImageUrl;
  final String? userName;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.duration,
    required this.time,
    required this.isMe,
    required this.isRead,
    this.isPlaying,
    this.onPlayPressed,
    required this.onLongPress,
    this.profileImageUrl,
    this.userName,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  bool _initialized = false;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.isPlaying ?? false;

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (widget.onPlayPressed == null) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _audioPlayer.onPositionChanged.listen((pos) {
      setState(() => _currentPosition = pos);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _currentPosition = Duration.zero;
        _isPlaying = false;
      });
    });
  }

  Future<void> _toggle() async {
    if (widget.onPlayPressed != null) {
      await widget.onPlayPressed!();
      return;
    }

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (!_initialized) {
        await _audioPlayer.setSource(UrlSource(widget.audioUrl));
        _initialized = true;
      }
      await _audioPlayer.resume();
    }
  }

  void _toggleSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 2.0;
      } else {
        _playbackSpeed = 1.0;
      }
    });
    _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  double get _progress {
    if (widget.duration.inMilliseconds == 0) return 0;
    return _currentPosition.inMilliseconds / widget.duration.inMilliseconds;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        widget.isMe
            ? const Color.fromARGB(255, 16, 70, 151)
            : const Color(0xFF2A2F32);

    Color micIconColor;
    if (widget.isRead) {
      micIconColor = const Color(0xFF25D366);
    } else {
      micIconColor = widget.isMe ? Colors.grey : const Color(0xFF53BDEB);
    }

    final waveColor = Colors.white;
    final waveColorInactive = Colors.white54;

    return Container(
      constraints: BoxConstraints(
        // RESPONSIVE WIDTH FIX (prevents overflow on small screens)
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: widget.isMe ? const Radius.circular(12) : Radius.zero,
          bottomRight: widget.isMe ? Radius.zero : const Radius.circular(12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _toggle,
                child:
                    widget.isMe
                        ? _buildProfilePlayButton(micIconColor)
                        : _buildCircularPlayButton(bubbleColor, micIconColor),
              ),

              const SizedBox(width: 8),

              // Waveform always shrinks first
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final barCount = (constraints.maxWidth / 3.6).floor().clamp(
                      18,
                      36,
                    );

                    return SizedBox(
                      height: 24,
                      child: Row(
                        children: List.generate(barCount, (i) {
                          final active = (i / barCount) <= _progress;
                          final heights = [3, 6, 10, 14, 18, 14, 10, 6];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 0.8,
                            ),
                            child: Container(
                              width: 2,
                              height: heights[i % heights.length].toDouble(),
                              decoration: BoxDecoration(
                                color: active ? waveColor : waveColorInactive,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 6),

              // Speed badge
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 46),
                child: GestureDetector(
                  onTap: _toggleSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_playbackSpeed}x',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Row(
              children: [
                Text(
                  _isPlaying || _currentPosition.inSeconds > 0
                      ? _fmt(_currentPosition)
                      : _fmt(widget.duration),
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                const Spacer(),
                Text(
                  widget.time,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                if (widget.isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    color:
                        widget.isRead
                            ? const Color(0xFF25D366)
                            : Colors.white38,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePlayButton(Color micIconColor) {
    final ImageProvider avatarImage =
        widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty
            ? NetworkImage(widget.profileImageUrl!)
            : const AssetImage('assets/images/default_avatar.jpg');

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: Colors.grey[800],
          backgroundImage: avatarImage,
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.35),
          ),
        ),
        Icon(
          _isPlaying ? Icons.pause : Icons.play_arrow,
          size: 30,
          color: Colors.white,
        ),
        Positioned(
          bottom: -3,
          right: -2,
          child: Icon(Icons.mic, size: 20, color: micIconColor),
        ),
      ],
    );
  }

  Widget _buildCircularPlayButton(Color bubbleColor, Color micIconColor) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 16, 70, 151),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            size: 30,
            color: Colors.white,
          ),
        ),
        Positioned(
          bottom: -3,
          left: -2,
          child: Icon(Icons.mic, size: 20, color: micIconColor),
        ),
      ],
    );
  }
}
