import 'package:supabase_flutter/supabase_flutter.dart';

class PromoCode {
  final String id;
  final String code;
  final String title;
  final String? description;
  final String discountType;
  final double discountValue;
  final double minimumOrder;
  final double? maximumDiscount;
  final int? usageLimit;
  final int usageCount;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? restaurantId;

  const PromoCode({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    required this.discountType,
    required this.discountValue,
    required this.minimumOrder,
    this.maximumDiscount,
    this.usageLimit,
    required this.usageCount,
    this.startsAt,
    this.endsAt,
    this.restaurantId,
  });

  factory PromoCode.fromMap(Map<String, dynamic> map) {
    return PromoCode(
      id: map['id'] as String,
      code: map['code'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      discountType: (map['discount_type'] as String?) ?? 'fixed',
      discountValue: (map['discount_value'] as num).toDouble(),
      minimumOrder: ((map['minimum_order'] as num?) ?? 0).toDouble(),
      maximumDiscount: (map['maximum_discount'] as num?)?.toDouble(),
      usageLimit: map['usage_limit'] as int?,
      usageCount: (map['usage_count'] as int?) ?? 0,
      startsAt: _date(map['starts_at']),
      endsAt: _date(map['ends_at']),
      restaurantId: map['restaurant_id'] as String?,
    );
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  bool get isGlobal => restaurantId == null;

  double calculateDiscount(double subtotal) {
    if (subtotal < minimumOrder) return 0;

    double discount;
    switch (discountType.toLowerCase()) {
      case 'percentage':
      case 'percent':
        discount = subtotal * discountValue / 100;
        break;
      case 'fixed':
      case 'amount':
      default:
        discount = discountValue;
    }

    if (maximumDiscount != null) {
      discount = discount.clamp(0, maximumDiscount!);
    }

    return discount.clamp(0, subtotal).toDouble();
  }

  String get discountLabel {
    switch (discountType.toLowerCase()) {
      case 'percentage':
      case 'percent':
        return '${discountValue.toStringAsFixed(0)}% OFF';
      default:
        return '₱${discountValue.toStringAsFixed(2)} OFF';
    }
  }
}

class PromoCodeRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<PromoCode>> getAvailablePromos({
    required String restaurantId,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final response = await _supabase
        .from('promo_codes')
        .select()
        .or('restaurant_id.is.null,restaurant_id.eq.$restaurantId')
        .eq('is_active', true)
        .or('starts_at.is.null,starts_at.lte.$nowIso')
        .or('ends_at.is.null,ends_at.gte.$nowIso')
        .order('restaurant_id', ascending: true)
        .order('created_at', ascending: false);

    final promos = (response as List)
        .map((row) => PromoCode.fromMap(row))
        .where((promo) =>
            promo.usageLimit == null ||
            promo.usageCount < promo.usageLimit!)
        .toList();

    if (promos.isEmpty) return promos;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return promos;

    final used = await _supabase
        .from('promo_redemptions')
        .select('promo_code_id')
        .eq('customer_id', userId)
        .inFilter('promo_code_id', promos.map((p) => p.id).toList());

    final usedIds = (used as List)
        .map((row) => row['promo_code_id'] as String)
        .toSet();

    return promos.where((promo) => !usedIds.contains(promo.id)).toList();
  }
}
