import 'package:abo_glumbo_bbk/helpers/constants.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ContactService {
  static Future<void> launchEmail() async {
    await launchUrlString("mailto:${AccountPageConstants.supportEmail}");
  }

  static Future<void> launchWhatsApp() async {
    await launchUrlString(AccountPageConstants.whatsappUrl);
  }
}

class ContactBottomSheet extends StatelessWidget {
  const ContactBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context)?.contactSupportOptions ?? "",
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _ContactOption(
            icon: Icons.email,
            iconColor: AppColors.primary,
            title: AppLocalizations.of(context)?.contactByEmail ?? "",
            onTap: () async {
              Navigator.pop(context);
              await ContactService.launchEmail();
            },
          ),
          _ContactOption(
            icon: Icons.chat,
            iconColor: Colors.green,
            title: AppLocalizations.of(context)?.contactByWhatsApp ?? "",
            onTap: () async {
              Navigator.pop(context);
              await ContactService.launchWhatsApp();
            },
          ),
        ],
      ),
    );
  }
}

class _ContactOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _ContactOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: GoogleFonts.dmSans(fontSize: 16, color: AppColors.black1),
      ),
      onTap: onTap,
    );
  }
}
