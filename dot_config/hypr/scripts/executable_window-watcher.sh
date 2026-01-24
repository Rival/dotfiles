#!/bin/bash

# Path to your layout manager script
LAYOUT_SCRIPT="$HOME/.config/hypr/scripts/layout-per-window.nu"

handle() {
    case $1 in
        openwindow*)
            window_data=${1#openwindow>>}
            IFS=',' read -r addr workspace class title <<< "$window_data"
            
            echo "Window opened: $class - $title on workspace: $workspace"
            
            # Direct workspace name comparison (works for named workspaces)
            case "$workspace" in
                "Unity")
                    echo "Unity workspace detected!"
                    if [[ "$title" == "Explorer" ]]; then
                      hyprctl dispatch resizewindowpixel exact 90% 100%, "title:^(Explorer)$"
                      echo "Explorer opened end resized!"
                        # sleep 0.2
                        # hyprctl dispatch layoutmsg swapwithmaster
                    fi
                    ;;
            esac
            ;;

        closewindow*)
          window_addr=${1#closewindow>>}

          echo "Window closed: $window_addr"

          # Check if we're currently on Game workspace and it's now empty
          current_workspace=$(hyprctl activeworkspace -j | jq -r '.name')

          if [[ "$current_workspace" == "Game" || "$current_workspace" == "MainTop" ]]; then
            # Count remaining windows on Game workspace
            window_count=$(hyprctl clients -j | jq '[.[] | select(.workspace.name == "Game")] | length')

            echo "Current workspace: $current_workspace, Windows remaining: $window_count"

            if [[ "$window_count" == "0" ]]; then
              echo "Game workspace is empty, switching to Main"
              hyprctl dispatch workspace name:Main
            fi
          fi
          ;;

          activewindow*)
              window_data=${1#activewindow>>}
              IFS=',' read -r class title <<< "$window_data"
              
              echo "Window focused: $class - $title"
              
              # Store layout for the previously active window and restore for new active window
              if [[ -x "$LAYOUT_SCRIPT" ]]; then
                  echo "Restoring layout for focused window: $class"
                  "$LAYOUT_SCRIPT" restore
              fi
              ;;

          workspace*)
            workspace_data=${1#workspace>>}
              echo "Workspace changed to: $workspace_data"
              
              # Update Waybar theme based on workspace
              # case $workspace_data in
              #     1|Main)
              #         waybar_class="workspace-main"
              #         css_bg="#f38ba8"
              #         ;;
              #     2|MainTop)
              #         waybar_class="workspace-top"
              #         css_bg="#a6e3a1"
              #         ;;
              #     3|MainCenter)
              #         waybar_class="workspace-center"
              #         css_bg="#fab387"
              #         ;;
              #     4|MainBottom)
              #         waybar_class="workspace-bottom"
              #         css_bg="#89b4fa"
              #         ;;
              #     5|Unity)
              #         waybar_class="workspace-unity"
              #         css_bg="#cba6f7"
              #         ;;
              #     *)
              #         waybar_class="workspace-default"
              #         css_bg="@bar-bg"
              #         ;;
              # esac
              
              # Apply theme to Waybar
              echo "Applying Waybar theme: $waybar_class"
              
              hyprctl dispatch exec ~/.config/hypr/scripts/change-workspace-style.nu
              # Method 1: Update CSS variable file
              # echo ":root { --workspace-bg: $css_bg; }" > /tmp/waybar-workspace-theme.css
              
              # Method 2: Send signal to custom Waybar module (if you have one)
              # echo "$waybar_class" > /tmp/waybar-workspace-class
              pkill -RTMIN+10 waybar  # Signal custom module to refresh
              
              # When workspace changes, restore layout for the active window in that workspace
              if [[ -x "$LAYOUT_SCRIPT" ]]; then
                  echo "Restoring layout after workspace change"
                  sleep 0.1  # Small delay to ensure window focus is settled
                  "$LAYOUT_SCRIPT" restore
              fi
              ;;
    esac
}

socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do
    handle "$line"
done
