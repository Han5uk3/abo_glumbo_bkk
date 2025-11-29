import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/common_widgets/service_booking_tile.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';

import 'package:abo_glumbo_bbk/pages/bookings/bloc/booking_bloc.dart';
import 'package:abo_glumbo_bbk/sheets/write_review.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:abo_glumbo_bbk/utils/dm_sans_font.dart';
import 'package:shimmer/shimmer.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  @override
  void initState() {
    context.read<BookingBloc>().add(
      LoadBookingsEvent(LocalStoreHelper.getUID() ?? ''),
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<BookingBloc>().add(
          RefreshBookingsEvent(LocalStoreHelper.getUID() ?? ''),
        );
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            titleSpacing: 16,
            title: Text(AppLocalizations.of(context)?.myBooking ?? ''),
            pinned: true,
            primary: true,
            centerTitle: true,
          ),
          // Wrap filter tabs in BlocBuilder
          BlocBuilder<BookingBloc, BookingState>(
            builder: (context, state) {
              if (state is BookingsLoading || state is BookingInitial) {
                return _buildFilterTabsShimmer();
              }
              return SliverToBoxAdapter(
                child: _buildFilterTabs(context, state),
              );
            },
          ),
          // State-dependent content
          BlocBuilder<BookingBloc, BookingState>(
            builder: (context, state) => _buildContent(context, state),
          ),
        ],
      ),
    );
  }

  // Shimmer loader for filter tabs
  Widget _buildFilterTabsShimmer() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SizedBox(
          height: 34,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    width: 70,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Extract filter tabs widget
  Widget _buildFilterTabs(BuildContext context, BookingState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 34,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: BookingStatusType.values.length,
          itemBuilder: (context, index) {
            BookingStatusType status = BookingStatusType.values[index];
            final selectedStatus = _getSelectedStatus(state);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  context.read<BookingBloc>().add(ChangeStatusEvent(status));
                },
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: selectedStatus == status
                        ? Border.all(width: 1, color: AppColors.blue1)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    color: AppColors.blue1.withOpacity(0.04),
                  ),
                  child: Text(
                    _getLocalizedStatusNames(status.name, context),
                    style: DMSansFont.textStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: selectedStatus == status
                          ? AppColors.blue1
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, BookingState state) {
    if (state is BookingsLoading || state is BookingInitial) {
      return SliverToBoxAdapter(
        child: Center(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Loader(color: AppColors.primary),
          ),
        ),
      );
    } else if (state is BookingsError) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Loader(color: AppColors.primary),
            ),
          ),
        ),
      );
    } else if (state is BookingsLoaded) {
      final filteredBookings = state.filteredBookings;

      if (filteredBookings.isEmpty) {
        return SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 120,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _getEmptyStateIcon(state.selectedStatus.name),
                        size: 70,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context)?.noBookingFound(
                          _getLocalizedNormalStatusNames(
                            state.selectedStatus.name,
                            context,
                          ),
                        ) ??
                        '',
                    textAlign: TextAlign.center,
                    style: DMSansFont.textStyle(
                      color: Colors.grey.shade400,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return SliverList.builder(
        itemCount: filteredBookings.length,
        itemBuilder: (context, index) {
          final booking = filteredBookings[index];
          return ServiceBookingTile(
            booking: booking,
            onRefresh: () {
              context.read<BookingBloc>().add(
                RefreshBookingsEvent(LocalStoreHelper.getUID() ?? ''),
              );
            },
            onReviewButtonPressed: () async {
              bool? reload = await showWriteReviewBottomSheet(
                context,
                booking: booking,
              );
              if (reload == true) {
                context.read<BookingBloc>().add(
                  RefreshBookingsEvent(LocalStoreHelper.getUID() ?? ''),
                );
              }
            },
            isWarranty: state.selectedStatus == BookingStatusType.onWarranty,
          );
        },
      );
    }

    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  // Rest of your helper methods remain the same...
  BookingStatusType _getSelectedStatus(BookingState state) {
    if (state is BookingsLoaded) {
      return state.selectedStatus;
    } else if (state is BookingsError) {
      return state.selectedStatus;
    }
    return BookingStatusType.pending;
  }

  String _getLocalizedStatusNames(String name, BuildContext context) {
    AppLocalizations locn = AppLocalizations.of(context)!;
    switch (name) {
      case "pending":
        return locn.pending.toUpperCase();
      case "confirmed":
        return locn.confirmed.toUpperCase();
      case "completed":
        return locn.completed.toUpperCase();
      case "pendingPayment":
        return locn.paymentPending.toUpperCase();
      case "cancelled":
        return locn.cancelled.toUpperCase();
      case "onWarranty":
        return locn.onWarranty.toUpperCase();
      default:
        return "Error";
    }
  }

  String _getLocalizedNormalStatusNames(String name, BuildContext context) {
    AppLocalizations locn = AppLocalizations.of(context)!;
    switch (name) {
      case "pending":
        return locn.pending.toLowerCase();
      case "confirmed":
        return locn.confirmed.toLowerCase();
      case "completed":
        return locn.completed.toLowerCase();
      case "pendingPayment":
        return locn.paymentPending.toLowerCase();
      case "cancelled":
        return locn.cancelled.toLowerCase();
      case "onWarranty":
        return locn.onWarranty.toLowerCase();
      default:
        return "Error";
    }
  }

  IconData _getEmptyStateIcon(String name) {
    switch (name) {
      case "pending":
        return Icons.schedule_outlined;
      case "confirmed":
        return Icons.event_available_outlined;
      case "pendingPayment":
        return Icons.wallet;
      case "completed":
        return Icons.task_alt_outlined;
      case "cancelled":
        return Icons.event_busy_outlined;
      default:
        return Icons.calendar_today_outlined;
    }
  }

  // String _getEmptyStateMessage(String name, BuildContext context) {
  //   switch (name) {
  //     case "pending":
  //       return AppLocalizations.of(context)?.noPendingBookingsMessage ??
  //           'You have no pending bookings at the moment. New booking requests will appear here.';
  //     case "confirmed":
  //       return AppLocalizations.of(context)?.noConfirmedBookingsMessage ??
  //           'No confirmed bookings yet. Once technicians accept your requests, they will show up here.';
  //     case "completed":
  //       return AppLocalizations.of(context)?.noCompletedBookingsMessage ??
  //           'Your completed bookings will appear here once services are finished.';
  //     case "pendingPayment":
  //       return AppLocalizations.of(context)?.noPendingPaymentBookingsMessage ??
  //           'You have no pending payment bookings. This is great!';
  //     case "cancelled":
  //       return AppLocalizations.of(context)?.noCancelledBookingsMessage ??
  //           'You have no cancelled bookings. This is great!';
  //     default:
  //       return AppLocalizations.of(context)?.noBookingsMessage ??
  //           'You have no bookings at the moment.';
  //   }
  // }
}
