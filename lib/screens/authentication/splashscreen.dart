import 'package:almahub/screens/authentication/login_screen.dart';
import 'package:almahub/screens/role_selection_screen.dart';
import 'package:almahub/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _progressController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;

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
    _logger.i('SplashScreen initialized');
    _initializeAnimations();
    _checkAuthStatus();
  }

  void _initializeAnimations() {
    _logger.d('Initializing animations');

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _logoController.forward();
    Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _textController.forward();
        _logger.d('Text animation started');
      }
    });
    Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        _progressController.repeat();
        _logger.d('Progress animation started');
      }
    });
  }

  /// Main auth routing logic:
  ///
  /// 1. No Firebase Auth user → WelcomeScreen
  /// 2. Auth user found, exists in Users collection → LoginScreen
  ///    (they are a registered employee; force re-login for security)
  /// 3. Auth user found, exists in Draft/EmployeeDetails → RoleSelectionScreen
  ///    (they are mid-onboarding or fully onboarded admins)
  /// 4. Auth user found but no matching Firestore document → sign out → WelcomeScreen
  Future<void> _checkAuthStatus() async {
    _logger.i('Starting authentication status check');

    // Allow animations to play
    await Future.delayed(const Duration(seconds: 5));

    if (!mounted) {
      _logger.w('Widget not mounted, aborting auth check');
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _logger.i('No authenticated user — navigating to WelcomeScreen');
        _navigateTo(const WelcomeScreen());
        return;
      }

      _logger.i('Authenticated user found: uid=${user.uid}, email=${user.email}');

      // ── Check 1: Users collection (registered employees) ──────────────────
      _logger.d('Checking Users collection for uid: ${user.uid}');
      final usersQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (usersQuery.docs.isNotEmpty) {
        final userData = usersQuery.docs.first.data();
        final role = userData['role'] as String?;
        _logger.i('User found in Users collection — role: $role');

        if (role == 'Admin') {
          // Admin goes straight to RoleSelectionScreen
          _logger.i('Admin user — navigating to RoleSelectionScreen');
          _navigateTo(const RoleSelectionScreen());
        } else {
          // Regular registered user → show LoginScreen so they authenticate
          // fresh (avoids session confusion after a recruitment flow).
          _logger.i('Registered user (non-Admin) — navigating to LoginScreen');
          _navigateTo(const LoginScreen());
        }
        return;
      }

      // ── Check 2: EmployeeDetails collection (onboarding record, draft or
      // submitted — `status` distinguishes them, not the collection; either
      // way this user has a record and goes to RoleSelectionScreen) ─────────
      _logger.d('Checking EmployeeDetails collection for uid: ${user.uid}');
      final employeeQuery = await FirebaseFirestore.instance
          .collection('EmployeeDetails')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (employeeQuery.docs.isNotEmpty) {
        final employeeData = employeeQuery.docs.first.data();
        final username = employeeData['personalInfo']?['fullName'] ??
            employeeQuery.docs.first.id;
        _logger.i('User found in EmployeeDetails: $username — navigating to RoleSelectionScreen');
        _navigateTo(const RoleSelectionScreen());
        return;
      }

      // ── No matching Firestore document — clean up and go to WelcomeScreen ──
      _logger.w(
          'Authenticated user has no matching Firestore document — signing out');
      await FirebaseAuth.instance.signOut();
      _navigateTo(const WelcomeScreen());
    } on FirebaseAuthException catch (e) {
      _logger.e('FirebaseAuthException during auth check',
          error: e, stackTrace: e.stackTrace);
      _navigateTo(const WelcomeScreen());
    } on FirebaseException catch (e) {
      _logger.e('FirebaseException during Firestore query',
          error: e, stackTrace: e.stackTrace);
      _navigateTo(const WelcomeScreen());
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during auth check',
          error: e, stackTrace: stackTrace);
      _navigateTo(const WelcomeScreen());
    }
  }

  void _navigateTo(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  void dispose() {
    _logger.d('SplashScreen disposing');
    _logoController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 600;

    final logoSize = isSmallScreen ? 60.0 : (isMediumScreen ? 70.0 : 80.0);
    final titleFontSize =
        isSmallScreen ? 24.0 : (isMediumScreen ? 28.0 : 32.0);
    final subtitleFontSize =
        isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0);
    final taglineFontSize =
        isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Stack(
          children: [
            _buildBackgroundDecoration(),
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight = constraints.maxHeight;
                  return SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: availableHeight,
                        maxWidth: isMediumScreen ? 500 : 600,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.08,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: availableHeight * 0.12),

                            // Logo with scale animation
                            ScaleTransition(
                              scale: _logoAnimation,
                              child: Container(
                                width: isSmallScreen
                                    ? 120
                                    : (isMediumScreen ? 140 : 160),
                                height: isSmallScreen
                                    ? 120
                                    : (isMediumScreen ? 140 : 160),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF7B2CBF),
                                      Color(0xFF5A189A),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7B2CBF)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 30,
                                      offset: const Offset(0, 10),
                                    ),
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.business_center,
                                  size: logoSize,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            SizedBox(height: availableHeight * 0.05),

                            // Animated company name
                            FadeTransition(
                              opacity: _textFadeAnimation,
                              child: SlideTransition(
                                position: _textSlideAnimation,
                                child: Column(
                                  children: [
                                    Text(
                                      'JV Almacis',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: titleFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1A1A2E),
                                        letterSpacing: -0.5,
                                        height: 1.2,
                                      ),
                                    ),

                                    SizedBox(height: availableHeight * 0.025),

                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 16 : 20,
                                        vertical: isSmallScreen ? 8 : 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7B2CBF)
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF7B2CBF)
                                              .withValues(alpha: 0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'Employee Onboarding System',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: subtitleFontSize,
                                          color: const Color(0xFF7B2CBF),
                                          letterSpacing: 0.3,
                                          fontWeight: FontWeight.w600,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: availableHeight * 0.015),

                                    Text(
                                      'Italian Excellence, Global Reach',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: taglineFontSize,
                                        color: const Color(0xFF64748B),
                                        letterSpacing: 0.5,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: availableHeight * 0.12),

                            // Loading indicator
                            FadeTransition(
                              opacity: _textFadeAnimation,
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: isSmallScreen ? 40 : 45,
                                    height: isSmallScreen ? 40 : 45,
                                    child: const CircularProgressIndicator(
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Color(0xFF7B2CBF),
                                      ),
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  SizedBox(height: availableHeight * 0.025),
                                  Text(
                                    'Loading your workspace...',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: taglineFontSize,
                                      color: const Color(0xFF64748B),
                                      letterSpacing: 0.3,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: availableHeight * 0.1),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundDecoration() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF7B2CBF).withValues(alpha: 0.05),
                  const Color(0xFF7B2CBF).withValues(alpha: 0.02),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -150,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF7B2CBF).withValues(alpha: 0.04),
                  const Color(0xFF7B2CBF).withValues(alpha: 0.02),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}