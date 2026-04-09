import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wrytte/models/user_models/user_profile_service.dart';

class UserProfileService {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const _collection = 'users';

  // In-memory cache so screens don't re-fetch on every rebuild
  UserProfile? _cachedProfile;

  // ─────────────────────────────────────────────────────────────
  // FETCH
  // ─────────────────────────────────────────────────────────────

  /// Fetches the current logged-in user's profile from Firestore.
  /// Returns null if the user is not authenticated or document missing.
  Future<UserProfile?> getCurrentUserProfile({
    bool forceRefresh = false,
  }) async {
    if (_cachedProfile != null && !forceRefresh) return _cachedProfile;

    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    return getProfileByUid(firebaseUser.uid);
  }

  /// Fetches any user's profile by their Firestore document UID.
  Future<UserProfile?> getProfileByUid(String uid) async {
    try {
      final doc = await _firestore.collection(_collection).doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;

      final profile = UserProfile.fromMap(uid, doc.data()!);

      // Cache if it's the current user
      if (_auth.currentUser?.uid == uid) {
        _cachedProfile = profile;
      }

      return profile;
    } catch (e) {
      return null;
    }
  }

  /// Fetches any user's profile by their phone number.
  /// Useful for chat — look up a contact by phone.
  Future<UserProfile?> getProfileByPhone(String phone) async {
    try {
      final query =
          await _firestore
              .collection(_collection)
              .where('phone', isEqualTo: phone)
              .limit(1)
              .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;
      return UserProfile.fromMap(doc.id, doc.data());
    } catch (e) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // STREAM  (real-time updates — useful for profile screen)
  // ─────────────────────────────────────────────────────────────

  /// Stream of the current user's profile — auto-updates on changes.
  Stream<UserProfile?> getCurrentUserProfileStream() {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return Stream.value(null);

    return _firestore
        .collection(_collection)
        .doc(firebaseUser.uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          final profile = UserProfile.fromMap(doc.id, doc.data()!);
          _cachedProfile = profile;
          return profile;
        });
  }

  // ─────────────────────────────────────────────────────────────
  // CACHE HELPERS
  // ─────────────────────────────────────────────────────────────

  /// Returns the cached profile synchronously — use where async is not ideal.
  UserProfile? get cachedProfile => _cachedProfile;

  /// Call on logout to wipe the in-memory cache.
  void clearCache() => _cachedProfile = null;
}
