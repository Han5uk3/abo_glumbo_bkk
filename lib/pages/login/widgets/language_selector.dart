import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

class LanguageSelectorCard extends StatelessWidget {
  final bool isInLoginPage;

  const LanguageSelectorCard({super.key, required this.isInLoginPage});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, state) {
        final currentLanguageCode = state.locale.languageCode;

        return Center(
          child: isInLoginPage
              ? Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCardLanguageOption(
                        context,
                        'en',
                        'EN',
                        isSelected: currentLanguageCode == 'en',
                      ),
                      const SizedBox(width: 1),
                      _buildCardLanguageOption(
                        context,
                        'ar',
                        'AR',
                        isSelected: currentLanguageCode == 'ar',
                      ),
                    ],
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCardLanguageOption(
                        context,
                        'en',
                        'EN',
                        isSelected: currentLanguageCode == 'en',
                      ),
                      const SizedBox(width: 1),
                      _buildCardLanguageOption(
                        context,
                        'ar',
                        'AR',
                        isSelected: currentLanguageCode == 'ar',
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildCardLanguageOption(
    BuildContext context,
    String langCode,
    String langShort, {

    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        final currentState = context.read<AccountBloc>().state;
        final currentLanguageCode = currentState.locale.languageCode;
        if (langCode != currentLanguageCode) {
          context.read<AccountBloc>().add(ChangeLocale(languageCode: langCode));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 56,
        height: 40,
        decoration: BoxDecoration(
          color: isInLoginPage
              ? isSelected
                    ? Colors.white.withOpacity(0.25)
                    : Colors.transparent
              : isSelected
              ? AppColors.primary
              : Colors.transparent,

          borderRadius: BorderRadius.circular(12),
          border: isInLoginPage
              ? isSelected
                    ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
                    : null
              : null,
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: DMSansFont.textStyle(
              color: isInLoginPage
                  ? isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.7)
                  : isSelected
                  ? Colors.white
                  : AppColors.primary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.8,
            ),
            child: Text(langShort),
          ),
        ),
      ),
    );
  }
}
