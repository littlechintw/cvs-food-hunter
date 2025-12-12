import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/store.dart';

class ApiService {
  // 7-11 API
  static const String sevenElevenBaseUrl = 'https://lovefood.openpoint.com.tw/LoveFood/api/';
  static const String sevenElevenMidV = 'W0_DiF4DlgU5OeQoRswrRcaaNHMWOL7K3ra3385ocZcv-bBOWySZvoUtH6j-7pjiccl0C5h30uRUNbJXsABCKMqiekSb7tdiBNdVq8Ro5jgk6sgvhZla5iV0H3-8dZfASc7AhEm85679LIK3hxN7Sam6D0LAnYK9Lb0DZhn7xeTeksB4IsBx4Msr_VI';
  
  // 全家 API
  static const String familyMartBaseUrl = 'https://stamp.family.com.tw/api/maps';
  static const String familyMartProjectCode = '202106302';

  // 快取設定
  static const Duration _cacheDuration = Duration(minutes: 5);
  static const double _cacheDistance = 200; // 公尺

  // 快取資料
  String? _sevenElevenToken;
  
  List<Store>? _cachedSevenEleven;
  DateTime? _sevenElevenCacheTime;
  double? _sevenElevenCacheLat;
  double? _sevenElevenCacheLon;

  List<Store>? _cachedFamilyMart;
  DateTime? _familyMartCacheTime;
  double? _familyMartCacheLat;
  double? _familyMartCacheLon;

