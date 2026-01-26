import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';

class VideoCallService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCDataChannel? _dataChannel;

  final List<RTCIceCandidate> _iceCandidates = [];
  bool _isInitialized = false;
  bool _isCaller = false;

  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(RTCIceCandidate)? onIceCandidate;
  Function(RTCSessionDescription)? onOffer;
  Function(RTCSessionDescription)? onAnswer;
  Function()? onCallEnded;
  Function(String)? onError;

  Future<void> initialize({required bool isCaller}) async {
    if (_isInitialized) return;

    _isCaller = isCaller;

    try {
      // Create peer connection configuration
      final configuration = <String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
        ],
      };

      final sdpConstraints = <String, dynamic>{
        'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
        'optional': [],
      };

      // Create peer connection
      _peerConnection = await createPeerConnection(
        configuration,
        sdpConstraints,
      );

      // Set up event handlers
      _peerConnection?.onIceCandidate = (candidate) {
        print('ICE candidate: ${candidate.candidate}');
        onIceCandidate?.call(candidate);
      };

      _peerConnection?.onIceConnectionState = (state) {
        print('ICE connection state: $state');
      };

      _peerConnection?.onAddStream = (stream) {
        print('Remote stream added');
        _remoteStream = stream;
        onRemoteStream?.call(stream);
      };

      _peerConnection?.onDataChannel = (channel) {
        print('Data channel received');
        _dataChannel = channel;
        _setupDataChannel(channel);
      };

      // Get local media stream
      final mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': {
          'mandatory': {
            'minWidth': '1280',
            'minHeight': '720',
            'minFrameRate': '30',
          },
          'facingMode': 'user',
          'optional': [],
        },
      };

      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      onLocalStream?.call(_localStream!);

      // Add local stream to peer connection
      _peerConnection?.addStream(_localStream!);

      // Create data channel if caller
      if (isCaller) {
        _dataChannel = await _peerConnection?.createDataChannel(
          'chat',
          RTCDataChannelInit(),
        );
        _setupDataChannel(_dataChannel!);
      }

      _isInitialized = true;
      print('Video call service initialized successfully');
    } catch (e) {
      print('Error initializing video call service: $e');
      onError?.call('Failed to initialize video call: $e');
      rethrow;
    }
  }

  void _setupDataChannel(RTCDataChannel channel) {
    channel.onMessage = (message) {
      print('Data channel message: ${message.text}');
      // Handle data channel messages (chat, reactions, etc.)
    };

    channel.onDataChannelState = (state) {
      print('Data channel state: $state');
    };
  }

  Future<RTCSessionDescription> createOffer() async {
    try {
      if (_peerConnection == null) {
        throw Exception('Peer connection not initialized');
      }

      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _peerConnection!.setLocalDescription(offer);
      return offer;
    } catch (e) {
      print('Error creating offer: $e');
      onError?.call('Failed to create call offer: $e');
      rethrow;
    }
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    try {
      if (_peerConnection == null) {
        throw Exception('Peer connection not initialized');
      }
      await _peerConnection!.setRemoteDescription(description);
    } catch (e) {
      print('Error setting remote description: $e');
      onError?.call('Failed to set remote description: $e');
      rethrow;
    }
  }

  Future<RTCSessionDescription> createAnswer() async {
    try {
      if (_peerConnection == null) {
        throw Exception('Peer connection not initialized');
      }

      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _peerConnection!.setLocalDescription(answer);
      return answer;
    } catch (e) {
      print('Error creating answer: $e');
      onError?.call('Failed to create answer: $e');
      rethrow;
    }
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    try {
      if (_peerConnection == null) {
        _iceCandidates.add(candidate);
        return;
      }
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      print('Error adding ICE candidate: $e');
      onError?.call('Failed to add ICE candidate: $e');
    }
  }

  Future<void> processPendingIceCandidates() async {
    for (final candidate in _iceCandidates) {
      await addIceCandidate(candidate);
    }
    _iceCandidates.clear();
  }

  Future<void> switchCamera() async {
    try {
      final videoTrack = _localStream?.getVideoTracks().first;
      if (videoTrack != null) {
        await Helper.switchCamera(videoTrack);
      }
    } catch (e) {
      print('Error switching camera: $e');
      onError?.call('Failed to switch camera: $e');
    }
  }

  Future<void> toggleMuteAudio() async {
    try {
      final audioTrack = _localStream?.getAudioTracks().first;
      if (audioTrack != null) {
        audioTrack.enabled = !audioTrack.enabled;
      }
    } catch (e) {
      print('Error toggling audio: $e');
      onError?.call('Failed to toggle audio: $e');
    }
  }

  Future<void> toggleVideo() async {
    try {
      final videoTrack = _localStream?.getVideoTracks().first;
      if (videoTrack != null) {
        videoTrack.enabled = !videoTrack.enabled;
      }
    } catch (e) {
      print('Error toggling video: $e');
      onError?.call('Failed to toggle video: $e');
    }
  }

  Future<void> dispose() async {
    print('Disposing video call service');

    try {
      // Stop all tracks
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });

      _remoteStream?.getTracks().forEach((track) {
        track.stop();
      });

      // Close data channel
      await _dataChannel?.close();

      // Close peer connection
      await _peerConnection?.close();

      // Clear references
      _localStream = null;
      _remoteStream = null;
      _peerConnection = null;
      _dataChannel = null;
      _iceCandidates.clear();
      _isInitialized = false;

      print('Video call service disposed successfully');
    } catch (e) {
      print('Error disposing video call service: $e');
    } finally {
      onCallEnded?.call();
    }
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isCaller => _isCaller;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
}
