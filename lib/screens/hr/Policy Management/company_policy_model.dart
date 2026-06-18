import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a company policy document uploaded by HR.
/// Stored in Firestore collection: 'CompanyPolicies'
class CompanyPolicy {
  final String id;
  final String title;
  final String? description;
  final String fileUrl;           // Firebase Storage URL
  final String fileName;
  final String fileType;          // pdf, doc, docx, txt, etc.
  final String uploadedBy;        // HR user UID
  final DateTime uploadedAt;
  final bool isActive;

  CompanyPolicy({
    required this.id,
    required this.title,
    this.description,
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
    required this.uploadedBy,
    required this.uploadedAt,
    this.isActive = true,
  });

  factory CompanyPolicy.fromMap(Map<String, dynamic> map, String documentId) {
    return CompanyPolicy(
      id: documentId,
      title: map['title'] ?? '',
      description: map['description'],
      fileUrl: map['fileUrl'] ?? '',
      fileName: map['fileName'] ?? '',
      fileType: map['fileType'] ?? '',
      uploadedBy: map['uploadedBy'] ?? '',
      uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'uploadedBy': uploadedBy,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'isActive': isActive,
    };
  }

  CompanyPolicy copyWith({
    String? id,
    String? title,
    String? description,
    String? fileUrl,
    String? fileName,
    String? fileType,
    String? uploadedBy,
    DateTime? uploadedAt,
    bool? isActive,
  }) {
    return CompanyPolicy(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
