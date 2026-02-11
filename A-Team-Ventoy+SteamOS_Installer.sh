#!/bin/bash

#
# Copyright (C) 2019-Present A-Team Digital Solutions
#

set -euo pipefail

# ===============================
# Custom SteamOS Grub Entry Function 
# ==============================
ventoy_steamos_grub_entry() {
    PART="${DRIVE}1"
    MNT="/tmp/ventoy.$$"

    echo "Adding SteamOS Repair / Install To Ventoy GRUB Entry..."

    mkdir -p "$MNT"

    mount "$PART" "$MNT"

    mkdir -p "$MNT/ventoy"

    cat > "$MNT/ventoy/ventoy_grub.cfg" <<'EOF'
# =====================================================
# A-Team SteamOS Recover / Install - Custom GRUB Entry
# =====================================================

menuentry 'SteamOS Repair / Install' --class steamos --class gnu-linux --class gnu --class os {
    insmod part_gpt
    search --label efi --set=root
    chainloader /EFI/steamos/grubx64.efi

    echo ""
    echo "Booting SteamOS Repair / Install In 5 Seconds"
    echo ""
    for i in 5 4 3 2 1; do
        echo " $i..."
        sleep 1
    done
}
EOF
    sync
    umount "$MNT"
    rmdir "$MNT"
    echo "--> DONE."
}

