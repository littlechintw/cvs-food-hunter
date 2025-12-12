import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../models/store.dart';
import '../providers/favorites_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/store_card.dart';
import 'favorites_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<Store> _stores = [];
  bool _isLoading = false;
  Position? _currentPosition;
  double _searchRadius = 500; // 預設 500 公尺
  String _selectedBrand = 'all'; // all, 7-11, 全家

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    final locationService = context.read<LocationService>();
    final position = await locationService.getCurrentLocation();
    
    if (position != null) {
      setState(() {
        _currentPosition = position;
      });
      _searchStores();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法取得位置資訊，請檢查定位權限')),
        );
      }
    }
  }

  Future<void> _searchStores({bool forceRefresh = false}) async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      List<Store> results;
      
      if (_selectedBrand == 'all') {
        results = await _apiService.searchAll(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          maxDistance: _searchRadius,
          maxStores: 20,
          forceRefresh: forceRefresh,
        );
      } else if (_selectedBrand == '7-11') {
        results = await _apiService.searchSevenEleven(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          maxDistance: _searchRadius,
          maxStores: 20,
          forceRefresh: forceRefresh,
        );
      } else {
        results = await _apiService.searchFamilyMart(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          maxDistance: _searchRadius,
          maxStores: 20,
          forceRefresh: forceRefresh,
        );
      }

      setState(() {
        _stores = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜尋失敗: $e')),
        );
      }
    }
  }

  String _formatTimeDiff(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    final minutes = diff.inMinutes;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')} ($minutes分鐘前)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('便利商店即期品搜尋'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FavoritesScreen()),
              );
            },
            tooltip: '關注商品',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _searchStores(forceRefresh: true),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('設定'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Consumer<ThemeProvider>(
                        builder: (context, themeProvider, child) {
                          // 判斷當前是否為深色模式（包含系統預設或手動設定）
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          
                          return SwitchListTile(
                            title: const Text('深色模式'),
                            value: isDark,
                            onChanged: (value) {
                              themeProvider.toggleTheme(value);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('關閉'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜尋設定區域
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                // 品牌選擇
                Row(
                  children: [
                    const Text('品牌: '),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('全部'),
                      selected: _selectedBrand == 'all',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedBrand = 'all');
                          _searchStores();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('7-11'),
                      selected: _selectedBrand == '7-11',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedBrand = '7-11');
                          _searchStores();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('全家'),
                      selected: _selectedBrand == '全家',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedBrand = '全家');
                          _searchStores();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 距離滑桿
                Row(
                  children: [
                    const Text('範圍: '),
                    Expanded(
                      child: Slider(
                        value: _searchRadius,
                        min: 300,
                        max: 3000,
                        divisions: 27,
                        label: '${_searchRadius.round()} 公尺',
                        onChanged: (value) {
                          setState(() => _searchRadius = value);
                        },
                        onChangeEnd: (value) {
                          _searchStores();
                        },
                      ),
                    ),
                    Text('${_searchRadius.round()}m'),
                  ],
                ),
                // 資料時間顯示
                if (_stores.isNotEmpty && _stores.first.fetchTime != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '資料時間: ${_formatTimeDiff(_stores.first.fetchTime)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // 結果列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _stores.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _currentPosition == null
                                  ? '無法取得位置資訊'
                                  : '附近沒有找到即期品',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            if (_currentPosition == null) ...[
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadCurrentLocation,
                                child: const Text('重新取得位置'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _stores.length,
                        itemBuilder: (context, index) {
                          return StoreCard(store: _stores[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
