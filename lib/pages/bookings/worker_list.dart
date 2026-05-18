import 'dart:math';
import 'package:abo_glumbo_bbk/helpers/location_helper.dart';
import 'dart:async';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/categories.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';

import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/pages/bookings/worker_card.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/location_matcher_service.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:abo_glumbo_bbk/models/job_request.dart';



class WorkerList extends StatefulWidget {
  final ServiceModel service;
  final String category;
  final AddressModel? selectedAddress;
  final ValueNotifier<int?> selectedIndexNotifier;
  final Function(UserModel) onWorkerSelected;
  final Function(String) onBroadcastIdCreated;
  final DateTime selectedDate;
  final Map timeSlot;
  final bool isOnHour;

  final String? notes;
  final File? issueImageFile;
  final File? issueVideoFile;

  const WorkerList({
    super.key,
    required this.category,
    required this.selectedAddress,
    required this.selectedIndexNotifier,
    required this.onWorkerSelected,
    required this.onBroadcastIdCreated,
    required this.service,
    required this.selectedDate,
    required this.timeSlot,
    required this.isOnHour,
    this.notes,
    this.issueImageFile,
    this.issueVideoFile,
  });

  @override
  State<WorkerList> createState() => _WorkerListState();
}

class _WorkerListState extends State<WorkerList> with WidgetsBindingObserver {

  CustomerModel? customerData;
  bool isLoadingCustomer = true;
  String? _requestId;
  int _timerSeconds = 120;
  Timer? _broadcastTimer;
  StreamSubscription? _responsesSubscription;
  List<WorkerWithStats> _acceptedWorkers = [];
  bool _isBroadcasting = true;
  Set<String> _busyAgentIds = {};
  StreamSubscription? _busyAgentsSubscription;
  
