import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';

class TextFormWidget extends StatelessWidget {
  TextFormWidget({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.onTap,
    this.readOnly,
    this.suffixIcon,
    this.inputFormatters,
    this.onChanged,
    this.textDirection,
    this.hint,
    this.isNeedLabel = true,
  });
  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String?>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final GestureTapCallback? onTap;
  final bool? readOnly;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  void Function(String)? onChanged;
  TextDirection? textDirection;
  final Widget? hint;
  bool isNeedLabel = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNeedLabel)
          Text(
            label,
            style: DMSansFont.textStyle(fontSize: 16),
          ),
        const SizedBox(height: 5),
        TextFormField(
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          textDirection: textDirection,
          decoration: InputDecoration(
            suffixIcon: suffixIcon,
            border: InputBorder.none,
            hint: hint,
            constraints: const BoxConstraints(minHeight: 62),
            fillColor: readOnly == true ? AppColors.black2 : null,
            filled: readOnly,
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black12),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.secondary),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            errorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black12),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black12),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          style: DMSansFont.textStyle(fontSize: 16, color: Colors.black),
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onTap: onTap,
          readOnly: readOnly ?? onTap != null,
        )
      ],
    );
  }
}
