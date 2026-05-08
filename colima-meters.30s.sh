#!/bin/bash
# Colima VM resource monitor for SwiftBar
# Refreshes every 30 seconds

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
COLIMA=$(command -v colima)

# Map percentage to color on the green-to-red scale
pct_to_color() {
  local pct=$1
  if [[ $pct -gt 80 ]]; then echo "#FF3B30"
  elif [[ $pct -gt 60 ]]; then echo "#FF9500"
  elif [[ $pct -gt 40 ]]; then echo "#FFCC00"
  elif [[ $pct -gt 20 ]]; then echo "#8AC926"
  else echo "#34C759"
  fi
}

# Check if colima is running
if ! $COLIMA list 2>/dev/null | awk 'NR==2{print $2}' | grep -q Running; then
  SFCONFIG=$(echo -n '{"renderingMode":"Palette","colors":["gray"]}' | base64)
  echo "| sfimage=power.circle sfconfig=$SFCONFIG"
  echo "---"
  echo "Colima is not running | size=14"
  echo "---"
  echo "Start Colima | bash=$COLIMA param1=start terminal=true refresh=true"
  echo "---"
  echo "Refresh | refresh=true"
  exit 0
fi

# Get raw percentages (integers)
MEM_PCT=$($COLIMA ssh -- free -m 2>/dev/null | awk '/^Mem:/{printf "%d", ($2-$7)/$2*100}')
CPU_PCT=$($COLIMA ssh -- vmstat 1 2 2>/dev/null | awk 'END{printf "%d", 100-$15}')

# Map CPU to gauge icon and color (5 levels)
CPU_COLOR=$(pct_to_color "${CPU_PCT:-0}")
if [[ ${CPU_PCT:-0} -gt 80 ]]; then
  ICON="gauge.with.dots.needle.100percent"
elif [[ ${CPU_PCT:-0} -gt 60 ]]; then
  ICON="gauge.with.dots.needle.67percent"
elif [[ ${CPU_PCT:-0} -gt 40 ]]; then
  ICON="gauge.with.dots.needle.50percent"
elif [[ ${CPU_PCT:-0} -gt 20 ]]; then
  ICON="gauge.with.dots.needle.33percent"
else
  ICON="gauge.with.dots.needle.0percent"
fi

# Map memory to single-column fill block (▁▂▃▄▅▆▇█)
BLOCKS=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
IDX=$(( (${MEM_PCT:-0} * 7) / 100 ))
[[ $IDX -gt 7 ]] && IDX=7
MEM_BLOCK="${BLOCKS[$IDX]}"
MEM_COLOR=$(pct_to_color "${MEM_PCT:-0}")

# Menu bar: gauge icon + colored memory block
SFCONFIG=$(echo -n "{\"renderingMode\":\"Palette\",\"colors\":[\"$CPU_COLOR\"]}" | base64)
echo "$MEM_BLOCK | sfimage=$ICON sfconfig=$SFCONFIG color=$MEM_COLOR"
echo "---"

# Dropdown details
echo "Colima VM | size=14"
echo "---"
echo "CPU: ${CPU_PCT:-?}%"
$COLIMA ssh -- free -m 2>/dev/null | awk -v pct="${MEM_PCT:-?}" '
  /^Mem:/{printf "Memory: %.1fG / %.1fG (%s%%)\n", ($2-$7)/1024, $2/1024, pct}
'
$COLIMA ssh -- cat /proc/pressure/memory 2>/dev/null | awk '
  /^some/{split($2,a,"="); split($3,b,"="); split($4,c,"=")
    if (a[2]+0 > 0) printf "  ⚠ pressure %s%% / %s%% / %s%%\n", a[2], b[2], c[2]
  }
'
$COLIMA ssh -- df -h 2>/dev/null | awk '
  $1 ~ /^\/dev\/vdb/ {printf "Disk: %s / %s (%s)\n", $3, $2, $5; exit}
'
echo "CPUs: $($COLIMA list 2>/dev/null | awk 'NR==2{print $4}')"
echo "Load: $($COLIMA ssh -- cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}')"
echo "---"
echo "Stop Colima | bash=$COLIMA param1=stop terminal=true refresh=true"
echo "Restart Colima | bash=$COLIMA param1=restart terminal=true refresh=true"
echo "---"
echo "Refresh | refresh=true"
