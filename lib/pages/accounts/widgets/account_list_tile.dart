import 'package:abo_glumbo_bbk/helpers/constants.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

class AccountListTile extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool dense;
  final Color? textcolor;
  final Widget? leading;

  const AccountListTile({
    super.key,
    required this.title,
    this.onTap,
    this.leading,
    this.trailing,
    this.textcolor,
    this.dense = false,
  });

  factory AccountListTile.withArrow({
    Widget? leading,
    required String title,
    VoidCallback? onTap,
  }) {
    return AccountListTile(
      title: title,
      onTap: onTap,
      trailing: const Icon(Icons.arrow_forward_ios_sharp, size: 15),
      leading: leading,
    );
  }

  factory AccountListTile.withText({
    Widget? leading,

    required String title,
    required String trailingText,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return AccountListTile(
      title: title,
      onTap: onTap,
      leading: leading,
      trailing: Text(
        trailingText,
        style: DMSansFont.textStyle(
          fontSize: 11,
          color: textColor ?? AppColors.black1,
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
        style: DMSansFont.textStyle(
          fontSize: 12,
          color: textcolor ?? Colors.black,
        ),
      ),
      trailing: trailing,
      leading: leading,
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
        style: DMSansFont.textStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.lightGrey,
        ),
      ),
    );
  }
}
