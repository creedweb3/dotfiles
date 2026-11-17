pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory, GPU, disks, network and uptime, read from /proc, /sys, nvidia-smi (or amdgpu
// sysfs) and df. CPU and memory always update (the bar shows them); the rest only while `detail`
// is set (the quick panel is open), so a closed panel costs nothing. The system tab's detail
// views (`view`: cpu, mem, gpu, disk, net) add per-thread clocks, top processes, the largest
// folders in ~ and the network address, again only while that view is open.
// Disks are also checked once a minute: one notification when one passes 95%, whose click opens
// the disk view (`qs -c rice ipc call panel system disk` does the same).
Singleton {
    id: root

    property bool detail: false
    property string view: ""      // system tab detail view: "", cpu, mem, gpu, disk, net
    readonly property int interval: 2000
    readonly property int histLength: 60

    property int cpu: 0
    property var cpuHist: []
    property var cores: []        // per thread, %
    property var coreMHz: []      // per thread, from /proc/cpuinfo
    property string cpuName: ""
    property int threads: 0
    property int cpuTemp: -1
    property int mem: 0
    property real memUsed: 0      // GiB
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real memCache: 0     // GiB: page cache and reclaimable slab
    property var topCpu: []       // [[name, "12.4%"]], cpu view
    property var topMem: []       // [[name, "2.1 GiB"]], mem view
    property string load: "0.00"
    property int uptime: 0        // seconds
    property string kernel: ""

    property bool hasGpu: true    // false once neither nvidia-smi nor an amdgpu card answers
    property string gpuKind: "nvidia"   // nvidia, then amd once nvidia-smi fails
    property string gpuName: ""
    property int gpu: 0
    property int gpuTemp: -1
    property real vramUsed: 0     // GiB
    property real vramTotal: 0
    property int gpuFan: -1       // %, -1 = unknown
    property real gpuPower: -1    // W
    property real gpuPowerMax: -1
    property int gpuClock: -1     // MHz

    property real down: 0         // MB/s
    property real up: 0
    property var netHist: []
    property var disks: []        // [{ mount, used, size }] in GiB
    property var bigDirs: []      // [[name, "310 GiB"]], disk view; measured once per opening
    property bool measuring: false
    property var netInfo: ({})    // { iface, ip }, net view
    property var warned: []       // mounts already warned about (until they drop below 90%)

    property var lastCpu: null
    property var lastCores: []
    property var lastNet: null

    function push(list, v) {
        const out = list.concat([v]);
        return out.length > histLength ? out.slice(out.length - histLength) : out;
    }

    // one /proc/stat line -> { idle, total } jiffies
    function jiffies(line) {
        const f = line.trim().split(/\s+/).slice(1, 9).map(Number);
        return { idle: f[3] + f[4], total: f.reduce((a, b) => a + b, 0) };
    }
    function busy(now, last) {
        return last && now.total > last.total ? Math.round(100 * (1 - (now.idle - last.idle) / (now.total - last.total))) : 0;
    }

    function readCpu(text) {
        const lines = text.split("\n");
        const all = jiffies(lines[0]);
        if (lastCpu && all.total > lastCpu.total)
            cpu = busy(all, lastCpu);
        lastCpu = all;
        cpuHist = push(cpuHist, cpu);
        // per thread: cpu0, cpu1, ...
        const per = lines.filter(l => /^cpu\d+ /.test(l)).map(jiffies);
        cores = per.map((j, i) => busy(j, lastCores[i]));
        lastCores = per;
    }

    function readMem(text) {
        const kv = {};
        for (const l of text.split("\n")) {
            const m = l.match(/^(\w+):\s+(\d+)/);
            if (m)
                kv[m[1]] = Number(m[2]) / 1048576;
        }
        memTotal = kv.MemTotal || 0;
        memUsed = memTotal - (kv.MemAvailable || 0);
        mem = memTotal > 0 ? Math.round(memUsed / memTotal * 100) : 0;
        swapTotal = kv.SwapTotal || 0;
        swapUsed = swapTotal - (kv.SwapFree || 0);
        memCache = (kv.Cached || 0) + (kv.Buffers || 0) + (kv.SReclaimable || 0);
    }

    function readNet(text) {
        let rx = 0, tx = 0;
        for (const l of text.split("\n").slice(2)) {
            const [name, rest] = l.split(":");
            if (!rest || name.trim() === "lo")
                continue;
            const f = rest.trim().split(/\s+/).map(Number);
            rx += f[0];
            tx += f[8];
        }
        const now = Date.now();
        if (lastNet) {
            const s = (now - lastNet.t) / 1000;
            down = Math.max(0, (rx - lastNet.rx) / s / 1e6);
            up = Math.max(0, (tx - lastNet.tx) / s / 1e6);
        }
        lastNet = { rx, tx, t: now };
        netHist = push(netHist, down);
    }

    FileView { id: statFile; path: "/proc/stat"; onLoaded: root.readCpu(text()) }
    FileView { id: memFile; path: "/proc/meminfo"; onLoaded: root.readMem(text()) }
    FileView { id: netFile; path: "/proc/net/dev"; onLoaded: root.readNet(text()) }
    FileView { id: loadFile; path: "/proc/loadavg"; onLoaded: root.load = text().split(" ")[0] }
    FileView { id: upFile; path: "/proc/uptime"; onLoaded: root.uptime = Math.floor(parseFloat(text())) }
    FileView {
        id: tempFile
        printErrors: false
        onLoaded: root.cpuTemp = Math.round(parseInt(text()) / 1000)
    }
    FileView {
        id: cpuinfoFile
        path: "/proc/cpuinfo"
        onLoaded: {
            const t = text();
            root.coreMHz = (t.match(/^cpu MHz\s*:\s*[\d.]+/gm) || []).map(l => parseFloat(l.split(":")[1]));
            const m = t.match(/model name\s*:\s*(.+)/);
            root.cpuName = m ? m[1].replace(/\(R\)|\(TM\)|CPU|\d+-Core Processor|Processor/g, "").replace(/@.*/, "").replace(/\s+/g, " ").trim() : "";
            root.threads = (t.match(/^processor\s*:/gm) || []).length;
        }
    }

    // CPU temperature sensor: k10temp (AMD), coretemp (Intel) or zenpower.
    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do case $(cat $d/name) in k10temp|coretemp|zenpower) echo $d/temp1_input; exit;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: tempFile.path = text.trim()
        }
    }

    Process {
        running: true
        command: ["uname", "-r"]
        stdout: StdioCollector {
            onStreamFinished: root.kernel = text.trim()
        }
    }

    Process {
        id: gpuProc
        command: ["nvidia-smi", "--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,fan.speed,power.draw,power.limit,clocks.gr", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.split("\n")[0].split(",").map(s => s.trim());
                if (f.length < 5)
                    return;
                const num = (s, d) => isFinite(parseFloat(s)) ? parseFloat(s) : d;   // "[N/A]" on some cards
                root.gpuName = f[0].replace(/NVIDIA |GeForce /g, "");
                root.gpu = num(f[1], 0);
                root.gpuTemp = num(f[2], -1);
                root.vramUsed = num(f[3], 0) / 1024;
                root.vramTotal = num(f[4], 0) / 1024;
                root.gpuFan = Math.round(num(f[5], -1));
                root.gpuPower = num(f[6], -1);
                root.gpuPowerMax = num(f[7], -1);
                root.gpuClock = Math.round(num(f[8], -1));
            }
        }
        onExited: code => {
            if (code !== 0)
                root.gpuKind = "amd";
        }
    }

    // AMD: amdgpu's sysfs files. Prints "busy vram_used vram_total temp_mC clock_MHz name", or
    // nothing when there is no amdgpu card (then the gpu card says so).
    Process {
        id: amdProc
        command: ["sh", "-c", "for d in /sys/class/drm/card*/device; do [ -r \"$d/gpu_busy_percent\" ] || continue; "
            + "h=$(ls -d \"$d\"/hwmon/hwmon* 2>/dev/null | head -n 1); "
            + "clk=$(sed -n 's/^[0-9]*: \\([0-9]*\\)Mhz \\*$/\\1/p' \"$d/pp_dpm_sclk\" 2>/dev/null); "
            + "echo \"$(cat \"$d/gpu_busy_percent\") $(cat \"$d/mem_info_vram_used\" 2>/dev/null || echo 0) $(cat \"$d/mem_info_vram_total\" 2>/dev/null || echo 0) "
            + "$(cat \"$h/temp1_input\" 2>/dev/null || echo -1000) ${clk:--1} $(cat \"$d/product_name\" 2>/dev/null || echo AMD GPU)\"; exit; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(" ");
                if (f.length < 6) {
                    root.hasGpu = false;
                    return;
                }
                root.gpu = parseInt(f[0]) || 0;
                root.vramUsed = Number(f[1]) / 1073741824;
                root.vramTotal = Number(f[2]) / 1073741824;
                root.gpuTemp = Number(f[3]) > -1000 ? Math.round(Number(f[3]) / 1000) : -1;
                root.gpuClock = parseInt(f[4]);
                root.gpuName = f.slice(5).join(" ").replace(/AMD |Radeon /g, "");
            }
        }
    }

    Process {
        id: diskProc
        command: ["df", "-B1", "--output=target,used,size", "/", "/home"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = new Set(), out = [];
                for (const l of text.trim().split("\n").slice(1)) {
                    const [mount, used, size] = l.trim().split(/\s+/);
                    if (seen.has(mount))
                        continue;
                    seen.add(mount);
                    out.push({ mount, used: Number(used) / 1073741824, size: Number(size) / 1073741824 });
                }
                root.disks = out;
                root.checkDisks();
            }
        }
    }

    // ---- disk warning: one notification per mount when it passes 95%, again only after it
    // has dropped below 90%. Clicking it (the rice daemon: the default action) opens the disk view.
    function checkDisks() {
        let w = warned.slice();
        for (const d of disks) {
            const pc = d.size > 0 ? d.used / d.size * 100 : 0;
            if (pc < 90)
                w = w.filter(m => m !== d.mount);
            else if (pc >= 95 && w.indexOf(d.mount) < 0 && !warnProc.running) {
                w.push(d.mount);
                warnProc.command = ["notify-send", "-a", "rice", "-u", "critical", "-A", "default=open",
                    "disk almost full", d.mount + " is " + Math.round(pc) + "% full · " + Math.round(d.size - d.used) + " GiB left"];
                warnProc.running = true;
            }
        }
        warned = w;
    }
    function openView(v) {
        view = "";   // so opening the same view again measures again
        view = v;
        Popup.open("panel", "system");
    }

    // notify-send -A waits for the notification to close and prints the action that was clicked
    Process {
        id: warnProc
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() === "default") root.openView("disk")
        }
    }

    // ---- detail views
    // top processes, summed per name so twenty browser processes show as one row
    Process {
        id: topProc
        property string sort: "cpu"
        // the name goes last: it may hold spaces ("Web Content"), so it is fields 3 to the end
        command: ["sh", "-c", "ps -eo %cpu=,rss=,comm= | awk '{n=$3; for (i=4; i<=NF; i++) n=n\" \"$i; c[n]+=$1; m[n]+=$2} END {for (n in c) print c[n], m[n], n}' | sort -k" + (sort === "cpu" ? "1" : "2") + " -rn | head -n 6"]
        stdout: StdioCollector {
            onStreamFinished: {
                // each row: cpu rss name...
                const rows = text.trim().split("\n").filter(x => x).map(l => {
                    const f = l.split(" ");
                    return [f.slice(2).join(" "), Number(f[0]), Number(f[1])];
                });
                if (topProc.sort === "cpu")
                    root.topCpu = rows.map(r => [r[0], r[1].toFixed(1) + "%"]);
                else
                    root.topMem = rows.map(r => [r[0], root.fmtKiB(r[2])]);
            }
        }
    }
    // largest folders in ~ (one level, this file system only); slow on a big home, so once per opening
    Process {
        id: duProc
        command: ["sh", "-c", "du -x -d 1 -k \"$HOME\" 2>/dev/null | sort -rn | sed 1d | head -n 6"]
        stdout: StdioCollector {
            onStreamFinished: {
                const home = Quickshell.env("HOME");
                root.bigDirs = text.trim().split("\n").filter(x => x).map(l => {
                    const m = /^(\d+)\s+(.*)$/.exec(l);
                    return m ? [m[2].replace(home, "~"), root.fmtKiB(Number(m[1]))] : null;
                }).filter(x => x);
                root.measuring = false;
            }
        }
    }
    // network: the interface carrying the default route, and its address
    Process {
        id: netProc
        command: ["sh", "-c", "ip -4 -o route get 1.1.1.1 2>/dev/null | sed -n 's/.* dev \\([^ ]*\\).* src \\([^ ]*\\).*/\\1 \\2/p'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(" ");
                root.netInfo = f.length === 2 ? { iface: f[0], ip: f[1] } : {};
            }
        }
    }
    onViewChanged: {
        if (view === "disk" && !duProc.running) {
            measuring = true;
            duProc.running = true;
        }
        if (view === "net" && !netProc.running)
            netProc.running = true;
    }

    function fmtKiB(k) {
        return k >= 1048576 ? (k / 1048576).toFixed(1) + " GiB" : Math.round(k / 1024) + " MiB";
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: root.interval
        onTriggered: {
            statFile.reload();
            memFile.reload();
            if (!root.detail)
                return;
            netFile.reload();
            loadFile.reload();
            upFile.reload();
            if (tempFile.path)
                tempFile.reload();
            if (root.hasGpu && root.gpuKind === "nvidia" && !gpuProc.running)
                gpuProc.running = true;
            if (root.hasGpu && root.gpuKind === "amd" && !amdProc.running)
                amdProc.running = true;
            if (!diskProc.running)
                diskProc.running = true;
            if (root.view === "cpu")
                cpuinfoFile.reload();
            if ((root.view === "cpu" || root.view === "mem") && !topProc.running) {
                topProc.sort = root.view;
                topProc.running = true;
            }
        }
    }

    // disks also while the panel is closed, for the 95% warning (df is cheap)
    Timer {
        running: true
        repeat: true
        interval: 60000
        onTriggered: if (!diskProc.running) diskProc.running = true
    }

    function fmtUptime(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d ? d + "d " : "") + (d || h ? h + "h " : "") + m + "m";
    }
}
