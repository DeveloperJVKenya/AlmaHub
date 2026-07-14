import 'package:almahub/screens/role_selection_screen.dart';
import 'package:almahub/screens/employee/employee_dashboard.dart';
import 'package:almahub/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

/// LoginScreen — Sign-in only.
/// The Sign Up link has been removed: registration is exclusively accessible
/// through the RecruitmentStatusScreen after an application is ACCEPTED.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    _logger.i('LoginScreen initialized');
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _logger.d('LoginScreen disposing');
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _formatUsernameForDisplay(String username) {
    return username.replaceAll('_', ' ');
  }

  Future<AppUser?> _getUserByUid(String uid) async {
    _logger.i('Searching for user with UID: $uid in Users collection');
    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userData = userQuery.docs.first.data();
        _logger.i('User found in Users collection — role: ${userData['role']}');
        return AppUser.fromMap(userData);
      }

      _logger.e('User not found in Users collection for UID: $uid');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Error searching Users collection', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<Map<String, dynamic>?> _findUserDataByEmail(String email, String uid) async {
    _logger.i('Searching user data for email: $email, uid: $uid');

    try {
      // Draft and submitted onboarding records both live in EmployeeDetails
      // now — `status` distinguishes them, not the collection.
      final employeeQuery = await FirebaseFirestore.instance
          .collection('EmployeeDetails')
          .where('personalInfo.email', isEqualTo: email)
          .limit(1)
          .get();

      if (employeeQuery.docs.isNotEmpty) {
        final doc = employeeQuery.docs.first;
        if (doc.data()['uid'] == uid) {
          _logger.i('User found in EmployeeDetails via personalInfo.email');
          return {
            'collection': 'EmployeeDetails',
            'documentId': doc.id,
            'data': doc.data(),
            'username': doc.data()['registrationUsername'] ?? doc.id,
            'status': doc.data()['status'],
          };
        }
      }

      // Fallback: check by registrationEmail field
      final empEmailQuery = await FirebaseFirestore.instance
          .collection('EmployeeDetails')
          .where('registrationEmail', isEqualTo: email)
          .limit(1)
          .get();

      if (empEmailQuery.docs.isNotEmpty) {
        final doc = empEmailQuery.docs.first;
        if (doc.data()['uid'] == uid) {
          _logger.i('User found in EmployeeDetails via registrationEmail');
          return {
            'collection': 'EmployeeDetails',
            'documentId': doc.id,
            'data': doc.data(),
            'username': doc.data()['registrationUsername'] ?? doc.id,
            'status': doc.data()['status'],
          };
        }
      }

      _logger.e('User not found in Draft or EmployeeDetails for email: $email');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Error searching user data', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _handleLogin() async {
    _logger.i('Login process initiated');

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;
      if (user == null) throw Exception('User not found after login');

      _logger.i('Firebase Auth successful — uid: ${user.uid}');

      // Step 2: Get role from Users collection
      final appUser = await _getUserByUid(user.uid);
      if (appUser == null) {
        throw Exception(
            'User profile not found. Please contact support.');
      }

      _logger.i('Role retrieved: ${appUser.role}');

      // Step 3: Find user data in Draft / EmployeeDetails
      final userData = await _findUserDataByEmail(email, user.uid);
      if (userData == null) {
        throw Exception(
            'User profile data not found. Please contact support.');
      }

      final username = userData['username'] as String;

      // Step 4: Navigate based on role
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, ${_formatUsernameForDisplay(username)}!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        if (appUser.isAdmin) {
          _logger.i('Navigating Admin to RoleSelectionScreen');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          );
        } else {
          _logger.i('Navigating ${appUser.role} to EmployeeDashboard');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const EmployeeDashboard()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _logger.e('FirebaseAuthException: ${e.code}');
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorMessage = 'No account found with this email address.';
            break;
          case 'wrong-password':
            _errorMessage = 'Incorrect password. Please try again.';
            break;
          case 'invalid-email':
            _errorMessage = 'Invalid email address format.';
            break;
          case 'user-disabled':
            _errorMessage = 'This account has been disabled.';
            break;
          case 'invalid-credential':
            _errorMessage = 'Invalid email or password.';
            break;
          case 'too-many-requests':
            _errorMessage = 'Too many failed attempts. Try again later.';
            break;
          default:
            _errorMessage = 'Login failed: ${e.message ?? "Unknown error"}';
        }
      });
    } catch (e) {
      _logger.e('Unexpected login error: $e');
      setState(() {
        _errorMessage = e.toString().contains('User profile')
            ? e.toString().replaceAll('Exception: ', '')
            : 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address first'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'invalid-email':
          message = 'Invalid email format.';
          break;
        default:
          message = 'Failed to send reset email.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
                    horizontal: isSmallScreen
                        ? 20.0
                        : (isMediumScreen ? 40.0 : 60.0),
                    vertical: 24.0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isSmallScreen ? double.infinity : 480,
                    ),
                    child: Column(
                      children: [
                        _buildBrandingSection(isSmallScreen),
                        SizedBox(height: isSmallScreen ? 32 : 40),
                        _buildLoginCard(isSmallScreen),
                        const SizedBox(height: 24),
                        // Informational note — no Sign Up link
                        _buildInfoNote(),
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
        Container(
          width: isSmallScreen ? 80 : 96,
          height: isSmallScreen ? 80 : 96,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7B2CBF), Color(0xFF5A189A)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B2CBF).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            size: 48,
            color: Colors.white,
          ),
        ),
        SizedBox(height: isSmallScreen ? 20 : 24),
        Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: isSmallScreen ? 28 : 34,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A2E),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to continue to your account',
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 15,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              if (_errorMessage != null) ...[
                _buildErrorMessage(),
                const SizedBox(height: 20),
              ],
              _buildEmailField(),
              const SizedBox(height: 20),
              _buildPasswordField(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _handleForgotPassword,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                  ),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Color(0xFF7B2CBF),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 24 : 28),
              _buildLoginButton(isSmallScreen),
            ],
          ),
        ),
      ),
    );
  }

  /// Replaces the old "Don't have an account? Sign Up" row.
  /// Explains that account creation is invitation-only (post-acceptance).
  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF7B2CBF).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF7B2CBF).withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: Color(0xFF7B2CBF), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'New accounts are created through the recruitment process after application acceptance.',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_errorMessage!,
                style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Email Address',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155))),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 15),
          decoration: InputDecoration(
            hintText: 'you@example.com',
            hintStyle:
                const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
            prefixIcon: const Icon(Icons.email_outlined,
                color: Color(0xFF64748B), size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0), width: 1.5)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0), width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF7B2CBF), width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFDC2626), width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFDC2626), width: 2)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Email is required';
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
        const Text('Password',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155))),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
            prefixIcon: const Icon(Icons.lock_outline,
                color: Color(0xFF64748B), size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF64748B),
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0), width: 1.5)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0), width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF7B2CBF), width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFDC2626), width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFDC2626), width: 2)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Password is required';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildLoginButton(bool isSmallScreen) {
    return SizedBox(
      height: isSmallScreen ? 52 : 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7B2CBF),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          disabledForegroundColor: const Color(0xFF94A3B8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : const Text('Sign In',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
      ),
    );
  }
}