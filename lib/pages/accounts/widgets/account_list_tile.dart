import 'package:abo_glumbo_bbk/helpers/constants.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AccountListTile extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool dense;

  const AccountListTile({
    super.key,
    required this.title,
    this.onTap,
    this.trailing,
    this.dense = false,
  });

  factory AccountListTile.withArrow({
    required String title,
    VoidCallback? onTap,
  }) {
    return AccountListTile(
      title: title,
      onTap: onTap,
      trailing: const Icon(Icons.arrow_forward_ios_sharp, size: 15),
    );
  }

  factory AccountListTile.withText({
    required String title,
    required String trailingText,
    VoidCallback? onTap,
  }) {
    return AccountListTile(
      title: title,
      onTap: onTap,
      trailing: Text(
        trailingText,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          color: AppColors.black1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: dense,
      onTap: onTap,
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: dense ? 15 : 16,
          color: AppColors.black1,
        ),
      ),
      trailing: trailing,
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AccountPageConstants.horizontalPadding,
      child: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.lightGrey,
        ),
      ),
    );
  }
}
