import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'variantId': variantId,
        'name': name,
        'price': price,
        'imageUrl': imageUrl,
        'size': size,
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        productId: json['productId'] ?? '',
        variantId: json['variantId'],
        name: json['name'] ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        imageUrl: json['imageUrl'] ?? '',
        size: json['size'] ?? '',
        quantity: json['quantity'] ?? 1,
      );
}

class CartManager extends ChangeNotifier {
  static final CartManager instance = CartManager._internal();
  static const String _storageKey = 'eldoc_cart_items';

  CartManager._internal() {
    _loadFromStorage();
  }

  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  int get totalCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => _items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_storageKey);
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        _items.clear();
        _items.addAll(decoded.map((e) => CartItem.fromJson(e)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_items.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

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
    _saveToStorage();
    notifyListeners();
  }

  void updateQuantity(int index, int delta) {
    _items[index].quantity += delta;
    if (_items[index].quantity <= 0) {
      _items.removeAt(index);
    }
    _saveToStorage();
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _saveToStorage();
    notifyListeners();
  }
}