import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key, required this.isFromLogin});

  final bool isFromLogin;

  @override
  Widget build(BuildContext context) {
    final fontStyle = DMSansFont.textStyle(color: Colors.black);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFromLogin
              ? AppLocalizations.of(context)!.termsOfUse
              : AppLocalizations.of(context)?.termsAndConditions ??
                    'Terms and Conditions',
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${AppLocalizations.of(context)?.introduction}",
              style: DMSansFont.textStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "${AppLocalizations.of(context)?.termsIntroduction}",
              style: DMSansFont.textStyle(color: Colors.black, fontSize: 16),
            ),
            SizedBox(height: 16),
            _buildText(AppLocalizations.of(context)?.terms1 ?? '', 1),
            SizedBox(height: 6),
            _buildText(AppLocalizations.of(context)?.terms2 ?? '', 2),
            SizedBox(height: 6),
            _buildText(AppLocalizations.of(context)?.terms3 ?? '', 3),
            SizedBox(height: 6),
            _buildText(AppLocalizations.of(context)?.terms4 ?? '', 4),
            SizedBox(height: 6),
            _buildText(AppLocalizations.of(context)?.terms5 ?? '', 5),
          ],
        ),
      ),
    );
  }

  Widget _buildText(String text, int index) {
    return Text(
      "$index. $text",
      style: DMSansFont.textStyle(color: Colors.black, fontSize: 16),
    );
  }
}
