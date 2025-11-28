import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/tipping.dart';
import 'package:abo_glumbo_bbk/models/total_tip.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:abo_glumbo_bbk/pages/telr/payment_screen.dart';
import 'package:abo_glumbo_bbk/services/booking/save_booking.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import '../models/booking.dart';

Future<bool?> showWriteReviewBottomSheet(
  BuildContext context, {
  required BookingModel booking,
}) async {
  return await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => WriteReviewBottomSheetWidget(booking: booking),
  );
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
  final _formKey = GlobalKey<FormState>();
  final _reviewController = TextEditingController();
  final _customTipController = TextEditingController();

  int _rating = 0;
  double _selectedTip = 0.0;
  bool _showCustomTip = false;
  String _tipPaymentMethod = '';
  bool _saving = false;
  bool _processingTip = false;

  static const List<double> _tipAmounts = [1.0, 2.0, 3.0, 5.0];
  static const double _minTipAmount = 0.5;

  @override
  void dispose() {
    _reviewController.dispose();
    _customTipController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    final l10n = AppLocalizations.of(context);
    String? errorMessage;

    if (_rating == 0) {
      errorMessage = l10n?.pleaseSelectRating ?? 'Please select a rating';
    } else if (_reviewController.text.trim().isEmpty) {
      errorMessage = l10n?.pleaseWriteAReview ?? 'Please write a review';
    } else if (_selectedTip > 0 && _tipPaymentMethod.isEmpty) {
      errorMessage =
          l10n?.pleaseSelectPaymentMethod ??
          'Please select a payment method for your tip';
    } else if (_showCustomTip && _selectedTip <= 0) {
      errorMessage =
          l10n?.pleaseEnterValidTipAmount ?? 'Please enter a valid tip amount';
    } else if (_showCustomTip &&
        _selectedTip > 0 &&
        _selectedTip < _minTipAmount) {
      errorMessage = l10n?.minimumTipAmount ?? 'Minimum tip amount is SAR 0.50';
    }

    if (errorMessage != null) {
      _showSnackBar(errorMessage, isError: true);
      return false;
    }

    return _formKey.currentState?.validate() ?? false;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  ReviewModel _createReviewModel({bool isTipPaid = false}) {
    return ReviewModel(
      workerId: widget.booking.agent?.uid,
      rating: _rating, // Rating is guaranteed to be set here
      review: _reviewController.text.trim(),
      tipAmount: _selectedTip > 0 ? _selectedTip : null,
      paymentType: _tipPaymentMethod.isNotEmpty ? _tipPaymentMethod : null,
      isTipPaid: _selectedTip > 0 && _tipPaymentMethod.toLowerCase() == 'cash'
          ? false
          : (_selectedTip > 0 && isTipPaid ? true : null),
      createdAt: Timestamp.now(),
    );
  }

  Future<void> _saveReview() async {
    if (!_validateForm()) return;

    setState(() => _saving = true);

    try {
      if (_selectedTip > 0 && _tipPaymentMethod.toLowerCase() == 'card') {
        // Card payment - navigate to PaymentWebView
        await _processTipPayment();
      } else {
        // No tip or cash payment - save review directly
        final success = await BookingUtils.saveReview(
          booking: widget.booking,
          review: _createReviewModel(),
        );

        if (success) {
          // If there's a cash tip, save it to subcollection
          if (_selectedTip > 0 && _tipPaymentMethod.toLowerCase() == 'cash') {
            await _saveCashTipToSubcollection();
          }

          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const Home()),
            (route) => false,
          );
          _showSnackBar(
            AppLocalizations.of(context)?.reviewSubmittedSuccessfully ??
                'Review submitted successfully',
          );
        } else {
          setState(() => _saving = false);
          _showSnackBar(
            AppLocalizations.of(context)?.failedToSaveReview ??
                'Failed to save review',
            isError: true,
          );
        }
      }
    } catch (e) {
      setState(() => _saving = false);
      _showSnackBar('An error occurred: $e', isError: true);
    }
  }

  Future<void> _saveCashTipToSubcollection() async {
    try {
      final workerId = widget.booking.agent?.uid;
      if (workerId == null || _selectedTip <= 0) return;

      final tipModel = AllTipsModel(
        id: "id_${DateTime.now().millisecondsSinceEpoch}",
        agentId: workerId,
        totalTipAmount: _selectedTip,
        paymentMethod: 'cash',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        proofs: [],
      );

      await BookingUtils.saveTipToSubcollection(
        workerId: workerId,
        tipData: tipModel,
      );
    } catch (e) {
      debugPrint('Error saving cash tip: $e');
    }
  }

  Future<bool> saveToTipping() async {
    return await BookingUtils.saveToTipping(
      workerId: widget.booking.agent?.uid ?? "",
      tipData: TippingModel.fromJson({
        "agentId": widget.booking.agent?.uid ?? "",
        "agentName": widget.booking.agent?.name ?? "",
        "agentPhone": widget.booking.agent?.phone ?? "",
        "cardtip": FieldValue.increment(_selectedTip),
        "lastUpdated": Timestamp.now(),
        "cashtip": FieldValue.increment(0.00),
        "walletId": widget.booking.agent?.uid ?? "",
        "payoutRequested": false,
      }),
    );
  }

  Future<void> _processTipPayment() async {
    setState(() => _processingTip = true);
    try {
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentWebView(
            isFromBooking: false,
            booking: widget.booking,
            customerData: widget.booking.customer,
            review: _createReviewModel(isTipPaid: true),
          ),
        ),
      );

      if (mounted) setState(() => _processingTip = false);
    } catch (e) {
      if (mounted) {
        setState(() => _processingTip = false);
        _showSnackBar(
          AppLocalizations.of(context)?.paymentFailed ??
              'Payment processing failed',
          isError: true,
        );
      }
    }
  }

  void _onTipAmountSelected(double amount) {
    setState(() {
      _selectedTip = amount;
      _showCustomTip = false;
      _customTipController.clear();
      _tipPaymentMethod = '';
    });
  }

  void _onCustomTipSelected() {
    setState(() {
      _showCustomTip = true;
      _selectedTip = 0.0;
      _tipPaymentMethod = '';
    });
  }

  void _onPaymentMethodSelected(String method) {
    setState(() => _tipPaymentMethod = method);
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildHeader(l10n),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildRatingSection(l10n),
                    const SizedBox(height: 16),
                    _buildReviewSection(l10n),
                    _buildTipSection(l10n),
                  ],
                ),
              ),
              _buildActionButtons(safePadding, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations? l10n) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n?.submitAReview ?? 'Submit Review',
            style: DMSansFont.textStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black54),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection(AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRequiredLabel(l10n?.overallRating ?? 'Overall Rating'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) => _buildStarIcon(index)),
          ),
        ],
      ),
    );
  }

  Widget _buildStarIcon(int index) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _rating = index + 1);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.star_rounded,
          color: index < _rating ? AppColors.yellow : AppColors.grey5,
          size: 36,
        ),
      ),
    );
  }

  Widget _buildReviewSection(AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRequiredLabel(l10n?.writeYourReview ?? 'Write Your Review'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _reviewController,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: l10n?.writeYourReviewHere ?? 'Share your experience...',
              hintStyle: DMSansFont.textStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black54,
              ),
              border: _outlineInputBorder(Colors.grey.shade300),
              focusedBorder: _outlineInputBorder(AppColors.secondary, width: 2),
              errorBorder: _outlineInputBorder(Colors.red),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return l10n?.pleaseWriteAReview ?? 'Please write a review';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTipSection(AppLocalizations? l10n) {
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
          _buildTipHeader(l10n),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._tipAmounts.map((amount) => _buildTipButton(amount, l10n)),
              _buildCustomTipButton(l10n),
            ],
          ),
          if (_showCustomTip) _buildCustomTipInput(l10n),
          if (_selectedTip > 0) _buildPaymentMethodSection(l10n),
          if (_selectedTip > 0 && _tipPaymentMethod.isNotEmpty)
            _buildTipSummary(l10n),
        ],
      ),
    );
  }

  Widget _buildTipHeader(AppLocalizations? l10n) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.favorite, color: AppColors.secondary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.thankTheTechnician ?? 'Thank the Technician',
                style: DMSansFont.textStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                l10n?.showAppreciationWithTip ?? 'Show appreciation with a tip',
                style: DMSansFont.textStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTipButton(double amount, AppLocalizations? l10n) {
    final isSelected = _selectedTip == amount && !_showCustomTip;
    return GestureDetector(
      onTap: () => _onTipAmountSelected(amount),
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
          '${l10n?.sar ?? 'SAR '} ${amount.toInt()}',
          style: DMSansFont.textStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTipButton(AppLocalizations? l10n) {
    return GestureDetector(
      onTap: _onCustomTipSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _showCustomTip ? AppColors.secondary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _showCustomTip ? AppColors.secondary : Colors.grey.shade300,
            width: _showCustomTip ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit,
              size: 16,
              color: _showCustomTip ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 4),
            Text(
              l10n?.custom ?? 'Custom',
              style: DMSansFont.textStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _showCustomTip ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTipInput(AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
        ),
        child: TextFormField(
          controller: _customTipController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            hintText: l10n?.enterCustomTipAmount ?? 'Enter custom tip amount',
            hintStyle: DMSansFont.textStyle(fontSize: 14, color: Colors.black54),
            prefixText: l10n?.sar ?? 'SAR ',
            prefixStyle: DMSansFont.textStyle(
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
              _selectedTip = amount;
              if (amount == 0) _tipPaymentMethod = '';
            });
          },
          validator: (value) {
            if (_showCustomTip) {
              if (value?.isEmpty ?? true) {
                return l10n?.pleaseEnterTipAmount ?? 'Please enter tip amount';
              }
              final amount = double.tryParse(value!) ?? 0.0;
              if (amount <= 0) {
                return l10n?.pleaseEnterValidTipAmount ??
                    'Please enter a valid tip amount';
              }
              if (amount < _minTipAmount) {
                return l10n?.minimumTipAmount ??
                    'Minimum tip amount is SAR 0.50';
              }
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection(AppLocalizations? l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          l10n?.selectPaymentMethod ?? 'Select Payment Method',
          style: DMSansFont.textStyle(
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
                l10n?.payWithCard ?? 'Pay with Card',
                Icons.credit_card,
                AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPaymentMethodButton(
                'cash',
                l10n?.payInCash ?? 'Pay in Cash',
                Icons.money,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodButton(
    String method,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _tipPaymentMethod == method;
    return GestureDetector(
      onTap: () => _onPaymentMethodSelected(method),
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
                style: DMSansFont.textStyle(
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

  Widget _buildTipSummary(AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              _tipPaymentMethod == 'card' ? Icons.credit_card : Icons.money,
              color: Colors.green,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${l10n?.tip ?? 'Tip'}: ${l10n?.sar ?? 'SAR '} ${_selectedTip.toStringAsFixed(2)} (${_tipPaymentMethod == 'card' ? l10n?.card ?? 'Card' : l10n?.cash ?? 'Cash'})',
                style: DMSansFont.textStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(EdgeInsets safePadding, AppLocalizations? l10n) {
    final isProcessing = _saving || _processingTip;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        bottom: safePadding.bottom + 16,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          if (!isProcessing)
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
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    l10n?.cancel ?? 'Cancel',
                    style: DMSansFont.textStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          if (!isProcessing) const SizedBox(width: 16),
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
                onPressed: isProcessing ? null : _saveReview,
                child: isProcessing
                    ? _buildProcessingIndicator(l10n)
                    : _buildSubmitButtonText(l10n),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingIndicator(AppLocalizations? l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _processingTip
              ? l10n?.processing ?? 'Processing...'
              : l10n?.submitting ?? 'Submitting...',
          style: DMSansFont.textStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButtonText(AppLocalizations? l10n) {
    return Text(
      _selectedTip > 0
          ? '${l10n?.submitReviewAndTip ?? 'Submit Review & Tip'} (${l10n?.sar ?? 'SAR '} ${_selectedTip.toStringAsFixed(2)})'
          : l10n?.submitReview ?? 'Submit Review',
      style: DMSansFont.textStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildRequiredLabel(String label) {
    return Row(
      children: [
        Text(
          label,
          style: DMSansFont.textStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        Text(
          ' *',
          style: DMSansFont.textStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  OutlineInputBorder _outlineInputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
