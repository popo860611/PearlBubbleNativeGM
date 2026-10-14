import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / "src" / "NativeGMBridge.lua"
PROGRAM = ROOT / "src" / "Program.cs"


class NativeMenuContractTests(unittest.TestCase):
    def test_bridge_has_exact_supported_commands_and_one_shot_visual_override(self):
        text = BRIDGE.read_text(encoding="utf-8")
        for command in (
            "ADD_DRA",
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

    def test_controller_exposes_six_requested_actions_and_hotkey(self):
        text = PROGRAM.read_text(encoding="utf-8")
        for label in (
            "自然流程普通龍珠",
            "增加彩虹珠",
            "空獎路徑",
            "小獎路徑",
            "中獎路徑",
            "大獎路徑",
        ):
            self.assertIn(label, text)
        self.assertIn("Keys.Insert", text)
        self.assertIn("TopMost = true", text)

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

    def test_controller_has_server_code_tester_and_marks_local_ball_buttons(self):
        text = PROGRAM.read_text(encoding="utf-8")
        for label in (
            "自然流程普通龍珠",
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

    def test_normal_ball_button_uses_the_games_natural_party_hole_flow(self):
        text = BRIDGE.read_text(encoding="utf-8")
        self.assertIn("local function triggerNaturalDraBall()", text)
        self.assertIn("gameCtrl:onPartyTrigger", text)
        self.assertIn("define.PartyTriggerType.DraBall", text)
        self.assertIn("define.BlockGroup.EnterDraBall", text)
        self.assertIn('appendEvent("natural_draball_trigger"', text)
        dispatch = text[text.index("local function dispatch(command)"):]
        self.assertIn('command == "ADD_DRA"', dispatch)
        self.assertIn("triggerNaturalDraBall()", dispatch)

    def test_bridge_logs_authoritative_money_callbacks_as_events(self):
        text = BRIDGE.read_text(encoding="utf-8")
        self.assertIn('appendEvent("server_sync"', text)
        self.assertIn("originalOnChangeMoneyNotify", text)
        self.assertIn("originalOnEventChangeNotify", text)
        self.assertIn('appendEvent("money_notify"', text)
        self.assertIn('appendEvent("event_money_notify"', text)
        self.assertIn("gameMain.OnChangeMoneyNotify = self.originalOnChangeMoneyNotify", text)
        self.assertIn("gameMain.OnEventChangeNotify = self.originalOnEventChangeNotify", text)


if __name__ == "__main__":
    unittest.main()
