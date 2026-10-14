# 深海龍珠 GM／正式協定探索狀態

日期：2026-10-14

## 後台／GM API 探索

- 在客戶端 PE 中找到正式、測試、開發三組 `admin` 管理端點，方法為 `GetOrSetMemberData.aspx`。
- 正式管理站會轉至 Microsoft Entra ID SSO；API 未帶內部授權時明確回覆「權限不足」。
- 這證明後台系統存在，但目前只確認會員資料 API，尚未定位 PearlBubble／DinoBall 專用設獎方法。
- 詳細證據：`outputs/PearlBubble_admin_api_discovery.md`。

## 1. 既有伺服器 GM 功能

### 已確認

- 客戶端確實定義 `U2G_CHEAT_CODE_REQ = 51`，結構為 `PearlBubbleCheatCodeReq.code`（INT）。
- `GameMain.lua` 中未被本機分支吃掉的非空數字，會經 `SendLuaCommand` 送入 opcode 51。
- `00031`（普通龍珠）與 `00032`（彩虹珠）是明確的 client-only 分支，只呼叫客戶端
  `addBonusDraBall/createBonusDraBall`，不會送 opcode 51。
- Code 31 的 Native builder 與 Winsock send 先前已捕獲；命令確實離開客戶端。

### 未確認／目前結論

- 客戶端 Lua 沒有列出伺服器接受哪些 GM code，也沒有伺服器權限表。
- Code 31 實測後：帳戶餘額 delta = 0、server reward delta = 0；因此不是已確認可用 GM 功能。
- `11111111`、`22222222`、`12345678`、`87654321` 也只有送出證據，沒有成功回覆證據。
- 在沒有伺服器程式、GM API 或具有權限的帳號證據前，不能把任一 code 標為正式功能。

靜態清冊：

- `outputs/PearlBubble_protocol_catalog.json`
- `outputs/PearlBubble_protocol_catalog.md`

## 2. 正式遊戲協定

### 已完成的被動擷取能力

- Hook：`send`、`recv`、同步 `WSASend`、同步 `WSARecv`。
- 過濾：只保留指定 PID 到 `34.81.163.209:2591`。
- 重組：依 socket＋方向分流，支援 TCP 分段、黏包，保留重複訊息。
- 外層 record：`marker + uint16 little-endian length + body`。
- 外層 body：以 `marker - 1` XOR 還原。
- 全程唯讀，不修改 buffer、不重送封包。

### 實機證據

| 情境 | 時間 | Records | 錯誤 | 收到 opcode 15 | 狀態 |
|---|---:|---:|---:|---:|---|
| baseline | 10 秒 | 8 | 0 | 2 | RAW_CAPTURED / NOT_REVIEWED |
| normal_ball attempt 1 | 120 秒 | 93 | 0 | 19 | NOT_RUN：使用者確認目標球未生成 |
| rainball | 直到使用者回報 | 102 | 0 | 11 | 使用者確認＋伺服器 opcode 15 已解碼 |

`normal_ball` 的伺服器方向看到 19 筆外層解碼後以 `0F 00 00 00` 開頭的訊息，與 Lua 的
`G2U_SYNC_GAME_STATE_ACK_V2 = 15` 一致；其中長度 17、101、103、110、114、116、118、120
等多種回覆都被保留。

使用者確認這 120 秒內沒有自然普通龍珠或彩虹珠生成，因此這份資料只作為「持續射擊／同步但
目標球未生成」的負樣本，不能宣稱自然普通龍珠已被確認。此外，仍需將 opcode 15 內層資料
對照 `verifyOk/bgDataList`。

### 正式結果的判定門檻

必須同時建立以下證據：

1. opcode 15 回覆中 `verifyOk = true`；
2. `bgDataList[].ballType/holeType` 與自然球、落洞種類一致；
3. 若有正式金流，看到 opcode 31 `changeAmount/currentMoney` 或平台帳戶餘額更新；
4. 回首頁後帳戶餘額一致。

在上述條件達成前，一律保持 `NOT_REVIEWED` 或 `NOT_RUN`，不標成 PASS。

## 彩虹珠第一筆正式協定成果

使用者於擷取中回報自然彩色珠出現。相同擷取窗內已解出以下伺服器回覆。注意：這是伺服器
回傳的「預定結果」，不是畫面上已完成進獎洞的證明：

