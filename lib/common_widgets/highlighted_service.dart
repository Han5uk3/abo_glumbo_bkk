import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/highlighted_services.dart';
import '../models/service.dart';

class HighlightedServiceWidget extends StatelessWidget {
  const HighlightedServiceWidget({
    super.key,
    required this.data,
    required this.isGuestUser,
  });
  final bool isGuestUser;
  final HighlightedServicesModel data;

  @override
  Widget build(BuildContext context) {
    final currentLanguage = AppLocalizations.of(context)?.localeName ?? 'en';
    final isRtlLanguage = currentLanguage == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 10, right: 16),
          child: Text(
            data.titleLocalized(languageCode: currentLanguage) ?? '',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 13),
        SizedBox(
          height: 127,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: data.services?.length ?? 0,
            itemBuilder: (context, index) {
              return FutureBuilder(
                future: AppFirestore.servicesCollectionRef
                    .doc(data.services![index])
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 127,
                      width: 127,
                      alignment: Alignment.center,
                      margin: isRtlLanguage
                          ? const EdgeInsets.only(left: 13)
                          : const EdgeInsets.only(right: 13),
                      color: Colors.grey[200],
                      // child: const CircularProgressIndicator(),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        AppLocalizations.of(context)?.failedToLoadServices ??
                            '',
                      ),
                    );
                  }
                  final service = ServiceModel.fromDocumentSnapshot(
                    snapshot.data as DocumentSnapshot,
                  );

                  return GestureDetector(
                    onTap: () {
                      // showServiceBottomSheet(
                      //   context,
                      //   service: service,
                      //   isGuestUser: isGuestUser,
                      // );
                    },
                    child: Container(
                      height: 127,
                      width: 127,
                      margin: isRtlLanguage
                          ? const EdgeInsets.only(left: 13)
                          : const EdgeInsets.only(right: 13),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          SizedBox(
                            height: 127,
                            width: 127,
                            child:
                                (service.image != null &&
                                    service.image!.isNotEmpty &&
                                    Uri.tryParse(service.image!) != null &&
                                    Uri.tryParse(
                                      service.image!,
                                    )!.hasAbsolutePath)
                                ? CachedNetworkImage(
                                    imageUrl: service.image!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Loader(size: 20, color: Colors.white),
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                          Icons.error,
                                          color: Colors.red,
                                          size: 30,
                                        ),
                                  )
                                : Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                          ),
                          Container(
                            height: 88,
                            width: 127,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                stops: [0, 1],
                                begin: Alignment.center,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black],
                              ),
                            ),
                            alignment: Alignment.bottomCenter,
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              service.nameLocalized(
                                    languageCode: currentLanguage,
                                  ) ??
                                  "",
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}
