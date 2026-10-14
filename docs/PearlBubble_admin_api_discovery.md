# 深海龍珠：後台／GM API 探索結果

日期：2026-10-14

## 已找到的後台入口

`StarMJ371_unpacked_RemoveCheck_Cli_v2.exe` 內含三個相同用途、不同環境的管理 API：

- `https://admin-dev.towergame.com/common/receive/Member/GetOrSetMemberData.aspx`
- `https://admin-twtest.towergame.com/common/receive/Member/GetOrSetMemberData.aspx`
- `https://admin.gametower.com.tw/common/receive/Member/GetOrSetMemberData.aspx`

正式站字串位於 PE 檔案偏移 `0x1072E40`，映射 VA `0x1474440`。

三個端點在未帶內部授權的唯讀 GET 測試中均回傳 JSON：

```json
{"RETURN_CODE":-1,"RETURN_MESSAGE":"權限不足 (...)"}
```

這證明它們是實際存在且具有存取控制的後台 API，不是無效字串。

## 後台登入

`https://admin.gametower.com.tw/` 會重新導向 `/common/Admin`，再轉至 Microsoft Entra ID 登入；回呼位置為管理站內的 `entralogin.aspx`。因此正式後台需要組織帳號／SSO 權限，並非沿用一般遊戲帳號。

開發與測試管理站的根路徑也指向 `/common/Admin`，但目前該頁回傳站內 404。

## 與深海龍珠設獎的關係

目前找到的 `GetOrSetMemberData.aspx` 名稱與回覆只能證明「會員資料管理 API」存在，尚不能證明它具有深海龍珠的指定獎項功能。

在目前客戶端與 Lua 中仍未找到以下任一項：

- PearlBubble／DinoBall 專用管理頁 URL；
- 指定 Small／Middle／Big 的 HTTP API 方法；
- 後台 API 的合法參數與授權權杖；
- Opcode 51 伺服器端 accepted-code 清單。

所以目前狀態為：

- 後台入口：`FOUND`
- 後台存取控制：`CONFIRMED`
- 深海龍珠正式設獎 API：`NOT_FOUND`
- 小／中／大獎正式強制與餘額同步：`NOT_PROVEN`

## 當前環境證據

本機 `env_override_log.txt` 顯示 `SYSTEM_ENVIRONMENT=2`、`CONFIG_DOMAIN=External`，設定來源為正式 CDN。2026-10-14 下載的當前 `Config_New.json` 只列 `External` 與 `AppleTest`，未列 GM、admin、cheat 或 backoffice 設定鍵。

當前設定快照：`outputs/Config_New.current.json`

SHA-256：`EF4AACC4BF35652B4BB41978D980FCD06B71C5E816B4A01A3505BA6AEB72A099`

