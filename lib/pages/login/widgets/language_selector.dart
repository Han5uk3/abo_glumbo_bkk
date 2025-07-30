import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LanguageSelector extends StatelessWidget {
  final String currentLanguageCode;

  const LanguageSelector({super.key, required this.currentLanguageCode});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: SegmentedButton<String>(
          style: SegmentedButton.styleFrom(
            backgroundColor: Colors.white,
            selectedBackgroundColor: Theme.of(
              context,
            ).primaryColor.withOpacity(0.1),
            selectedForegroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.black,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          segments: const <ButtonSegment<String>>[
            ButtonSegment<String>(value: 'en', label: Text('English')),
            ButtonSegment<String>(value: 'ar', label: Text('العربية')),
          ],
          selected: {currentLanguageCode},
          onSelectionChanged: (newSelection) {
            final selectedLang = newSelection.first;
            context.read<AccountBloc>().add(
              ChangeLocale(languageCode: selectedLang),
            );
          },
        ),
      ),
    );
  }
}
