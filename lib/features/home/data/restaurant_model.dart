class Restaurant {
  final String id;
  final String name;
  final String description;
  final String address;
  final String city;
  final String province;
  final String? logoUrl;
  final String? coverImageUrl;
  final String halalStatus;
  final bool isActive;
  final bool isFeatured;
  final double averageRating;
  final int reviewCount;

  const Restaurant({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.city,
    required this.province,
    this.logoUrl,
    this.coverImageUrl,
    required this.halalStatus,
    required this.isActive,
    required this.isFeatured,
    required this.averageRating,
    required this.reviewCount,
  });

  factory Restaurant.fromMap(Map<String, dynamic> map) {
    return Restaurant(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      address: map['address'] as String? ?? '',
      city: map['city'] as String? ?? '',
      province: map['province'] as String? ?? '',
      logoUrl: map['logo_url'] as String?,
      coverImageUrl: map['cover_image_url'] as String?,
      halalStatus: map['halal_status']?.toString() ?? '',
      isActive: map['is_active'] as bool? ?? false,
      isFeatured: map['is_featured'] as bool? ?? false,
      averageRating:
          (map['average_rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: map['review_count'] as int? ?? 0,
    );
  }
}