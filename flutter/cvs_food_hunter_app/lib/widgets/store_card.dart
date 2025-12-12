import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/store.dart';
import '../providers/favorites_provider.dart';

class StoreCard extends StatelessWidget {
  final Store store;

  const StoreCard({super.key, required this.store});

  Future<void> _launchPhone(String tel) async {
    final uri = Uri.parse('tel:$tel');
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('Error launching phone: $e');
    }
  }

  Future<void> _launchMaps(String address) async {
    // 嘗試使用 Google Maps URL Scheme
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching maps: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = context.watch<FavoritesProvider>();
    
    // 檢查是否有關注商品
    bool hasFavoriteItem = store.items.any((item) => favoritesProvider.isFavorite(item.name));
    
    // 金色設定
    final goldColor = Colors.amber[800]; // 用於文字和邊框，較深以利閱讀
    final starColor = Colors.amber; // 用於星星圖示

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      // 如果有關注商品，顯示特殊邊框
      shape: hasFavoriteItem 
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: goldColor!, width: 2),
            )
          : null,
      child: ExpansionTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: store.brand == '7-11' ? Colors.green : Colors.blue,
              child: Text(
                store.brand == '7-11' ? '7' : '全',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            if (hasFavoriteItem)
              Positioned(
                right: -2,
                top: -2,
                child: Icon(Icons.star, color: starColor, size: 16),
              ),
          ],
        ),
        title: Text(
          store.storeName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: hasFavoriteItem ? goldColor : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('距離: ${store.distance.toStringAsFixed(0)} 公尺'),
            Text('商品數: ${store.totalQty} 項'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 地址
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text(store.address)),
                    IconButton(
                      icon: const Icon(Icons.map, color: Colors.blue),
                      onPressed: () => _launchMaps(store.address),
                      tooltip: '開啟地圖',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 電話
                if (store.tel.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(store.tel)),
                      IconButton(
                        icon: const Icon(Icons.call, color: Colors.green),
                        onPressed: () => _launchPhone(store.tel),
                        tooltip: '撥打電話',
                      ),
                    ],
                  ),
                const Divider(height: 24),
                // 商品分類
                const Text(
                  '商品分類',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: store.categories.map((cat) {
                    return Chip(
                      label: Text('${cat.name} (${cat.qty})'),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // 商品列表
                const Text(
                  '商品明細',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...store.items.map((item) {
                  final isFavorite = favoritesProvider.isFavorite(item.name);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.star : Icons.star_border,
                            color: isFavorite ? starColor : Colors.grey,
                            size: 20,
                          ),
                          onPressed: () {
                            favoritesProvider.toggleFavorite(item.name);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              color: isFavorite ? goldColor : null,
                              fontWeight: isFavorite ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                        Text(
                          'x${item.qty}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
