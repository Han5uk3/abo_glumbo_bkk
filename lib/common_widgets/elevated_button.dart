import 'package:flutter/material.dart';

Widget eButton({
  String? text,
  required VoidCallback? onPressed,
  required BuildContext context,
  Color? textColor,
  required Color? backgroundColor,
  Widget? widget,
}) {
  return ElevatedButton(
    style: ButtonStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      backgroundColor: WidgetStatePropertyAll(backgroundColor),
    ),
    onPressed: onPressed,
    child:
        widget ??
        Text(text ?? "", style: TextStyle(color: textColor ?? Colors.black)),
  );
}
