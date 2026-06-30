// ignore_for_file: non_constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';

import 'categories.dart';

class ServiceModel {
  String? id;

  String? name;
  String? name_ar;
  String? name_ur;
  String? nameLocalized({required String languageCode}) {
    if (languageCode == 'ar') {
      return name_ar;
    }
    if (languageCode == 'ur') {
      return name_ur ?? name_ar;
    }
    return name;
  }

  String? description;
  String? description_ar;
  String? description_ur;
  String? descriptionLocalized({required String languageCode}) {
    if (languageCode == 'ar') {
      return description_ar;
    }
    if (languageCode == 'ur') {
      return description_ur ?? description_ar;
    }
    return description;
  }

  String? image;
  double? rating;
  int? ratingCount;
  double? totalRating;

  // the price in its lowest form
  double? price;

  // Work hour pricing fields
  String? workStartTime;
  String? workEndTime;
  double? onWorkHourPrice;
  double? offWorkHourPrice;
  List<int>? workingDays;

  // the price in its highest form
  String? category;
  String? categoryNameFilled;
  List<String>? specialSection;
  List<String?>? locations;

  bool isActive;

  // timestamps
  Timestamp? createdAt;
  Timestamp? updatedAt;
  double? discountPercentage;

  ServiceModel({
    this.id,
    this.name,
    this.name_ar,
    this.name_ur,
    this.description,
    this.description_ar,
    this.description_ur,
    this.image,
    this.rating,
    this.ratingCount,
    this.totalRating,
    this.price,
    this.workStartTime,
    this.workEndTime,
    this.onWorkHourPrice,
    this.offWorkHourPrice,
    this.workingDays,
    this.category,
    this.specialSection,
    this.locations,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.categoryNameFilled,
    this.discountPercentage,
  });

