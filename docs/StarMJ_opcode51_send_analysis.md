# StarMJ PID 23004：Client 67 / Opcode 51 / Code 31 封裝與送出分析

分析標的：`D:\明星\StarAIO\StarMJ371_unpacked_RemoveCheck_Cli_v2.exe`

## 1. `send` 的靜態位置

執行期模組基址為 `0x00F90000`，PE 偏好 ImageBase 為 `0x00400000`。

Frida 在 PID 23004 的 `ws2_32!send` 入口取得的第一層遊戲回傳位置為：

- runtime：`0x01C66317`
- module RVA：`0x00CD6317`
- static VA：`0x010D6317`

`0x010D6317` 是 `send` 返回後的第一條指令；真正的 call site 是 `0x010D6311`：

```asm
010D630B  push edx              ; flags = 0
010D630C  push eax              ; len
010D630D  push ecx              ; buf
010D630E  push dword ptr [esi+10h] ; socket
010D6311  call dword ptr [0141F8E4h] ; ws2_32!send
010D6317  mov  edi,eax
010D6319  cmp  edi,-1
```

包含這段的傳送函式入口為 `0x010D62A0`。實測所列四個 API 中，目標 TCP 連線實際命中的是 `send`，未命中 `WSASend`。

## 2. Lua command 的靜態封裝鏈

Lua 端的物件為：

```lua
LuaRefCommand:Create(67, 51, request)
request.code = 31
```

`PearlBubbleCheatCodeReq:AppendMemberList()` 把 `code` 宣告成一個 `LUA_STRUCT_TYPE_INT`。

native binding `0x009471E0` 依序讀取 Lua command 的：

- `type`（字串位址 `0x0144DDD8`）
- `commandType`（字串位址 `0x0144AEB4`）
- `content`（字串位址 `0x01460090`）

然後在 `0x009475F5` 呼叫 `0x00947CE0`。後續呼叫鏈為：

```text
0x009471E0  Lua command binding / 欄位擷取
  -> 0x00947CE0  command builder wrapper
  -> 0x009497E0
  -> 0x00949750  複製 content 物件並讀取 command type byte
  -> 0x00956770  轉交 LuaCommandModel 的虛擬 send handler
  -> virtual thunk 0x00BE85C0
  -> queue / transport
  -> 0x010D62A0
  -> ws2_32!send at 0x010D6311
```

## 3. 執行期確認欄位

在 `0x00947CE0` 的執行期入口攔截到：

```text
arg1_hex = 43 33 AA 00 ...
           ^^ ^^
           67 51
```

也就是 native builder 收到：

- Client/type：`0x43` = 67
- commandType/opcode：`0x33` = 51

同一次受控測試中，native 物件記憶體 `+0x2C` 可見：

```text
1F 00 00 00
```

即 little-endian 整數 `31`。因此可確認 `31` 已經越過 Lua bridge，進入 native command builder；不是只更新 GM 選單畫面。

## 4. TCP record 與 XOR 層

對 `34.81.163.209:2591` 的 `send` 實測封包為：

```text
88 0B 00 87 87 87 87 54 83 87 68 87 87 87
```

本 record 的結構：

```text
[0]      88       record marker
[1..2]   0B 00    encrypted-body length = 11
[3..13]           body
```

marker `0x88` 對應 body XOR key `0x87`。解掉 transport XOR 後：

```text
00 00 00 00 D3 04 00 EF 00 00 00
```

注意：最後四位元組 `EF 00 00 00` **不是** 原始 little-endian `31`。這表示在 transport XOR 之前還有 native command serializer / bit-packing 層；不能把 `1F 00 00 00` 直接塞入 TCP record。

受控對照也確認只有內層最後四位元組隨 `code` 改變：

| 輸入 code | wire packet body（XOR 前） | XOR `0x87` 後的最後 4 bytes |
|---:|---|---|
| 31 | `... 68 87 87 87` | `EF 00 00 00` |
| 11111111 | `... C0 FD DE 87` | `47 7A 59 00` |
| 22222222 | `... F9 72 34 86` | `7E F5 B3 01` |
| 12345678 | `... 39 26 CB 87` | `BE A1 4C 00` |
| 87654321 | `... D6 08 4E 82` | `51 8F C9 05` |

因此已確認兩個不同層次：

1. `67 / 51 / 31` 以原始值進入 native builder。
2. native serializer 將 command 壓成 11-byte inner body，再由 record layer 對 body 做 `0x87` XOR，最後交給 `send`。

## 5. 重複送出的觀察

Code 31 測試中：

- `0x00947CE0` builder 命中兩次；
- `send` 也送出兩個完全相同的 14-byte record。

所以重複封包是在 native builder 之前就已經形成兩次命令，不是 `send` 自己重送。需再檢查 Native GM bridge 是否被兩個 Lua context 載入，或同一 `.cmd` 被兩個輪詢器消費。

## 證據檔

- `D:\tool\codex\2026-10-13\d-staraio-mj-patch-exe-2\outputs\frida_starmj_send.jsonl`
- `D:\tool\codex\2026-10-13\d-staraio-mj-patch-exe-2\outputs\trace_lua_command_builder_31.jsonl`
- `D:\tool\codex\2026-10-13\d-staraio-mj-patch-exe-2\outputs\sendluacommand_disasm.txt`
- `D:\tool\codex\2026-10-13\d-staraio-mj-patch-exe-2\outputs\packet_builder_947ce0_disasm.txt`
- `D:\tool\codex\2026-10-13\d-staraio-mj-patch-exe-2\outputs\packet_builder_9497e0_disasm.txt`
- `D:\tool\codex\2026-10-13\d-staraio-mj-patch-exe-2\outputs\send_dispatch_956770_disasm.txt`
