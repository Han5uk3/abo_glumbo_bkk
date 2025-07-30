import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/telr/payment_screen.dart';
import 'package:abo_glumbo_bbk/services/booking/save_booking.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/booking.dart';

Future<bool?> showWriteReviewBottomSheet(
  BuildContext context, {
  required BookingModel booking,
}) async {
  bool? res = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
    builder: (context) {
      return WriteReviewBottomSheetWidget(booking: booking);
    },
  );

  return res;
}

class WriteReviewBottomSheetWidget extends StatefulWidget {
  const WriteReviewBottomSheetWidget({super.key, required this.booking});
  final BookingModel booking;

  @override
  State<WriteReviewBottomSheetWidget> createState() =>
      _WriteReviewBottomSheetWidgetState();
}

class _WriteReviewBottomSheetWidgetState
    extends State<WriteReviewBottomSheetWidget> {
  bool saving = false;
  bool processingTip = false;
  final formKey = GlobalKey<FormState>();
  final TextEditingController reviewController = TextEditingController();
  final TextEditingController customTipController = TextEditingController();
  int rating = 0;
  double selectedTip = 0.0;
  bool showCustomTip = false;
  String tipPaymentMethod = '';
  final List<double> tipAmounts = [1.0, 2.0, 3.0, 5.0];

  // Validation method
  bool _validateForm() {
    String? errorMessage;

    // Rating validation
    if (rating == 0) {
      errorMessage =
          AppLocalizations.of(context)?.pleaseSelectRating ??
          'Please select a rating';
    }
    // Review text validation
    else if (reviewController.text.trim().isEmpty) {
      errorMessage =
          AppLocalizations.of(context)?.pleaseWriteAReview ??
          'Please write a review';
    }
    // Tip validation
    else if (selectedTip > 0 && tipPaymentMethod.isEmpty) {
      errorMessage =
          AppLocalizations.of(context)?.pleaseSelectPaymentMethod ??
          'Please select a payment method for your tip';
    }
    // Custom tip validation
    else if (showCustomTip && selectedTip <= 0) {
      errorMessage =
          AppLocalizations.of(context)?.pleaseEnterValidTipAmount ??
          'Please enter a valid tip amount';
    }
    // Custom tip minimum amount validation
    else if (showCustomTip && selectedTip > 0 && selectedTip < 0.5) {
      errorMessage =
          AppLocalizations.of(context)?.minimumTipAmount ??
          'Minimum tip amount is SAR 0.50';
    }

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return false;
    }

    return formKey.currentState?.validate() ?? false;
  }

  void _saveReview() {
    if (!_validateForm()) return;

    setState(() => saving = true);

    if (selectedTip > 0 && tipPaymentMethod.toLowerCase() == 'card') {
      _processTipPayment();
    } else {
      BookingUtils.saveReview(
        booking: widget.booking,
        review: ReviewModel(
          rating: rating,
          review: reviewController.text.trim(),
          tipAmount: selectedTip > 0 ? selectedTip : null,
          paymentType: tipPaymentMethod.isNotEmpty ? tipPaymentMethod : null,
          isTipPaid: selectedTip > 0 && tipPaymentMethod.toLowerCase() == 'cash'
              ? false
              : null,
        ),
      ).then((value) {
        if (value) {
          Navigator.pop(context, true);
        } else {
          setState(() => saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.failedToSaveReview),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      });
    }
  }

  Future _processTipPayment() async {
    setState(() => processingTip = true);
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentWebView(
            isFromBooking: false,
            booking: widget.booking,
            customerData: widget.booking.customer,
            review: ReviewModel(
              rating: rating,
              review: reviewController.text.trim(),
              tipAmount: selectedTip,
              paymentType: tipPaymentMethod,
              isTipPaid: true,
              createdAt: Timestamp.now(),
            ),
          ),
        ),
      );
      setState(() => processingTip = false);
    } catch (e) {
      setState(() => processingTip = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.paymentFailed ??
                'Payment processing failed',
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Widget _buildTipSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary.withOpacity(0.05),
            AppColors.secondary.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.favorite,
                  color: AppColors.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.thankTheTechnician ??
                          'Thank the Technician',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)?.showAppreciationWithTip ??
                          'Show appreciation with a tip',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...tipAmounts.map((amount) => _buildTipButton(amount)),
              _buildCustomTipButton(),
            ],
          ),
          if (showCustomTip) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
              ),
              child: TextFormField(
                controller: customTipController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  hintText:
                      AppLocalizations.of(context)?.enterCustomTipAmount ??
                      'Enter custom tip amount',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  prefixText: AppLocalizations.of(context)?.sar ?? 'SAR ',
                  prefixStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                onChanged: (value) {
                  final amount = double.tryParse(value) ?? 0.0;
                  setState(() {
                    selectedTip = amount;
                    // Reset payment method when tip amount changes
                    if (amount == 0) {
                      tipPaymentMethod = '';
                    }
                  });
                },
                validator: (value) {
                  if (showCustomTip) {
                    if (value?.isEmpty ?? true) {
                      return AppLocalizations.of(
                            context,
                          )?.pleaseEnterTipAmount ??
                          'Please enter tip amount';
                    }
                    final amount = double.tryParse(value!) ?? 0.0;
                    if (amount <= 0) {
                      return AppLocalizations.of(
                            context,
                          )?.pleaseEnterValidTipAmount ??
                          'Please enter a valid tip amount';
                    }
                    if (amount < 0.5) {
                      return AppLocalizations.of(context)?.minimumTipAmount ??
                          'Minimum tip amount is SAR 0.50';
                    }
                  }
                  return null;
                },
              ),
            ),
          ],
          if (selectedTip > 0) ...[
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)?.selectPaymentMethod ??
                  'Select Payment Method',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPaymentMethodButton(
                    'card',
                    AppLocalizations.of(context)?.payWithCard ??
                        'Pay with Card',
                    Icons.credit_card,
                    AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPaymentMethodButton(
                    'cash',
                    AppLocalizations.of(context)?.payInCash ?? 'Pay in Cash',
                    Icons.money,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
          if (selectedTip > 0 && tipPaymentMethod.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    tipPaymentMethod == 'card'
                        ? Icons.credit_card
                        : Icons.money,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${AppLocalizations.of(context)?.tip ?? 'Tip'}: ${AppLocalizations.of(context)?.sar ?? 'SAR '} ${selectedTip.toStringAsFixed(2)} (${tipPaymentMethod == 'card' ? AppLocalizations.of(context)?.card ?? 'Card' : AppLocalizations.of(context)?.cash ?? 'Cash'})',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTipButton(double amount) {
    final isSelected = selectedTip == amount && !showCustomTip;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTip = amount;
          showCustomTip = false;
          customTipController.clear();
          // Reset payment method when switching tip amounts
          tipPaymentMethod = '';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.secondary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          '${AppLocalizations.of(context)?.sar ?? 'SAR '} ${amount.toInt()}',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTipButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          showCustomTip = true;
          selectedTip = 0.0;
          // Reset payment method when switching to custom
          tipPaymentMethod = '';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: showCustomTip ? AppColors.secondary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: showCustomTip ? AppColors.secondary : Colors.grey.shade300,
            width: showCustomTip ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit,
              size: 16,
              color: showCustomTip ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context)?.custom ?? 'Custom',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: showCustomTip ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodButton(
    String method,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = tipPaymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => tipPaymentMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.black54, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? color : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Form(
          key: formKey,
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(
                  top: 16,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.submitAReview ??
                          'Submit Review',
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                        children: [
                          Row(
                            children: [
                              Text(
                                AppLocalizations.of(context)?.overallRating ??
                                    'Overall Rating',
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                ' *',
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (mounted)
                                    setState(() => rating = index + 1);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: index < rating
                                        ? AppColors.yellow
                                        : AppColors.grey5,
                                    size: 36,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                        children: [
                          Row(
                            children: [
                              Text(
                                AppLocalizations.of(context)?.writeYourReview ??
                                    'Write Your Review',
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                ' *',
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: reviewController,
                            maxLines: 4,
                            maxLength: 500,
                            decoration: InputDecoration(
                              hintText:
                                  AppLocalizations.of(
                                    context,
                                  )?.writeYourReviewHere ??
                                  'Share your experience...',
                              hintStyle: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.black54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.secondary,
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.red,
                                  width: 1,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value?.trim().isEmpty ?? true) {
                                return AppLocalizations.of(
                                      context,
                                    )?.pleaseWriteAReview ??
                                    'Please write a review';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    _buildTipSection(),
                  ],
                ),
              ),
              Container(
                color: Colors.white,
                padding: EdgeInsets.only(
                  bottom: safePadding.bottom + 16,
                  top: 16,
                  left: 16,
                  right: 16,
                ),
                child: Row(
                  children: [
                    if (!saving && !processingTip)
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              AppLocalizations.of(context)?.cancel ?? 'Cancel',
                              style: GoogleFonts.dmSans(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!saving && !processingTip) const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: (saving || processingTip)
                              ? null
                              : _saveReview,
                          child: (saving || processingTip)
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      processingTip
                                          ? AppLocalizations.of(
                                                  context,
                                                )?.processing ??
                                                'Processing...'
                                          : AppLocalizations.of(
                                                  context,
                                                )?.submitting ??
                                                'Submitting...',
                                      style: GoogleFonts.dmSans(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  selectedTip > 0
                                      ? '${AppLocalizations.of(context)?.submitReviewAndTip ?? 'Submit Review & Tip'} (${AppLocalizations.of(context)?.sar ?? 'SAR '} ${selectedTip.toStringAsFixed(2)})'
                                      : AppLocalizations.of(
                                              context,
                                            )?.submitReview ??
                                            'Submit Review',
                                  style: GoogleFonts.dmSans(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
