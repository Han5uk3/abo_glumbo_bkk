class CustomerSupportModel {
  final String? id;
  final String type;
  final String name;
  final String detail;
  final bool? isActive;

  CustomerSupportModel({
    this.id,
    required this.type,
    required this.name,
    this.isActive,
    required this.detail,
  });

  factory CustomerSupportModel.fromJson(Map<String, dynamic> json) {
    return CustomerSupportModel(
      id: json['id'],
      type: json['type'],
      name: json['name'],
      detail: json['detail'],
      isActive: json['isActive'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'detail': detail,
    'isActive': isActive,
  };

  CustomerSupportModel copyWith({
    String? id,
    String? type,
    String? name,
    String? detail,
    bool? isActive,
  }) {
    return CustomerSupportModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      detail: detail ?? this.detail,
      isActive: isActive ?? this.isActive,
    );
  }
}
