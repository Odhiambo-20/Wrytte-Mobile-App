import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(String) onSendVoiceMessage;
  final VoidCallback onCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onSendVoiceMessage,
    required this.onCancel,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _audioPath;
  bool _isRecorderReady = false;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    try {
      // Request microphone permission
      final permissionStatus = await Permission.microphone.request();

      if (!permissionStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
        widget.onCancel();
        return;
      }

      // Initialize the recorder
      await _audioRecorder.openRecorder();
      setState(() {
        _isRecorderReady = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing recorder: $e')),
        );
      }
      widget.onCancel();
    }
  }

  Future<void> _startRecording() async {
    if (!_isRecorderReady) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';

      await _audioRecorder.startRecorder(toFile: path, codec: Codec.aacADTS);

      setState(() {
        _isRecording = true;
        _audioPath = path;
        _recordingDuration = Duration.zero;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      await _audioRecorder.stopRecorder();
      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to stop recording: $e')));
      }
    }
  }

  Future<void> _playRecording() async {
    if (_audioPath == null || !File(_audioPath!).existsSync()) return;

    try {
      setState(() {
        _isPlaying = true;
      });

      await _audioPlayer.play(DeviceFileSource(_audioPath!));

      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          _isPlaying = false;
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to play recording: $e')));
      }
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _stopPlaying() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to stop playback: $e')));
      }
    }
  }

  Future<void> _sendVoiceMessage() async {
    if (_audioPath == null || !File(_audioPath!).existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No recording to send')));
      }
      return;
    }

    try {
      widget.onSendVoiceMessage(_audioPath!);
      setState(() {
        _audioPath = null;
        _recordingDuration = Duration.zero;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice message: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.closeRecorder();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1D2C),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          // Cancel button
          IconButton(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 8),

          // Recording/Playback controls
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isRecording ? 'Recording...' : 'Voice message',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(_recordingDuration),
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ),

          // Action buttons
          if (_isRecording) ...[
            IconButton(
              onPressed: _stopRecording,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.stop, color: Colors.white, size: 20),
              ),
            ),
          ] else if (_audioPath != null) ...[
            IconButton(
              onPressed: _isPlaying ? _stopPlaying : _playRecording,
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 24,
              ),
            ),
            IconButton(
              onPressed: _sendVoiceMessage,
              icon: const Icon(Icons.send, color: Colors.blue, size: 24),
            ),
          ] else ...[
            IconButton(
              onPressed: _isRecorderReady ? _startRecording : null,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isRecorderReady ? Colors.red : Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.mic, color: Colors.white, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
