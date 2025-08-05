import 'dart:io';
import 'package:abo_glumbo_bbk/apis/telr_apple_pay.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/snak_bar.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/pages/bookings/booking_success.dart';
import 'package:abo_glumbo_bbk/pages/telr/payment_screen.dart';
import 'package:abo_glumbo_bbk/services/booking/save_booking.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pay/pay.dart';

showPaymentBottomSheet(
  BuildContext context, {
  required ServiceModel service,
  required File? selectedImage,
  required File? selectedVideo,
  required DateTime? selectedDate,
  required List<Map> timeSlots,
  required int selectedTimeCategory,
  required int selectedTimeSlot,
  required TextEditingController notesController,
  required CustomerModel customerData,
  required AddressModel selectedAddress,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    builder: (BuildContext context) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: PaymentWindow(
            service: service,
            selectedImage: selectedImage,
            selectedVideo: selectedVideo,
            selectedDate: selectedDate,
            timeSlots: timeSlots,
            selectedTimeCategory: selectedTimeCategory,
            selectedTimeSlot: selectedTimeSlot,
            notesController: notesController,
            customerData: customerData,
            selectedAddress: selectedAddress,
          ),
        ),
      );
    },
  );
}

class PaymentWindow extends StatefulWidget {
  final ServiceModel service;
  File? selectedImage;
  File? selectedVideo;
  DateTime? selectedDate;
  List<Map> timeSlots;
  int selectedTimeCategory;
  int selectedTimeSlot;
  TextEditingController notesController;
  CustomerModel customerData;
  AddressModel selectedAddress;
  PaymentWindow({
    super.key,
    required this.service,
    this.selectedImage,
    this.selectedVideo,
    this.selectedDate,
    required this.timeSlots,
    this.selectedTimeCategory = 0,
    this.selectedTimeSlot = 0,
    required this.notesController,
    required this.customerData,
    required this.selectedAddress,
  });

  @override
  State<PaymentWindow> createState() => _PaymentWindowState();
}

class _PaymentWindowState extends State<PaymentWindow> {
  final _formKey = GlobalKey<FormState>();
  String? selectedPayment;
  bool isLoading = false;
  String? selectedImageDownloadUrl;
  String? selectedVideoDownloadUrl;
  bool isUploading = false;
  bool isCashPaymentProcessing = false;

  String generateOrderId(String uid, double amount) {
    String uidSuffix = uid.length > 6 ? uid.substring(uid.length - 6) : uid;
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String amountString = amount.toStringAsFixed(0);
    return "ORDER$uidSuffix$timestamp$amountString";
  }

  Future<bool> saveBooking() async {
    return await BookingUtils.saveBooking(
      service: widget.service,
      selectedDate: widget.selectedDate!,
      paymentMode: selectedPayment ?? "",
      customerData: widget.customerData,
      notes: widget.notesController.text.trim(),
      timeSlot:
          widget.timeSlots[widget.selectedTimeCategory]["values"][widget
              .selectedTimeSlot],
      selectedImage: widget.selectedImage,
      selectedVideo: widget.selectedVideo,
    );
  }

