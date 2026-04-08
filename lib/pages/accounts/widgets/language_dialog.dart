import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

class LanguageSelectionDialog extends StatelessWidget {
  final String title;
  final VoidCallback? onEnglishSelected;
  final VoidCallback? onArabicSelected;
  final String? currentLanguage;

  const LanguageSelectionDialog({
    super.key,
    required this.title,
    this.onEnglishSelected,
    this.onArabicSelected,
    this.currentLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgBlueTint,
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LanguageOption(
            language: 'English',
            isSelected: currentLanguage == 'English',
            onTap: () {
              Navigator.pop(context);
              onEnglishSelected?.call();
            },
          ),
          _LanguageOption(
            language: 'العربية',
            isSelected: currentLanguage == 'العربية',
            onTap: () {
              Navigator.pop(context);
              onArabicSelected?.call();
            },
          ),
        ],
      ),
    );
  }
}

enum LanguageOption { english, arabic }

class _LanguageOption extends StatelessWidget {
  final String language;
  final VoidCallback onTap;
  final bool isSelected;

  const _LanguageOption({
    required this.language,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        language,
        style: DMSansFont.textStyle(fontSize: 14, color: AppColors.black1),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: AppColors.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