# =============================
# STARTUP SCREEN SIZE Function 
# =============================
startup_screen_size() {
    # Function to check if a command exists
    command_exists() {
        command -v "$1" >/dev/null 2>&1
    }

    # Check for required packages and prompt to install if missing
    MISSING=()
    for cmd in xdotool wmctrl; do
        if ! command_exists "$cmd"; then
            MISSING+=("$cmd")
        fi
    done

    if [ ${#MISSING[@]} -gt 0 ]; then
        echo ""
        echo "The Following Required Packages Are Missing: ${MISSING[*]}"
        echo ""
        read -p "Would You Like To Install Them? (y/n) " -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if command_exists apt; then
                sudo apt install -y "${MISSING[@]}"
            elif command_exists pacman; then
                sudo pacman -S --noconfirm "${MISSING[@]}"
            elif command_exists dnf; then
                sudo dnf install -y "${MISSING[@]}"
            elif command_exists zypper; then
                sudo zypper install -y "${MISSING[@]}"
            else
                echo "Package Manager Not Detected. Please Install ${MISSING[*]} Manually."
                echo ""
                echo "Press ENTER To Exit"
                read
                exit 1
                fi
        else
            echo "Dependencies Not Installed."
            echo ""
            echo "Press ENTER To Exit"
            read
            exit 1
        fi
    fi

    # Wait for a moment to ensure the window is ready
    sleep 0.5

    # Get the active window ID
    WIN_ID=$(xdotool getactivewindow)

    if [ -z "$WIN_ID" ]; then
        echo "** ERROR ** --> Failed To Get Active Window ID."
        return 1
    fi

    # Get screen dimensions
    SCREEN_WIDTH=$(xdpyinfo | awk '/dimensions/{print $2}' | cut -d 'x' -f1)
    SCREEN_HEIGHT=$(xdpyinfo | awk '/dimensions/{print $2}' | cut -d 'x' -f2)

    if [ -z "$SCREEN_WIDTH" ] || [ -z "$SCREEN_HEIGHT" ]; then
        echo "** ERROR ** --> Failed To Get Screen Dimensions."
        return 1
    fi

    # Calculate half-width
    HALF_WIDTH=$((SCREEN_WIDTH / 2))

    # Apply the window positioning multiple times to ensure it sticks
    for i in {1..3}; do
        wmctrl -i -r "$WIN_ID" -e 0,0,0,"$HALF_WIDTH","$SCREEN_HEIGHT"
        sleep 0.2
    done
}

# =================================
# FRESH VENTOY INSTALL + CUSTOMIZE
# =================================
ventoy_fresh_install() {

    echo ""
    echo "Running Ventoy Installer..."
    echo ""
    bash Ventoy2Disk.sh -I -r 7900 -g -s "$DRIVE"

    # Name image storage partition (exFAT label)
    echo ""
    echo "Naming Ventoy Image Storage Partition..."
    exfatlabel "${DRIVE}1" "Vtoy Images" 2>/dev/null || true

    # Helper mount wrapper
    _mount_copy() {
        local PART="$1"
        local SRC="$2"
        local SUBDIR="$3"
        local MNT="/tmp/ventoy.$$"

        mkdir -p "$MNT"

        mount "$PART" "$MNT" || {
            echo "** ERROR ** --> Mount Failed: $PART"
            echo ""
            echo "Press ENTER To Exit"
            read
            exit 1
        }

        mkdir -p "$MNT/$SUBDIR"
        cp -r "$SRC" "$MNT/$SUBDIR/"

        sync
        umount "$MNT"
        rmdir "$MNT"
    }

    # Add custom grub entry
    ventoy_steamos_grub_entry

    # Add theme
    echo ""
    echo "Adding A-Team Custom Ventoy Theme..."
    _mount_copy "${DRIVE}1" "A-Team/themes" "ventoy"
    echo "--> DONE."

    # Add ventoy.json
    echo ""
    echo "Adding A-Team Custom Ventoy Json Config..."
    _mount_copy "${DRIVE}1" "A-Team/ventoy.json" "ventoy"
    echo "--> DONE."

    # Patch grub.cfg
    echo ""
    echo "Patching Ventoy grub.cfg..."

    MNT="/tmp/grub.$$"
    mkdir -p "$MNT"

    mount "${DRIVE}2" "$MNT" || {
        echo "** ERROR ** --> Ventoy Grub Patch Failed: ${DRIVE}2"
        echo ""
        echo "Press ENTER To Exit"
        read
        exit 1
    }

    sed -i \
    -e 's|set VTOY_TEXT_MENU_VER="Ventoy $VENTOY_VERSION BIOS  www.ventoy.net"|set VTOY_TEXT_MENU_VER="Ventoy $VENTOY_VERSION BIOS"|' \
    -e 's|set VTOY_TEXT_MENU_VER="Ventoy $VENTOY_VERSION IA32  www.ventoy.net"|set VTOY_TEXT_MENU_VER="Ventoy $VENTOY_VERSION IA32"|' \
    -e 's|set VTOY_TEXT_MENU_VER="Ventoy $VENTOY_VERSION AA64  www.ventoy.net"|set VTOY_TEXT_MENU_VER="Ventoy $VENTOY_VERSION AA64"|' \
    -e 's|set VTOY_TEXT_MENU_VER="Ventoy $VENTOY_VERSION MIPS  www.ventoy.net"|set VTOY_TEXT_MENU_VER="Ventoy $VENTOY_VERSION MIPS"|' \
    -e 's|set VTOY_TEXT_MENU_VER="Ventoy $VENTOY_VERSION UEFI  www.ventoy.net"|set VTOY_TEXT_MENU_VER="Ventoy $VENTOY_VERSION UEFI"|' \
    "$MNT/grub/grub.cfg"

    sync
    umount "$MNT"
    rmdir "$MNT"

    echo "--> DONE."
}

# ================================
# SHRINK & MOVE VENTOY PARTITIONS
# ================================
ventoy_existing_install() {
    echo ""
    echo "Preparing Existing Ventoy Drive For SteamOS..."
    echo ""

    P1="${DRIVE}1"
    P2="${DRIVE}2"

    if [[ ! -b "$P1" || ! -b "$P2" ]]; then
        echo "** ERROR ** --> Expected Ventoy Partitions Missing"
        echo " Missing:"
        [[ ! -b "$P1" ]] && echo "  $P1"
        [[ ! -b "$P2" ]] && echo "  $P2"
        echo ""
        echo "Press ENTER To Exit"
        read
        exit 1
    fi

    # unmount everything safely
    umount -lf "$P1" 2>/dev/null || true
    umount -lf "$P2" 2>/dev/null || true

    # get size of partition 1
    SIZE_BYTES=$(blockdev --getsize64 "$P1")

    SHRINK_BYTES=$((8 * 1024 * 1024 * 1024))
    NEW_BYTES=$((SIZE_BYTES - SHRINK_BYTES))

    if (( NEW_BYTES <= 0 )); then
        echo "** ERROR ** --> Partition Too Small To Shrink"
        echo ""
        echo "Press ENTER To Exit"
        read
        exit 1
    fi

    NEW_MIB=$((NEW_BYTES / 1024 / 1024))

    echo "Shrinking Ventoy Data Partition By 8GB..."
    echo " New End: ${NEW_MIB} MiB"
    echo ""

    parted ---pretend-input-tty "$DRIVE" <<EOF
resizepart 1 ${NEW_MIB}MiB
Yes
quit
EOF

    partprobe "$DRIVE"
    udevadm settle

    # Move partition 2 right after partition 1 using sfdisk
    PART_NUM=2

    # Sanity checks
    if [[ ! -b "$DRIVE" ]]; then
        echo "** ERROR ** --> Drive Not Found: $DRIVE"
        exit 1
    fi

    if ! lsblk -no NAME "$DRIVE" | grep -q "$(basename ${DRIVE})$PART_NUM"; then
        echo "** ERROR ** --> Partition Not Found: $DRIVE$PART_NUM"
        exit 1
    fi

    # Get the end of partition 1 in sectors
    END_P1=$(parted -sm "$DRIVE" unit s print | awk -F: '$1==1 {print $3+1}')

    if [[ -z "$END_P1" ]]; then
        echo "** ERROR ** --> Failed To Read End Of Partition 1"
        exit 1
    fi

    echo "Moving Ventoy EFI Partition To Follow Ventoy Data Partition..."
    echo ""
    sfdisk --move-data -N $PART_NUM "$DRIVE" <<EOF
$END_P1
EOF

    partprobe "$DRIVE"
    udevadm settle

    echo ""
    echo "Ventoy EFI Partition Moved Successfully."
    echo ""
    echo "--> 8GB Free Space Now After Ventoy EFI Partition (Ventoy Safe)"
}

# =================
# A-Team Variables 
# =================
APP_VERSION="0.02"
APP_NAME="A-Team Ventoy + SteamOS Repair Image Installer | Version: ${APP_VERSION}" 

# ===========================
# PRINT APP NAME TO TERMINAL 
# ===========================
echo -ne "\033]0;$APP_NAME\007"

# =========================
# SET TERMINAL WINDOW SIZE 
# =========================
startup_screen_size

# ===============================
# Auto-Elevate To Root If Needed 
# ===============================
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo "Script Not Running As Root. Re-Running With Sudo..."
    sleep 5
    clear
    exec sudo bash "$0" "$@"
fi

# ==============
# CONFIGURATION
# ==============
STEAMOS_DIR="./A-Team/SteamOS"
PADDING=$((10*1024*1024))  # 100MB slack

# ================
# DRIVE SELECTION
# ================
echo ""
echo "Available Drives:"
echo ""

mapfile -t drives < <(lsblk -dpno NAME,SIZE,MODEL,TRAN | grep -E 'sd|nvme|mmc')

for i in "${!drives[@]}"; do
    echo "[$i] ${drives[$i]}"
done

echo ""
read -p "Select Drive Number To Use: " choice

if [[ -z "${drives[$choice]:-}" ]]; then
    echo "Invalid Device Selection."
    echo ""
    echo "Press ENTER To Exit"
    read
    exit 1
fi

DRIVE=$(echo "${drives[$choice]}" | awk '{print $1}')
echo ""
echo "Selected Drive: $DRIVE"
echo ""

# ==========================
# INSTALL MODE SELECTION
# ==========================
echo "Install Mode:"
echo "[1] Fresh Install (Install Ventoy + SteamOS) ⚠ Wipes Drive"
echo "[2] Add SteamOS To Existing Ventoy ⚠ No Wipe"
echo ""

read -p "Choose Option [1/2]: " mode
mode=${mode:-1}

case "$mode" in
    1)
        read -p "ALL DATA On $DRIVE Will Be Erased. Proceed? [Y/N]: " confirm
        [[ ! "$confirm" =~ ^[Yy]$ ]] && exit 1
        ventoy_fresh_install
        ;;
    2)
        ventoy_existing_install
        ;;
    *)
        echo "Invalid Option."
        echo ""
        echo "Press ENTER To Exit"
        read
        exit 1
        ;;
