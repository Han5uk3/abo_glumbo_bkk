import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/login/widgets/language_selector.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.bgBlueTint,
      body: Stack(
        children: [
          // // Screen 3
          Positioned.fill(
            child: _buildOnboardingScreen(
              context,
              screenHeight,
              screenWidth,
              icon: Icons.schedule_rounded,
              title: AppLocalizations.of(context)!.onboard1,
              description: AppLocalizations.of(context)!.onboard1desc,
              color: AppColors.primary,
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              height: screenHeight * 0.3,
              width: screenWidth,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.only(
                  bottomLeft: Directionality.of(context) == TextDirection.ltr
                      ? Radius.circular(12)
                      : Radius.circular(0),
                  bottomRight: Directionality.of(context) == TextDirection.ltr
                      ? Radius.circular(0)
                      : Radius.circular(12),
                ),
              ),
            ),
          ),

          //   ],
          // ),
          // Bottom section with page indicator and button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
              ),
              padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
              margin: EdgeInsets.fromLTRB(0, 24, 0, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _navigateToLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bgWhite,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 10,
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.getStarted,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Close/Skip button in top right
          Positioned(
            top: kToolbarHeight + 6,
            right: Directionality.of(context) == TextDirection.ltr ? 16 : null,
            left: Directionality.of(context) == TextDirection.ltr ? null : 16,
            child: LanguageSelectorCard(isInLoginPage: false),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingScreen(
    BuildContext context,
    double screenHeight,
    double screenWidth, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(color: color),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image/Icon Section
          SizedBox(
            height: screenHeight * 0.37,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    height: screenHeight * 0.3,

                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
                Center(
                  child: SizedBox(
                    height: screenHeight * 0.3,
                    width: screenWidth,
                    child: Image.asset(
                      "assets/onboardImage.png",
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                //box over the image with text
                Positioned(
                  bottom: 0,
                  left: screenWidth * 0.16,
                  right: screenWidth * 0.16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
                      child: Container(
                        width: screenWidth * 0.8,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  size: 14,
                                  Icons.verified_user,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Text(
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                AppLocalizations.of(
                                  context,
                                )!.verifiedAndProfessionalTechnicians,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}
