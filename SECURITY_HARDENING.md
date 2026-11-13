# Security Hardening Implementation Guide

This guide details the complete process for hardening your Oracle Cloud VM across four layers: **Purely Private VM with OCI NAT Gateway**, **Cloudflare Tunnels (Zero Inbound Ports)**, **SSH Restriction (OCI Bastion / Cloudflare Access)**, and **Ubuntu Host-Level Hardening**.

---

```
                                  INTERNET
                                     │
                    ┌────────────────▼────────────────┐
                    │      Cloudflare Edge Network    │
                    │   (DDoS Shield, WAF, SSL, CDN)  │
                    └────────────────┬────────────────┘
                                     │ Encrypted Outbound
                                     │ Tunnel (Zero Open Inbound Ports)
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│  ORACLE CLOUD VCN (10.0.0.0/16)                                        │
│                                                                        │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │  OCI NAT Gateway (Outbound-only Internet Access for Private)  │     │
│   └──────────────────────────────┬───────────────────────────────┘     │
│                                  │                                     │
│   ┌──────────────────────────────▼───────────────────────────────┐     │
│   │  PURELY PRIVATE VM (No Public IP assigned)                   │     │
│   │                                                              │     │
│   │   🔒 Host Hardening: Fail2ban + UFW + Unattended Upgrades    │     │
│   │   🔒 Secure SSH: OCI Bastion Service / Cloudflare Access     │     │
│   │                                                              │     │
│   │   ┌───────────────────────┐    ┌─────────────────────────┐   │     │
│   │   │   cloudflared Daemon  │───►│  App App (:3000)    │   │     │
│   │   │  (Outbound connection)│    │  (Unprivileged service) │   │     │
│   │   └───────────────────────┘    └─────────────────────────┘   │     │
│   └──────────────────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────────────────┘
```

---

# Why Disabling Public IP Caused "502 Bad Gateway"

In Oracle Cloud Infrastructure (OCI):
* When a subnet is routed to an **Internet Gateway (IGW)**, instances can only send/receive internet traffic if they possess an **Ephemeral or Reserved Public IP**.
* When you remove the Public IP from the VNIC, the VM loses **ALL outbound internet connectivity**.
* `cloudflared` can no longer reach Cloudflare's edge servers to maintain the tunnel, causing Cloudflare to display **`502 Bad Gateway`**.

### The Solution: OCI NAT Gateway
An **OCI NAT Gateway** gives instances without public IPs **outbound-only** internet access (so `cloudflared`, Supabase, SMTP, and `apt update` work), while **blocking 100% of all incoming internet traffic at the network level**.

---

# Step 0: Set Up an OCI NAT Gateway (Purely Private VM)

