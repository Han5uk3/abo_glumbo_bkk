import 'dart:io';
import 'package:abo_glumbo_bbk/common_widgets/elevated_button.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/booking.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<bool?> showUploadPaymentProofSheet(
  BuildContext context, {
  required BookingModel booking,
}) async {
  return await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => UploadPaymentProofSheet(booking: booking),
  );
}

class UploadPaymentProofSheet extends StatefulWidget {
  final BookingModel booking;

  const UploadPaymentProofSheet({super.key, required this.booking});

  @override
  State<UploadPaymentProofSheet> createState() =>
      _UploadPaymentProofSheetState();
}

class _UploadPaymentProofSheetState extends State<UploadPaymentProofSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _transactionIdController =
      TextEditingController();
  final List<File> _selectedFiles = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.booking.completionData != null) {
      final totalCost = widget.booking.completionData!.totalCost;
      _amountController.text = totalCost.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(
            result.paths.map((path) => File(path!)).toList(),
          );
        });
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${AppLocalizations.of(context)?.errorUploading ?? 'Error uploading'}: $e",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _uploadPaymentProof() async {
    // Payment proof files are now optional
    /*
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.pleaseSelectAtLeastOneFile ??
                'Please select at least one file',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    */

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.pleaseEnterValidAmount ??
                'Please enter a valid amount',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Transaction ID is now optional
    /*
    final transactionId = _transactionIdController.text.trim();
    if (transactionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.pleaseEnterTransactionId ??
                'Please enter a transaction ID',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    */
    final transactionId = _transactionIdController.text.trim();

    setState(() {
      _isUploading = true;
    });

    try {
      // Upload files to Firebase Storage
      List<String> uploadedUrls = [];
      for (var file in _selectedFiles) {
        String fileName =
            'payment_proofs/${widget.booking.id}/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final storageRef = FirebaseStorage.instance.ref().child(fileName);

        // Determine content type
        String? contentType;
        String extension = file.path.split('.').last.toLowerCase();
        if (['jpg', 'jpeg', 'png'].contains(extension)) {
          contentType = 'image/$extension';
        } else if (extension == 'pdf') {
          contentType = 'application/pdf';
        } else if (['doc', 'docx'].contains(extension)) {
          contentType = 'application/msword';
        }

        final uploadTask = storageRef.putFile(
          file,
          SettableMetadata(contentType: contentType),
        );

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        uploadedUrls.add(downloadUrl);
      }

      // Update booking document
      await AppFirestore.bookingsCollectionRef.doc(widget.booking.id).update({
        'paymentProof': uploadedUrls,
        'paidAmount': amount,
        'transactionId': transactionId, // Saving transaction ID
        'bookingStatusCode': 'VP',
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.paymentProofUploadedSuccessfully ??
                  'Payment proof uploaded successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading payment proof: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${AppLocalizations.of(context)?.errorUploading ?? 'Error uploading'}: $e",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: safePadding.bottom + viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)?.completePayment ??
                      'Complete Payment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: _isUploading
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount Input
                Text(
                  AppLocalizations.of(context)?.amountPaid ?? 'Amount Paid',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
                  ],
                  decoration: InputDecoration(
                    hintText: '0.00',
                    suffixText: " ${AppLocalizations.of(context)!.sar} ",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Transaction ID Input
                Text(
                  AppLocalizations.of(context)?.transactionId ??
                      'Transaction ID',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _transactionIdController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)?.enterTransactionId ??
                        'Enter Transaction ID',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // File Selection
                Text(
                  AppLocalizations.of(context)?.paymentProofFiles ??
                      'Payment Proof Files',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),

                // Selected Files List
                if (_selectedFiles.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _selectedFiles.length,
                      itemBuilder: (context, index) {
                        final file = _selectedFiles[index];
                        final fileName = file.path.split('/').last;
                        return Card(
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              _getFileIcon(fileName),
                              color: AppColors.primary,
                            ),
                            title: Text(
                              fileName,
                              style: TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.close, size: 18),
                              onPressed: _isUploading
                                  ? null
                                  : () => _removeFile(index),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Add Files Button
                SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickFiles,
                  icon: Icon(Icons.attach_file),
                  label: Text(
                    _selectedFiles.isEmpty
                        ? (AppLocalizations.of(context)?.selectFiles ??
                              'Select Files')
                        : (AppLocalizations.of(context)?.addMoreFiles ??
                              'Add More Files'),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusGeometry.circular(8),
                    ),
                    minimumSize: Size(double.infinity, 48),
                    side: BorderSide(color: AppColors.primary),
                  ),
                ),

                SizedBox(height: 30),

                // Upload Button
                SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: eButton(
                    onPressed: _isUploading ? null : _uploadPaymentProof,
                    context: context,
                    backgroundColor: AppColors.primary,
                    text: _isUploading
                        ? (AppLocalizations.of(context)?.uploading ??
                              'Uploading...')
                        : (AppLocalizations.of(context)?.uploadProof ??
                              'Upload Proof'),
                    textColor: Colors.white,
                    widget: _isUploading
                        ? Loader()
                        : Text(
                            AppLocalizations.of(context)?.uploadProof ??
                                'Upload Proof',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png'].contains(extension)) {
      return Icons.image;
    } else if (extension == 'pdf') {
      return Icons.picture_as_pdf;
    } else if (['doc', 'docx'].contains(extension)) {
      return Icons.description;
    }
    return Icons.insert_drive_file;
  }
}
