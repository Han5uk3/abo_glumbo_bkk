// ignore_for_file: non_constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';

class HighlightedServicesModel {
  String? id;
  bool? active;
  String? title;
  String? title_ar;
  String? titleLocalized({required String languageCode}) {
    if (languageCode == 'ar') {
      return title_ar;
    }
    return title;
  }

  int? sortOrder;
  List<String>? services;

  Timestamp? createdAt;
  Timestamp? updatedAt;

  HighlightedServicesModel({
    this.id,
    this.active,
    this.title,
    this.title_ar,
    this.sortOrder,
    this.services,
    this.createdAt,
    this.updatedAt,
  });

  factory HighlightedServicesModel.fromQueryDocumentSnapshot(
    QueryDocumentSnapshot<Object?> doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;

    return HighlightedServicesModel(
      id: doc.id,
      active: data['active'] as bool?,
      title: data['title'] as String?,
      title_ar: data['title_ar'] ?? data['title'] as String?,
      sortOrder: data['sortOrder'] as int?,
      services: List<String>.from(data['services'] as List<dynamic>),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  // copyWith method
  HighlightedServicesModel copyWith({
    String? id,
    bool? active,
    String? title,
    String? title_ar,
    int? sortOrder,
    List<String>? services,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return HighlightedServicesModel(
      id: id ?? this.id,
      active: active ?? this.active,
      title: title ?? this.title,
      title_ar: title_ar ?? this.title_ar,
      sortOrder: sortOrder ?? this.sortOrder,
      services: services ?? this.services,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // toMap method
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'active': active,
      'title': title,
      'title_ar': title_ar,
      'sortOrder': sortOrder,
      'services': services,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // toEditMap method
  Map<String, dynamic> toEditJson({
    required HighlightedServicesModel previous,
  }) {
    Map<String, dynamic> json = {};
    if (active != previous.active) {
      json['active'] = active;
    }
    if (title != previous.title && title != null) {
      json['title'] = title;
    }
    if (title_ar != previous.title_ar && title_ar != null) {
      json['title_ar'] = title_ar;
    }
    if (sortOrder != previous.sortOrder && sortOrder != null) {
      json['sortOrder'] = sortOrder;
    }
    if (services != previous.services && services != null) {
      json['services'] = services;
    }
    if (updatedAt != previous.updatedAt && updatedAt != null) {
      json['updatedAt'] = updatedAt;
    }
    return json;
  }
}
