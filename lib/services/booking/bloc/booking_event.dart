import 'package:equatable/equatable.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'dart:io';

abstract class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => [];
}

class CreateBookingEvent extends BookingEvent {
  final ServiceModel service;
  final DateTime selectedDate;
  final CustomerModel customerData;
  final String notes;
  final File? selectedImage;
  final File? selectedVideo;
  final Map timeSlot;
  final UserModel agent;
  final AddressModel? selectedAddress;

  const CreateBookingEvent({
    required this.service,
    required this.selectedDate,
    required this.customerData,
    required this.notes,
    this.selectedImage,
    this.selectedVideo,
    required this.timeSlot,
    required this.agent,
    this.selectedAddress,
  });

  @override
  List<Object?> get props => [
    service,
    selectedDate,
    customerData,
    notes,
    selectedImage,
    selectedVideo,
    timeSlot,
    agent,
    selectedAddress,
  ];
}
