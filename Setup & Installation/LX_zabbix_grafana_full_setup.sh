#!/bin/bash
# ================================================================
# Full setup script for Zabbix 7.0 LTS + Grafana on Ubuntu 24.04
# Includes LVM setup, database, Zabbix, and Grafana installation
# Assumptions: Ubuntu 24.04, /dev/vda (100GB), 8GB RAM, 4 CPU
# ================================================================

set -e

echo "[INFO] Starting full setup..."

# ------------------------------
# Step 1: Disk & LVM Setup
# ------------------------------
echo "[INFO] Preparing LVM partitions..."

DISK="/dev/vda"
VG="vg0"

# Fix GPT if needed
parted $DISK ---pretend-input-tty <<EOF
Fix
Ignore
EOF || true

# Create new partition if not exists
if ! lsblk | grep -q "${DISK}2"; then
  echo "[INFO] Creating partition for LVM..."
  parted -s $DISK mkpart primary 6GB 100%
  parted -s $DISK set 2 lvm on
fi

# Create PV, VG if not exist
if ! pvs | grep -q "${DISK}2"; then
  pvcreate ${DISK}2
  vgcreate $VG ${DISK}2
fi

# Logical volumes
lvcreate -L 40G -n db $VG || true
lvcreate -L 5G -n dblogs $VG || true
lvcreate -L 10G -n zbxlogs $VG || true
lvcreate -L 10G -n grafana $VG || true
lvcreate -L 5G -n grafanalogs $VG || true

# Filesystems (only create if not existing)
if ! blkid /dev/$VG/db; then mkfs.ext4 /dev/$VG/db; fi
if ! blkid /dev/$VG/dblogs; then mkfs.ext4 /dev/$VG/dblogs; fi
if ! blkid /dev/$VG/zbxlogs; then mkfs.ext4 /dev/$VG/zbxlogs; fi
if ! blkid /dev/$VG/grafana; then mkfs.ext4 /dev/$VG/grafana; fi
if ! blkid /dev/$VG/grafanalogs; then mkfs.ext4 /dev/$VG/grafanalogs; fi

# Mount points
mkdir -p /var/lib/mysql /var/log/mysql /var/log/zabbix /var/lib/grafana /var/log/grafana

# Update fstab
grep -q "/var/lib/mysql" /etc/fstab || echo "/dev/$VG/db /var/lib/mysql ext4 defaults 0 2" >> /etc/fstab
grep -q "/var/log/mysql" /etc/fstab || echo "/dev/$VG/dblogs /var/log/mysql ext4 defaults 0 2" >> /etc/fstab
grep -q "/var/log/zabbix" /etc/fstab || echo "/dev/$VG/zbxlogs /var/log/zabbix ext4 defaults 0 2" >> /etc/fstab
grep -q "/var/lib/grafana" /etc/fstab || echo "/dev/$VG/grafana /var/lib/grafana ext4 defaults 0 2" >> /etc/fstab
grep -q "/var/log/grafana" /etc/fstab || echo "/dev/$VG/grafanalogs /var/log/grafana ext4 defaults 0 2" >> /etc/fstab

mount -a

# ------------------------------
# Step 2: MariaDB Installation
# ------------------------------
echo "[INFO] Installing MariaDB..."
apt update
apt install -y mariadb-server mariadb-client

systemctl enable mariadb
systemctl start mariadb

# Create DB and user
mysql -uroot <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY 'zabbixpass';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# ------------------------------
# Step 3: Zabbix Installation
# ------------------------------
echo "[INFO] Installing Zabbix..."
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-3+ubuntu24.04_all.deb -O /tmp/zabbix-release.deb
dpkg -i /tmp/zabbix-release.deb
apt update

apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent2

# Import initial schema only if no tables
if ! mysql -uzabbix -pzabbixpass -e "USE zabbix; SHOW TABLES;" | grep -q users; then
  zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -pzabbixpass zabbix
fi

# Configure Zabbix server DB
sed -i 's/^# DBPassword=.*/DBPassword=zabbixpass/' /etc/zabbix/zabbix_server.conf

systemctl enable zabbix-server zabbix-agent2 apache2
systemctl restart zabbix-server zabbix-agent2 apache2

# ------------------------------
# Step 4: Grafana Installation
# ------------------------------
echo "[INFO] Installing Grafana..."
GRAFANA_VERSION="11.2.0"
wget https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_amd64.deb -O /tmp/grafana_${GRAFANA_VERSION}_amd64.deb
apt install -y /tmp/grafana_${GRAFANA_VERSION}_amd64.deb

# Configure paths
sed -i "s|^;data =.*|data = /var/lib/grafana|" /etc/grafana/grafana.ini
sed -i "s|^;logs =.*|logs = /var/log/grafana|" /etc/grafana/grafana.ini

chown -R grafana:grafana /var/lib/grafana /var/log/grafana

systemctl enable grafana-server
systemctl restart grafana-server

# ------------------------------
# Step 5: Verification
# ------------------------------
echo "[INFO] Setup complete!"
echo "Zabbix frontend: http://<server-ip>/zabbix"
echo "Grafana frontend: http://<server-ip>:3000 (admin/admin)"
