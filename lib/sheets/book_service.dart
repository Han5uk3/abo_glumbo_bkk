import 'dart:io';
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
import 'package:abo_glumbo_bbk/services/booking/bloc/booking_bloc.dart';
import 'package:abo_glumbo_bbk/services/booking/bloc/booking_event.dart';
import 'package:abo_glumbo_bbk/services/booking/bloc/booking_state.dart';
import 'package:abo_glumbo_bbk/services/booking/booking_complete.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

showBookServiceBottomSheet(
  BuildContext context, {
  required ServiceModel service,
}) async {
  await showModalBottomSheet(
    enableDrag: false,
    isDismissible: false,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.95,
    ),
    context: context,
    isScrollControlled: true,
    clipBehavior: Clip.antiAlias,
    builder: (context) {
      return BookServiceBottomSheet(service: service);
    },
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
  UserModel selectedWorker = UserModel(uid: "");
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
      setState(() {});
    } catch (e) {
      debugPrint("Error fetching addresses: $e");
    }
  }

  @override
  void initState() {
    fetchCustomerAddresses();

    super.initState();
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
      listener: (context, state) {
        if (state is BookingSuccess) {
          // Navigate only after successful booking
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => BookingCompletedPage(
                service: widget.service,
                worker: selectedWorker,
                selectedDate: selectedDate!,
                selectedTime:
                    timeSlots[selectedTimeCategory]["values"][selectedTimeSlot],
                address:
                    _selectedAddress ??
                    AddressModel(
                      id: '',
                      fullName: '',
                      buildingNumber: '',
                      phoneNumber: '',
                    ),
              ),
            ),
          );
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
        stream: AppServices.listenToCustomerData(
          LocalStoreHelper.getUID() ?? '',
        ),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            customerData = snapshot.data;
          }
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.95,
            child: AbsorbPointer(
              absorbing: saving,
              child: PopScope(
                canPop: !saving,
                child: Scaffold(
                  body: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(color: AppColors.primary),
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: 8,
                              left: 16,
                              right: 16,
                              bottom: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
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
                                  style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
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
                          child: isFirstStep
                              ? _buildFirstStepContent()
                              : isSecondStep
                              ? _buildSecondStepContent()
                              : _buildThirdStepContent(),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: safePadding.bottom + 3,
                            top: 18,
                            left: 16,
                            right: 16,
                          ),
                          child: isFirstStep
                              ? _buildFirstStepBottom()
                              : isSecondStep
                              ? _buildSecondStepBottom()
                              : _buildThirdStepBottom(context),
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
                  style: GoogleFonts.dmSans(
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
                                        )?.pleaseSelectaWorker ??
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
                                ),
                              );
                            }
                          },
                    child: saving
                        ? Loader()
                        : Text(
                            AppLocalizations.of(context)?.completeBooking ?? '',
                            style: GoogleFonts.dmSans(
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
                style: GoogleFonts.dmSans(
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
                  style: GoogleFonts.dmSans(
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
            style: GoogleFonts.dmSans(
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
    );
  }

  _buildSecondStepContent() {
    return ListView(
      children: [
        BlocProvider(
          create: (context) =>
              AddressBloc(AppServicesAddressRepository())..add(LoadAddresses()),
          child: AddIssueImageAndVideo(
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
            isAddressSelected: (value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _selectedAddress = value);
                }
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            top: 10,
            left: 16,
            right: 16,
            bottom: 0,
          ),
          child: Text(
            AppLocalizations.of(context)?.addNotes ?? '',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
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
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 18),
          child: Text(
            AppLocalizations.of(context)?.selectDate ?? '',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
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
              titleTextStyle: GoogleFonts.poppins(
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
              selectedTextStyle: GoogleFonts.mulish(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              todayTextStyle: GoogleFonts.mulish(
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
            style: GoogleFonts.dmSans(
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
                          style: GoogleFonts.dmSans(
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
                          style: GoogleFonts.dmSans(
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
