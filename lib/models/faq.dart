import 'package:cloud_firestore/cloud_firestore.dart';

class FaqModel {
  final String id;
  final int? stand;
  final String questionEn;
  final String questionAr;
  final String answerEn;
  final String answerAr;

  FaqModel(
    this.stand, {
    required this.id,
    required this.questionEn,
    required this.questionAr,
    required this.answerEn,
    required this.answerAr,
  });

  factory FaqModel.fromMap(Map<String, dynamic> map) {
    return FaqModel(
      map['stand'],
      id: map['id'],
      questionEn: map['questionEn'],
      questionAr: map['questionAr'],
      answerEn: map['answerEn'],
      answerAr: map['answerAr'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stand': stand,
      'id': id,
      'questionEn': questionEn,
      'questionAr': questionAr,
      'answerEn': answerEn,
      'answerAr': answerAr,
    };
  }

  static fromDocumentSnapshot(QueryDocumentSnapshot<Object?> doc) {
    return FaqModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  factory FaqModel.fromJson(Map<String, dynamic> json) {
    return FaqModel(
      json['stand'],
      id: json['id'],
      questionEn: json['questionEn'],
      questionAr: json['questionAr'],
      answerEn: json['answerEn'],
      answerAr: json['answerAr'],
    );
  }
}
