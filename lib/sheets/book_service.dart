import 'dart:io';
import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/models/hierarchical_location.dart';
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
import 'package:abo_glumbo_bbk/services/booking/bloc/booking_bloc.dart';
import 'package:abo_glumbo_bbk/services/booking/bloc/booking_event.dart';
import 'package:abo_glumbo_bbk/services/booking/bloc/booking_state.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/utils/poppins_font.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:abo_glumbo_bbk/utils/mulish_font.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:abo_glumbo_bbk/services/booking/save_booking.dart';
import 'package:abo_glumbo_bbk/pages/telr/payment_screen.dart';
import 'package:abo_glumbo_bbk/services/location_matcher_service.dart';
import 'package:abo_glumbo_bbk/sheets/save_address_sheet.dart';
import 'package:abo_glumbo_bbk/services/location_service.dart';
import 'package:abo_glumbo_bbk/models/address_result.dart';

showBookServiceBottomSheet(
  BuildContext context, {
  required ServiceModel service,
}) async {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: BookServiceBottomSheet(service: service),
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutQuart;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
    ),
  );
}

class BookServiceBottomSheet extends StatefulWidget {
  final ServiceModel service;
  const BookServiceBottomSheet({super.key, required this.service});

  @override
  State<BookServiceBottomSheet> createState() => _BookServiceBottomSheetState();
}

class _BookServiceBottomSheetState extends State<BookServiceBottomSheet> {
  final ValueNotifier<int?> selectedIndexNotifier = ValueNotifier<int?>(null);
  UserModel selectedWorker = UserModel(uid: "", role: "customer");
  bool isFirstStep = true;
  bool isSecondStep = false;
  bool isThirdStep = false;
  DateTime? selectedDate;
  bool cashInHand = true;
  bool saving = false;
  AddressModel? selectedAddress;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController notesController = TextEditingController();
  int selectedTimeCategory = 0;
  int selectedTimeSlot = 0;
  String? addressValidationError; // New state variable
  bool isValidatingAddress = false; // New state variable
  Map<String, dynamic> _initialPosition = {
    "lon": 0.0,
    "lat": 0.0,
    "userLocation": "",
  };
  Timer? _sheetUpdateTimer;
  bool _hasRecentlyUpdatedFromSheet = false;
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
  AddressModel? _selectedAddress;
  String? selectedImageDownloadUrl;
  String? selectedVideoDownloadUrl;
  CustomerModel? customerData;

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

  Stream<CustomerModel>? _customerStream;

  @override
  void initState() {
    super.initState();
    _fetchCoordinates();
    fetchCustomerAddresses();
    _customerStream = AppServices.listenToCustomerData(
      LocalStoreHelper.getUID() ?? '',
    );
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  void _onDaySelect(DateTime day, DateTime focusedDay) {
    setState(() {
      selectedDate = day;

      selectedTimeCategory = 0;
      selectedTimeSlot = 0;
    });
  }

  bool _isTimeSlotPast(int categoryIndex, int slotIndex) {
    if (selectedDate == null) return false;

    final now = DateTime.now();
    if (!isSameDay(selectedDate!, now)) return false;

    final timeOfDay =
        timeSlots[categoryIndex]["values"][slotIndex]["time"] as TimeOfDay;
    final selectedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );

    final currentTimeWithBuffer = now.add(const Duration(minutes: 30));

    return selectedDateTime.isBefore(currentTimeWithBuffer);
  }

  bool _isTimeCategoryDisabled(int categoryIndex) {
    if (selectedDate == null) return false;

    final now = DateTime.now();
    if (!isSameDay(selectedDate!, now)) return false;

    final timeSlotsList = timeSlots[categoryIndex]["values"] as List<Map>;

    for (int i = 0; i < timeSlotsList.length; i++) {
      if (!_isTimeSlotPast(categoryIndex, i)) {
        return false;
      }
    }

    return true;
  }

