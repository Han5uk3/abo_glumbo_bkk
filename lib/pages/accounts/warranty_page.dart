import 'package:abo_glumbo_bbk/common_widgets/warranty_tile.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WarrantyPage extends StatefulWidget {
  final CustomerModel customerData;

  const WarrantyPage({super.key, required this.customerData});

  @override
  State<WarrantyPage> createState() => _WarrantyPageState();
}

class _WarrantyPageState extends State<WarrantyPage> {
  Future<bool> _showWarrantyConfirmationDialog(BuildContext context) async {
    final locale = AppLocalizations.of(context)!;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(locale.repairUnderWarranty),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(locale.warrantyAlertContent, style: TextStyle(fontSize: 15)),
              SizedBox(height: 12),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                locale.cancel,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                locale.confirm,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(locale.repairUnderWarranty),
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: AppServices.getBookingsWithWarranty(
          widget.customerData.uid ?? "",
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final bookings = snapshot.data as List<BookingModel>?;
          return Column(
            children: [
              // Warranty Information Header
              Card(
                margin: const EdgeInsets.all(16),
                elevation: 2,
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: Text(
                    locale.warrantyInformation,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // What's Covered Section
                          Text(
                            "✓ ${locale.whatsCovered} ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• ${locale.issueone}\n'
                            '• ${locale.issuetwo}\n'
                            '• ${locale.issuethree}\n'
                            '• ${locale.issuefour}',
                            style: TextStyle(fontSize: 13, height: 1.5),
                          ),
                          const SizedBox(height: 16),

                          // What's NOT Covered Section
                          Text(
                            "✗ ${locale.whatsNotCovered} ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• ${locale.notissueone}\n'
                            '• ${locale.notissuetwo}\n'
                            '• ${locale.notissuethree}\n'
                            '• ${locale.notissuefour}\n'
                            '• ${locale.notissuefive}',
                            style: TextStyle(fontSize: 13, height: 1.5),
                          ),
                          const SizedBox(height: 12),

                          // Additional Info
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    locale.claimText,
                                    style: TextStyle(fontSize: 12),
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

              // Bookings List
              Expanded(
                child: ListView.builder(
                  itemCount: bookings?.length ?? 0,
                  itemBuilder: (context, index) {
                    final booking = bookings?[index];
                    return WarrantyTile(
                      booking:
                          booking ??
                          BookingModel(
                            id: '',
                            service: ServiceModel(),
                            bookingDateTime: DateTime.now() as Timestamp,
                            bookingStatusCode: '',
                            notes: '',
                            issueImage: '',
                            issueVideo: '',
                            customer: CustomerModel(),
                            paymentModeCode: '',
                          ),
                      isRequested: booking?.warranty?.availability ?? false,
                      onPressed: () async {
                        final confirmed = await _showWarrantyConfirmationDialog(
                          context,
                        );
                        if (confirmed && booking != null) {
                          AppServices.requestWarrantyRepair(booking);

                          // Show success message
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  locale.warrantyRepairSubmittedSuccessfully,
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
