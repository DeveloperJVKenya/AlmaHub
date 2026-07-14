import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Data Models for AlmaHub HR Management System
/// This file contains all data models and Firestore structure

// ==================== EMPLOYEE MODEL ====================
class Employee {
  final String id;
  final String employeeId;
  final String name;
  final String email;
  final String phone;
  final String position;
  final String department;
  final String status; // active, inactive, on_leave, terminated
  final DateTime hireDate;
  final String? profileImageUrl;
  
  // Personal Information
  final String? address;
  final String? dateOfBirth;
  final String? gender;
  final String? nationality;
  final String? idNumber;
  final String? kraPin;
  final String? nssfNumber;
  final String? shifNumber;
  
  // Next of Kin
  final String? nextOfKinName;
  final String? nextOfKinRelation;
  final String? nextOfKinPhone;
  final String? nextOfKinAddress;
  
  // Employment Details
  final double salary;
  final String employmentType; // permanent, contract, casual
  final String? contractEndDate;
  final String? supervisor;
  
  // Documents (Firebase Storage URLs)
  final Map<String, String>? documents; // {documentType: storageUrl}
  
  // Academic Qualifications
  final List<Map<String, dynamic>>? qualifications;
  
  // Employment History
  final List<Map<String, dynamic>>? employmentHistory;
  
