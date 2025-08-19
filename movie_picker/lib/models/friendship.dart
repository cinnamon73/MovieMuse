import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendshipStatus {
  pending,
  accepted,
  declined
}

class Friendship {
  final String id;
  final String requesterUid;
  final String receiverUid;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Friendship({
    required this.id,
    required this.requesterUid,
    required this.receiverUid,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requesterUid': requesterUid,
      'receiverUid': receiverUid,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      id: json['id'] as String,
      requesterUid: json['requesterUid'] as String,
      receiverUid: json['receiverUid'] as String,
      status: FriendshipStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => FriendshipStatus.pending,
      ),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: json['updatedAt'] != null 
          ? (json['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Friendship copyWith({
    String? id,
    String? requesterUid,
    String? receiverUid,
    FriendshipStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Friendship(
      id: id ?? this.id,
      requesterUid: requesterUid ?? this.requesterUid,
      receiverUid: receiverUid ?? this.receiverUid,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Friendship && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Friendship(id: $id, requesterUid: $requesterUid, receiverUid: $receiverUid, status: $status)';
  }
}

// Simplified user profile - just username and avatar
class UserProfile {
  final String uid;
  final String username;
  final String? avatarId; // Changed from profilePicUrl to avatarId
  final bool isAnonymous;

  UserProfile({
    required this.uid,
    required this.username,
    this.avatarId, // Changed from profilePicUrl
    required this.isAnonymous,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'username': username,
      'avatarId': avatarId, // Changed from profilePicUrl
      'isAnonymous': isAnonymous,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      username: json['username'] as String,
      avatarId: json['avatarId'] as String?, // Changed from profilePicUrl
      isAnonymous: json['isAnonymous'] as bool? ?? false,
    );
  }

  UserProfile copyWith({
    String? uid,
    String? username,
    String? avatarId, // Changed from profilePicUrl
    bool? isAnonymous,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      avatarId: avatarId ?? this.avatarId, // Changed from profilePicUrl
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }
} 