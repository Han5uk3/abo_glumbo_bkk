import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fontStyle = DMSansFont.textStyle(color: Colors.black);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.privacyPolicy)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),

            _buildText(AppLocalizations.of(context)?.policy1 ?? '', 1),
            SizedBox(height: 6),
            _buildText(AppLocalizations.of(context)?.policy2 ?? '', 2),
            SizedBox(height: 6),
            _buildText(AppLocalizations.of(context)?.policy3 ?? '', 3),
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
