import 'dart:developer';

import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:abo_glumbo_bbk/sheets/write_review.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentSuccessPage extends StatefulWidget {
  final double amount;
  final bool isFromBooking;
  final String paymentMethod;
  final String orderId;
  final BookingModel booking;

  const PaymentSuccessPage({
    super.key,
    required this.amount,
    required this.paymentMethod,
    required this.orderId,
    required this.booking,
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
  static const Color successColor = Color(0xFF4CAF50);
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

  void _navigateHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const Home()),
      (route) => false,
    );
  }

  void _navigateToReview() {
    showWriteReviewBottomSheet(context, booking: widget.booking);
  }

  @override
  Widget build(BuildContext context) {
    log('PaymentSuccessPage build called');
    log(
      'Amount: ${widget.amount}, Order ID: ${widget.orderId}, Payment Method: ${widget.paymentMethod}, Booking: ${widget.booking.toJson()}',
    );
    return PopScope(
      canPop: false,

      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              SizedBox(height: 60),
              Expanded(child: _buildContent()),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSuccessIcon(),
          const SizedBox(height: 40),
          _buildTitle(),
          const SizedBox(height: 60),
          _buildPaymentDetails(),
        ],
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: successColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: successColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(Icons.check_circle, color: Colors.white, size: 55),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Text(
              AppLocalizations.of(context)!.paymentSuccessful,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.paymentProcessedSuccessfully,
              style: TextStyle(
                fontSize: 16,
                color: primaryColor.withOpacity(0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetails() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildAmountRow(),
              const SizedBox(height: 16),
              _buildDetailRow(
                icon: Icons.payment,
                label: AppLocalizations.of(context)!.paymentMethod,
                value: _getPaymentMethod(widget.paymentMethod),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                icon: Icons.receipt_long,
                label: AppLocalizations.of(context)!.orderId,
                value: widget.orderId,
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                icon: Icons.calendar_today,
                label: AppLocalizations.of(context)!.date,
                value: DateFormat.yMMMMd(
                  LocalStoreHelper.getUserlanguage(),
                ).format(DateTime.now()),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                icon: Icons.access_time,
                label: AppLocalizations.of(context)!.time,
                value: DateFormat.jm(
                  LocalStoreHelper.getUserlanguage(),
                ).format(DateTime.now()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _getPaymentMethod(String method) {
    if (method.contains("cash")) {
      return AppLocalizations.of(context)!.cashInHand;
    } else if (method.contains("card")) {
      return AppLocalizations.of(context)!.cards;
    } else if (method.toLowerCase() == "o") {
      return AppLocalizations.of(context)!.cashInHand;
    } else if (method.toLowerCase() == "c") {
      return AppLocalizations.of(context)!.cards;
    } else {
      return AppLocalizations.of(context)!.unknown;
    }
  }

  Widget _buildAmountRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            successColor.withOpacity(0.1),
            successColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildIconContainer(Icons.account_balance_wallet, successColor),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.amountPaid,
                style: TextStyle(
                  fontSize: 14,
                  color: primaryColor.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            '${widget.amount.toStringAsFixed(2)} ${AppLocalizations.of(context)!.sar}',
            style: const TextStyle(
              fontSize: 20,
              color: successColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        _buildIconContainer(icon, primaryColor),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: primaryColor.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconContainer(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildActionButtons() {
    log('isFromBooking: ${widget.isFromBooking}');
    return AnimatedBuilder(
      animation: _buttonSlideAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          (1 - _buttonSlideAnimation.value.clamp(0.0, 1.0)) * 100,
        ),
        child: Opacity(
          opacity: _buttonSlideAnimation.value.clamp(0.0, 1.0),
          child: Column(
            children: [
              if (widget.isFromBooking == true) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _navigateToReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rate, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.reviewNow,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _navigateHome,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.goToHome,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
