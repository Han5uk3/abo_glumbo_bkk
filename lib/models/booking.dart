import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/models/warranty.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  String id;
  late ServiceModel service;
  late Timestamp bookingDateTime;
  late String bookingStatusCode;
  bool? isEscalated;
  Timestamp? escalatedAt;

  late String notes;
  late String? issueImage;
  late String? issueVideo;
  late CustomerModel customer;
  CompletionDataModel? completionData;
  late String paymentModeCode;
  String chatroomId = '';
  ReviewModel? review;

  UserModel? agent;
  bool? isStartTracking;
  List<CancelledWorkers> cancelledWorkers;
  Timestamp? createdAt;
  Timestamp? updatedAt;
  Timestamp? acceptedAt;
  Timestamp? rejectedAt;
  Timestamp? completedAt;
  Timestamp? trackingStartedAt;
  Timestamp? trackingStoppedAt;
  Timestamp? cancelledAt;
  String? cancellationReason;
  bool paymentCompleted = false;
  String? orderId;
  String? transactionId; // Added transactionId
  String? selectedAddressId; // Added selectedAddressId
  WarrantyModel? warranty;
  Timestamp? paymentCompletedAt;
  List<String>? paymentProof; // Payment completion proof files
  double? paidAmount; // Amount paid for job completion

  List<String>? cancelledWorkerUids;

  BookingModel({
    required this.id,
    required this.service,
    required this.bookingDateTime,
    required this.bookingStatusCode,
    required this.notes,
    required this.issueImage,
    required this.issueVideo,
    required this.customer,
    required this.paymentModeCode,
    this.isStartTracking,
    this.chatroomId = '',
    this.review,
    this.paymentCompletedAt,
    this.cancelledWorkers = const [],
    this.isEscalated = false,
    this.escalatedAt,
    this.agent,
    this.completionData, // Add this
    this.trackingStartedAt,
    this.trackingStoppedAt,
    this.createdAt,
    this.updatedAt,
    this.acceptedAt,
    this.rejectedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.orderId,
    this.transactionId, // Added transactionId
    this.selectedAddressId, // Added selectedAddressId
    this.cancelledWorkerUids,
    this.paymentCompleted = false,
    this.warranty,
    this.paymentProof,
    this.paidAmount,
  });

  BookingModel.fromMap(Map<String, dynamic> data)
    : service = ServiceModel.fromJson(data['service']),
      completionData = data['completionData'] != null
          ? CompletionDataModel.fromMap(data['completionData'])
          : null,
      isEscalated = data['isEscalated'] ?? false,
      cancelledWorkers = data['cancelledWorkers'] != null
          ? (data['cancelledWorkers'] as List)
                .map((e) => CancelledWorkers.fromMap(e))
                .toList()
          : [],
      paymentCompletedAt = data['paymentCompletedAt'],
      escalatedAt = data['escalatedAt'],
      chatroomId = data['chatroomId'] ?? '',
      bookingDateTime = data['bookingDateTime'],
      bookingStatusCode = data['bookingStatusCode'],
      isStartTracking = data['isStarted'] ?? false,
      notes = data['notes'],
      id = data['id'] ?? '',
      issueImage = data['issueImage'],
      issueVideo = data['issueVideo'],
      customer = CustomerModel.fromJson(data['customer']),
      paymentModeCode = data['paymentModeCode'],
      review = data['review'] != null
          ? ReviewModel.fromMap(data['review'])
          : null,
      cancelledWorkerUids = data['cancelledWorkerUids'] != null
          ? List<String>.from(data['cancelledWorkerUids'])
          : null,
      trackingStartedAt = data['trackingStartedAt'],
      trackingStoppedAt = data['trackingStoppedAt'],
      warranty = (data['warranty'] is Map<String, dynamic>)
          ? WarrantyModel.fromJson(data['warranty'])
          : null,
      agent = data['agent'] != null ? UserModel.fromJson(data['agent']) : null,
      createdAt = data['createdAt'],
      updatedAt = data['updatedAt'],
      acceptedAt = data['acceptedAt'],
      rejectedAt = data['rejectedAt'],
      cancellationReason = data['cancellationReason'],
      completedAt = data['completedAt'],
      paymentCompleted = data['paymentCompleted'] ?? false,
      orderId = data['orderId'],
      transactionId = data['transactionId'], // Added transactionId
      selectedAddressId = data['selectedAddressId'], // Added selectedAddressId
      paymentProof = data['paymentProof'] != null
          ? List<String>.from(data['paymentProof'])
          : null,
      paidAmount = data['paidAmount']?.toDouble(),
      cancelledAt = data['cancelledAt'];

  factory BookingModel.fromJson(Map<String, dynamic> data) {
    return BookingModel.fromMap(data);
  }

  factory BookingModel.fromQueryDocumentSnapshot(
    QueryDocumentSnapshot snapshot,
  ) {
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    return BookingModel.fromMap(data);
  }

  factory BookingModel.fromDocumentSnapshot(DocumentSnapshot snapshot) {
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    return BookingModel.fromMap(data);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> map = {
      'service': service.toJson(),
      'bookingDateTime': bookingDateTime,
      'bookingStatusCode': bookingStatusCode,
      'notes': notes,
      'paymentCompletedAt': paymentCompletedAt,
      'cancelledWorkers': cancelledWorkers.map((e) => e.toJson()).toList(),
      'trackingStartedAt': trackingStartedAt,
      'trackingStoppedAt': trackingStoppedAt,
      'cancelledWorkerUids': cancelledWorkerUids,
      'isEscalated': isEscalated ?? false,
      'escalatedAt': escalatedAt,
      'issueImage': issueImage,
      'issueVideo': issueVideo,
      'chatroomId': chatroomId,
      'customer': customer.toJson(),
      'paymentModeCode': paymentModeCode,
      'isStarted': isStartTracking ?? false,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'acceptedAt': acceptedAt,
      'rejectedAt': rejectedAt,
      'completedAt': completedAt,
      'cancelledAt': cancelledAt,
      'orderId': orderId,
      'transactionId': transactionId, // Added transactionId
      'selectedAddressId': selectedAddressId, // Added selectedAddressId
      'cancellationReason': cancellationReason,
      'paymentCompleted': paymentCompleted,
      'paymentProof': paymentProof,
      'paidAmount': paidAmount,
    };

    map['id'] = id;
    if (warranty != null) {
      map['warranty'] = warranty!.toJson();
    }
    if (review != null) {
      map['review'] = review!.toJson();
    }
    if (agent != null) {
      map['agent'] = agent!.toJson();
    }
    if (completionData != null) {
      map['completionData'] = completionData!.toJson();
    }
    return map;
  }
}

