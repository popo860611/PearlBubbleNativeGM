# PearlBubble Native GM

深海龍珠客戶端研究與 Native 控制面板（v2.1）。此儲存庫預設為私人使用。

## 已實作

- 以遊戲既有 `onPartyTrigger` 流程建立普通龍珠。
- 本機建立彩虹珠演出。
- 維持空獎／小獎／中獎／大獎的客戶端落洞路徑。
- 顯示伺服器正式獎值、客戶端演出路徑與平台餘額。
- 記錄逐球生命週期、伺服器結果與餘額事件。
- 手動送出 `U2G_CHEAT_CODE_REQ` 測試碼。

## 證據界線

- 路徑選擇只控制客戶端演出，**不等於伺服器正式設獎**。
- 普通龍珠使用較接近自然流程的遊戲事件，但仍需伺服器接受與結算。
- 正式小／中／大獎、客戶端路徑及回首頁餘額三者一致，目前仍為 `NOT_PROVEN`。
- 請以 `server_outcome`、`reward_credit` 與回首頁後餘額判定正式結果。

## BAT 自動安裝（建議）

1. 關閉所有 `StarMJ371` 與 `PearlBubbleNativeGM` 程序。
2. 雙擊 `INSTALL.bat`。
3. 遊戲位於 `D:\明星\StarAIO` 時直接按 Enter；否則輸入另一台電腦的完整遊戲路徑。
4. 安裝完成後啟動遊戲並進入「深海龍珠」。
5. 雙擊 `START_GM.bat`，按 `Insert` 顯示或隱藏面板。

其他 BAT：

- `CHECK_STATUS.bat`：驗證三個安裝檔的 SHA-256。
- `RESTORE.bat`：還原安裝前的遊戲檔案。

## PowerShell 安裝

目標電腦必須使用相同版本的 StarMJ 遊戲檔案。

1. 下載或複製整個儲存庫。
2. 關閉所有 `StarMJ371` 與 `PearlBubbleNativeGM` 程序。
3. 在 PowerShell 執行：

```powershell
powershell -ExecutionPolicy Bypass -File .\installer\install.ps1 -GameRoot 'D:\明星\StarAIO'
```

4. 啟動遊戲並進入「深海龍珠」。
5. 執行：

```powershell
& 'D:\明星\StarAIO\PearlBubbleNativeGM.exe' --root 'D:\明星\StarAIO'
```

按 `Insert` 顯示或隱藏面板。

## 驗證安裝

```powershell
powershell -ExecutionPolicy Bypass -File .\installer\status.ps1 -GameRoot 'D:\明星\StarAIO'
```

## 還原

先關閉遊戲與控制面板，再執行：

```powershell
powershell -ExecutionPolicy Bypass -File .\installer\restore.ps1 -GameRoot 'D:\明星\StarAIO'
```

安裝器會在遊戲目錄的 `tmpNew\PearlBubbleNativeGM_backup_portable` 保存原始檔及 SHA-256 manifest。

## 原始碼與建置

- `src/Program.cs`：Win32/WPF Native 控制面板。
- `src/NativeGMBridge.lua`：遊戲 Lua bridge。
- `src/PearlBubbleNativeGM.csproj`：.NET 8 專案。
- `src/build.ps1`：產生 Windows x86 self-contained 單檔 EXE。

```powershell
powershell -ExecutionPolicy Bypass -File .\src\build.ps1
```

## 相容版本雜湊

| 檔案 | SHA-256 |
|---|---|
| 原始 `main.lua` | `00FFAD7C10C87CEB95DA3B6B7D364F841A7D9B42E2F08DE935CC62C64E9BABCC` |
| 安裝後 `main.lua` | `B76670884FBEE02F79EE0F9962F524FA35AEF019419186F0597724EC60A40510` |
| 安裝後 `NativeGMBridge.lua` | `63043B62EC78937BB018EBB8171CE38CE209BCB8F3EE3252BA2EE17888B45824` |
| `PearlBubbleNativeGM.exe` | `774F515D85E4A9CA30817C3D68A31062C06557A11EC043FF3C26D1CA2C13E422` |

