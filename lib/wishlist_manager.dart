import 'package:flutter/material.dart';

class WishlistManager extends ChangeNotifier {
  static final WishlistManager instance = WishlistManager._internal();
  WishlistManager._internal();

  final List<Map<String, dynamic>> _items = [];

  List<Map<String, dynamic>> get items => _items;

  int get totalCount => _items.length;

  bool isFavorite(String productId) {
    return _items.any((item) => item['id'] == productId);
  }

  void toggleFavorite(Map<String, dynamic> product) {
    final productId = product['id'];
    if (isFavorite(productId)) {
      _items.removeWhere((item) => item['id'] == productId);
    } else {
      _items.add(product);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item['id'] == productId);
    notifyListeners();
  }

  void clearWishlist() {
    _items.clear();
    notifyListeners();
  }
}