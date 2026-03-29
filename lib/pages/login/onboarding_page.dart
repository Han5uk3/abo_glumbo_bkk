import 'package:abo_glumbo_bbk/pages/login/widgets/language_selector.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // PageView for onboarding screens
            // PageView(
            //   controller: _pageController,
            //   children: [
            // // Screen 1
            // _buildOnboardingScreen(
            //   context,
            //   screenHeight,
            //   screenWidth,
            //   icon: Icons.home_repair_service_rounded,
            //   title: 'Welcome to Abo Glumbo!',
            //   description:
            //       'We are your new partner for peace of mind. Ready for your home maintenance? Start your first request now.',
            //   color: const Color(0xFF0A2A5E),
            // ),
            // // Screen 2
            // _buildOnboardingScreen(
            //   context,
            //   screenHeight,
            //   screenWidth,
            //   icon: Icons.verified_user_rounded,
            //   title: 'Trusted Professionals',
            //   description:
            //       'All our technicians are verified, trained, and ready to help you with any home maintenance needs.',
            //   color: const Color(0xFF1E5AB6),
            // ),
            // // Screen 3
            _buildOnboardingScreen(
              context,
              screenHeight,
              screenWidth,
              icon: Icons.schedule_rounded,
              title: 'Reliable Home Services at Your Fingertips',
              description:
                  'Find trusted professionals for repairs, installations, and maintenance in just a few taps.',
              color: const Color(0xFF2A6FD4),
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
                  // color: Colors.white,
                  // boxShadow: [
                  //   BoxShadow(
                  //     color: Colors.black.withOpacity(0.08),
                  //     blurRadius: 10,
                  //     offset: const Offset(0, -2),
                  //   ),
                  // ],
                ),
                padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page Indicator
                    // SmoothPageIndicator(
                    //   controller: _pageController,
                    //   count: 3,
                    //   effect: ExpandingDotsEffect(
                    //     dotHeight: 8,
                    //     dotWidth: 8,
                    //     activeDotColor: AppColors.secondary,
                    //     dotColor: Colors.grey.shade300,
                    //     spacing: 6,
                    //   ),
                    // ),
                    // const SizedBox(height: 32),
                    // Navigation Buttons

                    // if (_currentPage < 2)
                    //   Row(
                    //     children: [
                    //       // Skip Button
                    //       if (_currentPage > 0)
                    //         Expanded(
                    //           child: SizedBox(
                    //             height: 56,
                    //             child: OutlinedButton(
                    //               onPressed: () => _pageController.previousPage(
                    //                 duration: const Duration(milliseconds: 300),
                    //                 curve: Curves.easeInOut,
                    //               ),
                    //               style: OutlinedButton.styleFrom(
                    //                 side: BorderSide(
                    //                   color: AppColors.secondary,
                    //                   width: 2,
                    //                 ),
                    //                 shape: RoundedRectangleBorder(
                    //                   borderRadius: BorderRadius.circular(12),
                    //                 ),
                    //               ),
                    //               child: Text(
                    //                 'Back',
                    //                 style: DMSansFont.textStyle(
                    //                   color: AppColors.secondary,
                    //                   fontSize: 16,
                    //                   fontWeight: FontWeight.w600,
                    //                 ),
                    //               ),
                    //             ),
                    //           ),
                    //         ),
                    //       if (_currentPage > 0) const SizedBox(width: 12),
                    //       // Next/Start Button
                    //       Expanded(
                    //         child: SizedBox(
                    //           height: 56,
                    //           child: ElevatedButton(
                    //             onPressed: () {
                    //               if (_currentPage < 2) {
                    //                 _pageController.nextPage(
                    //                   duration: const Duration(
                    //                     milliseconds: 300,
                    //                   ),
                    //                   curve: Curves.easeInOut,
                    //                 );
                    //               } else {
                    //                 _navigateToLogin();
                    //               }
                    //             },
                    //             style: ElevatedButton.styleFrom(
                    //               backgroundColor: AppColors.secondary,
                    //               shape: RoundedRectangleBorder(
                    //                 borderRadius: BorderRadius.circular(12),
                    //               ),
                    //               elevation: 0,
                    //             ),
                    //             child: Text(
                    //               'Next',
                    //               style: DMSansFont.textStyle(
                    //                 color: Colors.white,
                    //                 fontSize: 16,
                    //                 fontWeight: FontWeight.w600,
                    //               ),
                    //             ),
                    //           ),
                    //         ),
                    //       ),
                    //     ],
                    //   )
                    // else
                    // Start Now Button on last screen
                    SizedBox(
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
                          'Start Now',
                          style: DMSansFont.textStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Close/Skip button in top right
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: _navigateToLogin,
                child: LanguageSelectorCard(isInLoginPage: false),

                //  Container(
                //   padding: const EdgeInsets.all(8),
                //   decoration: BoxDecoration(
                //     color: Colors.white,
                //     borderRadius: BorderRadius.circular(8),
                //     boxShadow: [
                //       BoxShadow(
                //         color: Colors.black.withOpacity(0.1),
                //         blurRadius: 4,
                //       ),
                //     ],
                //   ),
                //   child: Icon(
                //     Icons.close,
                //     color: AppColors.secondary,
                //     size: 20,
                //   ),
                // ),
              ),
            ),
          ],
        ),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withOpacity(0.8)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                top: 0,
                bottom: 0, // Remove bottom constraint
                child: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: Image.asset(
                    "assets/images/Ellipse1.png",
                    fit: BoxFit.fill,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0, // Remove bottom constraint
                child: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: Image.asset(
                    "assets/images/Ellipse1.png",
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: DMSansFont.textStyle(
                fontSize: 22,
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
              style: DMSansFont.textStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.9),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
