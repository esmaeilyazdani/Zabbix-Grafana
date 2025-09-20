LX_zabbix_grafana_full_setup.sh

🚀 Automated Deployment of Zabbix 7.0 LTS + Grafana on Ubuntu 24.04

This repository provides automation scripts to set up a production-ready monitoring stack with Zabbix 7.0 LTS and Grafana OSS on Ubuntu 24.04.
The setup includes LVM-based partitioning for databases and logs, ensuring clean separation of data and easy scalability.

📋 Assumptions

Before running the script, please make sure your environment matches these requirements:

OS: Ubuntu 24.04 (installed from a template image consuming ~6GB of disk space).

Server resources:

CPU: 4 cores

RAM: 8GB

Disk: 100GB available at /dev/vda

The script assumes the first 6GB are already consumed by the OS installation, and the remaining space will be used for LVM setup.

⚙️ What the script does

The main script LX_zabbix_grafana_full_setup.sh automates the following tasks:

Disk & LVM Setup

Creates partitions and initializes an LVM volume group.

Allocates dedicated logical volumes:

db → /var/lib/mysql (40GB)

dblogs → /var/log/mysql (5GB)

zbxlogs → /var/log/zabbix (10GB)

grafana → /var/lib/grafana (10GB)

grafanalogs → /var/log/grafana (5GB)

Formats partitions with ext4 and updates /etc/fstab.

MariaDB Installation

Installs MariaDB server and client.

Creates the zabbix database and a dedicated user with proper privileges.

Zabbix Installation (7.0 LTS)

Adds the Zabbix repository.

Installs server, frontend, agent, and SQL scripts.

Imports the initial schema if the database is empty.

Configures Zabbix server with DB credentials.

Grafana Installation (OSS)

Installs Grafana OSS (v11.2.0 by default).

Configures Grafana to use dedicated LVM-backed storage for data and logs.

Ensures proper ownership and permissions.

Service Management

Enables and starts MariaDB, Zabbix server, Zabbix agent, Apache2, and Grafana server.

Verification & Access

Zabbix frontend → http://<server-ip>/zabbix

Grafana frontend → http://<server-ip>:3000 (default credentials: admin/admin)

🚀 Usage
1. Clone the Repository
git clone https://github.com/<your-github-user>/<your-repo>.git
cd <your-repo>

2. Make Script Executable
chmod +x LX_zabbix_grafana_full_setup.sh

3. Run the Script

Run as root or with sudo:

sudo ./LX_zabbix_grafana_full_setup.sh

📦 Extending Storage

When your monitoring data grows, you can easily extend the volumes with the companion script:

LX_extend_lvm.sh
This script allows you to expand existing LVM volumes (e.g., /var/lib/mysql or /var/lib/grafana) and resize the filesystem without downtime.

Usage example:

sudo ./LX_extend_lvm.sh vg0 db +10G


This will add +10GB to the db logical volume.

🔐 Default Credentials

Zabbix DB User: zabbix

Zabbix DB Password: zabbixpass

Grafana: admin / admin (you’ll be prompted to change this at first login)

📌 Notes

The script is idempotent — safe to re-run if something fails midway.

All partitions are mounted automatically via /etc/fstab.

Adjust logical volume sizes inside the script if you need a different layout.

🏷️ Tags

#Zabbix #Grafana #Ubuntu #Automation #DevOps #IaC #Ansible #ConfigurationManagement #SysAdmin
