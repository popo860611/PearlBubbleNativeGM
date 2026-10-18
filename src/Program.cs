using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

namespace PearlBubbleNativeGM;

internal static class Program
{
    [STAThread]
    private static void Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        string? requestedRoot = null;
        for (var i = 0; i + 1 < args.Length; i++)
            if (args[i].Equals("--root", StringComparison.OrdinalIgnoreCase))
                requestedRoot = args[i + 1];
        Application.Run(new MainForm(requestedRoot));
    }
}

internal sealed class MainForm : Form
{
    private const int HotkeyId = 0x5042;
    private const int WmHotkey = 0x0312;
    private readonly string root;
    private readonly string commandPath;
    private readonly string statusPath;
    private readonly Label gameState = new();
    private readonly Label bridgeState = new();
    private readonly Label pendingState = new();
    private readonly Label localBalanceState = new();
    private readonly Label localDeltaState = new();
    private readonly Label serverBalanceState = new();
    private readonly Label syncState = new();
    private readonly Label rewardState = new();
    private readonly Label pathResultState = new();
    private readonly Label serverCodeState = new();
    private readonly Label smallPearlState = new();
    private readonly Label dragonSyncState = new();
    private readonly TextBox serverCodeInput = new();
    private readonly System.Windows.Forms.Timer timer = new() { Interval = 350 };
    private long serial;

