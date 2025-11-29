import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(locale.privacyPolicy)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 24),
            _buildText(locale.policy1, locale.policy1title, 1),
            SizedBox(height: 8),
            _buildText(locale.policy2, locale.policy2title, 2),
            SizedBox(height: 8),
            _buildText(locale.policy3, locale.policy3title, 3),
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