  // copyWith method
  ServiceModel copyWith({
    String? id,
    String? name,
    String? name_ar,
    String? name_ur,
    String? description,
    String? description_ar,
    String? description_ur,
    String? image,
    double? rating,
    int? ratingCount,
    double? totalRating,
    double? price,
    String? workStartTime,
    String? workEndTime,
    double? onWorkHourPrice,
    double? offWorkHourPrice,
    List<int>? workingDays,
    String? category,
    List<String>? specialSection,
    List<String?>? locations,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    bool? isActive,
    List<CategoryModel>? categories,
    double? discountPercentage,
  }) {
    String? categoryName;
    if (categories != null && this.category != null) {
      categoryName = categories
          .firstWhere((element) => element.id == this.category)
          .name;
    }
    return ServiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      name_ar: name_ar ?? this.name_ar,
      name_ur: name_ur ?? this.name_ur,
      description: description ?? this.description,
      description_ar: description_ar ?? this.description_ar,
      description_ur: description_ur ?? this.description_ur,
      image: image ?? this.image,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      totalRating: totalRating ?? this.totalRating,
      price: price ?? this.price,
      workStartTime: workStartTime ?? this.workStartTime,
      workEndTime: workEndTime ?? this.workEndTime,
      onWorkHourPrice: onWorkHourPrice ?? this.onWorkHourPrice,
      offWorkHourPrice: offWorkHourPrice ?? this.offWorkHourPrice,
      workingDays: workingDays ?? this.workingDays,
      category: category ?? this.category,
      specialSection: specialSection ?? this.specialSection,
      locations: locations ?? this.locations,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      categoryNameFilled: categoryName,
      discountPercentage: discountPercentage ?? this.discountPercentage,
    );
  }

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'],
      name: json['name'],
      name_ar: json['name_ar'] ?? json['name'],
      name_ur: json['name_ur'] ?? json['name_ar'] ?? json['name'],
      description: json['description'],
      description_ar: json['description_ar'] ?? json['description'],
      description_ur:
          json['description_ur'] ??
          json['description_ar'] ??
          json['description'],
      image: json['image'],
      rating: json['rating']?.toDouble(),
      ratingCount: json['ratingCount'],
      totalRating: json['totalRating']?.toDouble(),
      price: (json['price'] != null)
          ? (json['price'] is int
                ? (json['price'] as int).toDouble()
                : json['price'] as double)
          : 0.0,
      workStartTime: json['workStartTime'],
      workEndTime: json['workEndTime'],
      onWorkHourPrice: (json['onWorkHourPrice'] != null)
          ? (json['onWorkHourPrice'] is int
                ? (json['onWorkHourPrice'] as int).toDouble()
                : json['onWorkHourPrice'] as double)
          : 0.0,
      offWorkHourPrice: (json['offWorkHourPrice'] != null)
          ? (json['offWorkHourPrice'] is int
                ? (json['offWorkHourPrice'] as int).toDouble()
                : json['offWorkHourPrice'] as double)
          : 0.0,
      workingDays: json['workingDays']?.cast<int>(),
      category: json['category'],
      specialSection: json['specialSection']?.cast<String>(),
      locations: json['locations']?.cast<String>(),
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isActive: json['isActive'],
      discountPercentage: (json['discountPercentage'] != null)
          ? (json['discountPercentage'] is int
                ? (json['discountPercentage'] as int).toDouble()
                : json['discountPercentage'] as double)
          : 0.0,
    );
  }

  // from firebase query document snapshot
  factory ServiceModel.fromQueryDocumentSnapshot(
    QueryDocumentSnapshot snapshot,
  ) {
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    return ServiceModel(
      id: snapshot.id,
      name: data['name'],
      name_ar: data['name_ar'] ?? data['name'],
      name_ur: data['name_ur'] ?? data['name_ar'] ?? data['name'],
      description: data['description'],
      description_ar: data['description_ar'] ?? data['description'],
      description_ur:
          data['description_ur'] ??
          data['description_ar'] ??
          data['description'],
      image: data['image'],
      rating: data['rating']?.toDouble(),
      ratingCount: data['ratingCount'],
      totalRating: data['totalRating']?.toDouble(),
      price: (data['price'] != null)
          ? (data['price'] is int
                ? (data['price'] as int).toDouble()
                : data['price'] as double)
          : 0.0,
      workStartTime: data['workStartTime'],
      workEndTime: data['workEndTime'],
      onWorkHourPrice: (data['onWorkHourPrice'] != null)
          ? (data['onWorkHourPrice'] is int
                ? (data['onWorkHourPrice'] as int).toDouble()
                : data['onWorkHourPrice'] as double)
          : 0.0,
      offWorkHourPrice: (data['offWorkHourPrice'] != null)
          ? (data['offWorkHourPrice'] is int
                ? (data['offWorkHourPrice'] as int).toDouble()
                : data['offWorkHourPrice'] as double)
          : 0.0,
      workingDays: data['workingDays']?.cast<int>(),
      category: data['category'],
      specialSection: data['specialSection']?.cast<String>(),
      locations: data['locations']?.cast<String>(),
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
      isActive: data['isActive'],
      discountPercentage: (data['discountPercentage'] != null)
          ? (data['discountPercentage'] is int
                ? (data['discountPercentage'] as int).toDouble()
                : data['discountPercentage'] as double)
          : 0.0,
    );
  }

  // from firebase document snapshot
  factory ServiceModel.fromDocumentSnapshot(DocumentSnapshot snapshot) {
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    return ServiceModel(
      id: snapshot.id,
      name: data['name'],
      name_ar: data['name_ar'] ?? data['name'],
      name_ur: data['name_ur'] ?? data['name_ar'] ?? data['name'],
      description: data['description'],
      description_ar: data['description_ar'] ?? data['description'],
      description_ur:
          data['description_ur'] ??
          data['description_ar'] ??
          data['description'],
      image: data['image'],
      rating: data['rating']?.toDouble(),
      ratingCount: data['ratingCount'],
      totalRating: data['totalRating']?.toDouble(),
      price: (data['price'] != null)
          ? (data['price'] is int
                ? (data['price'] as int).toDouble()
                : data['price'] as double)
          : 0.0,
      workStartTime: data['workStartTime'],
      workEndTime: data['workEndTime'],
      onWorkHourPrice: (data['onWorkHourPrice'] != null)
          ? (data['onWorkHourPrice'] is int
                ? (data['onWorkHourPrice'] as int).toDouble()
                : data['onWorkHourPrice'] as double)
          : 0.0,
      offWorkHourPrice: (data['offWorkHourPrice'] != null)
          ? (data['offWorkHourPrice'] is int
                ? (data['offWorkHourPrice'] as int).toDouble()
                : data['offWorkHourPrice'] as double)
          : 0.0,
      workingDays: data['workingDays']?.cast<int>(),
      category: data['category'],
      specialSection: data['specialSection']?.cast<String>(),
      locations: data['locations']?.cast<String>(),
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
      isActive: data['isActive'],
      discountPercentage: (data['discountPercentage'] != null)
          ? (data['discountPercentage'] is int
                ? (data['discountPercentage'] as int).toDouble()
                : data['discountPercentage'] as double)
          : 0.0,
    );
  }

  // toJson method
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'name': name,
      'name_ar': name_ar,
      'name_ur': name_ur,
      'description': description,
      'description_ar': description_ar,
      'description_ur': description_ur,
      'image': image,
      'rating': rating,
      'ratingCount': ratingCount,
      'totalRating': totalRating,
      'price': price,
      'workStartTime': workStartTime,
      'workEndTime': workEndTime,
      'onWorkHourPrice': onWorkHourPrice,
      'offWorkHourPrice': offWorkHourPrice,
      'workingDays': workingDays,
      'category': category,
      'specialSection': specialSection,
      'locations': locations,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isActive': isActive,
      'discountPercentage': discountPercentage,
    };
    if (id != null) {
      json['id'] = id;
    }
    return json;
  }

  // to fire edit json
  Map<String, dynamic> toEditJson({required ServiceModel previous}) {
    Map<String, dynamic> json = {};
    if (name != previous.name && name != null) {
      json['name'] = name;
    }
    if (name_ar != previous.name_ar && name_ar != null) {
      json['name_ar'] = name_ar;
    }
    if (name_ur != previous.name_ur && name_ur != null) {
      json['name_ur'] = name_ur;
    }
    if (description != previous.description && description != null) {
      json['description'] = description;
    }
    if (description_ar != previous.description_ar && description_ar != null) {
      json['description_ar'] = description_ar;
    }
    if (description_ur != previous.description_ur && description_ur != null) {
      json['description_ur'] = description_ur;
    }
    if (image != previous.image && image != null) {
      json['image'] = image;
    }
    if (rating != previous.rating && rating != null) {
      json['rating'] = rating;
    }
    if (ratingCount != previous.ratingCount && ratingCount != null) {
      json['ratingCount'] = ratingCount;
    }
    if (totalRating != previous.totalRating && totalRating != null) {
      json['totalRating'] = totalRating;
    }
    if (price != previous.price && price != null) {
      json['price'] = price;
    }
    if (workStartTime != previous.workStartTime && workStartTime != null) {
      json['workStartTime'] = workStartTime;
    }
    if (workEndTime != previous.workEndTime && workEndTime != null) {
      json['workEndTime'] = workEndTime;
    }
    if (onWorkHourPrice != previous.onWorkHourPrice &&
        onWorkHourPrice != null) {
      json['onWorkHourPrice'] = onWorkHourPrice;
    }
    if (offWorkHourPrice != previous.offWorkHourPrice &&
        offWorkHourPrice != null) {
      json['offWorkHourPrice'] = offWorkHourPrice;
    }
    if (workingDays != null &&
        !_areListsEqual(workingDays, previous.workingDays)) {
      json['workingDays'] = workingDays;
    }
    if (category != previous.category && category != null) {
      json['category'] = category;
    }
    if (specialSection != null &&
        !_areListsEqual(specialSection, previous.specialSection)) {
      json['specialSection'] = specialSection;
    }
    if (locations != null && !_areListsEqual(locations, previous.locations)) {
      json['locations'] = locations;
    }
    if (createdAt != previous.createdAt && createdAt != null) {
      json['createdAt'] = createdAt;
    }
    if (updatedAt != previous.updatedAt && updatedAt != null) {
      json['updatedAt'] = updatedAt;
    }
    if (isActive != previous.isActive) {
      json['isActive'] = isActive;
    }
    if (discountPercentage != previous.discountPercentage &&
        discountPercentage != null) {
      json['discountPercentage'] = discountPercentage;
    }
    return json;
  }

  bool _areListsEqual(List? a, List? b) {
    if (a == b) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Helper method to calculate average rating
  double get averageRating {
    if (totalRating != null && ratingCount != null && ratingCount! > 0) {
      return totalRating! / ratingCount!;
    } else if (rating != null) {
      return rating!;
    }
    return 0.0;
  }

  // Helper method to check if service has ratings
  bool get hasRatings {
    return (ratingCount != null && ratingCount! > 0) ||
        (rating != null && rating! > 0);
  }

  DateTime _getMiddleEastNow({DateTime? time}) {
    return time ?? DateTime.now();
  }

  bool isOnWorkHour({DateTime? currentTime}) {
    final referenceTime = currentTime ?? _getMiddleEastNow();
    if (workingDays != null && !workingDays!.contains(referenceTime.weekday)) {
      return false; // It's a holiday, therefore off work hour
    }
    if (workStartTime == null || workEndTime == null) return true;
    try {
      final startParts = workStartTime!.split(':');
      final endParts = workEndTime!.split(':');

      final startHour = int.parse(startParts[0]);
      final startMinute = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMinute = int.parse(endParts[1]);

      final currentMinutes = referenceTime.hour * 60 + referenceTime.minute;
      final startMinutes = startHour * 60 + startMinute;
      final endMinutes = endHour * 60 + endMinute;

      if (startMinutes <= endMinutes) {
        return currentMinutes >= startMinutes && currentMinutes < endMinutes;
      } else {
        return currentMinutes >= startMinutes || currentMinutes < endMinutes;
      }
    } catch (e) {
      return true;
    }
  }

  bool get isCurrentlyOnHour => isOnWorkHour();

  double getCurrentPrice({DateTime? currentTime}) {
    if (workStartTime == null ||
        workEndTime == null ||
        onWorkHourPrice == null ||
        offWorkHourPrice == null ||
        onWorkHourPrice == 0 ||
        offWorkHourPrice == 0) {
      return price ?? 0.0;
    }

    if (isOnWorkHour(currentTime: currentTime)) {
      return onWorkHourPrice!;
    } else {
      return offWorkHourPrice!;
    }
  }

  double getDiscountedPrice(double currentPrice) {
    if (discountPercentage == null || discountPercentage! <= 0) {
      return currentPrice;
    }
    return currentPrice * (1.00 - (discountPercentage! / 100.00));
  }
}
