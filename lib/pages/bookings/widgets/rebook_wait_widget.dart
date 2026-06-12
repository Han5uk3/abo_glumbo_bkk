import 'dart:async';
import 'dart:io';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/job_request.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RebookWaitWidget extends StatefulWidget {
  final UserModel technician;
  final ServiceModel service;
  final AddressModel selectedAddress;
  final DateTime selectedDate;
  final Map timeSlot;
  final String? notes;
  final File? issueImageFile;
  final File? issueVideoFile;
  final Function(UserModel, DateTime?) onAccepted;
  final Function(String) onBroadcastIdCreated;
  final Function() onFailed;

  const RebookWaitWidget({
    super.key,
    required this.technician,
    required this.service,
    required this.selectedAddress,
    required this.selectedDate,
    required this.timeSlot,
    required this.onAccepted,
    required this.onBroadcastIdCreated,
    required this.onFailed,
    this.notes,
    this.issueImageFile,
    this.issueVideoFile,
  });

  @override
  State<RebookWaitWidget> createState() => _RebookWaitWidgetState();
}

class _RebookWaitWidgetState extends State<RebookWaitWidget>
    with WidgetsBindingObserver {
  String? _requestId;
  int _timerSeconds = 120;
  Timer? _timer;
  StreamSubscription? _offersSubscription;
  bool _isInitializing = true;
  bool _hasResponded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startFlow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _offersSubscription?.cancel();
    _cleanupRequest();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _cleanupRequest();
    }
  }

  void _cleanupRequest() {
    if (_requestId != null && !_hasResponded) {
      AppServices.deleteJobRequest(_requestId!);
    }
  }

  Future<void> _startFlow() async {
    try {
      if (widget.technician.isOnline != true) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
        return;
      }

      // 1. Handle File Uploads
      String? issueImageUrl;
      String? issueVideoUrl;
      final uid = LocalStoreHelper.getUID();

      if (widget.issueImageFile != null) {
        String fileName =
            'users/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        final uploadTask = storageRef.putFile(widget.issueImageFile!);
        final snapshot = await uploadTask;
        issueImageUrl = await snapshot.ref.getDownloadURL();
      }
      if (widget.issueVideoFile != null) {
        String fileName =
            'users/$uid/${DateTime.now().millisecondsSinceEpoch}.mp4';
        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        final uploadTask = storageRef.putFile(
          widget.issueVideoFile!,
          SettableMetadata(contentType: 'video/mp4'),
        );
        final snapshot = await uploadTask;
        issueVideoUrl = await snapshot.ref.getDownloadURL();
      }

      // 2. Create Job Request
      final requestId = AppFirestore.jobRequestsCollectionRef.doc().id;
      final now = Timestamp.now();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(seconds: 120)),
      );

      final request = JobRequestModel(
        id: requestId,
        service: widget.service,
        customer: await _fetchCustomerData(),
        address: widget.selectedAddress,
        notes: widget.notes ?? '',
        issueImage: issueImageUrl ?? "",
        issueVideo: issueVideoUrl ?? "",
        createdAt: now,
        expiresAt: expiresAt,
        isOnHour: true, // Rebooking is always treated as intentional wait
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

      await AppServices.broadcastJobRequest(
        request: request,
        workerIds: [widget.technician.uid!],
        isRebook: true,
      );

      if (mounted) {
        setState(() {
          _requestId = requestId;
          _isInitializing = false;
        });
        widget.onBroadcastIdCreated(requestId);
        _startTimer();
        _listenToOffers();
      }
    } catch (e) {
      debugPrint("Error starting rebook flow: $e");
      widget.onFailed();
    }
  }

  Future<dynamic> _fetchCustomerData() async {
    final uid = LocalStoreHelper.getUID();
    final doc = await AppFirestore.customersCollectionRef.doc(uid).get();
    return doc.data();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        _timer?.cancel();
        if (!_hasResponded) {
          widget.onFailed();
        }
      }
    });
  }

  void _listenToOffers() {
    _offersSubscription = AppServices.listenToJobOffersForRequest(_requestId!)
        .listen((offers) {
          if (offers.isEmpty) return;

          final offer = offers.first; // Should only be one
          final status = offer['status'];

          if (status == 'accepted_by_technician') {
            _hasResponded = true;
            widget.onAccepted(widget.technician, null);
          } else if (status == 'declined' || status == 'expired') {
            _hasResponded = true;
            widget.onFailed();
          }
          // 'counter_offered' will be handled by UI
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Center(child: Loader());
    }

    if (widget.technician.isOnline != true) {
      return _buildOfflineUI();
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AppServices.listenToJobOffersForRequest(_requestId!),
      builder: (context, snapshot) {
        final offers = snapshot.data ?? [];
        final counterOffer = offers.firstWhere(
          (o) => o['status'] == 'counter_offered',
          orElse: () => {},
        );

        if (counterOffer.isNotEmpty) {
          return _buildCounterOfferUI(counterOffer);
        }

        return _buildWaitingUI();
      },
    );
  }

  Widget _buildWaitingUI() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage:
                widget.technician.profileUrl != null &&
                    widget.technician.profileUrl!.isNotEmpty
                ? CachedNetworkImageProvider(widget.technician.profileUrl!)
                : null,
            child:
                widget.technician.profileUrl == null ||
                    widget.technician.profileUrl!.isEmpty
                ? const Icon(Icons.person, size: 50)
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            widget.technician.name ?? "",
            style: DMSansFont.textStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.waitingForRequestedTechnician,
            style: DMSansFont.textStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          CircularProgressIndicator(
            value: _timerSeconds / 120,
            strokeWidth: 6,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            "${_timerSeconds}s",
            style: DMSansFont.textStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterOfferUI(Map<String, dynamic> offer) {
    final l10n = AppLocalizations.of(context)!;
    final proposedTime = offer['proposedTime'] as Timestamp;
    final locale = l10n.localeName;

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_repeat_rounded, size: 48, color: Colors.blue[700]),
            const SizedBox(height: 16),
            Text(
              l10n.counterOfferFromTechnician,
              style: DMSansFont.textStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.technicianProposedNewTime,
              textAlign: TextAlign.center,
              style: DMSansFont.textStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                DateFormat.yMMMMd(
                  locale,
                ).add_jm().format(proposedTime.toDate()),
                style: DMSansFont.textStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _hasResponded = true;
                      AppServices.respondToJobOfferForRequest(
                        requestId: _requestId!,
                        offerId: offer['id'],
                        status: 'declined',
                      );
                      widget.onFailed();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(l10n.rejectOffer),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _hasResponded = true;
                      AppServices.respondToJobOfferForRequest(
                        requestId: _requestId!,
                        offerId: offer['id'],
                        status: 'accepted_by_customer',
                      );
                      // Update request time
                      AppFirestore.jobRequestsCollectionRef
                          .doc(_requestId)
                          .update({'bookingDateTime': proposedTime});
                      widget.onAccepted(
                        widget.technician,
                        proposedTime.toDate(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(l10n.acceptOffer),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineUI() {
    final l10n = AppLocalizations.of(context)!;
    final locale = l10n.localeName;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage:
                widget.technician.profileUrl != null &&
                    widget.technician.profileUrl!.isNotEmpty
                ? CachedNetworkImageProvider(widget.technician.profileUrl!)
                : null,
            child:
                widget.technician.profileUrl == null ||
                    widget.technician.profileUrl!.isEmpty
                ? const Icon(Icons.person, size: 50)
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            widget.technician.name ?? "",
            style: DMSansFont.textStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            locale == 'ar'
                ? 'الفني غير متصل حالياً'
                : locale == 'ur'
                ? 'ٹیکنیشن اس وقت آف لائن ہے'
                : "Technician is currently offline",
            style: DMSansFont.textStyle(fontSize: 16, color: Colors.red[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              _hasResponded = true;
              widget.onFailed();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              locale == 'ar'
                  ? 'المتابعة للبحث العادي'
                  : locale == 'ur'
                  ? 'عام تلاش جاری رکھیں'
                  : "Continue with normal search",
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
}
