import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WishlistManager extends ChangeNotifier {
  static final WishlistManager instance = WishlistManager._internal();
  static const String _storageKey = 'eldoc_wishlist_items';

  WishlistManager._internal() {
    _loadFromStorage();
  }

  final List<Map<String, dynamic>> _items = [];

  List<Map<String, dynamic>> get items => _items;

  int get totalCount => _items.length;

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_storageKey);
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        _items.clear();
        _items.addAll(decoded.map((e) => Map<String, dynamic>.from(e)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading wishlist: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_items);
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('Error saving wishlist: $e');
    }
  }

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
    _saveToStorage();
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item['id'] == productId);
    _saveToStorage();
    notifyListeners();
  }

  void clearWishlist() {
    _items.clear();
    _saveToStorage();
    notifyListeners();
  }
}