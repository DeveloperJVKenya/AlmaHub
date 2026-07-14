import 'package:cloud_firestore/cloud_firestore.dart';

/// Who created a [DailyHoursEntry]. Employee entries start life unverified;
/// supervisor entries are a rare, explicitly-flagged exception path.
class HoursEntrySource {
  static const String employee = 'employee';
  static const String supervisor = 'supervisor';
}

/// Approval lifecycle for a [DailyHoursEntry].
class HoursEntryStatus {
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

/// A single day's worked-hours record, stored at
/// `EmployeeDetails/{docId}/DailyHours/{yyyy-MM-dd}`.
///
/// Employee-submitted entries start `pending` and are immutable to the
/// employee once approved. Supervisor-submitted entries (manual override,
/// e.g. an employee without app access) are written already `approved` but
/// always carry a [note] justification and [source] == supervisor so they
/// render distinctly from an independently-checked, self-reported entry.
class DailyHoursEntry {
  final String dateKey; // yyyy-MM-dd, also the Firestore doc id
  final DateTime date;
  final String entryTime; // HH:mm
  final String exitTime; // HH:mm
  final int breakMinutes;
  final double hours;
  final String monthKey; // yyyy-MM
  final String uid; // employee uid this entry belongs to
  final String? note;
  final String status;
  final String source;
  final String submittedByUid;
  final DateTime? submittedAt;
  final String? reviewedByUid;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final double? workQuality;

  const DailyHoursEntry({
    required this.dateKey,
    required this.date,
    required this.entryTime,
    required this.exitTime,
    required this.breakMinutes,
    required this.hours,
    required this.monthKey,
    required this.uid,
    this.note,
    required this.status,
    required this.source,
    required this.submittedByUid,
    this.submittedAt,
    this.reviewedByUid,
    this.reviewedAt,
    this.rejectionReason,
    this.workQuality,
  });

  factory DailyHoursEntry.fromMap(Map<String, dynamic> map, String dateKey) {
    return DailyHoursEntry(
      dateKey: dateKey,
      date: (map['date'] as Timestamp).toDate(),
      entryTime: map['entryTime'] ?? 'N/A',
      exitTime: map['exitTime'] ?? 'N/A',
      breakMinutes: (map['breakMinutes'] ?? 0) as int,
      hours: (map['hours'] ?? 0).toDouble(),
      monthKey: map['monthKey'] ?? '',
      uid: map['uid'] ?? '',
      note: map['note'],
      status: map['status'] ?? HoursEntryStatus.pending,
      source: map['source'] ?? HoursEntrySource.employee,
      submittedByUid: map['submittedByUid'] ?? map['uid'] ?? '',
      submittedAt: (map['submittedAt'] as Timestamp?)?.toDate(),
      reviewedByUid: map['reviewedByUid'],
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
      rejectionReason: map['rejectionReason'],
      workQuality: (map['workQuality'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'entryTime': entryTime,
      'exitTime': exitTime,
      'breakMinutes': breakMinutes,
      'hours': hours,
      'monthKey': monthKey,
      'uid': uid,
      if (note != null) 'note': note,
      'status': status,
      'source': source,
      'submittedByUid': submittedByUid,
      if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
      if (reviewedByUid != null) 'reviewedByUid': reviewedByUid,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (workQuality != null) 'workQuality': workQuality,
    };
  }

  bool get isPending => status == HoursEntryStatus.pending;
  bool get isApproved => status == HoursEntryStatus.approved;
  bool get isRejected => status == HoursEntryStatus.rejected;
  bool get isSupervisorEntered => source == HoursEntrySource.supervisor;
}

/// Aggregated view of one employee's hours for the supervisor table —
/// replaces the ad-hoc `Map<String, dynamic>` assembly that used to live
/// inline in the supervisor dashboard.
class EmployeeHoursSummary {
  final String uid;
  final String fullName;
  final String email;
  final String department;
  final String jobTitle;
  final String employmentType;
  final String status; // EmployeeDetails.status (draft/submitted/approved/rejected)
  final double hoursWorked;
  final double workQuality;
  final int daysWorked;
  final double overtimeHours;
  final int pendingCount;
  final String? documentId;

  const EmployeeHoursSummary({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.department,
    required this.jobTitle,
    required this.employmentType,
    required this.status,
    required this.hoursWorked,
    required this.workQuality,
    required this.daysWorked,
    required this.overtimeHours,
    required this.pendingCount,
    this.documentId,
  });
}