  int _getFirstAvailableTimeSlot(int categoryIndex) {
    if (selectedDate == null) return 0;

    final now = DateTime.now();
    if (!isSameDay(selectedDate!, now)) return 0;

    final timeSlotsList = timeSlots[categoryIndex]["values"] as List<Map>;

    for (int i = 0; i < timeSlotsList.length; i++) {
      if (!_isTimeSlotPast(categoryIndex, i)) {
        return i;
      }
    }

    return 0;
  }

  Future<void> fetchCustomerAddresses() async {
    try {
      selectedAddress = await AppServices.getCustomerSelectedAddress();
      // Validate initially selected address
      if (selectedAddress != null) {
        _validateSelectedAddress(selectedAddress!);
      }
      setState(() {});
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

  Future<void> _showAddressSheet(
    BuildContext context, {
    bool isChangingAddress = false,
  }) async {
    // customerData is likely available in the state or we assume it is loaded

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

    // Refresh addresses
    await fetchCustomerAddresses();

    if (result != null) {
      if (result.needsAddressSelection) {
        _hasRecentlyUpdatedFromSheet = true;
        setState(() {
          selectedAddress = null;
        });
        return;
      }

      final selected = result.selectedAddress;
      if (selected != null) {
        _hasRecentlyUpdatedFromSheet = true;
        setState(() {
          selectedAddress = selected;
        });
        _validateSelectedAddress(selected);
      }
    }
  }

  Future<void> _validateSelectedAddress(AddressModel address) async {
    if (address.lat == null || address.lon == null) {
      setState(() {
        addressValidationError = "Invalid address: Missing coordinates";
      });
      return;
    }

    setState(() {
      isValidatingAddress = true;
      addressValidationError = null;
    });

    try {
      // 1. Check Service Area (Radius-based from Admin App)
      debugPrint("🔍 Checking service area availability for ${address.fullName}");
      final serviceLocationsQuery = await AppFirestore.locationsCollectionRef
          .where('service_id', isEqualTo: widget.service.id)
          .get();

      if (serviceLocationsQuery.docs.isNotEmpty) {
        final data = serviceLocationsQuery.docs.first.data() as Map<String, dynamic>;
        final locations = data['locations'] as List<dynamic>? ?? [];

        if (locations.isNotEmpty) {
          bool inServiceArea = false;
          for (var loc in locations) {
            final double? lat = loc['lat']?.toDouble();
            final double? lng = loc['lng']?.toDouble();
            final double? radius = loc['radius']?.toDouble(); // meters

            if (lat != null && lng != null && radius != null) {
              final double distanceKm = calculateDistance(
                address.lat!,
                address.lon!,
                lat,
                lng,
              );
              final double distanceMeters = distanceKm * 1000;

              if (distanceMeters <= radius) {
                inServiceArea = true;
                break;
              }
            }
          }

          if (!inServiceArea && mounted) {
            setState(() {
              isValidatingAddress = false;
              addressValidationError = "Service unavailable to this location currently";
            });

            // Show alert dialog as requested
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(AppLocalizations.of(context)?.serviceUnavailable ?? "Service Unavailable"),
                content: Text(
                  AppLocalizations.of(context)?.serviceUnavailableLongMessage ?? 
                  "service unavailable to this location currently, we hope to expand our services to this area in the future"
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)?.ok ?? "OK"),
                  ),
                ],
              ),
            );
            return;
          }
        }
      }

      // 2. Fetch technicians for this service (Keep existing check but make it second)
      debugPrint("🔍 Checking technician coverage for ${address.fullName}");

      final techniciansQuery = await AppFirestore.usersCollectionRef
          .where('role', isEqualTo: 'agent')
          .where('accountStatus', isEqualTo: 'approved')
          .get();

      bool isServiceable = false;

      for (var doc in techniciansQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Check if tech provides this service
        List<dynamic> services = data['services'] ?? [];
        bool providesService = services.any((s) {
          String? sId;
          if (s is String) {
            sId = s;
          } else if (s is Map) {
            sId = s['id'];
          }

          return sId == widget.service.id;
        });

        if (!providesService) continue;

        // Check service area
        List<dynamic> serviceAreasJson = data['serviceAreas'] ?? [];
        // Map to SelectedCity
        List<SelectedCity> serviceAreas = serviceAreasJson
            .map((e) => SelectedCity.fromJson(e))
            .toList();

        final techCovers = await LocationMatcherService.isAddressInServiceArea(
          customerLat: address.lat!,
          customerLon: address.lon!,
          technicianServiceAreas: serviceAreas,
        );

        if (techCovers) {
          isServiceable = true;
          break; // Found at least one
        }
      }

      if (mounted) {
        setState(() {
          isValidatingAddress = false;
          addressValidationError = isServiceable
              ? null
              : "No technicians available in this area";
        });
      }
    } catch (e) {
      debugPrint("❌ Error validating address: $e");
      if (mounted) {
        setState(() {
          isValidatingAddress = false;
          addressValidationError = "Failed to validate service area";
        });
      }
    }
  }

  @override
  void dispose() {
    selectedIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;
    return BlocListener<NewBookingBloc, BookingState>(
      listener: (context, state) async {
        if (state is BookingSuccess) {
          if (state.bookingId == null) {
            if (mounted) {
              setState(() {
                saving = false;
              });
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: No Booking ID'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          final booking = await BookingUtils.getBooking(state.bookingId!);

          if (!mounted) return;

          if (booking != null) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PaymentWebView(
                  service: widget.service,
                  customerData: customerData!,
                  isFromBooking: true,
                  booking: booking,
                  notesController: notesController,
                ),
              ),
            );
            // If returned, reset saving
            if (mounted) {
              setState(() {
                saving = false;
              });
            }
          } else {
            if (mounted) {
              setState(() {
                saving = false;
              });
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: Could not fetch booking details'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else if (state is BookingError) {
          // Show error message
          if (mounted) {
            setState(() {
              saving = false;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        } else if (state is BookingLoading) {
          // Update saving state when loading
          if (mounted && !saving) {
            setState(() {
              saving = true;
            });
          }
        }
      },
      child: StreamBuilder<CustomerModel>(
        stream: _customerStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            customerData = snapshot.data;
          }
          return Container(
            height: MediaQuery.of(context).size.height * 0.95,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            clipBehavior: Clip.antiAlias,
            child: AbsorbPointer(
              absorbing: saving,
              child: PopScope(
                canPop: !saving,
                child: Material(
                  color: Colors.white,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(color: AppColors.primary),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                  layoutBuilder:
                                      (currentChild, previousChildren) {
                                        return Stack(
                                          alignment: Alignment.centerLeft,
                                          children: <Widget>[
                                            ...previousChildren,
                                            if (currentChild != null)
                                              currentChild,
                                          ],
                                        );
                                      },
                                  child: Text(
                                    key: ValueKey<int>(
                                      isFirstStep
                                          ? 1
                                          : isSecondStep
                                          ? 2
                                          : 3,
                                    ),
                                    isFirstStep
                                        ? AppLocalizations.of(
                                                context,
                                              )?.selectDateTime ??
                                              ''
                                        : isSecondStep
                                        ? AppLocalizations.of(
                                                context,
                                              )?.completeYourBooking ??
                                              ''
                                        : AppLocalizations.of(
                                                context,
                                              )?.chooseYourTechnician ??
                                              '',
                                    style: DMSansFont.textStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                        ),

                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: isFirstStep
                                ? KeyedSubtree(
                                    key: const ValueKey('step1'),
                                    child: _buildFirstStepContent(),
                                  )
                                : isSecondStep
                                ? KeyedSubtree(
                                    key: const ValueKey('step2'),
                                    child: _buildSecondStepContent(),
                                  )
                                : KeyedSubtree(
                                    key: const ValueKey('step3'),
                                    child: _buildThirdStepContent(),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: safePadding.bottom + 3,
                            top: isSecondStep ? 0 : 18,
                            left: 16,
                            right: 16,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: isFirstStep
                                ? KeyedSubtree(
                                    key: const ValueKey('bottom1'),
                                    child: _buildFirstStepBottom(),
                                  )
                                : isSecondStep
                                ? KeyedSubtree(
                                    key: const ValueKey('bottom2'),
                                    child: _buildSecondStepBottom(),
                                  )
                                : KeyedSubtree(
                                    key: const ValueKey('bottom3'),
                                    child: _buildThirdStepBottom(context),
                                  ),
                          ),
                        ),
                      ],
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

  _buildThirdStepBottom(BuildContext context) {
    return Row(
      children: [
        if (!saving)
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black87),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    isSecondStep = true;
                    isThirdStep = false;
                  });
                },
                child: Text(
                  AppLocalizations.of(context)?.back ?? '',
                  style: DMSansFont.textStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        if (!saving) const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 50,
            child: Hero(
              tag: 'primary_button',
              child: ValueListenableBuilder<int?>(
                valueListenable: selectedIndexNotifier,
                builder: (context, value, child) {
                  return FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: selectedIndexNotifier.value == null
                          ? Colors.grey.shade400
                          : AppColors.secondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: saving
                        ? null
                        : () {
                            if (selectedIndexNotifier.value == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  content: Text(
                                    AppLocalizations.of(
                                          context,
                                        )?.pleaseSelectaTechnician ??
                                        'Please select a worker',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } else {
                              FocusScope.of(context).unfocus();

                              context.read<NewBookingBloc>().add(
                                CreateBookingEvent(
                                  service: widget.service,
                                  selectedDate: selectedDate!,
                                  customerData: customerData!,
                                  notes: notesController.text,
                                  selectedImage: _selectedImage,
                                  selectedVideo: _selectedVideo,
                                  timeSlot:
                                      timeSlots[selectedTimeCategory]["values"][selectedTimeSlot],
                                  agent: selectedWorker,
                                  selectedAddress: selectedAddress,
                                ),
                              );
                            }
                          },
                    child: saving
                        ? Loader()
                        : Text(
                            AppLocalizations.of(context)?.completeBooking ?? '',
                            style: DMSansFont.textStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  _buildSecondStepBottom() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black87),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                setState(() {
                  isSecondStep = false;
                  isFirstStep = true;
                  isThirdStep = false;
                });
              },
              child: Text(
                AppLocalizations.of(context)?.back ?? '',
                style: DMSansFont.textStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 50,
            child: Hero(
              tag: 'primary_button',
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (_selectedAddress == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          AppLocalizations.of(
                                context,
                              )?.pleaseSelectServiceAddress ??
                              '',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  } else {
                    setState(() {
                      isSecondStep = false;
                    });
                  }
                },
                child: Text(
                  AppLocalizations.of(context)?.continueText ?? '',
                  style: DMSansFont.textStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  _buildFirstStepBottom() {
    final activeAddress = selectedAddress;
    return SizedBox(
      width: double.maxFinite,
      height: 50,
      child: Hero(
        tag: 'primary_button',
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.secondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            if (activeAddress == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    AppLocalizations.of(context)?.pleaseSelectServiceAddress ??
                        'Please select a service address',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            if (isValidatingAddress) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('Validating service area, please wait...'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            if (addressValidationError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(addressValidationError!),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            if (selectedDate == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    AppLocalizations.of(context)?.pleaseSelectADate ?? '',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            if (_isTimeSlotPast(selectedTimeCategory, selectedTimeSlot)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    AppLocalizations.of(context)?.pleaseSelectAValidTime ??
                        'Please select a valid time',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            setState(() {
              isFirstStep = false;
              isSecondStep = true;
            });
          },
          child: Text(
            AppLocalizations.of(context)?.continueText ?? '',
            style: DMSansFont.textStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  _buildThirdStepContent() {
    return WorkerList(
      service: widget.service,
      category: widget.service.category ?? "",
      selectedAddress: selectedAddress,
      selectedIndexNotifier: selectedIndexNotifier,
      onWorkerSelected: (worker) {
        selectedWorker = worker;
      },
      selectedDate: selectedDate!,
      timeSlot: timeSlots[selectedTimeCategory]["values"][selectedTimeSlot],
    );
  }

  _buildSecondStepContent() {
    return ListView(
      padding: const EdgeInsets.only(top: 5, bottom: 16),
      children: [
        BlocProvider(
          create: (context) =>
              AddressBloc(AppServicesAddressRepository())..add(LoadAddresses()),
          child: AddIssueImageAndVideo(
            showAddressPicker: false, // Hide address picker in step 2
            onImageSelected: (value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _selectedImage = value);
                }
              });
            },
            onVideoSelected: (value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _selectedVideo = value);
                }
              });
            },
            // Address callback not needed since we pick it in step 1
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            top: 22,
            left: 16,
            right: 16,
            bottom: 8,
          ),
          child: Text(
            AppLocalizations.of(context)?.addNotes ?? '',
            style: DMSansFont.textStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            top: 10,
            left: 16,
            right: 16,
            bottom: 8,
          ),
          child: TextFormField(
            controller: notesController,
            maxLines: null,
            minLines: 4,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black12, width: 2.0),
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black12, width: 2.0),
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  _buildFirstStepContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16, top: 5),
      children: [
        // Address Selection Section
        Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 8,
          ),
          child: Text(
            AppLocalizations.of(context)?.selectLocation ?? 'Select Location',
            style: DMSansFont.textStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildAddressSelectionWidget(),
        if (addressValidationError != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    addressValidationError!,
                    style: DMSansFont.textStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (isValidatingAddress)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  "Checking service availability...",
                  style: DMSansFont.textStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            AppLocalizations.of(context)?.selectDate ?? '',
            style: DMSansFont.textStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0XFFEAEAEA)),
            borderRadius: BorderRadius.circular(9),
          ),
          child: TableCalendar(
            locale: AppLocalizations.of(context)?.localeName,
            availableGestures: AvailableGestures.all,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: PoppinsFont.textStyle(
                color: AppColors.black4,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: AppColors.blue2,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.blue2, width: 2),
              ),
              selectedTextStyle: MulishFont.textStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              todayTextStyle: MulishFont.textStyle(
                color: AppColors.blue2,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            rowHeight: 38,
            selectedDayPredicate: (day) => isSameDay(day, selectedDate),
            focusedDay: selectedDate ?? DateTime.now(),
            firstDay: DateTime.now(),
            lastDay: DateTime.utc(2050, 01, 16),
            onDaySelected: _onDaySelect,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          child: Text(
            AppLocalizations.of(context)?.availableTimeSlot ?? '',
            style: DMSansFont.textStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 31,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16.0),
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            itemCount: 4,
            itemBuilder: (context, index) {
              final isDisabled = _isTimeCategoryDisabled(index);

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: InkWell(
                  onTap: isDisabled
                      ? null
                      : () {
                          setState(() {
                            selectedTimeCategory = index;
                            selectedTimeSlot = _getFirstAvailableTimeSlot(
                              index,
                            );
                          });
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDisabled
                          ? Colors.grey.shade300
                          : selectedTimeCategory == index
                          ? AppColors.secondary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDisabled
                            ? Colors.grey.shade400
                            : selectedTimeCategory == index
                            ? AppColors.secondary
                            : Colors.black,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Center(
                        child: Text(
                          _getLocalizedTimeCategory(timeSlots[index]["label"]),
                          style: DMSansFont.textStyle(
                            color: isDisabled
                                ? Colors.grey.shade600
                                : selectedTimeCategory == index
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 16, right: 5),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (
                int i = 0;
                i <
                    (timeSlots[selectedTimeCategory]["values"] as List<Map>)
                        .length;
                i++
              )
                Builder(
                  builder: (context) {
                    final isPast = _isTimeSlotPast(selectedTimeCategory, i);

                    return InkWell(
                      onTap: isPast
                          ? null
                          : () {
                              setState(() => selectedTimeSlot = i);
                            },
                      child: Container(
                        height: 30,
                        width: 80,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: isPast
                              ? Colors.grey.shade200
                              : selectedTimeSlot == i
                              ? Colors.transparent
                              : AppColors.grey4,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isPast
                                ? Colors.grey.shade400
                                : selectedTimeSlot == i
                                ? AppColors.secondary
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          "${(timeSlots[selectedTimeCategory]["values"] as List<Map>)[i]["label"].toString().substring(0, 5)} ${_getLocalizedTimeSlots((timeSlots[selectedTimeCategory]["values"] as List<Map>)[i]["label"])}",
                          style: DMSansFont.textStyle(
                            color: isPast
                                ? Colors.grey.shade500
                                : selectedTimeSlot == i
                                ? AppColors.secondary
                                : Colors.black87,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSelectionWidget() {
    final bool isRTL = Directionality.of(context) == TextDirection.rtl;

    return GestureDetector(
      onTap: () => _showAddressSheet(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: EdgeInsets.only(left: 16, right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDDDDD), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: selectedAddress != null
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: isRTL ? 8 : 0,
                right: isRTL ? 0 : 8,
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: const Color(0xFF4F4F4F),
                size: 20,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedAddress != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.serviceto,
                            style: DMSansFont.textStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: isRTL ? TextAlign.right : TextAlign.left,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[400],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            AppLocalizations.of(context)?.change ?? 'Change',
                            style: DMSansFont.textStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedAddress!.fullName,
                      style: DMSansFont.textStyle(
                        color: const Color(0xFF2C2C2C),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedAddress!.streetName?.isNotEmpty == true
                          ? selectedAddress!.streetName!
                          : selectedAddress!.buildingNumber.isNotEmpty
                          ? selectedAddress!.buildingNumber
                          : "Address location",
                      style: DMSansFont.textStyle(
                        color: const Color(0xFF959595),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ] else ...[
                    Text(
                      (AppLocalizations.of(context)?.selectServiceAddress ??
                          'Select Service Address'),
                      style: DMSansFont.textStyle(
                        color: const Color(0xFF4F4F4F),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (AppLocalizations.of(context)?.selectFromSavedAddresses ??
                          'Select from your saved addresses or add a new one.'),
                      style: DMSansFont.textStyle(
                        color: const Color(0xFF959595),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ],
                ],
              ),
            ),
            if (selectedAddress == null)
              Padding(
                padding: EdgeInsets.only(
                  left: isRTL ? 0 : 8,
                  right: isRTL ? 8 : 0,
                ),
                child: Transform.rotate(
                  angle: isRTL ? 3.14159 : 0,
                  child: Icon(
                    isRTL
                        ? Icons.arrow_back_ios_rounded
                        : Icons.arrow_forward_ios_rounded,
                    color: const Color(0xFF4F4F4F),
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  _getLocalizedTimeCategory(String timeCategory) {
    switch (timeCategory.toLowerCase()) {
      case 'morning':
        return AppLocalizations.of(context)?.morning ?? '';
      case 'after noon':
        return AppLocalizations.of(context)?.afterNoon ?? '';
      case 'evening':
        return AppLocalizations.of(context)?.evening ?? '';
      case 'night':
        return AppLocalizations.of(context)?.night ?? '';
      default:
        return '';
    }
  }

  _getLocalizedTimeSlots(String timeSlot) {
    if (timeSlot.toLowerCase().contains("am")) {
      return AppLocalizations.of(context)?.am;
    } else if (timeSlot.toLowerCase().contains("pm")) {
      return AppLocalizations.of(context)?.pm;
    } else {
      return '';
    }
  }
}
