import 'package:cloud_firestore/cloud_firestore.dart';

class SessionRecord {
  final String id;
  final String userId;
  final String mode;
  final int durationMinutes;
  final String reflection;
  final bool hasProof;
  final DateTime createdAt;

  const SessionRecord({
    required this.id,
    required this.userId,
    required this.mode,
    required this.durationMinutes,
    this.reflection = '',
    this.hasProof = false,
    required this.createdAt,
  });

  SessionRecord copyWith({
    String? id,
    String? userId,
    String? mode,
    int? durationMinutes,
    String? reflection,
    bool? hasProof,
    DateTime? createdAt,
  }) {
    return SessionRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mode: mode ?? this.mode,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      reflection: reflection ?? this.reflection,
      hasProof: hasProof ?? this.hasProof,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory SessionRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final timestamp = data['createdAt'];
    DateTime parsedCreatedAt;

    if (timestamp is Timestamp) {
      parsedCreatedAt = timestamp.toDate();
    } else if (timestamp is String) {
      parsedCreatedAt = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return SessionRecord(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      mode: data['mode'] as String? ?? 'focus',
      durationMinutes: data['durationMinutes'] as int? ?? 0,
      reflection: data['reflection'] as String? ?? '',
      hasProof: data['hasProof'] as bool? ?? false,
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'mode': mode,
      'durationMinutes': durationMinutes,
      'reflection': reflection,
      'hasProof': hasProof,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