esac

# ==========================
# UNMOUNT DEVICE PARTITIONS
# ==========================
umount -lf "${DRIVE}"?* 2>/dev/null || true

# ==============================================
# FIND & EXTRACT STEAM-OS REPAIR /INSTALL IMAGE
# ==============================================
DEST="A-Team/SteamOS"
mkdir -p "$DEST"
IMAGES=(esp.img efi.img rootfs.img var.img home.img)

echo ""
echo "Checking For SteamOS Partition Images..."

# Check which images already exist
EXISTING=()
for f in "${IMAGES[@]}"; do
    [[ -f "$DEST/$f" ]] && EXISTING+=("$f")
done

# Decide if extraction is required
EXTRACT=1
if [[ ${#EXISTING[@]} -gt 0 ]]; then
    echo ""
    echo "Existing SteamOS Repair Images Found In: $DEST"
    for f in "${EXISTING[@]}"; do
        echo "-->  $f"
    done
    echo ""

    read -p "Re-Extract From SteamOS Repair Image? [Y/N]: " choice
    echo ""
    choice=${choice:-N}

    if [[ "$choice" =~ ^[Nn]$ ]]; then
        echo "Skipping SteamOS Repair Image Extraction..."
        EXTRACT=0
    else
        echo "Deleting Existing SteamOS Repair Images..."
        rm -f "$DEST"/*.img
    fi
fi

# Extraction
if [[ $EXTRACT -eq 1 ]]; then
    echo ""
    echo "Searching For SteamOS Repair Image..."

    mapfile -t REPAIRS < <(ls *repair*.img 2>/dev/null)

    if [[ ${#REPAIRS[@]} -eq 0 ]]; then
        echo "** ERROR ** --> No SteamOS Repair Image Found!"
        echo "** INFO ** Filename Must Include 'repair'"
        echo ""
        read -p "Press ENTER To Exit"
        exit 1
    fi

    IMG=""

    # cycle one-by-one until accepted
    for candidate in "${REPAIRS[@]}"; do
        echo ""
        echo "Found SteamOS Repair Image:"
        echo "-->  $candidate"
        echo ""

        read -p "Use This Image? [Y/N]: " choice
        choice=${choice:-Y}

        if [[ "$choice" =~ ^[Yy]$ ]]; then
            IMG="$candidate"
            break
        fi
    done

    if [[ -z "$IMG" ]]; then
        echo "**ERROR ** --> No Repair Image Selected."
        echo ""
        echo "Press ENTER To Exit"
        read
        exit 1
    fi

    echo ""
    echo "Preparing Extraction..."
    echo ""

    LOOP=$(losetup --find --show -P "$IMG") || {
        echo "** ERROR ** --> Failed To Attach Loop Device"
        echo ""
        echo "Press ENTER To Exit"
        read
        exit 1
    }

    echo "Attached: $IMG --> $LOOP"

    # safe partition extraction
    for i in {1..5}; do
        PART_NAME=$(case $i in
            1) echo "esp.img" ;;
            2) echo "efi.img" ;;
            3) echo "rootfs.img" ;;
            4) echo "var.img" ;;
            5) echo "home.img" ;;
        esac)

        echo ""
        echo "Extracting $PART_NAME..."

        dd if="${LOOP}p$i" of="$DEST/$PART_NAME" \
           bs=4M status=progress conv=fsync || {
            echo "** ERROR ** --> Failed Extracting: $PART_NAME"
            losetup -d "$LOOP"
            echo ""
            echo "Press ENTER To Exit"
            read
            exit 1
        }
    done
    sync
    losetup -d "$LOOP"
    echo ""
    echo "SteamOS Partition Images Extracted Successfully To: $DEST"
fi

echo ""
echo "Continuing..."
echo ""

# ==========================================
# INSTALL STEAM-OS REPAIR IMAGE / INSTALLER
# ==========================================
STEAMOS_ORDER=( "esp.img" "efi.img" "rootfs.img" "var.img" "home.img" )
PART_NUM=3
LAST_PART_NUM=$(( PART_NUM + ${#STEAMOS_ORDER[@]} - 1 ))

echo "Installing SteamOS Repair / Installer Image To Ventoy..."
echo ""

for IMG in "${STEAMOS_ORDER[@]}"; do
    IMG_PATH="$STEAMOS_DIR/$IMG"
    NAME="${IMG%.img}"

    echo "Processing: $IMG..."

    if [ "$PART_NUM" -eq "$LAST_PART_NUM" ]; then
        sgdisk -n $PART_NUM:0:0 -t $PART_NUM:8300 -c $PART_NUM:"$NAME" "$DRIVE"
    else
        SIZE_BYTES=$(stat -c%s "$IMG_PATH")
        SECTORS=$(( (SIZE_BYTES + 511) / 512 ))
        sgdisk -n $PART_NUM:0:+${SECTORS}s -t $PART_NUM:8300 -c $PART_NUM:"$NAME" "$DRIVE"
    fi

    partprobe "$DRIVE"
    udevadm settle

    umount -lf "${DRIVE}${PART_NUM}" 2>/dev/null || true
    
    BYTES_EXPECTED=$(stat -c%s "$IMG_PATH")

    echo ""
    echo "Writing: $IMG → ${DRIVE}${PART_NUM}..."
    dd if="$IMG_PATH" of="${DRIVE}${PART_NUM}" bs=4M conv=fsync status=progress
    sync
    echo ""

    BYTES_WRITTEN=$(blockdev --getsize64 "${DRIVE}${PART_NUM}")

    # DD Image Sanity Check
    if [ "$BYTES_WRITTEN" -lt "$BYTES_EXPECTED" ]; then
        echo "** ERROR ** --> Write Failed On: ${DRIVE}${PART_NUM}"
        echo ""
        echo "Press ENTER To Exit"
        read
        exit 1
    fi

    PART_NUM=$((PART_NUM + 1))
done

# Apply SteamOS Partition Boot Patch
echo "Applying SteamOS GPT Partitions Boot Patch..."

for pair in "efi:efi-A" "rootfs:rootfs-A" "var:var-A"; do
    OLD="${pair%%:*}"
    NEW="${pair##*:}"

    PART_NUM=$(sgdisk -p "$DRIVE" | awk -v n="$OLD" '$0 ~ n {print $1}')

    if [[ -n "$PART_NUM" ]]; then
        sgdisk --change-name=${PART_NUM}:${NEW} "$DRIVE"
        echo "  ${OLD} → ${NEW} (p${PART_NUM})"
    fi
done

partprobe "$DRIVE"

# ===========================
# FINAL INSTALL STAUS & EXIT
# ===========================
echo ""
echo ""
echo "=========================================="
echo "A-Team Ventoy + SteamOS Install Successful"
echo "=========================================="
echo ""
echo ""
echo "Press ENTER To Exit"
read
exit 1
