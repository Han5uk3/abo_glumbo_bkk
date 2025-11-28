import 'dart:developer';

import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:intl/intl.dart' show DateFormat;

class BookingCompletedPage extends StatefulWidget {
  final ServiceModel service;
  final UserModel worker;
  final DateTime selectedDate;
  final Map selectedTime;
  final AddressModel? address;

  const BookingCompletedPage({
    super.key,
    required this.service,
    required this.worker,
    required this.selectedDate,
    required this.selectedTime,
    required this.address,
  });

  @override
  State<BookingCompletedPage> createState() => _BookingCompletedPageState();
}

class _BookingCompletedPageState extends State<BookingCompletedPage>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _headerController;
  late AnimationController _contentController;
  late AnimationController _buttonController;

  late Animation<double> _checkScaleAnimation;
  late Animation<double> _checkRotationAnimation;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerFadeAnimation;

  String? _localizedRole;
  bool _isLoadingRole = true;
  bool _hasLoadedRole = false;

  @override
  void initState() {
    super.initState();

    // Check mark animation controller
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Header text animation controller
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Content cards animation controller
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Button animation controller
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Check mark animations
    _checkScaleAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );

    _checkRotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Header animations
    _headerSlideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
    );

    _headerFadeAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeIn,
    );

    // Start animations in sequence
    _startAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Load role data here - context is now fully available
    if (!_hasLoadedRole) {
      _hasLoadedRole = true;
      _loadRoleData();
    }
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _checkController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    _headerController.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    _contentController.forward();

    await Future.delayed(const Duration(milliseconds: 800));
    _buttonController.forward();
  }

  Future<void> _loadRoleData() async {
    try {
      final role = await getLocalizedRole(
        context,
        widget.worker.jobRoles ?? [],
      );

      if (mounted) {
        setState(() {
          _localizedRole = role;
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localizedRole = 'Unknown Role';
          _isLoadingRole = false;
        });
      }
    }
  }

  Future<String> getLocalizedRole(
    BuildContext context,
    List<String> roleIds,
  ) async {
    bool isArabic = Directionality.of(context) == TextDirection.rtl;

    log("Role IDs: $roleIds");

    // Use Future.wait to fetch all role names in parallel
    List<String> roleNames = await Future.wait(
      roleIds.map((element) async {
        if (isArabic) {
          return await AppServices.getroleNameArbyid(element);
        } else {
          return await AppServices.getroleNameEnbyid(element);
        }
      }),
    );

    // Join the names with commas
    String name = roleNames.join(', ');
    log("Localized roles: $name");

    return name;
  }

  @override
  void dispose() {
    // Restore status bar to dark theme (dark icons on light background)
    _checkController.dispose();
    _headerController.dispose();
    _contentController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // Success Header with animations
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
              child: Column(
                children: [
                  // Animated check mark
                  ScaleTransition(
                    scale: _checkScaleAnimation,
                    child: RotationTransition(
                      turns: _checkRotationAnimation,
                      child: Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: AppColors.secondary,
                          size: 70,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Animated header text
                  AnimatedBuilder(
                    animation: _headerController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _headerSlideAnimation.value),
                        child: Opacity(
                          opacity: _headerFadeAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          AppLocalizations.of(context)?.bookingConfirmed ??
                              'Booking Confirmed!',
                          style: DMSansFont.textStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)?.bookingSuccessMessage ??
                              'Your booking has been successfully placed',
                          style: DMSansFont.textStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Booking Details with staggered animations
            Expanded(
              child: AnimatedBuilder(
                animation: _contentController,
                builder: (context, child) {
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Service Details Section
                      _buildAnimatedSection(
                        delay: 0.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle(
                              context,
                              AppLocalizations.of(context)?.serviceDetails ??
                                  'Service Details',
                            ),
                            const SizedBox(height: 12),
                            _buildDetailCard(
                              context,
                              children: [
                                _buildDetailRow(
                                  context,
                                  icon: Icons.home_repair_service,
                                  label:
                                      AppLocalizations.of(context)?.service ??
                                      'Service',
                                  value:
                                      Directionality.of(context) ==
                                          TextDirection.rtl
                                      ? widget.service.name_ar ?? ''
                                      : widget.service.name ?? '',
                                ),
                                const Divider(height: 24),
                                _buildDetailRow(
                                  context,
                                  icon: Icons.calendar_today,
                                  label:
                                      AppLocalizations.of(context)?.date ??
                                      'Date',
                                  value: DateFormat(
                                    'dd MMMM yyyy',
                                    Directionality.of(context) ==
                                            TextDirection.rtl
                                        ? 'ar'
                                        : 'en',
                                  ).format(widget.selectedDate),
                                ),
                                const Divider(height: 24),
                                _buildDetailRow(
                                  context,
                                  icon: Icons.access_time,
                                  label:
                                      AppLocalizations.of(context)?.time ??
                                      'Time',
                                  value: widget.selectedTime['time'].format(
                                    context,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Worker Details Section
                      _buildAnimatedSection(
                        delay: 0.15,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle(
                              context,
                              AppLocalizations.of(context)?.technicianDetails ??
                                  'Worker Details',
                            ),
                            const SizedBox(height: 12),
                            _buildDetailCard(
                              context,
                              children: [
                                Row(
                                  children: [
                                    Hero(
                                      tag: 'worker_${widget.worker.uid}',
                                      child: CircleAvatar(
                                        radius: 30,
                                        backgroundImage:
                                            widget.worker.profileUrl != null
                                            ? NetworkImage(
                                                widget.worker.profileUrl!,
                                              )
                                            : const AssetImage(
                                                    'assets/images/profile_placeholder.jpg',
                                                  )
                                                  as ImageProvider,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.worker.name ?? 'Unknown',
                                            style: DMSansFont.textStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _isLoadingRole
                                                ? AppLocalizations.of(
                                                    context,
                                                  )!.loading
                                                : (_localizedRole ?? ''),
                                            style: DMSansFont.textStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Address Section
                      _buildAnimatedSection(
                        delay: 0.3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle(
                              context,
                              AppLocalizations.of(context)?.serviceLocation ??
                                  'Service Location',
                            ),
                            const SizedBox(height: 12),
                            _buildDetailCard(
                              context,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.location_on,
                                        color: AppColors.primary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            widget.address?.fullName ?? '',
                                            style: DMSansFont.textStyle(
                                              fontSize: 14,
                                              color: Colors.grey[800],
                                              height: 1.5,
                                            ),
                                          ),
                                          Flexible(
                                            child: Text(
                                              widget.address?.streetName ?? '',
                                              style: DMSansFont.textStyle(
                                                fontSize: 14,
                                                color: Colors.grey[800],
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Bottom Actions with animation
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _buttonController,
                  curve: Curves.easeOutBack,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          // Navigate back to home
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const Home(),
                            ),
                            (route) => false,
                          );
                        },
                        child: Text(
                          AppLocalizations.of(context)?.backToHome ??
                              'Back to Home',
                          style: DMSansFont.textStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for staggered animations
  Widget _buildAnimatedSection({required double delay, required Widget child}) {
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: Interval(delay, delay + 0.3, curve: Curves.easeOutCubic),
      ),
    );

    final slideAnimation =
        Tween<Offset>(begin: const Offset(0, 30), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentController,
            curve: Interval(delay, delay + 0.3, curve: Curves.easeOutCubic),
          ),
        );

    return AnimatedBuilder(
      animation: _contentController,
      builder: (context, _) {
        return Transform.translate(
          offset: slideAnimation.value,
          child: Opacity(opacity: animation.value, child: child),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: DMSansFont.textStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: DMSansFont.textStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: DMSansFont.textStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
