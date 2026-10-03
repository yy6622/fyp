import 'package:flutter/material.dart';

import '../models/booking_details.dart';

/// Controller for [FlightPassengerDetailsPage] — one [PassengerDetail] per
/// seat, kept in lockstep with the seat/quantity count (same idea as
/// [TravellerDetailsController] for Insurance, which this flow is modelled
/// on), plus a single contact email/phone for the whole booking (an actual
/// airline booking collects contact details once per booking, not once
/// per passenger).
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

  /// Returns false (and leaves the list unchanged) once [maxQuantity] is
  /// reached, so the view can show feedback — same contract as
  /// [TravellerDetailsController.addTraveller].
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

  // No notifyListeners() in the plain-text setters — these back a
  // TextField the widget itself already renders what was typed into, so
  // rebuilding the whole form on every keystroke would just fight the
  // field's own cursor (see TravellerDetailsController's equivalent note).
  void setName(int index, String value) => passengers[index].name = value;

  void setPassportNumber(int index, String value) => passengers[index].passportNumber = value;

  void setContactEmail(String value) => contactEmail = value;

  void setContactPhone(String value) => contactPhone = value;

  // DOB/Nationality/Passport Expiry go through picker sheets rather than a
  // text field, so there's no cursor to disturb — these do notify.
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

  /// The first validation problem found, or null once every required field
  /// for every passenger plus the booking contact is filled in.
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
    if (contactPhone.trim().isEmpty) return 'A contact phone number is required.';
    return null;
  }
}

/// Controller for [HotelGuestDetailsPage] — the guest's own contact/ID
/// details plus the stay's room count and check-in/check-out dates (moved
/// here from BookingPaymentPage so they're collected alongside the rest of
/// the guest details, in one step, before checkout).
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

  // Plain-text setters — no notifyListeners(), same reasoning as
  // FlightPassengerDetailsController's.
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
    if (phone.trim().isEmpty) return 'A contact phone number is required.';
    if (idNumber.trim().isEmpty) return 'A passport/ID number is required.';
    if (checkIn == null || checkOut == null) return 'Please select check-in and check-out dates.';
    return null;
  }
}
