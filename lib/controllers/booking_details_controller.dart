import 'package:flutter/material.dart';

import '../models/booking_details.dart';

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmailFormat(String value) => _emailPattern.hasMatch(value.trim());

bool isValidPhoneFormat(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  if (!RegExp(r'^[0-9+\-\s()]+$').hasMatch(trimmed)) return false;
  final digitCount = trimmed.replaceAll(RegExp(r'[^0-9]'), '').length;
  return digitCount >= 7 && digitCount <= 15;
}

class FlightPassengerDetailsController extends ChangeNotifier {
  final int minQuantity;
  final int maxQuantity;

  final List<PassengerDetail> passengers;
  String contactEmail = '';
  String contactPhone = '';

  FlightPassengerDetailsController({
    int initialQuantity = 1,
    this.minQuantity = 1,
    this.maxQuantity = 9,
  }) : passengers = List.generate(initialQuantity.clamp(minQuantity, maxQuantity), (_) => PassengerDetail());

  int get quantity => passengers.length;

  bool addPassenger() {
    if (passengers.length >= maxQuantity) return false;
    passengers.add(PassengerDetail());
    notifyListeners();
    return true;
  }

  void removePassenger(int index) {
    if (passengers.length <= minQuantity) return;
    passengers.removeAt(index);
    notifyListeners();
  }

  void setName(int index, String value) => passengers[index].name = value;

  void setPassportNumber(int index, String value) => passengers[index].passportNumber = value;

  void setContactEmail(String value) => contactEmail = value;

  void setContactPhone(String value) => contactPhone = value;

  void setDob(int index, DateTime value) {
    passengers[index].dob = value;
    notifyListeners();
  }

  void setNationality(int index, String value) {
    passengers[index].nationality = value;
    notifyListeners();
  }

  void setPassportExpiry(int index, DateTime value) {
    passengers[index].passportExpiry = value;
    notifyListeners();
  }

  String? validate() {
    for (var i = 0; i < passengers.length; i++) {
      final p = passengers[i];
      final who = passengers.length > 1 ? 'Passenger ${i + 1}' : 'The passenger';
      if (p.name.trim().isEmpty) return "$who's full name is required.";
      if (p.dob == null) return "$who's date of birth is required.";
      if (p.nationality == null || p.nationality!.isEmpty) return "$who's nationality is required.";
      if (p.passportNumber.trim().isEmpty) return "$who's passport number is required.";
      if (p.passportExpiry == null) return "$who's passport expiry date is required.";
    }
    if (contactEmail.trim().isEmpty) return 'A contact email is required.';
    if (!isValidEmailFormat(contactEmail)) return 'Please enter a valid contact email address.';
    if (contactPhone.trim().isEmpty) return 'A contact phone number is required.';
    if (!isValidPhoneFormat(contactPhone)) return 'Please enter a valid contact phone number.';
    return null;
  }
}

class HotelGuestDetailsController extends ChangeNotifier {
  final int minQuantity;
  final int maxQuantity;

  int _rooms;
  int get rooms => _rooms;

  String fullName = '';
  String email = '';
  String phone = '';
  String idNumber = '';
  String specialRequests = '';
  DateTime? checkIn;
  DateTime? checkOut;

  HotelGuestDetailsController({
    int initialRooms = 1,
    this.minQuantity = 1,
    this.maxQuantity = 9,
    this.checkIn,
    this.checkOut,
  }) : _rooms = initialRooms.clamp(minQuantity, maxQuantity);

  void setRooms(int value) {
    final clamped = value.clamp(minQuantity, maxQuantity);
    if (clamped == _rooms) return;
    _rooms = clamped;
    notifyListeners();
  }

  void setFullName(String value) => fullName = value;
  void setEmail(String value) => email = value;
  void setPhone(String value) => phone = value;
  void setIdNumber(String value) => idNumber = value;
  void setSpecialRequests(String value) => specialRequests = value;

  void setDates(DateTime start, DateTime end) {
    checkIn = start;
    checkOut = end;
    notifyListeners();
  }

  String? validate() {
    if (fullName.trim().isEmpty) return "The guest's full name is required.";
    if (email.trim().isEmpty) return 'A contact email is required.';
    if (!isValidEmailFormat(email)) return 'Please enter a valid email address.';
    if (phone.trim().isEmpty) return 'A contact phone number is required.';
    if (!isValidPhoneFormat(phone)) return 'Please enter a valid phone number.';
    if (idNumber.trim().isEmpty) return 'A passport/ID number is required.';
    if (checkIn == null || checkOut == null) return 'Please select check-in and check-out dates.';
    return null;
  }
}
