import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';

void showSnackBar(
  String message,
  BuildContext context, {
  Color? backgroundColor,
}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: backgroundColor == AppColors.yellow
              ? Colors.grey.shade800
              : Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: backgroundColor ?? AppColors.yellow,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
