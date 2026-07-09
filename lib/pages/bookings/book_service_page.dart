import 'dart:io';
import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/pages/bookings/widgets/embedded_technician_search.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart' hide TextDirection;
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
  const BookServicePage({
    super.key,
    required this.service,
    this.rebookTechnician,
  });

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
  DateTime? _counterProposedTime;
  bool saving = false;
  bool _rebookFailed = false;
  bool _rebookFailedAcknowledged = false;
  String? _bookingRequestId;
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
        {"label": "06:00 AM", "time": const TimeOfDay(hour: 6, minute: 0)},
        {"label": "06:30 AM", "time": const TimeOfDay(hour: 6, minute: 30)},
        {"label": "07:00 AM", "time": const TimeOfDay(hour: 7, minute: 0)},
        {"label": "07:30 AM", "time": const TimeOfDay(hour: 7, minute: 30)},
        {"label": "08:00 AM", "time": const TimeOfDay(hour: 8, minute: 0)},
        {"label": "08:30 AM", "time": const TimeOfDay(hour: 8, minute: 30)},
        {"label": "09:00 AM", "time": const TimeOfDay(hour: 9, minute: 0)},
        {"label": "09:30 AM", "time": const TimeOfDay(hour: 9, minute: 30)},
        {"label": "10:00 AM", "time": const TimeOfDay(hour: 10, minute: 0)},
        {"label": "10:30 AM", "time": const TimeOfDay(hour: 10, minute: 30)},
        {"label": "11:00 AM", "time": const TimeOfDay(hour: 11, minute: 0)},
        {"label": "11:30 AM", "time": const TimeOfDay(hour: 11, minute: 30)},
      ],
    },
    {
      "label": "Evening",
      "values": [
        {"label": "12:00 PM", "time": const TimeOfDay(hour: 12, minute: 0)},
        {"label": "12:30 PM", "time": const TimeOfDay(hour: 12, minute: 30)},
        {"label": "01:00 PM", "time": const TimeOfDay(hour: 13, minute: 0)},
        {"label": "01:30 PM", "time": const TimeOfDay(hour: 13, minute: 30)},
        {"label": "02:00 PM", "time": const TimeOfDay(hour: 14, minute: 0)},
        {"label": "02:30 PM", "time": const TimeOfDay(hour: 14, minute: 30)},
        {"label": "03:00 PM", "time": const TimeOfDay(hour: 15, minute: 0)},
        {"label": "03:30 PM", "time": const TimeOfDay(hour: 15, minute: 30)},
        {"label": "04:00 PM", "time": const TimeOfDay(hour: 16, minute: 0)},
        {"label": "04:30 PM", "time": const TimeOfDay(hour: 16, minute: 30)},
        {"label": "05:00 PM", "time": const TimeOfDay(hour: 17, minute: 0)},
        {"label": "05:30 PM", "time": const TimeOfDay(hour: 17, minute: 30)},
        {"label": "06:00 PM", "time": const TimeOfDay(hour: 18, minute: 0)},
        {"label": "06:30 PM", "time": const TimeOfDay(hour: 18, minute: 30)},
        {"label": "07:00 PM", "time": const TimeOfDay(hour: 19, minute: 0)},
        {"label": "07:30 PM", "time": const TimeOfDay(hour: 19, minute: 30)},
        {"label": "08:00 PM", "time": const TimeOfDay(hour: 20, minute: 0)},
        {"label": "08:30 PM", "time": const TimeOfDay(hour: 20, minute: 30)},
        {"label": "09:00 PM", "time": const TimeOfDay(hour: 21, minute: 0)},
        {"label": "09:30 PM", "time": const TimeOfDay(hour: 21, minute: 30)},
        {"label": "10:00 PM", "time": const TimeOfDay(hour: 22, minute: 0)},
      ],
    },
  ];

  File? _selectedImage;
  File? _selectedVideo;
  CustomerModel? customerData;
  Stream<CustomerModel>? _customerStream;
  UserModel? _activeRebookTechnician;

  @override
  void initState() {
    super.initState();
    _activeRebookTechnician = widget.rebookTechnician;
    if (_activeRebookTechnician != null) {
      selectedWorker = _activeRebookTechnician!;
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
                  if (currentStep == 2 && _bookingRequestId != null) {
                    // Cancel search if backing out of step 2
                    AppFirestore.bookingRequestsCollectionRef
                        .doc(_bookingRequestId!)
                        .delete();
                    setState(() {
                      _bookingRequestId = null;
                      selectedWorker = UserModel(uid: "", role: "agent");
                    });
                  } else if (currentStep == 3 && _bookingRequestId != null) {
                    // If going back to step 2 from step 3, keep the request so they can change worker
                    setState(() {
                      selectedWorker = UserModel(uid: "", role: "agent");
                    });
                  }
                  setState(() => currentStep--);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Text(
              _getTitle(context),
              style: TextStyle(
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
              style: TextStyle(
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        _buildBookingTypeSelector(),

        if (isServiceNow && _isCurrentTimeOffHour())
          _buildOffHoursWarningCard(),

        if (!isServiceNow) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.selectDate ??
                            'Select Date',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _showDatePickerDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedDate != null
                                      ? DateFormat(
                                          'dd MMM yyyy',
                                        ).format(selectedDate!)
                                      : AppLocalizations.of(
                                              context,
                                            )?.selectDate ??
                                            'Select Date',
                                  style: TextStyle(
                                    color: selectedDate != null
                                        ? Colors.black87
                                        : Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.selectTime ??
                            'Available Slots',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: selectedDate == null
                            ? null
                            : _showTimeSlotPickerDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 20,
                                color: selectedDate == null
                                    ? Colors.grey
                                    : AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  (selectedTimeCategory != -1 &&
                                          selectedTimeSlot != -1)
                                      ? (timeSlots[selectedTimeCategory]["values"][selectedTimeSlot]["time"]
                                                as TimeOfDay)
                                            .format(context)
                                      : AppLocalizations.of(
                                          context,
                                        )!.selectTime,
                                  style: TextStyle(
                                    color:
                                        (selectedTimeCategory != -1 &&
                                            selectedTimeSlot != -1)
                                        ? Colors.black87
                                        : Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if ((!isServiceNow &&
                selectedDate != null &&
                selectedTimeCategory != -1 &&
                selectedTimeSlot != -1) ||
            (isServiceNow && !_isCurrentTimeOffHour()))
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
              onTap: () {
                setState(() {
                  isServiceNow = true;
                  selectedDate = null;
                  selectedTimeCategory = -1;
                  selectedTimeSlot = -1;
                });
                if (_isCurrentTimeOffHour()) {
                  _showOffHoursDialog();
                }
              },
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
                    style: TextStyle(
                      color: isServiceNow ? Colors.white : Colors.black87,
                      fontWeight: isServiceNow
                          ? FontWeight.bold
                          : FontWeight.normal,
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
                    color: !isServiceNow
                        ? AppColors.primary
                        : Colors.grey[300]!,
                  ),
                ),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)?.serviceForLater ??
                        'Service for Later',
                    style: TextStyle(
                      color: !isServiceNow ? Colors.white : Colors.black87,
                      fontWeight: !isServiceNow
                          ? FontWeight.bold
                          : FontWeight.normal,
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

  String _getOffHoursTitle() {
    final locale = AppLocalizations.of(context)?.localeName;
    if (locale == 'ar') {
      return "تنبيه الحجز خارج ساعات العمل";
    } else if (locale == 'ur') {
      return "آف آورز بکنگ الرٹ";
    } else {
      return "Off-Hours Booking Alert";
    }
  }

  String _getOffHoursMessage() {
    return AppLocalizations.of(context)?.cannotBookDuringOffHours ??
        (AppLocalizations.of(context)?.localeName == 'ar'
            ? "لا يمكن الحجز خارج ساعات العمل. يرجى المحاولة مرة أخرى خلال ساعات العمل."
            : AppLocalizations.of(context)?.localeName == 'ur'
            ? "کام کے اوقات کے علاوہ بکنگ نہیں کی جا سکتی۔ براہ کرم کام کے اوقات میں دوبارہ کوشش کریں۔"
            : "Cannot book during off hours. Please try again during working hours.");
  }

  String _getBookForLaterText() {
    final locale = AppLocalizations.of(context)?.localeName;
    if (locale == 'ar') {
      return "احجز لوقت لاحق";
    } else if (locale == 'ur') {
      return "بعد کے لیے بک کریں";
    } else {
      return "Book for Later";
    }
  }

  String _getCancelText() {
    return AppLocalizations.of(context)?.cancel ??
        (AppLocalizations.of(context)?.localeName == 'ar'
            ? "إلغاء"
            : AppLocalizations.of(context)?.localeName == 'ur'
            ? "منسوخ کریں"
            : "Cancel");
  }

  void _showOffHoursDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history_toggle_off_rounded,
                    color: Colors.amber.shade800,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _getOffHoursTitle(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _getOffHoursMessage(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Text(
                          _getCancelText(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          setState(() {
                            isServiceNow = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _getBookForLaterText(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOffHoursWarningCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber.shade800,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getOffHoursTitle(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getOffHoursMessage(),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.amber.shade900.withOpacity(0.85),
                  ),
                ),
              ],
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
            color: isOnHour ? Colors.green.shade200 : Colors.orange.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isOnHour ? Colors.green : Colors.orange).withOpacity(
                0.08,
              ),
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
                            ? (AppLocalizations.of(context)?.onHour ??
                                  'On-Hour')
                            : (AppLocalizations.of(context)?.offHour ??
                                  'Off-Hour'),
                        style: TextStyle(
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
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasDiscount)
                      Text(
                        '${price.toStringAsFixed(2)} ${AppLocalizations.of(context)?.sar ?? "SAR"}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Text(
                      '${(hasDiscount ? discountedPrice : price).toStringAsFixed(2)} ${AppLocalizations.of(context)?.sar ?? "SAR"}',
                      style: TextStyle(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.inspectionFeeNote(
                                (hasDiscount ? discountedPrice : price)
                                    .toStringAsFixed(2),
                              ) ??
                              'Inspection fee: ${(hasDiscount ? discountedPrice : price).toStringAsFixed(2)} SAR — paid only after the technician arrives and inspects the issue.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondary,
                            height: 1.4,
                          ),
                        ),
                        if (hasDiscount)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              AppLocalizations.of(
                                    context,
                                  )?.discountAppliesToInspectionFeeOnly ??
                                  'Discount applies to the inspection fee only.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.secondary,
                                fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCategories({StateSetter? setStateDialog}) {
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
                      if (setStateDialog != null) {
                        setStateDialog(() {
                          selectedTimeCategory = index;
                          selectedTimeSlot = -1;
                        });
                      }
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
                    style: TextStyle(
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

  Widget _buildTimeSlots({
    StateSetter? setStateDialog,
    BuildContext? dialogContext,
  }) {
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
            onTap: isPast
                ? null
                : () {
                    if (setStateDialog != null) {
                      setStateDialog(() => selectedTimeSlot = i);
                    }
                    setState(() => selectedTimeSlot = i);
                    if (dialogContext != null) {
                      Navigator.pop(dialogContext);
                    }
                  },
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
                  style: TextStyle(
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

  void _showDatePickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.date,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade100,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TableCalendar(
                      locale: AppLocalizations.of(context)?.localeName,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        weekendStyle: TextStyle(
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
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
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
                        todayTextStyle: TextStyle(color: AppColors.primary),
                      ),
                      selectedDayPredicate: (day) =>
                          isSameDay(day, selectedDate),
                      focusedDay: selectedDate ?? DateTime.now(),
                      firstDay: DateTime.now(),
                      lastDay: DateTime.utc(2050, 01, 16),
                      onDaySelected: (selectedDay, focusedDay) {
                        if (!isSameDay(selectedDate, selectedDay)) {
                          setStateDialog(() {
                            selectedDate = selectedDay;
                            selectedTimeCategory = -1;
                            selectedTimeSlot = -1;
                          });
                          this.setState(() {
                            selectedDate = selectedDay;
                            selectedTimeCategory = -1;
                            selectedTimeSlot = -1;
                          });
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showTimeSlotPickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context)?.time ??
                                'Available Slots',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey.shade100,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTimeCategories(setStateDialog: setStateDialog),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade300, thickness: 1),
                    if (selectedTimeCategory != -1)
                      _buildTimeSlots(
                        setStateDialog: setStateDialog,
                        dialogContext: dialogContext,
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              text: AppLocalizations.of(context)!.problemDescription,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
              children: const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red),
                ),
              ],
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
              initialImage: _selectedImage,
              initialVideo: _selectedVideo,
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
    if (_activeRebookTechnician != null && !_rebookFailed) {
      return RebookWaitWidget(
        technician: _activeRebookTechnician!,
        service: widget.service,
        selectedAddress: selectedAddress!,
        selectedDate: isServiceNow ? _getMiddleEastNow() : selectedDate!,
        timeSlot: isServiceNow
            ? {"label": "Now", "time": TimeOfDay.now()}
            : timeSlots[selectedTimeCategory]["values"][selectedTimeSlot],
        notes: notesController.text,
        issueImageFile: _selectedImage,
        issueVideoFile: _selectedVideo,
        onAccepted: (worker, newTime) {
          setState(() {
            selectedWorker = worker;
            _counterProposedTime = newTime;
            currentStep = 3;
          });
        },
        onBroadcastIdCreated: (id) {
          setState(() {
            _bookingRequestId = id;
          });
        },
        onFailed: () {
          setState(() {
            _rebookFailed = true;
          });
        },
      );
    }
    if (_rebookFailed && !_rebookFailedAcknowledged) {
      return _buildRebookFailedContent();
    }
    if (!_shouldShowTechnicianSelection()) {
      return _buildAutoAssignContent();
    }

    if (_bookingRequestId == null) {
      return const Center(child: Loader());
    }

    return EmbeddedTechnicianSearch(
      bookingRequestId: _bookingRequestId!,
      onTechnicianSelected: (worker) {
        setState(() {
          selectedWorker = worker;
        });
      },
    );
  }

  Widget _buildRebookFailedContent() {
    final bool shouldSearch = _shouldShowTechnicianSelection();
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
            child: Icon(
              Icons.person_off_rounded,
              color: Colors.red.shade600,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            locale == 'ar'
                ? 'اعتذر الفني'
                : locale == 'ur'
                ? 'ٹیکنیشن نے معذرت کر لی'
                : "Technician Cancelled",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            locale == 'ar'
                ? 'لقد اعتذر الفني المطلوب عن طلب إعادة الجدولة الخاص بك. يرجى اختيار خيار آخر.'
                : locale == 'ur'
                ? 'مطلوبہ ٹیکنیشن نے آپ کی دوبارہ شیڈولنگ کی درخواست سے معذرت کر لی ہے۔ براہ کرم دوسرا آپشن منتخب کریں۔'
                : "The requested technician cancelled or could not accept your rebooking request. Please proceed with another option.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              if (shouldSearch) {
                setState(() => saving = true);
                final requestId = await BookingUtils.saveBookingRequest(
                  service: widget.service,
                  selectedDate: isServiceNow
                      ? _getMiddleEastNow()
                      : selectedDate!,
                  paymentMode: "Outside App", // Default for now
                  customerData: customerData!,
                  notes: notesController.text,
                  selectedImage: _selectedImage,
                  selectedVideo: _selectedVideo,
                  timeSlot: isServiceNow
                      ? {"label": "Now", "time": TimeOfDay.now()}
                      : timeSlots[selectedTimeCategory]["values"][selectedTimeSlot],
                  selectedAddress: selectedAddress,
                  serviceLocation: _matchedServiceZone,
                  rejectedTechnicianUids: widget.rebookTechnician != null
                      ? [widget.rebookTechnician!.uid!]
                      : null,
                );

                if (mounted) {
                  setState(() {
                    if (requestId != null) {
                      _bookingRequestId = requestId;
                    }
                    saving = false;
                    _rebookFailedAcknowledged = true;
                    _activeRebookTechnician = null;
                  });
                }
              } else {
                setState(() {
                  _rebookFailedAcknowledged = true;
                  _activeRebookTechnician = null;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: saving
                ? const Loader(color: Colors.white)
                : Text(
                    shouldSearch
                        ? (locale == 'ar'
                              ? 'البحث عن فنيين متاحين'
                              : locale == 'ur'
                              ? 'دستیاب ٹیکنیشنز تلاش کریں'
                              : "Search Available Technicians")
                        : (locale == 'ar'
                              ? 'المتابعة للتعيين التلقائي'
                              : locale == 'ur'
                              ? 'خودکار تفویض کے لیے آگے بڑھیں'
                              : "Proceed to Auto-Assignment"),
                    style: TextStyle(
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

  Widget _buildAutoAssignContent() {
    final DateTime bookingDate = isServiceNow
        ? _getMiddleEastNow()
        : DateTime(
            selectedDate!.year,
            selectedDate!.month,
            selectedDate!.day,
            timeSlots[selectedTimeCategory]["values"][selectedTimeSlot]["time"]
                .hour,
            timeSlots[selectedTimeCategory]["values"][selectedTimeSlot]["time"]
                .minute,
          );

    final bool isToday =
        isServiceNow ||
        (isSameDay(bookingDate, _getMiddleEastNow()) &&
            _shouldShowTechnicianSelection());

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
                isToday ? Icons.sensors_rounded : Icons.auto_awesome_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isToday
                  ? (AppLocalizations.of(context)?.localeName == 'ar'
                        ? 'البحث عن الفنيين المتاحين'
                        : AppLocalizations.of(context)?.localeName == 'ur'
                        ? 'دستیاب ٹیکنیشن کی تلاش'
                        : 'Live Technician Broadcast')
                  : (AppLocalizations.of(context)?.localeName == 'ar'
                        ? 'تعيين تلقائي للفني'
                        : AppLocalizations.of(context)?.localeName == 'ur'
                        ? 'ٹیکنیشن کا خودکار تعین'
                        : 'Auto-Assignment Schedule'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      AppLocalizations.of(
                            context,
                          )?.technicianAutoAssignedBeforeAppointment ??
                          "",
                      style: TextStyle(
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
    final DateTime bookingDate =
        _counterProposedTime ??
        (isServiceNow
            ? _getMiddleEastNow()
            : DateTime(
                selectedDate!.year,
                selectedDate!.month,
                selectedDate!.day,
                timeSlots[selectedTimeCategory]["values"][selectedTimeSlot]["time"]
                    .hour,
                timeSlots[selectedTimeCategory]["values"][selectedTimeSlot]["time"]
                    .minute,
              ));
    final isAssignmentOnHour = widget.service.isOnWorkHour(
      currentTime: bookingDate,
    );
    final price = _getSelectedPrice();
    final hasDiscount = (widget.service.discountPercentage ?? 0) > 0;
    final discountedPrice = widget.service.getDiscountedPrice(price);
    final languageCode = AppLocalizations.of(context)?.localeName ?? 'en';
    final serviceName =
        widget.service.nameLocalized(languageCode: languageCode) ?? '';
    final timeLabel = _counterProposedTime != null
        ? DateFormat.jm(languageCode).format(_counterProposedTime!)
        : (isServiceNow
              ? (AppLocalizations.of(context)?.serviceNow ?? 'Service Now')
              : timeSlots[selectedTimeCategory]["values"][selectedTimeSlot]["label"]);
    final dateStr = _counterProposedTime != null
        ? '${_counterProposedTime!.day}/${_counterProposedTime!.month}/${_counterProposedTime!.year}'
        : (isServiceNow
              ? '${_getMiddleEastNow().day}/${_getMiddleEastNow().month}/${_getMiddleEastNow().year}'
              : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}');
    final addressName = selectedAddress?.fullName ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          AppLocalizations.of(context)?.bookingSummary ?? 'Booking Summary',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  ? (AppLocalizations.of(context)!.onHour)
                  : (AppLocalizations.of(context)!.offHour),
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
        if (selectedWorker.uid != null && selectedWorker.uid!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildReviewCard(
            children: [
              _buildReviewRow(
                icon: Icons.person_rounded,
                label:
                    AppLocalizations.of(context)?.technicianAssignment ??
                    'Technician',
                value: (isAssignmentOnHour || _activeRebookTechnician != null)
                    ? (selectedWorker.name ??
                          (AppLocalizations.of(
                                context,
                              )?.youSelectedTechnician ??
                              'You selected a technician'))
                    : (AppLocalizations.of(context)?.autoAssignMessage ??
                          'Your selected time is outside our working hours. We will assign an available technician before your service time and notify you once confirmed.'),
                valueColor:
                    (isAssignmentOnHour || _activeRebookTechnician != null)
                    ? AppColors.primary
                    : Colors.blue,
              ),
            ],
          ),
        ],
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
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
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
    if (isServiceNow && !_isCurrentTimeOffHour()) {
      return true;
    }

    if (!isServiceNow && selectedDate != null) {
      return !_isCurrentTimeOffHour();
    }

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
    final isBlocked = isServiceNow && _isCurrentTimeOffHour();
    return ElevatedButton(
      onPressed: isBlocked ? null : _onContinueFromFirstStep,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey.shade500,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: isBlocked ? 0 : null,
      ),
      child: Text(
        AppLocalizations.of(context)?.continueText ?? 'Continue',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isBlocked ? Colors.grey.shade500 : Colors.white,
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
            onPressed: saving ? null : _onContinueFromSecondStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(0, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: saving
                ? const Loader(color: Colors.white)
                : Text(
                    AppLocalizations.of(context)?.continueText ?? 'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _onContinueFromSecondStep() async {
    if (notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.localeName == 'ar'
                ? 'يرجى إدخال وصف المشكلة'
                : AppLocalizations.of(context)?.localeName == 'ur'
                ? 'براہ کرم مسئلے کی تفصیل درج کریں'
                : 'Please enter the problem description',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (customerData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (AppLocalizations.of(context)?.loadingCustomerData ??
                'Loading customer data, please wait...'),
          ),
        ),
      );
      return;
    }

    if (_shouldShowTechnicianSelection() &&
        _bookingRequestId == null &&
        _activeRebookTechnician == null) {
      setState(() => saving = true);
      final requestId = await BookingUtils.saveBookingRequest(
        service: widget.service,
        selectedDate: isServiceNow ? _getMiddleEastNow() : selectedDate!,
        paymentMode: "Outside App", // Default for now
        customerData: customerData!,
        notes: notesController.text,
        selectedImage: _selectedImage,
        selectedVideo: _selectedVideo,
        timeSlot: isServiceNow
            ? {"label": "Now", "time": TimeOfDay.now()}
            : timeSlots[selectedTimeCategory]["values"][selectedTimeSlot],
        selectedAddress: selectedAddress,
        serviceLocation: _matchedServiceZone,
      );

      if (requestId != null && mounted) {
        setState(() {
          _bookingRequestId = requestId;
          saving = false;
          currentStep = 2;
        });
      } else if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (AppLocalizations.of(context)?.failedToCreateBookingRequest ??
                  "Failed to create booking request"),
            ),
          ),
        );
      }
    } else {
      setState(() => currentStep = 2);
    }
  }

  Widget _buildThirdStepBottom(BuildContext context) {
    if (_activeRebookTechnician != null && !_rebookFailed) {
      // While RebookWaitWidget is active, we don't show a continue button.
      // The widget will call onAccepted which moves to step 3.
      return const SizedBox.shrink();
    }

    if (_shouldShowTechnicianSelection()) {
      // On-hour broadcast: hide continue button until a technician is selected
      if (selectedWorker.uid == null || selectedWorker.uid!.isEmpty) {
        return const SizedBox.shrink();
      }
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
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
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
              style: TextStyle(
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
        backgroundColor: AppColors.primary,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: saving
          ? const Loader(color: Colors.white)
          : Text(
              AppLocalizations.of(context)?.confirmBooking ?? 'Confirm Booking',
              style: TextStyle(
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
            (AppLocalizations.of(context)?.pleaseWaitCustomerDataLoad ??
                'Please wait for customer data to load or select a date'),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() => saving = true);

    final DateTime bookingDate = isServiceNow
        ? _getMiddleEastNow()
        : DateTime(
            selectedDate!.year,
            selectedDate!.month,
            selectedDate!.day,
            timeSlots[selectedTimeCategory]["values"][selectedTimeSlot]["time"]
                .hour,
            timeSlots[selectedTimeCategory]["values"][selectedTimeSlot]["time"]
                .minute,
          );

    final bool isManual =
        isServiceNow ||
        _activeRebookTechnician != null ||
        _shouldShowTechnicianSelection();

    if (isManual) {
      if (selectedWorker.uid?.isNotEmpty == true && _bookingRequestId != null) {
        // We already have a selected technician and a request ID.
        // Convert the request to a booking.
        try {
          final docSnap = await AppFirestore.bookingRequestsCollectionRef
              .doc(_bookingRequestId!)
              .get();

          if (docSnap.exists) {
            final requestData = docSnap.data() as Map<String, dynamic>;
            final bookingJson = {
              ...requestData,
              'agent': selectedWorker.toJson(),
              'bookingStatusCode': 'A',
              'assignedAt': Timestamp.now(),
              'technicianSelectedAt': Timestamp.now(),
              'paymentCompleted': false,
            };

            await AppFirestore.bookingsCollectionRef
                .doc(_bookingRequestId!)
                .set(bookingJson);

            await AppFirestore.bookingRequestsCollectionRef
                .doc(_bookingRequestId!)
                .delete();

            LocalStoreHelper.clearBookingRequestId();

            // Notify tech
            await AppServices.recordTechnicianNotification(
              technicianId: selectedWorker.uid!,
              titleEn: 'Job Confirmed',
              titleAr: 'تم تأكيد الطلب',
              bodyEn: 'You have been assigned to a booking.',
              bodyAr: 'لقد تم تعيينك في حجز جديد.',
              type: 'booking_confirmed',
              data: {'bookingId': _bookingRequestId},
            );

            setState(() => saving = false);

            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingCompletedPage(
                    service: widget.service,
                    worker: selectedWorker,
                    selectedDate: bookingDate,
                    selectedTime: isServiceNow
                        ? {"label": "Now", "time": TimeOfDay.now()}
                        : timeSlots[selectedTimeCategory]["values"][selectedTimeSlot],
                    address: selectedAddress,
                  ),
                ),
                (route) => false,
              );
            }
            return;
          }
        } catch (e) {
          debugPrint("Error confirming booking request: $e");
        }
      }

      // Fallback if no worker was selected via the embedded widget (e.g. rebook flow)
      final requestId = await BookingUtils.saveBooking(
        service: widget.service,
        selectedDate: bookingDate,
        paymentMode: "Outside App",
        customerData: customerData!,
        notes: notesController.text,
        selectedImage: _selectedImage,
        selectedVideo: _selectedVideo,
        timeSlot: _counterProposedTime != null
            ? {
                "label": DateFormat.jm(
                  AppLocalizations.of(context)?.localeName ?? 'en',
                ).format(bookingDate),
                "time": TimeOfDay.fromDateTime(bookingDate),
              }
            : (isServiceNow
                  ? {"label": "Now", "time": TimeOfDay.now()}
                  : timeSlots[selectedTimeCategory]["values"][selectedTimeSlot]),
        selectedAddress: selectedAddress,
        serviceLocation: _matchedServiceZone,
        agent: selectedWorker,
        requestId: _bookingRequestId,
        rebookTechnicianId: _activeRebookTechnician?.uid,
      );

      setState(() => saving = false);

      if (requestId != null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => BookingCompletedPage(
              service: widget.service,
              worker: selectedWorker,
              selectedDate: bookingDate,
              selectedTime: _counterProposedTime != null
                  ? {
                      "label": DateFormat.jm(
                        AppLocalizations.of(context)?.localeName ?? 'en',
                      ).format(bookingDate),
                      "time": TimeOfDay.fromDateTime(bookingDate),
                    }
                  : (isServiceNow
                        ? {"label": "Now", "time": TimeOfDay.now()}
                        : timeSlots[selectedTimeCategory]["values"][selectedTimeSlot]),
              address: selectedAddress,
            ),
          ),
          (route) => false,
        );
      } else if (mounted) {
        _showSnackBar(
          AppLocalizations.of(context)?.failedToCompleteBooking ??
              "Failed to create booking request",
        );
      }
    } else {
      final bookingId = await BookingUtils.saveAutoAssignmentRequest(
        service: widget.service,
        selectedDate: selectedDate!,
        paymentMode: "Outside App",
        customerData: customerData!,
        notes: notesController.text,
        selectedImage: _selectedImage,
        selectedVideo: _selectedVideo,
        timeSlot: timeSlots[selectedTimeCategory]["values"][selectedTimeSlot],
        selectedAddress: selectedAddress,
        serviceLocation: _matchedServiceZone,
        cancelledWorkerUids: widget.rebookTechnician != null
            ? [widget.rebookTechnician!.uid!]
            : null,
      );

      setState(() => saving = false);

      if (bookingId != null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => BookingCompletedPage(
              service: widget.service,
              worker: UserModel(role: "agent", uid: ""),
              selectedDate: selectedDate!,
              selectedTime:
                  timeSlots[selectedTimeCategory]["values"][selectedTimeSlot],
              address: selectedAddress,
            ),
          ),
          (route) => false,
        );
      } else if (mounted) {
        _showSnackBar(
          AppLocalizations.of(context)?.failedToCompleteBooking ??
              "Failed to complete auto-assignment booking",
        );
      }
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          textAlign: isRTL ? TextAlign.right : TextAlign.left,
                        ),
                        Text(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          (selectedAddress!.buildingNumber.isNotEmpty ||
                                  selectedAddress!.streetName?.isNotEmpty ==
                                      true)
                              ? "${selectedAddress!.buildingNumber.isNotEmpty ? '${selectedAddress!.buildingNumber}, ' : ''}${selectedAddress!.streetName ?? ''}"
                              : "Saved Location",
                          style: TextStyle(color: Colors.black, fontSize: 10),
                          textAlign: isRTL ? TextAlign.right : TextAlign.left,
                        ),
                      ],
                    )
                  : Text(
                      AppLocalizations.of(context)?.selectServiceAddress ??
                          'Select Address',
                      style: TextStyle(
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
                style: TextStyle(
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
              style: TextStyle(color: Colors.red, fontSize: 12),
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
          Text(message, style: TextStyle(color: Colors.grey, fontSize: 12)),
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
