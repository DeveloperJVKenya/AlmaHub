import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks an employee's interaction with a specific policy.
/// Stored in Firestore collection: 'PolicyStatus'
/// Document ID: {employeeUid}_{policyId}
class PolicyStatus {
  final String id;
  final String employeeUid;
  final String policyId;
  final String status;      // 'unread' | 'opened' | 'accepted'
  final DateTime? openedAt;
  final DateTime? acceptedAt;
  final DateTime? lastOpenedAt;  // Tracks every reopen
  final DateTime updatedAt;

  PolicyStatus({
    required this.id,
    required this.employeeUid,
    required this.policyId,
    this.status = 'unread',
    this.openedAt,
    this.acceptedAt,
    this.lastOpenedAt,
    required this.updatedAt,
  });

  factory PolicyStatus.fromMap(Map<String, dynamic> map, String documentId) {
    return PolicyStatus(
      id: documentId,
      employeeUid: map['employeeUid'] ?? '',
      policyId: map['policyId'] ?? '',
      status: map['status'] ?? 'unread',
      openedAt: (map['openedAt'] as Timestamp?)?.toDate(),
      acceptedAt: (map['acceptedAt'] as Timestamp?)?.toDate(),
      lastOpenedAt: (map['lastOpenedAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeUid': employeeUid,
      'policyId': policyId,
      'status': status,
      'openedAt': openedAt != null ? Timestamp.fromDate(openedAt!) : null,
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'lastOpenedAt': lastOpenedAt != null ? Timestamp.fromDate(lastOpenedAt!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Helper to generate document ID from employeeUid and policyId
  static String generateId(String employeeUid, String policyId) {
    return '${employeeUid}_$policyId';
  }

  bool get isUnread => status == 'unread';
  bool get isOpened => status == 'opened';
  bool get isAccepted => status == 'accepted';

  PolicyStatus copyWith({
    String? id,
    String? employeeUid,
    String? policyId,
    String? status,
    DateTime? openedAt,
    DateTime? acceptedAt,
    DateTime? lastOpenedAt,
    DateTime? updatedAt,
  }) {
    return PolicyStatus(
      id: id ?? this.id,
      employeeUid: employeeUid ?? this.employeeUid,
      policyId: policyId ?? this.policyId,
      status: status ?? this.status,
      openedAt: openedAt ?? this.openedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
