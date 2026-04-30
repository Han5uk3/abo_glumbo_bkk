import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:intl/intl.dart';

class InvoiceService {
  static Future<void> generateAndShowInvoice(BookingModel booking) async {
    final pdf = pw.Document();
    
    // Load logo if exists
    pw.ImageProvider? logo;
    try {
      final logoData = await rootBundle.load('assets/images/app_icon.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Logo not found, proceed without it
    }

    final data = booking.completionData;
    if (data == null) return;

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final completedAtStr = booking.completedAt != null 
        ? dateFormat.format(booking.completedAt!.toDate()) 
        : 'N/A';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logo != null) 
                    pw.Container(width: 80, height: 80, child: pw.Image(logo)),
                  pw.SizedBox(height: 10),
                  pw.Text("Abo Glumbo", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Service Booking Invoice"),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("INVOICE", style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                  pw.SizedBox(height: 10),
                  pw.Text("Invoice #: ${booking.id.substring(0, 8).toUpperCase()}"),
                  pw.Text("Date: ${dateFormat.format(DateTime.now())}"),
                  pw.Text("Status: PAID", style: pw.TextStyle(color: PdfColors.green, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 40),

          pw.SizedBox(height: 40),
          
          // Get the address used for this booking
          () {
            final address = booking.customer.addresses.firstWhere(
              (a) => a.id == booking.selectedAddressId,
              orElse: () => booking.customer.addresses.firstWhere(
                (a) => a.isSelected ?? false,
                orElse: () => booking.customer.addresses.isNotEmpty 
                    ? booking.customer.addresses.first 
                    : AddressModel(id: '', fullName: '', buildingNumber: '', phoneNumber: ''),
              ),
            );
            
            return pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("BILL TO:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(booking.customer.name ?? "Valued Customer"),
                      pw.Text(booking.customer.phone ?? ""),
                      pw.Text("${address.buildingNumber}${address.streetName != null ? ', ${address.streetName}' : ''}"),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("BOOKING DETAILS:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text("Service: ${booking.service.name}"),
                      pw.Text("Completed At: $completedAtStr"),
                      pw.Text("Payment Mode: ${booking.paymentModeCode.toUpperCase()}"),
                      if (booking.transactionId != null) pw.Text("Transaction ID: ${booking.transactionId}"),
                    ],
                  ),
                ),
              ],
            );
          }(),
          pw.SizedBox(height: 40),

          // Items Table
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
            cellHeight: 30,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            headers: ['Description', 'Quantity', 'Unit Price', 'Amount'],
            data: [
              ...data.serviceItems.map((item) => [
                item.name,
                item.quantity.toStringAsFixed(0),
                "SAR ${item.price.toStringAsFixed(2)}",
                "SAR ${(item.quantity * item.price).toStringAsFixed(2)}",
              ]),
              if (data.inspectionFee > 0) 
                ['Inspection Fee', '1', "SAR ${data.inspectionFee.toStringAsFixed(2)}", "SAR ${data.inspectionFee.toStringAsFixed(2)}"],
            ],
          ),
          pw.SizedBox(height: 20),

          // Totals
          pw.Row(
            children: [
              pw.Spacer(flex: 2),
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Subtotal:"),
                        pw.Text("SAR ${data.serviceCost.toStringAsFixed(2)}"),
                      ],
                    ),
                    if (data.inspectionFee > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("Inspection Fee:"),
                          pw.Text("SAR ${data.inspectionFee.toStringAsFixed(2)}"),
                        ],
                      ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Total:", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text("SAR ${data.totalCost.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          pw.SizedBox(height: 60),
          pw.Center(
            child: pw.Text("Thank you for choosing Abo Glumbo!", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey)),
          ),
        ],
      ),
    );

    // Show preview/print dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) => pdf.save(),
      name: 'Invoice_${booking.id.substring(0, 8)}',
    );
  }
}
