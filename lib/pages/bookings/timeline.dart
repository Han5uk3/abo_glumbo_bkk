import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/utils/poppins_font.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

Widget buildBookingTimelineCard(
  BuildContext context,
  TextTheme textTheme,
  ColorScheme colorScheme,
  bool isWarranty,
  BookingModel booking,
) {
  return FutureBuilder<String?>(
    future: isWarranty
        ? _fetchWarrantyTechnicianName(booking)
        : Future.value(null),
    builder: (context, snapshot) {
      final workerName =
          snapshot.data ?? AppLocalizations.of(context)!.unknownTechnician;
      List<Map<String, dynamic>> timelineItems = [];

      if (isWarranty) {
        // ==========================================
        // WARRANTY BOOKING TIMELINE ONLY
        // ==========================================
        // Shows complete warranty timeline without date filtering

        // Created (original booking)
        if (booking.createdAt != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.createdAt,
            'time': _formatDateLocalized(booking.createdAt!.toDate(), context),
            'description': AppLocalizations.of(
              context,
            )!.youSubmittedTheBookingRequest,
            'status': 'completed',
            'date': booking.createdAt!.toDate(),
          });
        }

        // Original service completed
        if (booking.completedAt != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.originalServiceCompleted,
            'time': _formatDateLocalized(
              booking.completedAt!.toDate(),
              context,
            ),
            'description': AppLocalizations.of(
              context,
            )!.serviceHasBeenSuccessfullyCompleted,
            'status': 'completed',
            'date': booking.completedAt!.toDate(),
          });
        }

        // Warranty requested
        if (booking.warranty?.requestedOn != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.warrantyRepairRequested,
            'time': _formatDateLocalized(
              booking.warranty!.requestedOn!,
              context,
            ),
            'description': AppLocalizations.of(
              context,
            )!.customerRequestedRepairUnderWarranty,
            'status': 'completed',
            'date': booking.warranty!.requestedOn!,
          });
        }

        // Warranty accepted
        if (booking.warranty?.acceptedAt != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.warrantyRepairAccepted,
            'time': _formatDateLocalized(
              booking.warranty!.acceptedAt!,
              context,
            ),
            'description':
                '${AppLocalizations.of(context)!.technicianAcceptedTheRequest}: $workerName',
            'status': 'completed',
            'date': booking.warranty!.acceptedAt!,
          });
        }

        // Warranty tracking started
        if (booking.trackingStartedAt != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.trackingStartedAt,
            'time': _formatDateLocalized(
              booking.trackingStartedAt!.toDate(),
              context,
            ),
            'description': AppLocalizations.of(
              context,
            )!.serviceTrackingInitiated,
            'status': 'completed',
            'date': booking.trackingStartedAt!.toDate(),
          });
        }

        // Warranty tracking stopped
        if (booking.trackingStoppedAt != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.trackingStoppedAt,
            'time': _formatDateLocalized(
              booking.trackingStoppedAt!.toDate(),
              context,
            ),
            'description': AppLocalizations.of(context)!.serviceTrackingStopped,
            'status': 'completed',
            'date': booking.trackingStoppedAt!.toDate(),
          });
        }

        // Warranty completed
        if (booking.warranty?.completedAt != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.warrantyRepairCompleted,
            'time': _formatDateLocalized(
              booking.warranty!.completedAt!,
              context,
            ),
            'description': AppLocalizations.of(
              context,
            )!.technicianCompletedTheRequest,
            'status': 'completed',
            'date': booking.warranty!.completedAt!,
          });
        }

        // Warranty rejected technicians
        if (booking.warranty?.rejectedTechnicians != null &&
            booking.warranty!.rejectedTechnicians!.isNotEmpty) {
          for (var tech in booking.warranty!.rejectedTechnicians!) {
            final rejectedWorkerName =
                tech.name ?? AppLocalizations.of(context)!.unknownTechnician;

            timelineItems.add({
              'title': AppLocalizations.of(context)!.technicianCancelled,
              'time': _formatDateLocalized(tech.rejectedAt!, context),
              'description':
                  '${AppLocalizations.of(context)!.cancelledByTechnician}: $rejectedWorkerName',
              'status': 'cancelled',
              'date': tech.rejectedAt!,
            });
          }
        }

        // Warranty rejected by admin
        if (booking.warranty?.rejectedAt != null) {
          final warrantyStatus =
              booking.warranty?.warrantyStatusCode.toLowerCase() ?? '';
          final isAdminRejection =
              warrantyStatus == 's' || warrantyStatus == 'x';

          timelineItems.add({
            'title': isAdminRejection
                ? AppLocalizations.of(context)!.warrantyRejectedByAdmin
                : AppLocalizations.of(context)!.warrantyRejectedByTechnician,
            'time': _formatDateLocalized(
              booking.warranty!.rejectedAt!,
              context,
            ),
            'description': isAdminRejection
                ? AppLocalizations.of(
                    context,
                  )!.warrantyRequestWasRejectedByAdmin
                : AppLocalizations.of(
                    context,
                  )!.warrantyRequestWasRejectedByTechnician,
            'status': 'rejected',
            'date': booking.warranty!.rejectedAt!,
          });
        }

        // Warranty expired
        if (booking.warranty?.expiredOn != null &&
            booking.warranty?.availability == false &&
            booking.warranty?.warrantyStatusCode == 'E') {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.warrantyExpired,
            'time': _formatDateLocalized(booking.warranty!.expiredOn!, context),
            'description': AppLocalizations.of(
              context,
            )!.warrantyPeriodHasExpired,
            'status': 'rejected',
            'date': booking.warranty!.expiredOn!,
          });
        }
      } else {
        // ==========================================
        // NORMAL BOOKING TIMELINE ONLY
        // ==========================================
        // Does NOT show any warranty-related events

        // Created
        if (booking.createdAt != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.createdAt,
            'time': _formatDateLocalized(booking.createdAt!.toDate(), context),
            'description': AppLocalizations.of(
              context,
            )!.youSubmittedTheBookingRequest,
            'status': 'completed',
            'date': booking.createdAt!.toDate(),
          });
        }

        // Technician Selected
        if (booking.technicianSelectedAt != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.technicianSelected,
            'time': _formatDateLocalized(booking.technicianSelectedAt!.toDate(), context),
            'description': AppLocalizations.of(context)!.youSelectedTechnician,
            'status': 'completed',
            'date': booking.technicianSelectedAt!.toDate(),
          });
        }

        // Confirmed / Assigned
        final dateToUse = booking.assignedAt ?? booking.acceptedAt;
        if (dateToUse != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.acceptedAt,
            'time': _formatDateLocalized(dateToUse.toDate(), context),
            'description': AppLocalizations.of(
              context,
            )!.serviceProviderConfirmedAppointment,
            'status': 'completed',
            'date': dateToUse.toDate(),
          });
        }

        // New Technician Assigned (Reassigned)
        if (booking.reassignedAt != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.newTechnicianAssigned,
            'time': _formatDateLocalized(booking.reassignedAt!.toDate(), context),
            'description': AppLocalizations.of(context)!.serviceProviderConfirmedAppointment,
            'status': 'completed',
            'date': booking.reassignedAt!.toDate(),
          });
        }

        // Tracking started
        if (booking.trackingStartedAt != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.technicianStartedTracking,
            'time': _formatDateLocalized(
              booking.trackingStartedAt!.toDate(),
              context,
            ),
            'description': AppLocalizations.of(
              context,
            )!.yourTechnicianIsOnTheWay,
            'status': 'completed',
            'date': booking.trackingStartedAt!.toDate(),
          });
        }

        // Arrived at location
        if (booking.arrivedAt != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.technicianArrived,
            'time': _formatDateLocalized(
              booking.arrivedAt!.toDate(),
              context,
            ),
            'description': AppLocalizations.of(context)!.technicianArrivedAtLocation,
            'status': 'completed',
            'date': booking.arrivedAt!.toDate(),
          });
        }

        // Completed
        if (booking.completedAt != null) {
          bool isInspection = booking.completionData?.mode == 0;
          timelineItems.add({
            'title': isInspection 
                ? AppLocalizations.of(context)!.inspectionCompleted
                : AppLocalizations.of(context)!.fullServiceCompleted,
            'time': _formatDateLocalized(
              booking.completedAt!.toDate(),
              context,
            ),
            'description': AppLocalizations.of(
              context,
            )!.serviceHasBeenSuccessfullyCompleted,
            'status': 'completed',
            'date': booking.completedAt!.toDate(),
          });
        }

        // Payment Requested
        if (booking.paymentRequestedAt != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.paymentRequested,
            'time': _formatDateLocalized(booking.paymentRequestedAt!.toDate(), context),
            'description': AppLocalizations.of(context)!.waitingForYourPayment,
            'status': 'completed',
            'date': booking.paymentRequestedAt!.toDate(),
          });
        }

        // Payment status (Legacy verification pending)
        if (booking.paidAt != null && booking.paymentCompletedAt == null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.verificationPending,
            'time': _formatDateLocalized(booking.paidAt!.toDate(), context),
            'description':
                AppLocalizations.of(context)!.waitingForTechnicianVerification,
            'status': 'completed',
            'date': booking.paidAt!.toDate(),
          });
        }

        // Payment Completed
        if (booking.paymentCompleted == true) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.paymentCompleted,
            'time': _formatDateLocalized(
              booking.paymentCompletedAt?.toDate() ?? 
              booking.completedAt?.toDate() ?? 
              DateTime.now(), 
              context
            ),
            'description':
                AppLocalizations.of(context)!.paymentSuccessfullyCompleted,
            'status': 'completed',
            'date': booking.paymentCompletedAt?.toDate() ??
                booking.completedAt?.toDate() ??
                DateTime.now(),
          });
        }

        // Reviewed
        if (booking.review != null && booking.review!.createdAt != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.review,
            'time': _formatDateLocalized(booking.review!.createdAt!.toDate(), context),
            'description': AppLocalizations.of(context)!.reviewSubmittedSuccessfully,
            'status': 'completed',
            'date': booking.review!.createdAt!.toDate(),
          });
        }

        // Rejected by Admin
        if (booking.bookingStatusCode.toLowerCase() == 'r' && (booking.rejectedBy == 'Admin' || booking.rejectedBy == null)) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.cancelledByAdmin,
            'time': _formatDateLocalized(booking.rejectedAt?.toDate() ?? booking.updatedAt?.toDate() ?? DateTime.now(), context),
            'description': AppLocalizations.of(
              context,
            )!.bookingCancelledByAdmin,
            'status': 'rejected',
            'date': booking.rejectedAt?.toDate() ?? booking.updatedAt?.toDate() ?? DateTime.now(),
          });
        } else if (booking.bookingStatusCode.toLowerCase() == 'r' && booking.rejectedBy != 'Admin' && booking.rejectedBy != null) {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.technicianCancelled,
            'time': _formatDateLocalized(booking.rejectedAt?.toDate() ?? booking.updatedAt?.toDate() ?? DateTime.now(), context),
            'description': AppLocalizations.of(context)!.cancelledByTechnician,
            'status': 'cancelled',
            'date': booking.rejectedAt?.toDate() ?? booking.updatedAt?.toDate() ?? DateTime.now(),
          });
        }

        // Cancelled by customer
        if (booking.bookingStatusCode.toLowerCase() == 'xc') {
          timelineItems.add({
            'title': AppLocalizations.of(context)!.cancelledByYou,
            'time': _formatDateLocalized(
              booking.cancelledAt?.toDate() ?? DateTime.now(),
              context,
            ),
            'description': AppLocalizations.of(
              context,
            )!.youCancelledThisBooking,
            'status': 'rejected',
            'date': booking.cancelledAt?.toDate() ?? DateTime.now(),
          });
        }

        // Worker cancellations (Technician declined/cancelled)
        if (booking.cancelledWorkers.isNotEmpty) {
          for (var worker in booking.cancelledWorkers) {
            final workerName = worker.agentName.isNotEmpty
                ? worker.agentName
                : AppLocalizations.of(context)!.unknownTechnician;

            timelineItems.add({
              'title': AppLocalizations.of(context)!.technicianCancelled,
              'time': _formatDateLocalized(
                worker.cancelledAt.toDate(),
                context,
              ),
              'description':
                  '${AppLocalizations.of(context)!.cancelledByTechnician}: $workerName',
              'status': 'cancelled',
              'date': worker.cancelledAt.toDate(),
            });
          }
        }
      }
      // Counter Proposal Started
      if (booking.counterProposalStartedAt != null) {
        final eventDate = booking.counterProposalStartedAt!.toDate();
        timelineItems.add({
          'title': AppLocalizations.of(context)!.counterProposalStarted,
          'time': _formatDateLocalized(eventDate, context),
          'description': AppLocalizations.of(context)!.counterOfferSent,
          'status': 'completed',
          'date': eventDate,
        });
      }

      // Counter Proposal Accepted
      if (booking.counterProposalAcceptedAt != null) {
        final eventDate = booking.counterProposalAcceptedAt!.toDate();
        timelineItems.add({
          'title': AppLocalizations.of(context)!.counterProposalAccepted,
          'time': _formatDateLocalized(eventDate, context),
          'description': AppLocalizations.of(context)!.counterOfferResponse,
          'status': 'completed',
          'date': eventDate,
        });
      }

      // Sort ALL events by date
      timelineItems.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
      );

      // Check if there is any rejection (admin rejected or customer cancelled)
      // If so, don't add any more entries
      bool hasRejectionOrCancellation =
          timelineItems.any((item) => item['status'] == 'rejected');

      // Add current/pending status only if there's no rejection/cancellation
      if (!hasRejectionOrCancellation) {
        bool isInProgress =
            booking.trackingStartedAt != null &&
            booking.trackingStoppedAt == null;

        if (isWarranty) {
          if (booking.warranty?.completedAt == null &&
              booking.warranty?.rejectedAt == null &&
              booking.warranty!.warrantyStatusCode.toUpperCase() != 'A') {
            // Check if there are rejected technicians
            bool hasTechnicianRejection =
                booking.warranty?.rejectedTechnicians != null &&
                booking.warranty!.rejectedTechnicians!.isNotEmpty;

            if (isInProgress) {
              timelineItems.add({
                'title': AppLocalizations.of(context)!.serviceInProgress,
                'time': AppLocalizations.of(context)!.current,
                'description': AppLocalizations.of(
                  context,
                )!.serviceIsCurrentlyBeingPerformed,
                'status': 'current',
                'date': DateTime.now(),
              });
            } else if (booking.warranty?.acceptedAt != null) {
              timelineItems.add({
                'title': AppLocalizations.of(
                  context,
                )!.waitingForServiceProvider,
                'time': AppLocalizations.of(context)!.pending,
                'description': AppLocalizations.of(
                  context,
                )!.waitingForTechnicianToStartService,
                'status': 'current',
                'date': DateTime.now(),
              });
            } else if (hasTechnicianRejection) {
              // If technician rejected, show "Waiting for Admin" instead
              timelineItems.add({
                'title': AppLocalizations.of(context)!.waitingForAdmin,
                'time': AppLocalizations.of(context)!.pending,
                'description': AppLocalizations.of(
                  context,
                )!.waitingForAdminToReassign,
                'status': 'current',
                'date': DateTime.now(),
              });
            } else {
              timelineItems.add({
                'title': AppLocalizations.of(
                  context,
                )!.waitingForServiceProvider,
                'time': AppLocalizations.of(context)!.pending,
                'description': AppLocalizations.of(
                  context,
                )!.waitingForServiceProviderResponse,
                'status': 'current',
                'date': DateTime.now(),
              });
            }
          }
        } else {
          bool isAdminRejection = booking.bookingStatusCode.toLowerCase() == 'r' &&
              (booking.rejectedBy == 'Admin' || booking.rejectedBy == null);

          if (booking.completedAt == null &&
              booking.rejectedAt == null &&
              booking.bookingStatusCode.toLowerCase() != 'xc' &&
              !isAdminRejection) {
            if (isInProgress) {
              timelineItems.add({
                'title': AppLocalizations.of(context)!.serviceInProgress,
                'time': AppLocalizations.of(context)!.current,
                'description': AppLocalizations.of(
                  context,
                )!.serviceIsCurrentlyBeingPerformed,
                'status': 'current',
                'date': DateTime.now(),
              });
            } else if (booking.assignedAt != null || booking.acceptedAt != null) {
              timelineItems.add({
                'title': AppLocalizations.of(
                  context,
                )!.waitingForServiceProvider,
                'time': AppLocalizations.of(context)!.pending,
                'description': AppLocalizations.of(
                  context,
                )!.waitingForTechnicianToStartService,
                'status': 'current',
                'date': DateTime.now(),
              });
            } else {
              timelineItems.add({
                'title': AppLocalizations.of(context)!.waitingForAcceptance,
                'time': AppLocalizations.of(context)!.pending,
                'description': AppLocalizations.of(
                  context,
                )!.waitingForServiceProviderResponse,
                'status': 'current',
                'date': DateTime.now(),
              });
            }
          }
        }
      }

      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.timeline,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)!.bookingTimeline,
                    style: PoppinsFont.textStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...timelineItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isLast = index == timelineItems.length - 1;

                return _buildTimelineItem(
                  title: item['title']!,
                  time: item['time']!,
                  description: item['description']!,
                  status: item['status']!,
                  isLast: isLast,
                  colorScheme: colorScheme,
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}

