
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:intl/intl.dart';

import 'package:flutter/widgets.dart' as material_widgets;
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';

import 'package:bidi/bidi.dart' as bidi;

class InvoiceService {
  /// Scripts that must be laid out right-to-left: Arabic, Arabic Supplement
  /// (the extra Urdu/Persian letters) and both Arabic presentation form blocks.
  static final RegExp _rtlScript = RegExp(r'[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]');

  /// A run of Latin letters, digits and the separators that hold them together.
  static final RegExp _ltrRun = RegExp(
    r'[+#]?[0-9A-Za-z][0-9A-Za-z \u00A0.,:;+\-/\\#@%_]*[0-9A-Za-z%]|[0-9A-Za-z]',
  );

  /// Keeps a Latin/number run together and left-to-right, by fencing it between
  /// two LRMs. That matters twice over:
  ///
  ///  * package:bidi does not apply rule W4 to the hyphen-minus, so `2026-07-28`
  ///    would otherwise be split at the hyphens and reordered to `28-07-2026`.
  ///  * rule W2 turns a European number into an *Arabic* number when the nearest
  ///    preceding strong type is an Arabic letter, which pulls the `2` out of
  ///    `اشفابدران, 2WX5+FW` and drops it on the far side of the Arabic word. The
  ///    fence puts a strong L in front of the digit, so it stays European.
  ///
  /// LRM is consumed by the bidi pass, and Noto Naskh Arabic carries a glyph for
  /// it, so it never reaches the page as a box either way.
  static final String _lrm = String.fromCharCode(0x200E);

  static String _isolateLtrRuns(String value) =>
      value.replaceAllMapped(_ltrRun, (match) => '$_lrm${match[0]}$_lrm');

  /// Reorders [value] into visual order and shapes the Arabic, using the same
  /// bidi implementation package:pdf calls internally, so the result can be
  /// drawn left to right verbatim.
  ///
  /// The leading LRM forces the paragraph direction to left-to-right. Rule P2
  /// would otherwise derive it from the first strong character, so a geocoded
  /// address such as `اشفابدران, Amman, Jordan, 2WX5+FW` would lay out
  /// right-to-left inside an English invoice. Runs of Arabic are still reversed
  /// and shaped within themselves; only the direction of the line as a whole is
  /// pinned. Text that is entirely Arabic comes out the same either way.
  static String _visualOrderLtr(String value) {
    final buffer = StringBuffer();
    for (final paragraph in bidi.BidiString.fromLogical(
      _lrm + value,
    ).paragraphs) {
      final endsWithNewLine = paragraph.separator == 10;
      final end = paragraph.bidiText.length - (endsWithNewLine ? 1 : 0);
      buffer.write(String.fromCharCodes(paragraph.bidiText, 0, end));
      if (endsWithNewLine) buffer.writeln();
    }
    return buffer.toString();
  }

