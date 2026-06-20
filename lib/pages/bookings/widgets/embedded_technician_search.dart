import 'dart:async';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:abo_glumbo_bbk/utils/poppins_font.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EmbeddedTechnicianSearch extends StatefulWidget {
  final String bookingRequestId;
  final Function(UserModel) onTechnicianSelected;

  const EmbeddedTechnicianSearch({
    super.key,
    required this.bookingRequestId,
    required this.onTechnicianSelected,
  });

  @override
  State<EmbeddedTechnicianSearch> createState() =>
      _EmbeddedTechnicianSearchState();
}

class _EmbeddedTechnicianSearchState extends State<EmbeddedTechnicianSearch>
    with SingleTickerProviderStateMixin {
  late String _currentRequestId;
  Timer? _countdownTimer;
  int _secondsRemaining = 120;
  int _elapsedSeconds = 0;
  bool _isSearchingAgain = false;
  late AnimationController _pulseController;
  StreamSubscription<DocumentSnapshot>? _requestSubscription;
  Map<String, dynamic>? _bookingRequestData;
  List<dynamic> _acceptedTechnicians = [];
  bool _isLoading = true;

  bool _filterByDistance = false;
  bool _filterByRating = false;
  bool _filterByCompletedJobs = false;
  final double _nearbyThresholdKm = 60.0;
  String? _selectedTechnicianUid;

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
        .listen(
          (snapshot) {
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
          },
          onError: (e) {
            debugPrint("Error listening to booking request: $e");
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        );
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
  }

  Future<void> _searchAgain() async {
    setState(() => _isSearchingAgain = true);
    try {
      final docSnap = await AppFirestore.bookingRequestsCollectionRef
          .doc(_currentRequestId)
          .get();
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;

        // Delete old request
        await AppFirestore.bookingRequestsCollectionRef
            .doc(_currentRequestId)
            .delete();

        // Create new request
        final newId = AppFirestore.bookingRequestsCollectionRef.doc().id;
        final newData = Map<String, dynamic>.from(data);
        newData['id'] = newId;
        newData['createdAt'] = Timestamp.now();
        newData['updatedAt'] = Timestamp.now();
        newData['status'] = 'searching';
        newData['acceptedTechnicians'] = [];

        // Exclude the technician who rejected or ignored the rebook
        List<dynamic> rejected = data['rejectedTechnicians'] ?? [];
        if (data['isRebook'] == true && data['rebookTechnicianId'] != null) {
          if (!rejected.contains(data['rebookTechnicianId'])) {
            rejected.add(data['rebookTechnicianId']);
          }
        }
        newData['rejectedTechnicians'] = rejected;
        newData['isRebook'] = false;
        newData['rebookTechnicianId'] = null;

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

  void _selectTechnician(Map<String, dynamic> techData) {
    setState(() {
      _selectedTechnicianUid = techData['uid'];
    });
    final agent = UserModel(
      uid: techData['uid'],
      name: techData['name'],
      phone: techData['phone'],
      profileUrl: techData['profileUrl'],
      role: "agent",
    );
    widget.onTechnicianSelected(agent);
  }

  bool get _allFiltersOff =>
      !_filterByRating && !_filterByCompletedJobs && !_filterByDistance;

  List<dynamic> _applyFiltersAndSort(List<dynamic> workers) {
    List<dynamic> filtered = List<dynamic>.from(workers);

    if (_allFiltersOff) {
      return filtered;
    }

    if (_filterByDistance) {
      filtered = filtered.where((w) {
        final dist = (w['distance'] as num?)?.toDouble() ?? 99999.0;
        return dist <= _nearbyThresholdKm;
      }).toList();
    }

    filtered.sort((a, b) {
      if (_filterByRating) {
        double ratingA = (a['rating'] as num?)?.toDouble() ?? 0.0;
        double ratingB = (b['rating'] as num?)?.toDouble() ?? 0.0;
        int ratingCompare = ratingB.compareTo(ratingA);
        if (ratingCompare != 0) return ratingCompare;
      }

      if (_filterByCompletedJobs) {
        int jobsA = (a['completedJobs'] as num?)?.toInt() ?? 0;
        int jobsB = (b['completedJobs'] as num?)?.toInt() ?? 0;
        int jobsCompare = jobsB.compareTo(jobsA);
        if (jobsCompare != 0) return jobsCompare;
      }

      if (_filterByDistance) {
        double distA = (a['distance'] as num?)?.toDouble() ?? 99999.0;
        double distB = (b['distance'] as num?)?.toDouble() ?? 99999.0;
        int distCompare = distA.compareTo(distB);
        if (distCompare != 0) return distCompare;
      }

      return 0;
    });

    return filtered;
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
                child: Icon(
                  Icons.people_alt_rounded,
                  color: Colors.amber.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.chooseYourTechnician ?? "Choose your technician",
                      style: PoppinsFont.textStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)?.pleaseSelectTechnician ?? "Please select one of the accepted technicians below to continue.",
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
                AppLocalizations.of(context)?.requestExpiresIn ?? "Request expires in:",
                style: DMSansFont.textStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                "${remainingSelectionTime}${AppLocalizations.of(context)!.sText}",
                style: PoppinsFont.textStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: remainingSelectionTime <= 30
                      ? Colors.red
                      : AppColors.primary,
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
      return Center(child: Loader());
    }

    final bool showSearchingHeader = _elapsedSeconds < 120;
    final bool showChooseHeader =
        _elapsedSeconds >= 120 &&
        _elapsedSeconds < 300 &&
        _acceptedTechnicians.isNotEmpty;
    final bool showExpiredScreen =
        _elapsedSeconds >= 300 ||
        (_elapsedSeconds >= 120 && _acceptedTechnicians.isEmpty);

    final String locale = AppLocalizations.of(context)?.localeName ?? 'en';

    return Column(
      children: [
        if (showSearchingHeader) ...[
          _buildPulsingSearchSection(primaryColor),
        ] else if (showChooseHeader) ...[
          _buildChooseHeaderSection(),
        ] else if (showExpiredScreen) ...[
          _buildExpiredSection(),
        ],

        if (!showExpiredScreen && _acceptedTechnicians.isNotEmpty)
          _buildFilterChips(locale),

        if (!showExpiredScreen) Expanded(child: _buildTechniciansListSection()),
      ],
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
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withOpacity(
                        0.1 + (0.15 * _pulseController.value),
                      ),
                    ),
                    child: Icon(
                      Icons.radar_rounded,
                      color: primaryColor,
                      size: 28,
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.lookingForNearbyTechnicians ?? "Looking for nearby technicians...",
                      style: PoppinsFont.textStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)?.pleaseWaitTechniciansHave120s ?? "Please wait, eligible technicians have 120s to accept.",
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
                AppLocalizations.of(context)?.requestExpiresIn ?? "Request expires in:",
                style: DMSansFont.textStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                "${_secondsRemaining}${AppLocalizations.of(context)!.seconds}",
                style: PoppinsFont.textStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _secondsRemaining <= 20
                      ? Colors.red
                      : AppColors.primary,
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
            child: Icon(
              Icons.timer_off_outlined,
              color: Colors.red.shade600,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)?.noTechniciansAccepted ?? "No Technicians Accepted",
            style: PoppinsFont.textStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)?.allTechniciansBusy ?? "All technicians are currently busy or didn't accept in time.",
            textAlign: TextAlign.center,
            style: DMSansFont.textStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSearchingAgain ? null : _searchAgain,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isSearchingAgain
                ? const Loader(color: Colors.white)
                : Text(
                    AppLocalizations.of(context)?.searchAgain ?? "Search Again",
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

  Widget _buildFilterChips(String localeName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: AppLocalizations.of(context)?.highestRating ?? 'Highest Rating',
              icon: Icons.star_rounded,
              isActive: _filterByRating,
              activeColor: Colors.amber,
              onTap: () {
                setState(() {
                  _filterByRating = !_filterByRating;
                  _selectedTechnicianUid = null;
                });
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: AppLocalizations.of(context)?.mostOrders ?? 'Most Orders',
              icon: Icons.workspace_premium_rounded,
              isActive: _filterByCompletedJobs,
              activeColor: AppColors.green2,
              onTap: () {
                setState(() {
                  _filterByCompletedJobs = !_filterByCompletedJobs;
                  _selectedTechnicianUid = null;
                });
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: AppLocalizations.of(context)?.nearest ?? 'Nearest',
              icon: Icons.near_me_rounded,
              isActive: _filterByDistance,
              activeColor: AppColors.secondary,
              onTap: () {
                setState(() {
                  _filterByDistance = !_filterByDistance;
                  _selectedTechnicianUid = null;
                });
              },
            ),
            if (!_allFiltersOff) ...[
              const SizedBox(width: 8),
              _buildClearAllChip(localeName),
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
              color: isActive
                  ? activeColor.withOpacity(0.12)
                  : Colors.grey.shade100,
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
                    color: isActive
                        ? activeColor.withOpacity(0.9)
                        : Colors.grey.shade600,
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

  Widget _buildClearAllChip(String localeName) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _filterByRating = false;
            _filterByCompletedJobs = false;
            _filterByDistance = false;
            _selectedTechnicianUid = null;
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
                AppLocalizations.of(context)?.clear ?? 'Clear',
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
                child: Loader(color: AppColors.primary, size: 25),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)?.waitingForTechniciansToAccept ?? "Waiting for technicians to accept...",
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

    final displayedTechnicians = _applyFiltersAndSort(_acceptedTechnicians);

    if (displayedTechnicians.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            AppLocalizations.of(context)?.noTechniciansMatchFilters ?? "No technicians match the selected filters.",
            textAlign: TextAlign.center,
            style: DMSansFont.textStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            AppLocalizations.of(context)?.acceptedTechniciansCount(displayedTechnicians.length) ?? "Accepted Technicians (${displayedTechnicians.length})",
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
            itemCount: displayedTechnicians.length,
            itemBuilder: (context, index) {
              final tech = displayedTechnicians[index] as Map<String, dynamic>;
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
    final isSelected = _selectedTechnicianUid == tech['uid'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : Colors.black.withOpacity(0.04),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _selectTechnician(tech),
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
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.amber.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: DMSansFont.textStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: AppColors.primary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$completedJobs ${AppLocalizations.of(context)?.jobsCount ?? 'jobs'}",
                            style: DMSansFont.textStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (distance != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: Colors.blue.shade700,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${distance.toStringAsFixed(1)} ${AppLocalizations.of(context)?.km ?? 'km'}",
                          style: DMSansFont.textStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
