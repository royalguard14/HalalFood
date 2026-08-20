class Address {
  final String id;
  final String userId;
  final String? label;
  final String recipientName;
  final String? phone;
  final String addressLine;
  final String? barangay;
  final String? city;
  final String? province;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Address({
    required this.id,
    required this.userId,
    this.label,
    required this.recipientName,
    this.phone,
    required this.addressLine,
    this.barangay,
    this.city,
    this.province,
    this.latitude,
    this.longitude,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Address.fromMap(
    Map<String, dynamic> map,
  ) {
    return Address(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      label: map['label'] as String?,
      recipientName:
          map['recipient_name'] as String? ?? '',
      phone: map['phone'] as String?,
      addressLine:
          map['address_line'] as String? ?? '',
      barangay: map['barangay'] as String?,
      city: map['city'] as String?,
      province: map['province'] as String?,
      latitude:
          (map['latitude'] as num?)?.toDouble(),
      longitude:
          (map['longitude'] as num?)?.toDouble(),
      isDefault:
          map['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(
        map['created_at'].toString(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'].toString(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'label': label,
      'recipient_name': recipientName,
      'phone': phone,
      'address_line': addressLine,
      'barangay': barangay,
      'city': city,
      'province': province,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}