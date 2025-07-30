import 'package:cloud_firestore/cloud_firestore.dart';

class BannerModel {
  String? id;

  /// The section of the app where the banner will be displayed, 1,2
  int? section;
  String? label;
  String? image;
  String? url;
  bool? active;

  Timestamp? createdAt;
  Timestamp? updatedAt;

  BannerModel({
    this.id,
    this.section = 1,
    this.label,
    this.image,
    this.url,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  BannerModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    section = json['section'] ?? 1;
    label = json['label'];
    image = json['image'];
    url = json['url'];
    active = json['active'] ?? true;

    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'section': section,
      'label': label,
      'image': image,
      'url': url,
      'active': active,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> toEditJson({required BannerModel previous}) {
    Map<String, dynamic> json = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (section != previous.section) {
      json['section'] = section;
    }
    if (label != previous.label && label != null) {
      json['label'] = label;
    }
    if (image != previous.image && image != null) {
      json['image'] = image;
    }
    if (url != previous.url && url != null) {
      json['url'] = url;
    }
    if (createdAt != previous.createdAt && createdAt != null) {
      json['createdAt'] = createdAt;
    }
    if (active != previous.active) {
      json['active'] = active;
    }
    return json;
  }

  factory BannerModel.fromQueryDocumentSnapshot(
      QueryDocumentSnapshot snapshot) {
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    return BannerModel.fromJson(data)..id = snapshot.id;
  }

  factory BannerModel.fromDocumentSnapshot(DocumentSnapshot snapshot) {
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    return BannerModel.fromJson(data)..id = snapshot.id;
  }

  // copy with
  BannerModel copyWith({
    String? id,
    int? section,
    String? label,
    String? image,
    String? url,
    bool? active,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return BannerModel(
      id: id ?? this.id,
      section: section ?? this.section,
      label: label ?? this.label,
      image: image ?? this.image,
      url: url ?? this.url,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
