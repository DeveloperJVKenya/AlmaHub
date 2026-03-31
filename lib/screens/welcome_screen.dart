import 'package:almahub/screens/recruitment/recruitment_portal_screen.dart';
//import 'package:almahub/screens/authentication/registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

/// WelcomeScreen is shown only to unauthenticated users (no sign-in link).
/// Authenticated users are routed directly from SplashScreen to LoginScreen
/// or RoleSelectionScreen — they never land here unless their session is
/// completely absent from Firestore.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
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
    _logger.i('WelcomeScreen initialized — unauthenticated user');
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _logger.d('Animations initialized and started');
  }

  @override
  void dispose() {
    _logger.d('WelcomeScreen disposing');
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _navigateToRecruitment() {
    _logger.i('Navigating to Recruitment Portal');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecruitmentPortalScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 600;

    _logger.d('Building WelcomeScreen — Width: $screenWidth, Height: $screenHeight');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      // ── ADMIN FAB — remove when done ────────────────────────
      /*floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegistrationScreen()),
          );
        },
        backgroundColor: const Color(0xFF7B2CBF),
        icon: const Icon(Icons.app_registration, color: Colors.white),
        label: const Text(
          'Register [TEST]',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      // ───────────────────────────────────────────────────────
      */
      body: SafeArea(
        child: Stack(
          children: [
            _buildBackgroundDecoration(),
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.08,
                        vertical: screenHeight * 0.05,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isMediumScreen ? 500 : 600,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo
                            _buildLogo(isSmallScreen),

                            SizedBox(height: screenHeight * 0.04),

                            // Welcome message
                            _buildWelcomeMessage(isSmallScreen, isMediumScreen),

                            SizedBox(height: screenHeight * 0.015),

                            _buildSubtitle(isSmallScreen),

                            SizedBox(height: screenHeight * 0.05),

                            // Recruitment button (only action for unauthenticated users)
                            _buildRecruitmentButton(),

                            SizedBox(height: screenHeight * 0.04),

                            _buildFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(bool isSmallScreen) {
    return Container(
      width: isSmallScreen ? 100 : 120,
      height: isSmallScreen ? 100 : 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7B2CBF),
            Color(0xFF5A189A),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.business_center,
        size: isSmallScreen ? 50 : 60,
        color: Colors.white,
      ),
    );
  }

  Widget _buildWelcomeMessage(bool isSmallScreen, bool isMediumScreen) {
    return Text(
      'Welcome to AlmaHub',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: isSmallScreen ? 26 : (isMediumScreen ? 30 : 34),
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1A1A2E),
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildSubtitle(bool isSmallScreen) {
    return Text(
      'Start your journey with JV Almacis.\nSubmit your application to join our team.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: isSmallScreen ? 14 : 16,
        color: const Color(0xFF64748B),
        height: 1.5,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildRecruitmentButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF9333EA),
            Color(0xFF7B2CBF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToRecruitment,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.work_outline,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join Our Team',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Submit your CV and application',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'New applicants — submit your CV to get started',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'JV Almacis — Italian Excellence, Global Reach',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        color: const Color(0xFF94A3B8),
        fontStyle: FontStyle.italic,
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
        Positioned(
          bottom: 100,
          right: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF9333EA).withValues(alpha: 0.03),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}