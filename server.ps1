# yt-dlp Studio - serveur local (http://127.0.0.1:8765/)
# Sert index.html et lance yt-dlp directement : plus de copier/coller dans un terminal.
# Ecoute UNIQUEMENT en local. Chaque appel /api exige le jeton injecte dans la page
# (une page web tierce ne peut pas le lire) + un en-tete Host local (anti DNS rebinding).
# Les arguments yt-dlp sont construits ICI a partir d'options en liste blanche :
# le navigateur n'envoie jamais de ligne de commande brute, et aucun shell n'est utilise.
param(
    [int]$Port = 8765,
    [switch]$NoBrowser,
    [switch]$NoUpdate
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
try { $Host.UI.RawUI.WindowTitle = 'yt-dlp Studio - serveur (fermer = arreter)' } catch {}

$Root = $PSScriptRoot
$Bin = Join-Path $Root 'bin'
$Ytdlp = Join-Path $Bin 'yt-dlp.exe'
$SettingsPath = Join-Path $Root 'settings.json'
# "Telechargements" avec accents, sans mettre de non-ASCII dans ce .ps1 (PS 5.1 lit en ANSI)
$DefaultDest = Join-Path $Root ('T' + [char]0xE9 + 'l' + [char]0xE9 + 'chargements')
$BaseUrl = "http://127.0.0.1:$Port/"
$Token = [guid]::NewGuid().ToString('N')

function Log([string]$msg) { Write-Host ((Get-Date -Format 'HH:mm:ss') + '  ' + $msg) }

function Open-Ui {
    if ($NoBrowser) { return }
    & (Join-Path $Root 'open-ui.ps1') -Url $BaseUrl
}

# --- Deja lance ? On rouvre juste l'interface ---
try {
    $r = Invoke-WebRequest -Uri ($BaseUrl + 'api/ping') -UseBasicParsing -TimeoutSec 2
    if ($r.Content -match 'yt-dlp-studio') {
        Log 'yt-dlp Studio tourne deja : ouverture de l''interface.'
        Open-Ui
        exit 0
    }
} catch {}

# ============================================================================
#  C# : file d'attente (processus + lecture de la progression) et selecteur
#  de dossier Windows moderne. Compile une fois au demarrage (~1 s).
# ============================================================================
$cs = @'
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace YtdlpStudio
{
    public class Job
    {
        public int Id;
        public string Label = "";
        public string Kind = "";
        public string Dir = "";
        public string CommandLine = "";
        public string Status = "queued";
        public int ExitCode;
        public double Percent = -1;
        public double Speed = -1;
        public int Eta = -1;
        public string Title = "";
        public int ItemIndex;
        public int ItemCount;
        public int Started;
        public int FilesDone;
        public string LastFile = "";
        public string LastError = "";
        public DateTime Created = DateTime.Now;
        public Process Proc;
        public bool CancelRequested;
        public List<string> Log = new List<string>();
    }

    public class JobQueue
    {
        readonly object gate = new object();
        readonly List<Job> jobs = new List<Job>();
        readonly AutoResetEvent signal = new AutoResetEvent(false);
        readonly string exe, workDir, pathEnv;
        int nextId = 1;
        bool paused;

        public JobQueue(string exe, string workDir, string pathEnv, bool startPaused)
        {
            this.exe = exe; this.workDir = workDir; this.pathEnv = pathEnv; this.paused = startPaused;
            Thread t = new Thread(Loop);
            t.IsBackground = true;
            t.Start();
        }

        public bool Paused { get { lock (gate) { return paused; } } }

        public void Resume() { lock (gate) { paused = false; } signal.Set(); }

        public static string Quote(string a) { return QuoteCore(a, false); }

        static string QuoteCore(string a, bool force)
        {
            if (!force && a.Length > 0 && a.IndexOfAny(new char[] { ' ', '\t', '"', '\n', '\v' }) < 0) return a;
            StringBuilder sb = new StringBuilder("\"");
            int bs = 0;
            foreach (char c in a)
            {
                if (c == '\\') { bs++; continue; }
                if (c == '"') { sb.Append('\\', bs * 2 + 1); sb.Append('"'); bs = 0; continue; }
                sb.Append('\\', bs); bs = 0; sb.Append(c);
            }
            sb.Append('\\', bs * 2);
            sb.Append('"');
            return sb.ToString();
        }

        public static string JoinArgs(string[] args)
        {
            string[] q = new string[args.Length];
            for (int i = 0; i < args.Length; i++) q[i] = Quote(args[i]);
            return string.Join(" ", q);
        }

        // Version a coller dans cmd : on met aussi entre guillemets < > | & ^ ( ) etc.
        public static string JoinArgsForCmd(string[] args)
        {
            char[] special = " \t\"<>|&^()%!;,=".ToCharArray();
            string[] q = new string[args.Length];
            for (int i = 0; i < args.Length; i++) q[i] = QuoteCore(args[i], args[i].IndexOfAny(special) >= 0);
            return string.Join(" ", q);
        }

        public int Add(string label, string kind, string dir, string[] args, int itemCount)
        {
            Job j = new Job();
            j.Label = label; j.Kind = kind; j.Dir = dir; j.ItemCount = itemCount;
            j.CommandLine = JoinArgs(args);
            lock (gate) { j.Id = nextId++; jobs.Add(j); }
            signal.Set();
            return j.Id;
        }

        Job Find(int id)
        {
            foreach (Job j in jobs) if (j.Id == id) return j;
            return null;
        }

        public bool Cancel(int id)
        {
            int pid = 0;
            lock (gate)
            {
                Job j = Find(id);
                if (j == null) return false;
                if (j.Status == "queued") { j.Status = "canceled"; return true; }
                if (j.Status != "running") return false;
                j.CancelRequested = true;
                if (j.Proc != null) { try { pid = j.Proc.Id; } catch { pid = 0; } }
            }
            if (pid > 0) KillTree(pid);
            return true;
        }

        public void CancelAll()
        {
            List<int> ids = new List<int>();
            lock (gate) { foreach (Job j in jobs) if (j.Status == "queued" || j.Status == "running") ids.Add(j.Id); }
            foreach (int id in ids) Cancel(id);
        }

        public int ActiveCount()
        {
            int n = 0;
            lock (gate) { foreach (Job j in jobs) if (j.Status == "queued" || j.Status == "running") n++; }
            return n;
        }

        public void ClearFinished()
        {
            lock (gate) { jobs.RemoveAll(delegate (Job j) { return j.Status != "queued" && j.Status != "running"; }); }
        }

        static void KillTree(int pid)
        {
            // yt-dlp lance ffmpeg : taskkill /T tue tout l'arbre de processus.
            try
            {
                ProcessStartInfo k = new ProcessStartInfo("taskkill", "/PID " + pid + " /T /F");
                k.UseShellExecute = false; k.CreateNoWindow = true;
                Process kp = Process.Start(k);
                kp.WaitForExit(8000);
            }
            catch { }
        }

        void Loop()
        {
            while (true)
            {
                Job next = null;
                lock (gate)
                {
                    if (!paused) foreach (Job j in jobs) if (j.Status == "queued") { next = j; break; }
                }
                if (next == null) { signal.WaitOne(1000); continue; }
                Run(next);
            }
        }

        void Run(Job j)
        {
            ProcessStartInfo psi = new ProcessStartInfo(exe, j.CommandLine);
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.StandardOutputEncoding = Encoding.UTF8;
            psi.StandardErrorEncoding = Encoding.UTF8;
            psi.WorkingDirectory = workDir;
            psi.EnvironmentVariables["PATH"] = pathEnv;
            psi.EnvironmentVariables["PYTHONIOENCODING"] = "utf-8";
            psi.EnvironmentVariables["PYTHONUTF8"] = "1";

            Process p = new Process();
            p.StartInfo = psi;
            p.OutputDataReceived += delegate (object s, DataReceivedEventArgs e) { if (e.Data != null) OnLine(j, e.Data); };
            p.ErrorDataReceived += delegate (object s, DataReceivedEventArgs e) { if (e.Data != null) OnLine(j, e.Data); };

            lock (gate)
            {
                if (j.Status != "queued") return;
                j.Status = "running";
            }
            Console.WriteLine(DateTime.Now.ToString("HH:mm:ss") + "  [#" + j.Id + "] demarrage : " + j.Label);
            try
            {
                if (!File.Exists(exe)) throw new FileNotFoundException("yt-dlp.exe introuvable (lancez install.bat)");
                Directory.CreateDirectory(j.Dir);
                p.Start();
            }
            catch (Exception ex)
            {
                lock (gate) { j.Status = "error"; j.LastError = ex.Message; }
                Console.WriteLine(DateTime.Now.ToString("HH:mm:ss") + "  [#" + j.Id + "] ERREUR : " + ex.Message);
                return;
            }
            bool killNow;
            lock (gate) { j.Proc = p; killNow = j.CancelRequested; }
            if (killNow) KillTree(p.Id);
            p.BeginOutputReadLine();
            p.BeginErrorReadLine();
            p.WaitForExit();

            lock (gate)
            {
                j.ExitCode = p.ExitCode;
                j.Proc = null;
                if (j.CancelRequested) j.Status = "canceled";
                else if (p.ExitCode == 0) { j.Status = "done"; j.Percent = 100; }
                else if (j.FilesDone > 0) j.Status = "partial";
                else j.Status = "error";
                j.Speed = -1; j.Eta = -1;
            }
            p.Dispose();
            Console.WriteLine(DateTime.Now.ToString("HH:mm:ss") + "  [#" + j.Id + "] " + j.Status + " (" + j.FilesDone + " fichier(s))");
        }

        static double Num(string s)
        {
            double d;
            if (double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out d)) return d;
            return -1;
        }

        void OnLine(Job j, string line)
        {
            lock (gate)
            {
                if (line.StartsWith("@@P|"))
                {
                    // downloaded|total|estimate|speed|eta
                    string[] f = line.Split('|');
                    if (f.Length >= 6)
                    {
                        double done = Num(f[1]), total = Num(f[2]), est = Num(f[3]);
                        if (total <= 0) total = est;
                        if (done >= 0 && total > 0) j.Percent = Math.Min(100.0, done * 100.0 / total);
                        j.Speed = Num(f[4]);
                        double eta = Num(f[5]);
                        j.Eta = eta >= 0 ? (int)eta : -1;
                    }
                    return;
                }
                if (line.StartsWith("@@T|"))
                {
                    // playlist_index|n_entries|title
                    string[] f = line.Split(new char[] { '|' }, 4);
                    if (f.Length == 4)
                    {
                        int idx, n;
                        j.Started++;
                        j.ItemIndex = int.TryParse(f[1], out idx) ? idx : j.Started;
                        if (int.TryParse(f[2], out n) && n > 0) j.ItemCount = n;
                        j.Title = f[3];
                        j.Percent = 0;
                    }
                    return;
                }
                if (line.StartsWith("@@F|"))
                {
                    j.FilesDone++;
                    j.LastFile = line.Substring(4);
                    return;
                }
                if (line.StartsWith("ERROR:")) j.LastError = line;
                j.Log.Add(line);
                if (j.Log.Count > 300) j.Log.RemoveRange(0, j.Log.Count - 300);
            }
        }

        public ArrayList Snapshot()
        {
            ArrayList list = new ArrayList();
            lock (gate)
            {
                foreach (Job j in jobs)
                {
                    Hashtable h = new Hashtable();
                    h["id"] = j.Id; h["label"] = j.Label; h["kind"] = j.Kind; h["dir"] = j.Dir;
                    h["status"] = j.Status; h["exitCode"] = j.ExitCode;
                    h["percent"] = Math.Round(j.Percent, 1); h["speed"] = Math.Round(j.Speed); h["eta"] = j.Eta;
                    h["title"] = j.Title; h["itemIndex"] = j.ItemIndex; h["itemCount"] = j.ItemCount;
                    h["filesDone"] = j.FilesDone; h["lastFile"] = j.LastFile; h["lastError"] = j.LastError;
                    int from = Math.Max(0, j.Log.Count - 40);
                    h["log"] = j.Log.GetRange(from, j.Log.Count - from).ToArray();
                    list.Add(h);
                }
            }
            return list;
        }
    }

    // ------------------------------------------------------------------------
    // Selecteur de dossier Windows (IFileOpenDialog + FOS_PICKFOLDERS)
    // ------------------------------------------------------------------------
    [ComImport, Guid("DC1C5A9C-E88A-4dde-A5A1-60F82A20AEF7")]
    class FileOpenDialogRCW { }

    [ComImport, Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellItem
    {
        void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
        void GetParent(out IShellItem ppsi);
        void GetDisplayName(uint sigdnName, [MarshalAs(UnmanagedType.LPWStr)] out string ppszName);
        void GetAttributes(uint sfgaoMask, out uint psfgaoAttribs);
        void Compare(IShellItem psi, uint hint, out int piOrder);
    }

    [ComImport, Guid("d57c7288-d4ad-4768-be02-9d969532d960"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IFileOpenDialog
    {
        [PreserveSig] int Show(IntPtr parent);
        void SetFileTypes(uint cFileTypes, IntPtr rgFilterSpec);
        void SetFileTypeIndex(uint iFileType);
        void GetFileTypeIndex(out uint piFileType);
        void Advise(IntPtr pfde, out uint pdwCookie);
        void Unadvise(uint dwCookie);
        void SetOptions(uint fos);
        void GetOptions(out uint pfos);
        void SetDefaultFolder(IShellItem psi);
        void SetFolder(IShellItem psi);
        void GetFolder(out IShellItem ppsi);
        void GetCurrentSelection(out IShellItem ppsi);
        void SetFileName([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetFileName([MarshalAs(UnmanagedType.LPWStr)] out string pszName);
        void SetTitle([MarshalAs(UnmanagedType.LPWStr)] string pszTitle);
        void SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string pszText);
        void SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string pszLabel);
        void GetResult(out IShellItem ppsi);
        void AddPlace(IShellItem psi, int fdap);
        void SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string pszDefaultExtension);
        void Close(int hr);
        void SetClientGuid(ref Guid guid);
        void ClearClientData();
        void SetFilter(IntPtr pFilter);
        void GetResults(out IntPtr ppenum);
        void GetSelectedItems(out IntPtr ppsai);
    }

    public static class FolderPicker
    {
        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        static extern int SHCreateItemFromParsingName([MarshalAs(UnmanagedType.LPWStr)] string pszPath, IntPtr pbc,
            [In] ref Guid riid, [MarshalAs(UnmanagedType.Interface)] out IShellItem ppv);

        public static string Pick(string title, string initial)
        {
            string result = null;
            Exception error = null;
            Thread t = new Thread(delegate ()
            {
                try { result = PickSta(title, initial); } catch (Exception ex) { error = ex; }
            });
            t.SetApartmentState(ApartmentState.STA);
            t.Start();
            t.Join();
            if (error != null) throw error;
            return result;
        }

        static string PickSta(string title, string initial)
        {
            // Fenetre proprietaire invisible et "au premier plan" : sans elle, la boite
            // de dialogue s'ouvre souvent DERRIERE le navigateur.
            Form owner = new Form();
            owner.ShowInTaskbar = false;
            owner.FormBorderStyle = FormBorderStyle.None;
            owner.StartPosition = FormStartPosition.Manual;
            owner.Opacity = 0;
            owner.TopMost = true;
            System.Drawing.Rectangle wa = Screen.PrimaryScreen.WorkingArea;
            owner.Bounds = new System.Drawing.Rectangle(wa.Left + wa.Width / 2, wa.Top + wa.Height / 3, 1, 1);
            owner.Show();
            owner.Activate();

            IFileOpenDialog dlg = (IFileOpenDialog)new FileOpenDialogRCW();
            try
            {
                uint opts;
                dlg.GetOptions(out opts);
                dlg.SetOptions(opts | 0x20 | 0x40 | 0x800); // PICKFOLDERS | FORCEFILESYSTEM | PATHMUSTEXIST
                dlg.SetTitle(title);
                if (!string.IsNullOrEmpty(initial) && Directory.Exists(initial))
                {
                    IShellItem start;
                    Guid iid = typeof(IShellItem).GUID;
                    if (SHCreateItemFromParsingName(initial, IntPtr.Zero, ref iid, out start) == 0) dlg.SetFolder(start);
                }
                if (dlg.Show(owner.Handle) != 0) return null; // annule
                IShellItem item;
                dlg.GetResult(out item);
                string path;
                item.GetDisplayName(0x80058000, out path); // SIGDN_FILESYSPATH
                return path;
            }
            finally
            {
                Marshal.ReleaseComObject(dlg);
                owner.Close();
                owner.Dispose();
            }
        }
    }
}
'@

if (-not ('YtdlpStudio.JobQueue' -as [type])) {
    Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Windows.Forms, System.Drawing
}

# ============================================================================
#  Reglages persistants (settings.json a cote du script)
# ============================================================================
$Profiles = @('maxcompat', 'best', '2160', '1440', '1080', 'hap', 'hapq', 'mp3', 'frames')
$Browsers = @('firefox', 'chrome', 'edge', 'brave', 'chromium', 'opera', 'vivaldi')

function New-DefaultSettings {
    return [ordered]@{
        dest       = $DefaultDest
        profile    = 'maxcompat'
        playlist   = $false
        groupBatch = $true
        cookies    = $true
        browser    = 'firefox'
        ffmpeg     = ''
    }
}

function Read-Settings {
    $s = New-DefaultSettings
    if (Test-Path -LiteralPath $SettingsPath) {
        try {
            $j = [IO.File]::ReadAllText($SettingsPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
            foreach ($k in @($s.Keys)) {
                if ($null -ne $j.PSObject.Properties[$k]) { $s[$k] = $j.$k }
            }
        } catch {
            Log 'settings.json illisible : reglages par defaut.'
        }
    }
    return $s
}

function Save-Settings($s) {
    [IO.File]::WriteAllText($SettingsPath, (ConvertTo-Json -InputObject $s), (New-Object Text.UTF8Encoding $false))
}

# Fusionne les options recues du navigateur dans les reglages, avec validation.
function Merge-Options($settings, $body) {
    $s = [ordered]@{}
    foreach ($k in $settings.Keys) { $s[$k] = $settings[$k] }
    if ($null -eq $body) { return $s }
    $p = $body.PSObject.Properties
    if ($p['dest'])  { $s.dest = ([string]$body.dest).Trim().Trim('"') }
    if ($p['profile'] -and ($Profiles -contains [string]$body.profile)) { $s.profile = [string]$body.profile }
    if ($p['browser'] -and ($Browsers -contains [string]$body.browser)) { $s.browser = [string]$body.browser }
    if ($p['playlist'])   { $s.playlist = [bool]$body.playlist }
    if ($p['groupBatch']) { $s.groupBatch = [bool]$body.groupBatch }
    if ($p['cookies'])    { $s.cookies = [bool]$body.cookies }
    if ($p['ffmpeg'])     { $s.ffmpeg = ([string]$body.ffmpeg).Trim().Trim('"') }
    return $s
}

function Test-DestPath([string]$dest) {
    if (-not $dest) { return 'Choisissez un dossier de destination.' }
    if ($dest.IndexOfAny([IO.Path]::GetInvalidPathChars()) -ge 0) { return 'Chemin de destination invalide.' }
    try { if (-not [IO.Path]::IsPathRooted($dest)) { return 'Le dossier doit etre un chemin complet (ex. D:\Videos).' } }
    catch { return 'Chemin de destination invalide.' }
    return $null
}

# ============================================================================
#  Construction des commandes yt-dlp
# ============================================================================
function Get-FormatAvoidAv1([string]$cap) {
    # Prefere H.264, puis VP9 - pas AV1 (souvent 403 CDN).
    if ($cap -eq 'best') { return 'bv*[vcodec^=avc1]+ba[acodec^=mp4a]/bv*[vcodec!=av01]+ba/b' }
    return "bv*[vcodec^=avc1][height<=$cap]+ba[acodec^=mp4a]/bv*[vcodec!=av01][height<=$cap]+ba/b[height<=$cap]/b[height<=$cap]"
}

function Get-BaseArgs($s) {
    $a = New-Object 'System.Collections.Generic.List[string]'
    if ($s.ffmpeg) { $a.Add('--ffmpeg-location'); $a.Add($s.ffmpeg) }

    # Anti-403 YouTube (sept. 2026) : client tv + cookies, Deno pour les challenges JS.
    # Voir yt-dlp#17348 / #17456 : default -> visionos/android_vr exigent un PO token.
    foreach ($x in @('--js-runtimes', 'deno',
            '--extractor-args', 'youtube:player_client=tv,default,-android_vr,-visionos',
            '--retries', '10', '--fragment-retries', '10', '--retry-sleep', 'fragment:linear=1:8')) { $a.Add($x) }
    if ($s.cookies) { $a.Add('--cookies-from-browser'); $a.Add($s.browser) }

    switch ($s.profile) {
        'mp3' {
            foreach ($x in @('-f', 'bestaudio', '-x', '--audio-format', 'mp3', '--audio-quality', '0')) { $a.Add($x) }
        }
        { $_ -eq 'hap' -or $_ -eq 'hapq' } {
            $fmt = if ($s.profile -eq 'hapq') { 'hap_q' } else { 'hap' }
            foreach ($x in @('-f', (Get-FormatAvoidAv1 'best'), '--recode-video', 'mov',
                    '--postprocessor-args', "VideoConvertor:-c:v hap -format $fmt -c:a pcm_s16le")) { $a.Add($x) }
        }
        'maxcompat' {
            foreach ($x in @('-f', 'bv*[vcodec^=avc1][height<=1080]+ba[acodec^=mp4a]/b[ext=mp4][height<=1080]/bv*[height<=1080][vcodec!=av01]+ba/b[height<=1080]/b',
                    '--merge-output-format', 'mp4')) { $a.Add($x) }
        }
        'frames' {
            # Video <=1080p puis extraction PNG via extract-frames.bat (sur le PATH)
            foreach ($x in @('-f', (Get-FormatAvoidAv1 '1080'), '--merge-output-format', 'mp4',
                    '--exec', 'extract-frames.bat %(filepath)q')) { $a.Add($x) }
        }
        default {
            foreach ($x in @('-f', (Get-FormatAvoidAv1 $s.profile), '--merge-output-format', 'mp4')) { $a.Add($x) }
        }
    }
    return , $a
}

# Lignes machine lues par JobQueue.OnLine (progression, debut d'element, fichier fini).
$UiArgs = @(
    '--newline', '--color', 'never',
    '--progress-template', 'download:@@P|%(progress.downloaded_bytes)s|%(progress.total_bytes)s|%(progress.total_bytes_estimate)s|%(progress.speed)s|%(progress.eta)s',
    '--print', 'before_dl:@@T|%(playlist_index|)s|%(n_entries|)s|%(title)s',
    '--print', 'after_move:@@F|%(filepath)s',
    '--no-quiet', '--progress'   # --print active --quiet : on garde le journal et la barre
)

function Test-PlaylistUrl([Uri]$u, [bool]$force) {
    $hostName = $u.Host.ToLowerInvariant()
    $path = $u.AbsolutePath
    $hasList = $u.Query -match '(^\?|&)list=[^&]+'
    if ($hostName -match '(^|\.)(youtube\.com|youtube-nocookie\.com|youtu\.be)$') {
        if ($path -match '^/playlist/?$' -and $hasList) { return $true }
        if ($path -match '^/(@[^/]+|channel/[^/]+|c/[^/]+|user/[^/]+)(/(videos|shorts|streams|playlists))?/?$') { return $true }
        # watch?v=...&list=... : la video seule, sauf si "playlist entiere" est coche
        return ($hasList -and $force)
    }
    if ($path -match '/(sets|album|showcase|playlist|playlists)(/|$)') { return $true }
    return $force
}

function ConvertTo-SafeFolderName([string]$name) {
    $n = ($name -replace '[<>:"/\\|?*\x00-\x1F]', ' ') -replace '\s+', ' '
    $n = $n.Trim().TrimEnd('.').Trim()
    if ($n.Length -gt 80) { $n = $n.Substring(0, 80).Trim() }
    return $n
}

# Decoupe les liens en travaux : 1 travail par playlist (dans son propre dossier)
# + 1 travail pour les videos seules (dans un sous-dossier "Lot" s'il y en a plusieurs).
function New-DownloadPlan($s, $body, [bool]$forUi) {
    $plan = @{ jobs = New-Object System.Collections.ArrayList; rejected = New-Object System.Collections.ArrayList; error = $null }

    $destErr = Test-DestPath $s.dest
    if ($destErr) { $plan.error = $destErr; return $plan }
    if ($s.ffmpeg -and -not (Test-Path -LiteralPath $s.ffmpeg)) { $plan.error = 'FFmpeg introuvable au chemin indique.'; return $plan }

    $singles = New-Object System.Collections.ArrayList
    $playlists = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($raw in @($body.urls)) {
        $line = ([string]$raw).Trim()
        if (-not $line) { continue }
        $u = $null
        if (-not [Uri]::TryCreate($line, [UriKind]::Absolute, [ref]$u) -or ($u.Scheme -ne 'http' -and $u.Scheme -ne 'https') -or ($line -match '\s')) {
            [void]$plan.rejected.Add($line); continue
        }
        if ($seen.ContainsKey($line)) { continue }
        $seen[$line] = $true
        if (Test-PlaylistUrl $u $s.playlist) { [void]$playlists.Add($line) } else { [void]$singles.Add($line) }
    }

    $base = Get-BaseArgs $s
    $frames = ($s.profile -eq 'frames')

    foreach ($url in $playlists) {
        $a = New-Object 'System.Collections.Generic.List[string]' (, $base)
        $tmpl = if ($frames) { '%(playlist_title,playlist_id|Playlist)s/%(playlist_index)s - %(title)s/%(title)s.%(ext)s' }
                else { '%(playlist_title,playlist_id|Playlist)s/%(playlist_index)s - %(title)s.%(ext)s' }
        foreach ($x in @('--yes-playlist', '-P', $s.dest, '-o', $tmpl)) { $a.Add($x) }
        if ($forUi) { $a.AddRange([string[]]$UiArgs) }
        $a.Add('--'); $a.Add($url)
        [void]$plan.jobs.Add(@{ kind = 'playlist'; label = $url; dir = $s.dest; count = 0; urls = @($url); args = $a.ToArray() })
    }

    if ($singles.Count -gt 0) {
        $dir = $s.dest
        $kind = 'single'
        if ($singles.Count -ge 2 -and $s.groupBatch) {
            $name = ''
            if ($body.PSObject.Properties['batchName']) { $name = ConvertTo-SafeFolderName ([string]$body.batchName) }
            if (-not $name) { $name = 'Lot ' + (Get-Date -Format 'yyyy-MM-dd HH\hmm') }
            $dir = Join-Path $s.dest $name
            $kind = 'batch'
        }
        $a = New-Object 'System.Collections.Generic.List[string]' (, $base)
        $tmpl = if ($frames) { '%(title)s/%(title)s.%(ext)s' } else { '%(title)s.%(ext)s' }
        foreach ($x in @('--no-playlist', '-P', $dir, '-o', $tmpl)) { $a.Add($x) }
        if ($forUi) { $a.AddRange([string[]]$UiArgs) }
        $a.Add('--')
        foreach ($url in $singles) { $a.Add($url) }
        $label = if ($singles.Count -eq 1) { $singles[0] } else { "$($singles.Count) liens" }
        [void]$plan.jobs.Add(@{ kind = $kind; label = $label; dir = $dir; count = $singles.Count; urls = @($singles); args = $a.ToArray() })
    }
    return $plan
}

# ============================================================================
#  HTTP
# ============================================================================
function Send-Bytes($ctx, [int]$code, [byte[]]$bytes, [string]$type) {
    $res = $ctx.Response
    $res.StatusCode = $code
    $res.ContentType = $type
    $res.Headers['Cache-Control'] = 'no-store'
    $res.Headers['X-Content-Type-Options'] = 'nosniff'
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.OutputStream.Close()
}

function Send-Json($ctx, [int]$code, $obj) {
    $json = ConvertTo-Json -InputObject $obj -Depth 8 -Compress
    Send-Bytes $ctx $code ([Text.Encoding]::UTF8.GetBytes($json)) 'application/json; charset=utf-8'
}

function Read-JsonBody($ctx) {
    $sr = New-Object IO.StreamReader($ctx.Request.InputStream, [Text.Encoding]::UTF8)
    $text = $sr.ReadToEnd()
    $sr.Close()
    if (-not $text.Trim()) { return [pscustomobject]@{} }
    return ($text | ConvertFrom-Json)
}

function Get-State {
    $s = $script:Settings
    return @{
        app      = 'yt-dlp-studio'
        updating = $Queue.Paused
        settings = $s
        defaultDest = $DefaultDest
        destExists  = [bool]($s.dest -and [IO.Directory]::Exists($s.dest))
        jobs     = $Queue.Snapshot()
    }
}

function Invoke-Api($ctx, [string]$path) {
    switch ($path) {
        '/api/state' {
            Send-Json $ctx 200 (Get-State)
        }
        '/api/settings' {
            $body = Read-JsonBody $ctx
            $script:Settings = Merge-Options $script:Settings $body
            Save-Settings $script:Settings
            Send-Json $ctx 200 (Get-State)
        }
        '/api/preview' {
            $body = Read-JsonBody $ctx
            $s = Merge-Options $script:Settings $body
            $plan = New-DownloadPlan $s $body $false
            $jobs = @()
            foreach ($j in $plan.jobs) {
                $jobs += @{ kind = $j.kind; label = $j.label; dir = $j.dir; count = $j.count
                    command = 'yt-dlp ' + [YtdlpStudio.JobQueue]::JoinArgsForCmd($j.args) }
            }
            Send-Json $ctx 200 @{ error = $plan.error; rejected = @($plan.rejected); jobs = $jobs }
        }
        '/api/download' {
            $body = Read-JsonBody $ctx
            $script:Settings = Merge-Options $script:Settings $body
            $plan = New-DownloadPlan $script:Settings $body $true
            if ($plan.error) { Send-Json $ctx 400 @{ error = $plan.error }; return }
            if ($plan.jobs.Count -eq 0) { Send-Json $ctx 400 @{ error = 'Aucun lien valide (http/https).' }; return }
            Save-Settings $script:Settings
            try { [void][IO.Directory]::CreateDirectory($script:Settings.dest) }
            catch { Send-Json $ctx 400 @{ error = 'Impossible de creer le dossier : ' + $_.Exception.Message }; return }
            $ids = @()
            foreach ($j in $plan.jobs) {
                $ids += $Queue.Add([string]$j.label, [string]$j.kind, [string]$j.dir, [string[]]$j.args, [int]$j.count)
            }
            Log ("File d'attente : +" + $ids.Count + ' travail(aux) -> ' + $script:Settings.dest)
            Send-Json $ctx 200 @{ ids = $ids; rejected = @($plan.rejected) }
        }
        '/api/pick-folder' {
            $body = Read-JsonBody $ctx
            $start = if ($body.PSObject.Properties['start']) { [string]$body.start } else { $script:Settings.dest }
            try {
                $picked = [YtdlpStudio.FolderPicker]::Pick('Dossier de destination des telechargements', $start)
                Send-Json $ctx 200 @{ path = $picked }
            } catch {
                Send-Json $ctx 500 @{ error = 'Selecteur indisponible : ' + $_.Exception.Message }
            }
        }
        '/api/open' {
            # Ouvre un dossier (ou selectionne un fichier) dans l'Explorateur.
            $body = Read-JsonBody $ctx
            $p = ([string]$body.path).Trim()
            if ($p -and [IO.Directory]::Exists($p)) {
                Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $p + '"')
                Send-Json $ctx 200 @{ ok = $true }
            } elseif ($p -and [IO.File]::Exists($p)) {
                Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"' + $p + '"')
                Send-Json $ctx 200 @{ ok = $true }
            } else {
                Send-Json $ctx 404 @{ error = "Ce dossier n'existe pas (encore)." }
            }
        }
        '/api/cancel' {
            $body = Read-JsonBody $ctx
            Send-Json $ctx 200 @{ ok = $Queue.Cancel([int]$body.id) }
        }
        '/api/clear' {
            $Queue.ClearFinished()
            Send-Json $ctx 200 (Get-State)
        }
        '/api/quit' {
            $Queue.CancelAll()
            Send-Json $ctx 200 @{ ok = $true }
            $script:Quit = $true
        }
        default { Send-Json $ctx 404 @{ error = 'not found' } }
    }
}

function Invoke-Request($ctx) {
    $req = $ctx.Request
    $path = $req.Url.AbsolutePath

    # Anti DNS rebinding : seul un Host local est accepte.
    $hostHeader = [string]$req.Headers['Host']
    if ($hostHeader -notmatch ('^(127\.0\.0\.1|localhost):' + $Port + '$')) {
        Send-Json $ctx 403 @{ error = 'forbidden' }; return
    }

    if ($path -eq '/api/ping') { Send-Json $ctx 200 @{ app = 'yt-dlp-studio' }; return }

    if ($req.HttpMethod -eq 'GET' -and ($path -eq '/' -or $path -eq '/index.html')) {
        $html = [IO.File]::ReadAllText((Join-Path $Root 'index.html'), [Text.Encoding]::UTF8)
        $html = $html.Replace('__STUDIO_TOKEN__', $Token)
        Send-Bytes $ctx 200 ([Text.Encoding]::UTF8.GetBytes($html)) 'text/html; charset=utf-8'
        return
    }
    if ($req.HttpMethod -eq 'GET' -and $path -eq '/favicon.ico') {
        $ico = Join-Path $Root 'assets\yt-dlp-studio.ico'
        if (Test-Path -LiteralPath $ico) { Send-Bytes $ctx 200 ([IO.File]::ReadAllBytes($ico)) 'image/x-icon' }
        else { Send-Json $ctx 404 @{ error = 'not found' } }
        return
    }

    if ($path.StartsWith('/api/')) {
        # Jeton obligatoire : un site tiers ne peut ni le lire ni envoyer d'en-tete
        # personnalise sans pre-requete CORS (a laquelle on ne repond jamais).
        if ([string]$req.Headers['X-Studio-Token'] -cne $Token) {
            Send-Json $ctx 403 @{ error = 'jeton invalide - rechargez la page' }; return
        }
        if ($path -ne '/api/state' -and $req.HttpMethod -ne 'POST') {
            Send-Json $ctx 405 @{ error = 'POST attendu' }; return
        }
        Invoke-Api $ctx $path
        return
    }

    Send-Json $ctx 404 @{ error = 'not found' }
}

# ============================================================================
#  Demarrage
# ============================================================================
Write-Host ''
Write-Host '============================================================'
Write-Host '   yt-dlp Studio - serveur local'
Write-Host "   $BaseUrl"
Write-Host '   Laissez cette fenetre ouverte (reduite) pendant les telechargements.'
Write-Host '   La fermer arrete le serveur.'
Write-Host '============================================================'
Write-Host ''

$Settings = Read-Settings
$pathEnv = $Bin + ';' + $Root + ';' + $env:PATH

# Verification des outils (1x / 12h) en arriere-plan : la file reste en pause
# tant que update.ps1 peut remplacer yt-dlp.exe.
$UpdateProc = $null
$updateScript = Join-Path $Root 'update.ps1'
if (-not $NoUpdate -and (Test-Path -LiteralPath $updateScript)) {
    $UpdateProc = Start-Process -FilePath 'powershell.exe' -NoNewWindow -PassThru -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $updateScript + '"'), '-Auto')
}
$Queue = New-Object YtdlpStudio.JobQueue($Ytdlp, $Root, $pathEnv, ($null -ne $UpdateProc))

$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add($BaseUrl)
try {
    $Listener.Start()
} catch {
    Log "Impossible d'ecouter sur le port $Port : $($_.Exception.Message)"
    Log 'Un autre programme utilise peut-etre ce port.'
    Read-Host 'Entree pour fermer'
    exit 1
}

Log 'Pret.'
Open-Ui

$Quit = $false
try {
    while ($Listener.IsListening -and -not $Quit) {
        $task = $Listener.GetContextAsync()
        while (-not $task.AsyncWaitHandle.WaitOne(250)) {
            if ($UpdateProc -and $UpdateProc.HasExited) {
                $UpdateProc = $null
                $Queue.Resume()
                Log 'Outils verifies - file d''attente active.'
            }
        }
        $ctx = $task.GetAwaiter().GetResult()
        try {
            Invoke-Request $ctx
        } catch {
            Log ('Erreur requete ' + $ctx.Request.Url.AbsolutePath + ' : ' + $_.Exception.Message)
            try { Send-Json $ctx 500 @{ error = $_.Exception.Message } } catch {}
        }
    }
} finally {
    $Queue.CancelAll()
    $Listener.Stop()
    $Listener.Close()
    Log 'Serveur arrete.'
}
