library;

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
