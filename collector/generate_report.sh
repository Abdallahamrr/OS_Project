#!/bin/bash

LOG_FILE="/app/logs/system_metrics.log"
REPORT_FILE="/app/logs/dashboard.html"

# --- 1. Get last line for live dashboard ---
LAST_LINE=$(tail -n 1 "$LOG_FILE")

TIME_STAMP=$(echo "$LAST_LINE" | cut -d'|' -f1)
CPU_VAL=$(echo "$LAST_LINE" | sed -n 's/.*CPU: \([0-9.]*\).*/\1/p')
TEMP_VAL=$(echo "$LAST_LINE" | sed -n 's/.*Temp: \([0-9.]*\).*/\1/p')
GPU_VAL=$(echo "$LAST_LINE" | sed -n 's/.*GPU: \([0-9.]*\).*/\1/p')
MEM_VAL=$(echo "$LAST_LINE" | sed -n 's/.*Mem: \([0-9.]*\).*/\1/p')
DSK_VAL=$(echo "$LAST_LINE" | sed -n 's/.*Disk: \([0-9.]*\).*/\1/p')

CPU_VAL=${CPU_VAL:-0}; TEMP_VAL=${TEMP_VAL:-0}; GPU_VAL=${GPU_VAL:-0}; MEM_VAL=${MEM_VAL:-0}; DSK_VAL=${DSK_VAL:-0}

get_color() {
    local val=$1
    if (( $(echo "$val < 70" | bc -l) )); then echo "#22c55e";
    elif (( $(echo "$val < 90" | bc -l) )); then echo "#facc15";
    else echo "#ef4444"; fi
}

CPU_COL=$(get_color "$CPU_VAL")
GPU_COL=$(get_color "$GPU_VAL")
MEM_COL=$(get_color "$MEM_VAL")
DSK_COL=$(get_color "$DSK_VAL")
TEMP_COL=$( (( $(echo "$TEMP_VAL < 80" | bc -l) )) && echo "#facc15" || echo "#ef4444" )

