#!/bin/bash
# ================================================================
# Interactive script to check LVM usage and extend logical volumes
# ================================================================

echo "=== Current LVM Setup ==="
sudo vgdisplay vg0 | grep -E "VG Name|VG Size|Free  PE / Size"
echo ""
sudo lvdisplay | grep -E "LV Name|VG Name|LV Size"
echo ""
df -h | grep -E "mapper|/"

# List all mounted LVs
echo ""
echo "=== Mounted Logical Volumes ==="
mapfile -t lvs < <(lsblk -lnpo NAME,MOUNTPOINT | grep "/")
for i in "${!lvs[@]}"; do
    echo "$((i+1)). ${lvs[$i]}"
done

# Ask user to select LV
read -p "Enter the number of the LV you want to extend: " lvnum
LVINFO=${lvs[$((lvnum-1))]}
LVPATH=$(echo $LVINFO | awk '{print $1}')
MOUNTPOINT=$(echo $LVINFO | awk '{print $2}')
echo "[INFO] Selected LV: $LVPATH mounted at $MOUNTPOINT"

# Show VG free space
VGNAME=$(sudo lvdisplay $LVPATH | grep "VG Name" | awk '{print $3}')
FREE=$(sudo vgdisplay $VGNAME | grep "Free  PE / Size" | awk '{print $5 $6}')
echo "[INFO] Free space in VG $VGNAME: $FREE"

# Ask user how much to extend
read -p "Enter size to extend (e.g., +10G) or type 'all' to use all free space: " SIZE
if [ "$SIZE" == "all" ]; then
    SIZE="-l +100%FREE"
else
    SIZE="-L $SIZE"
fi

# Extend LV
echo "[INFO] Extending $LVPATH by $SIZE..."
sudo lvextend $SIZE $LVPATH

# Detect filesystem type
FSTYPE=$(df -Th $MOUNTPOINT | tail -1 | awk '{print $2}')
echo "[INFO] Detected filesystem: $FSTYPE"

# Resize filesystem
if [ "$FSTYPE" == "xfs" ]; then
    echo "[INFO] Resizing XFS filesystem..."
    sudo xfs_growfs $MOUNTPOINT
elif [ "$FSTYPE" == "ext4" ]; then
    echo "[INFO] Resizing EXT4 filesystem..."
    sudo resize2fs $LVPATH
else
    echo "[WARNING] Unknown filesystem type: $FSTYPE. Resize manually."
fi

# Verify
echo "[INFO] New size:"
df -h $MOUNTPOINT
sudo lvdisplay $LVPATH

echo "=== Done! ==="
