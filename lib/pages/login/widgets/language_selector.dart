import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:abo_glumbo_bbk/pages/accounts/widgets/language_dialog.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LanguageSelectorCard extends StatelessWidget {
  final bool isInLoginPage;

  const LanguageSelectorCard({super.key, required this.isInLoginPage});

  static String _getFlag(String code) {
    switch (code) {
      case 'ar':
        return '🇸🇦';
      case 'ur':
        return '🇵🇰';
      default:
        return '🇬🇧';
    }
  }

  static String _getLanguageLabel(String code) {
    switch (code) {
      case 'ar':
        return 'العربية';
      case 'ur':
        return 'اردو';
      default:
        return 'EN';
    }
  }

  void _showLanguageDialog(BuildContext context) {
    final currentCode = context.read<AccountBloc>().state.locale.languageCode;

    showDialog(
      context: context,
      builder: (dialogContext) => LanguageSelectionDialog(
        title: AppLocalizations.of(context)?.selectLanguage ?? 'Select Language',
        currentLanguageCode: currentCode,
        onEnglishSelected: () {
          context.read<AccountBloc>().add(ChangeLocale(languageCode: 'en'));
        },
        onArabicSelected: () {
          context.read<AccountBloc>().add(ChangeLocale(languageCode: 'ar'));
        },
        onUrduSelected: () {
          context.read<AccountBloc>().add(ChangeLocale(languageCode: 'ur'));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, state) {
        final currentCode = state.locale.languageCode;
        final flag = _getFlag(currentCode);
        final label = _getLanguageLabel(currentCode);

        return GestureDetector(
          onTap: () => _showLanguageDialog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary.withOpacity(0.7),
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
