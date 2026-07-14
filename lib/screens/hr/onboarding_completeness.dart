import 'package:almahub/models/employee_onboarding_models.dart';

/// Data-level completeness checks for the HR onboarding wizard.
///
/// Deliberately independent of the wizard's `Form`/`GlobalKey<FormState>`
/// widgets — those only exist for whichever step is currently on screen (see
/// `hr_employee_onboarding_screen.dart._buildStepContent`, a `switch` that
/// builds one step at a time, not an `IndexedStack`). Validating "all steps"
/// via form keys is therefore impossible once the user has navigated away
/// from a step; this checks the underlying data models instead, so it works
/// regardless of which step is currently mounted.
///
/// Mirrors exactly the required-field `validator:` logic already present in
/// each step file. Steps 5–8 (Academic Docs, Contracts & Forms, Benefits &
/// Insurance, Work Tools) have no required-field validators in the wizard
/// today and are intentionally not checked here.
class OnboardingCompleteness {
  const OnboardingCompleteness._();

  /// Returns a human-readable label for every step (1-4) that is missing a
  /// required field, in step order. Empty list means fully complete.
  static List<String> incompleteStepLabels({
    required PersonalInformation personalInfo,
    required EmploymentDetails employmentDetails,
    required StatutoryDocuments statutoryDocs,
    required PayrollDetails payrollDetails,
  }) {
    final labels = <String>[];

    if (!_isPersonalInfoComplete(personalInfo)) {
      labels.add('Step 1: Personal Information');
    }
    if (!_isEmploymentDetailsComplete(employmentDetails)) {
      labels.add('Step 2: Employment Details');
    }
    if (!_isStatutoryDocsComplete(statutoryDocs)) {
      labels.add('Step 3: Statutory Documents');
    }
    if (!isPayrollComplete(payrollDetails)) {
      labels.add('Step 4: Payroll & Payment Details');
    }

    return labels;
  }

  /// Zero-based index of the first incomplete step (0-3), or null if every
  /// checked step is complete. Used to jump the wizard there.
  static int? firstIncompleteStepIndex({
    required PersonalInformation personalInfo,
    required EmploymentDetails employmentDetails,
    required StatutoryDocuments statutoryDocs,
    required PayrollDetails payrollDetails,
  }) {
    if (!_isPersonalInfoComplete(personalInfo)) return 0;
    if (!_isEmploymentDetailsComplete(employmentDetails)) return 1;
    if (!_isStatutoryDocsComplete(statutoryDocs)) return 2;
    if (!isPayrollComplete(payrollDetails)) return 3;
    return null;
  }

  static bool _isPersonalInfoComplete(PersonalInformation p) {
    return p.fullName.trim().isNotEmpty &&
        p.nationalIdOrPassport.trim().isNotEmpty &&
        p.gender.trim().isNotEmpty &&
        p.phoneNumber.trim().isNotEmpty &&
        p.email.trim().isNotEmpty &&
        p.postalAddress.trim().isNotEmpty &&
        p.physicalAddress.trim().isNotEmpty &&
        p.nextOfKin.name.trim().isNotEmpty &&
        p.nextOfKin.relationship.trim().isNotEmpty &&
        p.nextOfKin.contact.trim().isNotEmpty;
  }

  static bool _isEmploymentDetailsComplete(EmploymentDetails e) {
    return e.jobTitle.trim().isNotEmpty &&
        e.department.trim().isNotEmpty &&
        e.employmentType.trim().isNotEmpty &&
        e.workingHours.trim().isNotEmpty &&
        e.workLocation.trim().isNotEmpty &&
        e.supervisorName.trim().isNotEmpty;
  }

  static bool _isStatutoryDocsComplete(StatutoryDocuments s) {
    return s.kraPinNumber.trim().isNotEmpty &&
        s.nssfNumber.trim().isNotEmpty &&
        s.shifNumber.trim().isNotEmpty;
  }

  /// Whether an employee's payroll data is complete enough for payroll
  /// operations: a real basic salary and a fully-filled bank account.
  /// Reused by both the onboarding submit check and
  /// `PayrollService.generateRun` (the single source of truth for "is this
  /// employee payroll-ready" — don't duplicate this logic elsewhere).
  static bool isPayrollComplete(PayrollDetails p) {
    return p.basicSalary > 0 &&
        p.bankDetails.bankName.trim().isNotEmpty &&
        p.bankDetails.branchName.trim().isNotEmpty &&
        p.bankDetails.accountName.trim().isNotEmpty &&
        p.bankDetails.accountNumber.trim().isNotEmpty;
  }

  /// Field-level breakdown of what's missing from [p] for payroll purposes —
  /// same criteria as [isPayrollComplete], but itemized so HR can be told
  /// exactly why an employee was excluded from a payroll run instead of just
  /// "incomplete." Empty list means fully complete.
  static List<String> incompletePayrollFields(PayrollDetails p) {
    final missing = <String>[];
    if (p.basicSalary <= 0) missing.add('Basic Salary');
    if (p.bankDetails.bankName.trim().isEmpty) missing.add('Bank Name');
    if (p.bankDetails.branchName.trim().isEmpty) missing.add('Bank Branch');
    if (p.bankDetails.accountName.trim().isEmpty) missing.add('Account Name');
    if (p.bankDetails.accountNumber.trim().isEmpty) missing.add('Account Number');
    return missing;
  }
}
