import 'dart:io';
import 'package:abo_glumbo_bbk/apis/telr_services.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/telr/request_model.dart';

import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/pages/bookings/payment_failed.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:abo_glumbo_bbk/services/telr_config.dart';
import 'package:abo_glumbo_bbk/pages/bookings/processing_payment_page.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/services/location_matcher_service.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebView extends StatefulWidget {
  final CustomerModel customerData;
  final bool isFromBooking;
  File? selectedImage;
  File? selectedVideo;
  DateTime? selectedDate;
  Map? timeSlot;
  ServiceModel? service;
  ReviewModel? review;
  BookingModel? booking;
  UserModel? agent;
  AddressModel? selectedAddress;
  MatchedServiceZone? serviceLocation;
  TextEditingController? notesController;
  String? selectedPayment;

  PaymentWebView({
    super.key,
    this.service,
    required this.customerData,
    required this.isFromBooking,
    this.selectedImage,
    this.selectedVideo,
    this.selectedDate,
    this.timeSlot,
    this.review,
    this.notesController,
    this.booking,
    this.agent,
    this.selectedAddress,
    this.serviceLocation,
    this.selectedPayment,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  bool isLoading = false;
  String? selectedImageDownloadUrl;
  String? selectedVideoDownloadUrl;
  bool isUploading = false;
  String? orderId;

  @override
  void initState() {
    _checkConfigurationAndInitialize();
    super.initState();
  }

  // Initialize the Payment
  void _checkConfigurationAndInitialize() {
    if (!TelrConfig.isConfigured) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context)!.telrNotConfigured;
        });
      }
      return;
    }
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    String generateOrderId(String uid, double amount) {
      String uidSuffix = uid.length > 6 ? uid.substring(uid.length - 6) : uid;
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String amountString = amount.toStringAsFixed(0);
      return "ORDER$uidSuffix$timestamp$amountString";
    }

    AddressModel selectedAddress = widget.customerData.addresses.firstWhere(
      (address) => address.isSelected == true,
      orElse: () => widget.customerData.addresses.isNotEmpty
          ? widget.customerData.addresses.first
          : AddressModel(
              id: 'default',
              fullName: '',
              buildingNumber: '',
              phoneNumber: '',
              streetName: null,
              lon: null,
              lat: null,
              isSelected: false,
            ),
    );

    ServiceModel? activeService = widget.booking?.service ?? widget.service;
    
    double inspectionFee =
        widget.booking?.completionData?.inspectionFee ??
        activeService?.price ??
        0.0;
    
    double discountedInspectionFee = activeService != null 
        ? activeService.getDiscountedPrice(inspectionFee) 
        : inspectionFee;

    double totalServiceCost = widget.booking?.completionData?.totalCost ?? 0.0;
    double finalAmount = widget.booking?.completionData != null
        ? (totalServiceCost + discountedInspectionFee)
        : widget.isFromBooking
        ? discountedInspectionFee
        : widget.review?.tipAmount ?? 0.0;

    orderId = generateOrderId(widget.customerData.uid ?? '', finalAmount);

    // Extract city from the full city address (fullName)
    String city = "";
    if (selectedAddress.fullName.isNotEmpty) {
      if (selectedAddress.fullName.contains(',')) {
        final parts = selectedAddress.fullName.split(',');
        if (parts.length >= 2) {
          // Take the second to last component (usually the city)
          city = parts[parts.length - 2].trim();
        } else {
          city = parts.first.trim();
        }
      } else {
        city = selectedAddress.fullName.split(' ').first;
      }
    }

    try {
      final paymentRequest = TelrPaymentRequest(
        ivp_store: TelrConfig.storeId,
        ivp_authkey: TelrConfig.authKey,
        ivp_order: OrderData(
          ivp_cart: orderId ?? 'NO ORDER ID',
          ivp_ref: widget.customerData.uid ?? '',
          ivp_amount: finalAmount.toStringAsFixed(2),
          ivp_desc: widget.notesController?.text.isNotEmpty == true
              ? widget.notesController?.text ?? "No description provided"
              : "No description provided",
          ivp_currency: TelrConfig.currency,
          ivp_test: TelrConfig.testMode,
        ),
        return_auth: TelrConfig.returnAuthUrl,
        return_can: TelrConfig.returnCanUrl,
        return_decl: TelrConfig.returnDeclUrl,
        bill_fname: widget.customerData.name?.isNotEmpty == true
            ? widget.customerData.name
            : null,
        bill_email: widget.customerData.email?.isNotEmpty == true
            ? widget.customerData.email
            : null,
        bill_addr1: selectedAddress.fullName.isNotEmpty == true
            ? selectedAddress.fullName
            : null,
        bill_country: 'Saudi Arabia',
        bill_zip: selectedAddress.buildingNumber.isNotEmpty == true
            ? selectedAddress.buildingNumber
            : null,
        ivp_lang: 'en',
        bill_custref: widget.customerData.uid,
        bill_city: city,
        bill_phone: widget.customerData.phone,
      );
      final paymentService = TelrPaymentService();
      final response = await paymentService.createPayment(paymentRequest);
      if (response.success && response.paymentUrl != null) {
        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (NavigationRequest request) {
                // Logic moved to _handleNavigation to prevent double execution

                return _handleNavigation(request.url, widget.isFromBooking);
              },
              onPageStarted: (String url) {
                debugPrint('Page started loading: $url');
              },
              onPageFinished: (String url) {
                debugPrint('Page finished loading: $url');
              },
            ),
          )
          ..loadRequest(Uri.parse(response.paymentUrl!));

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        String errorMsg =
            response.errorMessage ?? 'Failed to initialize payment';
        if (response.trace != null) {
          errorMsg += '\nTrace: ${response.trace}';
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = errorMsg;
          });
        }
      }
    } catch (e) {
      debugPrint('Payment initialization error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              '${AppLocalizations.of(context)!.errorInitializingPayment}: $e';
        });
      }
    }
  }

  bool isPaymentProcessed = false;

  void _handleCancelPayment() {
    if (isPaymentProcessed) return;
    isPaymentProcessed = true;

    if (widget.isFromBooking) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PaymentFailedScreen(
            message: AppLocalizations.of(context)!.paymentWasCancelledByUser,
            orderId: orderId ?? 'NO ORDER ID',
            onRetry: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PaymentWebView(
                    customerData: widget.customerData,
                    isFromBooking: widget.isFromBooking,
                    selectedImage: widget.selectedImage,
                    selectedVideo: widget.selectedVideo,
                    selectedDate: widget.selectedDate,
                    timeSlot: widget.timeSlot,
                    service: widget.service,
                    review: widget.review,
                    booking: widget.booking,
                    agent: widget.agent,
                    selectedAddress: widget.selectedAddress,
                    serviceLocation: widget.serviceLocation,
                    notesController: widget.notesController,
                    selectedPayment: widget.selectedPayment,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      Navigator.pop(context);
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.paymentCancelled),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<NavigationDecision> _handleNavigation(
    String url,
    bool isFromBooking,
  ) async {
    final lowerUrl = url.toLowerCase();

    if (lowerUrl.contains('cancel') || lowerUrl.contains('payment/cancelled')) {
      _handleCancelPayment();
      return NavigationDecision.prevent;
    } else if (lowerUrl.contains('declined') ||
        lowerUrl.contains('payment/declined')) {
      if (isPaymentProcessed) {
        return NavigationDecision.prevent;
      }
      isPaymentProcessed = true;

      if (widget.isFromBooking) {
        if (!mounted) return NavigationDecision.prevent;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentFailedScreen(
              message: AppLocalizations.of(context)!.paymentWasDeclined,
              orderId: orderId ?? 'NO ORDER ID',
              onRetry: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => PaymentWebView(
                      customerData: widget.customerData,
                      isFromBooking: widget.isFromBooking,
                      selectedImage: widget.selectedImage,
                      selectedVideo: widget.selectedVideo,
                      selectedDate: widget.selectedDate,
                      timeSlot: widget.timeSlot,
                      service: widget.service,
                      review: widget.review,
                      booking: widget.booking,
                      agent: widget.agent,
                      selectedAddress: widget.selectedAddress,
                      serviceLocation: widget.serviceLocation,
                      notesController: widget.notesController,
                      selectedPayment: widget.selectedPayment,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        Navigator.pop(context);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.paymentDeclined),
            duration: Duration(seconds: 2),
          ),
        );
      }

      return NavigationDecision.prevent;
    } else if ((lowerUrl.contains('success') &&
            !lowerUrl.contains('unsuccessful')) ||
        lowerUrl.contains('payment/success')) {
      if (isPaymentProcessed) {
        return NavigationDecision.prevent;
      }
      isPaymentProcessed = true;

      if (widget.booking == null && !widget.isFromBooking) {
        // Handle the case where there's no booking and not from booking flow
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Home()),
          (Route<dynamic> route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.paymentProcessedSuccessfully,
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ProcessingPaymentPage(
              customerData: widget.customerData,
              isFromBooking: widget.isFromBooking,
              orderId: orderId ?? "",
              selectedImage: widget.selectedImage,
              selectedVideo: widget.selectedVideo,
              selectedDate: widget.selectedDate,
              timeSlot: widget.timeSlot,
              service: widget.service,
              review: widget.review,
              booking: widget.booking,
              agent: widget.agent,
              selectedAddress: widget.selectedAddress,
              serviceLocation: widget.serviceLocation,
              notesController: widget.notesController,
              selectedPayment: widget.selectedPayment,
            ),
          ),
          (Route<dynamic> route) => false,
        );
      }

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(AppLocalizations.of(context)!.thankYouMessage),
      //     duration: Duration(seconds: 2),
      //     backgroundColor: Colors.green,
      //   ),
      // );

      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.payment),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleCancelPayment,
          ),
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Loader(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(AppLocalizations.of(context)!.initializingPayment),
                  ],
                ),
              )
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.paymentError,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: () {
                          if (mounted) {
                            setState(() {
                              _isLoading = true;
                              _errorMessage = null;
                            });
                            _initializePayment();
                          }
                        },
                        child: Text(AppLocalizations.of(context)!.retry),
                      ),
                    ],
                  ),
                ),
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}

