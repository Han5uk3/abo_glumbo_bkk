import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:abo_glumbo_bbk/pages/login/onboarding_page.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _hasInitialized = false;
  bool _isUserLogout = false;

  late AnimationController _logoController;
  late AnimationController _taglineController;
  late AnimationController _pulseController;

  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _taglineAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _taglineController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _taglineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (!_hasInitialized) {
      _hasInitialized = true;
      String savedLanguage = LocalStoreHelper.getUserlanguage();
      _isUserLogout = LocalStoreHelper.getLogoutStatus();
      final currentLocale = context
          .read<AccountBloc>()
          .state
          .locale
          .languageCode;
      if (currentLocale != savedLanguage) {
        context.read<AccountBloc>().add(
          ChangeLocale(languageCode: savedLanguage),
        );
      }
      _startAnimationSequence();
      // _initializeApp();
    }
  }

  void _startAnimationSequence() async {
    _pulseController.repeat(reverse: true);

    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) _taglineController.forward();
  }

  void _initializeApp() async {
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      if (LocalStoreHelper.getUID() != null && !_isUserLogout) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => Home()),
          (Route<dynamic> route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingPage()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _taglineController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, state) {
        return Scaffold(
          body: Stack(
            children: [
              // 1. Solid Background
              Container(
                width: double.infinity,
                height: double.infinity,
                color: AppColors.primary,
              ),

              // 2. Large Shape at Bottom (Rectangle + Triangle Top)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CustomPaint(
                  size: Size(screenWidth, screenHeight * 0.35),
                  painter: BottomShapePainter(
                    color: const Color(0xFF143D82).withOpacity(0.5),
                  ),
                ),
              ),

              // 3. Central Content (Logo & Text)
              SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _logoController,
                          _pulseController,
                        ]),
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _logoFadeAnimation,
                            child: ScaleTransition(
                              scale: _logoScaleAnimation,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Logo
                                  SizedBox(
                                    width: 120,
                                    height: 120,
                                    child: Image.asset(
                                      'assets/icons/app_icon.png',
                                      color: Colors.white,
                                      fit: BoxFit.contain,
                                    ),
                                  ),

                                  // Text
                                  Text(
                                    state.locale.languageCode == "ar"
                                        ? "ابو جلمبو"
                                        : "Abo Glumbo",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BottomShapePainter extends CustomPainter {
  final Color color;
  BottomShapePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path();
    // Draws a pentagon shape (rectangle with a triangle on top)
    path.moveTo(0, size.height); // bottom left
    path.lineTo(0, size.height * 0.6); // top of rectangle part
    path.lineTo(size.width / 2, 0); // peak of triangle
    path.lineTo(size.width, size.height * 0.6); // top of rectangle right
    path.lineTo(size.width, size.height); // bottom right
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
