#!/usr/bin/env bash
set -euo pipefail

# Balance all windows in the current workspace
# Iterates until all columns are within tolerance of target width

workspace=$(hyprctl activeworkspace -j | jq -r '.id')
monitor_width=$(hyprctl monitors -j | jq -r '.[0].width')
gaps=10
tolerance=20  # Accept widths within this many pixels of target
max_iterations=10

echo "Workspace: $workspace, Monitor width: $monitor_width"

# Store original focus
original=$(hyprctl activewindow -j | jq -r '.address')

for ((iter = 1; iter <= max_iterations; iter++)); do
    echo "--- Iteration $iter ---"

    # Get unique X positions (columns) in current workspace
    columns=$(hyprctl clients -j | jq -r --arg ws "$workspace" \
        '[.[] | select(.workspace.id == ($ws | tonumber) and .floating == false) | .at[0]] | unique | .[]')

    if [[ -z "$columns" ]]; then
        echo "No tiled windows found"
        exit 0
    fi

    num_columns=$(echo "$columns" | wc -l)
    target_width=$(( (monitor_width - (gaps * (num_columns + 1))) / num_columns ))
    echo "Columns: $num_columns, Target width: $target_width"

    needs_resize=0

    for col_x in $columns; do
        addr=$(hyprctl clients -j | jq -r --arg ws "$workspace" --arg x "$col_x" \
            '[.[] | select(.workspace.id == ($ws | tonumber) and .at[0] == ($x | tonumber))] | .[0].address')

        if [[ -n "$addr" && "$addr" != "null" ]]; then
            current_width=$(hyprctl clients -j | jq -r --arg addr "$addr" \
                '.[] | select(.address == $addr) | .size[0]')

            diff=$((target_width - current_width))
            abs_diff=${diff#-}

            echo "  Column x=$col_x: width=$current_width, diff=$diff"

            if [[ $abs_diff -gt $tolerance ]]; then
                needs_resize=1
                hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1
                hyprctl dispatch resizeactive "$diff 0" >/dev/null 2>&1
                echo "    -> Resized by $diff"
            fi
        fi
    done

    if [[ $needs_resize -eq 0 ]]; then
        echo "Balanced $num_columns columns in $iter iteration(s)"
        break
    fi

    sleep 0.05
done

# Restore focus
if [[ -n "$original" && "$original" != "null" ]]; then
    hyprctl dispatch focuswindow "address:$original" >/dev/null 2>&1
fi

echo "Done!"
