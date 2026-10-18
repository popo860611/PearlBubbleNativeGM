# 深海龍珠 Native GM v2.2

## 功能

- 自然流程普通龍珠（透過遊戲內建龍珠洞事件建立，仍需伺服器驗證）
- 本機增加彩虹珠（Rainball 101；僅實體演出）
- 指定下一顆龍珠採用空獎路徑
- 將小獎、中獎或大獎路徑持續套用到每一顆後續龍珠，直到按下取消或改選另一條路徑
- 取消路徑指定並恢復正常
- 手動輸入 1～8 位數字，經正式 `U2G_CHEAT_CODE_REQ` 送至私服測試
- 記錄送碼前帳戶餘額、送碼後餘額差及收到的龍珠結果事件數
- `Insert` 顯示或隱藏 Win32 選單

## v2.2 純被動協定時間線

- 在真正的 `PearlBubbleModel:SendLuaCommand(cmd, content)` 邊界記錄 `SEND`。
- 在真正的 `PearlBubbleModel:OnCommand(luaCommand)` 邊界、原處理器執行前記錄 `RECV`。
- 每筆包含工作階段序號、Unix 秒、相對毫秒、方向、Opcode、協定名稱及已解碼欄位。
- 針對 `15` 記錄 `verifyOk/index/bgDataList`，針對 `31` 記錄 `changeAmount/currentMoney`，針對 `51` 記錄 `code`，針對 `52` 記錄 `buffer/soulBuffer`。
- Hook 只讀取已由遊戲解析完成的資料，並原封不動呼叫原函式及回傳原結果；不改寫封包、獎值或狀態。
- 時間線位於 `D:\明星\StarAIO\tmpNew\PearlBubbleNativeGM.timeline.log`，每次進入深海龍珠會建立一份乾淨的新工作階段。

靜態確認：`Opcode 52` 的 `buffer` 與 `soulBuffer` 在此版本資料結構中均為 `double`，不是可做 HexDump 的原始 byte buffer。`Opcode 51` 的單一參數是 `PearlBubbleCheatCodeReq.code`（`int`），不是 SessionID、子彈 SequenceID 或 StageID。

## v2.1 普通龍珠自然觸發流程

- 「自然流程普通龍珠」不再直接呼叫 `addBonusDraBall/createBonusDraBall`。
- 改用遊戲原始 TestUI 相同的 `GameCtrl:onPartyTrigger` 龍珠洞流程。
- 使用 `PartyTriggerDefine` 中的 DraBall 洞及 `BlockGroup.EnterDraBall`，讓遊戲建立 `SGSCSE_EnterMid` 同步步驟，再交由正常發射器延遲建立龍珠。
- 這會比純本機物理球多出正式遊戲狀態事件，但是否被伺服器接受仍須以 `server_outcome`、獎值及回首頁保存結果驗證。

## v2.0 延遲入帳與正式金流追蹤

- `property_change`：記錄每次客戶端 `GameCtrl:addProperty` 的來源、金額及前後餘額。
- `reward_credit`：獎圈演出結束後，精確記錄 `endCB` 實際加入的獎值。
- `balance_probe`：獎值加入後 0.5、2、5、10 秒再次讀取本機與平台帳戶餘額。
- `money_notify`／`event_money_notify`：記錄伺服器外來金流通知。
- `server_sync`：把伺服器 `finalNum/addNum/subNum` 寫入事件檔，而非只顯示於狀態列。

此版本可在沒有額外射擊的情況下，用已在場上的球或本機增加球觀察「演出獎值」是否後續成為平台正式餘額；本機增加球仍不等於伺服器承認。

## v1.9 自動逐球生命週期紀錄

不再依賴人工盯畫面判斷同一顆球，事件檔自動記錄：

- `ball_created`：客戶端建立普通龍珠／彩虹珠。
- `platform_drop`：大球從上層推盤掉到下方區域並準備同步。
- `server_outcome`：伺服器回傳球種、預定獎項及 `broadcastIndex`。
- `wheel_landed`：大球實際進入最終轉盤獎洞，並記錄前後客戶端值與平台帳戶餘額。

