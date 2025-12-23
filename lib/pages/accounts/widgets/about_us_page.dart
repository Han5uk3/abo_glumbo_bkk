import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class CustomerAboutUsPage extends StatelessWidget {
  const CustomerAboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            centerTitle: false,
            title: Text(locale.customerAboutUsTitle),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _FadeSlide(
                  delay: 0,
                  child: Text(
                    locale.customerAboutHeadline,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _FadeSlide(
                  delay: 100,
                  child: Text(
                    locale.customerAboutIntro,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 24),

                _FadeSlide(
                  delay: 200,
                  child: _SectionTitle(title: locale.customerWhyChooseUs),
                ),
                const SizedBox(height: 12),

                _FadeSlide(
                  delay: 300,
                  child: _CustomerCard(
                    title: locale.customerCertifiedExpertsTitle,
                    description: locale.customerCertifiedExpertsDesc,
                  ),
                ),
                const SizedBox(height: 12),

                _FadeSlide(
                  delay: 400,
                  child: _CustomerCard(
                    title: locale.customerSeamlessExperienceTitle,
                    description: locale.customerSeamlessExperienceDesc,
                  ),
                ),
                const SizedBox(height: 12),

                _FadeSlide(
                  delay: 500,
                  child: _CustomerCard(
                    title: locale.customerTransparencyTitle,
                    description: locale.customerTransparencyDesc,
                  ),
                ),
                const SizedBox(height: 24),

                _FadeSlide(
                  delay: 600,
                  child: _CustomerMissionCard(
                    text: locale.customerMission,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
class _CustomerCard extends StatelessWidget {
  final String title;
  final String description;

  const _CustomerCard({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
class _CustomerMissionCard extends StatelessWidget {
  final String text;

  const _CustomerMissionCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(18),
      child: Text(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
