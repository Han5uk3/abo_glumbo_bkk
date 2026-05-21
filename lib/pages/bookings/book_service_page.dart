import 'dart:io';
import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/bookings/worker_list.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/pages/bookings/add_image_booking.dart';
import 'package:abo_glumbo_bbk/pages/bookings/bloc/address_bloc.dart';
import 'package:abo_glumbo_bbk/services/address_services.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:abo_glumbo_bbk/sheets/save_address_sheet.dart';
import 'package:abo_glumbo_bbk/services/location_matcher_service.dart';
import 'package:abo_glumbo_bbk/services/location_service.dart';
import 'package:abo_glumbo_bbk/models/address_result.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/pages/bookings/widgets/rebook_wait_widget.dart';

import 'package:abo_glumbo_bbk/services/booking/save_booking.dart';
import 'package:abo_glumbo_bbk/services/booking/booking_complete.dart';

class BookServicePage extends StatefulWidget {
  final ServiceModel service;
  final UserModel? rebookTechnician;
  const BookServicePage({super.key, required this.service, this.rebookTechnician});

  @override
  State<BookServicePage> createState() => _BookServicePageState();
}

class _BookServicePageState extends State<BookServicePage> {
  final ValueNotifier<int?> selectedIndexNotifier = ValueNotifier<int?>(null);
  UserModel selectedWorker = UserModel(uid: "", role: "agent");
  int currentStep =
      0; // 0: Schedule, 1: Details, 2: Expert/Auto-assign, 3: Review & Confirm

  bool isServiceNow = true;

  DateTime? selectedDate;
  bool saving = false;
  bool _rebookFailed = false;
  String? broadcastRequestId;
  AddressModel? selectedAddress;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController notesController = TextEditingController();
  int selectedTimeCategory = -1;
  int selectedTimeSlot = -1;
  String? addressValidationError;
  bool isValidatingAddress = false;
  MatchedServiceZone? _matchedServiceZone;
  Map<String, dynamic> _initialPosition = {
    "lon": 0.0,
    "lat": 0.0,
    "userLocation": "",
  };

  List<Map> timeSlots = [
    {
      "label": "Morning",
      "values": [
        {"label": "09:00 AM", "time": const TimeOfDay(hour: 9, minute: 0)},
        {"label": "09:30 AM", "time": const TimeOfDay(hour: 9, minute: 30)},
        {"label": "10:00 AM", "time": const TimeOfDay(hour: 10, minute: 0)},
        {"label": "10:30 AM", "time": const TimeOfDay(hour: 10, minute: 30)},
        {"label": "11:00 AM", "time": const TimeOfDay(hour: 11, minute: 0)},
        {"label": "11:30 AM", "time": const TimeOfDay(hour: 11, minute: 30)},
      ],
    },
    {
      "label": "After noon",
      "values": [
        {"label": "12:00 PM", "time": const TimeOfDay(hour: 12, minute: 0)},
        {"label": "12:30 PM", "time": const TimeOfDay(hour: 12, minute: 30)},
        {"label": "01:00 PM", "time": const TimeOfDay(hour: 13, minute: 0)},
        {"label": "01:30 PM", "time": const TimeOfDay(hour: 13, minute: 30)},
        {"label": "02:00 PM", "time": const TimeOfDay(hour: 14, minute: 0)},
        {"label": "02:30 PM", "time": const TimeOfDay(hour: 14, minute: 30)},
      ],
    },
    {
      "label": "Evening",
      "values": [
        {"label": "03:00 PM", "time": const TimeOfDay(hour: 15, minute: 0)},
        {"label": "03:30 PM", "time": const TimeOfDay(hour: 15, minute: 30)},
        {"label": "04:00 PM", "time": const TimeOfDay(hour: 16, minute: 0)},
        {"label": "04:30 PM", "time": const TimeOfDay(hour: 16, minute: 30)},
        {"label": "05:00 PM", "time": const TimeOfDay(hour: 17, minute: 0)},
        {"label": "05:30 PM", "time": const TimeOfDay(hour: 17, minute: 30)},
      ],
    },
    {
      "label": "Night",
      "values": [
        {"label": "06:00 PM", "time": const TimeOfDay(hour: 18, minute: 0)},
        {"label": "06:30 PM", "time": const TimeOfDay(hour: 18, minute: 30)},
        {"label": "07:00 PM", "time": const TimeOfDay(hour: 19, minute: 0)},
        {"label": "07:30 PM", "time": const TimeOfDay(hour: 19, minute: 30)},
        {"label": "08:00 PM", "time": const TimeOfDay(hour: 20, minute: 0)},
        {"label": "08:30 PM", "time": const TimeOfDay(hour: 20, minute: 30)},
        {"label": "09:00 PM", "time": const TimeOfDay(hour: 21, minute: 0)},
        {"label": "09:30 PM", "time": const TimeOfDay(hour: 21, minute: 30)},
        {"label": "10:00 PM", "time": const TimeOfDay(hour: 22, minute: 0)},
        {"label": "10:30 PM", "time": const TimeOfDay(hour: 22, minute: 30)},
        {"label": "11:00 PM", "time": const TimeOfDay(hour: 23, minute: 0)},
        {"label": "11:30 PM", "time": const TimeOfDay(hour: 23, minute: 30)},
        {"label": "12:00 AM", "time": const TimeOfDay(hour: 0, minute: 0)},
        {"label": "12:30 AM", "time": const TimeOfDay(hour: 0, minute: 30)},
      ],
    },
  ];

