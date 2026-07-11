import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:intl/intl.dart';

import 'package:flutter/widgets.dart' as material_widgets;
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/models/invoice.dart';
import 'package:http/http.dart' as http;

class InvoiceService {
  static Future<pw.Document?> _buildInvoiceDocument(
    material_widgets.BuildContext context,
    BookingModel booking,
  ) async {
    final loc = AppLocalizations.of(context)!;
    final pdf = pw.Document();

    // Load logo if exists
    pw.ImageProvider? logo;
    try {
      final logoData = await rootBundle.load('assets/images/app_icon.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Logo not found, proceed without it
    }

    final data =
        booking.completionData ??
        CompletionDataModel(
          fileUrls: [],
          mode: 0,
          paymentMethod: booking.paymentModeCode,
          serviceCost: 0,
          totalCost: 0,
          serviceItems: [],
          inspectionFee: booking.effectiveInspectionFee,
        );

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final completedAtStr = booking.completedAt != null
        ? dateFormat.format(booking.completedAt!.toDate())
        : ((loc.localeName == 'ar')
              ? 'غير متوفر'
              : (loc.localeName == 'ur')
              ? 'دستیاب نہیں'
              : 'N/A');

    final isArabic = loc.localeName == 'ar' || loc.localeName == 'ur';
    final ttf = await PdfGoogleFonts.cairoRegular();
    final ttfBold = await PdfGoogleFonts.cairoBold();

    final theme = pw.ThemeData.withFont(base: ttf, bold: ttfBold);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
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
                  pw.Text(
                    "Abo Glumbo",
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(loc.invoiceTitle),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    loc.invoiceWord,
                    style: pw.TextStyle(
                      fontSize: 30,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    loc.invoiceNumber(
                      booking.newBookingId ??
                          booking.id.substring(0, 8).toUpperCase(),
                    ),
                  ),
                  pw.Text(loc.dateString(dateFormat.format(DateTime.now()))),
                  pw.Text(
                    loc.statusPaid,
                    style: pw.TextStyle(
                      color: PdfColors.green,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 40),

          pw.SizedBox(height: 40),

          // Get the address used for this booking from the customer data inside the booking
          () {
            final address = booking.customer.addresses.firstWhere(
              (a) => a.isSelected == true,
              orElse: () => booking.customer.addresses.isNotEmpty
                  ? booking.customer.addresses.first
                  : AddressModel(
                      id: '',
                      fullName: '',
                      buildingNumber: '',
                      phoneNumber: '',
                    ),
            );

            final daysDiff =
                booking.warranty?.expiredOn != null &&
                    (booking.warranty?.createdAt != null ||
                        booking.completedAt != null)
                ? booking.warranty!.expiredOn!
                      .difference(
                        booking.warranty!.createdAt ??
                            booking.completedAt!.toDate(),
                      )
                      .inDays
                : 7;

            final warrantyDuration = (loc.localeName == 'ar')
                ? "$daysDiff أيام"
                : (loc.localeName == 'ur')
                ? "$daysDiff دن"
                : "$daysDiff Days";

            return pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        loc.billTo,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        booking.customer.name ??
                            ((loc.localeName == 'ar')
                                ? 'عميلنا العزيز'
                                : (loc.localeName == 'ur')
                                ? 'معزز صارف'
                                : 'Valued Customer'),
                      ),
                      pw.Text(booking.customer.phone ?? ""),
                      pw.Text(booking.customer.email ?? ""),
                      pw.Text(
                        "${address.buildingNumber}${address.streetName != null ? ', ${address.streetName}' : ''}",
                      ),
                      if (address.fullName.isNotEmpty &&
                          address.fullName != booking.customer.name)
                        pw.Text(address.fullName),
                      if (booking.customer.districtName != null ||
                          booking.customer.cityName != null)
                        pw.Text(
                          "${booking.customer.districtName ?? ''}${booking.customer.districtName != null && booking.customer.cityName != null ? ', ' : ''}${booking.customer.cityName ?? ''}",
                        ),
                      if (booking.serviceLocation != null)
                        pw.Text(
                          booking.serviceLocation!.localizedName(
                            loc.localeName,
                          ),
                        ),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        loc.bookingDetailsInvoice,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        loc.serviceLabel(
                          booking.service.nameLocalized(
                                languageCode: loc.localeName,
                              ) ??
                              "",
                        ),
                      ),
                      if (booking.agent?.name != null)
                        pw.Text(loc.technicianLabel(booking.agent!.name!)),
                      if (booking.agent?.phone != null)
                        pw.Text(loc.techPhoneLabel(booking.agent!.phone!)),
                      pw.Text(loc.completedAtLabel(completedAtStr)),
                      pw.Text(loc.warrantyLabel(warrantyDuration)),
                      pw.Text(
                        loc.paymentModeLabel(
                          (booking.paymentModeCode.toUpperCase() == 'C' ||
                                  booking.paymentModeCode.toUpperCase() == 'A')
                              ? (loc.insideApp)
                              : (loc.outsideApp),
                        ),
                      ),
                      if (booking.orderId != null ||
                          booking.transactionId != null)
                        pw.Text(
                          loc.transactionIdLabel(
                            booking.orderId ?? booking.transactionId ?? '',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }(),
          pw.SizedBox(height: 40),

          // Items Table
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
            cellHeight: 30,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            headers: (loc.localeName == 'ar')
                ? ['الوصف', 'الكمية', 'سعر الوحدة', 'المبلغ']
                : (loc.localeName == 'ur')
                ? ['تفصیل', 'مقدار', 'فی اکائی قیمت', 'رقم']
                : ['Description', 'Quantity', 'Unit Price', 'Amount'],
            data: [
              ...data.serviceItems.map(
                (item) => [
                  item.name,
                  item.quantity.toStringAsFixed(0),
                  "${item.price.toStringAsFixed(2)} ${loc.sar}",
                  "${(item.quantity * item.price).toStringAsFixed(2)} ${loc.sar}",
                ],
              ),
              if (data.serviceItems.isEmpty && data.serviceCost > 0)
                [
                  (loc.localeName == 'ar')
                      ? 'تكلفة الخدمة'
                      : (loc.localeName == 'ur')
                      ? 'سروس کی قیمت'
                      : 'Service Cost',
                  '1',
                  "${data.serviceCost.toStringAsFixed(2)} ${loc.sar}",
                  "${data.serviceCost.toStringAsFixed(2)} ${loc.sar}",
                ],
              if (data.inspectionFee > 0)
                [
                  loc.inspectionFee,
                  '1',
                  "${data.inspectionFee.toStringAsFixed(2)} ${loc.sar}",
                  "${data.inspectionFee.toStringAsFixed(2)} ${loc.sar}",
                ],
            ],
          ),
          pw.SizedBox(height: 20),

          // Totals
          pw.Row(
            children: [
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(loc.subtotal),
                        pw.Text(
                          "${data.serviceCost.toStringAsFixed(2)} ${loc.sar}",
                        ),
                      ],
                    ),
                    if (data.inspectionFee > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(loc.inspectionFee),
                          pw.Text(
                            "${data.inspectionFee.toStringAsFixed(2)} ${loc.sar}",
                          ),
                        ],
                      ),
                    if ((booking.service.discountPercentage ?? 0) > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            (loc.localeName == 'ar')
                                ? 'الخصم (${booking.service.discountPercentage}%)'
                                : (loc.localeName == 'ur')
                                ? 'رعایت (${booking.service.discountPercentage}%)'
                                : 'Discount (${booking.service.discountPercentage}%)',
                          ),
                          pw.Text(
                            '- ${(data.inspectionFee - booking.service.getDiscountedPrice(data.inspectionFee)).toStringAsFixed(2)} ${loc.sar}',
                            style: pw.TextStyle(color: PdfColors.red),
                          ),
                        ],
                      ),
                    if ((booking.service.discountPercentage ?? 0) > 0)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
                        child: pw.Text(
                          loc.discountAppliesToInspectionFeeOnly,
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey,
                          ),
                        ),
                      ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          loc.totalLabel,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          "${(data.totalCost + booking.service.getDiscountedPrice(data.inspectionFee)).toStringAsFixed(2)} ${loc.sar}",
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.Spacer(flex: 2),
            ],
          ),

          pw.SizedBox(height: 60),
          pw.Center(
            child: pw.Text(
              (loc.localeName == 'ar')
                  ? 'شكرا لاختيارك أبو جلمبو'
                  : (loc.localeName == 'ur')
                  ? 'ابو جلمبو کا انتخاب کرنے کا شکریہ'
                  : 'Thank you for choosing Abo Glumbo',
              style: pw.TextStyle(color: PdfColors.grey),
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  static Future<Uint8List?> _getOrGenerateInvoiceBytes(
    material_widgets.BuildContext context,
    BookingModel booking,
  ) async {
    // If we already have the URL cached, download the bytes.
    if (booking.invoicePdfUrl != null && booking.invoicePdfUrl!.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(booking.invoicePdfUrl!));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
      } catch (e) {
        debugPrint('Error downloading existing invoice: $e');
      }
    }

    // Fallback: generate it locally
    final pdf = await _buildInvoiceDocument(context, booking);
    if (pdf == null) return null;
    return await pdf.save();
  }

  static Future<bool> generateAndUploadInvoice(
    material_widgets.BuildContext context,
    BookingModel booking,
  ) async {
    try {
      final invoiceId =
          '${booking.newBookingId ?? booking.id}_${booking.customer.uid}';

      final pdf = await _buildInvoiceDocument(context, booking);
      if (pdf == null) return false;

      final bytes = await pdf.save();

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref(
        'invoices/$invoiceId.pdf',
      );
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'application/pdf'),
      );
      final downloadUrl = await storageRef.getDownloadURL();

      // Save to invoices collection
      final invoiceModel = InvoiceModel(
        id: invoiceId,
        invoiceUrl: downloadUrl,
        createdAt: Timestamp.now(),
        bookingId: booking.id,
        newBookingId: booking.newBookingId,
        userId: booking.customer.uid ?? '',
        technicianId: booking.agent?.uid,
      );

      await FirebaseFirestore.instance
          .collection('invoices')
          .doc(invoiceId)
          .set(invoiceModel.toMap());

      // Update booking
      await AppFirestore.bookingsCollectionRef.doc(booking.id).update({
        'invoiceId': invoiceId,
        'invoicePdfUrl': downloadUrl,
      });

      return true;
    } catch (e) {
      debugPrint('Error generating and uploading invoice: $e');
      return false;
    }
  }

  static Future<void> generateAndShowInvoice(
    material_widgets.BuildContext context,
    BookingModel booking, {
    VoidCallback? onReady,
  }) async {
    final bytes = await _getOrGenerateInvoiceBytes(context, booking);
    if (onReady != null) onReady();
    if (bytes == null) return;

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name:
          '${booking.newBookingId ?? booking.id.substring(0, 8).toUpperCase()}.pdf',
    );
  }

  static Future<void> generateAndShareInvoice(
    material_widgets.BuildContext context,
    BookingModel booking, {
    VoidCallback? onReady,
  }) async {
    final bytes = await _getOrGenerateInvoiceBytes(context, booking);
    if (onReady != null) onReady();
    if (bytes == null) return;

    await Printing.sharePdf(
      bytes: bytes,
      filename:
          '${booking.newBookingId ?? booking.id.substring(0, 8).toUpperCase()}.pdf',
    );
  }
}
