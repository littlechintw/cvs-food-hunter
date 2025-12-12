# CVS Food Hunter (便利商店即期品搜尋)

整合 7-11 (i珍食) 和全家 (友善食光) 的即期品搜尋工具，幫你省錢又減少食物浪費！

本專案包含兩個部分：
1. **Flutter 行動 App**：隨身攜帶，即時定位搜尋。
2. **Python 腳本**：適合自動化抓取或資料分析。

---

## � Flutter 行動 App

位於 `flutter/cvs_food_hunter_app` 目錄下。

### 功能特色

- **雙平台支援**：同時搜尋 7-11 和全家。
- **即時定位**：利用手機 GPS 自動搜尋附近門市。
- **關注商品**：
  - 點擊星星收藏特定商品。
  - 關注商品在列表中會以**金色**高亮顯示。
  - 若店家有您關注的商品，店家卡片會顯示**金色邊框**與標示，讓您一眼鎖定目標。
- **貼心功能**：
  - **深色模式**：保護眼睛，支援系統自動切換或手動設定。
  - **地圖導航**：一鍵開啟 Google Maps 導航。
  - **電話撥打**：直接撥打門市電話確認庫存。
  - **智慧快取**：減少重複 API 請求，節省流量與電量。

### 安裝與執行

請確保已安裝 [Flutter SDK](https://flutter.dev/docs/get-started/install)。

1. **進入專案目錄**
   ```bash
   cd flutter/cvs_food_hunter_app
   ```

2. **安裝依賴**
   ```bash
   flutter pub get
   ```

3. **執行 App**
   ```bash
   flutter run
   ```

---

## 🐍 Python 腳本工具

位於專案根目錄，適合在電腦上快速查詢或整合至其他自動化流程。

### 功能

- 讀取 `config.json` 設定檔進行搜尋。
- 輸出 JSON 與 TXT 格式報告。

### 使用方式

1. **安裝依賴**
   ```bash
   pip install requests
   ```

2. **修改設定 (`config.json`)**
   設定您的經緯度與搜尋範圍。

3. **執行**
   ```bash
   python3 main.py
   ```

---

## 📂 專案結構

```
cvs-food-hunter/
├── flutter/                 # Flutter App 專案
│   └── cvs_food_hunter_app/
├── config.json              # Python 腳本設定檔
├── main.py                  # Python 主程式
├── seven_eleven.py          # 7-11 API 邏輯
├── family_mart.py           # 全家 API 邏輯
├── expired_food_results.json # Python 輸出結果
└── README.md                # 本說明文件
```

## 🤝 貢獻

歡迎提交 Issue 或 Pull Request！

## 參考資料

- [Friendly-Cat](https://github.com/a3510377/Friendly-Cat) - 感謝提供 API 參考

## ⚠️ 免責聲明

本專案僅供技術研究與個人輔助使用，並非 7-Eleven 或全家便利商店官方應用程式。

1. **資料準確性**：所有即期品庫存資訊皆來自超商公開 API，資料可能存在延遲或誤差（例如：系統更新時間差、商品被拿走但尚未結帳）。**實際庫存請務必以門市現場狀況為準**。
2. **非官方軟體**：本專案與統一超商（7-Eleven）或全家便利商店（FamilyMart）無任何官方合作關係。
3. **使用風險**：開發者不對因使用本軟體而產生的任何直接或間接損失負責（例如：特地前往卻已售完）。
4. **合理使用**：請理性使用本工具，勿對 API 進行惡意攻擊、高頻率請求或用於商業營利行為。