  File? _selectedImage;
  File? _selectedVideo;
  CustomerModel? customerData;
  Stream<CustomerModel>? _customerStream;

  @override
  void initState() {
    super.initState();
    if (widget.rebookTechnician != null) {
      selectedWorker = widget.rebookTechnician!;
    }
    _fetchCoordinates();
    fetchCustomerAddresses();
    _customerStream = AppServices.listenToCustomerData(
      LocalStoreHelper.getUID() ?? '',
    );
  }

  @override
  void dispose() {
    selectedIndexNotifier.dispose();
    notesController.dispose();
    super.dispose();
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = R * c;
    return distance;
  }

  Future<void> fetchCustomerAddresses() async {
    try {
      selectedAddress = await AppServices.getCustomerSelectedAddress();
      if (selectedAddress != null) {
        _validateSelectedAddress(selectedAddress!);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error fetching addresses: $e");
    }
  }

  Future<void> _fetchCoordinates() async {
    try {
      final coordinates = await LocationService().getUserCoordinates();
      if (mounted) {
        setState(() {
          _initialPosition = coordinates;
        });
      }
    } catch (error) {
      debugPrint("Error fetching coordinates: $error");
    }
  }

  Future<void> _validateSelectedAddress(AddressModel address) async {
    if (address.lat == null || address.lon == null) {
      if (mounted) {
        setState(() {
          addressValidationError = "Invalid address: Missing coordinates";
          _matchedServiceZone = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        isValidatingAddress = true;
        addressValidationError = null;
        _matchedServiceZone = null;
      });
    }

    try {
      // Check Service Area using polygon-based point-in-polygon (PIP)
      debugPrint("🔍 Checking polygon service area for ${address.fullName}");
      final serviceLocationsQuery = await AppFirestore.locationsCollectionRef
          .where('service_id', isEqualTo: widget.service.id)
          .get();

      if (serviceLocationsQuery.docs.isEmpty) {
        // No service areas defined at all for this service — block by default
        if (mounted) {
          setState(() {
            isValidatingAddress = false;
            addressValidationError =
                AppLocalizations.of(context)?.serviceAreaNotConfigured ??
                "Service unavailable: No service areas are set currently";
            _matchedServiceZone = null;
          });
        }
        return;
      }

      final data =
          serviceLocationsQuery.docs.first.data() as Map<String, dynamic>;
      final locations = data['locations'] as List<dynamic>? ?? [];

      if (locations.isEmpty) {
        if (mounted) {
          setState(() {
            isValidatingAddress = false;
            addressValidationError =
                AppLocalizations.of(context)?.noActiveServiceZones ??
                "Service unavailable: No active service zones defined";
            _matchedServiceZone = null;
          });
        }
        return;
      }

      final matched = LocationMatcherService.getMatchedServiceZone(
        customerLat: address.lat!,
        customerLon: address.lon!,
        serviceLocations: locations,
      );

      if (matched == null && mounted) {
        setState(() {
          isValidatingAddress = false;
          addressValidationError =
              AppLocalizations.of(context)?.serviceUnavailableLongMessage ??
              "Service unavailable to this location currently";
          _matchedServiceZone = null;
        });
        return;
      }

      // Found a matching polygon zone — allow booking
      if (mounted) {
        setState(() {
          isValidatingAddress = false;
          addressValidationError = null;
          _matchedServiceZone = matched;
        });
        debugPrint(
          "✅ Matched zone: ${matched?.nameEn} (priority ${matched?.priority})",
        );
      }
    } catch (e) {
      debugPrint("❌ Error validating address: $e");
      if (mounted) {
        setState(() {
          isValidatingAddress = false;
          addressValidationError =
              AppLocalizations.of(context)?.failedToValidateServiceArea ??
              "Failed to validate service area";
          _matchedServiceZone = null;
        });
      }
    }
  }

  DateTime _getMiddleEastNow() {
    return DateTime.now();
  }

  void _onDaySelect(DateTime day, DateTime focusedDay) {
    setState(() {
      selectedDate = day;
      selectedTimeCategory = -1;
      selectedTimeSlot = -1;
    });
  }

  bool _isTimeSlotPast(int categoryIndex, int slotIndex) {
    if (selectedDate == null ||
        categoryIndex == -1 ||
        slotIndex == -1 ||
        categoryIndex >= timeSlots.length) {
      return false;
    }

    final nowInME = _getMiddleEastNow();
    final selectedDateOnly = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
    );
    final todayOnly = DateTime(nowInME.year, nowInME.month, nowInME.day);

    if (selectedDateOnly.isBefore(todayOnly)) return true;
    if (selectedDateOnly.isAfter(todayOnly)) return false;

    final timeOfDay =
        timeSlots[categoryIndex]["values"][slotIndex]["time"] as TimeOfDay;
    DateTime selectedDateTime = DateTime(
      nowInME.year,
      nowInME.month,
      nowInME.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );

    // If it's a late night slot (e.g., 12:00 AM, 12:30 AM), it technically belongs to the next day
    if (timeOfDay.hour < 5) {
      selectedDateTime = selectedDateTime.add(const Duration(days: 1));
    }

    return selectedDateTime.isBefore(nowInME);
  }

  bool _isTimeCategoryDisabled(int categoryIndex) {
    if (selectedDate == null) return false;

    final nowInME = _getMiddleEastNow();
    final selectedDateOnly = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
    );
    final todayOnly = DateTime(nowInME.year, nowInME.month, nowInME.day);

    if (selectedDateOnly.isBefore(todayOnly)) return true;
    if (selectedDateOnly.isAfter(todayOnly)) return false;

    final timeSlotsList = timeSlots[categoryIndex]["values"] as List<Map>;
    for (int i = 0; i < timeSlotsList.length; i++) {
      if (!_isTimeSlotPast(categoryIndex, i)) return false;
    }
    return true;
  }

