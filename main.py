"""
便利商店即期品搜尋主程式
整合 7-11 和全家的即期品資訊
"""
import json
import os
from datetime import datetime
from typing import List, Dict, Any

from seven_eleven import search_seven_eleven
from family_mart import search_family_mart


def load_config(config_path: str = "config.json") -> Dict[str, Any]:
    """載入設定檔"""
    with open(config_path, "r", encoding="utf-8") as f:
        return json.load(f)


def search_all_stores(config: Dict[str, Any]) -> Dict[str, Any]:
    """
    搜尋所有便利商店的即期品
    
    Args:
        config: 設定檔內容
        
    Returns:
        搜尋結果
    """
    latitude = config["location"]["latitude"]
    longitude = config["location"]["longitude"]
    max_distance = config["search"]["max_distance_meters"]
    max_stores = config["search"]["max_stores"]
    
    results = {
        "query_time": datetime.now().isoformat(),
        "location": config["location"],
        "search_settings": config["search"],
        "seven_eleven": [],
        "family_mart": [],
        "all_stores": []
    }
    
    # 搜尋 7-11
    if config["seven_eleven"]["enabled"]:
        print("\n🔍 搜尋 7-11 即期品 (i珍食)...")
        try:
            seven_eleven_results = search_seven_eleven(
                latitude=latitude,
                longitude=longitude,
                max_distance=max_distance,
                max_stores=max_stores,
                mid_v=config["seven_eleven"]["mid_v"]
            )
            results["seven_eleven"] = seven_eleven_results
            results["all_stores"].extend(seven_eleven_results)
            print(f"   ✅ 找到 {len(seven_eleven_results)} 間 7-11 有即期品")
        except Exception as e:
            print(f"   ❌ 7-11 搜尋失敗: {e}")
    
    # 搜尋全家
    if config["family_mart"]["enabled"]:
        print("\n🔍 搜尋全家即期品 (友善食光)...")
        try:
            family_mart_results = search_family_mart(
                latitude=latitude,
                longitude=longitude,
                max_distance=max_distance,
                max_stores=max_stores,
                project_code=config["family_mart"]["project_code"]
            )
            results["family_mart"] = family_mart_results
            results["all_stores"].extend(family_mart_results)
            print(f"   ✅ 找到 {len(family_mart_results)} 間全家有即期品")
        except Exception as e:
            print(f"   ❌ 全家搜尋失敗: {e}")
    
    # 依距離排序所有門市
    results["all_stores"].sort(key=lambda x: x.get("distance", float('inf')))
    
    return results


def print_results(results: Dict[str, Any]):
    """印出搜尋結果"""
    print("\n" + "=" * 80)
    print("📍 即期品搜尋結果")
    print("=" * 80)
    
    location = results["location"]
    print(f"\n位置: {location.get('description', '')} ({location['latitude']}, {location['longitude']})")
    print(f"搜尋範圍: {results['search_settings']['max_distance_meters']} 公尺內")
    print(f"查詢時間: {results['query_time']}")
    
    all_stores = results["all_stores"]
    
    if not all_stores:
        print("\n😢 附近沒有找到即期品")
        return
    
    print(f"\n🏪 共找到 {len(all_stores)} 間店有即期品:\n")
    
    for i, store in enumerate(all_stores, 1):
        brand = store.get("brand", "")
        name = store.get("store_name", "")
        distance = store.get("distance", 0)
        total_qty = store.get("total_qty", 0)
        address = store.get("address", "")
        
        print(f"{i}. 【{brand}】{name}")
        print(f"   距離: {distance:.0f} 公尺 | 即期品: {total_qty} 項")
        if address:
            print(f"   地址: {address}")
        
        # 顯示商品分類
        categories = store.get("categories", [])
        if categories:
            cat_str = ", ".join([f"{c['name']}({c['qty']})" for c in categories])
            print(f"   分類: {cat_str}")
        
        # 顯示商品列表（最多5項）
        items = store.get("items", [])
        if items:
            print("   商品:")
            for item in items[:5]:
                print(f"     - {item['name']}: {item['qty']} 個")
            if len(items) > 5:
                print(f"     ... 還有 {len(items) - 5} 項商品")
        
        print()


def save_results(results: Dict[str, Any], config: Dict[str, Any]):
    """儲存搜尋結果"""
    output_config = config.get("output", {})
    
    # 儲存 JSON
    if output_config.get("save_json", True):
        json_file = output_config.get("json_file", "expired_food_results.json")
        with open(json_file, "w", encoding="utf-8") as f:
            json.dump(results, f, ensure_ascii=False, indent=2)
        print(f"📁 JSON 結果已儲存到: {json_file}")
    
    # 儲存文字報告
    if output_config.get("save_txt", True):
        txt_file = output_config.get("txt_file", "expired_food_report.txt")
        with open(txt_file, "w", encoding="utf-8") as f:
            f.write("=" * 80 + "\n")
            f.write("便利商店即期品搜尋報告\n")
            f.write("=" * 80 + "\n\n")
            
            location = results["location"]
            f.write(f"位置: {location.get('description', '')} ({location['latitude']}, {location['longitude']})\n")
            f.write(f"搜尋範圍: {results['search_settings']['max_distance_meters']} 公尺內\n")
            f.write(f"查詢時間: {results['query_time']}\n\n")
            
            f.write("-" * 80 + "\n")
            
            for i, store in enumerate(results["all_stores"], 1):
                brand = store.get("brand", "")
                name = store.get("store_name", "")
                distance = store.get("distance", 0)
                total_qty = store.get("total_qty", 0)
                address = store.get("address", "")
                
                f.write(f"\n{i}. 【{brand}】{name}\n")
                f.write(f"   距離: {distance:.0f} 公尺 | 即期品: {total_qty} 項\n")
                if address:
                    f.write(f"   地址: {address}\n")
                
                items = store.get("items", [])
                if items:
                    f.write("   商品:\n")
                    for item in items:
                        f.write(f"     - {item['name']}: {item['qty']} 個\n")
                
                f.write("\n")
        
        print(f"📄 文字報告已儲存到: {txt_file}")


def main():
    """主程式"""
    print("=" * 80)
    print("🛒 便利商店即期品搜尋系統")
    print("   支援: 7-11 (i珍食) + 全家 (友善食光)")
    print("=" * 80)
    
    # 載入設定
    config_path = os.path.join(os.path.dirname(__file__), "config.json")
    config = load_config(config_path)
    
    # 搜尋
    results = search_all_stores(config)
    
    # 顯示結果
    print_results(results)
    
    # 儲存結果
    save_results(results, config)
    
    print("\n✅ 搜尋完成！")


if __name__ == "__main__":
    main()
