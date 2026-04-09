class UserProfile {
  final String uid;
  final String name;
  final String username;
  final String phone;
  final String bio;
  final String profileImage;
  final List<String> links;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.username,
    required this.phone,
    required this.bio,
    required this.profileImage,
    required this.links,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      name: data['name'] as String? ?? '',
      username: data['username'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      profileImage: data['profileImage'] as String? ?? '',
      links: List<String>.from(data['links'] as List? ?? []),
      createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
      updatedAt: (data['updatedAt'] as dynamic)?.toDate() as DateTime?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'username': username,
      'phone': phone,
      'bio': bio,
      'profileImage': profileImage,
      'links': links,
    };
  }

  /// Display name falls back gracefully: name → username → phone
  String get displayName {
    if (name.isNotEmpty) return name;
    if (username.isNotEmpty) return username;
    return phone;
  }

  /// True only if profileImage is a non-empty valid URL
  bool get hasProfileImage =>
      profileImage.isNotEmpty && profileImage.startsWith('http');

  UserProfile copyWith({
    String? name,
    String? username,
    String? phone,
    String? bio,
    String? profileImage,
    List<String>? links,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      profileImage: profileImage ?? this.profileImage,
      links: links ?? this.links,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
