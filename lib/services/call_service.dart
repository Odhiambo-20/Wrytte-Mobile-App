import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a call document
  Future<String> initiateCall({
    required String callerId,
    required String callerName,
    required String callerAvatar,
    required String receiverId,
    required String receiverName,
    required String receiverAvatar,
    required bool isVideoCall,
  }) async {
    try {
      final callId =
          '${DateTime.now().millisecondsSinceEpoch}_${callerId}_${receiverId}';

      final callData = {
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callerAvatar': callerAvatar,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'receiverAvatar': receiverAvatar,
        'isVideoCall': isVideoCall,
        'status': 'calling', // calling, accepted, rejected, ended, missed
        'startedAt': FieldValue.serverTimestamp(),
        'endedAt': null,
        'duration': 0,
      };

      await _firestore.collection('calls').doc(callId).set(callData);

      // Create call history for both users
      await _createCallHistory(callId, callerId, receiverId, callData);

      return callId;
    } catch (e) {
      print('Error initiating call: $e');
      rethrow;
    }
  }

  // Create call history entries
  Future<void> _createCallHistory(
    String callId,
    String callerId,
    String receiverId,
    Map<String, dynamic> callData,
  ) async {
    final batch = _firestore.batch();

    // For caller
    batch.set(
      _firestore
          .collection('users')
          .doc(callerId)
          .collection('callHistory')
          .doc(callId),
      {
        ...callData,
        'isOutgoing': true,
        'participantId': receiverId,
        'participantName': callData['receiverName'],
        'participantAvatar': callData['receiverAvatar'],
      },
    );

    // For receiver
    batch.set(
      _firestore
          .collection('users')
          .doc(receiverId)
          .collection('callHistory')
          .doc(callId),
      {
        ...callData,
        'isOutgoing': false,
        'participantId': callerId,
        'participantName': callData['callerName'],
        'participantAvatar': callData['callerAvatar'],
      },
    );

    await batch.commit();
  }

  // Update call status
  Future<void> updateCallStatus(
    String callId,
    String status, [
    int? duration,
  ]) async {
    try {
      final updateData = {
        'status': status,
        'endedAt': FieldValue.serverTimestamp(),
      };

      if (duration != null) {
        updateData['duration'] = duration;
      }

      await _firestore.collection('calls').doc(callId).update(updateData);

      // Also update in user's call history
      await _updateCallHistoryStatus(callId, status, duration);
    } catch (e) {
      print('Error updating call status: $e');
      rethrow;
    }
  }

  Future<void> _updateCallHistoryStatus(
    String callId,
    String status, [
    int? duration,
  ]) async {
    // This would update the call history for both users
    // Implementation depends on my database structure
  }

  // Get call stream
  Stream<DocumentSnapshot> getCallStream(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots();
  }

  // Get incoming calls for a user
  Stream<QuerySnapshot> getIncomingCalls(String userId) {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'calling')
        .snapshots();
  }

  // End call
  Future<void> endCall(String callId, int duration) async {
    await updateCallStatus(callId, 'ended', duration);
  }

  // Reject call
  Future<void> rejectCall(String callId) async {
    await updateCallStatus(callId, 'rejected');
  }

  // Accept call
  Future<void> acceptCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'accepted',
      'answeredAt': FieldValue.serverTimestamp(),
    });
  }

  // Get call history for user
  Stream<QuerySnapshot> getUserCallHistory(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('callHistory')
        .orderBy('startedAt', descending: true)
        .snapshots();
  }
}