### 0.1: Create the NAT Gateway in OCI Console
1. Open [Oracle Cloud Console](https://cloud.oracle.com).
2. Go to **Networking** → **Virtual Cloud Networks (VCN)**.
3. Click your VCN (e.g. `vcn-app`).
4. On the left menu under **Resources**, click **NAT Gateways**.
5. Click **Create NAT Gateway**:
   * **Name:** `nat-gateway-app`
   * **Compartment:** Select your compartment
6. Click **Create NAT Gateway**.

---

### 0.2: Route Subnet Outbound Traffic to the NAT Gateway
1. In your VCN on the left menu, click **Route Tables**.
2. Click **Create Route Table** (or edit your Private Subnet's Route Table):
   * **Name:** `private-route-table`
   * Under **Route Rules**, click **+ Add Route Rules**:
     * **Target Type:** `NAT Gateway`
     * **Destination CIDR Block:** `0.0.0.0/0`
     * **Target NAT Gateway:** Select `nat-gateway-app`
3. Click **Create Route Table**.
4. Go to **Subnets** → Click your Subnet (or create a Private Subnet):
   * Click **Edit**.
   * Change **Route Table** to `private-route-table`.
   * Click **Save Changes**.

---

### 0.3: Or via OCI CLI (One Command)
If using the OCI CLI:
```bash
# 1. Create NAT Gateway
oci network nat-gateway create \
  --compartment-id <TENANCY_OCID> \
  --vcn-id <YOUR_VCN_OCID> \
  --name "nat-gateway-app" \
  --config-file ~/.oci/config --profile DEFAULT --auth security_token

# 2. Add default 0.0.0.0/0 route to Route Table
oci network route-table update \
  --rt-id <YOUR_ROUTE_TABLE_OCID> \
  --route-rules '[{"destination":"0.0.0.0/0","destinationType":"CIDR_BLOCK","networkEntityId":"<NAT_GATEWAY_OCID>"}]' \
  --config-file ~/.oci/config --profile DEFAULT --auth security_token
```

Once the NAT Gateway is active, your private VM will immediately re-establish the outbound Cloudflare Tunnel, and **`https://app.example.com`** will load with 0 public IP exposure!

---

# Step 1: The Ultimate Shield - Cloudflare Tunnels (Zero Open Inbound Ports)

Cloudflare Tunnels (`cloudflared`) establish an encrypted, outbound-only connection from your private VM to Cloudflare.

### Benefits:
* **Zero Open Ingress Ports:** Purely private subnet with no public IP.
* **Origin IP Masking:** The VM has no public IP address to scan or attack.
* **Automatic SSL & Edge WAF:** Cloudflare manages trusted SSL certificates, DDoS mitigation, and bot protection automatically.

---

### Step 1.1: Install `cloudflared` on the VM

```bash
# Add Cloudflare GPG key and repository
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflared.list

# Install cloudflared
sudo apt update && sudo apt install -y cloudflared
```

---

### Step 1.2: Connect Tunnel (via Cloudflare Dashboard)

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/) → **Networks** → **Tunnels**.
2. Click **Create a Tunnel** → Select **Cloudflared**.
3. Name your tunnel: `tunnel-app-oracle`.
4. Select **Debian/Ubuntu** architecture (`ARM64` for Ampere A1).
5. Copy the connector installation command and run it on your VM:
   ```bash
   sudo cloudflared service install <TUNNEL_TOKEN>
   ```
6. In Cloudflare Dashboard under **Routes** → **Add a route**:
   * **Subdomain:** `app`
   * **Domain:** `example.com`
   * **Service:** `HTTP`
   * **URL:** `localhost:3000`
7. Click **Save route**.

---

# Step 2: How to SSH into a Purely Private VM (No Public IP)

When a VM has no public IP, you have two secure options to SSH into it:

### Option A: Oracle Cloud Free Bastion Service (Recommended)
Oracle provides a managed, zero-cost **Bastion Service** that creates secure ephemeral SSH tunnels directly into private VMs:

1. In OCI Console → **Identity & Security** → **Bastions** → **Create Bastion**.
   * Target VCN: Select your VCN
   * Target Subnet: Select your Private Subnet
2. Click **Create Session** → **Managed SSH Session**:
   * Username: `ubuntu`
   * Compute Instance: Select your VM
   * SSH Key: Upload your public key
3. Copy the generated SSH command and run it from your local machine to connect instantly!

### Option B: SSH over Cloudflare Tunnel (`cloudflared access ssh`)
You can also route SSH directly through your Cloudflare Tunnel:
1. In Cloudflare Zero Trust → **Tunnels** → **Routes** → **Add a route**:
   * **Hostname:** `ssh.example.com`
   * **Service:** `SSH`
   * **URL:** `localhost:22`
2. On your Mac, configure `~/.ssh/config`:
   ```ssh-config
   Host vm-private
     HostName ssh.example.com
     User ubuntu
     ProxyCommand cloudflared access ssh --hostname %h
     IdentityFile /path/to/your/ssh-key.key
   ```
3. Run `ssh vm-private` to connect through Cloudflare!

---

# Step 3: Host-Level Hardening (Ubuntu 22.04 / 24.04)

---

### Step 3.1: Enforce SSH Key-Only Authentication

Create `/etc/ssh/sshd_config.d/60-hardening.conf`:

```bash
sudo tee /etc/ssh/sshd_config.d/60-hardening.conf > /dev/null <<'EOF'
# Disable password login (Key-only authentication)
PasswordAuthentication no
AuthenticationMethods publickey
PubkeyAuthentication yes

# Disable root direct login
PermitRootLogin no

# Reduce login grace period and brute-force retry limits
LoginGraceTime 30
MaxAuthTries 3
MaxSessions 2

# Disconnect idle sessions after 10 minutes
ClientAliveInterval 300
ClientAliveCountMax 2

# Disable insecure legacy protocols
X11Forwarding no
AllowAgentForwarding no
EOF
```

Restart SSH service:
```bash
sudo sshd -t && sudo systemctl restart ssh
```

---

### Step 3.2: Enable Automatic Security Updates (`unattended-upgrades`)

```bash
sudo apt install -y unattended-upgrades update-notifier-common
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

---

### Step 3.3: Install and Configure Fail2ban

```bash
sudo apt install -y fail2ban

sudo tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
maxretry = 3
bantime = 24h
EOF

sudo systemctl enable --now fail2ban
sudo systemctl restart fail2ban
```

---

### Step 3.4: Configure UFW (Uncomplicated Firewall)

```bash
# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow 22/tcp

# Enable Firewall
sudo ufw enable
```

---

### Step 3.5: Kernel Network Parameter Hardening (`sysctl`)

```bash
sudo tee /etc/sysctl.d/99-security-hardening.conf > /dev/null <<'EOF'
# Protect against SYN flood attacks
net.ipv4.tcp_syncookies = 1

# Disable packet routing/redirects (Prevent MITM)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Ignore ICMP echo broadcasts (Prevent Smurf DDoS attacks)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Enable IP spoofing protection (Reverse Path Filtering)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log Martians (Suspicious/spoofed packets)
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
EOF

sudo sysctl --system
```

---

### Step 3.6: Isolate Application Systemd Service

Edit `/etc/systemd/system/app.service`:
```ini
[Unit]
Description=App
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/app
EnvironmentFile=/opt/app/.env.production
ExecStart=/usr/bin/npm run start
Restart=always
RestartSec=5

# Security Hardening Directives
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

Reload and restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart app
```

---

# Security Verification Checklist

| Security Control | Implementation | Verification Command |
|---|---|---|
| **Purely Private VM** | No Public IP assigned | Check VNIC in OCI Console |
| **Outbound Internet** | OCI NAT Gateway | `curl -I https://cloudflare.com` on VM |
| **Cloudflare Tunnel** | `tunnel-app-oracle` | `sudo systemctl status cloudflared` |
| **Private SSH Access** | OCI Bastion or Cloudflare SSH | Connect via Bastion / Cloudflare |
| **Fail2ban** | Automated 24h IP banning | `sudo fail2ban-client status sshd` |
| **Auto Updates** | `unattended-upgrades` | `sudo systemctl status unattended-upgrades` |
| **Host Firewall** | UFW Default Deny | `sudo ufw status verbose` |
