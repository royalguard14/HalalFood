import '../../restaurant/data/menu_item_model.dart';

class CartItem {
  final MenuItem item;
  int quantity;

  CartItem({
    required this.item,
    this.quantity = 1,
  });

  double get subtotal {
    return item.price * quantity;
  }
}