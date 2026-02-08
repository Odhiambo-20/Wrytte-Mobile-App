import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wrytte/services/call_service.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceCallScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;
  final String callId;
  final bool isIncomingCall;

  const VoiceCallScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverAvatar,
    required this.callId,
    this.isIncomingCall = false,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  final CallService _callService = CallService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Timer? _callTimer;
  int _callDuration = 0;
  bool _isCallConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  String _callStatus = 'calling';
  bool _isProcessing = false; // Track if we're processing a call action

  @override
  void initState() {
    super.initState();
    _initializeCall();
    _startCallTimer();

    if (!widget.isIncomingCall) {
      _playCallingTone();
    }
  }

  void _initializeCall() {
    // Listen for call status updates
    _callService.getCallStream(widget.callId).listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'calling';

        setState(() {
          _callStatus = status;
        });

        if (status == 'accepted') {
          _onCallAccepted();
        } else if (status == 'rejected') {
          _onCallRejected();
        } else if (status == 'ended') {
          _endCall();
        }
      }
    });
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isCallConnected) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  void _playCallingTone() async {
    // to add a calling tone audio file
    // await _audioPlayer.play(AssetSource('audio/calling_tone.mp3'));
  }

  void _stopCallingTone() {
    _audioPlayer.stop();
  }

  void _onCallAccepted() {
    setState(() {
      _isCallConnected = true;
      _callStatus = 'accepted';
    });
    _stopCallingTone();
  }

  void _onCallRejected() {
    _stopCallingTone();
    _navigateBack();
  }

  Future<void> _acceptCall() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      await _callService.acceptCall(widget.callId);
      setState(() {
        _isCallConnected = true;
        _callStatus = 'accepted';
      });
      _stopCallingTone();
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _rejectCall() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      await _callService.rejectCall(widget.callId);
      _navigateBack();
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _endCall() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      await _callService.endCall(widget.callId, _callDuration);
      _navigateBack();
    } catch (e) {
      print('Error ending call: $e');
      // Even if call update fails, still close the screen
      _navigateBack();
    } finally {
      _isProcessing = false;
    }
  }

  void _navigateBack() {
    if (!mounted) return;

    // Using a microtask to ensure navigation happens after current frame
    Future.microtask(() {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _toggleMute() {
    if (_isProcessing) return;
    setState(() {
      _isMuted = !_isMuted;
    });
    // to Implement actual mute functionality
  }

  void _toggleSpeaker() {
    if (_isProcessing) return;
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    // to Implement speaker functionality
  }

  // New method for video call button (placeholder)
  void _onVideoCallPressed() {
    if (_isProcessing) return;
    // This will be implemented later
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video call functionality coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // New method for minimize button
  void _onMinimizePressed() {
    if (_isProcessing) return;
    _navigateBack();
  }

  // New method for contact button
  void _onContactPressed() {
    if (_isProcessing) return;
    // This would open the contact details
    // For now, show a placeholder dialog
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Contact Info'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: ${widget.receiverName}'),
                const SizedBox(height: 8),
                Text('ID: ${widget.receiverId}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _audioPlayer.dispose();
    // Make sure to end the call if screen is disposed while call is active
    if (_isCallConnected && !_isProcessing) {
      _callService.endCall(widget.callId, _callDuration);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/chat_wallpaper.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with call info
              _buildCallHeader(),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // User avatar
                    _buildUserAvatar(),
                    const SizedBox(height: 32),

                    // Call status
                    _buildCallStatus(),
                    const SizedBox(height: 8),

                    // Call duration
                    if (_isCallConnected) _buildCallDuration(),
                  ],
                ),
              ),

              // Call controls
              _buildCallControls(),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back/Minimize button
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.unfold_less,
                color: Colors.white,
                size: 24,
              ),
              onPressed: _onMinimizePressed,
            ),
          ),

          // Call title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isCallConnected
                  ? 'Voice Call • ${_formatDuration(_callDuration)}'
                  : 'Voice Call',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Contact button
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.person_add, color: Colors.white, size: 24),
              onPressed: _onContactPressed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.5),
            border: Border.all(
              color: _isCallConnected ? Colors.green : Colors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 85,
            backgroundColor: Colors.transparent,
            backgroundImage:
                widget.receiverAvatar.isNotEmpty
                    ? NetworkImage(widget.receiverAvatar)
                    : null,
            child:
                widget.receiverAvatar.isEmpty
                    ? Icon(Icons.person, size: 80, color: Colors.white)
                    : null,
          ),
        ),
        if (!_isCallConnected)
          Positioned(
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Ringing...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCallStatus() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.receiverName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            _isCallConnected ? 'Connected' : _getCallStatusText(),
            style: TextStyle(
              color: _isCallConnected ? Colors.greenAccent : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _getCallStatusText() {
    switch (_callStatus) {
      case 'calling':
        return widget.isIncomingCall ? 'Incoming call' : 'Calling...';
      case 'ringing':
        return 'Ringing...';
      default:
        return 'Calling...';
    }
  }

  Widget _buildCallDuration() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        _formatDuration(_callDuration),
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCallControls() {
    // If it's an incoming call and not connected yet, show accept/reject buttons
    if (widget.isIncomingCall && !_isCallConnected) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Reject button
            _buildControlButton(
              icon: Icons.call_end,
              backgroundColor: Colors.red.withOpacity(0.8),
              isLarge: true,
              onPressed: _rejectCall,
            ),

            // Accept button
            _buildControlButton(
              icon: Icons.call,
              backgroundColor: Colors.green.withOpacity(0.8),
              isLarge: true,
              onPressed: _acceptCall,
            ),
          ],
        ),
      );
    }

    // Regular call controls for outgoing calls or connected calls
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Video call button (leftmost)
          _buildControlButton(
            icon: Icons.videocam,
            backgroundColor: Colors.black.withOpacity(0.6),
            onPressed: _onVideoCallPressed,
          ),

          // Speaker button
          _buildControlButton(
            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
            backgroundColor: Colors.black.withOpacity(0.6),
            onPressed: _toggleSpeaker,
          ),

          // Mute button
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            backgroundColor: Colors.black.withOpacity(0.6),
            onPressed: _toggleMute,
          ),

          // End call button (rightmost)
          _buildControlButton(
            icon: Icons.call_end,
            backgroundColor: Colors.red.withOpacity(0.8),
            isLarge: true,
            onPressed: _endCall,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onPressed,
    bool isLarge = false,
  }) {
    return Container(
      width: isLarge ? 70 : 60,
      height: isLarge ? 70 : 60,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: isLarge ? 35 : 30),
        onPressed: onPressed,
      ),
    );
  }
}
