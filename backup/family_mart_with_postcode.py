"""
全家便利商店即期品 (友善食光) API 模組
"""
import requests
import math
from typing import Optional, List, Dict, Any


class FamilyMartAPI:
    """全家便利商店即期品 API"""
    
    BASE_URL = "https://stamp.family.com.tw/api/maps"
    
    HEADERS = {
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }
    
    def __init__(self, project_code: str = "202106302"):
        """
        初始化全家 API
        
        Args:
            project_code: 專案代碼
        """
        self.project_code = project_code
    
    @staticmethod
    def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        使用 Haversine 公式計算兩點間的距離（公尺）
        
        Args:
            lat1, lon1: 第一點的緯度和經度
            lat2, lon2: 第二點的緯度和經度
            
        Returns:
            距離（公尺）
        """
        R = 6371000  # 地球半徑（公尺）
        
        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        delta_phi = math.radians(lat2 - lat1)
        delta_lambda = math.radians(lon2 - lon1)
        
        a = math.sin(delta_phi / 2) ** 2 + \
            math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        
        return R * c
    
    @staticmethod
    def get_post_code_from_coords(latitude: float, longitude: float) -> Optional[str]:
        """
        根據經緯度取得郵遞區號（使用 Reverse Geocoding）
        
        Args:
            latitude: 緯度
            longitude: 經度
            
        Returns:
            郵遞區號，若無法取得則回傳 None
        """
        # 使用 Nominatim (OpenStreetMap) 的 Reverse Geocoding API
        url = "https://nominatim.openstreetmap.org/reverse"
        params = {
            "lat": latitude,
            "lon": longitude,
            "format": "json",
            "addressdetails": 1
        }
        headers = {
            "User-Agent": "CVS-Food-Hunter/1.0"
        }
        
        try:
            response = requests.get(url, params=params, headers=headers, timeout=10)
            response.raise_for_status()
            data = response.json()
            
            address = data.get("address", {})
            postcode = address.get("postcode")
            
            if postcode:
                # 台灣郵遞區號是 3 碼，取前 3 碼
                return postcode[:3]
            
            return None
        except Exception as e:
            print(f"   ⚠️ 無法取得郵遞區號: {e}")
            return None
    
    def get_stores_by_post_code(self, post_code: str) -> List[Dict[str, Any]]:
        """
        根據郵遞區號取得門市即期品資訊
        
        Args:
            post_code: 郵遞區號
            
        Returns:
            門市清單
        """
        url = f"{self.BASE_URL}/MapProductInfo"
        payload = {
            "OldPKeys": [],
            "PostInfo": post_code,
            "Latitude": 0,
            "Longitude": 0,
            "ProjectCode": self.project_code
        }
        
        response = requests.post(url, json=payload, headers=self.HEADERS)
        response.raise_for_status()
        
        data = response.json()
        return data.get("data", [])
    
    def get_nearby_stores(
        self,
        latitude: float,
        longitude: float,
        max_distance: float = 1000,
        post_code: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        取得附近有即期品的門市
        
        Args:
            latitude: 緯度
            longitude: 經度
            max_distance: 最大距離（公尺）
            post_code: 郵遞區號（可選，不指定會自動判斷）
            
        Returns:
            門市清單（已依距離排序）
        """
        if not post_code:
            post_code = self.get_post_code_from_coords(latitude, longitude)
        
        if not post_code:
            print("   ⚠️ 無法判斷郵遞區號，請手動指定 post_code 參數")
            return []
        
        stores = self.get_stores_by_post_code(post_code)
        
        # 計算距離並過濾
        nearby_stores = []
        for store in stores:
            store_lat = store.get("latitude", 0)
            store_lon = store.get("longitude", 0)
            
            if store_lat and store_lon:
                distance = self.calculate_distance(
                    latitude, longitude, store_lat, store_lon
                )
                
                if distance <= max_distance:
                    store["calculated_distance"] = distance
                    nearby_stores.append(store)
        
        # 依距離排序
        nearby_stores.sort(key=lambda x: x.get("calculated_distance", float('inf')))
        
        return nearby_stores
    
    def search_expired_food(
        self,
        latitude: float,
        longitude: float,
        max_distance: float = 1000,
        max_stores: int = 10,
        post_code: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        搜尋附近的即期品（主要入口函數）
        
        Args:
            latitude: 緯度
            longitude: 經度
            max_distance: 最大距離（公尺）
            max_stores: 最多回傳幾間店
            post_code: 郵遞區號（可選）
            
        Returns:
            包含門市和商品資訊的清單
        """
        stores = self.get_nearby_stores(latitude, longitude, max_distance, post_code)
        
        results = []
        for store in stores[:max_stores]:
            store_name = store.get("name", "")
            address = store.get("address", "")
            tel = store.get("tel", "")
            distance = store.get("calculated_distance", 0)
            info = store.get("info", [])
            
            store_info = {
                "brand": "全家",
                "store_no": store.get("oldPKey", ""),
                "store_name": store_name,
                "address": address,
                "tel": tel,
                "distance": round(distance, 2),
                "total_qty": sum(cat.get("qty", 0) for cat in info),
                "categories": [],
                "items": []
            }
            
            # 解析商品資訊
            for category in info:
                cat_name = category.get("name", "")
                cat_qty = category.get("qty", 0)
                
                store_info["categories"].append({
                    "name": cat_name,
                    "qty": cat_qty
                })
                
                # 取得商品詳情
                for sub_cat in category.get("categories", []):
                    for product in sub_cat.get("products", []):
                        store_info["items"].append({
                            "name": product.get("name", ""),
                            "qty": product.get("qty", 0),
                            "category": cat_name,
                            "sub_category": sub_cat.get("name", "")
                        })
            
            results.append(store_info)
        
        return results


def search_family_mart(
    latitude: float,
    longitude: float,
    max_distance: float = 1000,
    max_stores: int = 10,
    project_code: str = "202106302",
    post_code: Optional[str] = None
) -> List[Dict[str, Any]]:
    """
    搜尋全家即期品的便利函數
    
    Args:
        latitude: 緯度
        longitude: 經度
        max_distance: 最大距離（公尺）
        max_stores: 最多回傳幾間店
        project_code: 專案代碼
        post_code: 郵遞區號（可選）
        
    Returns:
        包含門市和商品資訊的清單
    """
    api = FamilyMartAPI(project_code)
    return api.search_expired_food(
        latitude, longitude, max_distance, max_stores, post_code
    )