  bool _filterByDistance = false;
  bool _filterByRating = false;
  bool _filterByCompletedJobs = false;
  final double _nearbyThresholdKm = 60.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchCustomerData();
    _subscribeToBusyAgents();
    _startSearchAndBroadcast();
  }

  void _subscribeToBusyAgents() {
    try {
      final timeOfDay = widget.timeSlot["time"] as TimeOfDay;
      final bookingDate = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );

      _busyAgentsSubscription = AppFirestore.bookingsCollectionRef
          .where('bookingDateTime', isEqualTo: Timestamp.fromDate(bookingDate))
          .snapshots()
          .listen((snapshot) {
        final busyIds = <String>{};
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['bookingStatusCode'] == 'A') {
            final agent = data['agent'];
            if (agent != null && agent['uid'] != null) {
              busyIds.add(agent['uid']);
            }
          }
        }
        if (mounted) setState(() => _busyAgentIds = busyIds);
      });
    } catch (e) {
      debugPrint("Error subscribing to busy agents: $e");
    }
  }

  Future<void> _startSearchAndBroadcast() async {
    // 1. Fetch service locations/zones from Firestore
    List<dynamic> serviceLocations = [];
    try {
      final serviceLocationsQuery = await AppFirestore.locationsCollectionRef
          .where('service_id', isEqualTo: widget.service.id)
          .get();
      if (serviceLocationsQuery.docs.isNotEmpty) {
        final data = serviceLocationsQuery.docs.first.data() as Map<String, dynamic>;
        serviceLocations = data['locations'] as List<dynamic>? ?? [];
      }
    } catch (e) {
      debugPrint("Error fetching service locations in WorkerList: $e");
    }

    // 2. Get eligible workers
    final workers = await AppServices.getWorkersByRolesWithStatsRealtime(
      widget.category,
    ).first;

    // 3. Filter technicians (Availability + Proximity within 60km + Service Zone)
    List<WorkerWithStats> eligible = workers.where((w) {
      if (_busyAgentIds.contains(w.worker.uid)) return false;
      
      // Proximity check
      final distance = _getWorkerDistance(w);
      if (distance > 60.0) return false;

      // Service Zone check
      if (w.worker.lastKnownLocation == null) return false;
      final isWithinServiceZone = LocationMatcherService.isAddressInServiceZones(
        customerLat: w.worker.lastKnownLocation!.latitude,
        customerLon: w.worker.lastKnownLocation!.longitude,
        serviceLocations: serviceLocations,
      );
      return isWithinServiceZone;
    }).toList();
    
    // Sort by proximity
    eligible.sort((a, b) => _getWorkerDistance(a).compareTo(_getWorkerDistance(b)));
    
    // Take all eligible qualified technicians within 60km
    final qualifiedTechnicians = eligible;

    if (qualifiedTechnicians.isEmpty) {
      if (mounted) {
        setState(() {
          _isBroadcasting = false;
        });
      }
      return;
    }

    // 3. Handle File Uploads
    String? issueImageUrl;
    String? issueVideoUrl;

    try {
      if (widget.issueImageFile != null) {
        String fileName = 'users/${customerData?.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        final uploadTask = storageRef.putFile(widget.issueImageFile!);
        final snapshot = await uploadTask;
        issueImageUrl = await snapshot.ref.getDownloadURL();
      }
      if (widget.issueVideoFile != null) {
        String fileName = 'users/${customerData?.uid}/${DateTime.now().millisecondsSinceEpoch}.mp4';
        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        final uploadTask = storageRef.putFile(
          widget.issueVideoFile!,
          SettableMetadata(contentType: 'video/mp4'),
        );
        final snapshot = await uploadTask;
        issueVideoUrl = await snapshot.ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint("Error uploading files in WorkerList: $e");
    }

    // 4. Create Job Request
    final requestId = AppFirestore.jobRequestsCollectionRef.doc().id;
    final now = Timestamp.now();
    final expiresAt = Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 120)));

    final request = JobRequestModel(
      id: requestId,
      service: widget.service,
      customer: customerData!,
      address: widget.selectedAddress!,
      notes: widget.notes ?? '',
      issueImage: issueImageUrl ?? "",
      issueVideo: issueVideoUrl ?? "",
      createdAt: now,
      expiresAt: expiresAt,
      isOnHour: widget.isOnHour,
      bookingDateTime: Timestamp.fromDate(
        DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          (widget.timeSlot['time'] as TimeOfDay).hour,
          (widget.timeSlot['time'] as TimeOfDay).minute,
        ),
      ),
      status: 'pending',
    );

    // 4. Broadcast
    if (mounted) {
      setState(() {
        _requestId = requestId;
        _isBroadcasting = true;
      });
    }

    await AppServices.broadcastJobRequest(
      request: request,
      workerIds: qualifiedTechnicians.map((w) => w.worker.uid!).toList(),
    );

    if (mounted) {
      widget.onBroadcastIdCreated(requestId);
      _startTimer();
      _listenToResponses(qualifiedTechnicians);
    }
  }

  void _startTimer() {
    _broadcastTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() {
          _timerSeconds--;
        });
      } else {
        _stopBroadcast();
      }
    });
  }

  void _listenToResponses(List<WorkerWithStats> qualifiedTechniciansList) {
    _responsesSubscription = AppServices.listenToInterestedWorkers(_requestId!).listen((workerIds) {
      if (mounted) {
        setState(() {
          _acceptedWorkers = qualifiedTechniciansList.where((w) => workerIds.contains(w.worker.uid)).toList();
        });
      }
    });
  }

  void _stopBroadcast() {
    _broadcastTimer?.cancel();
    _responsesSubscription?.cancel();
    if (mounted) {
      setState(() {
        _isBroadcasting = false;
      });
    }
    // If no one accepted by now, request is essentially failed
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If app is closed or put in background during selection, cleanup the request
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      _cleanupRequest();
    }
  }

  void _cleanupRequest() {
    // If user exits and hasn't selected a worker, delete the request and its offers
    if (_requestId != null && widget.selectedIndexNotifier.value == null) {
      AppServices.deleteJobRequest(_requestId!);
      _requestId = null; // Prevent duplicate deletions
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _broadcastTimer?.cancel();
    _responsesSubscription?.cancel();
    _cleanupRequest();
    _busyAgentsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchCustomerData() async {
    setState(() => isLoadingCustomer = true);

    try {
      final uid = LocalStoreHelper.getUID();
      if (uid != null) {
        final docSnapshot = await AppFirestore.customersCollectionRef
            .doc(uid)
            .get();

        if (docSnapshot.exists) {
          customerData = CustomerModel.fromJson(
            docSnapshot.data() as Map<String, dynamic>,
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching customer data: $e');
    } finally {
      if (mounted) {
        setState(() => isLoadingCustomer = false);
      }
    }
  }

  bool get _allFiltersOff => !_filterByRating && !_filterByCompletedJobs && !_filterByDistance;

  /// Calculate distance between the booking address and a worker
  double _getWorkerDistance(WorkerWithStats workerStat) {
    if (widget.selectedAddress?.lat != null &&
        widget.selectedAddress?.lon != null &&
        workerStat.worker.lastKnownLocation != null) {
      return LocationHelper.calculateDistance(
        widget.selectedAddress!.lat!,
        widget.selectedAddress!.lon!,
        workerStat.worker.lastKnownLocation!.latitude,
        workerStat.worker.lastKnownLocation!.longitude,
      );
    }
    return 99999;
  }

  /// Filter and sort workers based on active filters
  List<WorkerWithStats> _applyFiltersAndSort(List<WorkerWithStats> workers) {
    List<WorkerWithStats> filtered = List<WorkerWithStats>.from(workers);

    // When all filters are ON (default), show best match: nearby + high rating
    // When specific filters are ON, filter by those criteria
    // When all filters are OFF, show everyone unsorted

    if (_allFiltersOff) {
      // Show all workers, no filtering, just basic sort by name
      return filtered;
    }

    // Apply filters
    if (_filterByDistance && widget.selectedAddress?.lat != null && widget.selectedAddress?.lon != null) {
      filtered = filtered.where((w) {
        final dist = _getWorkerDistance(w);
        return dist <= _nearbyThresholdKm;
      }).toList();
    }



    // Sort based on active filter priorities
    filtered.sort((a, b) {
      if (_filterByRating) {
        int ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;
      }

      if (_filterByCompletedJobs) {
        int jobsCompare = b.completedJobs.compareTo(a.completedJobs);
        if (jobsCompare != 0) return jobsCompare;
      }

      if (_filterByDistance) {
        double distA = _getWorkerDistance(a);
        double distB = _getWorkerDistance(b);
        int distCompare = distA.compareTo(distB);
        if (distCompare != 0) return distCompare;
      }

      return 0;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    if (isLoadingCustomer) {
      return Center(child: Loader());
    }

    final displayedWorkers = _applyFiltersAndSort(_acceptedWorkers);

    return Column(
      children: [
        // Timer display
        _buildTimerDisplay(),

        // Show filters once technicians are listed (i.e. _acceptedWorkers is not empty)
        if (_acceptedWorkers.isNotEmpty) _buildFilterChips(locale),

        // Workers List
        Expanded(
          child: _acceptedWorkers.isEmpty && _isBroadcasting
              ? const _FilteringAnimation()
              : _acceptedWorkers.isEmpty && !_isBroadcasting
                  ? _EmptyState(
                      searchQuery: '',
                      hasActiveFilters: false,
                      totalCount: 0,
                      onClearFilter: () {},
                      onChangeLocation: () {},
                    )
                  : displayedWorkers.isEmpty
                      ? _EmptyState(
                          searchQuery: '',
                          hasActiveFilters: !_allFiltersOff,
                          totalCount: _acceptedWorkers.length,
                          onClearFilter: () {
                            setState(() {
                              _filterByRating = false;
                              _filterByCompletedJobs = false;
                              _filterByDistance = false;
                              widget.selectedIndexNotifier.value = null;
                            });
                          },
                          onChangeLocation: () {},
                        )
                      : _WorkerListView(
                          key: ValueKey('worker_list_${displayedWorkers.map((w) => w.worker.uid ?? '').join('_')}'),
                          service: widget.service,
                          workers: displayedWorkers,
                          selectedAddress: widget.selectedAddress,
                          selectedIndexNotifier: widget.selectedIndexNotifier,
                          onWorkerSelected: widget.onWorkerSelected,
                          selectedDate: widget.selectedDate,
                          timeSlot: widget.timeSlot,
                        ),
        ),
      ],
    );
  }

  Widget _buildTimerDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            _isBroadcasting
                ? "Selecting experts... ${_timerSeconds}s"
                : "Selection time over",
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(AppLocalizations locale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: locale.highestRating,
              icon: Icons.star_rounded,
              isActive: _filterByRating,
              activeColor: Colors.amber,
              onTap: () {
                setState(() {
                  _filterByRating = !_filterByRating;
                  widget.selectedIndexNotifier.value = null;
                });
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: locale.mostOrders,
              icon: Icons.workspace_premium_rounded,
              isActive: _filterByCompletedJobs,
              activeColor: AppColors.green2,
              onTap: () {
                setState(() {
                  _filterByCompletedJobs = !_filterByCompletedJobs;
                  widget.selectedIndexNotifier.value = null;
                });
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: locale.nearest,
              icon: Icons.near_me_rounded,
              isActive: _filterByDistance,
              activeColor: AppColors.secondary,
              onTap: () {
                setState(() {
                  _filterByDistance = !_filterByDistance;
                  widget.selectedIndexNotifier.value = null;
                });
              },
            ),
            if (!_allFiltersOff) ...[
              const SizedBox(width: 8),
              _buildClearAllChip(locale),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withOpacity(0.12) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? activeColor : Colors.grey.shade300,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive ? activeColor : Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? activeColor.withOpacity(0.9) : Colors.grey.shade600,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: activeColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearAllChip(AppLocalizations locale) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _filterByRating = false;
            _filterByCompletedJobs = false;
            _filterByDistance = false;
            widget.selectedIndexNotifier.value = null;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close_rounded, size: 14, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Text(
                locale.clear,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Animated filtering state widget
class _FilteringAnimation extends StatefulWidget {
  const _FilteringAnimation();

  @override
  State<_FilteringAnimation> createState() => _FilteringAnimationState();
}

class _FilteringAnimationState extends State<_FilteringAnimation>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: 5,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: const [
                        Colors.white24,
                        Colors.white38,
                        Colors.white24,
                      ],
                      stops: [0.0, _shimmerController.value, 1.0],
                      transform: GradientRotation(
                        _shimmerController.value * 2 * pi,
                      ),
                    ).createShader(bounds);
                  },
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 16,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 12,
                                  width: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade400,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 12,
                                  width: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade400,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
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
        );
      },
    );
  }
}



// Empty State
class _EmptyState extends StatelessWidget {
  final String searchQuery;
  final bool hasActiveFilters;
  final int totalCount;
  final VoidCallback onClearFilter;
  final VoidCallback onChangeLocation;

  const _EmptyState({
    required this.searchQuery,
    required this.onClearFilter,
    required this.onChangeLocation,
    this.hasActiveFilters = false,
    this.totalCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasActiveFilters ? Icons.filter_list_off_rounded : Icons.search_off_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                searchQuery.isNotEmpty
                    ? locale.noTechniciansFoundMatchingYourSearch
                    : hasActiveFilters
                        ? locale.noTechniciansMatchFilters
                        : locale.noTechniciansFound,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (hasActiveFilters && totalCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  locale.tryRemovingFilters,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: onClearFilter,
                  icon: const Icon(Icons.filter_list_off_rounded, size: 18),
                  label: Text(locale.showAllTechnicians),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                    ),
                  ),
                ),
              ] else if (!hasActiveFilters) ...[
                const SizedBox(height: 12),
                Text(
                  locale.noTechniciansFound,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Worker List View with staggered animation
class _WorkerListView extends StatefulWidget {
  final ServiceModel service;
  final List<WorkerWithStats> workers;
  final AddressModel? selectedAddress;
  final ValueNotifier<int?> selectedIndexNotifier;
  final Function(UserModel) onWorkerSelected;
  final DateTime selectedDate;
  final Map timeSlot;

  const _WorkerListView({
    super.key,
    required this.workers,
    required this.selectedAddress,
    required this.selectedIndexNotifier,
    required this.onWorkerSelected,
    required this.service,
    required this.selectedDate,
    required this.timeSlot,
  });

  @override
  State<_WorkerListView> createState() => _WorkerListViewState();
}

class _WorkerListViewState extends State<_WorkerListView>
    with SingleTickerProviderStateMixin {
  Map<String, Map<String, String>> workerLocalizedRoles =
      {}; // categoryId -> {name, name_ar}
  late AnimationController _animationController;
  final List<Animation<double>> _itemAnimations = [];
  bool _isLoadingCategories = true;

  static final Map<String, String> jobRoleToCategoryId = {}; // jobRole -> categoryId
  static final Map<String, Map<String, String>> categoryIdToNames =
      {}; // categoryId -> {name, name_ar}

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100 * widget.workers.length),
    );

    for (int i = 0; i < widget.workers.length; i++) {
      final start = (i / widget.workers.length).clamp(0.0, 1.0);
      final end = ((i + 1) / widget.workers.length).clamp(0.0, 1.0);

      _itemAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        ),
      );
    }

    _animationController.forward();
    _loadCategoryNames();
    _subscribeToBusyAgents();
  }

  Set<String> busyAgentIds = {};
  StreamSubscription? _bookingsSubscription;

  void _subscribeToBusyAgents() {
    try {
      final timeOfDay = widget.timeSlot["time"] as TimeOfDay;
      final bookingDate = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );

      _bookingsSubscription = AppFirestore.bookingsCollectionRef
          .where('bookingDateTime', isEqualTo: Timestamp.fromDate(bookingDate))
          .snapshots()
          .listen(
            (snapshot) {
              final busyIds = <String>{};
              for (var doc in snapshot.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['bookingStatusCode'];
                // Consider busy only if status is Accepted (A)
                if (status == 'A') {
                  final agent = data['agent'];
                  if (agent != null && agent['uid'] != null) {
                    busyIds.add(agent['uid']);
                  }
                }
              }

              if (mounted) {
                setState(() {
                  busyAgentIds = busyIds;
                });
              }
            },
            onError: (e) {
              debugPrint("Error fetching busy agents: $e");
            },
          );
    } catch (e) {
      debugPrint("Error setting up busy agents subscription: $e");
    }
  }

  Future<void> _loadCategoryNames() async {
    try {
      // 1. Collect all unique job roles from all workers
      Set<String> allJobRoles = {};
      for (var workerStat in widget.workers) {
        if (workerStat.worker.jobRoles != null) {
          allJobRoles.addAll(workerStat.worker.jobRoles!);
        }
      }

      // Check if all needed roles are already cached in our static map
      final bool allRolesCached = allJobRoles.every((role) => jobRoleToCategoryId.containsKey(role));
      if (allRolesCached && jobRoleToCategoryId.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isLoadingCategories = false;
          });
        }
        return;
      }

      if (allJobRoles.isEmpty) {
        if (mounted) setState(() => _isLoadingCategories = false);
        return;
      }

      // 2. Get category IDs for all job roles in parallel
      List<String> jobRolesList = allJobRoles.toList();
      List<Future<String?>> categoryIdFutures = jobRolesList
          .map((role) => AppServices.getCategoryIdByJobRoleOnce(role))
          .toList();

      List<String?> categoryIdResults = await Future.wait(categoryIdFutures);

      // 3. Create jobRole -> categoryId mapping (THIS IS CRITICAL)
      Map<String, String> roleToIdMap = {};
      for (int i = 0; i < jobRolesList.length; i++) {
        if (categoryIdResults[i] != null) {
          roleToIdMap[jobRolesList[i]] = categoryIdResults[i]!;
        }
      }

      // 4. Get unique category IDs
      Set<String> uniqueCategoryIds = roleToIdMap.values.toSet();

      if (uniqueCategoryIds.isEmpty) {
        if (mounted) setState(() => _isLoadingCategories = false);
        return;
      }

      // 5. Batch fetch all categories
      List<CategoryModel> categories = await AppServices.getCategoriesByIds(
        uniqueCategoryIds.toList(),
      );

      // 6. Create categoryId -> names mapping
      Map<String, Map<String, String>> idToNamesMap = {};
      for (var category in categories) {
        if (category.id != null) {
          idToNamesMap[category.id!] = {
            'name': category.name ?? '',
            'name_ar': category.name_ar ?? category.name ?? '',
          };
        }
      }

      if (mounted) {
        setState(() {
          jobRoleToCategoryId.clear();
          jobRoleToCategoryId.addAll(roleToIdMap);
          categoryIdToNames.clear();
          categoryIdToNames.addAll(idToNamesMap);
        });
      }
    } catch (e) {
      debugPrint('Error loading category names: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  List<String> _getLocalizedRoles(UserModel worker) {
    bool isArabic = Directionality.of(context) == TextDirection.rtl;
    List<String> localizedRoles = [];

    for (var role in worker.jobRoles ?? []) {
      String localizedName = role; // Fallback to original role name

      // Get category ID for THIS SPECIFIC job role
      String? categoryId = jobRoleToCategoryId[role];

      if (categoryId != null) {
        // Get localized name from category
        Map<String, String>? categoryNames = categoryIdToNames[categoryId];

        if (categoryNames != null) {
          if (isArabic && categoryNames['name_ar']!.isNotEmpty) {
            localizedName = categoryNames['name_ar']!;
          } else if (categoryNames['name']!.isNotEmpty) {
            localizedName = categoryNames['name']!;
          }
        }
      }

      localizedRoles.add(localizedName);
    }

    return localizedRoles;
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: widget.workers.length,
      itemBuilder: (context, index) {
        final statData = widget.workers[index];

        // Calculate if the technician is too far (>60km)
        bool isTooFar = false;
        if (widget.selectedAddress?.lat != null &&
            widget.selectedAddress?.lon != null &&
            statData.worker.lastKnownLocation != null) {
          final dist = LocationHelper.calculateDistance(
            widget.selectedAddress!.lat!,
            widget.selectedAddress!.lon!,
            statData.worker.lastKnownLocation!.latitude,
            statData.worker.lastKnownLocation!.longitude,
          );
          isTooFar = dist > 60.0;
        }

        bool isBusy = statData.worker.uid != null && busyAgentIds.contains(statData.worker.uid);

        return AnimatedBuilder(
          animation: _itemAnimations[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - _itemAnimations[index].value)),
              child: Opacity(
                opacity: _itemAnimations[index].value,
                child: child,
              ),
            );
          },
          child: ValueListenableBuilder<int?>(
            valueListenable: widget.selectedIndexNotifier,
            builder: (context, selectedIndex, child) {
              final isSelected = selectedIndex == index;
              return GestureDetector(
                onTap: () {
                  if (isTooFar) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)!.tooFarAway,
                        ),
                        backgroundColor: Colors.red.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  if (isBusy) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)!.technicianIsBusyatThisTime,
                        ),
                        backgroundColor: Colors.red.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  widget.selectedIndexNotifier.value = index;
                  widget.onWorkerSelected(statData.worker);
                },
                child: WorkerCard(
                  reviewCount: statData.reviewCount,
                  service: widget.service,
                  rating: statData.rating,
                  completedJobs: statData.completedJobs,
                  worker: statData.worker,
                  customerAddress:
                      widget.selectedAddress ??
                      AddressModel(
                        id: '',
                        fullName: '',
                        buildingNumber: '',
                        phoneNumber: '',
                      ),
                  isSelected: isSelected && !isTooFar && !isBusy,
                  localizedJobRoles: _getLocalizedRoles(
                    statData.worker,
                  ),
                  isBusy: isBusy,
                  isTooFar: isTooFar,
                ),
              );
            },
          ),
        );
      },
    );
  }
}


