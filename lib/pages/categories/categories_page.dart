import 'package:abo_glumbo_bbk/common_widgets/category_card.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:flutter/material.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          titleSpacing: 16,
          title: Text(AppLocalizations.of(context)?.categories ?? ''),
          pinned: true,
          primary: true,
          centerTitle: true,
        ),
        const SliverPadding(padding: EdgeInsets.only(top: 30)),
        StreamBuilder(
          stream: AppFirestore.categoriesCollectionRef
              .where('isActive', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SliverToBoxAdapter(
                child: Center(
                  child: Text(
                    '${AppLocalizations.of(context)?.error ?? ''}: ${snapshot.error}',
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final categories = snapshot.data?.docs ?? [];

            return SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                mainAxisSpacing: 20,
                mainAxisExtent: 130,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final category = CategoryModel.fromQuerySnapshot(
                  categories[index],
                );
                return Center(child: CategoryCard(category: category));
              }, childCount: categories.length),
            );
          },
        ),
      ],
    );
  }
}
