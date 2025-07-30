import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          const SizedBox(width: double.infinity),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SvgPicture.asset(
              // selectedLanguage.code == "ar"
              //     ? 'assets/svg/logo_wide_white_ar.svg'
              // :
              'assets/svg/logo_wide_white_en.svg',
              height: 80,
            ),
          ),
          const SizedBox(height: 50),
          Loader(color: Colors.white, size: 38.0),
        ],
      ),
    );
  }
}
