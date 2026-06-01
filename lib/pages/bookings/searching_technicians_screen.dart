import 'dart:async';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/services/booking/booking_complete.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:abo_glumbo_bbk/utils/poppins_font.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SearchingTechniciansScreen extends StatefulWidget {
  final String bookingRequestId;

  const SearchingTechniciansScreen({
    super.key,
    required this.bookingRequestId,
  });

  @override
  State<SearchingTechniciansScreen> createState() => _SearchingTechniciansScreenState();
}

class _SearchingTechniciansScreenState extends State<SearchingTechniciansScreen> with SingleTickerProviderStateMixin {
  late String _currentRequestId;
  Timer? _countdownTimer;
  int _secondsRemaining = 120;
  int _elapsedSeconds = 0;
  bool _isSearchingAgain = false;
  bool _isConfirmingSelection = false;
  late AnimationController _pulseController;
  StreamSubscription<DocumentSnapshot>? _requestSubscription;
  Map<String, dynamic>? _bookingRequestData;
  List<dynamic> _acceptedTechnicians = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentRequestId = widget.bookingRequestId;
    LocalStoreHelper.putBookingRequestId(_currentRequestId);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _listenToBookingRequest();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _requestSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _listenToBookingRequest() {
    _requestSubscription?.cancel();
    _requestSubscription = AppFirestore.bookingRequestsCollectionRef
        .doc(_currentRequestId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        if (mounted) {
          setState(() {
            _bookingRequestData = null;
            _acceptedTechnicians = [];
            _isLoading = false;
          });
        }
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final createdAt = data['createdAt'] as Timestamp?;

      if (mounted) {
        setState(() {
          _bookingRequestData = data;
          _acceptedTechnicians = data['acceptedTechnicians'] ?? [];
          _isLoading = false;
        });
        _calculateRemainingTime(createdAt);
      }
    }, onError: (e) {
      debugPrint("Error listening to booking request: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _calculateRemainingTime(Timestamp? createdAt) {
    _countdownTimer?.cancel();
    if (createdAt == null) return;

    final elapsed = DateTime.now().difference(createdAt.toDate()).inSeconds;
    
    if (mounted) {
      setState(() {
        _elapsedSeconds = elapsed;
        _secondsRemaining = (120 - elapsed).clamp(0, 120);
      });
    }

    if (elapsed < 300) {
      _startTimer(createdAt);
    } else {
      _stopBroadcast();
    }
  }

  void _startTimer(Timestamp createdAt) {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(createdAt.toDate()).inSeconds;
      final remaining = (120 - elapsed).clamp(0, 120);

      if (mounted) {
        setState(() {
          _elapsedSeconds = elapsed;
          _secondsRemaining = remaining;
        });
      }

      if (elapsed >= 300) {
        timer.cancel();
        _stopBroadcast();
      }
    });
  }

  void _stopBroadcast() {
    _countdownTimer?.cancel();
    // Do not delete request automatically here so customer can choose to search again.
  }

