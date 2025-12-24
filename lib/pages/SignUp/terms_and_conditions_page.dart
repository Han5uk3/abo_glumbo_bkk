import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key, required this.isFromLogin});

  final bool isFromLogin;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          isFromLogin ? locale.termsOfUse : locale.termsAndConditions,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),
            _FadeSlide(
              delay: 0,
              child: _buildText(
                locale.termsIntroduction,
                locale.introduction,
                0,
              ),
            ),
            SizedBox(height: 24),
            _FadeSlide(
              delay: 100,
              child: _buildText(locale.terms1, locale.terms1title, 1),
            ),
            SizedBox(height: 8),
            _FadeSlide(
              delay: 200,
              child: _buildText(locale.terms2, locale.terms2title, 2),
            ),
            SizedBox(height: 8),
            _FadeSlide(
              delay: 300,
              child: _buildText(locale.terms3, locale.terms3title, 3),
            ),
            SizedBox(height: 8),
            _FadeSlide(
              delay: 400,
              child: _buildWarrantyTermsText(
                locale.terms4p1,
                locale.terms4p2,
                locale.terms4title,
                4,
                context,
              ),
            ),
            SizedBox(height: 8),
            _FadeSlide(
              delay: 500,
              child: _buildText(locale.terms5, locale.terms5title, 5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildText(String text, String title, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          index == 0 ? title : "$index. $title",
          style: DMSansFont.textStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 3),
        Text(
          text,
          style: DMSansFont.textStyle(color: Colors.black, fontSize: 14),
        ),
      ],
    );
  }

  _buildWarrantyTermsText(
    String part1,
    String part2,
    String title,
    int index,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$index. $title",
          style: DMSansFont.textStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 3),
        RichText(
          text: TextSpan(
            style: DMSansFont.textStyle(color: Colors.black, fontSize: 14),
            children: [
              TextSpan(text: part1),
              TextSpan(
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            centerTitle: true,
                            title: Text(
                              AppLocalizations.of(context)!.warrantyPolicy,
                            ),
                          ),
                          body: SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 16),
                                _FadeSlide(
                                  delay: 0,
                                  child: _buildWarrantyContent(
                                    AppLocalizations.of(context)!.whatsCovered,
                                    AppLocalizations.of(context)!.issueone,
                                    AppLocalizations.of(context)!.issuetwo,
                                    AppLocalizations.of(context)!.issuethree,
                                    AppLocalizations.of(context)!.issuefour,
                                  ),
                                ),
                                SizedBox(height: 24),
                                _FadeSlide(
                                  delay: 100,
                                  child: _buildWarrantyContent(
                                    AppLocalizations.of(
                                      context,
                                    )!.whatsNotCovered,
                                    AppLocalizations.of(context)!.notissueone,
                                    AppLocalizations.of(context)!.notissuetwo,
                                    AppLocalizations.of(context)!.notissuethree,
                                    AppLocalizations.of(context)!.notissuefour,
                                    content5: AppLocalizations.of(
                                      context,
                                    )!.notissuefive,
                                  ),
                                ),
                                SizedBox(height: 24),

                                _FadeSlide(
                                  delay: 200,
                                  child: Text(
                                    AppLocalizations.of(context)!.claimText,
                                    style: DMSansFont.textStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },

                text: ' ${AppLocalizations.of(context)!.warrantyPolicy} ',
                style: DMSansFont.textStyle(
                  color: Colors.blue,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
              TextSpan(
                text: part2,
                style: DMSansFont.textStyle(color: Colors.black, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarrantyContent(
    String heading,
    String content1,
    String content2,
    String content3,
    String content4, {
    String? content5,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: DMSansFont.textStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 16),
        Text(
          "1. $content1",
          style: DMSansFont.textStyle(color: Colors.black, fontSize: 14),
        ),
        SizedBox(height: 6),
        Text(
          "2. $content2",
          style: DMSansFont.textStyle(color: Colors.black, fontSize: 14),
        ),
        SizedBox(height: 6),
        Text(
          "3. $content3",
          style: DMSansFont.textStyle(color: Colors.black, fontSize: 14),
        ),
        SizedBox(height: 6),
        Text(
          "4. $content4",
          style: DMSansFont.textStyle(color: Colors.black, fontSize: 14),
        ),
        if (content5 != null) ...[
          SizedBox(height: 6),
          Text(
            "5. $content5",
            style: DMSansFont.textStyle(color: Colors.black, fontSize: 14),
          ),
        ],
      ],
    );
  }
}

class _FadeSlide extends StatefulWidget {
  final Widget child;
  final int delay;

  const _FadeSlide({required this.child, required this.delay});

  @override
  State<_FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<_FadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _opacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _offset = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
