import 'package:almahub/screens/authentication/login_screen.dart';
import 'package:almahub/screens/employee/employee_dashboard.dart';
import 'package:almahub/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  RegistrationScreenState createState() => RegistrationScreenState();
}

class RegistrationScreenState extends State<RegistrationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Initialize logger
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  @override
  void initState() {
    super.initState();
    _logger.i('RegistrationScreen initialized');
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward();
    _logger.d('Animation controller initialized and started');
  }

  /// Convert username with spaces to underscore format for document ID
  String _formatUsernameForDocId(String username) {
    final formatted = username.trim().replaceAll(' ', '_');
    _logger.d('Formatted username: "$username" -> "$formatted"');
    return formatted;
  }

  bool _isValidUsernameFormat(String username) {
    // Allow letters, numbers, spaces, and underscores
    final regex = RegExp(r'^[a-zA-Z0-9_ ]+$');
    return regex.hasMatch(username.trim());
  }

  Future<void> _signUp() async {
    _logger.i('Sign up process initiated');

    if (!_formKey.currentState!.validate()) {
      _logger.w('Form validation failed');
      return;
    }
    _logger.d('Form validation passed');

    if (_passwordController.text != _confirmPasswordController.text) {
      _logger.w('Password mismatch detected');
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }
    _logger.d('Password confirmation matched');

    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _logger.w('Username is empty after trimming');
      setState(() => _errorMessage = 'Username is required');
      return;
    }
    _logger.d('Username validated: $username');

    // Convert username to document ID format (spaces to underscores)
    final usernameDocId = _formatUsernameForDocId(username);
    _logger.i('Username for document ID: $usernameDocId');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _logger.i('Registration process starting for username: $username');

    User? user;

    try {
      // STEP 1: CREATE FIREBASE AUTH USER FIRST
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      _logger.i('Creating Firebase Auth user with email: $email');

      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      _logger.i('Firebase Auth user created successfully');

      user = userCredential.user;
      if (user == null) {
        _logger.e('User credential returned null user');
        throw Exception('User creation failed');
      }
      _logger.d('User UID obtained: ${user.uid}');

      // STEP 2: CHECK IF USERNAME EXISTS IN EMPLOYEEDETAILS COLLECTION
      _logger.d('Checking if username exists in EmployeeDetails collection: $usernameDocId');
      final existingDraftDoc = await FirebaseFirestore.instance
          .collection('EmployeeDetails')
          .doc(usernameDocId)
          .get();

      if (existingDraftDoc.exists) {
        _logger.w('Username already exists in EmployeeDetails: $usernameDocId');
        // Delete the auth user we just created since username is taken
        await user.delete();
        _logger.i('Deleted Firebase Auth user due to username conflict');
        throw Exception('Username already taken');
      }
      _logger.d('Username is available in EmployeeDetails collection: $usernameDocId');

      // STEP 3: CHECK IF USERNAME EXISTS IN USERS COLLECTION
      _logger.d('Checking if username exists in Users collection: $usernameDocId');
      final existingUserDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(usernameDocId)
          .get();

      if (existingUserDoc.exists) {
        _logger.w('Username already exists in Users: $usernameDocId');
        // Delete the auth user we just created since username is taken
        await user.delete();
        _logger.i('Deleted Firebase Auth user due to username conflict');
        throw Exception('Username already taken');
      }
      _logger.d('Username is available in Users collection: $usernameDocId');

      // STEP 4: CREATE DRAFT DOCUMENT 
      final draftData = {
        'id': usernameDocId,
        'status': 'draft',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'submittedAt': null,
        
        // Store registration metadata
        'registrationUsername': username, // Original username with spaces
        'registrationEmail': email,
        'uid': user.uid, // Store Firebase Auth UID
        
        'personalInfo': {
          'fullName': username, // ✅ Pre-fill fullName with username
          'nationalIdOrPassport': '',
          'idDocumentUrl': null,
          'dateOfBirth': null,
          'gender': '',
          'phoneNumber': '',
          'email': email, // ✅ Pre-fill email from registration
          'postalAddress': '',
          'physicalAddress': '',
          'nextOfKin': {
            'name': '',
            'relationship': '',
            'contact': '',
          },
        },
        'employmentDetails': {
          'jobTitle': '',
          'department': '',
          'employmentType': '',
          'startDate': null,
          'workingHours': '',
          'workLocation': '',
          'supervisorName': '',
        },
        'statutoryDocs': {
          'kraPinNumber': '',
          'kraPinCertificateUrl': null,
          'nssfNumber': '',
          'nssfConfirmationUrl': null,
          'shifNumber': '',
          'shifConfirmationUrl': null,
          'p9FormUrl': null,
        },
        'payrollDetails': {
          'basicSalary': 0.0,
          'allowances': {},
          'deductions': {},
          'bankDetails': {
            'bankName': '',
            'branchName': '',
            'accountName': '',
            'accountNumber': '',
          },
          'mpesaDetails': {
            'phoneNumber': '',
            'name': '',
          },
        },
        'academicDocs': {
          'academicCertificates': [],
          'trainingCertificates': [],
          'professionalCertificates': [],
          'professionalRegistrations': {},
        },
        'contractsForms': {
          'employmentContractUrl': null,
          'employeeInfoFormUrl': null,
          'ndaUrl': null,
          'codeOfConductAcknowledged': false,
          'dataProtectionConsentGiven': false,
          'consentDate': null,
        },
        'benefitsInsurance': {
          'shifDependants': [],
          'medicalInsuranceFormUrl': null,
          'beneficiaries': [],
        },
        'workTools': {
          'workEmail': null,
          'hrisProfileCreated': false,
          'systemAccessGranted': false,
          'issuedEquipment': [],
        },
      };
      
      _logger.d('Creating EmployeeDetails document (status: draft) with data');
      _logger.d('Document ID: $usernameDocId');
      _logger.d('Username (original): $username');
      _logger.d('Email: $email');

      await FirebaseFirestore.instance
          .collection('EmployeeDetails')
          .doc(usernameDocId)
          .set(draftData);
      _logger.i('✅ Draft record created successfully for: $usernameDocId');

      // STEP 5: CREATE USER DOCUMENT IN USERS COLLECTION
      _logger.i('Creating Users collection document for: $usernameDocId');
      
      final appUser = AppUser(
        uid: user.uid,
        email: email,
        fullName: username,
        role: UserRoles.employee, // ✅ Default role is Employee
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(usernameDocId)
          .set(appUser.toMap());
      
      _logger.i('✅ Users document created successfully for: $usernameDocId');
      _logger.d('User role set to: ${UserRoles.employee}');

      // STEP 6: SHOW SUCCESS MESSAGE AND NAVIGATE
      if (mounted) {
        _logger.i('Showing success message and navigating to Employee Dashboard');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to JV Almacis, $username!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        // New users always get Employee role, so redirect to Employee Dashboard
        _logger.i('Redirecting new Employee to Employee Dashboard');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const EmployeeDashboard(),
          ),
        );
        _logger.i('Navigation to EmployeeDashboard completed');
      }

    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.e(
        'FirebaseAuthException during registration',
        error: e,
        stackTrace: stackTrace,
      );
      _logger.e('Error code: ${e.code}, Message: ${e.message}');

      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _errorMessage = 'This email is already registered. Please login.';
            _logger.w('Email already in use: ${_emailController.text.trim()}');
            break;
          case 'invalid-email':
            _errorMessage = 'Invalid email address format.';
            _logger.w('Invalid email format: ${_emailController.text.trim()}');
            break;
          case 'weak-password':
            _errorMessage = 'Password is too weak. Use at least 6 characters.';
            _logger.w('Weak password detected');
            break;
          case 'operation-not-allowed':
            _errorMessage = 'Registration is currently disabled.';
            _logger.e('Email/password registration is not enabled in Firebase');
            break;
          default:
            _errorMessage =
                'Registration failed: ${e.message ?? "Unknown error"}';
            _logger.e('Unknown FirebaseAuthException: ${e.code}');
        }
      });

    } on FirebaseException catch (e, stackTrace) {
      _logger.e(
        'FirebaseException during Firestore operation',
        error: e,
        stackTrace: stackTrace,
      );
      _logger.e('Error code: ${e.code}, Message: ${e.message}');

      // If we created an auth user but failed to create Firestore docs, clean up
      if (user != null) {
        try {
          await user.delete();
          _logger.i('Cleaned up Firebase Auth user after Firestore error');
        } catch (deleteError) {
          _logger.e('Failed to delete auth user during cleanup: $deleteError');
        }
      }

      setState(() {
        _errorMessage = 'Failed to save user data. Please try again.';
      });

    } catch (e, stackTrace) {
      _logger.e(
        'Unexpected error during registration',
        error: e,
        stackTrace: stackTrace,
      );

      // If we created an auth user but encountered an error, clean up
      if (user != null) {
        try {
          await user.delete();
          _logger.i('Cleaned up Firebase Auth user after unexpected error');
        } catch (deleteError) {
          _logger.e('Failed to delete auth user during cleanup: $deleteError');
        }
      }

      setState(() {
        if (e.toString().contains('Username already taken')) {
          _errorMessage = 'This username is already taken. Please choose another.';
          _logger.w('Username taken: ${_usernameController.text.trim()}');
        } else {
          _errorMessage = 'An unexpected error occurred. Please try again.';
          _logger.e('Unknown error type: ${e.runtimeType}');
        }
      });

    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _logger.d('Registration process completed, loading state reset');
      }
    }
  }

  @override
  void dispose() {
    _logger.d('Disposing RegistrationScreen controllers');
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final isMediumScreen = size.width >= 600 && size.width < 900;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 20.0 : (isMediumScreen ? 40.0 : 60.0),
                    vertical: 24.0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isSmallScreen ? double.infinity : 500,
                    ),
                    child: Column(
                      children: [
                        // Logo and branding section
                        _buildBrandingSection(isSmallScreen),
                        
                        SizedBox(height: isSmallScreen ? 32 : 40),
                        
                        // Registration form card
                        _buildRegistrationCard(isSmallScreen),
                        
                        SizedBox(height: isSmallScreen ? 24 : 32),
                        
                        // Sign in section
                        _buildSignInSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingSection(bool isSmallScreen) {
    return Column(
      children: [
        // Logo with gradient background
        Container(
          width: isSmallScreen ? 80 : 96,
          height: isSmallScreen ? 80 : 96,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF7B2CBF),
                Color(0xFF5A189A),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B2CBF).withValues(alpha:0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_alt_1_rounded,
            size: 48,
            color: Colors.white,
          ),
        ),
        
        SizedBox(height: isSmallScreen ? 20 : 24),
        
        // Welcome text
        Text(
          'Join AlmaHub',
          style: TextStyle(
            fontSize: isSmallScreen ? 28 : 34,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A2E),
            letterSpacing: -0.5,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Create your account to get started',
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 15,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationCard(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black..withValues(alpha:0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 24.0 : 32.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error message (if any)
              if (_errorMessage != null) ...[
                _buildErrorMessage(),
                const SizedBox(height: 20),
              ],
              
              // Username field
              _buildUsernameField(),
              
              const SizedBox(height: 20),
              
              // Email field
              _buildEmailField(),
              
              const SizedBox(height: 20),
              
              // Password field
              _buildPasswordField(),
              
              const SizedBox(height: 20),
              
              // Confirm Password field
              _buildConfirmPasswordField(),
              
              SizedBox(height: isSmallScreen ? 28 : 32),
              
              // Register button
              _buildRegisterButton(isSmallScreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFECACA),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Full Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _usernameController,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your full name',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 15,
            ),
            prefixIcon: const Icon(
              Icons.account_circle_outlined,
              color: Color(0xFF64748B),
              size: 20,
            ),
            suffixIcon: Tooltip(
              message: 'Spaces are allowed in your name',
              child: Icon(
                Icons.info_outline,
                color: const Color(0xFF64748B).withValues(alpha:0.6),
                size: 18,
              ),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF7B2CBF),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Full name is required';
            }
            if (value.trim().length < 3) {
              return 'Name must be at least 3 characters';
            }
            if (!_isValidUsernameFormat(value.trim())) {
              return 'Only letters, numbers, and spaces allowed';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email Address',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'you@example.com',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 15,
            ),
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: Color(0xFF64748B),
              size: 20,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF7B2CBF),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Email is required';
            }
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'Create a strong password',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 15,
            ),
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: Color(0xFF64748B),
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF64748B),
                size: 20,
              ),
              onPressed: () => setState(
                () => _obscurePassword = !_obscurePassword,
              ),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF7B2CBF),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirm Password',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'Re-enter your password',
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 15,
            ),
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: Color(0xFF64748B),
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF64748B),
                size: 20,
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF7B2CBF),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildRegisterButton(bool isSmallScreen) {
    return SizedBox(
      height: isSmallScreen ? 52 : 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7B2CBF),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          disabledForegroundColor: const Color(0xFF94A3B8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }

  Widget _buildSignInSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Already have an account? ',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        TextButton(
          onPressed: () {
            _logger.i('Navigating to LoginScreen');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              ),
            );
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Sign In',
            style: TextStyle(
              color: Color(0xFF7B2CBF),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}