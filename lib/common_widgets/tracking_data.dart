import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class TrackingData extends StatelessWidget {
  String? timeTakenToArrive;
  String? remainingKm;
  UserModel? worker;

  TrackingData({
    super.key,
    this.timeTakenToArrive,
    this.worker,
    this.remainingKm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10),
          _title(
            AppLocalizations.of(context)?.technicianArrivesToLocationIn ??
                'Worker arrives to location in',
            16,
            fontWeight: FontWeight.normal,
          ),
          SizedBox(height: 5),
          _title('$timeTakenToArrive', 35, fontWeight: FontWeight.bold),
          _title('$remainingKm ${AppLocalizations.of(context)!.localeName == 'ar'? '' : 'away'}',
            12,
            fontWeight: FontWeight.normal,
          ),
          SizedBox(height: 10),
          _title(
            AppLocalizations.of(context)?.yourTechnicianIsOnTheWay ??
                'Your Worker is on the way',
            16,
            fontWeight: FontWeight.normal,
          ),
          SizedBox(height: 5),
          serviceWorkerCard(
            name:
                worker?.name ??
                AppLocalizations.of(context)?.serviceProvider ??
                'Service Provider',
            onCall: worker?.phone != null
                ? () {
                    launchUrl(
                      Uri.parse('tel:${worker!.phone}'),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                : null,
            context: context,
          ),
        ],
      ),
    );
  }

  Widget _title(
    String title,
    double fontSize, {
    FontWeight fontWeight = FontWeight.w600,
    String? subtitle,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 5),
        if (subtitle != null)
          Text(
            subtitle,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
      ],
    );
  }

  Widget serviceWorkerCard({
    String name = 'Service Provider',
    VoidCallback? onCall,
    VoidCallback? onTap,
    required BuildContext context,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: ListTile(
          leading: Container(
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.all(10),
            child: Icon(Icons.engineering, color: AppColors.primary, size: 32),
          ),
          title: Text(
            name,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.call, color: AppColors.primary),
                tooltip:
                    AppLocalizations.of(context)?.callServiceProvider ??
                    'Call Service Provider',
                onPressed: onCall,
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
