// ignore_for_file: deprecated_member_use
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/pages/categories/category_detail.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CategoryCard extends StatefulWidget {
  final CategoryModel category;
  const CategoryCard({super.key, required this.category});

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return CategoryDetail(category: widget.category);
            },
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(left: 10, right: 10, bottom: 20),
        height: 105,
        width: 105,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.black3.withOpacity(.1), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child:
                  (widget.category.svg != null &&
                      widget.category.svg!.isNotEmpty &&
                      Uri.tryParse(widget.category.svg!) != null &&
                      Uri.tryParse(widget.category.svg!)!.hasAbsolutePath)
                  ? CachedNetworkImage(
                      imageUrl: widget.category.svg!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Loader(size: 20, color: Colors.white),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.broken_image_outlined),
                    )
                  : const Icon(
                      Icons.category_outlined,
                      size: 30,
                      color: Colors.grey,
                    ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.category.nameLocalized(
                    languageCode:
                        AppLocalizations.of(context)?.localeName ?? '',
                  ) ??
                  '',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.black3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