  // Bank Details
  final String? bankName;
  final String? accountNumber;
  final String? bankBranch;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  Employee({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.phone,
    required this.position,
    required this.department,
    required this.status,
    required this.hireDate,
    this.profileImageUrl,
    this.address,
    this.dateOfBirth,
    this.gender,
    this.nationality,
    this.idNumber,
    this.kraPin,
    this.nssfNumber,
    this.shifNumber,
    this.nextOfKinName,
    this.nextOfKinRelation,
    this.nextOfKinPhone,
    this.nextOfKinAddress,
    required this.salary,
    required this.employmentType,
    this.contractEndDate,
    this.supervisor,
    this.documents,
    this.qualifications,
    this.employmentHistory,
    this.bankName,
    this.accountNumber,
    this.bankBranch,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'name': name,
      'email': email,
      'phone': phone,
      'position': position,
      'department': department,
      'status': status,
      'hireDate': Timestamp.fromDate(hireDate),
      'profileImageUrl': profileImageUrl,
      'address': address,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'nationality': nationality,
      'idNumber': idNumber,
      'kraPin': kraPin,
      'nssfNumber': nssfNumber,
      'shifNumber': shifNumber,
      'nextOfKinName': nextOfKinName,
      'nextOfKinRelation': nextOfKinRelation,
      'nextOfKinPhone': nextOfKinPhone,
      'nextOfKinAddress': nextOfKinAddress,
      'salary': salary,
      'employmentType': employmentType,
      'contractEndDate': contractEndDate,
      'supervisor': supervisor,
      'documents': documents,
      'qualifications': qualifications,
      'employmentHistory': employmentHistory,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'bankBranch': bankBranch,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Employee.fromMap(String id, Map<String, dynamic> map) {
    return Employee(
      id: id,
      employeeId: map['employeeId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      position: map['position'] ?? '',
      department: map['department'] ?? '',
      status: map['status'] ?? 'active',
      hireDate: (map['hireDate'] as Timestamp).toDate(),
      profileImageUrl: map['profileImageUrl'],
      address: map['address'],
      dateOfBirth: map['dateOfBirth'],
      gender: map['gender'],
      nationality: map['nationality'],
      idNumber: map['idNumber'],
      kraPin: map['kraPin'],
      nssfNumber: map['nssfNumber'],
      shifNumber: map['shifNumber'],
      nextOfKinName: map['nextOfKinName'],
      nextOfKinRelation: map['nextOfKinRelation'],
      nextOfKinPhone: map['nextOfKinPhone'],
      nextOfKinAddress: map['nextOfKinAddress'],
      salary: map['salary']?.toDouble() ?? 0.0,
      employmentType: map['employmentType'] ?? 'permanent',
      contractEndDate: map['contractEndDate'],
      supervisor: map['supervisor'],
      documents: map['documents'] != null 
          ? Map<String, String>.from(map['documents']) 
          : null,
      qualifications: map['qualifications'] != null
          ? List<Map<String, dynamic>>.from(map['qualifications'])
          : null,
      employmentHistory: map['employmentHistory'] != null
          ? List<Map<String, dynamic>>.from(map['employmentHistory'])
          : null,
      bankName: map['bankName'],
      accountNumber: map['accountNumber'],
      bankBranch: map['bankBranch'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
}

// ==================== JOB POSTING MODEL ====================
class JobPosting {
  final String id;
  final String title;
  final String department;
  final String location;
  final String employmentType; // full-time, part-time, contract
  final String experienceLevel; // entry, mid, senior
  final String description;
  final List<String> requirements;
  final List<String> responsibilities;
  final double? salaryMin;
  final double? salaryMax;
  final String status; // active, closed, draft
  final int applicantCount;
  final DateTime postedDate;
  final DateTime? closingDate;
  final String postedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  JobPosting({
    required this.id,
    required this.title,
    required this.department,
    required this.location,
    required this.employmentType,
    required this.experienceLevel,
    required this.description,
    required this.requirements,
    required this.responsibilities,
    this.salaryMin,
    this.salaryMax,
    required this.status,
    required this.applicantCount,
    required this.postedDate,
    this.closingDate,
    required this.postedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'department': department,
      'location': location,
      'employmentType': employmentType,
      'experienceLevel': experienceLevel,
      'description': description,
      'requirements': requirements,
      'responsibilities': responsibilities,
      'salaryMin': salaryMin,
      'salaryMax': salaryMax,
      'status': status,
      'applicantCount': applicantCount,
      'postedDate': Timestamp.fromDate(postedDate),
      'closingDate': closingDate != null ? Timestamp.fromDate(closingDate!) : null,
      'postedBy': postedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory JobPosting.fromMap(String id, Map<String, dynamic> map) {
    return JobPosting(
      id: id,
      title: map['title'] ?? '',
      department: map['department'] ?? '',
      location: map['location'] ?? '',
      employmentType: map['employmentType'] ?? '',
      experienceLevel: map['experienceLevel'] ?? '',
      description: map['description'] ?? '',
      requirements: List<String>.from(map['requirements'] ?? []),
      responsibilities: List<String>.from(map['responsibilities'] ?? []),
      salaryMin: map['salaryMin']?.toDouble(),
      salaryMax: map['salaryMax']?.toDouble(),
      status: map['status'] ?? 'draft',
      applicantCount: map['applicantCount'] ?? 0,
      postedDate: (map['postedDate'] as Timestamp).toDate(),
      closingDate: map['closingDate'] != null 
          ? (map['closingDate'] as Timestamp).toDate() 
          : null,
      postedBy: map['postedBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
}

// ==================== APPLICATION MODEL ====================
class Application {
  final String id;
  final String jobPostingId;
  final String position;
  
  // Candidate Information
  final String candidateName;
  final String email;
  final String phone;
  final String? alternativePhone;
  final String? address;
  final String? city;
  final String? country;
  final String? dateOfBirth;
  final String? gender;
  final String? nationality;
  final String? idNumber;
  
  // Professional Information
  final String? currentPosition;
  final String? currentEmployer;
  final int? yearsOfExperience;
  final String? linkedInProfile;
  final String? portfolioUrl;
  
  // Documents (Firebase Storage URLs) - KEY FEATURE
  final Map<String, DocumentInfo> documents; // Enhanced document tracking
  
  // Application Status
  final String status; // pending, under_review, shortlisted, interview_scheduled, 
                       // offer_sent, accepted, rejected
  final List<StatusHistory> statusHistory;
  
  // Interview Details
  final List<Interview>? interviews;
  
  // Ratings and Notes
  final double? rating;
  final String? hrNotes;
  final String? interviewerNotes;
  
  // Additional Information
  final String? coverLetter;
  final double? expectedSalary;
  final String? noticePeriod;
  final String? availabilityDate;
  
  final DateTime submittedDate;
  final DateTime? lastViewedDate;
  final String? reviewedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Application({
    required this.id,
    required this.jobPostingId,
    required this.position,
    required this.candidateName,
    required this.email,
    required this.phone,
    this.alternativePhone,
    this.address,
    this.city,
    this.country,
    this.dateOfBirth,
    this.gender,
    this.nationality,
    this.idNumber,
    this.currentPosition,
    this.currentEmployer,
    this.yearsOfExperience,
    this.linkedInProfile,
    this.portfolioUrl,
    required this.documents,
    required this.status,
    required this.statusHistory,
    this.interviews,
    this.rating,
    this.hrNotes,
    this.interviewerNotes,
    this.coverLetter,
    this.expectedSalary,
    this.noticePeriod,
    this.availabilityDate,
    required this.submittedDate,
    this.lastViewedDate,
    this.reviewedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'jobPostingId': jobPostingId,
      'position': position,
      'candidateName': candidateName,
      'email': email,
      'phone': phone,
      'alternativePhone': alternativePhone,
      'address': address,
      'city': city,
      'country': country,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'nationality': nationality,
      'idNumber': idNumber,
      'currentPosition': currentPosition,
      'currentEmployer': currentEmployer,
      'yearsOfExperience': yearsOfExperience,
      'linkedInProfile': linkedInProfile,
      'portfolioUrl': portfolioUrl,
      'documents': documents.map((key, value) => MapEntry(key, value.toMap())),
      'status': status,
      'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
      'interviews': interviews?.map((e) => e.toMap()).toList(),
      'rating': rating,
      'hrNotes': hrNotes,
      'interviewerNotes': interviewerNotes,
      'coverLetter': coverLetter,
      'expectedSalary': expectedSalary,
      'noticePeriod': noticePeriod,
      'availabilityDate': availabilityDate,
      'submittedDate': Timestamp.fromDate(submittedDate),
      'lastViewedDate': lastViewedDate != null 
          ? Timestamp.fromDate(lastViewedDate!) 
          : null,
      'reviewedBy': reviewedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

// ==================== DOCUMENT INFO MODEL ====================
class DocumentInfo {
  final String fileName;
  final String fileType; // pdf, doc, docx, jpg, png
  final String storageUrl;
  final int fileSize;
  final DateTime uploadedDate;
  final String documentType; // cv, cover_letter, certificate, id_copy, etc.
  final bool isVerified;
  final String? verifiedBy;
  final DateTime? verifiedDate;

  DocumentInfo({
    required this.fileName,
    required this.fileType,
    required this.storageUrl,
    required this.fileSize,
    required this.uploadedDate,
    required this.documentType,
    this.isVerified = false,
    this.verifiedBy,
    this.verifiedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'fileType': fileType,
      'storageUrl': storageUrl,
      'fileSize': fileSize,
      'uploadedDate': Timestamp.fromDate(uploadedDate),
      'documentType': documentType,
      'isVerified': isVerified,
      'verifiedBy': verifiedBy,
      'verifiedDate': verifiedDate != null 
          ? Timestamp.fromDate(verifiedDate!) 
          : null,
    };
  }

  factory DocumentInfo.fromMap(Map<String, dynamic> map) {
    return DocumentInfo(
      fileName: map['fileName'] ?? '',
      fileType: map['fileType'] ?? '',
      storageUrl: map['storageUrl'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      uploadedDate: (map['uploadedDate'] as Timestamp).toDate(),
      documentType: map['documentType'] ?? '',
      isVerified: map['isVerified'] ?? false,
      verifiedBy: map['verifiedBy'],
      verifiedDate: map['verifiedDate'] != null 
          ? (map['verifiedDate'] as Timestamp).toDate() 
          : null,
    );
  }
}

// ==================== STATUS HISTORY MODEL ====================
class StatusHistory {
  final String status;
  final DateTime changedDate;
  final String changedBy;
  final String? notes;

  StatusHistory({
    required this.status,
    required this.changedDate,
    required this.changedBy,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'changedDate': Timestamp.fromDate(changedDate),
      'changedBy': changedBy,
      'notes': notes,
    };
  }

  factory StatusHistory.fromMap(Map<String, dynamic> map) {
    return StatusHistory(
      status: map['status'] ?? '',
      changedDate: (map['changedDate'] as Timestamp).toDate(),
      changedBy: map['changedBy'] ?? '',
      notes: map['notes'],
    );
  }
}

// ==================== INTERVIEW MODEL ====================
class Interview {
  final String interviewType; // phone, technical, hr, final
  final DateTime scheduledDate;
  final String? location;
  final String? meetingLink;
  final List<String> interviewers;
  final String status; // scheduled, completed, cancelled, rescheduled
  final String? feedback;
  final double? score;

  Interview({
    required this.interviewType,
    required this.scheduledDate,
    this.location,
    this.meetingLink,
    required this.interviewers,
    required this.status,
    this.feedback,
    this.score,
  });

  Map<String, dynamic> toMap() {
    return {
      'interviewType': interviewType,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'location': location,
      'meetingLink': meetingLink,
      'interviewers': interviewers,
      'status': status,
      'feedback': feedback,
      'score': score,
    };
  }

  factory Interview.fromMap(Map<String, dynamic> map) {
    return Interview(
      interviewType: map['interviewType'] ?? '',
      scheduledDate: (map['scheduledDate'] as Timestamp).toDate(),
      location: map['location'],
      meetingLink: map['meetingLink'],
      interviewers: List<String>.from(map['interviewers'] ?? []),
      status: map['status'] ?? 'scheduled',
      feedback: map['feedback'],
      score: map['score']?.toDouble(),
    );
  }
}

// ==================== LEAVE MODEL ====================
class Leave {
  final String id;
  final String employeeId;
  final String employeeName;
  final String leaveType; // annual, sick, maternity, unpaid
  final DateTime startDate;
  final DateTime endDate;
  final int numberOfDays;
  final String reason;
  final String status; // pending, approved, rejected
  final String? approvedBy;
  final DateTime? approvedDate;
  final String? rejectionReason;
  final DateTime appliedDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Leave({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.numberOfDays,
    required this.reason,
    required this.status,
    this.approvedBy,
    this.approvedDate,
    this.rejectionReason,
    required this.appliedDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'leaveType': leaveType,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'numberOfDays': numberOfDays,
      'reason': reason,
      'status': status,
      'approvedBy': approvedBy,
      'approvedDate': approvedDate != null 
          ? Timestamp.fromDate(approvedDate!) 
          : null,
      'rejectionReason': rejectionReason,
      'appliedDate': Timestamp.fromDate(appliedDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

// ==================== ATTENDANCE MODEL ====================
class Attendance {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String status; // present, absent, late, half_day
  final String? notes;
  final String? location;
  final DateTime createdAt;

  Attendance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.notes,
    this.location,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'date': Timestamp.fromDate(date),
      'checkInTime': checkInTime != null 
          ? Timestamp.fromDate(checkInTime!) 
          : null,
      'checkOutTime': checkOutTime != null 
          ? Timestamp.fromDate(checkOutTime!) 
          : null,
      'status': status,
      'notes': notes,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// ==================== PAYROLL MODEL ====================
class Payroll {
  final String id;
  final String employeeId;
  final String employeeName;
  final String month; // "January 2026"
  final double basicSalary;
  final double allowances;
  final double deductions;
  final double grossSalary;
  final double netSalary;
  
  // Statutory Deductions
  final double payeTax;
  final double nssfContribution;
  final double shifContribution; // NHIF was replaced by SHIF/SHA
  
  // Other Deductions
  final double? loanDeduction;
  final double? advanceDeduction;
  final double? otherDeductions;
  
  final String status; // pending, approved, paid
  final String? approvedBy;
  final DateTime? paidDate;
  final String? paymentMethod; // mpesa, bank, airtel_money
  final String? transactionRef;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  Payroll({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.month,
    required this.basicSalary,
    required this.allowances,
    required this.deductions,
    required this.grossSalary,
    required this.netSalary,
    required this.payeTax,
    required this.nssfContribution,
    required this.shifContribution,
    this.loanDeduction,
    this.advanceDeduction,
    this.otherDeductions,
    required this.status,
    this.approvedBy,
    this.paidDate,
    this.paymentMethod,
    this.transactionRef,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'month': month,
      'basicSalary': basicSalary,
      'allowances': allowances,
      'deductions': deductions,
      'grossSalary': grossSalary,
      'netSalary': netSalary,
      'payeTax': payeTax,
      'nssfContribution': nssfContribution,
      'shifContribution': shifContribution,
      'loanDeduction': loanDeduction,
      'advanceDeduction': advanceDeduction,
      'otherDeductions': otherDeductions,
      'status': status,
      'approvedBy': approvedBy,
      'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
      'paymentMethod': paymentMethod,
      'transactionRef': transactionRef,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

/// ==================== FIRESTORE STRUCTURE ====================
/// 
/// Collections:
/// 
/// 1. employees/
///    - Document ID: Auto-generated
///    - Contains: Employee data with all personal, professional info
/// 
/// 2. job_postings/
///    - Document ID: Auto-generated
///    - Contains: Job posting details
/// 
/// 3. applications/
///    - Document ID: Auto-generated
///    - Contains: Candidate application with document references
///    - Subcollection: documents/ (optional for additional organization)
/// 
/// 4. leaves/
///    - Document ID: Auto-generated
///    - Contains: Leave requests and approvals
/// 
/// 5. attendance/
///    - Document ID: Auto-generated or {employeeId}_{date}
///    - Contains: Daily attendance records
/// 
/// 6. payroll/
///    - Document ID: Auto-generated or {employeeId}_{month}
///    - Contains: Monthly payroll records
/// 
/// 7. departments/
///    - Document ID: Department name
///    - Contains: Department info and staff count
/// 
/// 8. users/
///    - Document ID: Firebase Auth UID
///    - Contains: User authentication and role data
/// 
/// ==================== FIREBASE STORAGE STRUCTURE ====================
/// 
/// Storage Buckets:
/// 
/// applications/{applicationId}/
///    - cv/
///    - certificates/
///    - id_documents/
///    - cover_letters/
///    - other_documents/
/// 
/// employees/{employeeId}/
///    - profile_photo/
///    - id_documents/
///    - certificates/
///    - contracts/
///    - performance_reviews/
/// 
/// payroll/{month}/
///    - payslips/
///    - tax_documents/
///    - statutory_files/