這些紀錄只觀察原始流程，不更改伺服器結果。

空獎路徑指定是一次性的；小獎、中獎及大獎路徑會持續維持，直到按下「取消指定／恢復正常」或改選另一條路徑。所有路徑功能只改客戶端落球演出，不宣稱會改正式帳戶入帳。

## v1.8 正式獎值顯示與逐球紀錄

- 選單以中文分開顯示「伺服器正式獎值」與「客戶端演出路徑」，不再只顯示容易混淆的數字代碼。
- 每次套用路徑都記錄球種、伺服器獎值及演出路徑至事件紀錄。
- 帳戶餘額仍只採用平台 `Gt2UserApp:GetMoney`；不將客戶端演出路徑當成正式入帳。

## v1.7 三種得獎路徑維持

- 「小獎路徑（維持）」、「中獎路徑（維持）」與「大獎路徑（維持）」都會持續生效。
- 三者互斥；按另一個路徑按鈕會立即取代先前維持的路徑。
- 按「取消指定／恢復正常」會解除維持。

## v1.6 中獎路徑維持

- 「中獎路徑（維持）」會讓每顆後續正常收到伺服器結果的龍珠都走中獎演出。
- 選單狀態會顯示「維持路徑：中獎」。
- 按「取消指定／恢復正常」後，下一顆起恢復採用伺服器原始路徑。

## v1.5 路徑與獎勵值分離修正

- 舊版直接覆寫伺服器回傳的 `rewardType`，會讓客戶端顯示／待結算金額誤用指定路徑的獎值。
- v1.5 保留伺服器 `rewardType` 給遊戲結算，只在 `Machine:shootDraBallByRes` 選擇落洞動畫時代入指定路徑。
- 選單新增「路徑結果」，分開顯示伺服器獎勵類型與客戶端演出路徑。
- 例如指定中獎路徑但伺服器回傳小獎時：畫面走中獎路徑，帳戶與結算仍採小獎值。路徑按鈕不會要求私服改發中獎。

## v1.4 伺服器代碼測試與結算診斷

- 直接讀取 `Gt2UserApp:GetMoney(currencyType)` 顯示平台帳戶餘額
- 將 `PropertyMgr` 的合計值明確標示為「客戶端待結算」，避免誤認為正式餘額
- 監測 `OnUserConeyChanged` 的平台帳戶變更通知
- 顯示伺服器最後確認的 `finalNum`、`addNum` 與 `subNum`
- 顯示遊戲狀態同步序號
- 顯示最近一次伺服器龍珠結果的數量與獎勵類型
- 每秒刷新一次唯讀狀態，即使沒有操作選單也會更新餘額

只有使用者按下「送出至伺服器」時才會發送輸入的代碼；程式不會自動掃描或暴力測試。私服是否接受、是否要求 GM 權限，以及代碼的作用，都必須以伺服器回覆和回首頁後的帳戶餘額判定。

事件紀錄位於 `D:\明星\StarAIO\tmpNew\PearlBubbleNativeGM.events.log`。

v1.4.1 會在每次進入遊戲時丟棄前一個工作階段殘留的命令檔，避免重新執行上次的按鈕操作。

## 建置

```powershell
powershell -ExecutionPolicy Bypass -File .\work\pearlbubble_native_menu\build.ps1
```

## 安裝

必須先關閉所有 StarMJ 程序：

```powershell
python .\work\pearlbubble_native_menu\deploy.py install --root 'D:\明星\StarAIO'
python .\work\pearlbubble_native_menu\deploy.py status --root 'D:\明星\StarAIO'
```

安裝後啟動遊戲並進入深海龍珠，再執行：

```powershell
& 'D:\明星\StarAIO\PearlBubbleNativeGM.exe' --root 'D:\明星\StarAIO'
```

## 還原

先關閉遊戲及 Native GM：

```powershell
python .\work\pearlbubble_native_menu\deploy.py restore --root 'D:\明星\StarAIO'
```

備份與 SHA-256 manifest 位於 `D:\明星\StarAIO\tmpNew\PearlBubbleNativeGM_backup`。