class ReviewModel {
  int? rating;
  String review;
  double? tipAmount;
  String? paymentType;
  bool? isTipPaid;
  Timestamp? createdAt;
  String? workerId;

  ReviewModel({
    required this.rating,
    required this.review,
    this.createdAt,
    this.tipAmount,
    this.paymentType,
    this.isTipPaid,
    this.workerId,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> data) {
    return ReviewModel(
      rating: data['rating'] != null
          ? (data['rating'] is int
                ? data['rating'] as int
                : (data['rating'] as num).toInt())
          : null,
      review: data['review']?.toString() ?? '', // ✅ Fixed: Safe conversion
      tipAmount:
          data['tipAmount'] !=
              null // ✅ Fixed: Check null first
          ? (data['tipAmount'] is double
                ? data['tipAmount'] as double
                : (data['tipAmount'] as num).toDouble())
          : null,
      paymentType: data['paymentType'] as String?, // ✅ Make nullable
      isTipPaid: data['isTipPaid'] as bool?, // ✅ Make nullable
      createdAt: data['createdAt'] as Timestamp?, // ✅ Make nullable
      workerId: data['workerId'] as String?, // ✅ Make nullable
    );
  }

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel.fromMap(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      'review': review,
      'tipAmount': tipAmount,
      'paymentType': paymentType,
      'isTipPaid': isTipPaid,
      'createdAt': createdAt,
      'workerId': workerId,
    };
  }

