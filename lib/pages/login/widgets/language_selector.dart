import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class LanguageSelectorCard extends StatelessWidget {
  final String currentLanguageCode;

  const LanguageSelectorCard({super.key, required this.currentLanguageCode});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCardLanguageOption(
              context,
              'en',
              'EN',
              '🇺🇸',
              isSelected: currentLanguageCode == 'en',
            ),
            _buildCardLanguageOption(
              context,
              'ar',
              'AR',
              '🇸🇦',
              isSelected: currentLanguageCode == 'ar',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardLanguageOption(
    BuildContext context,
    String langCode,
    String langShort,
    String flag, {
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        if (langCode != currentLanguageCode) {
          context.read<AccountBloc>().add(
            ChangeLocale(languageCode: langCode),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 60,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.white.withOpacity(0.2) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              flag,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.dmSans(
                color: isSelected 
                    ? Colors.white 
                    : Colors.white.withOpacity(0.7),
                fontSize: 11,
                fontWeight: isSelected 
                    ? FontWeight.w700 
                    : FontWeight.w500,
                letterSpacing: 0.5,
              ),
              child: Text(langShort),
            ),
          ],
        ),
      ),
    );
  }
}
