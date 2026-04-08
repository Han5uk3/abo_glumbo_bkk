import 'package:flutter/material.dart';

Widget eButton({
  String? text,
  required VoidCallback? onPressed,
  required BuildContext context,
  Color? textColor,
  required Color? backgroundColor,
  Widget? widget,
  double? width,
  double? height,
  Widget? icon, // Added optional icon parameter
}) {
  return SizedBox(
    width: width,
    height: height,
    child: ElevatedButton(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        backgroundColor: WidgetStatePropertyAll(backgroundColor),
      ),
      onPressed: onPressed,
      child: widget ?? _buildChild(text, textColor, icon),
    ),
  );
}

// Helper method to build the child with icon and text
Widget _buildChild(String? text, Color? textColor, Widget? icon) {
  // If both icon and text are provided, show them in a Row
  if (icon != null && text != null && text.isNotEmpty) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon,
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: textColor ?? Colors.black)),
      ],
    );
  }

  // If only icon is provided
  if (icon != null) {
    return icon;
  }

  // If only text is provided
  return Text(
    text ?? "",
    style: TextStyle(color: textColor ?? Colors.black, fontSize: 12),
  );
}
