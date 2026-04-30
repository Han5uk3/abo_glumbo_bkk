import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

class LanguageSelectionDialog extends StatelessWidget {
  final String title;
  final VoidCallback? onEnglishSelected;
  final VoidCallback? onArabicSelected;
  final VoidCallback? onUrduSelected;
  final String? currentLanguageCode;

  const LanguageSelectionDialog({
    super.key,
    required this.title,
    this.onEnglishSelected,
    this.onArabicSelected,
    this.onUrduSelected,
    this.currentLanguageCode,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgBlueTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.translate_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: DMSansFont.textStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Divider
            Divider(color: Colors.grey.withOpacity(0.2), height: 1),
            const SizedBox(height: 8),
            // Language options
            _LanguageOptionTile(
              languageCode: 'en',
              languageName: 'English',
              nativeName: 'English',
              flag: '🇬🇧',
              isSelected: currentLanguageCode == 'en',
              onTap: () {
                Navigator.pop(context);
                onEnglishSelected?.call();
              },
            ),
            _LanguageOptionTile(
              languageCode: 'ar',
              languageName: 'Arabic',
              nativeName: 'العربية',
              flag: '🇸🇦',
              isSelected: currentLanguageCode == 'ar',
              onTap: () {
                Navigator.pop(context);
                onArabicSelected?.call();
              },
            ),
            if (onUrduSelected != null)
              _LanguageOptionTile(
                languageCode: 'ur',
                languageName: 'Urdu',
                nativeName: 'اردو',
                flag: '🇵🇰',
                isSelected: currentLanguageCode == 'ur',
                onTap: () {
                  Navigator.pop(context);
                  onUrduSelected?.call();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  final String languageCode;
  final String languageName;
  final String nativeName;
  final String flag;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOptionTile({
    required this.languageCode,
    required this.languageName,
    required this.nativeName,
    required this.flag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isSelected
            ? AppColors.primary.withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.15),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nativeName,
                        style: DMSansFont.textStyle(
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.black1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        languageName,
                        style: DMSansFont.textStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isSelected
                      ? Container(
                          key: const ValueKey('selected'),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey('unselected'),
                          width: 24,
                          height: 24,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