// class PaymentScreen extends ConsumerStatefulWidget {
//   final CustomerModel customerData;
//   final bool isFromBooking;
//   File? selectedImage;
//   File? selectedVideo;
//   DateTime? selectedDate;
//   List<Map>? timeSlots;
//   int? selectedTimeCategory;
//   int? selectedTimeSlot;
//   ServiceModel? service;
//   ReviewModel? review;
//   BookingModel? booking;
//   TextEditingController? notesController;

//   PaymentScreen({
//     super.key,
//     this.service,
//     required this.customerData,
//     required this.isFromBooking,
//     this.selectedImage,
//     this.selectedVideo,
//     this.selectedDate,
//     this.timeSlots,
//     this.review,
//     this.selectedTimeCategory,
//     this.selectedTimeSlot,
//     this.notesController,
//     this.booking,
//   });

//   @override
//   ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
// }

// class _PaymentScreenState extends ConsumerState<PaymentScreen> {
//   late WebViewController _controller;
//   bool _isLoading = true;
//   String? _errorMessage;
//   String? selectedPayment;
//   bool isLoading = false;
//   String? selectedImageDownloadUrl;
//   String? selectedVideoDownloadUrl;
//   bool isUploading = false;
//   String? orderId;

//   @override
//   void initState() {
//     super.initState();
//     _checkConfigurationAndInitialize();
//   }

//   Future<bool> saveBooking() async {
//     final CustomerModel customerData = ref.read(customerDataState)!;
//     return await BookingUtils.saveBooking(
//       service: widget.service ?? ServiceModel(),
//       selectedDate: widget.selectedDate!,
//       paymentMode: "Cards",
//       customerData: customerData,
//       notes: widget.notesController?.text.trim() ?? '',
//       timeSlot:
//           widget.timeSlots?[(widget.selectedTimeCategory ??
//               0)]["values"][widget.selectedTimeSlot],
//       selectedImage: widget.selectedImage,
//       selectedVideo: widget.selectedVideo,
//     );
//   }


//   @override
//   Widget build(BuildContext context) {
//     return 
//   }
// }