  Future<void> _searchAgain() async {
    setState(() => _isSearchingAgain = true);
    try {
      final docSnap = await AppFirestore.bookingRequestsCollectionRef.doc(_currentRequestId).get();
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;

        // Delete old request
        await AppFirestore.bookingRequestsCollectionRef.doc(_currentRequestId).delete();

        // Create new request
        final newId = AppFirestore.bookingRequestsCollectionRef.doc().id;
        final newData = Map<String, dynamic>.from(data);
        newData['id'] = newId;
        newData['createdAt'] = Timestamp.now();
        newData['updatedAt'] = Timestamp.now();
        newData['status'] = 'searching';
        newData['acceptedTechnicians'] = [];
        newData['rejectedTechnicians'] = [];

        await AppFirestore.bookingRequestsCollectionRef.doc(newId).set(newData);
        LocalStoreHelper.putBookingRequestId(newId);

        setState(() {
          _currentRequestId = newId;
          _isSearchingAgain = false;
        });

        _listenToBookingRequest();
      }
    } catch (e) {
      debugPrint("Error searching again: $e");
      if (mounted) {
        setState(() => _isSearchingAgain = false);
      }
    }
  }

  Future<void> _cancelBooking() async {
    final String locale = AppLocalizations.of(context)?.localeName ?? 'en';
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          locale == 'ar'
              ? 'إلغاء طلب الحجز؟'
              : locale == 'ur'
              ? 'بکنگ کی درخواست منسوخ کریں؟'
              : 'Cancel Booking Request?',
          style: DMSansFont.textStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          locale == 'ar'
              ? 'هل أنت متأكد أنك تريد الإلغاء؟ سيؤدي هذا إلى إيقاف البحث عن فنيين.'
              : locale == 'ur'
              ? 'کیا آپ واقعی منسوخ کرنا چاہتے ہیں؟ اس سے ٹیکنیشنز کی تلاش رک جائے گی۔'
              : 'Are you sure you want to cancel? This will stop searching for technicians.',
          style: DMSansFont.textStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              locale == 'ar' ? 'لا' : locale == 'ur' ? 'نہیں' : 'No',
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              locale == 'ar' ? 'نعم، إلغاء' : locale == 'ur' ? 'جی ہاں، منسوخ کریں' : 'Yes, Cancel',
            ),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      setState(() => _isLoading = true);
      try {
        await AppFirestore.bookingRequestsCollectionRef.doc(_currentRequestId).delete();
        LocalStoreHelper.clearBookingRequestId();
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint("Error cancelling booking request: $e");
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _selectTechnician(Map<String, dynamic> techData) async {
    setState(() {
      _isConfirmingSelection = true;
    });

    try {
      final docSnap = await AppFirestore.bookingRequestsCollectionRef.doc(_currentRequestId).get();
      if (!docSnap.exists) {
        throw Exception("Booking request no longer exists");
      }

      final request = docSnap.data() as Map<String, dynamic>;
      final serviceMap = request['service'] as Map<String, dynamic>;
      final service = ServiceModel.fromJson(serviceMap);
      
      final customerMap = request['customer'] as Map<String, dynamic>;
      final customer = CustomerModel.fromJson(customerMap);

      final selectedAddressId = request['selectedAddressId'];
      final paymentModeCode = request['paymentModeCode'];
      final notes = request['notes'];
      final issueImage = request['issueImage'];
      final issueVideo = request['issueVideo'];
      final isOnHour = request['isOnHour'];
      final serviceLocation = request['serviceLocation'];
      final bookingDateTime = request['bookingDateTime'] as Timestamp;

      final agent = UserModel(
        uid: techData['uid'],
        name: techData['name'],
        phone: techData['phone'],
        profileUrl: techData['profileUrl'],
        role: "agent",
      );

      final Map<String, dynamic> bookingJson = {
        'id': _currentRequestId,
        'service': service.toJson(),
        'bookingDateTime': bookingDateTime,
        'bookingStatusCode': 'A', // Assigned
        'notes': notes,
        'issueImage': issueImage,
        'issueVideo': issueVideo,
        'customer': customer.toJson(),
        'agent': agent.toJson(),
        'selectedAddressId': selectedAddressId,
        'isOnHour': isOnHour,
        'paymentModeCode': paymentModeCode,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'assignedAt': Timestamp.now(),
        'technicianSelectedAt': Timestamp.now(),
        'paymentCompleted': false,
        'serviceLocation': serviceLocation,
      };

      // Add to bookings collection
      await AppFirestore.bookingsCollectionRef.doc(_currentRequestId).set(bookingJson);

      // Delete from booking_requests
      await AppFirestore.bookingRequestsCollectionRef.doc(_currentRequestId).delete();
      LocalStoreHelper.clearBookingRequestId();

      AddressModel? selectedAddress;
      try {
        if (customer.addresses.isNotEmpty) {
          selectedAddress = customer.addresses.firstWhere(
            (a) => a.id == selectedAddressId,
            orElse: () => customer.addresses.first,
          );
        }
      } catch (e) {
        debugPrint("Error extracting selected address: $e");
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => BookingCompletedPage(
              service: service,
              worker: agent,
              selectedDate: bookingDateTime.toDate(),
              selectedTime: {"label": "Confirmed", "time": TimeOfDay.fromDateTime(bookingDateTime.toDate())},
              address: selectedAddress,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Error confirming selection: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConfirmingSelection = false;
        });
      }
    }
  }

  Widget _buildChooseHeaderSection() {
    final remainingSelectionTime = (300 - _elapsedSeconds).clamp(0, 300);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.shade50,
                ),
                child: Icon(Icons.people_alt_rounded, color: Colors.amber.shade700, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.localeName == 'ar'
                          ? 'اختر الفني الخاص بك'
                          : AppLocalizations.of(context)?.localeName == 'ur'
                          ? 'اپنے ٹیکنیشن کا انتخاب کریں'
                          : "Choose your technician",
                      style: PoppinsFont.textStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)?.localeName == 'ar'
                          ? 'الرجاء اختيار أحد الفنيين المقبولين أدناه للمتابعة.'
                          : AppLocalizations.of(context)?.localeName == 'ur'
                          ? 'براہ کرم جاری رکھنے کے لیے نیچے قبول شدہ ٹیکنیشنز میں سے ایک کا انتخاب کریں۔'
                          : "Please select one of the accepted technicians below to continue.",
                      style: DMSansFont.textStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)?.localeName == 'ar'
                    ? 'ينتهي الطلب خلال:'
                    : AppLocalizations.of(context)?.localeName == 'ur'
                    ? 'درخواست کی میعاد ختم ہو جائے گی:'
                    : "Request expires in:",
                style: DMSansFont.textStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                "${remainingSelectionTime}s",
                style: PoppinsFont.textStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: remainingSelectionTime <= 30 ? Colors.red : AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bgBlueTint,
        body: Center(child: Loader()),
      );
    }

    final bool showSearchingHeader = _elapsedSeconds < 120;
    final bool showChooseHeader = _elapsedSeconds >= 120 && _elapsedSeconds < 300 && _acceptedTechnicians.isNotEmpty;
    final bool showExpiredScreen = _elapsedSeconds >= 300 || (_elapsedSeconds >= 120 && _acceptedTechnicians.isEmpty);

    final String locale = AppLocalizations.of(context)?.localeName ?? 'en';

    return Scaffold(
      backgroundColor: AppColors.bgBlueTint,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black),
          onPressed: _cancelBooking,
        ),
        title: Text(
          locale == 'ar'
              ? 'البحث عن فنيين'
              : locale == 'ur'
              ? 'ٹیکنیشنز کی تلاش'
              : "Searching for Technicians",
          style: DMSansFont.textStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (showSearchingHeader) ...[
              _buildPulsingSearchSection(primaryColor),
              _buildProgressCircle(),
            ] else if (showChooseHeader) ...[
              _buildChooseHeaderSection(),
            ] else if (showExpiredScreen) ...[
              _buildExpiredSection(),
            ],
            
            if (!showExpiredScreen)
              Expanded(
                child: _buildTechniciansListSection(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingSearchSection(Color primaryColor) {
    final String locale = AppLocalizations.of(context)?.localeName ?? 'en';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.1 + (0.15 * _pulseController.value)),
                ),
                child: Icon(Icons.radar_rounded, color: primaryColor, size: 28),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale == 'ar'
                      ? 'جاري البحث عن فنيين بالقرب منك...'
                      : locale == 'ur'
                      ? 'قریبی ٹیکنیشنز تلاش کیے جا رہے ہیں...'
                      : "Looking for nearby technicians...",
                  style: PoppinsFont.textStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  locale == 'ar'
                      ? 'الرجاء الانتظار، لدى الفنيين المؤهلين 120 ثانية للقبول.'
                      : locale == 'ur'
                      ? 'براہ کرم انتظار کریں، اہل ٹیکنیشنز کے پاس قبول کرنے کے لیے 120 سیکنڈز ہیں۔'
                      : "Please wait, eligible technicians have 120s to accept.",
                  style: DMSansFont.textStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCircle() {
    final String locale = AppLocalizations.of(context)?.localeName ?? 'en';
    final progress = _secondsRemaining / 120.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: Colors.grey.shade200,
              color: _secondsRemaining <= 20 ? Colors.red : AppColors.primary,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${_secondsRemaining}s",
                style: PoppinsFont.textStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _secondsRemaining <= 20 ? Colors.red : Colors.black,
                ),
              ),
              Text(
                locale == 'ar' ? 'متبقي' : locale == 'ur' ? 'باقی' : "Remaining",
                style: DMSansFont.textStyle(
                  fontSize: 9,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredSection() {
    final String locale = AppLocalizations.of(context)?.localeName ?? 'en';
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.shade50,
            ),
            child: Icon(Icons.timer_off_outlined, color: Colors.red.shade600, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            locale == 'ar'
                ? 'لم يقبل أي فني'
                : locale == 'ur'
                ? 'کسی ٹیکنیشن نے قبول نہیں کیا'
                : "No Technicians Accepted",
            style: PoppinsFont.textStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            locale == 'ar'
                ? 'جميع الفنيين مشغولون حالياً أو لم يقبلوا في الوقت المحدد.'
                : locale == 'ur'
                ? 'تمام ٹیکنیشنز اس وقت مصروف ہیں یا انہوں نے وقت پر قبول نہیں کیا۔'
                : "All technicians are currently busy or didn't accept in time.",
            textAlign: TextAlign.center,
            style: DMSansFont.textStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSearchingAgain ? null : _searchAgain,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSearchingAgain
                ? const Loader(color: Colors.white)
                : Text(
                    locale == 'ar'
                        ? 'البحث مرة أخرى'
                        : locale == 'ur'
                        ? 'دوبارہ تلاش کریں'
                        : "Search Again",
                    style: DMSansFont.textStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechniciansListSection() {
    final String locale = AppLocalizations.of(context)?.localeName ?? 'en';
    if (_acceptedTechnicians.isEmpty) {
      if (_secondsRemaining > 0) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text(
                locale == 'ar'
                    ? 'بانتظار قبول الفنيين...'
                    : locale == 'ur'
                    ? 'ٹیکنیشنز کے قبول کرنے کا انتظار ہے...'
                    : "Waiting for technicians to accept...",
                style: DMSansFont.textStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      } else {
        return const SizedBox.shrink();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            locale == 'ar'
                ? 'الفنيون المقبولون (${_acceptedTechnicians.length})'
                : locale == 'ur'
                ? 'قبول شدہ ٹیکنیشنز (${_acceptedTechnicians.length})'
                : "Accepted Technicians (${_acceptedTechnicians.length})",
            style: PoppinsFont.textStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: _acceptedTechnicians.length,
            itemBuilder: (context, index) {
              final tech = _acceptedTechnicians[index] as Map<String, dynamic>;
              return _buildTechnicianCard(tech);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicianCard(Map<String, dynamic> tech) {
    final String locale = AppLocalizations.of(context)?.localeName ?? 'en';
    final profileUrl = tech['profileUrl'] as String?;
    final rating = (tech['rating'] as num?)?.toDouble() ?? 5.0;
    final completedJobs = (tech['completedJobs'] as num?)?.toInt() ?? 0;
    final distance = tech['distance'] as num?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey.shade100,
              backgroundImage: (profileUrl != null && profileUrl.isNotEmpty)
                  ? NetworkImage(profileUrl)
                  : null,
              child: (profileUrl == null || profileUrl.isEmpty)
                  ? const Icon(Icons.person, color: Colors.grey, size: 28)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tech['name'] ?? "Technician",
                    style: PoppinsFont.textStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: DMSansFont.textStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        locale == 'ar'
                            ? '•   $completedJobs وظيفة'
                            : locale == 'ur'
                            ? '•   $completedJobs کام'
                            : "•   $completedJobs jobs",
                        style: DMSansFont.textStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (distance != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          locale == 'ar'
                              ? '•   على بعد ${distance.toStringAsFixed(1)} كم'
                              : locale == 'ur'
                              ? '•   ${distance.toStringAsFixed(1)} کلومیٹر دور'
                              : "•   ${distance.toStringAsFixed(1)} km away",
                          style: DMSansFont.textStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isConfirmingSelection ? null : () => _selectTechnician(tech),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(80, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: _isConfirmingSelection
                  ? const Loader(color: Colors.white, size: 16)
                  : Text(
                      locale == 'ar' ? 'اختيار' : locale == 'ur' ? 'منتخب کریں' : "Choose",
                      style: DMSansFont.textStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
