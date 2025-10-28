class AllTipsModel {
  DateTime? createdAt;
  DateTime? updatedAt;
  String? agentId;
  String? id;
  double? totalTipAmount;
  List<Map<String, dynamic>>? proofs;

  AllTipsModel({this.agentId, this.id, this.proofs, this.totalTipAmount});

  AllTipsModel.fromJson(Map<String, dynamic> json) {
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    agentId = json['agentId'];
    id = json['id'];
    totalTipAmount = json['totalTipAmount'];
    proofs = json['proofs'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    data['agentId'] = agentId;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['id'] = id;
    data['totalTipAmount'] = totalTipAmount;
    data['proofs'] = proofs;
    return data;
  }
}
