import 'dart:developer';

import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ContactService {
  static Future<void> launchEmail(String email) async {
    await launchUrlString("mailto:$email");
  }

  static Future<void> launchWhatsApp(String phoneNumber) async {
    final whatsappUrl = 'https://wa.me/$phoneNumber';
    await launchUrlString(whatsappUrl);
  }

  static Future<void> launchPhone(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);

    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $launchUri');
    }
  }
}

class ContactBottomSheet extends StatelessWidget {
  const ContactBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.3,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: StreamBuilder(
        stream: AppServices.getCustomerSupportdata(),
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: Loader(color: AppColors.primary));
          }
          if (asyncSnapshot.hasError) {
            return Center(
              child: Text(
                '${AppLocalizations.of(context)?.error ?? "Error"}: ${asyncSnapshot.error}',
              ),
            );
          }
          if (!asyncSnapshot.hasData || asyncSnapshot.data!.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context)?.noSupportAvailable ??
                    "No support available",
              ),
            );
          }
          final data = asyncSnapshot.data!;

          log(data.toString());
          return Column(
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
              Expanded(
                child: ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final type = data[index].type;
                    final content = data[index].detail;
                    return _ContactOption(
                      icon: getIcon(type),
                      iconColor: getColor(type),
                      title: getTitle(type, context),
                      onTap: getOnTap(type, content),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

IconData getIcon(String type) {
  switch (type) {
    case "Email":
      return Icons.email;
    case "WhatsApp":
      return Icons.chat;
    case "Phone":
      return Icons.phone;
    default:
      return Icons.help_outline;
  }
}

Color getColor(String type) {
  switch (type) {
    case "Email":
      return AppColors.primary;
    case "WhatsApp":
      return Colors.green;
    case "Phone":
      return AppColors.secondary;
    default:
      return AppColors.black2;
  }
}

String getTitle(String type, BuildContext context) {
  switch (type) {
    case "Email":
      return AppLocalizations.of(context)?.contactByEmail ?? "";
    case "WhatsApp":
      return AppLocalizations.of(context)?.contactByWhatsApp ?? "";
    case "Phone":
      return AppLocalizations.of(context)?.contactByPhone ?? "";
    default:
      return AppLocalizations.of(context)?.contactByPhone ?? "";
  }
}

getOnTap(String type, String content) {
  switch (type) {
    case "Email":
      return () async {
        await ContactService.launchEmail(content);
      };
    case "WhatsApp":
      return () async {
        await ContactService.launchWhatsApp(content);
      };
    case "Phone":
      return () async {
        await ContactService.launchPhone(content);
      };
    default:
      return () {};
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