  void processPayment() async {
    if (selectedPayment == null) return;

    setState(() {
      isLoading = true;
    });

    String orderId = generateOrderId(
      widget.customerData.uid ?? "guest",
      double.tryParse(widget.service.price.toString()) ?? 0,
    );

    try {
      if (selectedPayment == "Cards") {
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
              selectedDate: widget.selectedDate,
              notesController: widget.notesController,
              selectedTimeCategory: widget.selectedTimeCategory,
              selectedTimeSlot: widget.selectedTimeSlot,
              timeSlots: [...widget.timeSlots],
              selectedImage: widget.selectedImage,
              selectedVideo: widget.selectedVideo,
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
            final isBooked = await saveBooking();
            if (mounted) {
              showSnackBar(
                isBooked
                    ? AppLocalizations.of(context)!.bookingSuccess
                    : AppLocalizations.of(context)!.bookingFailed,
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
      } else if (selectedPayment == "Cash On Hands") {
        // Prevent duplicate cash payments
        if (isCashPaymentProcessing) {
          return; // Exit early if cash payment is already being processed
        }

        // Set the flag to prevent duplicate processing
        isCashPaymentProcessing = true;

        // Cash payment logic
        final isBooked = await saveBooking();
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          if (isBooked) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BookingSuccessPage(
                  orderId: orderId,
                  isFromCashOnDelivery: true,
                ),
              ),
            );
          } else {
            showSnackBar(AppLocalizations.of(context)!.bookingFailed, context);
            // Reset the flag if booking failed so user can try again
            isCashPaymentProcessing = false;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        // Reset cash payment flag in case of any exception
        if (selectedPayment == "Cash On Hands") {
          isCashPaymentProcessing = false;
        }
      }
    }
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
                  'Apple Pay Not Available',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 50),
                    SizedBox(height: 16),
                    Text(
                      'Apple Pay is not available on this device.',
                      style: GoogleFonts.dmSans(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please make sure:',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• You have set up Apple Pay in your Wallet app\n'
                      '• Your device supports Apple Pay\n'
                      '• You have added a valid payment card',
                      style: GoogleFonts.dmSans(fontSize: 14),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: Text(
                      'Choose Another Payment Method',
                      style: GoogleFonts.dmSans(
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
                'Apple Pay Error',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 50),
                  SizedBox(height: 16),
                  Text(
                    'There was an error processing your Apple Pay payment.',
                    style: GoogleFonts.dmSans(fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Error details:',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    e.toString(),
                    style: GoogleFonts.dmSans(
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
                    'Try Another Payment Method',
                    style: GoogleFonts.dmSans(
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
                style: GoogleFonts.dmSans(
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
                style: GoogleFonts.dmSans(fontSize: 16, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Use Another Payment Method',
                style: GoogleFonts.dmSans(
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
                    style: GoogleFonts.dmSans(
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
              title: AppLocalizations.of(context)?.cards ?? '',
              imageUrl:
                  "https://firebasestorage.googleapis.com/v0/b/worker-app-tnext.appspot.com/o/categories%2Fatm-card.png?alt=media&token=06e60c23-63cf-45e3-9a73-b09ec10ba03b",
              isSelected: selectedPayment == "Cards",
              onTap: () => setState(() => selectedPayment = "Cards"),
            ),
            Platform.isIOS
                ? paymentModeButtons(
                    title: AppLocalizations.of(context)?.applePay ?? '',
                    imageUrl:
                        "https://firebasestorage.googleapis.com/v0/b/worker-app-tnext.appspot.com/o/categories%2Fapple-pay.png?alt=media&token=b1d799b1-3d10-42d0-b03a-810a69cba79f",
                    isSelected: selectedPayment == "Apple Pay",
                    onTap: () => setState(() => selectedPayment = "Apple Pay"),
                  )
                : Container(),
            paymentModeButtons(
              title: AppLocalizations.of(context)?.cashOnHands ?? '',
              imageUrl:
                  "https://firebasestorage.googleapis.com/v0/b/worker-app-tnext.appspot.com/o/categories%2Fcash-on-delivery.png?alt=media&token=90773e14-dfe6-4954-86fa-129975ce8a51",
              isSelected: selectedPayment == "Cash On Hands",
              onTap: () => setState(() => selectedPayment = "Cash On Hands"),
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
                            (selectedPayment == "Cash On Hands" &&
                                isCashPaymentProcessing))
                        ? Colors.grey
                        : AppColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      selectedPayment == null ||
                          (selectedPayment == "Cash On Hands" &&
                              isCashPaymentProcessing)
                      ? null
                      : processPayment,
                  child:
                      (isLoading ||
                          (selectedPayment == "Cash On Hands" &&
                              isCashPaymentProcessing))
                      ? Loader(size: 24, color: Colors.white)
                      : Text(
                          AppLocalizations.of(context)?.continueText ?? '',
                          style: GoogleFonts.dmSans(
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
