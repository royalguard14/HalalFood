import 'package:flutter/foundation.dart';

import '../data/cart_item.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount {
    return _items.fold(
      0,
      (total, item) => total + item.quantity,
    );
  }

  double get total {
    return _items.fold(
      0,
      (total, item) => total + item.subtotal,
    );
  }

  String? get restaurantId {
    if (_items.isEmpty) {
      return null;
    }

    return _items.first.item.restaurantId;
  }

  bool get isEmpty {
    return _items.isEmpty;
  }

  bool canAddItem(CartItem item) {
    if (_items.isEmpty) {
      return true;
    }

    return _items.first.item.restaurantId ==
        item.item.restaurantId;
  }

  bool addItem(CartItem item) {
    if (!canAddItem(item)) {
      return false;
    }

    final index = _items.indexWhere(
      (cartItem) => cartItem.item.id == item.item.id,
    );

    if (index >= 0) {
      _items[index].quantity += item.quantity;
    } else {
      _items.add(item);
    }

    notifyListeners();

    return true;
  }

  void removeItem(String itemId) {
    _items.removeWhere(
      (item) => item.item.id == itemId,
    );

    notifyListeners();
  }

  void updateQuantity(
    String itemId,
    int quantity,
  ) {
    final index = _items.indexWhere(
      (item) => item.item.id == itemId,
    );

    if (index == -1) {
      return;
    }

    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index].quantity = quantity;
    }

    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}