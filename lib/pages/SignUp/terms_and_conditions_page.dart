import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:flutter/material.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key, required this.isFromLogin});

  final bool isFromLogin;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFromLogin ? locale.termsOfUse : locale.termsAndConditions,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 24),
            _buildText(locale.terms1, locale.terms1title, 1),
            SizedBox(height: 8),
            _buildText(locale.terms2, locale.terms2title, 2),
            SizedBox(height: 8),
            _buildText(locale.terms3, locale.terms3title, 3),
            SizedBox(height: 8),
            _buildText(locale.terms4, locale.terms4title, 4),
            SizedBox(height: 8),
            _buildText(locale.terms5, locale.terms5title, 5),
          ],
        ),
      ),
    );
  }

  Widget _buildText(String text, String title, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$index. $title",
          style: DMSansFont.textStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 3),
        Text(
          text,
          style: DMSansFont.textStyle(color: Colors.black, fontSize: 14),
        ),
      ],
    );
  }
}
