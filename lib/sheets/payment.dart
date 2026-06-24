import 'package:abo_glumbo_bbk/sheets/upload_payment_proof_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:abo_glumbo_bbk/apis/telr_apple_pay.dart';
import 'package:abo_glumbo_bbk/common_widgets/elevated_button.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/transaction.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/pages/bookings/payment_success.dart';
import 'package:abo_glumbo_bbk/pages/telr/payment_screen.dart';
import 'package:abo_glumbo_bbk/services/booking/save_booking.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pay/pay.dart';

void showPaymentBottomSheet(
  BuildContext context, {
  required UserModel agent,
  required ServiceModel service,
  // required File? selectedImage,
  // required File? selectedVideo,
  // required DateTime? selectedDate,
  // required List<Map> timeSlots,
  // required int selectedTimeCategory,
  // required int selectedTimeSlot,
  // required TextEditingController notesController,
  required CustomerModel customerData,
  required BookingModel booking,
  // required AddressModel selectedAddress,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    builder: (BuildContext context) {
      return SafeArea(
        child: PaymentWindow(
          agent: agent,
          service: service,
          // selectedImage: selectedImage,
          // selectedVideo: selectedVideo,
          // selectedDate: selectedDate,
          // timeSlots: timeSlots,
          // selectedTimeCategory: selectedTimeCategory,
          // selectedTimeSlot: selectedTimeSlot,
          // notesController: notesController,
          customerData: customerData,
          booking: booking,
          // selectedAddress: selectedAddress,
        ),
      );
    },
  );
}

class PaymentWindow extends StatefulWidget {
  final ServiceModel service;
  // File? selectedImage;
  // File? selectedVideo;
  // DateTime? selectedDate;
  // List<Map> timeSlots;
  // int selectedTimeCategory;
  // int selectedTimeSlot;
  // TextEditingController notesController;
  CustomerModel customerData;
  final BookingModel booking;
  // AddressModel selectedAddress;

  UserModel agent;
  PaymentWindow({
    super.key,
    required this.service,
    required this.agent,
    // this.selectedImage,
    // this.selectedVideo,
    // this.selectedDate,
    // required this.timeSlots,
    // this.selectedTimeCategory = 0,
    // this.selectedTimeSlot = 0,
    // required this.notesController,
    required this.customerData,
    required this.booking,
    // required this.selectedAddress,
  });

  @override
  State<PaymentWindow> createState() => _PaymentWindowState();
}

class _PaymentWindowState extends State<PaymentWindow> {
  final _formKey = GlobalKey<FormState>();
  String? selectedPayment;
  bool isLoading = false;
  // String? selectedImageDownloadUrl;
  // String? selectedVideoDownloadUrl;
  // bool isUploading = false;
  bool isCashPaymentProcessing = false;

  String generateOrderId(String uid, double amount) {
    String uidSuffix = uid.length > 6 ? uid.substring(uid.length - 6) : uid;
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String amountString = amount.toStringAsFixed(0);
    return "ORDER$uidSuffix$timestamp$amountString";
  }

  // Future<bool> saveBooking() async {
  //   return await BookingUtils.saveBooking(
  //     service: widget.service,
  //     agent:widget.agent,
  //     selectedDate: widget.selectedDate!,
  //     paymentMode: selectedPayment ?? "",
  //     customerData: widget.customerData,
  //     notes: widget.notesController.text.trim(),
  //     timeSlot:
  //         widget.timeSlots[widget.selectedTimeCategory]["values"][widget
  //             .selectedTimeSlot],
  //     selectedImage: widget.selectedImage,
  //     selectedVideo: widget.selectedVideo,
  //   );
  // }

  void processPayment() async {
    if (selectedPayment == null) return;

    setState(() {
      isLoading = true;
    });

    double finalAmount = widget.booking.completionData?.totalCost ??
        double.tryParse(widget.service.price.toString()) ??
        0;

    String orderId = generateOrderId(
      widget.customerData.uid ?? "guest",
      finalAmount,
    );

    try {
      if (selectedPayment == "Inside App") {
        setState(() {
          isLoading = false;
        });
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebView(
              isFromBooking: true,
              customerData: widget.customerData,
              service: widget.service,
              booking: widget.booking,
              selectedPayment: selectedPayment,

              // selectedDate: widget.selectedDate,
              // notesController: widget.notesController,
              // selectedTimeCategory: widget.selectedTimeCategory,
              // selectedTimeSlot: widget.selectedTimeSlot,
              // timeSlots: [...widget.timeSlots],
              // selectedImage: widget.selectedImage,
              // selectedVideo: widget.selectedVideo,
            ),
          ),
          (route) => false,
        );
      } else if (selectedPayment == "Apple Pay") {
        // Apple Pay logic
        final applePayResult = await showApplePaySheet();

        if (applePayResult == null) {
          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }
          return; // Exit early if Apple Pay was cancelled or failed
        }

