# i3status Documentation - Markdown Format

## Overview

i3status generates status lines for i3bar, dzen2, xmobar, lemonbar and similar programs. It's designed for efficiency with minimal system calls, updating approximately once per second while conserving CPU resources.

## Installation & Usage

### Command Syntax

```
i3status [-c configfile] [-h] [-v]
```

### Configuration File Locations

The program searches for config files in this order:

1. `~/.config/i3status/config` (or `$XDG_CONFIG_HOME/i3status/config`)
2. `/etc/xdg/i3status/config` (or `$XDG_CONFIG_DIRS/i3status/config`)
3. `~/.i3status.conf`
4. `/etc/i3status.conf`

## Core Configuration Structure

### General Settings Block

**Key directives:**

- `output_format`: Specifies target program (i3bar, dzen2, xmobar, lemonbar, term, none)
- `colors`: Enable/disable color output (boolean)
- `interval`: Update frequency in seconds
- `color_good`, `color_degraded`, `color_bad`: Hex color values (#RRGGBB format)
- `color_separator`: Separator line color
- `separator`: Custom separator string between modules
- `markup`: Set to "pango" for i3bar markup support

### Module Ordering

Use the `order` directive to specify which modules appear and their sequence:

```
order += "module_name"
order += "another_module"
```

## Available Modules

### IPv6

Displays the best available public IPv6 address for outgoing connections.

**Format options:** `format_up`, `format_down`
**Placeholder:** `%ip`

### Disk

Shows space usage on mounted filesystems.

**Placeholders:**

- Used/free/available/total bytes: `%used`, `%free`, `%avail`, `%total`
- Percentages: `%percentage_used`, `%percentage_free`, `%percentage_avail`

**Key options:**

- `prefix_type`: binary (IEC), decimal (SI), or custom
- `low_threshold`: Triggers color_bad display
- `threshold_type`: bytes_free, bytes_avail, percentage_free, percentage_avail
- `format_below_threshold`: Custom format when threshold exceeded
- `format_not_mounted`: Output when path doesn't exist

**Example:** `"disk /" { format = "%free (%avail)/ %total" }`

### Run-watch

Monitors if a process ID file contains a running process.

**Placeholders:** `%title`, `%status`
**Options:** `pidfile`, `format_down`

**Use cases:** DHCP clients, VPN applications

### Path-exists

Checks filesystem path existence (useful for VPN tunnels, mounted drives).

**Placeholders:** `%title`, `%status`
**Options:** `path`, `format_down`

### Wireless

Retrieves link quality, frequency, and ESSID for network interfaces.

**Placeholders:** `%quality`, `%essid`, `%bitrate`, `%frequency`, `%ip`
**Format options:** `format_up`, `format_down`, `format_bitrate`, `format_quality`, `format_signal`, `format_noise`

**Special:** Use `_first_` interface name to auto-detect first wireless device

### Ethernet

Displays IP address and link speed for wired interfaces.

**Placeholders:** `%ip`, `%speed`
**Format options:** `format_up`, `format_down`

**Special:** Use `_first_` to auto-detect first non-wireless device

### Battery

Shows charge status, percentage, remaining time, and power consumption.

**Placeholders:** `%status`, `%percentage`, `%remaining`, `%emptytime`, `%consumption`

**Status strings:** `status_chr` (charging), `status_bat` (discharging), `status_unk` (unknown), `status_full`

**Key options:**

- `path`: Battery uevent file path (use %d for battery number)
- `last_full_capacity`: Use worn capacity instead of design capacity
- `low_threshold`: Battery level triggering color_bad
- `threshold_type`: time or percentage
- `format_percentage`: Custom percentage format
- `hide_seconds`: Show/hide seconds in time estimates

**Example:** `"battery all" { format = "%status %remaining (%emptytime %consumption)" }`

### CPU-Temperature

Displays thermal zone temperature.

**Placeholder:** `%degrees`
**Options:**

- `max_threshold`: Default 75°C
- `format_above_threshold`: Custom output when overheating
- `path`: Thermal zone file path

### CPU Usage

Shows CPU utilization percentage from system statistics.

**Placeholders:** `%usage`, `%cpu0`, `%cpu1` (individual cores)

**Threshold options:**

- `max_threshold`: Default 95%
- `degraded_threshold`: Default 90%
- `format_above_threshold`, `format_above_degraded_threshold`

### Memory

Displays memory usage statistics.

**Placeholders:** `total`, `used`, `free`, `available`, `shared` (with `percentage_` prefix for percentages)

**Options:**

- `threshold_degraded`, `threshold_critical`: Trigger color changes
- `format_degraded`: Alternative format below thresholds
- `unit`: auto, Ki, Mi, Gi, Ti conversion
- `decimals`: Decimal places in output
- `memory_used_method`: memavailable or classical calculation

### Load

Shows system load averages (1, 5, 15 minute intervals).

**Placeholders:** `%1min`, `%5min`, `%15min`
**Options:**

- `max_threshold`: Default 5
- `format_above_threshold`: Custom format when exceeded

### Time

Outputs current local time using strftime format codes.

**Placeholder:** `%Y-%m-%d %H:%M:%S` (example)

### TzTime

Displays time in specified timezone.

**Options:**

- `timezone`: IANA timezone identifier
- `locale`: Override environment locale
- `hide_if_equals_localtime`: Hide when matching system time
- `format_time`: Separately formatted time component

**Markup support:** Use `format_time` with `format` containing `%time` placeholder

### DDate

Shows Discordian calendar date.

**Format:** Uses ddate(1) format codes (excluding `%.` and `%X`)

### Volume

Reports mixer volume for audio devices.

**Placeholders:** `%volume`, `%devicename`
**Format options:** `format`, `format_muted`

**Device options:**

- ALSA: Specify mixer device and mixer name
- PulseAudio: Use `device = "pulse"` or `device = "pulse:N"`
- FreeBSD/OpenBSD: OSS API via `/dev/mixer`

### File Contents

Displays file contents (first 254 characters by default).

**Placeholders:** `%title`, `%content`, `%errno`, `%error`
**Options:**

- `path`: File location
- `Max_characters`: Override read limit (max 4095)
- `format_bad`: Display when file unreadable

## Universal i3bar Module Options

These apply when using `output_format = "i3bar"`:

- **align**: center (default), right, or left alignment
- **min_width**: Minimum pixel width or reference text string
- **separator**: Boolean to draw separator line (default true)
- **separator_block_width**: Gap pixels after block

**Example:**

```
disk "/" {
    format = "%avail"
    align = "left"
    min_width = 100
    separator = false
    separator_block_width = 1
}
```

## Output Formats

### i3bar

JSON-based output with metadata support; works with multi-monitor setups, tray integration.

### dzen2

General X11 messaging program; scriptable and window manager compatible.

### xmobar

Minimalistic text-based bar for xmonad environments.

### lemonbar

Lightweight XCB-based bar with UTF-8 and EWMH compliance.

### term

ANSI escape sequences for terminal debugging; basic color support (3-bit depth).

### none

Pipe-delimited output without colors; useful for custom scripts.

## Integration Patterns

### With dzen2

```bash
i3status | dzen2 -fg white -ta r -w 1280 \
-fn "-misc-fixed-medium-r-normal--13-120-75-75-C-70-iso8859-1"
```

### With xmobar

```bash
i3status | xmobar -o -t "%StdinReader%" -c "[Run StdinReader]"
```

### Custom Wrapper Scripts

For JSON output manipulation or prepending data, create shell scripts reading i3status line-by-line. Examples available in the contrib folder.

## Signal Management

Send `SIGUSR1` to force immediate update:

```bash
killall -USR1 i3status
```

Useful after volume changes or other system modifications requiring status refresh.

## Design Philosophy

i3status intentionally excludes certain metrics (like real-time CPU frequency) that change faster than display refresh rates, providing misleading information. The tool focuses on occasionally-checked values: time, connectivity status, storage capacity.

For frequently-monitored information, users should employ separate popup scripts rather than cluttering the status bar.