cat << EOF > "$REPORT_FILE"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta http-equiv="refresh" content="3">
<style>
body { font-family: sans-serif; background: #0f172a; color: #e5e7eb; padding: 20px; text-align: center; }
.card { background: #1e293b; padding: 15px; border-radius: 12px; margin: 10px auto; width: 400px; text-align: left; }
.bar { background: #334155; border-radius: 10px; height: 18px; width: 100%; margin-top:5px; }
.fill { height: 100%; border-radius: 10px; transition: width 0.5s; }
.value { float: right; font-weight: bold; }
button { padding: 10px 20px; background-color: #2563eb; color: white; border: none; border-radius: 8px; font-size: 16px; cursor: pointer; margin-bottom: 20px; }
</style>
</head>
<body>
<h2>🖥️ System Monitor</h2>

<!-- Print Report Button -->
<button id="printBtn">🖨️ Print Report</button>

<!-- Live Dashboard Cards -->
<div class="card" style="text-align:center; color:#94a3b8;" id="timestamp">$TIME_STAMP</div>
<div class="card">CPU Load: <span class="value" id="cpu-value">${CPU_VAL}%</span>
  <div class="bar"><div class="fill" id="cpu-bar" style="background:${CPU_COL}; width: ${CPU_VAL}%;"></div></div>
</div>
<div class="card">CPU Temp: <span class="value" id="temp-value">${TEMP_VAL}°C</span>
  <div class="bar"><div class="fill" id="temp-bar" style="background:${TEMP_COL}; width: ${TEMP_VAL}%;"></div></div>
</div>
<div class="card">GPU Load: <span class="value" id="gpu-value">${GPU_VAL}%</span>
  <div class="bar"><div class="fill" id="gpu-bar" style="background:${GPU_COL}; width: ${GPU_VAL}%;"></div></div>
</div>
<div class="card">Memory: <span class="value" id="mem-value">${MEM_VAL}%</span>
  <div class="bar"><div class="fill" id="mem-bar" style="background:${MEM_COL}; width: ${MEM_VAL}%;"></div></div>
</div>
<div class="card">Disk: <span class="value" id="dsk-value">${DSK_VAL}%</span>
  <div class="bar"><div class="fill" id="dsk-bar" style="background:${DSK_COL}; width: ${DSK_VAL}%;"></div></div>
</div>

<!-- JS for dynamic Print Report -->
<script>
document.getElementById('printBtn').addEventListener('click', () => {
    fetch('system_metrics.log')
    .then(r => r.text())
    .then(text => {
        const lines = text.trim().split('\\n');
        if(lines.length===0){alert("No data to report!");return;}
        let CPU_SUM=0, TEMP_SUM=0, GPU_SUM=0, MEM_SUM=0, DSK_SUM=0;
        let CPU_MAX=0, TEMP_MAX=0, GPU_MAX=0, MEM_MAX=0, DSK_MAX=0;
        let CPU_MIN=100, TEMP_MIN=100, GPU_MIN=100, MEM_MIN=100, DSK_MIN=100;
        const COUNT=lines.length;
        const parseVal = (line,key)=>{const m=line.match(new RegExp(key+': ([0-9.]+)'));return m?parseFloat(m[1]):0;}
        const startTime = lines[0].split('|')[0].replace('[NIX] ','').replace('[WIN] ','');
        const endTime = lines[lines.length-1].split('|')[0].replace('[NIX] ','').replace('[WIN] ','');
        const startDate=new Date(startTime), endDate=new Date(endTime);
        const durationSec=Math.floor((endDate-startDate)/1000);
        const durationStr=Math.floor(durationSec/3600)+"h "+Math.floor((durationSec%3600)/60)+"m "+durationSec%60+"s";

        lines.forEach(l=>{
            const C=parseVal(l,'CPU'), T=parseVal(l,'Temp'), G=parseVal(l,'GPU'), M=parseVal(l,'Mem'), D=parseVal(l,'Disk');
            CPU_SUM+=C; TEMP_SUM+=T; GPU_SUM+=G; MEM_SUM+=M; DSK_SUM+=D;
            if(C>CPU_MAX) CPU_MAX=C; if(T>TEMP_MAX) TEMP_MAX=T; if(G>GPU_MAX) GPU_MAX=G; if(M>MEM_MAX) MEM_MAX=M; if(D>DSK_MAX) DSK_MAX=D;
            if(C<CPU_MIN) CPU_MIN=C; if(T<TEMP_MIN) TEMP_MIN=T; if(G<GPU_MIN) GPU_MIN=G; if(M<MEM_MIN) MEM_MIN=M; if(D<DSK_MIN) DSK_MIN=D;
        });

        const CPU_AVG=(CPU_SUM/COUNT).toFixed(2);
        const TEMP_AVG=(TEMP_SUM/COUNT).toFixed(2);
        const GPU_AVG=(GPU_SUM/COUNT).toFixed(2);
        const MEM_AVG=(MEM_SUM/COUNT).toFixed(2);
        const DSK_AVG=(DSK_SUM/COUNT).toFixed(2);

        const reportHTML = \`
<html><head><title>Session Report</title><style>
body{font-family:sans-serif;color:#000;padding:20px;}
table{width:80%;margin:auto;border-collapse:collapse;}
th,td{border:1px solid #000;padding:10px;text-align:center;}
th{background:#ddd;} td{background:#f7f7f7;}
</style></head><body>
<h2>📊 System Monitor - Session Report</h2>
<table>
<tr><th>Metric</th><th>Average</th><th>Min</th><th>Max</th></tr>
<tr><td>CPU (%)</td><td>\${CPU_AVG}</td><td>\${CPU_MIN}</td><td>\${CPU_MAX}</td></tr>
<tr><td>CPU Temp (°C)</td><td>\${TEMP_AVG}</td><td>\${TEMP_MIN}</td><td>\${TEMP_MAX}</td></tr>
<tr><td>GPU (%)</td><td>\${GPU_AVG}</td><td>\${GPU_MIN}</td><td>\${GPU_MAX}</td></tr>
<tr><td>Memory (%)</td><td>\${MEM_AVG}</td><td>\${MEM_MIN}</td><td>\${MEM_MAX}</td></tr>
<tr><td>Disk (%)</td><td>\${DSK_AVG}</td><td>\${DSK_MIN}</td><td>\${DSK_MAX}</td></tr>
</table>
<p>Session Start: \${startTime}</p>
<p>Session End: \${endTime}</p>
<p>Duration: \${durationStr}</p>
<p>Total Samples: \${COUNT}</p>
</body></html>
        \`;
        const w=window.open(); w.document.write(reportHTML); w.document.close(); w.print();
    });
});

// --- Live dashboard update every 3 seconds ---
setInterval(() => {
  fetch('system_metrics.log')
    .then(r => r.text())
    .then(text => {
      const lines = text.trim().split('\\n');
      if(lines.length===0) return;
      const lastLine = lines[lines.length - 1];

      const CPU = lastLine.match(/CPU: ([0-9.]+)/)?.[1] || 0;
      const TEMP = lastLine.match(/Temp: ([0-9.]+)/)?.[1] || 0;
      const GPU = lastLine.match(/GPU: ([0-9.]+)/)?.[1] || 0;
      const MEM = lastLine.match(/Mem: ([0-9.]+)/)?.[1] || 0;
      const DSK = lastLine.match(/Disk: ([0-9.]+)/)?.[1] || 0;
      const TIME = lastLine.split('|')[0];

      const getColor = (val, type) => {
        if(type==='temp') return val < 80 ? '#facc15' : '#ef4444';
        if(val < 70) return '#22c55e';
        if(val < 90) return '#facc15';
        return '#ef4444';
      };

      document.getElementById('timestamp').textContent = TIME;
      document.getElementById('cpu-value').textContent = CPU + '%';
      document.getElementById('cpu-bar').style.width = CPU + '%';
      document.getElementById('cpu-bar').style.background = getColor(CPU);

      document.getElementById('temp-value').textContent = TEMP + '°C';
      document.getElementById('temp-bar').style.width = TEMP + '%';
      document.getElementById('temp-bar').style.background = getColor(TEMP, 'temp');

      document.getElementById('gpu-value').textContent = GPU + '%';
      document.getElementById('gpu-bar').style.width = GPU + '%';
      document.getElementById('gpu-bar').style.background = getColor(GPU);

      document.getElementById('mem-value').textContent = MEM + '%';
      document.getElementById('mem-bar').style.width = MEM + '%';
      document.getElementById('mem-bar').style.background = getColor(MEM);

      document.getElementById('dsk-value').textContent = DSK + '%';
      document.getElementById('dsk-bar').style.width = DSK + '%';
      document.getElementById('dsk-bar').style.background = getColor(DSK);
    });
}, 3000);
</script>

</body>
</html>
EOF

# --- 3. Replace placeholders with actual live values (bars fix) ---
sed -i "s|LAST UPDATE|$TIME_STAMP|" "$REPORT_FILE"
sed -i "s|CPUVAL|$CPU_VAL|" "$REPORT_FILE"
sed -i "s|TEMPVAL|$TEMP_VAL|" "$REPORT_FILE"
sed -i "s|GPUVAL|$GPU_VAL|" "$REPORT_FILE"
sed -i "s|MEMVAL|$MEM_VAL|" "$REPORT_FILE"
sed -i "s|DSKVAL|$DSK_VAL|" "$REPORT_FILE"
sed -i "s|CPUCOL|$CPU_COL|" "$REPORT_FILE"
sed -i "s|TEMPCOL|$TEMP_COL|" "$REPORT_FILE"
sed -i "s|GPUCOL|$GPU_COL|" "$REPORT_FILE"
sed -i "s|MEMCOL|$MEM_COL|" "$REPORT_FILE"
sed -i "s|DSKCOL|$DSK_COL|" "$REPORT_FILE"

# --- Fix: add '%' to the width of the progress bars ---
sed -i -E "s/(width: )([0-9.]+)(;)/\1\2%;/g" "$REPORT_FILE"
