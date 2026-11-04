# nixmgt: interactive management menu for this laptop. Type `nixmgt` and choose a number.
#
# - First pick a branch (any branch in the repository), then update, test or check on that branch.
# - Asks for sudo itself. The selected branch is stored in <stateDir>/branch.
# - Every path, unit name and address used by the tool is an option below (options.nixmgt),
#   so nothing is hard-coded in the script. Override an option in org/, hosts/ or Partners/ if needed.
# - The repository comes from dawo.autoUpdate.options.repoUrl, so the repository address
#   only has to be set in one place.
{ config, lib, pkgs, hostConfig, ... }:
let
  cfg = config.nixmgt;

  # A GitHub address becomes github:owner/repo, any other git address becomes git+<address>.
  # Both accept "?ref=<branch>".
  flakeRepo =
    if lib.hasPrefix "https://github.com/" cfg.repoUrl
    then "github:" + lib.removeSuffix ".git" (lib.removePrefix "https://github.com/" cfg.repoUrl)
    else "git+" + cfg.repoUrl;

  # Host name of the repository server, used by the connectivity check.
  repoHost = lib.head (lib.splitString "/" (lib.removePrefix "https://" cfg.repoUrl));

  nixmgt = pkgs.writeShellApplication {
    name = "nixmgt";
    runtimeInputs = [
      pkgs.git pkgs.coreutils pkgs.gnused pkgs.gnugrep pkgs.systemd pkgs.util-linux
      pkgs.curl pkgs.iproute2 pkgs.jq pkgs.figlet
    ];
    text = ''
      set -euo pipefail

      # Settings. These come from the NixOS options (options.nixmgt), do not edit here.
      repo="${flakeRepo}"
      url="${cfg.repoUrl}"
      repo_host="${repoHost}"
      config_name="${hostConfig.name}"
      state_dir="${cfg.stateDir}"
      registry_file="${cfg.registryFile}"
      luks_device="${cfg.luksDevice}"
      himmelblau_conf="${cfg.himmelblauConf}"
      profile="${cfg.profile}"
      keep_days="${toString cfg.keepDays}"
      debug_dir="${cfg.debugDir}"
      title=${lib.escapeShellArg cfg.title}
      logo_text=${lib.escapeShellArg cfg.logo}
      updater_unit="${cfg.updaterUnit}"
      login_socket="${cfg.loginSocket}"
      dm_unit="${cfg.displayManagerUnit}"
      nm_unit="${cfg.networkManagerUnit}"
      networkd_unit="${cfg.networkdUnit}"
      device_id_cmd="${cfg.deviceIdCommand}"
      fallback_probe_url="${cfg.fallbackProbeUrl}"
      tpm_device="${cfg.tpmDevice}"
      secureboot_var="${cfg.secureBootVar}"
      net_dir="${cfg.netDir}"
      login_caches="${lib.concatStringsSep " " cfg.loginCaches}"
      read -r -a login_units <<< "${lib.concatStringsSep " " cfg.loginUnits}"
      read -r -a status_units <<< "${lib.concatStringsSep " " cfg.statusUnits}"
      statefile="$state_dir/branch"

      login_journal_args=()
      for u in "''${login_units[@]}"; do
        login_journal_args+=(-u "$u")
      done


      # Everything runs as root; ask for sudo ourselves if needed.
      if [ "$(id -u)" -ne 0 ]; then
        exec sudo "$0"
      fi

      logo() {
        printf '\033[1;36m'
        if [ -n "$logo_text" ]; then
          printf '%s\n' "$logo_text"
        else
          figlet -t -f small "$title" || echo "$title"
        fi
        printf '\033[0m'
      }

      pause() {
        echo
        read -r -p "Press Enter to continue. " _
      }

      ask() {
        read -r -p "$1 (y/n) " a
        [ "$a" = "y" ]
      }

      # The selected branch; defaults to main. Any normal branch name is valid.
      current() {
        b=main
        if [ -s "$statefile" ]; then
          b=$(head -n 1 "$statefile")
        fi
        if ! [[ "$b" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]]; then
          b=main
        fi
        echo "$b"
      }

      # Builds the configuration of the selected branch. $1 = switch, test or dry-build
      build() {
        mode="$1"
        b=$(current)
        cfg="$config_name"
        # On a test branch, comin (automatic updates) must not move us back to main.
        if [ "$b" != main ] && [ "$mode" != dry-build ]; then
          systemctl stop "$updater_unit" || true
        fi
        echo "=== $cfg on branch $b ($mode) ==="
        nixos-rebuild "$mode" --refresh --no-write-lock-file --flake "$repo?ref=$b#$cfg" || return 1
        if [ "$b" = main ] && [ "$mode" = switch ]; then
          systemctl start "$updater_unit" || true
        fi
        echo "=== Done ==="
      }

      update_permanent() {
        b=$(current)
        echo "Permanent update to branch: $b"
        ask "Continue?" || { echo "Cancelled."; return 0; }
        build switch
      }

      test_build() {
        b=$(current)
        echo "Temporary test build of branch: $b"
        echo "The laptop uses the new version right away, but returns to the previous one after a reboot."
        ask "Continue?" || { echo "Cancelled."; return 0; }
        build test
      }

      check_only() {
        build dry-build
      }

      choose_branch() {
        list=$(git ls-remote --heads "$url" | sed 's|.*refs/heads/||' | grep -E '^[A-Za-z0-9][A-Za-z0-9._/-]*$' || true)
        if [ -z "$list" ]; then
          echo "No branches found. Is there an internet connection?"
          return 0
        fi
        mapfile -t branches <<< "$list"
        echo "Current branch: $(current)"
        echo "Choose the branch you want to work on:"
        PS3="Number: "
        b=""
        select b in "''${branches[@]}"; do
          if [ -n "$b" ]; then break; fi
          echo "Invalid choice."
        done
        if [ -z "$b" ]; then return 0; fi
        mkdir -p "$state_dir"
        echo "$b" > "$statefile"
        echo "Selected: $b"
        echo "Nothing has changed on the laptop yet. Now choose Update, Test build or Check only."
        if [ "$b" != main ]; then
          echo "Note: this is not main. To go back to main, choose main here."
        fi
      }

      # --- Troubleshooting ---

      show_status() {
        echo "Configuration   : $config_name"
        echo "Selected branch : $(current)"
        echo "Hostname        : $(hostname)"
        echo "NixOS           : $(nixos-version)"
        echo "Generation      : $(readlink "$profile")"
        echo "Disk (/)        : $(df -h / | tail -1)"
        echo
        echo "Services (active = OK):"
        for u in "''${status_units[@]}"; do
          printf '  %-20s %s\n' "$u" "$(systemctl is-active "$u" 2>&1 || true)"
        done
      }

      show_logs() {
        echo "Which logs?"
        PS3="Number: "
        select w in "Login (Himmelblau)" "Updates (comin)" "Login screen" "Back"; do
          case "$w" in
            "Login (Himmelblau)") journalctl -b "''${login_journal_args[@]}" --no-pager | tail -60; break ;;
            "Updates (comin)") journalctl -b -u "$updater_unit" --no-pager | tail -60; break ;;
            "Login screen") journalctl -b -u "$dm_unit" --no-pager | tail -60; break ;;
            "Back") break ;;
            *) echo "Invalid choice." ;;
          esac
        done
      }

      clear_login_cache() {
        echo "This clears the local Himmelblau cache: known users and PINs."
        echo "Users must log in again and set a new PIN afterwards."
        ask "Continue?" || { echo "Cancelled."; return 0; }
        systemctl stop "''${login_units[@]}" "$login_socket" || true
        # login_caches is intentionally unquoted: it can contain globs.
        # shellcheck disable=SC2086
        rm -f $login_caches
        systemctl start "$login_socket"
        echo "Cache cleared."
      }

      restart_login() {
        systemctl restart "''${login_units[@]}"
        echo "Login services restarted."
      }

      show_generations() {
        echo "Generations of this laptop (newest last, the active one is marked):"
        nix-env --list-generations -p "$profile" | tail -15
      }

      roll_back() {
        list=$(nix-env --list-generations -p "$profile" | grep -v '(current)' | tail -10 || true)
        if [ -z "$list" ]; then
          echo "There is no earlier generation to roll back to."
          return 0
        fi
        mapfile -t gens <<< "$list"
        echo "Choose the generation to roll back to:"
        PS3="Number: "
        g=""
        select g in "''${gens[@]}" "Cancel"; do
          if [ -n "$g" ]; then break; fi
          echo "Invalid choice."
        done
        if [ -z "$g" ] || [ "$g" = "Cancel" ]; then
          echo "Cancelled."
          return 0
        fi
        read -r n _ <<< "$g"
        if ! [[ "$n" =~ ^[0-9]+$ ]]; then
          echo "Could not read the generation number."
          return 1
        fi
        echo "Rolling back to generation $n."
        echo "Automatic updates (comin) are stopped until the next reboot."
        ask "Continue?" || { echo "Cancelled."; return 0; }
        systemctl stop "$updater_unit" || true
        nix-env -p "$profile" --switch-generation "$n" || return 1
        "$profile/bin/switch-to-configuration" switch || return 1
        echo "=== Now on generation $n ==="
      }

      check_connectivity() {
        echo "--- Network ---"
        ip -br addr | grep -v '^lo' || true
        gw=$(ip route | grep '^default' | head -1 || true)
        if [ -n "$gw" ]; then echo "Default route: $gw"; else echo "Default route: NONE"; fi

        echo "--- DNS ---"
        if getent hosts "$repo_host" > /dev/null; then echo "OK: $repo_host resolves"; else echo "FAIL: DNS does not resolve $repo_host"; fi

        echo "--- Clock (wrong time breaks logins and HTTPS) ---"
        timedatectl | grep -E 'Local time|synchronized' || true

        echo "--- Repository host (HTTPS) ---"
        code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "https://$repo_host" || true)
        if [ "$code" = "200" ]; then echo "OK: HTTP $code"; else echo "FAIL: HTTP ''${code:-none}"; fi

        echo "--- Git repository ---"
        n=$(git ls-remote --heads "$url" 2>/dev/null | wc -l || true)
        if [ "$n" -gt 0 ]; then echo "OK: repository reachable, $n branch(es)"; else echo "FAIL: repository not reachable"; fi

        echo "--- Login provider ---"
        conf="$himmelblau_conf"
        issuer=""
        if [ -r "$conf" ]; then
          issuer=$(grep -E '^[[:space:]]*oidc_issuer_url' "$conf" | head -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/"//g' || true)
        fi
        if [ -n "$issuer" ]; then
          echo "Issuer: $issuer"
          code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$issuer/.well-known/openid-configuration" || true)
        else
          echo "No OIDC issuer set (Entra mode): checking $fallback_probe_url"
          code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$fallback_probe_url" || true)
        fi
        if [ "$code" = "200" ]; then echo "OK: HTTP $code"; else echo "FAIL: HTTP ''${code:-none}"; fi
      }

      renew_ip() {
        if systemctl is-active --quiet "$nm_unit" && command -v nmcli > /dev/null; then
          echo "Using NetworkManager: reconnecting active ethernet/wifi connections."
          names=$(nmcli -t -f NAME,TYPE connection show --active | grep -E ':(802-3-ethernet|802-11-wireless)$' | cut -d: -f1 || true)
          if [ -z "$names" ]; then echo "No active ethernet or wifi connection found."; return 0; fi
          while IFS= read -r c; do
            echo "Reconnecting: $c"
            nmcli connection up "$c" || echo "Failed: $c"
          done <<< "$names"
        elif systemctl is-active --quiet "$networkd_unit"; then
          echo "Using systemd-networkd: renewing leases."
          for p in "$net_dir"/*; do
            i=$(basename "$p")
            if [ "$i" != lo ]; then networkctl renew "$i" || true; fi
          done
        else
          echo "No supported network manager found (NetworkManager or systemd-networkd)."
          return 1
        fi
        sleep 3
        echo "Addresses now:"
        ip -br addr | grep -v '^lo' || true
      }

      failed_units() {
        systemctl --failed --no-pager || true
      }

      check_tpm() {
        if [ -e "$tpm_device" ]; then echo "TPM2          : present"; else echo "TPM2          : not found"; fi
        sb="$secureboot_var"
        if [ -e "$sb" ]; then
          v=$(od -An -t u1 -j4 -N1 "$sb" | tr -d ' ')
          if [ "$v" = "1" ]; then echo "Secure Boot   : enabled"; else echo "Secure Boot   : disabled"; fi
        else
          echo "Secure Boot   : not available (not booted in EFI mode?)"
        fi
        echo "Disk unlock slots (tpm2 = automatic unlock):"
        systemd-cryptenroll "$luks_device" 2>&1 | head -10 || true
      }

      login_config() {
        f="$himmelblau_conf"
        if [ -r "$f" ]; then
          echo "From $f:"
          grep -E '^[[:space:]]*(oidc_issuer_url|app_id|domain|shell|pam_allow_groups|allow_console_password_only)' "$f" || echo "None of the usual settings found."
        else
          echo "$f not found."
        fi
      }

      restart_login_screen() {
        echo "This restarts the login screen and logs everyone out."
        ask "Continue?" || { echo "Cancelled."; return 0; }
        systemctl restart "$dm_unit"
      }

      reenroll_tpm() {
        if [ ! -e "$tpm_device" ]; then
          echo "No TPM found on this laptop. Nothing to do."
          return 1
        fi
        sb="$secureboot_var"
        v=0
        if [ -e "$sb" ]; then v=$(od -An -t u1 -j4 -N1 "$sb" | tr -d ' '); fi
        if [ "$v" != "1" ]; then
          echo "WARNING: Secure Boot is not enabled. The TPM unlock is then weak and can stop"
          echo "working after you enable Secure Boot later. Enable Secure Boot first if you can."
        fi
        echo "This replaces the automatic disk unlock (TPM2, PCR 7)."
        echo "You need the current disk (LUKS) password. Keep it: it stays the fallback."
        ask "Continue?" || { echo "Cancelled."; return 0; }
        systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 "$luks_device" || return 1
        echo "TPM2 enrolled again. Reboot to test: the disk should unlock without a password."
      }

      export_debug() {
        out="$debug_dir/nixmgt-debug-$(date +%Y%m%d-%H%M).txt"
        echo "Collecting information, this can take up to a minute..."
        {
          echo "nixmgt debug $(date)"
          echo "=== Status ==="; show_status
          echo; echo "=== Connectivity ==="; check_connectivity
          echo; echo "=== Failed services ==="; failed_units
          echo; echo "=== TPM and Secure Boot ==="; check_tpm
          echo; echo "=== Login configuration ==="; login_config
          echo; echo "=== Generations ==="; show_generations
          echo; echo "=== Himmelblau log ==="; journalctl -b "''${login_journal_args[@]}" --no-pager | tail -100
          echo; echo "=== comin log ==="; journalctl -b -u "$updater_unit" --no-pager | tail -60
          echo; echo "=== Login screen log ==="; journalctl -b -u "$dm_unit" --no-pager | tail -100
        } > "$out" 2>&1 || true
        chmod 644 "$out"
        echo "Saved to: $out"
        echo "The file can contain user names and IDs. Check it before you share it."
      }

      show_device_id() {
        if ! command -v "$device_id_cmd" > /dev/null; then
          echo "$device_id_cmd not found."
          return 1
        fi
        info=$("$device_id_cmd" --show)
        key=$(printf '%s\n' "$info" | sed -n 's/^key=//p')
        id=$(printf '%s\n' "$info" | tail -1)
        echo "Device key : $key"
        echo "Device ID  : $id"
        reg="$registry_file"
        entry=""
        if [ -r "$reg" ]; then
          entry=$(jq -c --arg id "$id" '.devices[$id] // empty' "$reg" 2>/dev/null || true)
        fi
        if [ -n "$entry" ]; then
          echo "Registered : $entry"
        else
          echo "Registered : no"
          echo
          echo "To register this device, add this line to devices.json (inside \"devices\"):"
          echo "  \"$id\": { \"name\": \"\", \"host\": \"laptop-nvme\", \"partner\": \"Edwin\", \"branch\": \"main\" }"
        fi
      }

      troubleshooting() {
        while true; do
          echo
          echo "--- Troubleshooting ---"
          PS3="Number: "
          select item in "Show status" "Check connectivity" "Renew IP address" "Show failed services" "Check TPM and Secure Boot" "Re-enroll TPM unlock" "Show login configuration" "Show device ID" "View logs" "Show generations" "Roll back to a previous generation" "Clear login cache" "Restart login services" "Restart login screen (logs everyone out)" "Export debug info" "Back"; do
            case "$item" in
              "Show status") show_status ;;
              "Check connectivity") check_connectivity ;;
              "Renew IP address") renew_ip || echo "Failed." ;;
              "Show failed services") failed_units ;;
              "Check TPM and Secure Boot") check_tpm ;;
              "Re-enroll TPM unlock") reenroll_tpm || echo "Failed." ;;
              "Show login configuration") login_config ;;
              "Show device ID") show_device_id || echo "Failed." ;;
              "View logs") show_logs ;;
              "Clear login cache") clear_login_cache ;;
              "Restart login services") restart_login || echo "Failed." ;;
              "Restart login screen (logs everyone out)") restart_login_screen || echo "Failed." ;;
              "Export debug info") export_debug ;;
              "Show generations") show_generations ;;
              "Roll back to a previous generation") roll_back || echo "Failed." ;;
              "Back") return 0 ;;
              *) echo "Invalid choice."; continue ;;
            esac
            pause
            break
          done
        done
      }

      clean_up() {
        echo "Old versions older than $keep_days days will be removed."
        ask "Continue?" || { echo "Cancelled."; return 0; }
        nix-collect-garbage --delete-older-than "$keep_days"d
      }

      # --- Main menu ---

      while true; do
        echo
        logo
        echo "=== Workplace management ($config_name) ==="
        echo "=== Selected branch: $(current) ==="
        if [ "$(current)" != main ]; then
          echo "!!! Not main: automatic updates (comin) are stopped as soon as you apply anything here !!!"
        fi
        PS3="Choose a number: "
        select choice in "Update (permanent)" "Test build (temporary)" "Check only (apply nothing)" "Choose another branch" "Troubleshooting" "Clean up old versions" "Reboot" "Quit"; do
          case "$choice" in
            "Update (permanent)") update_permanent || echo "Failed." ;;
            "Test build (temporary)") test_build || echo "Failed." ;;
            "Check only (apply nothing)") check_only || echo "Failed." ;;
            "Choose another branch") choose_branch || echo "Failed." ;;
            "Troubleshooting") troubleshooting ;;
            "Clean up old versions") clean_up || echo "Failed." ;;
            "Reboot") ask "Reboot now?" && systemctl reboot ;;
            "Quit") exit 0 ;;
            *) echo "Invalid choice."; continue ;;
          esac
          pause
          break
        done
      done
    '';
  };
in
{
  options.nixmgt = {
    logo = lib.mkOption {
      type = lib.types.lines;
      default = ''
          _     _             _               _ _                     _
       __| |___| |__ _ _ _  _(_)_ _  ___ _ _ | (_)_ _  ___   _ _  ___| |_
      / _` / -_) '_ \ '_| || | | ' \/ _ \ ' \| | | ' \/ -_)_| ' \/ -_)  _|
      \__,_\___|_.__/_|  \_,_|_|_||_\___/_||_|_|_|_||_\___(_)_||_\___|\__|
      '';
      description = "ASCII logo shown at the top of the menu. Leave empty to draw the title with figlet instead.";
    };
    title = lib.mkOption {
      type = lib.types.str;
      default = "debruinonline.net";
      description = "Text drawn with figlet when the logo option is empty.";
    };
    repoUrl = lib.mkOption {
      type = lib.types.str;
      default = config.dawo.autoUpdate.options.repoUrl;
      description = "Git address of the configuration repository (https).";
    };
    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/werkplek";
      description = "Directory where the tool keeps its state (the selected branch).";
    };
    registryFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/werkplek/devices.json";
      description = "Device registry file on the laptop.";
    };
    deviceIdCommand = lib.mkOption {
      type = lib.types.str;
      default = "werkplek-device-id";
      description = "Command that prints the device ID (see Config-system-hostname.nix).";
    };
    luksDevice = lib.mkOption {
      type = lib.types.str;
      default = "/dev/disk/by-partlabel/disk-main-luks";
      description = "Encrypted disk partition, used for the TPM checks.";
    };
    himmelblauConf = lib.mkOption {
      type = lib.types.str;
      default = "/etc/himmelblau/himmelblau.conf";
      description = "Himmelblau configuration file.";
    };
    profile = lib.mkOption {
      type = lib.types.str;
      default = "/nix/var/nix/profiles/system";
      description = "System profile that holds the generations.";
    };
    keepDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14;
      description = "The clean-up option removes versions older than this many days.";
    };
    debugDir = lib.mkOption {
      type = lib.types.str;
      default = "/tmp";
      description = "Directory where the debug export is written.";
    };
    updaterUnit = lib.mkOption {
      type = lib.types.str;
      default = "comin.service";
      description = "Unit of the automatic updater, stopped while a non-main branch is in use.";
    };
    loginUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "himmelblaud.service" "himmelblaud-tasks.service" ];
      description = "Login service units (restarted and stopped by the tool).";
    };
    loginSocket = lib.mkOption {
      type = lib.types.str;
      default = "himmelblaud.socket";
      description = "Socket unit of the login service.";
    };
    loginCaches = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/var/cache/himmelblaud/himmelblau.cache.db"
        "/var/cache/nss-himmelblau/*.db"
      ];
      description = "Files removed by Clear login cache. Globs are allowed.";
    };
    displayManagerUnit = lib.mkOption {
      type = lib.types.str;
      default = "display-manager.service";
      description = "Login screen unit.";
    };
    accountsUnit = lib.mkOption {
      type = lib.types.str;
      default = "accounts-daemon.service";
      description = "Accounts service unit, shown in the status overview.";
    };
    statusUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default =
        [ cfg.updaterUnit cfg.loginSocket ] ++ cfg.loginUnits ++ [ cfg.accountsUnit cfg.displayManagerUnit ];
      description = "Units shown in the status overview.";
    };
    networkManagerUnit = lib.mkOption {
      type = lib.types.str;
      default = "NetworkManager.service";
      description = "NetworkManager unit, used by Renew IP address.";
    };
    networkdUnit = lib.mkOption {
      type = lib.types.str;
      default = "systemd-networkd.service";
      description = "systemd-networkd unit, used by Renew IP address.";
    };
    fallbackProbeUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://login.microsoftonline.com/common/discovery/instance?api-version=1.1";
      description = "Address probed by the connectivity check when no OIDC issuer is configured.";
    };
    tpmDevice = lib.mkOption {
      type = lib.types.str;
      default = "/dev/tpmrm0";
      description = "TPM device node.";
    };
    secureBootVar = lib.mkOption {
      type = lib.types.str;
      default = "/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c";
      description = "EFI variable that tells whether Secure Boot is enabled.";
    };
    netDir = lib.mkOption {
      type = lib.types.str;
      default = "/sys/class/net";
      description = "Directory with the network interfaces.";
    };
  };

  config.environment.systemPackages = [ nixmgt ];
}
