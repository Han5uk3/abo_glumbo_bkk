import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/total_tip.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:abo_glumbo_bbk/pages/telr/payment_screen.dart';
import 'package:abo_glumbo_bbk/services/booking/save_booking.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import '../models/booking.dart';

Future<dynamic> showWriteReviewBottomSheet(
  BuildContext context, {
  required BookingModel booking,
  bool showLaterOption = false,
}) async {
  return await showModalBottomSheet<dynamic>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (context) => WriteReviewBottomSheetWidget(
      booking: booking,
      showLaterOption: showLaterOption,
    ),
  );
}

class WriteReviewBottomSheetWidget extends StatefulWidget {
  const WriteReviewBottomSheetWidget({
    super.key,
    required this.booking,
    this.showLaterOption = false,
  });
  final BookingModel booking;
  final bool showLaterOption;

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

  static const List<double> _tipAmounts = [5.0, 10.0, 20.0, 50.0];
  static const double _minTipAmount = 1.0;

  @override
  void initState() {
    super.initState();
    _markRatingSheetShown();
  }

  void _markRatingSheetShown() {
    if (widget.booking.id.isNotEmpty && widget.booking.isRatingSheetShown != true) {
      widget.booking.isRatingSheetShown = true;
      try {
        AppFirestore.bookingsCollectionRef.doc(widget.booking.id).update({
          'isRatingSheetShown': true,
        });
      } catch (e) {
        debugPrint('Error updating isRatingSheetShown in WriteReviewBottomSheet: $e');
      }
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _customTipController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    final l10n = AppLocalizations.of(context);
    String? errorMessage;

    if (_selectedTip > 0 && _tipPaymentMethod.isEmpty) {
      errorMessage =
          l10n?.pleaseSelectPaymentMethod ??
          'Please select a payment method for your tip';
    } else if (_showCustomTip && _selectedTip <= 0) {
      errorMessage =
          l10n?.pleaseEnterValidTipAmount ?? 'Please enter a valid tip amount';
    } else if (_showCustomTip &&
        _selectedTip > 0 &&
        _selectedTip < _minTipAmount) {
      errorMessage =
          l10n?.minimumTipAmount ??
          'Minimum tip amount is SAR ${_minTipAmount.toStringAsFixed(2)}';
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
        content: Text(
          message,
          style: TextStyle(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: isError ? AppColors.red : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  ReviewModel _createReviewModel({bool isTipPaid = false}) {
    return ReviewModel(
      workerId: widget.booking.agent?.uid,
      rating: _rating,
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
    final l10n = AppLocalizations.of(context);
    if (!_validateForm()) return;

    setState(() => _saving = true);

    try {
      if (_selectedTip > 0 && _tipPaymentMethod.toLowerCase() == 'card') {
        await _processTipPayment();
      } else {
        final success = await BookingUtils.saveReview(
          booking: widget.booking,
          review: _createReviewModel(),
        );

        if (success) {
          if (_selectedTip > 0 && _tipPaymentMethod.toLowerCase() == 'cash') {
            await _saveCashTipToSubcollection();
          }

          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const Home()),
            (route) => false,
          );
          _showSnackBar(
            l10n?.reviewSubmittedSuccessfully ?? 'Review submitted successfully',
          );
        } else {
          setState(() => _saving = false);
          _showSnackBar(
            l10n?.failedToSaveReview ?? 'Failed to save review',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showSnackBar('An error occurred: $e', isError: true);
      }
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
      if (_selectedTip == amount && !_showCustomTip) {
        _selectedTip = 0.0;
        _tipPaymentMethod = '';
      } else {
        _selectedTip = amount;
        _showCustomTip = false;
        _customTipController.clear();
        _tipPaymentMethod = '';
      }
    });
  }

  void _onCustomTipSelected() {
    setState(() {
      if (_showCustomTip) {
        _showCustomTip = false;
        _selectedTip = 0.0;
        _customTipController.clear();
        _tipPaymentMethod = '';
      } else {
        _showCustomTip = true;
        _selectedTip = 0.0;
        _tipPaymentMethod = '';
      }
    });
  }

  void _onPaymentMethodSelected(String method) {
    setState(() => _tipPaymentMethod = method);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgBlueTint,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          _buildHeader(l10n),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildBookingInfoCard(l10n),
                    const SizedBox(height: 16),
                    _buildRatingSection(l10n),
                    const SizedBox(height: 20),
                    _buildReviewSection(l10n),
                    const SizedBox(height: 20),
                    _buildTipSection(l10n),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          _buildActionButtons(l10n),
        ],
      ),
    ),);
  }

  Widget _buildBookingInfoCard(AppLocalizations? l10n) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final serviceName = widget.booking.service.nameLocalized(languageCode: languageCode) ??
        widget.booking.service.name ??
        '';
    final technicianName = widget.booking.agent?.name?.trim() ?? '';
    final bookingIdDisplay = (widget.booking.newBookingId != null &&
            widget.booking.newBookingId!.trim().isNotEmpty)
        ? widget.booking.newBookingId!.trim()
        : widget.booking.id;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  serviceName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  '#$bookingIdDisplay',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (technicianName.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.8, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.technician ?? 'Technician',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        technicianName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n?.submitAReview ?? 'Submit Review',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.black1,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context, widget.showLaterOption ? 'later' : false),
            icon: const Icon(Icons.close, color: Colors.black, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
        children: [
          Text(
            l10n?.overallRating ?? 'Overall Rating',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.black1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildStarIcon(index),
              ),
            ),
          ),
          if (_rating > 0) ...[
            const SizedBox(height: 12),
            Text(
              _getRatingDescription(_rating, l10n),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _getRatingColor(_rating),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getRatingDescription(int rating, AppLocalizations? l10n) {
    switch (rating) {
      case 1:
        return l10n?.poor ?? 'Poor';
      case 2:
        return l10n?.fair ?? 'Fair';
      case 3:
        return l10n?.good ?? 'Good';
      case 4:
        return l10n?.veryGood ?? 'Very Good';
      case 5:
        return l10n?.excellent ?? 'Excellent';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    if (rating <= 2) return AppColors.red;
    if (rating == 3) return AppColors.yellow;
    return const Color(0xFF34A059);
  }

  Widget _buildStarIcon(int index) {
    final bool isSelected = index < _rating;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() => _rating = index + 1);
      },
      child: AnimatedScale(
        scale: isSelected ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
          color: isSelected ? const Color(0xFFFBBF24) : Colors.grey.shade300,
          size: 44,
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
          Row(
            children: [
              Text(
                l10n?.writeYourReview ?? 'Write Your Review',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black1,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(color: AppColors.red, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _reviewController,
            maxLines: 4,
            maxLength: 500,
            style: TextStyle(fontSize: 14, color: AppColors.black1),
            decoration: InputDecoration(
              hintText:
                  l10n?.writeYourReviewHere ?? 'Share your experience with us...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
              counterStyle: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: _outlineInputBorder(Colors.grey.shade200),
              enabledBorder: _outlineInputBorder(Colors.grey.shade200),
              focusedBorder: _outlineInputBorder(AppColors.secondary, width: 1.5),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipSection(AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.volunteer_activism_rounded,
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
                      '${l10n?.thankTheTechnician ?? 'Thank the Technician'} (${l10n?.optional ?? 'Optional'})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black1,
                      ),
                    ),
                    Text(
                      l10n?.showAppreciationWithTip ??
                          'Show appreciation with a tip',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._tipAmounts.map(
                  (amount) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _buildTipButton(amount, l10n),
                  ),
                ),
                _buildCustomTipButton(l10n),
              ],
            ),
          ),
          if (_showCustomTip) _buildCustomTipInput(l10n),
          if (_selectedTip > 0) ...[
            const SizedBox(height: 20),
            Text(
              l10n?.selectPaymentMethod ?? 'Select Payment Method',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.black1,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPaymentMethodButton(
                    'card',
                    l10n?.payWithCard ?? 'Card',
                    Icons.credit_card_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPaymentMethodButton(
                    'cash',
                    l10n?.payInCash ?? 'Cash',
                    Icons.payments_rounded,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
          color: isSelected ? AppColors.secondary : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.secondary : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Text(
          '${amount.toInt()} ${l10n?.sar ?? 'SAR '}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.black1,
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
          color: _showCustomTip ? AppColors.secondary : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _showCustomTip ? AppColors.secondary : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.edit_rounded,
              size: 14,
              color: _showCustomTip ? Colors.white : AppColors.black1,
            ),
            const SizedBox(width: 6),
            Text(
              l10n?.custom ?? 'Custom',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _showCustomTip ? Colors.white : AppColors.black1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTipInput(AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
        ),
        child: TextFormField(
          controller: _customTipController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.black1,
          ),
          decoration: InputDecoration(
            hintText: '0.00',
            hintStyle: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade400,
            ),
            suffixText: ' ${l10n?.sar ?? 'SAR '}',
            suffixStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.black1,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onChanged: (value) {
            final amount = double.tryParse(value) ?? 0.0;
            setState(() {
              _selectedTip = amount;
              if (amount == 0) _tipPaymentMethod = '';
            });
          },
        ),
      ),
    );
  }

  Widget _buildPaymentMethodButton(String method, String label, IconData icon) {
    final isSelected = _tipPaymentMethod == method;
    return GestureDetector(
      onTap: () => _onPaymentMethodSelected(method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.secondary : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.black1,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.black1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(AppLocalizations? l10n) {
    final bool isBusy = _saving || _processingTip;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomPadding > 0 ? bottomPadding : 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 54,
              child: OutlinedButton(
                onPressed: isBusy ? null : () {
                  Navigator.pop(context, widget.showLaterOption ? 'later' : false);
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  widget.showLaterOption ? _getLaterText(context) : (l10n?.cancel ?? 'Cancel'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: isBusy ? null : _saveReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isBusy
                    ? const Loader(color: Colors.white, size: 24)
                    : Text(
                        _selectedTip > 0
                            ? l10n?.submitReviewAndTip ?? 'Submit Review & Tip'
                            : l10n?.submitReview ?? 'Submit Review',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLaterText(BuildContext context) {
    final lang = LocalStoreHelper.getUserlanguage();
    if (lang == 'ar') return 'لاحقاً';
    if (lang == 'ur') return 'بعد میں';
    return 'Later';
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
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