  @material_widgets.visibleForTesting
  static Future<pw.Document> buildInvoiceDocument(
    AppLocalizations loc,
    BookingModel booking,
  ) async {
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

    final isRtl = loc.localeName == 'ar' || loc.localeName == 'ur';

    // Noto Naskh Arabic is used for every locale on purpose. package:pdf shapes
    // Arabic by rewriting text into the Arabic presentation forms blocks, so the
    // font has to carry glyphs for those codepoints. Cairo only covers part of
    // Presentation Forms-B and none of Forms-A, which is where the Urdu letters
    // (ٹ ڈ ڑ ں ہ ھ ے ک گ پ) live - they came out as .notdef boxes.
    final ttf = await PdfGoogleFonts.notoNaskhArabicRegular();
    final ttfBold = await PdfGoogleFonts.notoNaskhArabicBold();

    final theme = pw.ThemeData.withFont(base: ttf, bold: ttfBold);

    // package:pdf reshapes *and* reorders Arabic itself (through package:bidi)
    // as soon as the resolved direction is RTL, so a string only ever needs the
    // correct direction wrapped around it - never a second reshaping pass.
    // Reshaping ahead of time produced disjointed glyphs and made package:bidi
    // throw on some strings.
    pw.Widget text(
      String value, {
      pw.TextStyle? style,
      pw.TextAlign? textAlign,
    }) {
      final wantsRtl = _rtlScript.hasMatch(value);

      // Arabic inside an English invoice. Handing it to package:pdf's RTL pass
      // lays the whole line out right-to-left, and because that pass reverses
      // words across the entire string before the line breaking runs, a wrapped
      // line comes out scrambled on top of that. Reorder it here against a
      // left-to-right paragraph and draw the result verbatim instead. Only
      // reachable on an LTR invoice, so ar/ur are unaffected.
      if (wantsRtl && !isRtl) {
        return pw.Text(
          _visualOrderLtr(_isolateLtrRuns(value)),
          style: style,
          textAlign: textAlign,
        );
      }

      final child = pw.Text(
        wantsRtl ? _isolateLtrRuns(value) : value,
        style: style,
        textAlign: textAlign,
      );
      if (wantsRtl == isRtl) return child;
      return pw.Directionality(
        textDirection: wantsRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        child: child,
      );
    }

    // pw.Table always lays its columns out left to right, so an RTL invoice
    // needs the columns (and their alignments) mirrored by hand.
    List<T> ordered<T>(List<T> columns) =>
        isRtl ? columns.reversed.toList() : columns;

    // Column order after `ordered`, left to right on the page:
    //   ltr: description, quantity, unit price, amount
    //   rtl: amount, unit price, quantity, description
    final cellAlignments = isRtl
        ? const <int, pw.Alignment>{
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.center,
            3: pw.Alignment.centerRight,
          }
        : const <int, pw.Alignment>{
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          };

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
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
                  text(
                    "Abo Glumbo",
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  text(loc.invoiceTitle),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  text(
                    loc.invoiceWord,
                    style: pw.TextStyle(
                      fontSize: 30,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  text(
                    loc.invoiceNumber(
                      booking.newBookingId ??
                          booking.id.substring(0, 8).toUpperCase(),
                    ),
                  ),
                  text(loc.dateString(dateFormat.format(DateTime.now()))),
                  text(
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

          pw.SizedBox(height: 20),

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

            final warrantyDuration = (loc.localeName == 'ar')
                ? "7 أيام (من تاريخ اكتمال الخدمة)"
                : (loc.localeName == 'ur')
                ? "7 دن (سروس مکمل ہونے کی تاریخ سے)"
                : "7 Days (from service completion)";

            return pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      text(
                        loc.billTo,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      text(
                        booking.customer.name ??
                            ((loc.localeName == 'ar')
                                ? 'عميلنا العزيز'
                                : (loc.localeName == 'ur')
                                ? 'معزز صارف'
                                : 'Valued Customer'),
                      ),
                      text(booking.customer.phone ?? ""),
                      text(booking.customer.email ?? ""),
                      text(
                        "${address.buildingNumber}${address.streetName != null ? ', ${address.streetName}' : ''}",
                      ),
                      if (address.fullName.isNotEmpty &&
                          address.fullName != booking.customer.name)
                        text(address.fullName),
                      if (booking.customer.districtName != null ||
                          booking.customer.cityName != null)
                        text(
                          "${booking.customer.districtName ?? ''}${booking.customer.districtName != null && booking.customer.cityName != null ? ', ' : ''}${booking.customer.cityName ?? ''}",
                        ),
                      if (booking.serviceLocation != null)
                        text(
                          booking.serviceLocation!.localizedName(
                            loc.localeName,
                          ),
                        ),
                    ],
                  ),
                ),
                // A long service address runs right up to the other column,
                // which reads as touching once the layout mirrors for ar/ur.
                pw.SizedBox(width: 24),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      text(
                        loc.bookingDetailsInvoice,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      text(
                        loc.serviceLabel(
                          booking.service.nameLocalized(
                                languageCode: loc.localeName,
                              ) ??
                              "",
                        ),
                      ),
                      if (booking.agent?.name != null)
                        text(loc.technicianLabel(booking.agent!.name!)),
                      if (booking.agent?.phone != null)
                        text(loc.techPhoneLabel(booking.agent!.phone!)),
                      text(loc.completedAtLabel(completedAtStr)),
                      if (data.mode == 1)
                        text(loc.warrantyLabel(warrantyDuration)),
                      text(
                        loc.paymentModeLabel(
                          (booking.orderId != null &&
                                      booking.orderId!.isNotEmpty) ||
                                  (booking.paymentModeCode.toUpperCase() ==
                                          'C' ||
                                      booking.paymentModeCode.toUpperCase() ==
                                          'A')
                              ? (loc.insideApp)
                              : (loc.outsideApp),
                        ),
                      ),
                      if (booking.orderId != null ||
                          booking.transactionId != null)
                        text(
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
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
            cellHeight: 30,
            cellAlignments: cellAlignments,
            headers: ordered(
              (loc.localeName == 'ar')
                  ? ['الوصف', 'الكمية', 'سعر الوحدة', 'المبلغ']
                  : (loc.localeName == 'ur')
                  ? ['تفصیل', 'مقدار', 'فی اکائی قیمت', 'رقم']
                  : ['Description', 'Quantity', 'Unit Price', 'Amount'],
            ),
            data: [
              ...data.serviceItems.map(
                (item) => ordered([
                  text(item.name),
                  text(item.quantity.toStringAsFixed(0)),
                  text("${item.price.toStringAsFixed(2)} ${loc.sar}"),
                  text(
                    "${(item.quantity * item.price).toStringAsFixed(2)} ${loc.sar}",
                  ),
                ]),
              ),
              if (data.serviceItems.isEmpty && data.serviceCost > 0)
                ordered([
                  text(
                    (loc.localeName == 'ar')
                        ? 'تكلفة الخدمة'
                        : (loc.localeName == 'ur')
                        ? 'سروس کی قیمت'
                        : 'Service Cost',
                  ),
                  text('1'),
                  text("${data.serviceCost.toStringAsFixed(2)} ${loc.sar}"),
                  text("${data.serviceCost.toStringAsFixed(2)} ${loc.sar}"),
                ]),
              if (data.inspectionFee > 0)
                ordered([
                  text(loc.inspectionFee),
                  text('1'),
                  text("${data.inspectionFee.toStringAsFixed(2)} ${loc.sar}"),
                  text("${data.inspectionFee.toStringAsFixed(2)} ${loc.sar}"),
                ]),
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
                        text(loc.subtotal),
                        text(
                          "${data.serviceCost.toStringAsFixed(2)} ${loc.sar}",
                        ),
                      ],
                    ),
                    if (data.inspectionFee > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          text(loc.inspectionFee),
                          text(
                            "${data.inspectionFee.toStringAsFixed(2)} ${loc.sar}",
                          ),
                        ],
                      ),
                    if ((booking.service.discountPercentage ?? 0) > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          text(
                            (loc.localeName == 'ar')
                                ? 'الخصم (${booking.service.discountPercentage}%)'
                                : (loc.localeName == 'ur')
                                ? 'رعایت (${booking.service.discountPercentage}%)'
                                : 'Discount (${booking.service.discountPercentage}%)',
                          ),
                          text(
                            '- ${(data.inspectionFee - booking.service.getDiscountedPrice(data.inspectionFee)).toStringAsFixed(2)} ${loc.sar}',
                            style: pw.TextStyle(color: PdfColors.red),
                          ),
                        ],
                      ),
                    if ((booking.service.discountPercentage ?? 0) > 0)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
                        child: text(
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
                        text(
                          loc.totalLabel,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        text(
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

          pw.SizedBox(height: 20),
          pw.Center(
            child: text(
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
    final loc = AppLocalizations.of(context);
    if (loc == null) return null;
    // Always generate locally to ensure the invoice matches the current app language exactly.
    final pdf = await buildInvoiceDocument(loc, booking);
    return await pdf.save();
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
