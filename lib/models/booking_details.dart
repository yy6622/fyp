/// The real-world fields a flight/hotel checkout actually needs beyond a
/// bare name — modelled separately from [TripFlight]/[TripHotelStay]
/// (lib/repositories/trip_repository.dart) so the checkout flow
/// (FlightPassengerDetailsPage / HotelGuestDetailsPage /
/// BookingPaymentPage) and the trip-plan models can both depend on the
/// same shape without a circular import between views and repositories.
library;

/// One flight passenger's details, as a real airline check-in/booking form
/// collects them: full legal name as printed on the passport, date of
/// birth, nationality, and passport number + expiry (every field an
/// international flight booking asks for, beyond just a name).
class PassengerDetail {
  String name;
  DateTime? dob;
  String? nationality;
  String passportNumber;
  DateTime? passportExpiry;

  PassengerDetail({
    this.name = '',
    this.dob,
    this.nationality,
    this.passportNumber = '',
    this.passportExpiry,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'dob': dob?.toIso8601String(),
        'nationality': nationality,
        'passportNumber': passportNumber,
        'passportExpiry': passportExpiry?.toIso8601String(),
      };

  factory PassengerDetail.fromMap(Map<String, dynamic> m) => PassengerDetail(
        name: (m['name'] as String?) ?? '',
        dob: m['dob'] != null ? DateTime.tryParse(m['dob'] as String) : null,
        nationality: m['nationality'] as String?,
        passportNumber: (m['passportNumber'] as String?) ?? '',
        passportExpiry: m['passportExpiry'] != null ? DateTime.tryParse(m['passportExpiry'] as String) : null,
      );
}
