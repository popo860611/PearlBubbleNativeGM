import hashlib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / "src" / "NativeGMBridge.lua"
PROGRAM = ROOT / "src" / "Program.cs"
DEPLOY = ROOT / "src" / "deploy.py"


class NativeMenuContractTests(unittest.TestCase):
    def test_windows_powershell_installers_keep_bom_and_current_payload_hashes(self):
        package_root = Path(__file__).resolve().parents[1]
        install = package_root / "installer" / "install.ps1"
        status = package_root / "installer" / "status.ps1"
        bridge_payload = package_root / "installer" / "payload" / "NativeGMBridge.lua"
        exe_payload = package_root / "installer" / "payload" / "PearlBubbleNativeGM.exe"
        self.assertTrue(install.read_bytes().startswith(b"\xef\xbb\xbf"))
        self.assertTrue(status.read_bytes().startswith(b"\xef\xbb\xbf"))
        bridge_hash = hashlib.sha256(bridge_payload.read_bytes()).hexdigest().upper()
        exe_hash = hashlib.sha256(exe_payload.read_bytes()).hexdigest().upper()
        self.assertIn(bridge_hash, install.read_text(encoding="utf-8-sig"))
        self.assertIn(exe_hash, install.read_text(encoding="utf-8-sig"))
        self.assertIn(bridge_hash, status.read_text(encoding="utf-8-sig"))
        self.assertIn(exe_hash, status.read_text(encoding="utf-8-sig"))

    def test_bridge_has_exact_supported_commands_and_one_shot_visual_override(self):
        text = BRIDGE.read_text(encoding="utf-8")
        for command in (
            "ADD_RAIN",
            "PATH_0",
            "PATH_1",
            "PATH_2",
            "PATH_3",
            "CANCEL_PATH",
        ):
            self.assertIn(command, text)
        self.assertIn("nextRewardType = nil", text)
        self.assertIn("originalShootDraBallByRes", text)
        self.assertNotIn("self.waitShootDraBallQueue[1].rewardType = selected", text)
        self.assertIn("NativeGMBridge.originalShootDraBallByRes(self, ballType, selected)", text)
        self.assertIn('file:write("server_path_reward="', text)
        self.assertIn('file:write("visual_path_reward="', text)

    def test_bridge_uses_game_thread_scheduler_and_explicit_server_test_command(self):
        text = BRIDGE.read_text(encoding="utf-8")
        self.assertIn("scheduleScriptFunc", text)
        self.assertIn("dinoBall.NativeGMBridge = NativeGMBridge", text)
        self.assertIn("SERVER_CODE:", text)
        self.assertIn("PearlBubbleCheatCodeReq:create()", text)
        self.assertIn("U2G_CHEAT_CODE_REQ", text)
        self.assertIn("SendLuaCommand", text)
        self.assertIn("tonumber(codeText)", text)

    def test_controller_exposes_safe_requested_actions_and_hotkey(self):
        text = PROGRAM.read_text(encoding="utf-8")
        for label in (
            "增加彩虹珠",
            "空獎路徑",
            "小獎路徑",
            "中獎路徑",
            "大獎路徑",
        ):
            self.assertIn(label, text)
        self.assertIn("Keys.Insert", text)
        self.assertIn("TopMost = true", text)
        self.assertNotIn('ActionButton("自然流程普通龍珠", "ADD_DRA"', text)

    def test_bridge_observes_server_settlement_and_correlates_explicit_test_code(self):
        text = BRIDGE.read_text(encoding="utf-8")
        self.assertIn("originalOnSyncConeyAck", text)
        self.assertIn("lastServerFinal", text)
        self.assertIn('file:write("server_final="', text)
        self.assertIn('file:write("local_delta="', text)
        self.assertIn('file:write("sync_index="', text)
        self.assertIn('file:write("server_reward_count="', text)
        self.assertIn("gameMain.OnSyncConeyAck = self.originalOnSyncConeyAck", text)
        self.assertIn("gameCtrl.onGetSuperRewardRes = self.originalOnGetSuperRewardRes", text)
        self.assertIn('file:write("server_code="', text)
        self.assertIn('file:write("server_code_account_before="', text)
        self.assertIn('file:write("server_code_account_delta="', text)
        self.assertIn('file:write("server_code_reward_delta="', text)

    def test_controller_labels_diagnostic_values_as_local_or_server_confirmed(self):
        text = PROGRAM.read_text(encoding="utf-8")
        for label in (
            "帳戶餘額",
            "客戶端待結算",
            "伺服器確認",
            "同步序號",
            "伺服器龍珠結果",
        ):
            self.assertIn(label, text)

    def test_bridge_reports_platform_account_balance_and_account_notifications(self):
        text = BRIDGE.read_text(encoding="utf-8")
        self.assertIn("Gt2UserApp:GetMoney(dinoBall.currencyType)", text)
        self.assertIn('file:write("account_balance="', text)
        self.assertIn("originalOnUserConeyChanged", text)
        self.assertIn("gameMain.OnUserConeyChanged = function", text)
        self.assertIn("data.coney", text)
        self.assertIn("gameMain.OnUserConeyChanged = self.originalOnUserConeyChanged", text)

    def test_bridge_refreshes_read_only_status_while_no_commands_arrive(self):
        text = BRIDGE.read_text(encoding="utf-8")
        self.assertIn("statusPollCount", text)
        self.assertIn("writeStatus(nil, nil)", text)
        self.assertIn("U2G_CHEAT_CODE_REQ", text)

    def test_bridge_discards_stale_command_when_a_new_game_session_starts(self):
        text = BRIDGE.read_text(encoding="utf-8")
        start = text.index("function NativeGMBridge:Start()")
        scheduler = text.index("scheduleScriptFunc", start)
        discard = text.index("os.remove(COMMAND_PATH)", start)
        self.assertLess(discard, scheduler)

    def test_bridge_atomically_claims_each_command_before_dispatch(self):
        text = BRIDGE.read_text(encoding="utf-8")
        poll = text[text.index("local function pollCommand()"):
                    text.index("function NativeGMBridge:Start()")]
        self.assertIn('local claimPath = COMMAND_PATH .. "." .. nonce .. ".claim"', poll)
        self.assertIn("local claimed = os.rename(COMMAND_PATH, claimPath)", poll)
        self.assertIn('local claimedFile = io.open(claimPath, "r")', poll)
        self.assertIn("os.remove(claimPath)", poll)
        self.assertLess(poll.index("os.rename(COMMAND_PATH, claimPath)"),
                        poll.index("pcall(dispatch, command)"))

    def test_controller_has_server_code_tester_and_marks_local_ball_buttons(self):
        text = PROGRAM.read_text(encoding="utf-8")
        for label in (
            "本機增加彩虹珠",
            "伺服器作弊碼測試",
            "送出至伺服器",
            "只接受 1～8 位數字",
        ):
            self.assertIn(label, text)
        self.assertIn('Send("SERVER_CODE:" + code)', text)
        self.assertIn('TryGetValue("server_code"', text)
        self.assertIn('TryGetValue("server_code_account_delta"', text)

    def test_controller_uses_account_balance_and_labels_client_total_as_pending(self):
        text = PROGRAM.read_text(encoding="utf-8")
        self.assertIn('TryGetValue("account_balance"', text)
        self.assertIn('帳戶餘額：{accountBalance', text)
        self.assertIn('客戶端待結算：{localBalance', text)

    def test_controller_distinguishes_server_reward_from_visual_path(self):
        text = PROGRAM.read_text(encoding="utf-8")
        self.assertIn('TryGetValue("server_path_reward"', text)
        self.assertIn('TryGetValue("visual_path_reward"', text)
        self.assertIn("路徑結果：伺服器", text)
        self.assertIn("客戶端演出", text)

    def test_all_prize_visual_paths_can_be_held_until_cancelled(self):
        bridge = BRIDGE.read_text(encoding="utf-8")
        controller = PROGRAM.read_text(encoding="utf-8")
        self.assertIn("persistentRewardType", bridge)
        self.assertIn('string.match(command, "^PATH_([123])_HOLD$")', bridge)
        self.assertIn("NativeGMBridge.persistentRewardType = tonumber(holdPath)", bridge)
        self.assertIn("NativeGMBridge.persistentRewardType = nil", bridge)
        self.assertIn('file:write("persistent_path="', bridge)
        self.assertIn('"小獎路徑（維持）", "PATH_1_HOLD"', controller)
        self.assertIn('"中獎路徑（維持）", "PATH_2_HOLD"', controller)
        self.assertIn('"大獎路徑（維持）", "PATH_3_HOLD"', controller)
        self.assertIn('TryGetValue("persistent_path"', controller)

    def test_controller_displays_named_authoritative_reward_and_bridge_logs_each_application(self):
        bridge = BRIDGE.read_text(encoding="utf-8")
        controller = PROGRAM.read_text(encoding="utf-8")
        self.assertIn('appendEvent("path_applied"', bridge)
        self.assertIn("ball_type=", bridge)
        self.assertIn("server_reward=", bridge)
        self.assertIn("visual_path=", bridge)
        self.assertIn("private static string RewardName", controller)
        self.assertIn('"0" => "空獎"', controller)
        self.assertIn('"1" => "小獎"', controller)
        self.assertIn('"2" => "中獎"', controller)
        self.assertIn('"3" => "大獎"', controller)
        self.assertIn("正式獎值", controller)
        self.assertIn("演出路徑", controller)

    def test_bridge_logs_full_ball_lifecycle_without_changing_results(self):
        text = BRIDGE.read_text(encoding="utf-8")
        for symbol in (
            "originalAddBonusDraBall",
            "originalOnEventBallDropDwon",
            "originalOnDraBallTrigger",
        ):
            self.assertIn(symbol, text)
        for event_name in (
            'appendEvent("ball_created"',
            'appendEvent("platform_drop"',
            'appendEvent("server_outcome"',
            'appendEvent("wheel_landed"',
        ):
            self.assertIn(event_name, text)
        self.assertIn("broadcast_index=", text)
        self.assertIn("assigned_reward=", text)
        self.assertIn("account_before=", text)
        self.assertIn("account_after=", text)
        self.assertIn("dinoBall.Machine.addBonusDraBall = self.originalAddBonusDraBall", text)
        self.assertIn("gameMain.OnEventBallDropDwon = self.originalOnEventBallDropDwon", text)
        self.assertIn("gameCtrl.onDraBallTrigger = self.originalOnDraBallTrigger", text)

    def test_bridge_correlates_delayed_reward_credit_and_balance_probes(self):
        text = BRIDGE.read_text(encoding="utf-8")
        self.assertIn("originalGameCtrlAddProperty", text)
        self.assertIn('appendEvent("property_change"', text)
        self.assertIn('appendEvent("reward_credit"', text)
        self.assertIn('appendEvent("balance_probe"', text)
        self.assertIn("scheduleBalanceProbe", text)
        self.assertIn("gameCtrl.addProperty = self.originalGameCtrlAddProperty", text)

    def test_rejected_client_forged_dragon_ball_command_is_disabled(self):
        bridge = BRIDGE.read_text(encoding="utf-8")
        controller = PROGRAM.read_text(encoding="utf-8")
        dispatch = bridge[bridge.index("local function dispatch(command)"):]
        self.assertNotIn('ActionButton("自然流程普通龍珠", "ADD_DRA"', controller)
        self.assertIn('command == "ADD_DRA"', dispatch)
        self.assertIn('writeStatus("blocked", "ADD_DRA disabled: server verify rejected")', dispatch)
        self.assertNotIn("triggerNaturalDraBall()", dispatch)

    def test_two_small_pearl_types_have_visual_only_spawn_and_launch_controls(self):
        bridge = BRIDGE.read_text(encoding="utf-8")
        controller = PROGRAM.read_text(encoding="utf-8")
        self.assertIn("visualPearlTags", bridge)
        self.assertIn("local function spawnVisualPearls(ballType, count)", bridge)
        self.assertIn("local function shootVisualWhitePearl()", bridge)
        self.assertIn("local function shootVisualBluePearl()", bridge)
        self.assertIn('appendEvent("visual_pearl_spawned"', bridge)
        self.assertIn('appendEvent("visual_pearl_drop_ignored"', bridge)
        self.assertIn('appendEvent("visual_party_hole_ignored"', bridge)
        dispatch = bridge[bridge.index("local function dispatch(command)"):]
        for command in ("VISUAL_WHITE_10", "VISUAL_BLUE_10", "VISUAL_SHOOT_WHITE", "VISUAL_SHOOT_BLUE"):
            self.assertIn(command, dispatch)
        self.assertIn('"白珠佈場 +10", "VISUAL_WHITE_10"', controller)
        self.assertIn('"藍珠佈場 +10", "VISUAL_BLUE_10"', controller)
        self.assertIn('"白珠連射 開／關", "TOGGLE_VISUAL_WHITE_AUTO"', controller)
        self.assertIn('"龍頭彈射藍珠", "VISUAL_SHOOT_BLUE"', controller)

    def test_visual_white_auto_fire_is_rate_limited_and_capped(self):
        bridge = BRIDGE.read_text(encoding="utf-8")
        self.assertIn("visualWhiteAutoEnabled", bridge)
        self.assertIn("visualWhiteAutoTicks", bridge)
        self.assertIn("visualWhiteAutoMaxPearls = 60", bridge)
        self.assertIn('command == "TOGGLE_VISUAL_WHITE_AUTO"', bridge)
        self.assertIn("updateVisualWhiteAuto()", bridge)
        self.assertIn('appendEvent("visual_white_auto"', bridge)
        self.assertIn("machine:getPearlCount() >= NativeGMBridge.visualWhiteAutoMaxPearls", bridge)

    def test_official_blue_pearl_probe_waits_for_server_verify_ack(self):
        bridge = BRIDGE.read_text(encoding="utf-8")
        controller = PROGRAM.read_text(encoding="utf-8")
        self.assertIn("local function requestOfficialBluePearls()", bridge)
        self.assertIn("gameCtrl:shootPearl()", bridge)
        self.assertIn("define.Event.EnterPartyHole", bridge)
        self.assertIn("gameMain:Net_SyncGameState(true)", bridge)
        self.assertIn("pendingOfficialPearlSyncIndex", bridge)
        self.assertIn("originalOnSyncGameStateAckV2", bridge)
        self.assertIn("data.verifyOk", bridge)
        self.assertIn("gameCtrl:onPearlPartyTrigger()", bridge)
        self.assertIn('appendEvent("official_blue_pearl_ack"', bridge)
        self.assertIn('command == "OFFICIAL_BLUE_PROBE"', bridge)
        self.assertIn('"正式藍珠測試（扣1發）", "OFFICIAL_BLUE_PROBE"', controller)

    def test_official_blue_probe_stays_locked_until_all_blue_drops_are_verified(self):
        bridge = BRIDGE.read_text(encoding="utf-8")
        controller = PROGRAM.read_text(encoding="utf-8")
        self.assertIn("officialBlueLocked", bridge)
        self.assertIn("officialBlueOutstanding", bridge)
        self.assertIn("officialBlueFinalSyncIndex", bridge)
        self.assertIn("official blue pearl batch still active", bridge)
        self.assertIn('appendEvent("official_blue_drop"', bridge)
        self.assertIn('appendEvent("official_blue_settled"', bridge)
        self.assertIn("BeginOfficialBlueCooldown", controller)
        self.assertIn("await Task.Delay(10000)", controller)

    def test_official_white_table_probe_uses_paid_shot_and_authoritative_sync(self):
        bridge = BRIDGE.read_text(encoding="utf-8")
        controller = PROGRAM.read_text(encoding="utf-8")
        self.assertIn("local function requestOfficialWhitePearlOnTable()", bridge)
        self.assertIn("gameCtrl:shootPearl()", bridge)
        self.assertIn("officialWhiteTags[ballTag] = true", bridge)
        self.assertIn("targetBall:setPosition3D", bridge)
        self.assertIn("officialWhiteFireSyncIndex", bridge)
        self.assertIn("officialWhiteDropSyncIndex", bridge)
        self.assertIn('appendEvent("official_white_created"', bridge)
        self.assertIn('appendEvent("official_white_drop_ack"', bridge)
        self.assertIn('appendEvent("official_white_balance"', bridge)
        self.assertIn('command == "OFFICIAL_WHITE_TABLE_PROBE"', bridge)
        self.assertIn('"正式白珠 +1（扣1發）", "OFFICIAL_WHITE_TABLE_PROBE"', controller)
        self.assertIn('TryGetValue("official_white_state"', controller)

    def test_official_white_probe_confirms_from_server_refreshed_reentry_balance(self):
        bridge = BRIDGE.read_text(encoding="utf-8")
        self.assertIn('NativeGMBridge.officialWhiteState == "drop_verified"', bridge)
        self.assertIn("tonumber(syncIndex) == 0", bridge)
        self.assertIn("official_white_reentry_balance", bridge)
        self.assertIn("official white pearl persisted after room re-entry", bridge)

    def test_unsafe_server_settled_small_pearl_buttons_are_not_exposed(self):
        bridge = BRIDGE.read_text(encoding="utf-8")
        controller = PROGRAM.read_text(encoding="utf-8")
        self.assertNotIn('"ADD_SMALL_1"', controller)
        self.assertNotIn('"ADD_SMALL_5"', controller)
        self.assertNotIn('command == "ADD_SMALL_1"', bridge)
        self.assertNotIn('command == "ADD_SMALL_5"', bridge)

    def test_bridge_logs_authoritative_money_callbacks_as_events(self):
        text = BRIDGE.read_text(encoding="utf-8")
        self.assertIn('appendEvent("server_sync"', text)
        self.assertIn("originalOnChangeMoneyNotify", text)
        self.assertIn("originalOnEventChangeNotify", text)
        self.assertIn('appendEvent("money_notify"', text)
        self.assertIn('appendEvent("event_money_notify"', text)
        self.assertIn("gameMain.OnChangeMoneyNotify = self.originalOnChangeMoneyNotify", text)
        self.assertIn("gameMain.OnEventChangeNotify = self.originalOnEventChangeNotify", text)

    def test_small_pearl_credit_and_dragon_sync_have_separate_diagnostics(self):
        bridge = BRIDGE.read_text(encoding="utf-8")
        controller = PROGRAM.read_text(encoding="utf-8")
        for field in (
            "smallPearlDropCount",
            "smallPearlClientCredit",
            "smallPearlAccountBase",
            "lastGameStateVerify",
            "lastGameStateAckIndex",
            "gameStateRejectCount",
        ):
            self.assertIn(field, bridge)
        for event_name in (
            'appendEvent("small_pearl_credit"',
            'appendEvent("dragon_sync_ack"',
        ):
            self.assertIn(event_name, bridge)
        for status_key in (
            'file:write("small_pearl_drop_count="',
            'file:write("small_pearl_client_credit="',
            'file:write("small_pearl_account_delta="',
            'file:write("dragon_sync_verify="',
            'file:write("dragon_sync_index="',
            'file:write("dragon_sync_reject_count="',
        ):
            self.assertIn(status_key, bridge)
        self.assertIn("真珠結算：", controller)
        self.assertIn("龍珠同步：", controller)
        self.assertIn('TryGetValue("small_pearl_drop_count"', controller)
        self.assertIn('TryGetValue("dragon_sync_verify"', controller)

    def test_real_pearl_settlement_reports_last_value_and_server_sync(self):
        bridge = BRIDGE.read_text(encoding="utf-8")
        controller = PROGRAM.read_text(encoding="utf-8")
        self.assertIn("smallPearlLastValue", bridge)
        self.assertIn('file:write("small_pearl_last_value="', bridge)
        self.assertIn('file:write("small_pearl_sync="', bridge)
        self.assertIn("NativeGMBridge.smallPearlLastValue = tonumber(value) or 0", bridge)
        self.assertIn('TryGetValue("small_pearl_last_value"', controller)
        self.assertIn('TryGetValue("small_pearl_sync"', controller)
        self.assertIn("真珠結算：", controller)
        self.assertIn("僅本機（未入帳）", controller)
        self.assertIn('smallPearlSync = "local_only"', bridge)
        self.assertNotIn('smallPearlSync = "true"', bridge)

    def test_passive_timeline_hooks_the_real_model_send_and_receive_boundaries(self):
        text = BRIDGE.read_text(encoding="utf-8")
        self.assertIn('local TEMP_ROOT = (os.getenv("TEMP")', text)
        self.assertIn('local IPC_ROOT = TEMP_ROOT .. "/PearlBubbleNativeGM"', text)
        self.assertIn('local TIMELINE_LOG_PATH = IPC_ROOT .. "/PearlBubbleNativeGM.timeline.log"', text)
        self.assertIn("originalModelSendLuaCommand", text)
        self.assertIn("originalModelOnCommand", text)
        self.assertIn("PearlBubbleModel.SendLuaCommand = function(self, cmd, content)", text)
        self.assertIn("PearlBubbleModel.OnCommand = function(self, luaCommand)", text)
        self.assertIn('appendTimeline("SEND", cmd, content)', text)
        self.assertIn('appendTimeline("RECV", commandType, content)', text)
        self.assertIn("PearlBubbleModel.SendLuaCommand = self.originalModelSendLuaCommand", text)
        self.assertIn("PearlBubbleModel.OnCommand = self.originalModelOnCommand", text)

    def test_controller_and_bridge_share_writable_temp_ipc(self):
        bridge = BRIDGE.read_text(encoding="utf-8")
        controller = PROGRAM.read_text(encoding="utf-8")
        self.assertIn('os.getenv("TEMP")', bridge)
        self.assertIn('Path.Combine(Path.GetTempPath(), "PearlBubbleNativeGM")', controller)
        self.assertIn('DateTime.UtcNow - File.GetLastWriteTimeUtc(statusPath)', controller)
        self.assertIn('命令未送出：遊戲橋接未連線', controller)
        runtime_check = (ROOT / "CHECK_RUNTIME.bat").read_text(encoding="utf-8")
        self.assertIn(r"%TEMP%\PearlBubbleNativeGM", runtime_check)
        self.assertIn("BRIDGE NOT CONNECTED", runtime_check)
        updater = (ROOT / "UPDATE.bat").read_text(encoding="utf-8")
        self.assertIn('call "%~dp0INSTALL.bat"', updater)

    def test_passive_timeline_serializes_the_parsed_protocol_structures(self):
        text = BRIDGE.read_text(encoding="utf-8")
        for field in (
            '"code"',
            '"verifyOk"',
            '"index"',
            '"bgDataList"',
            '"ballType"',
            '"holeType"',
            '"broadcastIndex"',
            '"buffer"',
            '"soulBuffer"',
            '"changeAmount"',
            '"currentMoney"',
        ):
            self.assertIn(field, text)
        self.assertIn("timelineProtocolFields", text)
        self.assertIn("timelineVectorFields", text)
        self.assertNotIn("ParseBgDataList", text)
        self.assertNotIn("table.tostring", text)
        self.assertNotIn("HexDump", text)

    def test_passive_timeline_has_stable_sequence_and_relative_clock_columns(self):
        text = BRIDGE.read_text(encoding="utf-8")
        self.assertIn("timelineSequence", text)
        self.assertIn("timelineStartClock", text)
        self.assertIn('"seq|unix_s|elapsed_ms|direction|opcode|name|data\\n"', text)
        self.assertIn("math.floor((os.clock() - NativeGMBridge.timelineStartClock) * 1000 + 0.5)", text)
        self.assertIn("timelineOpcodeName", text)


if __name__ == "__main__":
    unittest.main()