Future<String?> _fetchWarrantyTechnicianName(BookingModel booking) async {
  if (booking.warranty?.assignedTechnicianId == null) return null;

  // Check if the assigned technician is the same as the booking agent
  if (booking.agent?.uid == booking.warranty!.assignedTechnicianId) {
    return booking.agent?.name;
  }

  try {
    final doc = await AppFirestore.usersCollectionRef
        .doc(booking.warranty!.assignedTechnicianId)
        .get();
    if (doc.exists) {
      return UserModel.fromDocumentSnapshot(doc).name;
    }
  } catch (e) {
    debugPrint('Error fetching technician name: $e');
  }
  return null;
}

// Helper method to format dates (you might already have this in your project)
String _formatDateLocalized(DateTime date, BuildContext context) {
  return formatDateLocalized(date, context);
}

String formatDateLocalized(DateTime date, BuildContext context) {
  final locale = Localizations.localeOf(context).languageCode;
  String formatted;
  if (locale == 'ar') {
    // Use Arabic date format and convert numbers
    formatted = intl.DateFormat('EEEE، d MMMM y - h:mm a', 'ar').format(date);
    // Convert Western digits to Arabic-Indic digits
    formatted = formatted.replaceAllMapped(RegExp(r'[0-9]'), (match) {
      const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      return arabicNumbers[int.parse(match.group(0)!)];
    });
  } else if (locale == 'ur') {
    // Use Urdu date format
    formatted = intl.DateFormat('EEEE، d MMMM y - h:mm a', 'ur').format(date);
  } else {
    formatted = intl.DateFormat('EEE, MMM d, y - h:mm a').format(date);
  }
  return formatted;
}