| 時間（UTC） | Opcode | verifyOk | count | broadcastIndex | ballType | holeType | 結果 |
|---|---:|---|---:|---|---:|---:|---|
| 08:10:51.503 | 15 | true | 2 | 179132163333503 | 101 Rainball | 0 | None |
| 08:11:00.082 | 15 | true | 1 | 179132163334751 | 101 Rainball | 1 | Small |

Lua 定義確認 `BallType.Rainball = 101`。普通／彩虹珠的 `holeType = 1` 會映射成
`SuperRewardType.Small`。因此這個擷取窗只確認「伺服器曾回傳一筆彩虹珠的小獎預定結果」。
它不等於彩虹珠已在畫面進入小獎洞，也不等於帳戶已入帳。解析輸出在
`outputs/PearlBubble_rainball_events.json`。

### 時序修正

1. 小珍珠進入派對洞時，客戶端可能建立普通龍珠／彩虹珠。
2. 大球從上層推盤掉到下方區域時，`OnEventBallDropDwon` 才送出 `SGSCSE_DropBall`。
3. 伺服器回 opcode 15，將 `holeType` 結果放入 `superRewardResQueue`。
4. `checkShootDraBall` 之後呼叫 `shootDraBallByRes(ballType, rewardType)`，讓大球演出指定路徑。
5. 大球最後進入轉盤獎洞時，`onDraBallTrigger` 才播放得獎及計算獎值。

所以 `holeType=1` 位於步驟 3，會早於畫面最後落入獎洞。使用者確認當時只有小珍珠落下，
因此尚不能把該回覆一對一歸屬於剛出現、仍在推盤上的那顆彩虹珠；也可能是同類型的既有
等待佇列結果。需要加入 `broadcastIndex` 與 queue 的動態紀錄才能完成一對一關聯。

這一窗沒有發現 opcode 31 金流通知。帳戶餘額同時受到持續射擊扣款影響，所以不能把餘額
變化直接歸因於小獎；正式帳戶入帳仍待獨立捕獲。

### 「建立球」協定的修正結論

靜態 Lua 顯示自然球不是由獨立的伺服器建立球訊息產生：`GameCtrl:onPartyHoleTrigger` 在客戶端
判定派對洞事件後，依派對狀態選擇 `DraBall(100)` 或 `Rainball(101)`，直接呼叫
`machine:addBonusDraBall(...)`。客戶端隨後把球位置／落洞事件送進同步，伺服器用 opcode 15
驗證並回傳 `verifyOk/bgDataList` 正式結果。因此目前真正的權威邊界是「伺服器驗證與結算」，
不是「伺服器主動建立球」。

## v1.9 自然遊玩實機結果

使用者完成一輪正常遊玩；本輪沒有送 GM code，也沒有套用路徑覆寫。新增 391 行事件：

- 自然建立 5 顆普通龍珠（100）與 2 顆彩虹珠（101）。
- 收到 10 筆伺服器結果：6 筆 None、2 筆 Small、2 筆 Middle。
- 10 筆結果全部可依球種佇列配對到最終 `wheel_landed`，伺服器指定獎別與客戶端採用獎別 10/10 一致。
- Big（reward 3）仍未觀察到。
- 本輪沒有 `account_update` 或 `server_sync` 事件；起訖餘額同時包含大量射擊扣款，故不能將某一筆獎勵獨立證明為平台正式入帳。
- `wheel_landed` 的即時 before/after 不變不能解讀成沒有給獎：靜態 Lua 顯示實際 `addProperty(rewardVal)` 位於 WinCircle 的 `endCB`，會在獎圈演出完成後才執行。

完整分析：`outputs/PearlBubble_v1.9_field_run_analysis.md`。

## 下一輪擷取

待取得：自然 Big，以及 `WinCircle endCB -> addProperty -> 平台餘額通知／回首頁餘額`
的同一筆關聯。不能用 Native GM 新增球替代自然球樣本。

## v2.0 回首頁保存確認

使用者已在回首頁後確認本輪餘額確實保存，因此「本輪合計餘額可持久化」升級為
`USER_CONFIRMED`。但該輪同時包含自然事件、本機增加球、7 次 server code 發送及客戶端
路徑覆寫，不能把保存結果歸因到其中任一按鈕。下一步需要乾淨 A/B 測試，每輪只做一項操作。

快照：`outputs/captures/scenarios/v2.0_persisted_run.events.log`，SHA-256
`EC6FB4B63F0E23BA6DE1C0861422153B456298C6E0F96F564FFDC143C7426319`。

