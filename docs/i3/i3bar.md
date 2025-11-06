# i3bar Input Protocol Documentation

## Overview

The i3bar input protocol enables custom status bar scripts to communicate with i3's status bar using JSON. This protocol separates display information from metadata, allowing flexible script manipulation.

## Why JSON?

The protocol uses JSON for several advantages:

- **Separation of concerns**: Distinguishes actual output from meta-information like colors
- **Script manipulation**: Individual blocks can be identified and modified specifically
- **Simple integration**: Scripts can parse JSON or simply inject output at specific positions without complex parsing
- **No new dependencies**: i3 already depends on JSON for its IPC interface

Alternative plain text input remains supported for those concerned about computational overhead.

## Protocol Structure

### Header Block

Every status line begins with a header JSON object containing protocol configuration:

**Minimal**:

```json
{ "version": 1 }
```

**Full features**:

```json
{
  "version": 1,
  "stop_signal": 10,
  "cont_signal": 12,
  "click_events": true
}
```

#### Header Fields

| Field          | Purpose                                                        |
| -------------- | -------------------------------------------------------------- |
| `version`      | Protocol version (integer)                                     |
| `stop_signal`  | Signal to pause output (default: SIGSTOP; set to 0 to disable) |
| `cont_signal`  | Signal to resume output (default: SIGCONT)                     |
| `click_events` | Enable mouse click notifications when true                     |

### Status Line Format

Following the header is an infinite array of status lines. Each status line contains JSON objects representing individual blocks:

```json
[
  [
    {
      "full_text": "E: 10.0.0.1 (1000 Mbit/s)",
      "color": "#00ff00"
    },
    {
      "full_text": "2012-01-05 20:00:01"
    }
  ],
  [
    {
      "full_text": "E: 10.0.0.1 (1000 Mbit/s)",
      "color": "#00ff00"
    },
    {
      "full_text": "2012-01-05 20:00:02"
    }
  ]
]
```

Output should appear as single lines separated by newlines, without pretty-printing.

## Block Configuration

### Required Field

**full_text**: The displayed text. Empty strings cause blocks to be skipped.

### Display Properties

| Field                                                        | Type       | Description                                                    |
| ------------------------------------------------------------ | ---------- | -------------------------------------------------------------- |
| `short_text`                                                 | string     | Alternate text for space-constrained displays                  |
| `color`                                                      | hex string | Text color (e.g., "#ff0000" for red)                           |
| `background`                                                 | hex string | Block background color override                                |
| `border`                                                     | hex string | Border color override                                          |
| `border_top`, `border_right`, `border_bottom`, `border_left` | integer    | Border widths in pixels (default: 1)                           |
| `markup`                                                     | string     | "pango" or "none" (default); Pango markup requires pango fonts |

### Layout Properties

| Field                   | Type           | Description                                                   |
| ----------------------- | -------------- | ------------------------------------------------------------- |
| `min_width`             | integer/string | Minimum block width; string values use text width for padding |
| `align`                 | string         | Text alignment: "left" (default), "center", or "right"        |
| `separator`             | boolean        | Draw separator line after block (default: true)               |
| `separator_block_width` | integer        | Gap width after block in pixels (default: 9)                  |

### Metadata

| Field      | Type    | Description                                          |
| ---------- | ------- | ---------------------------------------------------- |
| `name`     | string  | Unique block identifier                              |
| `instance` | string  | Instance identifier for multiple blocks of same type |
| `urgent`   | boolean | Flag critical status (e.g., low battery)             |

### Custom Data

Prefix custom keys with underscore (`_`) to avoid conflicts. i3bar ignores unknown keys.

## Complete Block Example

```json
{
  "full_text": "E: 10.0.0.1 (1000 Mbit/s)",
  "short_text": "10.0.0.1",
  "color": "#00ff00",
  "background": "#1c1c1c",
  "border": "#ee0000",
  "border_top": 1,
  "border_right": 0,
  "border_bottom": 3,
  "border_left": 1,
  "min_width": 300,
  "align": "right",
  "urgent": false,
  "name": "ethernet",
  "instance": "eth0",
  "separator": true,
  "separator_block_width": 9,
  "markup": "none"
}
```

## Click Events

When enabled via `"click_events": true`, i3bar sends click notifications to stdin with this structure:

```json
{
  "name": "ethernet",
  "instance": "eth0",
  "button": 1,
  "modifiers": ["Shift", "Mod1"],
  "x": 1925,
  "y": 1400,
  "relative_x": 12,
  "relative_y": 8,
  "output_x": 5,
  "output_y": 1400,
  "width": 50,
  "height": 22
}
```

| Field                      | Meaning                                           |
| -------------------------- | ------------------------------------------------- |
| `button`                   | X11 button ID (1=left, 2=middle, 3=right)         |
| `x`, `y`                   | Root window coordinates                           |
| `relative_x`, `relative_y` | Coordinates within the block                      |
| `output_x`, `output_y`     | Coordinates relative to current output            |
| `width`, `height`          | Block dimensions in pixels                        |
| `modifiers`                | Array of active modifiers (e.g., "Shift", "Mod1") |

## Additional Resources

A reference shell script implementation is available at the [i3 GitHub repository](https://github.com/i3/i3/blob/next/contrib/trivial-bar-script.sh).
