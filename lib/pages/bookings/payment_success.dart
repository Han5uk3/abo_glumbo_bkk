import 'package:abo_glumbo_bbk/services/time_service.dart';
import 'dart:developer';
import 'package:flutter/services.dart';

import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentSuccessPage extends StatefulWidget {
  final double amount;
  final bool isFromBooking;
  final String paymentMethod;
  final String orderId;
  final BookingModel? booking;
  final String? bookingId;
  final DateTime? bookingDate;
  final ServiceModel? service;

  const PaymentSuccessPage({
    super.key,
    required this.amount,
    required this.paymentMethod,
    required this.orderId,
    this.booking,
    this.bookingId,
    this.bookingDate,
    this.service,
    required this.isFromBooking,
  });

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _buttonSlideAnimation;

  static const Color primaryColor = Color(0xFF0A2463);
  static Color get successColor => AppColors.primary;
  static const Color backgroundColor = Color(0xFFF9F9FA);
  static const Color accentColor = Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimation();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeIn),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
          ),
        );

    _buttonSlideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutBack),
      ),
    );
  }

  void _startAnimation() {
    Future.delayed(const Duration(milliseconds: 200), () {
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
    log('PaymentSuccessPage build called');
    log(
      'Amount: ${widget.amount}, Order ID: ${widget.orderId}, Payment Method: ${widget.paymentMethod}, Booking: ${widget.booking?.id ?? widget.bookingId}',
    );
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: successColor,
        body: Column(
          children: [
            Expanded(child: _buildContent()),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSuccessIcon(),
              const SizedBox(height: 24),
              _buildTitle(),
              const SizedBox(height: 32),
              _buildOrderDetails(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: const Icon(
          Icons.event_available,
          color: Colors.white,
          size: 100,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    final isPendingVerification = widget.paymentMethod == "O" || widget.paymentMethod == "Outside App" || widget.paymentMethod == "Outside App - Cash";

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Text(
              isPendingVerification 
                ? (AppLocalizations.of(context)?.verificationPending ?? "Payment Verification Pending")
                : (AppLocalizations.of(context)?.paymentCompleted ?? "Payment Completed"),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            if (isPendingVerification) ...[
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)?.paymentProofSubmittedPendingVerification ?? "Your payment proof has been submitted and is pending verification",
                style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                AppLocalizations.of(context)?.orderId ?? 'Order ID',
                widget.orderId,
                hasCopy: true,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white30, height: 1),
              ),
              if (widget.booking != null || widget.bookingDate != null) ...[
                _buildInfoRow(
                  AppLocalizations.of(context)?.date ?? 'Date',
                  DateFormat(
                    'dd MMM yyyy, hh:mm a',
                    LocalStoreHelper.getUserlanguage(),
                  ).format(
                    // Stored instant — render it on the Saudi clock.
                    KsaTime.fromInstant(
                      (widget.booking?.bookingDateTime.toDate() ??
                          widget.bookingDate)!,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: Colors.white30, height: 1),
                ),
                if ((widget.booking?.service.categoryNameFilled ??
                        widget.service?.categoryNameFilled) !=
                    null) ...[
                  _buildInfoRow(
                    AppLocalizations.of(context)?.category ?? 'Category',
                    (widget.booking?.service.categoryNameFilled ??
                        widget.service?.categoryNameFilled)!,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: Colors.white30, height: 1),
                  ),
                ],
                _buildInfoRow(
                  AppLocalizations.of(context)?.service ?? 'Service',
                  (widget.booking?.service.nameLocalized(
                            languageCode: LocalStoreHelper.getUserlanguage(),
                          ) ??
                          widget.service?.nameLocalized(
                            languageCode: LocalStoreHelper.getUserlanguage(),
                          )) ??
                      (widget.booking?.service.name ?? widget.service?.name) ??
                      '',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: Colors.white30, height: 1),
                ),
              ],
              _buildInfoRow(
                AppLocalizations.of(context)?.amountPaid ?? 'Amount Paid',
                '${widget.amount.toStringAsFixed(2)} ${AppLocalizations.of(context)?.sar ?? 'SAR'}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool hasCopy = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 1,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasCopy) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)?.orderIdCopied ?? 'Order ID copied to clipboard'),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.copy,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return AnimatedBuilder(
      animation: _buttonSlideAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          (1 - _buttonSlideAnimation.value.clamp(0.0, 1.0)) * 100,
        ),
        child: Opacity(
          opacity: _buttonSlideAnimation.value.clamp(0.0, 1.0),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Home(initialIndex: 1),
                          ),
                          (route) => false,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)?.goToBookings ??
                            'Go to Booking',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Home(initialIndex: 0),
                          ),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: successColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)?.goToHome ?? 'Go to Home',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
