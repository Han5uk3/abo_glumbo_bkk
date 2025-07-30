import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:abo_glumbo_bbk/pages/login/login_page.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasInitialized = false;
  bool _isUserLogout = false;

  @override
  void initState() {
    super.initState();
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
    }

    Future.delayed(const Duration(seconds: 2), () {
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
            MaterialPageRoute(builder: (context) => LoginPage()),
            (Route<dynamic> route) => false,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.primary,
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: SvgPicture.asset(
                      state.locale.languageCode == "ar"
                          ? 'assets/svg/logo_wide_white_ar.svg'
                          : 'assets/svg/logo_wide_white_en.svg',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 60),

                  
                  const SizedBox(
                    width: 60,
                    height: 60,
                    child: Center(
                      child: Loader(color: Colors.white, size: 38.0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
