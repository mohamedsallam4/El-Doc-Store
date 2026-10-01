import 'package:flutter/material.dart';

class CartItem {
  final String productId;
  final String? variantId;
  final String name;
  final double price;
  final String imageUrl;
  final String size;
  int quantity;

  CartItem({
    required this.productId,
    this.variantId,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.size,
    this.quantity = 1,
  });
}

class CartManager extends ChangeNotifier {
  static final CartManager instance = CartManager._internal();
  CartManager._internal();

  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  int get totalCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => _items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  void addItem({
    required String productId,
    String? variantId,
    required String name,
    required double price,
    required String imageUrl,
    required String size,
  }) {
    final existingIndex = _items.indexWhere(
      (item) => item.productId == productId && item.size == size,
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(
        productId: productId,
        variantId: variantId,
        name: name,
        price: price,
        imageUrl: imageUrl,
        size: size,
      ));
    }
    notifyListeners();
  }

  void updateQuantity(int index, int delta) {
    _items[index].quantity += delta;
    if (_items[index].quantity <= 0) {
      _items.removeAt(index);
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}