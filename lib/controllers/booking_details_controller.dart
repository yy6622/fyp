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

final RegExp _passportPattern = RegExp(r'^[A-Za-z0-9]{5,12}$');

bool isValidPassportFormat(String value) => _passportPattern.hasMatch(value.trim());

// Malaysian NRIC (IC): 12 digits, YYMMDD-PB-###G, entered with or without
// the dashes (e.g. "901231-14-5566" or "901231145566").
final RegExp _icPattern = RegExp(r'^\d{6}-?\d{2}-?\d{4}$');

bool isValidICFormat(String value) => _icPattern.hasMatch(value.trim());

class FlightPassengerDetailsController extends ChangeNotifier {
  final int minQuantity;
  final int maxQuantity;

  final DateTime? departureAt;

  final List<PassengerDetail> passengers;
  String contactEmail = '';
  String contactPhone = '';

  FlightPassengerDetailsController({
    int initialQuantity = 1,
    this.minQuantity = 1,
    this.maxQuantity = 9,
    this.departureAt,
  }) : passengers = List.generate(initialQuantity.clamp(minQuantity, maxQuantity), (_) => PassengerDetail());

  int get quantity => passengers.length;

  DateTime get minPassportExpiry {
    final now = DateTime.now();
    final base = (departureAt != null && departureAt!.isAfter(now)) ? departureAt! : now;
    return DateTime(base.year, base.month + 6, base.day);
  }

  /// Grows/shrinks [passengers] to match a quantity picked up front (a
  /// stepper, same pattern as [HotelGuestDetailsController.setRooms]) —
  /// new entries are blank, extra ones are dropped from the end.
  void setQuantity(int value) {
    final target = value.clamp(minQuantity, maxQuantity);
    if (target == passengers.length) return;
    while (passengers.length < target) {
      passengers.add(PassengerDetail());
    }
    while (passengers.length > target) {
      passengers.removeLast();
    }
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

  void setGender(int index, String value) {
    passengers[index].gender = value;
    notifyListeners();
  }

  String? validate() {
    for (var i = 0; i < passengers.length; i++) {
      final p = passengers[i];
      final who = passengers.length > 1 ? 'Passenger ${i + 1}' : 'The passenger';
      if (p.name.trim().isEmpty) return "$who's full name is required.";
      if (p.gender == null || p.gender!.isEmpty) return "$who's gender is required.";
      if (p.dob == null) return "$who's date of birth is required.";
      if (p.nationality == null || p.nationality!.isEmpty) return "$who's nationality is required.";
      if (p.passportNumber.trim().isEmpty) return "$who's passport number is required.";
      if (!isValidPassportFormat(p.passportNumber)) return "$who's passport number doesn't look right — letters/digits only, 5-12 characters.";
      if (p.passportExpiry == null) return "$who's passport expiry date is required.";
      if (p.passportExpiry!.isBefore(minPassportExpiry)) {
        return departureAt != null
            ? "$who's passport must stay valid for at least 6 months after the flight departs."
            : "$who's passport must stay valid for at least 6 months from today.";
      }
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
    if (checkIn == null || checkOut == null) return 'Please select check-in and check-out dates.';
    return null;
  }
}
