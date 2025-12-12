class Store {
  final String brand;
  final String storeNo;
  final String storeName;
  final String address;
  final String tel;
  final double distance;
  final int totalQty;
  final List<Category> categories;
  final List<Item> items;
  final DateTime? fetchTime;

  Store({
    required this.brand,
    required this.storeNo,
    required this.storeName,
    required this.address,
    required this.tel,
    required this.distance,
    required this.totalQty,
    required this.categories,
    required this.items,
    this.fetchTime,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      brand: json['brand'] ?? '',
      storeNo: json['store_no'] ?? '',
      storeName: json['store_name'] ?? '',
      address: json['address'] ?? '',
      tel: json['tel'] ?? '',
      distance: (json['distance'] ?? 0).toDouble(),
      totalQty: json['total_qty'] ?? 0,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((c) => Category.fromJson(c))
              .toList() ??
          [],
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => Item.fromJson(i))
              .toList() ??
          [],
      fetchTime: json['fetch_time'] != null 
          ? DateTime.parse(json['fetch_time']) 
          : null,
    );
  }
}

class Category {
  final String name;
  final int qty;

  Category({
    required this.name,
    required this.qty,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      name: json['name'] ?? '',
      qty: json['qty'] ?? 0,
    );
  }
}

class Item {
  final String name;
  final int qty;
  final String category;
  final String? subCategory;

  Item({
    required this.name,
    required this.qty,
    required this.category,
    this.subCategory,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      name: json['name'] ?? '',
      qty: json['qty'] ?? 0,
      category: json['category'] ?? '',
      subCategory: json['sub_category'],
    );
  }
}