  Future<void> _showAddressSheet(
    BuildContext context, {
    bool isChangingAddress = false,
  }) async {
    final result = await showModalBottomSheet<AddressSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => AddressSaveSheet(
        initialPosition: _initialPosition,
        isChangingAddress: isChangingAddress,
      ),
    );

    await fetchCustomerAddresses();

    if (result != null) {
      if (result.needsAddressSelection) {
        setState(() {
          selectedAddress = null;
        });
        return;
      }

      final selected = result.selectedAddress;
      if (selected != null) {
        setState(() {
          selectedAddress = selected;
        });
        _validateSelectedAddress(selected);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CustomerModel>(
      stream: _customerStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          customerData = snapshot.data;
        }
        return Scaffold(
          backgroundColor: AppColors.bgBlueTint,
          appBar: AppBar(
            backgroundColor: AppColors.bgBlueTint,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.black,
                size: 20,
              ),
              onPressed: () {
                if (currentStep > 0) {
                  setState(() => currentStep--);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Text(
              _getTitle(context),
              style: DMSansFont.textStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              _buildStepProgressBar(),
              Expanded(
                child: currentStep == 0
                    ? _buildFirstStepContent()
                    : currentStep == 1
                    ? _buildSecondStepContent()
                    : currentStep == 2
                    ? _buildThirdStepContent()
                    : _buildReviewStepContent(),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(context),
        );
      },
    );
  }

  String _getTitle(BuildContext context) {
    return AppLocalizations.of(context)!.bookservice;
  }

  Widget _buildStepProgressBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.bgBlueTint,
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.04), width: 1),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildStepItem(
                0,
                Icons.calendar_today_rounded,
                AppLocalizations.of(context)?.placeAndTiming ??
                    'Place and timing',
              ),
            ),
            Expanded(
              child: _buildStepItem(
                1,
                Icons.assignment_rounded,
                AppLocalizations.of(context)?.details ?? 'Details',
              ),
            ),
            Expanded(
              child: _buildStepItem(
                2,
                Icons.person_rounded,
                AppLocalizations.of(context)?.chooseYourTechnician ?? 'Expert',
              ),
            ),
            Expanded(
              child: _buildStepItem(
                3,
                Icons.checklist_rounded,
                AppLocalizations.of(context)?.reviewAndConfirm ?? 'Review',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(int step, IconData icon, String label) {
    bool isActive = currentStep >= step;
    bool isCurrent = currentStep == step;
    bool isCompleted = currentStep > step;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Connector Line
        Positioned(
          top: 14,
          left: 0,
          right: 0,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 2,
                  color: step == 0
                      ? Colors.transparent
                      : (isActive ? AppColors.primary : Colors.grey[200]!),
                ),
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: step == 3
                      ? Colors.transparent
                      : (isCompleted ? AppColors.primary : Colors.grey[200]!),
                ),
              ),
            ],
          ),
        ),
        // Step Content
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.primary
                    : isCurrent
                    ? Colors.white
                    : Colors.grey[100],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted
                      ? AppColors.primary
                      : isCurrent
                      ? AppColors.primary
                      : Colors.grey[300]!,
                  width: 2,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isCompleted ? Icons.check : icon,
                    key: ValueKey(isCompleted ? 'check' : 'icon'),
                    size: 14,
                    color: isCompleted
                        ? Colors.white
                        : isCurrent
                        ? AppColors.primary
                        : Colors.grey[400],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DMSansFont.textStyle(
                fontSize: 10,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                color: isCurrent
                    ? AppColors.primary
                    : isCompleted
                    ? AppColors.primary.withOpacity(0.8)
                    : Colors.grey[500],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFirstStepContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            AppLocalizations.of(context)?.selectLocation ?? 'Select Location',
            style: DMSansFont.textStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildAddressSelectionWidget(),
        if (addressValidationError != null)
          _buildErrorWidget(addressValidationError!),
        if (isValidatingAddress)
          _buildLoadingWidget(
            AppLocalizations.of(context)?.checkingServiceAvailability ??
                "Checking service availability...",
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            AppLocalizations.of(context)?.bookingType ?? 'Booking Type',
            style: DMSansFont.textStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildBookingTypeSelector(),

        if (!isServiceNow) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text(
              AppLocalizations.of(context)?.date ?? 'Select Date',
              style: DMSansFont.textStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
            ],
          ),
          child: TableCalendar(
            locale: AppLocalizations.of(context)?.localeName,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: DMSansFont.textStyle(fontWeight: FontWeight.bold),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: DMSansFont.textStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
              weekendStyle: DMSansFont.textStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
                shape: BoxShape.rectangle,
              ),
              todayDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary, width: 1.5),
                shape: BoxShape.rectangle,
              ),
              defaultDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              weekendDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              holidayDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              outsideDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              disabledDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              todayTextStyle: DMSansFont.textStyle(color: AppColors.primary),
            ),
            selectedDayPredicate: (day) => isSameDay(day, selectedDate),
            focusedDay: selectedDate ?? DateTime.now(),
            firstDay: DateTime.now(),
            lastDay: DateTime.utc(2050, 01, 16),
            onDaySelected: _onDaySelect,
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            AppLocalizations.of(context)?.time ?? 'Available Slots',
            style: DMSansFont.textStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildTimeCategories(),
        SizedBox(height: 16),
        Divider(
          color: Colors.grey.shade300,
          thickness: 1,
          indent: 16,
          endIndent: 16,
        ),
        if (selectedTimeCategory != -1) _buildTimeSlots(),
        ],
        if (isServiceNow ||
            (selectedDate != null &&
                selectedTimeCategory != -1 &&
                selectedTimeSlot != -1))
          _buildInspectionFeeInfo(),
      ],
    );
  }

  Widget _buildBookingTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() {
                isServiceNow = true;
                selectedDate = null;
                selectedTimeCategory = -1;
                selectedTimeSlot = -1;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isServiceNow ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isServiceNow ? AppColors.primary : Colors.grey[300]!,
                  ),
                ),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)?.serviceNow ?? 'Service Now',
                    style: DMSansFont.textStyle(
                      color: isServiceNow ? Colors.white : Colors.black87,
                      fontWeight: isServiceNow ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => setState(() {
                isServiceNow = false;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isServiceNow ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: !isServiceNow ? AppColors.primary : Colors.grey[300]!,
                  ),
                ),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)?.serviceForLater ?? 'Service for Later',
                    style: DMSansFont.textStyle(
                      color: !isServiceNow ? Colors.white : Colors.black87,
                      fontWeight: !isServiceNow ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionFeeInfo() {
    final isOnHour = _isInspectionFeeOnHour();
    final price = _getSelectedPrice();
    final hasDiscount = (widget.service.discountPercentage ?? 0) > 0;
    final discountedPrice = widget.service.getDiscountedPrice(price);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOnHour
                ? Colors.green.shade200
                : Colors.orange.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isOnHour ? Colors.green : Colors.orange).withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // On-hour / Off-hour tag
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isOnHour
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOnHour
                          ? Colors.green.shade300
                          : Colors.orange.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOnHour
                            ? Icons.schedule_rounded
                            : Icons.nightlight_round,
                        size: 14,
                        color: isOnHour
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnHour
                            ? (AppLocalizations.of(context)?.onHourBooking ??
                                'On-Hour')
                            : (AppLocalizations.of(context)?.offHourBooking ??
                                'Off-Hour'),
                        style: DMSansFont.textStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isOnHour
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Inspection Fee row
            Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.of(context)?.inspectionFee ??
                      'Inspection Fee',
                  style: DMSansFont.textStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasDiscount)
                      Text(
                        '${price.toStringAsFixed(2)} ${AppLocalizations.of(context)?.sar ?? "SAR"}',
                        style: DMSansFont.textStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Text(
                      '${(hasDiscount ? discountedPrice : price).toStringAsFixed(2)} ${AppLocalizations.of(context)?.sar ?? "SAR"}',
                      style: DMSansFont.textStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.green1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Disclaimer note
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bgBlueTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)?.inspectionFeeNote(
                            (hasDiscount ? discountedPrice : price)
                                .toStringAsFixed(2),
                          ) ??
                          'Inspection fee: ${(hasDiscount ? discountedPrice : price).toStringAsFixed(2)} SAR — paid only after the technician arrives and inspects the issue.',
                      style: DMSansFont.textStyle(
                        fontSize: 11,
                        color: AppColors.secondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCategories() {
    return SizedBox(
      height: 35,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: timeSlots.length,
        itemBuilder: (context, index) {
          final isDisabled = _isTimeCategoryDisabled(index);
          final isSelected = selectedTimeCategory == index;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: isDisabled
                  ? null
                  : () {
                      setState(() {
                        selectedTimeCategory = index;
                        selectedTimeSlot = -1;
                      });
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey[300]!,
                  ),
                ),
                child: Center(
                  child: Text(
                    _getLocalizedTimeCategory(timeSlots[index]["label"]),
                    style: DMSansFont.textStyle(
                      color: isSelected
                          ? Colors.white
                          : isDisabled
                          ? Colors.grey
                          : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSlots() {
    final currentSlots =
        (timeSlots[selectedTimeCategory]["values"] as List<Map>);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(currentSlots.length, (i) {
          final isPast = _isTimeSlotPast(selectedTimeCategory, i);
          final isSelected = selectedTimeSlot == i;

          return InkWell(
            onTap: isPast ? null : () => setState(() => selectedTimeSlot = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: (MediaQuery.of(context).size.width - 62) / 4,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : isPast
                    ? Colors.grey[100]
                    : AppColors.bgWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  "${currentSlots[i]["label"].toString().substring(0, 5)} ${_getLocalizedTimeSlots(currentSlots[i]["label"])}",
                  style: DMSansFont.textStyle(
                    color: isSelected
                        ? AppColors.primary
                        : isPast
                        ? Colors.grey
                        : Colors.black87,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSecondStepContent() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            AppLocalizations.of(context)!.details,
            style: DMSansFont.textStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.problemDescription,
            style: DMSansFont.textStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: notesController,
            maxLines: 5,
            style: TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintStyle: TextStyle(fontSize: 14),
              hintText: AppLocalizations.of(context)!.problemDescriptionHint,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
            ),
          ),
          const SizedBox(height: 24),
          BlocProvider(
            create: (context) =>
                AddressBloc(AppServicesAddressRepository())
                  ..add(LoadAddresses()),
            child: AddIssueImageAndVideo(
              showAddressPicker: false,
              onImageSelected: (value) =>
                  setState(() => _selectedImage = value),
              onVideoSelected: (value) =>
                  setState(() => _selectedVideo = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThirdStepContent() {
    if (widget.rebookTechnician != null && !_rebookFailed) {
      return RebookWaitWidget(
        technician: widget.rebookTechnician!,
        service: widget.service,
        selectedAddress: selectedAddress!,
        selectedDate: isServiceNow ? _getMiddleEastNow() : selectedDate!,
        timeSlot: isServiceNow
            ? {"label": "Now", "time": TimeOfDay.now()}
            : timeSlots[selectedTimeCategory]["values"][selectedTimeSlot],
        notes: notesController.text,
        issueImageFile: _selectedImage,
        issueVideoFile: _selectedVideo,
        onAccepted: (worker) {
          setState(() {
            selectedWorker = worker;
            currentStep = 3;
          });
        },
        onBroadcastIdCreated: (id) {
          setState(() {
            broadcastRequestId = id;
          });
        },
        onFailed: () {
          setState(() {
            _rebookFailed = true;
          });
        },
      );
    }
    if (!_shouldShowTechnicianSelection()) {
      return _buildAutoAssignContent();
    }
    return WorkerList(
        service: widget.service,
        category: widget.service.category ?? "",
        selectedAddress: selectedAddress,
        selectedIndexNotifier: selectedIndexNotifier,
        onWorkerSelected: (worker) {
          setState(() {
            selectedWorker = worker;
          });
        },
        onBroadcastIdCreated: (id) {
          setState(() {
            broadcastRequestId = id;
          });
        },
        selectedDate: isServiceNow ? _getMiddleEastNow() : selectedDate!,
        timeSlot: isServiceNow
            ? {"label": "Now", "time": TimeOfDay.now()}
            : timeSlots[selectedTimeCategory]["values"][selectedTimeSlot],
        isOnHour: _shouldShowTechnicianSelection(),
        notes: notesController.text,
        issueImageFile: _selectedImage,
        issueVideoFile: _selectedVideo,
      );
  }

  Widget _buildAutoAssignContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "A technician will be automatically assigned before the appointment based on availability.",
              textAlign: TextAlign.center,
              style: DMSansFont.textStyle(
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue.shade700,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)?.autoAssignMessage ??
                          'Since this is an off-hour booking, we will assign a technician to your booking atleast 3 hours before your booking time.',
                      style: DMSansFont.textStyle(
                        fontSize: 14,
                        color: Colors.blue.shade800,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStepContent() {
    final isAssignmentOnHour = _shouldShowTechnicianSelection();
    final price = _getSelectedPrice();
    final hasDiscount = (widget.service.discountPercentage ?? 0) > 0;
    final discountedPrice = widget.service.getDiscountedPrice(price);
    final languageCode = AppLocalizations.of(context)?.localeName ?? 'en';
    final serviceName =
        widget.service.nameLocalized(languageCode: languageCode) ?? '';
    final timeLabel = isServiceNow
        ? (AppLocalizations.of(context)?.serviceNow ?? 'Service Now')
        : timeSlots[selectedTimeCategory]["values"][selectedTimeSlot]["label"];
    final dateStr = isServiceNow
        ? '${_getMiddleEastNow().day}/${_getMiddleEastNow().month}/${_getMiddleEastNow().year}'
        : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}';
    final addressName = selectedAddress?.fullName ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          AppLocalizations.of(context)?.bookingSummary ?? 'Booking Summary',
          style: DMSansFont.textStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildReviewCard(
          children: [
            _buildReviewRow(
              icon: Icons.home_repair_service_rounded,
              label: AppLocalizations.of(context)?.serviceName ?? 'Service',
              value: serviceName,
            ),
            const Divider(height: 20),
            _buildReviewRow(
              icon: Icons.calendar_month_rounded,
              label: AppLocalizations.of(context)?.dateAndTime ?? 'Date & Time',
              value: '$dateStr  •  $timeLabel',
            ),
            const Divider(height: 20),
            _buildReviewRow(
              icon: Icons.location_on_outlined,
              label: AppLocalizations.of(context)?.address ?? 'Address',
              value: addressName,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildReviewCard(
          children: [
            _buildReviewRow(
              icon: Icons.access_time_rounded,
              label:
                  AppLocalizations.of(context)?.bookingType ?? 'Booking Type',
              value: isAssignmentOnHour
                  ? (AppLocalizations.of(context)?.onHourBooking ??
                        'On-Hour Booking')
                  : (AppLocalizations.of(context)?.offHourBooking ??
                        'Off-Hour Booking'),
              valueColor: isAssignmentOnHour ? Colors.green : Colors.orange,
            ),
            const Divider(height: 20),
            _buildReviewRow(
              icon: Icons.sell_rounded,
              label: AppLocalizations.of(context)?.price ?? 'Price',
              value: '${price.toStringAsFixed(2)} SAR',
            ),
            if (hasDiscount) ...[
              const Divider(height: 20),
              _buildReviewRow(
                icon: Icons.discount_rounded,
                label: AppLocalizations.of(context)?.discount ?? 'Discount',
                value:
                    '${widget.service.discountPercentage!.toStringAsFixed(0)}% ${AppLocalizations.of(context)?.off ?? "off"}',
                valueColor: Colors.green,
              ),
              const Divider(height: 20),
              _buildReviewRow(
                icon: Icons.payments_rounded,
                label:
                    AppLocalizations.of(context)?.finalPrice ?? 'Final Price',
                value: '${discountedPrice.toStringAsFixed(2)} SAR',
                valueColor: Colors.green,
                isBold: true,
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _buildReviewCard(
          children: [
            _buildReviewRow(
              icon: Icons.person_rounded,
              label:
                  AppLocalizations.of(context)?.technicianAssignment ??
                  'Technician',
              value: isAssignmentOnHour
                  ? (selectedWorker.name ??
                        (AppLocalizations.of(context)?.youSelectedTechnician ??
                            'You selected a technician'))
                  : (AppLocalizations.of(context)?.autoAssignMessage ??
                        'Since this is an off-hour booking, we will assign a technician to your booking atleast 3 hours before your booking time.'),
              valueColor: isAssignmentOnHour ? AppColors.primary : Colors.blue,
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildReviewCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildReviewRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[500]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: DMSansFont.textStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: DMSansFont.textStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          currentStep == 0
              ? _buildFirstStepBottom()
              : currentStep == 1
              ? _buildSecondStepBottom()
              : currentStep == 2
              ? _buildThirdStepBottom(context)
              : _buildReviewStepBottom(context),
        ],
      ),
    );
  }

  /// Determines whether to show the technician selection screen (true)
  /// or use auto-assign (false).
  ///
  /// Rules:
  /// - Service Now + On Hour → technician selection
  /// - Service Now + Off Hours → blocked (handled in _onContinueFromFirstStep)
  /// - Service Later + Current Off Hours → auto-assign
  /// - Service Later + Current On Hour + Today → technician selection
  /// - Service Later + Current On Hour + Future Date → auto-assign
  bool _shouldShowTechnicianSelection() {
    final now = DateTime.now();
    final isCurrentlyOnHour = widget.service.isOnWorkHour(currentTime: now);

    if (isServiceNow) {
      // Service Now: show technician selection only if on-hour
      // (off-hour blocking is handled before reaching this step)
      return isCurrentlyOnHour;
    }

    // Service Later
    if (!isCurrentlyOnHour) {
      // Current time is off-hours → always auto-assign
      return false;
    }

    // Current time is on-hour — check if scheduled date is today
    final todayOnly = DateTime(now.year, now.month, now.day);
    final scheduledDateOnly = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
    );

    if (scheduledDateOnly.isAtSameMomentAs(todayOnly)) {
      // Today → technician selection (regardless of scheduled time on/off hour)
      return true;
    }

    // Future date → auto-assign
    return false;
  }

  bool _isCurrentTimeOffHour() {
    return !widget.service.isOnWorkHour(currentTime: DateTime.now());
  }

  bool _isInspectionFeeOnHour() {
    final price = _getSelectedPrice();
    return price == widget.service.onWorkHourPrice;
  }

  double _getSelectedPrice() {
    if (isServiceNow) {
      return widget.service.getCurrentPrice(currentTime: _getMiddleEastNow());
    }
    if (selectedDate == null ||
        selectedTimeCategory == -1 ||
        selectedTimeSlot == -1) {
      return widget.service.getCurrentPrice();
    }
    final timeOfDay =
        timeSlots[selectedTimeCategory]["values"][selectedTimeSlot]["time"]
            as TimeOfDay;
    DateTime bookingDateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );

    // If it's a late night slot (e.g., 12:00 AM, 12:30 AM), it technically belongs to the next day
    if (timeOfDay.hour < 5) {
      bookingDateTime = bookingDateTime.add(const Duration(days: 1));
    }

    return widget.service.getCurrentPrice(currentTime: bookingDateTime);
  }

  Widget _buildFirstStepBottom() {
    return ElevatedButton(
      onPressed: _onContinueFromFirstStep,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        AppLocalizations.of(context)?.continueText ?? 'Continue',
        style: DMSansFont.textStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  void _onContinueFromFirstStep() {
    if (selectedAddress == null) {
      _showSnackBar(
        AppLocalizations.of(context)?.pleaseSelectServiceAddress ??
            "Please select a service address",
      );
      return;
    }

    if (isValidatingAddress) {
      _showSnackBar(
        AppLocalizations.of(context)?.validatingServiceAreaPleaseWait ??
            "Please wait while we validate your address...",
      );
      return;
    }

    if (addressValidationError != null) {
      _showSnackBar(addressValidationError!);
      return;
    }

    // Block Service Now bookings during off-hours
    if (isServiceNow && _isCurrentTimeOffHour()) {
      _showSnackBar(
        AppLocalizations.of(context)?.cannotBookDuringOffHours ??
            "Cannot book during off hours. Please try again during working hours.",
      );
      return;
    }

    if (!isServiceNow) {
      if (selectedDate == null) {
        _showSnackBar(
          AppLocalizations.of(context)?.pleaseSelectADate ??
              "Please select a date",
        );
        return;
      }

      if (selectedTimeCategory == -1 || selectedTimeSlot == -1) {
        _showSnackBar(
          AppLocalizations.of(context)?.pleaseSelectATimeSlot ??
              "Please select a time slot",
        );
        return;
      }

      if (_isTimeSlotPast(selectedTimeCategory, selectedTimeSlot)) {
        _showSnackBar(
          AppLocalizations.of(context)?.cannotBookForPastTime ??
              "Cannot book for past time",
        );
        return;
      }
    }

    setState(() => currentStep = 1);
  }

  Widget _buildSecondStepBottom() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              setState(() => currentStep = 2);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(0, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              AppLocalizations.of(context)?.continueText ?? 'Continue',
              style: DMSansFont.textStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThirdStepBottom(BuildContext context) {
    if (widget.rebookTechnician != null && !_rebookFailed) {
      // While RebookWaitWidget is active, we don't show a continue button.
      // The widget will call onAccepted which moves to step 3.
      return const SizedBox.shrink();
    }

    if (_shouldShowTechnicianSelection()) {
      // On-hour broadcast: hide continue button until a technician is selected
      return ValueListenableBuilder<int?>(
        valueListenable: selectedIndexNotifier,
        builder: (context, value, _) {
          if (value == null) return const SizedBox.shrink();
          return Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => currentStep = 3),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(0, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)?.continueText ?? 'Continue',
                    style: DMSansFont.textStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    // Off-hour: proceed to review directly
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => setState(() => currentStep = 3),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(0, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              AppLocalizations.of(context)?.continueText ?? 'Continue',
              style: DMSansFont.textStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStepBottom(BuildContext context) {
    return ElevatedButton(
      onPressed: saving ? null : () => _completeBooking(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: saving
          ? const Loader(color: Colors.white)
          : Text(
              AppLocalizations.of(context)?.confirmBooking ?? 'Confirm Booking',
              style: DMSansFont.textStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Future<void> _completeBooking(BuildContext context) async {
    if (customerData == null || (!isServiceNow && selectedDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please wait for customer data to load or select a date',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() => saving = true);

    final bookingId = await BookingUtils.saveBooking(
      service: widget.service,
      selectedDate: isServiceNow ? _getMiddleEastNow() : selectedDate!,
      paymentMode: "Outside App",
      customerData: customerData!,
      notes: notesController.text,
      selectedImage: _selectedImage,
      selectedVideo: _selectedVideo,
      timeSlot: isServiceNow
          ? {"label": "Now", "time": TimeOfDay.now()}
          : timeSlots[selectedTimeCategory]["values"][selectedTimeSlot],
      agent:
          _shouldShowTechnicianSelection() &&
              selectedWorker.uid != null &&
              selectedWorker.uid!.isNotEmpty
          ? selectedWorker
          : null,
      selectedAddress: selectedAddress,
      requestId: broadcastRequestId,
      rebookTechnicianId: widget.rebookTechnician?.uid,
    );

    setState(() => saving = false);

    if (bookingId != null && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => BookingCompletedPage(
            service: widget.service,
            worker: _shouldShowTechnicianSelection()
                ? selectedWorker
                : UserModel(role: "agent", uid: ""),
            selectedDate: isServiceNow ? _getMiddleEastNow() : selectedDate!,
            selectedTime: isServiceNow
                ? {"label": "Now", "time": TimeOfDay.now()}
                : timeSlots[selectedTimeCategory]["values"][selectedTimeSlot],
            address: selectedAddress,
          ),
        ),
        (route) => false,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to complete booking')));
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _buildAddressSelectionWidget() {
    final bool isRTL = Directionality.of(context) == TextDirection.rtl;
    return GestureDetector(
      onTap: () => _showAddressSheet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(
                Icons.location_on_outlined,
                color: Colors.orange,
                size: 20,
              ),
            ),

            const SizedBox(width: 16),
            Expanded(
              child: selectedAddress != null
                  ? Column(
                      crossAxisAlignment: isRTL
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedAddress!.fullName,
                          style: DMSansFont.textStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          textAlign: isRTL ? TextAlign.right : TextAlign.left,
                        ),
                        Text(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          (selectedAddress!.buildingNumber.isNotEmpty || selectedAddress!.streetName?.isNotEmpty == true)
                              ? "${selectedAddress!.buildingNumber.isNotEmpty ? '${selectedAddress!.buildingNumber}, ' : ''}${selectedAddress!.streetName ?? ''}"
                              : "Saved Location",
                          style: DMSansFont.textStyle(
                            color: Colors.black,
                            fontSize: 10,
                          ),
                          textAlign: isRTL ? TextAlign.right : TextAlign.left,
                        ),
                      ],
                    )
                  : Text(
                      AppLocalizations.of(context)?.selectServiceAddress ??
                          'Select Address',
                      style: DMSansFont.textStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AppLocalizations.of(context)?.change ?? 'Change',
                style: DMSansFont.textStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: DMSansFont.textStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Loader(color: AppColors.primary, size: 12),
          const SizedBox(width: 8),
          Text(
            message,
            style: DMSansFont.textStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getLocalizedTimeCategory(String timeCategory) {
    switch (timeCategory.toLowerCase()) {
      case 'morning':
        return AppLocalizations.of(context)?.morning ?? 'Morning';
      case 'after noon':
        return AppLocalizations.of(context)?.afterNoon ?? 'Afternoon';
      case 'evening':
        return AppLocalizations.of(context)?.evening ?? 'Evening';
      case 'night':
        return AppLocalizations.of(context)?.night ?? 'Night';
      default:
        return '';
    }
  }

  String _getLocalizedTimeSlots(String timeSlot) {
    if (timeSlot.toLowerCase().contains("am")) {
      return AppLocalizations.of(context)?.am ?? "AM";
    }
    if (timeSlot.toLowerCase().contains("pm")) {
      return AppLocalizations.of(context)?.pm ?? "PM";
    }
    return '';
  }
}
