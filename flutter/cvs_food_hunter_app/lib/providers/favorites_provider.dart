import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesProvider with ChangeNotifier {
  List<String> _favoriteItems = [];

  List<String> get favoriteItems => _favoriteItems;

  FavoritesProvider() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteItems = prefs.getStringList('favorite_items') ?? [];
    notifyListeners();
  }

  Future<void> toggleFavorite(String itemName) async {
    if (_favoriteItems.contains(itemName)) {
      _favoriteItems.remove(itemName);
    } else {
      _favoriteItems.add(itemName);
    }
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_items', _favoriteItems);
  }

  bool isFavorite(String itemName) {
    return _favoriteItems.contains(itemName);
  }
}
