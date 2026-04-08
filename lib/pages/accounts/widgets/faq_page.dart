import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/faq.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';

class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    bool isArabic = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        leading: IconButton(
          iconSize: 16,
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        shape: Border.all(style: BorderStyle.none),
        title: Text(
          AppLocalizations.of(context)?.faq ?? 'FAQ',
          style: TextStyle(color: Colors.black),
        ),

        centerTitle: true,
      ),
      body: StreamBuilder<List<FaqModel>>(
        stream: AppServices.getFaq(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: SizedBox(
                height: 24,
                child: Loader(color: AppColors.primary),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${AppLocalizations.of(context)?.error ?? "Error"}: ${snapshot.error}',
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context)?.noFaqsAvailable ??
                    'No FAQs available.',
              ),
            );
          }
          final faqs = snapshot.data!;
          return ListView.separated(
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: faqs.length,
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 40, top: 20),
            itemBuilder: (context, index) {
              final faq = faqs[index];
              final question = isArabic ? faq.questionAr : faq.questionEn;
              final answer = isArabic ? faq.answerAr : faq.answerEn;

              return Card(
                elevation: 3,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: AppColors.primary, width: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                color: Colors.white.withAlpha(225),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: theme.colorScheme.primary.withOpacity(0.05),
                  ),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    childrenPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    title: Row(
                      mainAxisSize: MainAxisSize.min,

                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: 3,
                      children: [
                        Expanded(
                          child: Text(
                            question,

                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    iconColor: theme.colorScheme.primary,
                    collapsedIconColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    expandedAlignment: isArabic
                        ? Alignment.centerRight
                        : Alignment.centerLeft,

                    children: [
                      Text(
                        answer,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
    );
  }
}
