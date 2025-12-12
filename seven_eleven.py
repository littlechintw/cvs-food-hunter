"""
7-11 即期品 (i珍食) API 模組
"""
import requests
from typing import Optional, List, Dict, Any


class SevenElevenAPI:
    """7-11 即期品 API"""
    
    BASE_URL = "https://lovefood.openpoint.com.tw/LoveFood/api/"
    
    HEADERS = {
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Referer": "https://lovefood.openpoint.com.tw/"
    }
    
    def __init__(self, mid_v: str):
        """
        初始化 7-11 API
        
        Args:
            mid_v: API 認證用的 mid_v 參數
        """
        self.mid_v = mid_v
        self.token: Optional[str] = None
    
    def get_access_token(self) -> str:
        """取得 Access Token"""
        url = self.BASE_URL + "Auth/FrontendAuth/AccessToken"
        params = {"mid_v": self.mid_v}
        
        response = requests.post(url, params=params, json={}, headers=self.HEADERS)
        response.raise_for_status()
        
        result = response.json()
        if result.get("isSuccess"):
            self.token = result.get("element")
            return self.token
        else:
            raise Exception(f"取得 Token 失敗: {result}")
    
    def get_nearby_stores(
        self, 
        latitude: float, 
        longitude: float,
        max_distance: Optional[float] = None
    ) -> List[Dict[str, Any]]:
        """
        取得附近有即期品的門市
        
        Args:
            latitude: 緯度
            longitude: 經度
            max_distance: 最大距離（公尺），None 表示不限制
            
        Returns:
            門市清單
        """
        if not self.token:
            self.get_access_token()
        
        url = self.BASE_URL + "Search/FrontendStoreItemStock/GetNearbyStoreList"
        params = {"token": self.token}
        body = {
            "CurrentLocation": {"Latitude": latitude, "Longitude": longitude},
            "SearchLocation": {"Latitude": latitude, "Longitude": longitude}
        }
        
        response = requests.post(url, params=params, json=body, headers=self.HEADERS)
        response.raise_for_status()
        
        result = response.json()
        if result.get("isSuccess"):
            stores = result.get("element", {}).get("StoreStockItemList", [])
            
            # 過濾有即期品的門市
            stores_with_stock = [s for s in stores if s.get("RemainingQty", 0) > 0]
            
            # 過濾距離
            if max_distance:
                stores_with_stock = [
                    s for s in stores_with_stock 
                    if s.get("Distance", float('inf')) <= max_distance
                ]
            
            return stores_with_stock
        else:
            raise Exception(f"查詢失敗: {result}")
    
    def get_store_detail(
        self, 
        store_no: str, 
        latitude: float, 
        longitude: float
    ) -> Dict[str, Any]:
        """
        取得指定門市的即期品詳細資訊
        
        Args:
            store_no: 門市店號
            latitude: 緯度
            longitude: 經度
            
        Returns:
            門市詳細資訊
        """
        if not self.token:
            self.get_access_token()
        
        url = self.BASE_URL + "Search/FrontendStoreItemStock/GetStoreDetail"
        params = {"token": self.token}
        body = {
            "storeNo": store_no,
            "CurrentLocation": {"Latitude": latitude, "Longitude": longitude}
        }
        
        response = requests.post(url, params=params, json=body, headers=self.HEADERS)
        response.raise_for_status()
        
        result = response.json()
        if result.get("isSuccess"):
            return result.get("element", {})
        else:
            raise Exception(f"查詢失敗: {result}")
    
    def get_store_by_name(self, store_name: str) -> Dict[str, Any]:
        """
        用店名查詢門市資訊（包含地址）
        
        Args:
            store_name: 門市名稱
            
        Returns:
            門市資訊
        """
        if not self.token:
            self.get_access_token()
        
        url = self.BASE_URL + "Master/FrontendStore/GetStoreByAddress"
        params = {"token": self.token, "keyword": store_name}
        
        response = requests.post(url, params=params, json={}, headers=self.HEADERS)
        response.raise_for_status()
        
        result = response.json()
        if result.get("isSuccess"):
            stores = result.get("element", [])
            # 找到完全匹配的店名
            for store in stores:
                if store.get("StoreName") == store_name:
                    return store
            # 如果沒有完全匹配，返回第一個
            return stores[0] if stores else {}
        else:
            return {}
    
    def search_expired_food(
        self,
        latitude: float,
        longitude: float,
        max_distance: float = 1000,
        max_stores: int = 10
    ) -> List[Dict[str, Any]]:
        """
        搜尋附近的即期品（主要入口函數）
        
        Args:
            latitude: 緯度
            longitude: 經度
            max_distance: 最大距離（公尺）
            max_stores: 最多回傳幾間店
            
        Returns:
            包含門市和商品資訊的清單
        """
        # 取得 Token
        self.get_access_token()
        
        # 取得附近門市
        stores = self.get_nearby_stores(latitude, longitude, max_distance)
        
        results = []
        for store in stores[:max_stores]:
            store_no = store.get("StoreNo", "")
            store_name = store.get("StoreName", "")
            distance = store.get("Distance", 0)
            remaining_qty = store.get("RemainingQty", 0)
            category_items = store.get("CategoryStockItems", [])
            
            store_info = {
                "brand": "7-11",
                "store_no": store_no,
                "store_name": f"7-11 {store_name}門市",
                "distance": round(distance, 2),
                "total_qty": remaining_qty,
                "categories": [],
                "items": []
            }
            
            # 加入分類資訊
            for cat in category_items:
                store_info["categories"].append({
                    "name": cat.get("Name", ""),
                    "qty": cat.get("RemainingQty", 0)
                })
            
            # 取得詳細商品資訊
            try:
                detail = self.get_store_detail(store_no, latitude, longitude)
                store_stock_item = detail.get("StoreStockItem", {})
                
                # 取得商品詳情
                category_stock_items = store_stock_item.get("CategoryStockItems", [])
                
                for cat in category_stock_items:
                    cat_name = cat.get("Name", "")
                    item_list = cat.get("ItemList", [])
                    
                    for item in item_list:
                        store_info["items"].append({
                            "name": item.get("ItemName", ""),
                            "qty": item.get("RemainingQty", 0),
                            "category": cat_name
                        })
                        
            except Exception as e:
                pass  # 無法取得詳情就跳過
            
            # 用店名查詢地址
            try:
                store_detail = self.get_store_by_name(store_name)
                if store_detail:
                    store_info["address"] = store_detail.get("Address", "")
                    store_info["tel"] = store_detail.get("Telno", "")
            except Exception:
                pass  # 無法取得地址就跳過
            
            results.append(store_info)
        
        return results


def search_seven_eleven(
    latitude: float,
    longitude: float,
    max_distance: float = 1000,
    max_stores: int = 10,
    mid_v: str = ""
) -> List[Dict[str, Any]]:
    """
    搜尋 7-11 即期品的便利函數
    
    Args:
        latitude: 緯度
        longitude: 經度
        max_distance: 最大距離（公尺）
        max_stores: 最多回傳幾間店
        mid_v: API 認證參數
        
    Returns:
        包含門市和商品資訊的清單
    """
    api = SevenElevenAPI(mid_v)
    return api.search_expired_food(latitude, longitude, max_distance, max_stores)