    [DllImport("user32.dll")]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint modifiers, uint key);

    [DllImport("user32.dll")]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    public MainForm(string? requestedRoot)
    {
        root = Path.GetFullPath(requestedRoot ?? AppContext.BaseDirectory);
        commandPath = Path.Combine(root, "tmpNew", "PearlBubbleNativeGM.cmd");
        statusPath = Path.Combine(root, "tmpNew", "PearlBubbleNativeGM.status");

        Text = "深海龍珠 Native GM";
        ClientSize = new Size(390, 930);
        FormBorderStyle = FormBorderStyle.FixedToolWindow;
        MaximizeBox = false;
        MinimizeBox = true;
        TopMost = true;
        StartPosition = FormStartPosition.Manual;
        Location = new Point(Math.Max(10, Screen.PrimaryScreen!.WorkingArea.Right - Width - 20), 80);
        Font = new Font("Microsoft JhengHei UI", 10F);
        BackColor = Color.FromArgb(26, 31, 42);
        ForeColor = Color.WhiteSmoke;

        var title = new Label
        {
            Text = "深海龍珠 · 實機控制",
            Font = new Font(Font.FontFamily, 15F, FontStyle.Bold),
            ForeColor = Color.FromArgb(93, 211, 255),
            Location = new Point(18, 15),
            AutoSize = true
        };
        Controls.Add(title);

        ConfigureStatus(gameState, 55);
        ConfigureStatus(bridgeState, 79);
        ConfigureStatus(pendingState, 103);
        ConfigureStatus(localBalanceState, 127);
        ConfigureStatus(localDeltaState, 151);
        ConfigureStatus(serverBalanceState, 175);
        ConfigureStatus(syncState, 199);
        ConfigureStatus(rewardState, 223);
        ConfigureStatus(pathResultState, 247);
        ConfigureStatus(serverCodeState, 271);
        ConfigureStatus(smallPearlState, 295);
        ConfigureStatus(dragonSyncState, 319);
        Controls.Add(gameState);
        Controls.Add(bridgeState);
        Controls.Add(pendingState);
        Controls.Add(localBalanceState);
        Controls.Add(localDeltaState);
        Controls.Add(serverBalanceState);
        Controls.Add(syncState);
        Controls.Add(rewardState);
        Controls.Add(pathResultState);
        Controls.Add(serverCodeState);
        Controls.Add(smallPearlState);
        Controls.Add(dragonSyncState);

        Controls.Add(Section("本機實體球（不保證伺服器入帳）", 352));
        Controls.Add(ActionButton("本機增加彩虹珠", "ADD_RAIN", 202, 384, Color.FromArgb(171, 71, 188)));
        Controls.Add(ActionButton("白珠佈場 +10", "VISUAL_WHITE_10", 18, 430, Color.FromArgb(120, 144, 156)));
        Controls.Add(ActionButton("藍珠佈場 +10", "VISUAL_BLUE_10", 202, 430, Color.FromArgb(3, 169, 244)));
        Controls.Add(ActionButton("白珠連射 開／關", "TOGGLE_VISUAL_WHITE_AUTO", 18, 476, Color.FromArgb(96, 125, 139)));
        Controls.Add(ActionButton("龍頭彈射藍珠", "VISUAL_SHOOT_BLUE", 202, 476, Color.FromArgb(2, 136, 209)));
        var officialBlue = ActionButton("正式藍珠測試（扣1發）", "OFFICIAL_BLUE_PROBE", 18, 522, Color.FromArgb(0, 105, 92));
        officialBlue.Width = 356;
        officialBlue.Click += (_, _) => BeginOfficialBlueCooldown(officialBlue);
        Controls.Add(officialBlue);

        Controls.Add(Section("伺服器作弊碼測試", 574));
        serverCodeInput.Location = new Point(18, 607);
        serverCodeInput.Size = new Size(172, 34);
        serverCodeInput.MaxLength = 8;
        serverCodeInput.PlaceholderText = "輸入數字代碼";
        Controls.Add(serverCodeInput);
        var sendServerCode = ActionButton("送出至伺服器", "", 202, 602, Color.FromArgb(0, 121, 107));
        sendServerCode.Click += (_, _) =>
        {
            var code = serverCodeInput.Text.Trim();
            if (code.Length is < 1 or > 8 || !code.All(char.IsDigit))
            {
                bridgeState.Text = "伺服器碼錯誤：只接受 1～8 位數字";
                return;
            }
            Send("SERVER_CODE:" + code);
        };
        Controls.Add(sendServerCode);
        Controls.Add(new Label
        {
            Text = "只接受 1～8 位數字；是否有效由私服回覆判定",
            Location = new Point(18, 646),
            Size = new Size(356, 22),
            ForeColor = Color.Silver
        });

        Controls.Add(Section("指定下一顆龍珠落洞路徑（一次性）", 679));
        Controls.Add(ActionButton("空獎路徑", "PATH_0", 18, 711, Color.FromArgb(84, 110, 122)));
        Controls.Add(ActionButton("小獎路徑（維持）", "PATH_1_HOLD", 202, 711, Color.FromArgb(67, 160, 71)));
        Controls.Add(ActionButton("中獎路徑（維持）", "PATH_2_HOLD", 18, 765, Color.FromArgb(251, 140, 0)));
        Controls.Add(ActionButton("大獎路徑（維持）", "PATH_3_HOLD", 202, 765, Color.FromArgb(229, 57, 53)));

        var cancel = ActionButton("取消指定／恢復正常", "CANCEL_PATH", 18, 822, Color.FromArgb(69, 75, 86));
        cancel.Width = 356;
        Controls.Add(cancel);

        var hint = new Label
        {
            Text = "Insert：顯示／隱藏　　路徑只影響客戶端演出",
            Location = new Point(18, 884),
            Size = new Size(356, 24),
            ForeColor = Color.Silver,
            TextAlign = ContentAlignment.MiddleCenter
        };
        Controls.Add(hint);

        timer.Tick += (_, _) => RefreshStatus();
        timer.Start();
        Shown += (_, _) => RefreshStatus();
    }

    private static void ConfigureStatus(Label label, int y)
    {
        label.Location = new Point(18, y);
        label.Size = new Size(356, 22);
        label.ForeColor = Color.Gainsboro;
    }

    private static string RewardName(string? value) => value switch
    {
        "0" => "空獎",
        "1" => "小獎",
        "2" => "中獎",
        "3" => "大獎",
        "none" => "尚未收到",
        null => "unknown",
        _ => value
    };

    private static string RewardListNames(string? values) => string.Join(",",
        (values ?? "none").Split(',').Select(RewardName));

    private Label Section(string text, int y) => new()
    {
        Text = text,
        Location = new Point(18, y),
        Size = new Size(356, 25),
        Font = new Font(Font, FontStyle.Bold),
        ForeColor = Color.FromArgb(255, 213, 79)
    };

    private Button ActionButton(string text, string command, int x, int y, Color color)
    {
        var button = new Button
        {
            Text = text,
            Location = new Point(x, y),
            Size = new Size(172, 42),
            FlatStyle = FlatStyle.Flat,
            BackColor = color,
            ForeColor = Color.White,
            Cursor = Cursors.Hand
        };
        button.FlatAppearance.BorderSize = 0;
        if (!string.IsNullOrEmpty(command))
            button.Click += (_, _) => Send(command);
        return button;
    }

    private void Send(string command)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(commandPath)!);
            var nonce = $"{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}-{Interlocked.Increment(ref serial)}";
            var temporary = commandPath + ".tmp";
            File.WriteAllText(temporary, nonce + "|" + command + "\n", new UTF8Encoding(false));
            File.Move(temporary, commandPath, true);
            bridgeState.Text = "命令：已送出 " + command;
        }
        catch (Exception ex)
        {
            bridgeState.Text = "命令錯誤：" + ex.Message;
        }
    }

    private async void BeginOfficialBlueCooldown(Button button)
    {
        button.Enabled = false;
        await Task.Delay(10000);
        if (!IsDisposed)
            button.Enabled = true;
    }

    private void RefreshStatus()
    {
        var names = new[] { "StarMJ371_unpacked_RemoveCheck_Cli_v2", "StarMJ371", "StarMJ371_unpacked_RemoveCheck_Cli" };
        var process = names.SelectMany(Process.GetProcessesByName).FirstOrDefault(p => !p.HasExited);
        gameState.Text = process == null ? "遊戲：未偵測到" : $"遊戲：執行中 PID {process.Id}";
        gameState.ForeColor = process == null ? Color.OrangeRed : Color.LightGreen;

        if (!File.Exists(statusPath))
        {
            bridgeState.Text = "橋接：等待進入深海龍珠";
            pendingState.Text = "下一路徑：未指定";
            localBalanceState.Text = "帳戶餘額：等待資料";
            localDeltaState.Text = "客戶端待結算：等待資料";
            serverBalanceState.Text = "伺服器確認：等待同步";
            syncState.Text = "同步序號：等待同步";
            rewardState.Text = "伺服器龍珠結果：尚未收到";
            pathResultState.Text = "路徑結果：伺服器等待資料／客戶端演出等待資料";
            serverCodeState.Text = "伺服器碼：尚未送出";
            smallPearlState.Text = "小珠流程：等待資料";
            dragonSyncState.Text = "龍珠同步：等待資料";
            return;
        }
        try
        {
            var values = File.ReadAllLines(statusPath)
                .Select(line => line.Split('=', 2))
                .Where(parts => parts.Length == 2)
                .ToDictionary(parts => parts[0], parts => parts[1]);
            values.TryGetValue("state", out var state);
            values.TryGetValue("detail", out var detail);
            values.TryGetValue("pending", out var pending);
            values.TryGetValue("persistent_path", out var persistentPath);
            values.TryGetValue("account_balance", out var accountBalance);
            values.TryGetValue("local_balance", out var localBalance);
            values.TryGetValue("local_delta", out var localDelta);
            values.TryGetValue("server_final", out var serverFinal);
            values.TryGetValue("server_add", out var serverAdd);
            values.TryGetValue("server_sub", out var serverSub);
            values.TryGetValue("sync_index", out var syncIndex);
            values.TryGetValue("server_reward_count", out var rewardCount);
            values.TryGetValue("server_reward_types", out var rewardTypes);
            values.TryGetValue("server_path_reward", out var serverPathReward);
            values.TryGetValue("visual_path_reward", out var visualPathReward);
            values.TryGetValue("server_code", out var serverCode);
            values.TryGetValue("server_code_account_delta", out var serverCodeAccountDelta);
            values.TryGetValue("server_code_reward_delta", out var serverCodeRewardDelta);
            values.TryGetValue("small_pearl_drop_count", out var smallPearlDropCount);
            values.TryGetValue("small_pearl_client_credit", out var smallPearlClientCredit);
            values.TryGetValue("small_pearl_account_delta", out var smallPearlAccountDelta);
            values.TryGetValue("dragon_sync_verify", out var dragonSyncVerify);
            values.TryGetValue("dragon_sync_index", out var dragonSyncIndex);
            values.TryGetValue("dragon_sync_reject_count", out var dragonSyncRejectCount);
            bridgeState.Text = $"橋接：{state ?? "unknown"}　{detail ?? ""}";
            var persistentPathName = persistentPath switch
            {
                "1" => "小獎",
                "2" => "中獎",
                "3" => "大獎",
                _ => null
            };
            pendingState.Text = persistentPathName != null
                ? $"維持路徑：{persistentPathName}（按取消恢復）"
                : "下一路徑：" + ((pending ?? "none") switch
                {
                    "0" => "空獎",
                    "1" => "小獎",
                    "2" => "中獎",
                    "3" => "大獎",
                    _ => "未指定"
                });
            localBalanceState.Text = $"帳戶餘額：{accountBalance ?? "unknown"}";
            localDeltaState.Text = $"客戶端待結算：{localBalance ?? "unknown"}（差額 {localDelta ?? "unknown"}）";
            serverBalanceState.Text = $"伺服器確認：{serverFinal ?? "unknown"}　(+{serverAdd ?? "?"}/-{serverSub ?? "?"})";
            syncState.Text = $"同步序號：{syncIndex ?? "unknown"}";
            rewardState.Text = $"伺服器龍珠結果：{rewardCount ?? "0"}　正式獎值 {RewardListNames(rewardTypes)}";
            pathResultState.Text = $"路徑結果：伺服器正式獎值 {RewardName(serverPathReward)}／客戶端演出路徑 {RewardName(visualPathReward)}";
            serverCodeState.Text = $"伺服器碼：{serverCode ?? "none"}　餘額差 {serverCodeAccountDelta ?? "?"}　回覆 {serverCodeRewardDelta ?? "?"}";
            smallPearlState.Text = $"小珠流程：掉落 {smallPearlDropCount ?? "0"}／客戶端 +{smallPearlClientCredit ?? "0"}／帳戶 +{smallPearlAccountDelta ?? "?"}";
            dragonSyncState.Text = $"龍珠同步：{dragonSyncVerify ?? "none"}／序號 {dragonSyncIndex ?? "?"}／拒絕 {dragonSyncRejectCount ?? "0"}";
        }
        catch (Exception ex)
        {
            bridgeState.Text = "橋接狀態讀取失敗：" + ex.Message;
        }
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        RegisterHotKey(Handle, HotkeyId, 0, (uint)Keys.Insert);
    }

    protected override void OnHandleDestroyed(EventArgs e)
    {
        UnregisterHotKey(Handle, HotkeyId);
        base.OnHandleDestroyed(e);
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WmHotkey && m.WParam.ToInt32() == HotkeyId)
        {
            if (Visible) Hide();
            else { Show(); Activate(); }
            return;
        }
        base.WndProc(ref m);
    }
}
