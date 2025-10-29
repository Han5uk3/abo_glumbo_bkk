import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/sheets/book_service.dart';
import 'package:abo_glumbo_bbk/sheets/sign_up_alert.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/pages/accounts/bloc/account_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/service.dart';

class ServiceTile extends StatelessWidget {
  const ServiceTile({
    super.key,
    required this.service,
    this.isGuestUser,
    this.onFavPressed,
    required this.isfromHome,
  });

  final ServiceModel service;
  final VoidCallback? onFavPressed;
  final bool? isGuestUser;

  final bool isfromHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      padding: const EdgeInsets.only(left: 13, right: 13, top: 13, bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child:
                (service.image != null &&
                    service.image!.isNotEmpty &&
                    Uri.tryParse(service.image!) != null &&
                    Uri.tryParse(service.image!)!.hasAbsolutePath)
                ? CachedNetworkImage(
                    imageUrl: service.image!,
                    height: 85,
                    width: 85,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => SizedBox(
                      height: 85,
                      width: 85,
                      child: Loader(color: AppColors.primary),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error, color: Colors.red, size: 30),
                  )
                : Container(
                    height: 85,
                    width: 85,
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
          const SizedBox(width: 17),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        service.nameLocalized(
                              languageCode:
                                  AppLocalizations.of(context)?.localeName ??
                                  '',
                            ) ??
                            '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    if (!(LocalStoreHelper.getGuestUser()))
                      BlocBuilder<AccountBloc, AccountState>(
                        buildWhen: (previous, current) {
                          // Don't rebuild during favorite updating state to prevent flickering
                          if (current is FavoriteServiceUpdating) {
                            return false;
                          }

                          // Only rebuild if this specific service's favorite status might have changed
                          if (previous is CustomerDataLoaded &&
                              current is CustomerDataLoaded) {
                            final prevIsFavorite = previous
                                .customerData
                                .favourites
                                .contains(service.id);
                            final currIsFavorite = current
                                .customerData
                                .favourites
                                .contains(service.id);
                            return prevIsFavorite != currIsFavorite;
                          }

                          // Rebuild if transitioning between different state types (but not updating states)
                          if (previous is! CustomerDataLoaded &&
                              current is CustomerDataLoaded) {
                            return true;
                          }

                          return false;
                        },
                        builder: (context, state) {
                          bool isFavorite = false;
                          if (state is CustomerDataLoaded &&
                              service.id != null) {
                            isFavorite = state.customerData.favourites.contains(
                              service.id!,
                            );
                          }

                          return IconButton(
                            onPressed: onFavPressed,
                            splashRadius: 20,
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: isFavorite
                                  ? const Icon(
                                      CupertinoIcons.heart_fill,
                                      color: Colors.red,
                                      key: ValueKey('heart_filled'),
                                    )
                                  : const Icon(
                                      CupertinoIcons.heart,
                                      color: Colors.black45,
                                      key: ValueKey('heart_empty'),
                                    ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                Text(
                  service.descriptionLocalized(
                        languageCode:
                            AppLocalizations.of(context)?.localeName ?? '',
                      ) ??
                      '',
                  style: GoogleFonts.dmSans(
                    color: Colors.black45,
                    fontSize: 12,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),

                if (isfromHome == true) ...[
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          SizedBox(height: 2),
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.secondary,
                            size: 15,
                          ),
                        ],
                      ),
                      SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context)?.inspectionDisclaimer ??
                              '',
                          style: GoogleFonts.dmSans(
                            color: AppColors.secondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      "${service.price} ${AppLocalizations.of(context)!.sar}",
                      style: GoogleFonts.dmSans(
                        color: AppColors.green1,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 11),
                    SizedBox(
                      height: 23,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          backgroundColor: AppColors.secondary,
                        ),
                        onPressed: () {
                          if (LocalStoreHelper.getGuestUser()) {
                            return SignUpAlertForGuestUsers().showSignUpAlert(
                              context,
                            );
                          }
                          showBookServiceBottomSheet(context, service: service);
                        },
                        child: Text(
                          AppLocalizations.of(context)?.requestService ?? '',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