        final token = applePayResult['token'];

        // Check if token is valid (not null and not empty)
        if (token == null || token.toString().isEmpty) {
          // Check if this is a simulator environment
          String errorMessage =
              'Invalid Apple Pay token received. Please try again or use another payment method.';
          bool isSimulator =
              applePayResult.containsKey('transactionIdentifier') &&
              applePayResult['transactionIdentifier'] == 'Simulated Identifier';

          if (isSimulator) {
            errorMessage =
                'Apple Pay simulation detected. The token is empty in the simulator environment.\n\nTo test Apple Pay:\n• Use a real iOS device\n• Ensure you have a valid card in Apple Wallet\n• Make sure Touch ID/Face ID is enabled\n\nFor now, please use another payment method.';
          }

          _showApplePayError(errorMessage);
          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }
          return;
        }
        // Prepare the token for Telr - it could be a string or a map
        Map<String, dynamic> tokenForTelr;
        if (token is String) {
          // If token is a string, wrap it in a map
          tokenForTelr = {"token": token};
        } else if (token is Map<String, dynamic>) {
          // If token is already a map, use it directly
          tokenForTelr = token;
        } else {
          // If token is neither string nor map, convert the entire result
          tokenForTelr = applePayResult;
        }

        final applePayService = ApplePayService(
          storeId: '31767',
          authKey: 'hSpz8-KLzZn~W5mp',
        );

        try {
          final paymentSuccess = await applePayService.sendApplePayTokenToTelr(
            applePayToken: tokenForTelr,
            amount: double.tryParse(widget.service.price.toString()) ?? 0,
            orderId: orderId,
            customerName: widget.customerData.name.toString(),
            customerEmail: widget.customerData.email.toString(),
            customerPhone: widget.customerData.phone.toString(),
          );

          if (paymentSuccess) {
            // final isBooked = await saveBooking();
            if (mounted) {
              showSnackBar(
                // isBooked
                //     ? AppLocalizations.of(context)!.bookingSuccess
                //     : AppLocalizations.of(context)!.bookingFailed,
                AppLocalizations.of(context)!.paymentSuccessful,
                context,
              );
            }
          } else {
            if (mounted) {
              showSnackBar(
                AppLocalizations.of(context)!.paymentFailed,
                context,
              );
            }
          }
        } catch (e) {
          _showApplePayError(
            'There was an error processing your Apple Pay payment with our payment provider.',
          );
        } finally {
          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }
        }
      } else if (selectedPayment == "Outside App") {
        setState(() {
          isLoading = false;
        });

        // If it's an existing booking being completed, show proof upload sheet
        if (widget.booking.completionData != null) {
          Navigator.pop(context); // Close the payment mode selector
          final result = await showUploadPaymentProofSheet(
            context,
            booking: widget.booking,
          );
          if (result == true) {
            // Success
          }
        } else {
          // Prevent duplicate cash payments
          if (isCashPaymentProcessing) {
            return; // Exit early if cash payment is already being processed
          }

          // Set the flag to prevent duplicate processing
          isCashPaymentProcessing = true;

          Navigator.pop(context); // Close the payment bottom sheet
          showCashDetailBottomSheet(
            booking: widget.booking,
            context: context,
            customer: widget.customerData,
            worker: widget.agent,
            orderId: orderId,
            paymentModeCode: "O",
            amount: finalAmount.toString(),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        // Reset cash payment flag in case of any exception
        if (selectedPayment == "Outside App") {
          isCashPaymentProcessing = false;
        }
      }
    }
  }

  void showCashDetailBottomSheet({
    required BookingModel booking,
    required BuildContext context,
    required CustomerModel customer,
    required UserModel worker,
    required String orderId,
    required String amount,
    required String paymentModeCode,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: CashPaymentDetails(
            orderId: orderId,
            amount: double.tryParse(amount) ?? 0.0,
            paymentModeCode: paymentModeCode,
            booking: booking,
            customer: customer,
            worker: worker,
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> showApplePaySheet() async {
    try {
      // Check if Apple Pay is available on this device
      final applePayConfig = await PaymentConfiguration.fromAsset(
        'apple_pay_config.json',
      );

      final payClient = Pay({PayProvider.apple_pay: applePayConfig});

      // Check if Apple Pay is available
      final isApplePayAvailable = await payClient.userCanPay(
        PayProvider.apple_pay,
      );

      if (!isApplePayAvailable) {
        // Show a dialog instead of a snackbar for better visibility
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: Text(
                  (AppLocalizations.of(context)?.applePayNotAvailable ?? 'Apple Pay Not Available'),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 50),
                    SizedBox(height: 16),
                    Text(
                      (AppLocalizations.of(context)?.applePayNotAvailableDevice ?? 'Apple Pay is not available on this device.'),
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please make sure:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• You have set up Apple Pay in your Wallet app\n'
                      '• Your device supports Apple Pay\n'
                      '• You have added a valid payment card',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: Text(
                      (AppLocalizations.of(context)?.chooseAnotherPaymentMethod ?? 'Choose Another Payment Method'),
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }
        return null;
      }

      final paymentItems = [
        PaymentItem(
          label: 'Total',
          amount: widget.service.price.toString(),
          status: PaymentItemStatus.final_price,
        ),
      ];

      final result = await payClient.showPaymentSelector(
        PayProvider.apple_pay,
        paymentItems,
      );
      return result;
    } catch (e) {
      debugPrint("Apple Pay Error: $e");

      // Show a dialog with error details instead of a snackbar
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(
                (AppLocalizations.of(context)?.applePayError ?? 'Apple Pay Error'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 50),
                  SizedBox(height: 16),
                  Text(
                    (AppLocalizations.of(context)?.errorProcessingApplePay ?? 'There was an error processing your Apple Pay payment.'),
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Error details:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    e.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red[700],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(
                    (AppLocalizations.of(context)?.tryAnotherPaymentMethod ?? 'Try Another Payment Method'),
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }

      return null;
    }
  }

  void _showApplePayError(String message) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.apple, color: Colors.black, size: 24),
              SizedBox(width: 8),
              Text(
                'Apple Pay',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: Colors.orange, size: 50),
              SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(fontSize: 16, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                (AppLocalizations.of(context)?.useAnotherPaymentMethod ?? 'Use Another Payment Method'),
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)?.paymentMode ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            paymentModeButtons(
              title: AppLocalizations.of(context)?.insideApp ?? 'Inside App',
              imageUrl:
                  "https://firebasestorage.googleapis.com/v0/b/worker-app-tnext.appspot.com/o/categories%2Fatm-card.png?alt=media&token=06e60c23-63cf-45e3-9a73-b09ec10ba03b",
              isSelected: selectedPayment == "Inside App",
              onTap: () => setState(() => selectedPayment = "Inside App"),
            ),
            paymentModeButtons(
              title: AppLocalizations.of(context)?.outsideApp ?? 'Outside App',
              imageUrl:
                  "https://firebasestorage.googleapis.com/v0/b/worker-app-tnext.appspot.com/o/categories%2Fcash-on-delivery.png?alt=media&token=90773e14-dfe6-4954-86fa-129975ce8a51",
              isSelected: selectedPayment == "Outside App",
              onTap: () => setState(() => selectedPayment = "Outside App"),
            ),
            Spacer(),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16,
                right: 16,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        (selectedPayment == null ||
                            (selectedPayment == "Outside App" &&
                                isCashPaymentProcessing))
                        ? Colors.grey
                        : AppColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      selectedPayment == null ||
                          (selectedPayment == "Outside App" &&
                              isCashPaymentProcessing)
                      ? null
                      : processPayment,
                  child:
                      (isLoading ||
                          (selectedPayment == "Outside App" &&
                              isCashPaymentProcessing))
                      ? Loader(size: 24, color: Colors.white)
                      : Text(
                          AppLocalizations.of(context)?.continueText ?? '',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget paymentModeButtons({
    required String title,
    required String imageUrl,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.secondary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            (imageUrl.isNotEmpty &&
                    Uri.tryParse(imageUrl) != null &&
                    Uri.tryParse(imageUrl)!.hasAbsolutePath)
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 50,
                    width: 50,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Loader(),
                    errorWidget: (context, url, error) =>
                        Icon(Icons.broken_image, size: 50, color: Colors.grey),
                  )
                : Container(
                    height: 50,
                    width: 50,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 25,
                      ),
                    ),
                  ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
              color: isSelected ? AppColors.secondary : Colors.grey,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class CashPaymentDetails extends StatefulWidget {
  final String orderId;
  final double amount;
  final String paymentModeCode;
  final BookingModel booking;
  final CustomerModel customer;
  final UserModel worker;

  const CashPaymentDetails({
    super.key,
    required this.orderId,
    required this.amount,
    required this.paymentModeCode,
    required this.booking,
    required this.customer,
    required this.worker,
  });

  @override
  State<CashPaymentDetails> createState() => _CashPaymentDetailsState();
}

class _CashPaymentDetailsState extends State<CashPaymentDetails> {
  final TextEditingController _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;

  double get totalAmount => (widget.amount);
  double get paidAmount => double.tryParse(_amountController.text) ?? 0.0;
  @override
  void initState() {
    super.initState();
    _amountController.text = totalAmount.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<bool> saveTransaction() async {
    TransactionModel transaction = TransactionModel(
      Timestamp.now(),
      amount: widget.amount,
      paymentStatus: "completed",
      paymentMethod: widget.paymentModeCode == "C" ? "Inside App" : "Outside App",
      createdAt: Timestamp.now(),
      orderId: widget.orderId,
      customerId: widget.customer.uid ?? "",
      workerId: widget.worker.uid ?? "",
      bookingId: widget.booking.id,
    );
    return await BookingUtils.saveTransaction(transaction: transaction);
  }

  void _processPayment() async {
    if (_formKey.currentState!.validate()) {
      // Show confirmation dialog
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // User must tap a button
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: AppColors.bgBlueTint,
            actionsAlignment: MainAxisAlignment.start,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.confirmPayment,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppLocalizations.of(context)!.orderId}: ${widget.orderId}',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.amountToBePaid,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${totalAmount.toStringAsFixed(2)} ${AppLocalizations.of(context)!.sar}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.amountPaid,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${paidAmount.toStringAsFixed(2)} ${AppLocalizations.of(context)!.sar}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(
                    context,
                  )!.areYouSureYouWantToConfirmThisPayment,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              eButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                context: context,
                backgroundColor: AppColors.primary,
                textColor: Colors.white,
                text: AppLocalizations.of(context)!.confirm,
              ),

              eButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                context: context,
                backgroundColor: Colors.grey,
                textColor: Colors.white,
                text: AppLocalizations.of(context)!.cancel,
              ),
            ],
          );
        },
      );

      // Check if user confirmed the payment
      if (confirmed == true) {
        setState(() => _isProcessing = true);

        BookingUtils.updateBookingStatus(
          booking: widget.booking,
          isCompleted: true,
          paymentModeCode: widget.paymentModeCode,
          orderId: widget.orderId,
        );
        await saveTransaction();

        // NOTE: Cash payments are "outside-app" payments — the technician collects 
        // the cash directly. The wallet tracking for these payments is handled by
        // the technician app's verify_payment_sheet when they upload payment proof.
        // We do NOT track cash payments as in-app earnings here.
        if (kDebugMode) {
          debugPrint(
            'ℹ️ Cash payment: wallet tracking handled by technician app verify_payment_sheet',
          );
        }

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => PaymentSuccessPage(
                isFromBooking: true,
                amount: widget.amount,
                paymentMethod: widget.paymentModeCode,
                orderId: widget.orderId,
                booking: widget.booking,
              ),
            ),
            (route) => false,
          );
        }
      }
      // If confirmed is false or null, do nothing (user cancelled)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.cashPayment,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Order ID
            _buildInfoRow(
              AppLocalizations.of(context)!.orderId,
              widget.orderId,
              Icons.receipt_long,
            ),
            const SizedBox(height: 16),

            // Amount to be paid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.amountToBePaid,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${totalAmount.toStringAsFixed(2)} ${AppLocalizations.of(context)!.sar}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Amount paid input
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,

              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.amountPaid,
                hintText: AppLocalizations.of(context)!.amountPaid,

                prefix: Padding(
                  padding: EdgeInsets.only(
                    right: Directionality.of(context) == TextDirection.rtl
                        ? 0
                        : 5,
                    left: Directionality.of(context) == TextDirection.rtl
                        ? 5
                        : 0,
                  ),
                  child: Text(AppLocalizations.of(context)!.sar),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context)!.pleaseEnterTheAmountPaid;
                }
                final paid = double.tryParse(value);
                if (paid == null) {
                  return AppLocalizations.of(context)!.pleaseEnterAValidAmount;
                }
                if (paid < totalAmount) {
                  return "${AppLocalizations.of(context)!.amountMustBeAtLeast} ${totalAmount.toStringAsFixed(2)}";
                }
                if (paid > totalAmount) {
                  return "${AppLocalizations.of(context)!.amountMustBeEqualTo} ${totalAmount.toStringAsFixed(2)}";
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Confirm button
            ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 30,
                      child: Loader(size: 10),
                    )
                  : Text(
                      AppLocalizations.of(context)!.confirmPayment,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}
