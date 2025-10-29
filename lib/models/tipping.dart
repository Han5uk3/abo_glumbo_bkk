import 'package:cloud_firestore/cloud_firestore.dart';

class TippingModel {
  String? agentId;
  String? agentName;
  String? agentPhone;
  double? cashtip;
  DateTime? lastUpdated;
  double? cardtip;
  String? walletId;
  bool? payoutRequested;

  TippingModel({
    this.agentId,
    this.agentName,
    this.agentPhone,
    this.cashtip,
    this.lastUpdated,
    this.cardtip,
    this.walletId,
    this.payoutRequested,
  });

  TippingModel.fromJson(Map<String, dynamic> json) {
    agentId = json['agentId'];
    agentName = json['agentName'];
    agentPhone = json['agentPhone'];
    cashtip = json['cashtip']?.toDouble();
    final timestamp = json['lastUpdated'];
    if (timestamp is Timestamp) {
      lastUpdated = timestamp.toDate();
    } else if (timestamp is String) {
      lastUpdated = DateTime.tryParse(timestamp);
    }
    cardtip = json['cardtip']?.toDouble();
    walletId = json['walletId'];
    payoutRequested = json['payoutRequested'] ?? false;
  }

  Map<String, dynamic> toJson() {
    return {
      'agentId': agentId,
      'agentName': agentName,
      'agentPhone': agentPhone,
      'cashtip': cashtip,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'cardtip': cardtip,
      'walletId': walletId,
      'payoutRequested': payoutRequested,
    };
  }

  TippingModel.fromSnapshot(DocumentSnapshot snapshot) {
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    agentId = data['agentId'];
    agentName = data['agentName'];
    agentPhone = data['agentPhone'];
    cashtip = data['cashtip']?.toDouble();
    final timestamp = data['lastUpdated'];
    if (timestamp is Timestamp) {
      lastUpdated = timestamp.toDate();
    } else if (timestamp is String) {
      lastUpdated = DateTime.tryParse(timestamp);
    }
    cardtip = data['cardtip']?.toDouble();
    walletId = data['walletId'];
    payoutRequested = data['payoutRequested'] ?? false;
  }

  factory TippingModel.fromMap(Map<String, dynamic> map) => TippingModel(
    agentId: map['agentId'],
    agentName: map['agentName'],
    agentPhone: map['agentPhone'],
    cashtip: map['cashtip']?.toDouble(),
    lastUpdated: map['lastUpdated']?.toDate(),
    cardtip: map['cardtip']?.toDouble(),
    walletId: map['walletId'],
    payoutRequested: map['payoutRequested'] ?? false,
  );

  Map<String, dynamic> toMap() => {
    'agentId': agentId,
    'agentName': agentName,
    'agentPhone': agentPhone,
    'cashtip': cashtip,
    'lastUpdated': lastUpdated,
    'cardtip': cardtip,
    'walletId': walletId,
    'payoutRequested': payoutRequested ?? false,
  };
}