Widget _buildTimelineItem({
  required String title,
  required String time,
  required String description,
  required String status,
  required bool isLast,
  required ColorScheme colorScheme,
}) {
  Color getStatusColor() {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'current':
        return colorScheme.primary;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.orange;
      case 'pending':
      default:
        return colorScheme.outline;
    }
  }

  IconData getStatusIcon() {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'current':
        return Icons.radio_button_checked;
      case 'rejected':
        return Icons.cancel;
      case 'cancelled':
        return Icons.block;
      case 'pending':
      default:
        return Icons.radio_button_unchecked;
    }
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Timeline indicator
      Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: getStatusColor().withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(getStatusIcon(), size: 20, color: getStatusColor()),
          ),
          if (!isLast)
            Container(
              width: 2,
              height: 40,
              color: colorScheme.outline.withOpacity(0.3),
              margin: const EdgeInsets.symmetric(vertical: 4),
            ),
        ],
      ),
      const SizedBox(width: 16),

      // Timeline content
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: PoppinsFont.textStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: status == 'pending'
                          ? colorScheme.onSurface.withOpacity(0.6)
                          : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: PoppinsFont.textStyle(
                  fontSize: 12,
                  color: status == 'pending'
                      ? colorScheme.onSurface.withOpacity(0.4)
                      : colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                time,
                style: PoppinsFont.textStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