  ReviewModel copyWith({
    int? rating,
    String? review,
    double? tipAmount,
    String? paymentType,
    bool? isTipPaid,
    Timestamp? createdAt,
    String? workerId,
  }) {
    return ReviewModel(
      rating: rating ?? this.rating,
      review: review ?? this.review,
      tipAmount: tipAmount ?? this.tipAmount,
      paymentType: paymentType ?? this.paymentType,
      isTipPaid: isTipPaid ?? this.isTipPaid,
      createdAt: createdAt ?? this.createdAt,
      workerId: workerId ?? this.workerId,
    );
  }
}

class CancelledWorkers {
  String uid;
  String agentName;
  Timestamp cancelledAt;

  CancelledWorkers({
    required this.uid,
    required this.agentName,
    required this.cancelledAt,
  });

  factory CancelledWorkers.fromMap(Map<String, dynamic> data) {
    return CancelledWorkers(
      uid: data['uid'],
      agentName: data['agentName'],
      cancelledAt: data['cancelledAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'uid': uid, 'agentName': agentName, 'cancelledAt': cancelledAt};
  }
}

enum BookingStatusType {
  pending,
  confirmed,
  pendingPayment,
  completed,
  cancelled,
  onWarranty,
}

class BookingServiceItem {
  final String name;
  final double quantity;
  final double price;

  const BookingServiceItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'quantity': quantity, 'price': price};
  }
}

class CompletionDataModel {
  final List<String> fileUrls; // Changed from imageUrls
  final int mode;
  final String paymentMethod;
  final double serviceCost;
  final double totalCost;
  final List<BookingServiceItem> serviceItems;
  final double inspectionFee;

  CompletionDataModel({
    required this.fileUrls, // Changed
    required this.mode,
    required this.paymentMethod,
    required this.serviceCost,
    required this.totalCost,
    required this.serviceItems,
    required this.inspectionFee,
  });

  factory CompletionDataModel.fromMap(Map<String, dynamic> data) {
    return CompletionDataModel(
      inspectionFee: data['inspectionFee']?.toDouble() ?? 0.0,

      fileUrls: data['fileUrls'] != null
          ? List<String>.from(data['fileUrls'])
          : (data['imageUrls'] != null
                ? List<String>.from(data['imageUrls']) // Support old field name
                : (data['imageUrl'] != null
                      ? [data['imageUrl']]
                      : [])), // Backward compatibility
      mode: data['mode'] ?? 0,
      paymentMethod: data['paymentMethod'] ?? '',
      serviceCost: data['serviceCost']?.toDouble() ?? 0.0,
      totalCost: data['totalCost']?.toDouble() ?? 0.0,
      serviceItems:
          (data['serviceItems'] as List<dynamic>?)
              ?.map(
                (item) => BookingServiceItem(
                  name: item['name'] ?? '',
                  quantity: item['quantity']?.toDouble() ?? 0.0,
                  price: item['price']?.toDouble() ?? 0.0,
                ),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileUrls': fileUrls, // Changed from imageUrls
      'mode': mode,
      'paymentMethod': paymentMethod,
      'serviceCost': serviceCost,
      'totalCost': totalCost,
      'inspectionFee': inspectionFee,

      'serviceItems': serviceItems.map((e) => e.toMap()).toList(),
    };
  }

  // Helper getter for backward compatibility
  String? get firstFileUrl => fileUrls.isNotEmpty ? fileUrls.first : null;

  // Get only image URLs from the file list
  List<String> get imageUrls {
    return fileUrls.where((url) {
      String lowerUrl = url.toLowerCase();
      return lowerUrl.endsWith('.jpg') ||
          lowerUrl.endsWith('.jpeg') ||
          lowerUrl.endsWith('.png');
    }).toList();
  }

  // Get only document URLs from the file list
  List<String> get documentUrls {
    return fileUrls.where((url) {
      String lowerUrl = url.toLowerCase();
      return lowerUrl.endsWith('.pdf') ||
          lowerUrl.endsWith('.doc') ||
          lowerUrl.endsWith('.docx');
    }).toList();
  }
}
