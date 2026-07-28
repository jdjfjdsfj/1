import QtQuick 2.15
import QtQuick.LocalStorage 2.0

Rectangle {
    id: root
    width: 320; height: 170; color: "#1a1a2e"

    signal backButtonClicked()

    property var sh: shellPluginController
    property bool ok: false
    property var s: ({ cpu: {u:-1,l:""}, mem: {t:0,a:0,u:-1}, disk: [],
        bat: {c:-1,st:"",v:0,cur:0,tmp:0,h:"",cf:0},
        emmc: {lta:"",lt:"",pe:"",nm:"",fw:"",w:-1},
        up: {up:0,id:0}, tmp: {soc:0} })
    property bool hd: false
    property bool rfsh: false
    property real bh: 100; property real rf: 980000
    property string trend: "→"; property int cyc: 0

    readonly property color c1: "#16213e"; readonly property color hl: "#e94560"
    readonly property color gr: "#4ecca3"; readonly property color yl: "#f0c040"
    readonly property color t1: "#eee"; readonly property color t2: "#aab"

    // === INIT ===
    Timer { id:tInit; interval:300; repeat:false; onTriggered:{
        try{sh.stopShell()}catch(e){}
        tStart.start()
    }}
    Timer { id:tStart; interval:600; repeat:false; onTriggered:{
        try{sh.startShell()}catch(e){}
        tCmd.start()
    }}
    Timer { id:tCmd; interval:1000; repeat:false; onTriggered:{
        try{sh.clearOutput()}catch(e){}
        try{sh.sendCommand(
            "while true; do echo '===STATS_START==='; echo '===CPU==='; read r</proc/stat; echo cpu:$r; read r</proc/loadavg 2>/dev/null; echo loadavg:$r; echo '===MEM==='; cat /proc/meminfo 2>/dev/null; echo '===DISK==='; df -k / /userdisk /userdata /uresource 2>/dev/null; echo '===BATTERY==='; for f in capacity status voltage_now current_now temp health charge_full charge_counter; do p=/sys/class/power_supply/battery/$f; [ -f \"$p\" ] && echo \"$f:$(cat $p 2>/dev/null)\"; done; cat /sys/class/power_supply/battery/uevent 2>/dev/null; echo '===EMMC==='; [ -f /sys/kernel/debug/mmc1/mmc1:0001/ext_csd ] && echo life_time_a:0x$(cut -c 537-538 /sys/kernel/debug/mmc1/mmc1:0001/ext_csd 2>/dev/null); [ -f /sys/block/mmcblk1/device/life_time ] && echo \"life_time:$(cat /sys/block/mmcblk1/device/life_time 2>/dev/null)\"; [ -f /sys/block/mmcblk1/device/pre_eol_info ] && echo \"pre_eol:$(cat /sys/block/mmcblk1/device/pre_eol_info 2>/dev/null)\"; [ -f /sys/block/mmcblk1/device/name ] && echo \"name:$(cat /sys/block/mmcblk1/device/name 2>/dev/null)\"; [ -f /sys/block/mmcblk1/device/fwrev ] && echo \"fwrev:$(cat /sys/block/mmcblk1/device/fwrev 2>/dev/null)\"; echo '===UPTIME==='; cat /proc/uptime 2>/dev/null; echo '===TEMP==='; for tz in /sys/class/thermal/thermal_zone*/temp; do [ -f \"$tz\" ] && echo \"$(basename $(dirname $tz)):$(cat $tz 2>/dev/null)\"; done; echo '===STATS_END==='; sleep 2; done"
        )}catch(e){}
        ok=true; tPoll.start()
    }}

    Timer { id:tPoll; interval:2200; repeat:true; running:false; onTriggered:{
        if(!ok)return
        try{var t=sh.outputText; if(t&&t.length>0){parse(t); if(t.length>60000)sh.clearOutput()}}catch(e){}
    }}

    Timer { id:rfshTimer; interval:400; repeat:false; onTriggered:{ rfsh=false } }

    Component.onCompleted: { tInit.start() }
    Component.onDestruction: { try{sh.sendCommand("\x03")}catch(e){} }

    // === PARSE ===
    function kv(l){var i=l.indexOf(":");return i<0?null:{k:l.substring(0,i).trim(),v:l.substring(i+1).trim()}}
    function parse(raw){
        var bl=raw.split("===STATS_START===");if(bl.length<2)return
        var lb=bl[bl.length-1];var ei=lb.indexOf("===STATS_END===");if(ei<0)return
        lb=lb.substring(0,ei);var sec=lb.split("\n===")
        for(var i=0;i<sec.length;i++){var x=sec[i].trim();if(!x)continue;var ln=x.split("\n");var h=ln[0].replace(/^=+|=+$/g,"").trim()
            if(h==="CPU")pCpu(ln.slice(1));else if(h==="MEM")pMem(ln.slice(1));else if(h==="DISK")pDsk(ln.slice(1))
            else if(h==="BATTERY")pBat(ln.slice(1));else if(h==="EMMC")pEm(ln.slice(1))
            else if(h==="UPTIME")pUp(ln.slice(1));else if(h==="TEMP")pTm(ln.slice(1))}
        hd=s.cpu.u>=0;cBH()
        // Force QML to detect deep changes
        try{s=JSON.parse(JSON.stringify(s))}catch(e){}
    }
    function sp(v){return v.split(" ").filter(function(e){return e.length>0})}
    function pCpu(ln){for(var i=0;i<ln.length;i++){var x=kv(ln[i]);if(!x)continue;if(x.k==="cpu"){var v=x.v;if(v.indexOf("cpu ")==0)v=v.substring(4);else if(v.indexOf("cpu")==0)v=v.substring(3);var p=sp(v);if(p.length>=4){var idle=parseInt(p[3])||0;var t=0;for(var j=0;j<p.length&&j<8;j++)t+=parseInt(p[j])||0;s.cpu.u=t>0?Math.round((1-idle/t)*100):0}}else if(x.k==="loadavg")s.cpu.l=x.v}}
    function pMem(ln){for(var i=0;i<ln.length;i++){var x=kv(ln[i]);if(!x)continue;var v=parseInt(x.v)||0;if(x.k==="MemTotal")s.mem.t=v;else if(x.k==="MemAvailable")s.mem.a=v;else if(x.k==="SwapTotal")s.mem.st=v;else if(x.k==="SwapFree")s.mem.sf=v}if(s.mem.t>0)s.mem.u=Math.round((1-s.mem.a/s.mem.t)*100)}
    function pDsk(ln){var d=[];for(var i=0;i<ln.length;i++){var l=ln[i].trim();if(!l||l.indexOf("Filesystem")>=0||l.indexOf("1K")>=0)continue;var p=sp(l);if(p.length>=5)d.push({fs:p[0],sz:p[1],us:p[2],av:p[3],up:p[4].replace("%",""),mt:p.length>=6?p.slice(5).join(" "):""})}s.disk=d}
    function pBat(ln){var seen={};for(var i=0;i<ln.length;i++){var l=ln[i].trim();if(!l)continue;var x=kv(l);if(!x)continue;var k=x.k;if(k.indexOf("POWER_SUPPLY_")==0)k=k.substring(13).toLowerCase();else k=k.toLowerCase();if(seen[k])continue;seen[k]=true;var v=x.v;if(k==="capacity")s.bat.c=parseInt(v)||0;else if(k==="status")s.bat.st=v;else if(k==="voltage_now")s.bat.v=parseInt(v)||0;else if(k==="current_now")s.bat.cur=parseInt(v)||0;else if(k==="temp")s.bat.tmp=parseInt(v)||0;else if(k==="health")s.bat.h=v;else if(k==="charge_full")s.bat.cf=parseInt(v)||0}}
    function pEm(ln){for(var i=0;i<ln.length;i++){var x=kv(ln[i]);if(!x)continue;if(x.k==="life_time_a"){s.emmc.lta=x.v;var h=x.v.replace(/^0x/i,"");var n=parseInt(h,16);if(!isNaN(n)){if(n==0)s.emmc.w=0;else if(n>=1&&n<=10)s.emmc.w=(n-1)*10+5;else if(n>=11)s.emmc.w=100}}else if(x.k==="life_time")s.emmc.lt=x.v;else if(x.k==="pre_eol")s.emmc.pe=x.v;else if(x.k==="name")s.emmc.nm=x.v.trim();else if(x.k==="fwrev")s.emmc.fw=x.v.trim()}}
    function pUp(ln){for(var i=0;i<ln.length;i++){var p=sp(ln[i].trim());if(p.length>=2){s.up.up=parseFloat(p[0])||0;s.up.id=parseFloat(p[1])||0}}}
    function pTm(ln){for(var i=0;i<ln.length;i++){var x=kv(ln[i]);if(!x)continue;if(x.k.indexOf("thermal")>=0&&x.k.indexOf("thermal_zone")<0)s.tmp.soc=parseInt(x.v)||0}}
    function cBH(){var cf=s.bat.cf;if(cf<=0)return;if(cf>rf*1.05)rf=cf;if(rf<=0)rf=cf;bh=Math.min(100,Math.max(0,(cf/rf)*100));cyc=Math.round(Math.max(0,100-bh)*5)}

    function fK(k){return k>=1048576?(k/1048576).toFixed(1)+"G":k>=1024?(k/1024).toFixed(0)+"M":k+"K"}
    function fU(s){return s<60?Math.floor(s)+"s":s<3600?Math.floor(s/60)+"m"+Math.floor(s%60)+"s":Math.floor(s/3600)+"h"+Math.floor((s%3600)/60)+"m"}
    function fT(r){return r>1000?(r/1000).toFixed(1)+"C":r>100?(r/10).toFixed(1)+"C":r+"C"}
    function fW(v,i){return((v/1e6)*(Math.abs(i)/1000)).toFixed(2)}
    function eC(){var w=s.emmc.w;if(w<0)return t2;if(w<10)return gr;if(w<50)return yl;if(w<80)return"#f08040";return hl}
    function bC(){return bh>=90?gr:bh>=75?yl:bh>=60?"#f08040":hl}
    function eD(){var w=s.emmc.w;if(w<0)return"...";if(w<=0)return"未定义";if(w<=10)return"0-10%(全新)";if(w<=30)return"10-30%";if(w<=50)return"30-50%";if(w<=70)return"50-70%!";if(w<=90)return"70-90%!!";return"超寿命!!!"}

    // === HEADER ===
    Rectangle {
        id: header
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 22; color: c1; z: 10
        Row {
            anchors.fill: parent; anchors.leftMargin: 2; anchors.rightMargin: 2
            // Back
            Rectangle { width: 36; height: 20; radius: 3; color: "#444"; anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; text: "←返回"; font.pixelSize: 9; color: t2 }
                MouseArea { anchors.fill: parent; onClicked: root.backButtonClicked() }
            }
            // Title
            Text { width: parent.width-80; height: 22; text: ok?(hd?"系统监测":"采集数据中..."):"启动中..."
                font.pixelSize: 10; font.bold: true; color: hd?hl:yl
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            // Refresh
            Rectangle { width: 36; height: 20; radius: 3; color: rfsh?"#2f7dcc":"#444"; anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; text: rfsh?"✓":"↻刷新"; font.pixelSize: 9; color: rfsh?"#fff":t2 }
                MouseArea { anchors.fill: parent; onClicked: {
                    rfsh=true
                    try{var t=sh.outputText;if(t&&t.length>0){parse(t);if(t.length>60000)sh.clearOutput()}}catch(e){}
                    rfshTimer.start()
                } }
            }
        }
    }

    // === UI ===
    Flickable {
        id: flick
        anchors.top: header.bottom; anchors.topMargin: 2
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        contentWidth: parent.width
        contentHeight: col.childrenRect.height + 8
        clip: true; boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col; anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: 4; spacing: 2
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "系统监测"; font.pixelSize: 12; font.bold: true; color: hl }
            Text { anchors.horizontalCenter: parent.horizontalCenter
                text: !hd?(ok?"采集数据中...":"启动中..."):("↑"+fU(s.up.up)+"  CPU:"+s.cpu.u+"%  BAT:"+(s.bat.c>=0?s.bat.c+"%":"?"))
                font.pixelSize: 8; color: hd?t2:yl }
            // CPU
            Rectangle { width:parent.width; height:24; radius:4; color:c1
                Row { anchors.fill:parent; anchors.margins:4; spacing:4
                    Text { text:"CPU"; font.pixelSize:10; font.bold:true; color:hl; width:26; anchors.verticalCenter:parent.verticalCenter }
                    Column { width:parent.width-30; anchors.verticalCenter:parent.verticalCenter
                        Row { spacing:4
                            Rectangle { width:100; height:7; radius:3; color:"#333"; anchors.verticalCenter:parent.verticalCenter
                                Rectangle { width:Math.min(100,s.cpu.u>=0?s.cpu.u:0); height:7; radius:3
                                    color: s.cpu.u>70?hl:(s.cpu.u>40?yl:gr) } }
                            Text { text: (s.cpu.u>=0?s.cpu.u:"?")+"%"; font.pixelSize:11; font.bold:true; color:t1 }
                        }
                        Text { text: s.cpu.l?"Load:"+s.cpu.l.split(" ").slice(0,3).join(" "):""; font.pixelSize:7; color:t2 }
                    }
                }
            }
            // RAM
            Rectangle { width:parent.width; height:24; radius:4; color:c1
                Row { anchors.fill:parent; anchors.margins:4; spacing:4
                    Text { text:"RAM"; font.pixelSize:10; font.bold:true; color:gr; width:26; anchors.verticalCenter:parent.verticalCenter }
                    Column { width:parent.width-30; anchors.verticalCenter:parent.verticalCenter
                        Row { spacing:4
                            Rectangle { width:100; height:7; radius:3; color:"#333"; anchors.verticalCenter:parent.verticalCenter
                                Rectangle { width:Math.min(100,s.mem.u>=0?s.mem.u:0); height:7; radius:3
                                    color: s.mem.u>85?hl:(s.mem.u>60?yl:gr) } }
                            Text { text: (s.mem.u>=0?s.mem.u:"?")+"%"; font.pixelSize:11; font.bold:true; color:t1 }
                        }
                        Text { text: fK(s.mem.t)+"总 "+fK(s.mem.a)+"可用"; font.pixelSize:7; color:t2 }
                    }
                }
            }
            // DISK
            Rectangle { width:parent.width; height:Math.max(16,s.disk.length*12+16); radius:4; color:c1
                Column { anchors.fill:parent; anchors.margins:4; spacing:1
                    Text { text:"磁盘"; font.pixelSize:9; font.bold:true; color:t1 }
                    Repeater { model:s.disk
                        Row { spacing:4
                            Text { text:modelData.mt; font.pixelSize:7; color:t2; width:52; elide:Text.ElideRight }
                            Rectangle { width:60; height:4; radius:2; color:"#333"; anchors.verticalCenter:parent.verticalCenter
                                Rectangle { width:Math.min(60,parseInt(modelData.up)*0.6); height:4; radius:2
                                    color: parseInt(modelData.up)>90?hl:(parseInt(modelData.up)>70?yl:gr) } }
                            Text { text:modelData.up+"%"; font.pixelSize:7; color:t1; width:20 }
                            Text { text:modelData.av+"K"; font.pixelSize:7; color:t2 }
                        }
                    }
                }
            }
            // BATTERY
            Rectangle { width:parent.width; height:48; radius:4; color:c1
                Column { anchors.fill:parent; anchors.margins:4; spacing:1
                    Text { text:"电池"; font.pixelSize:9; font.bold:true; color:t1 }
                    Grid { columns:2; columnSpacing:8; rowSpacing:1
                        Text { text:"电量:"+(s.bat.c>=0?s.bat.c+"%":"?"); font.pixelSize:8; color:t1 }
                        Text { text:"状态:"+s.bat.st; font.pixelSize:8; color:t1 }
                        Text { text:"电压:"+(s.bat.v/1e6).toFixed(3)+"V"; font.pixelSize:8; color:t1 }
                        Text { text:"电流:"+(s.bat.cur/1000).toFixed(0)+"mA"; font.pixelSize:8; color:t1 }
                        Text { text:"温度:"+(s.bat.tmp/10).toFixed(1)+"°C"; font.pixelSize:8; color:t1 }
                        Text { text:"功率:"+fW(s.bat.v,s.bat.cur)+"W"; font.pixelSize:8; color:t1 }
                        Text { text:"健康:"+Math.round(bh)+"%"+trend; font.pixelSize:8; color:bC() }
                        Text { text:"满容:"+(s.bat.cf/1000).toFixed(0)+"mAh"; font.pixelSize:8; color:t1 }
                    }
                }
            }
            // eMMC
            Rectangle { width:parent.width; height:34; radius:4; color:c1
                Column { anchors.fill:parent; anchors.margins:4; spacing:1
                    Text { text:"eMMC寿命 (JEDEC)"; font.pixelSize:9; font.bold:true; color:t1 }
                    Row { spacing:4
                        Rectangle { width:180; height:6; radius:3; color:"#333"; anchors.verticalCenter:parent.verticalCenter
                            Rectangle { width:Math.min(180,Math.max(0,s.emmc.w>=0?s.emmc.w*1.8:0)); height:6; radius:3; color:eC() } }
                        Text { text:(s.emmc.w>=0?s.emmc.w:"?")+"% "+eD(); font.pixelSize:8; color:eC() }
                    }
                    Text { text:(s.emmc.nm||"?")+" Life:"+(s.emmc.lt||"?")+" PreEOL:"+(s.emmc.pe||"?"); font.pixelSize:7; color:t2 }
                }
            }
            // ABOUT
            Rectangle { width:parent.width; height:30; radius:4; color:c1
                Column { anchors.fill:parent; anchors.margins:4; spacing:1
                    Text { text:"关于"; font.pixelSize:9; font.bold:true; color:t1 }
                    Text { text:"ARM Cortex-A35x4  RAM:"+fK(s.mem.t)+"  SOC:"+(s.tmp.soc>0?fT(s.tmp.soc):"N/A")+"  ↑"+fU(s.up.up)+"  电池:"+Math.round(bh)+"%"+trend+"  循环≈"+cyc+"  GPLv3"; font.pixelSize:7; color:t2 }
                }
            }
        }
    }
    Rectangle { anchors.right:parent.right; anchors.bottom:parent.bottom; anchors.margins:3; width:6; height:6; radius:3; color:hd?gr:(ok?yl:hl) }
}
