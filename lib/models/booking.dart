import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class BookingModel {
  String id;
  late ServiceModel service;
  late Timestamp bookingDateTime;
  late String bookingStatusCode;

  /// generate booking status string based on booking status code
  String get bookingStatusGen {
    switch (bookingStatusCode) {
      case 'P':
        return 'Pending';
      case 'A':
        return 'Accepted';
      case 'R':
        return 'Rejected';
      case 'C':
        return 'Completed';
      case 'X':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  late String notes;
  late String? issueImage;
  late String? issueVideo;
  late CustomerModel customer;

  late String paymentModeCode;

  /// generate payment mode string based on payment mode code
  String get paymentModeGen {
    switch (paymentModeCode) {
      case 'C':
        return 'Cards';
      case 'A':
        return 'Apple Pay';
      case 'O':
        return 'Cash On Hands';
      default:
        return 'Unknown';
    }
  }

  ReviewModel? review;

  UserModel? agent;
  bool? isStartTracking;

  Timestamp? createdAt;
  Timestamp? updatedAt;
  Timestamp? acceptedAt;
  Timestamp? rejectedAt;
  Timestamp? completedAt;
  Timestamp? cancelledAt;

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
    this.review,
    this.agent,
    this.createdAt,
    this.updatedAt,
    this.acceptedAt,
    this.rejectedAt,
    this.completedAt,
    this.cancelledAt,
  });

  BookingModel.fromMap(Map<String, dynamic> data)
      : service = ServiceModel.fromJson(data['service']),
        bookingDateTime = data['bookingDateTime'],
        bookingStatusCode = data['bookingStatusCode'],
        isStartTracking = data['isStarted'] ?? false,
        notes = data['notes'],
        id = data['id'] ?? '',
        issueImage = data['issueImage'],
        issueVideo = data['issueVideo'],
        customer = CustomerModel.fromJson(data['customer']),
        paymentModeCode = data['paymentModeCode'],
        review =
            data['review'] != null ? ReviewModel.fromMap(data['review']) : null,
        agent =
            data['agent'] != null ? UserModel.fromJson(data['agent']) : null,
        createdAt = data['createdAt'],
        updatedAt = data['updatedAt'],
        acceptedAt = data['acceptedAt'],
        rejectedAt = data['rejectedAt'],
        completedAt = data['completedAt'],
        cancelledAt = data['cancelledAt'];

  factory BookingModel.fromQueryDocumentSnapshot(
      QueryDocumentSnapshot snapshot) {
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
      'issueImage': issueImage,
      'customer': customer.toJson(),
      'paymentModeCode': paymentModeCode,
      'isStarted': isStartTracking ?? false,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'acceptedAt': acceptedAt,
      'rejectedAt': rejectedAt,
      'completedAt': completedAt,
      'cancelledAt': cancelledAt,
    };

    map['id'] = id;

    if (review != null) {
      map['review'] = review!.toJson();
    }
    if (agent != null) {
      map['agent'] = agent!.toJson();
    }
    return map;
  }
}

class ReviewModel {
  int rating;
  String review;
  double? tipAmount;
  String? paymentType;
  bool? isTipPaid;
  Timestamp? createdAt;
  ReviewModel(
      {required this.rating,
      required this.review,
      this.createdAt,
      this.tipAmount,
      this.paymentType,
      this.isTipPaid});

  factory ReviewModel.fromMap(Map<String, dynamic> data) {
    return ReviewModel(
      rating: data['rating'],
      review: data['review'],
      tipAmount: data['tipAmount'],
      paymentType: data['paymentType'],
      isTipPaid: data['isTipPaid'],
      createdAt: data['createdAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      'review': review,
      'tipAmount': tipAmount,
      'paymentType': paymentType,
      'isTipPaid': isTipPaid,
      'createdAt': createdAt,
    };
  }
}