  // 7-11: 取得 Access Token
  Future<String> _getSevenElevenToken() async {
    if (_sevenElevenToken != null) {
      return _sevenElevenToken!;
    }

    try {
      final response = await http.post(
        Uri.parse('${sevenElevenBaseUrl}Auth/FrontendAuth/AccessToken?mid_v=$sevenElevenMidV'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://lovefood.openpoint.com.tw/'
        },
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['isSuccess'] == true) {
          _sevenElevenToken = data['element'];
          return _sevenElevenToken!;
        }
      }
      throw Exception('Failed to get 7-11 access token');
    } catch (e) {
      print('Error getting 7-11 token: $e');
      rethrow;
    }
  }

  // 7-11: 搜尋附近門市
  Future<List<Store>> searchSevenEleven({
    required double latitude,
    required double longitude,
    double maxDistance = 1000,
    int maxStores = 10,
    bool forceRefresh = false,
  }) async {
    // 檢查快取
    if (!forceRefresh && _sevenElevenCacheTime != null && _cachedSevenEleven != null) {
      final dist = _calculateDistance(latitude, longitude, _sevenElevenCacheLat!, _sevenElevenCacheLon!);
      if (dist < _cacheDistance && DateTime.now().difference(_sevenElevenCacheTime!) < _cacheDuration) {
        print('Using 7-11 cache');
        return _cachedSevenEleven!;
      }
    }

    try {
      final token = await _getSevenElevenToken();

      // 取得附近門市列表
      final storesResponse = await http.post(
        Uri.parse('${sevenElevenBaseUrl}Search/FrontendStoreItemStock/GetNearbyStoreList?token=$token'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        body: json.encode({
          'CurrentLocation': {'Latitude': latitude, 'Longitude': longitude},
          'SearchLocation': {'Latitude': latitude, 'Longitude': longitude}
        }),
      );

      if (storesResponse.statusCode != 200) {
        return [];
      }

      final storesData = json.decode(storesResponse.body);
      if (storesData['isSuccess'] != true) {
        return [];
      }

      final storesList = storesData['element']['StoreStockItemList'] as List<dynamic>? ?? [];
      
      // 過濾有即期品且在距離範圍內的門市
      final filteredStores = storesList.where((store) {
        final remainingQty = store['RemainingQty'] ?? 0;
        final distance = (store['Distance'] ?? double.infinity).toDouble();
        return remainingQty > 0 && distance <= maxDistance;
      }).toList();

      List<Store> results = [];

      for (var store in filteredStores.take(maxStores)) {
        final storeNo = store['StoreNo'] ?? '';
        final storeName = store['StoreName'] ?? '';
        final distance = (store['Distance'] ?? 0).toDouble();
        final remainingQty = store['RemainingQty'] ?? 0;
        final categoryItems = store['CategoryStockItems'] as List<dynamic>? ?? [];

        List<Map<String, dynamic>> categoryList = [];
        List<Map<String, dynamic>> itemList = [];

        // 加入分類資訊
        for (var cat in categoryItems) {
          categoryList.add({
            'name': cat['Name'] ?? '',
            'qty': cat['RemainingQty'] ?? 0,
          });
        }

        // 取得門市詳細資訊
        String address = '';
        String tel = '';
        
        try {
          final detailResponse = await http.post(
            Uri.parse('${sevenElevenBaseUrl}Search/FrontendStoreItemStock/GetStoreDetail?token=$token'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
            body: json.encode({
              'storeNo': storeNo,
              'CurrentLocation': {'Latitude': latitude, 'Longitude': longitude}
            }),
          );

          if (detailResponse.statusCode == 200) {
            final detailData = json.decode(detailResponse.body);
            if (detailData['isSuccess'] == true) {
              final element = detailData['element'];
              final storeStockItem = element['StoreStockItem'];
              final categoryStockItems = storeStockItem['CategoryStockItems'] as List<dynamic>? ?? [];

              // 取得商品詳情
              for (var cat in categoryStockItems) {
                final catName = cat['Name'] ?? '';
                final items = cat['ItemList'] as List<dynamic>? ?? [];

                for (var item in items) {
                  itemList.add({
                    'name': item['ItemName'] ?? '',
                    'qty': item['RemainingQty'] ?? 0,
                    'category': catName,
                  });
                }
              }
            }
          }

          // 查詢地址資訊
          final addressResponse = await http.post(
            Uri.parse('${sevenElevenBaseUrl}Master/FrontendStore/GetStoreByAddress?token=$token&keyword=$storeName'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
            body: json.encode({}),
          );

          if (addressResponse.statusCode == 200) {
            final addressData = json.decode(addressResponse.body);
            if (addressData['isSuccess'] == true) {
              final stores = addressData['element'] as List<dynamic>? ?? [];
              if (stores.isNotEmpty) {
                final storeDetail = stores.firstWhere(
                  (s) => s['StoreName'] == storeName,
                  orElse: () => stores[0],
                );
                address = storeDetail['Address'] ?? '';
                tel = storeDetail['Telno'] ?? '';
              }
            }
          }
        } catch (e) {
          print('Error getting store detail: $e');
        }

        results.add(Store.fromJson({
          'brand': '7-11',
          'store_no': storeNo,
          'store_name': '7-11 $storeName門市',
          'address': address,
          'tel': tel,
          'distance': distance,
          'total_qty': remainingQty,
          'categories': categoryList,
          'items': itemList,
          'fetch_time': DateTime.now().toIso8601String(),
        }));
      }

      // 更新快取
      _cachedSevenEleven = results;
      _sevenElevenCacheTime = DateTime.now();
      _sevenElevenCacheLat = latitude;
      _sevenElevenCacheLon = longitude;

      return results;
    } catch (e) {
      print('Error searching 7-11: $e');
      return [];
    }
  }

  // 全家: 計算距離
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // 地球半徑（公尺）

    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lon2 - lon1) * pi / 180;

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // 全家: 搜尋即期品
  Future<List<Store>> searchFamilyMart({
    required double latitude,
    required double longitude,
    double maxDistance = 1000,
    int maxStores = 10,
    bool forceRefresh = false,
  }) async {
    // 檢查快取
    if (!forceRefresh && _familyMartCacheTime != null && _cachedFamilyMart != null) {
      final dist = _calculateDistance(latitude, longitude, _familyMartCacheLat!, _familyMartCacheLon!);
      if (dist < _cacheDistance && DateTime.now().difference(_familyMartCacheTime!) < _cacheDuration) {
        print('Using FamilyMart cache');
        return _cachedFamilyMart!;
      }
    }

    try {
      final response = await http.post(
        Uri.parse('$familyMartBaseUrl/MapProductInfo'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        },
        body: json.encode({
          'ProjectCode': familyMartProjectCode,
          'OldPKeys': [],
          'PostInfo': '',
          'Latitude': latitude,
          'Longitude': longitude,
        }),
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body);
      final stores = data['data'] as List<dynamic>? ?? [];

      List<Store> results = [];

      for (var store in stores) {
        final storeLat = (store['latitude'] ?? 0).toDouble();
        final storeLon = (store['longitude'] ?? 0).toDouble();

        if (storeLat != 0 && storeLon != 0) {
          final distance = _calculateDistance(latitude, longitude, storeLat, storeLon);

          if (distance <= maxDistance) {
            final info = store['info'] as List<dynamic>? ?? [];

            List<Map<String, dynamic>> categoryList = [];
            List<Map<String, dynamic>> itemList = [];
            int totalQty = 0;

            for (var category in info) {
              final catName = category['name'] ?? '';
              final catQty = category['qty'] ?? 0;
              totalQty += catQty as int;

              categoryList.add({'name': catName, 'qty': catQty});

              final subCategories = category['categories'] as List<dynamic>? ?? [];
              for (var subCat in subCategories) {
                final subCatName = subCat['name'] ?? '';
                final products = subCat['products'] as List<dynamic>? ?? [];

                for (var product in products) {
                  itemList.add({
                    'name': product['name'] ?? '',
                    'qty': product['qty'] ?? 0,
                    'category': catName,
                    'sub_category': subCatName,
                  });
                }
              }
            }

            if (totalQty > 0) {
              results.add(Store.fromJson({
                'brand': '全家',
                'store_no': store['oldPKey'] ?? '',
                'store_name': store['name'] ?? '',
                'address': store['address'] ?? '',
                'tel': store['tel'] ?? '',
                'distance': distance,
                'total_qty': totalQty,
                'categories': categoryList,
                'items': itemList,
                'fetch_time': DateTime.now().toIso8601String(),
              }));
            }
          }
        }
      }

      results.sort((a, b) => a.distance.compareTo(b.distance));
      
      final finalResults = results.take(maxStores).toList();

      // 更新快取
      _cachedFamilyMart = finalResults;
      _familyMartCacheTime = DateTime.now();
      _familyMartCacheLat = latitude;
      _familyMartCacheLon = longitude;

      return finalResults;
    } catch (e) {
      print('Error searching Family Mart: $e');
      return [];
    }
  }

  // 搜尋所有門市
  Future<List<Store>> searchAll({
    required double latitude,
    required double longitude,
    double maxDistance = 1000,
    int maxStores = 10,
    bool forceRefresh = false,
  }) async {
    final results = await Future.wait([
      searchSevenEleven(
        latitude: latitude,
        longitude: longitude,
        maxDistance: maxDistance,
        maxStores: maxStores,
        forceRefresh: forceRefresh,
      ),
      searchFamilyMart(
        latitude: latitude,
        longitude: longitude,
        maxDistance: maxDistance,
        maxStores: maxStores,
        forceRefresh: forceRefresh,
      ),
    ]);

    final allStores = [...results[0], ...results[1]];
    allStores.sort((a, b) => a.distance.compareTo(b.distance));
    return allStores;
  }
}
