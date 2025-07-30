import 'dart:io';
import 'package:abo_glumbo_bbk/apis/telr_services.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/telr/request_model.dart';
import 'package:abo_glumbo_bbk/pages/bookings/booking_success.dart';
import 'package:abo_glumbo_bbk/pages/bookings/payment_failed.dart';
import 'package:abo_glumbo_bbk/services/booking/save_booking.dart';
import 'package:abo_glumbo_bbk/services/telr_config.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebView extends StatefulWidget {
  final CustomerModel customerData;
  final bool isFromBooking;
  File? selectedImage;
  File? selectedVideo;
  DateTime? selectedDate;
  List<Map>? timeSlots;
  int? selectedTimeCategory;
  int? selectedTimeSlot;
  ServiceModel? service;
  ReviewModel? review;
  BookingModel? booking;
  TextEditingController? notesController;
  PaymentWebView({
    super.key,
    this.service,
    required this.customerData,
    required this.isFromBooking,
    this.selectedImage,
    this.selectedVideo,
    this.selectedDate,
    this.timeSlots,
    this.review,
    this.selectedTimeCategory,
    this.selectedTimeSlot,
    this.notesController,
    this.booking,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  String? selectedPayment;
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

  Future<bool> saveBooking() async {
    return await BookingUtils.saveBooking(
      service: widget.service ?? ServiceModel(),
      selectedDate: widget.selectedDate!,
      paymentMode: "Cards",
      customerData: widget.customerData,
      notes: widget.notesController?.text.trim() ?? '',
      timeSlot:
          widget.timeSlots?[(widget.selectedTimeCategory ??
              0)]["values"][widget.selectedTimeSlot],
      selectedImage: widget.selectedImage,
      selectedVideo: widget.selectedVideo,
    );
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

    orderId = generateOrderId(
      widget.customerData.uid ?? '',
      widget.isFromBooking
          ? double.tryParse(widget.service?.price.toString() ?? '0.00') ?? 0.00
          : widget.review?.tipAmount ?? 0.00,
    );

    try {
      final paymentRequest = TelrPaymentRequest(
        ivp_store: TelrConfig.storeId,
        ivp_authkey: TelrConfig.authKey,
        ivp_order: OrderData(
          ivp_cart: orderId ?? 'NO ORDER ID',
          ivp_ref: widget.customerData.uid ?? '',
          ivp_amount: widget.isFromBooking
              ? double.tryParse(
                      widget.service?.price.toString() ?? '0.00',
                    )?.toStringAsFixed(2) ??
                    '0.00'
              : widget.review?.tipAmount?.toStringAsFixed(2) ?? '0.00',
          ivp_desc: widget.notesController?.text.isNotEmpty == true
              ? widget.notesController?.text ?? "No description provided"
              : "No description provided",
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
        bill_addr1: selectedAddress.streetName?.isNotEmpty == true
            ? selectedAddress.streetName
            : null,
        bill_country: widget.customerData.country?.isNotEmpty == true
            ? widget.customerData.country
            : null,
        bill_zip: selectedAddress.buildingNumber.isNotEmpty == true
            ? selectedAddress.buildingNumber
            : null,
        ivp_lang: 'en',
        bill_custref: widget.customerData.uid,
      );
      final paymentService = TelrPaymentService();
      final response = await paymentService.createPayment(paymentRequest);
      if (response.success && response.paymentUrl != null) {
        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (NavigationRequest request) {
                return _handleNavigation(request.url);
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

  NavigationDecision _handleNavigation(String url) {
    if (url.contains('success') || url.contains('payment/success')) {
      if (widget.isFromBooking) {
        saveBooking();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                BookingSuccessPage(orderId: orderId ?? 'NO ORDER ID'),
          ),
        );
      } else {
        BookingUtils.saveReview(
          booking: widget.booking!,
          review: widget.review,
        );
        Navigator.pop(context);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.reviewSubmitted),
            duration: Duration(seconds: 2),
          ),
        );
      }

      return NavigationDecision.prevent;
    } else if (url.contains('cancel') || url.contains('payment/cancelled')) {
      if (widget.isFromBooking) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentFailedScreen(
              message: AppLocalizations.of(context)!.paymentWasCancelledByUser,
              orderId: orderId ?? 'NO ORDER ID',
            ),
          ),
        );
      } else {
        Navigator.pop(context);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.paymentCancelled),
            duration: Duration(seconds: 2),
          ),
        );
      }

      return NavigationDecision.prevent;
    } else if (url.contains('declined') || url.contains('payment/declined')) {
      if (widget.isFromBooking) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentFailedScreen(
              message: AppLocalizations.of(context)!.paymentWasDeclined,
              orderId: orderId ?? 'NO ORDER ID',
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
    }
    return NavigationDecision.navigate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.payment),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
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
