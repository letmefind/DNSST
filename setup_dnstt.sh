#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  DNSTT Tunnel Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get user input
read -p "Your DNS domain (e.g., tunnel.example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain cannot be empty${NC}"
    exit 1
fi

# Server doesn't need to know DNS resolver type
# This is only for users who use DoH or DoT
# Server only receives UDP DNS queries
# According to docs: dnstt-server -udp :PORT -privkey-file KEY DOMAIN TARGET:PORT

read -p "Server A IP (destination server - where proxy/application is installed, default: 127.0.0.1): " SERVER_A_IP
if [ -z "$SERVER_A_IP" ]; then
    SERVER_A_IP="127.0.0.1"
    echo -e "${YELLOW}Using default: $SERVER_A_IP${NC}"
fi

read -p "Proxy/Application port on Server A (default: 1080): " PROXY_PORT
if [ -z "$PROXY_PORT" ]; then
    PROXY_PORT="1080"
    echo -e "${YELLOW}Using default port: $PROXY_PORT${NC}"
fi

read -p "Local port for dnstt-server on Server B (receiving user traffic - default: 5300): " LOCAL_PORT
if [ -z "$LOCAL_PORT" ]; then
    LOCAL_PORT="5300"
    echo -e "${YELLOW}Using default port: $LOCAL_PORT${NC}"
fi

# Check if port 53 is selected and handle DNS service conflicts
if [ "$LOCAL_PORT" = "53" ]; then
    echo -e "${YELLOW}Port 53 selected. Checking for DNS service conflicts...${NC}"
    
    # Check if systemd-resolved is running
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        echo -e "${YELLOW}systemd-resolved is running on port 53. Stopping it...${NC}"
        systemctl stop systemd-resolved
        systemctl disable systemd-resolved
        echo -e "${GREEN}systemd-resolved stopped and disabled${NC}"
    fi
    
    # Check if dnsmasq is running
    if systemctl is-active --quiet dnsmasq 2>/dev/null; then
        echo -e "${YELLOW}dnsmasq is running on port 53. Stopping it...${NC}"
        systemctl stop dnsmasq
        systemctl disable dnsmasq
        echo -e "${GREEN}dnsmasq stopped and disabled${NC}"
    fi
    
    # Check if bind9 is running
    if systemctl is-active --quiet bind9 2>/dev/null; then
        echo -e "${YELLOW}bind9 is running on port 53. Stopping it...${NC}"
        systemctl stop bind9
        systemctl disable bind9
        echo -e "${GREEN}bind9 stopped and disabled${NC}"
    fi
    
    # Check if named is running
    if systemctl is-active --quiet named 2>/dev/null; then
        echo -e "${YELLOW}named is running on port 53. Stopping it...${NC}"
        systemctl stop named
        systemctl disable named
        echo -e "${GREEN}named stopped and disabled${NC}"
    fi
    
    # Function to forcefully free port 53
    free_port_53() {
        local max_attempts=5
        local attempt=0
        
        while [ $attempt -lt $max_attempts ]; do
            # Check if anything is listening on port 53 (UDP)
            PORT_53_USAGE=$(netstat -tulpn 2>/dev/null | grep -E "udp.*:53 " || ss -tulpn 2>/dev/null | grep -E "udp.*:53 " || echo "")
            
            if [ -z "$PORT_53_USAGE" ]; then
                echo -e "${GREEN}Port 53 is now free${NC}"
                return 0
            fi
            
            # Try to extract PID - works with both netstat and ss
            # netstat format: udp6  0  0  :::53  :::*  28381/./dnstt-server
            # ss format: udp  UNCONN 0  0  *:53  *:*  28381/./dnstt-server
            PID=$(echo "$PORT_53_USAGE" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\//) {print $i; exit}}' | cut -d'/' -f1)
            
            if [ -n "$PID" ] && [ "$PID" != "-" ] && [ "$PID" != "0" ]; then
                PROCESS_NAME=$(ps -p $PID -o comm= 2>/dev/null || echo "unknown")
                echo -e "${YELLOW}Found process $PROCESS_NAME (PID: $PID) using port 53. Killing it...${NC}"
                kill -9 $PID 2>/dev/null
                sleep 2
            else
                # Try to find by process name patterns
                if echo "$PORT_53_USAGE" | grep -q "dnstt-server"; then
                    echo -e "${YELLOW}Killing dnstt-server processes...${NC}"
                    systemctl stop dnstt-server 2>/dev/null
                    pkill -9 -f dnstt-server 2>/dev/null
                    sleep 2
                elif echo "$PORT_53_USAGE" | grep -q "systemd-resolved"; then
                    echo -e "${YELLOW}Forcefully stopping systemd-resolved...${NC}"
                    systemctl stop systemd-resolved 2>/dev/null
                    pkill -9 systemd-resolved 2>/dev/null
                    sleep 2
                elif echo "$PORT_53_USAGE" | grep -q "dnsmasq"; then
                    echo -e "${YELLOW}Forcefully stopping dnsmasq...${NC}"
                    systemctl stop dnsmasq 2>/dev/null
                    pkill -9 dnsmasq 2>/dev/null
                    sleep 2
                elif echo "$PORT_53_USAGE" | grep -q "named\|bind"; then
                    echo -e "${YELLOW}Forcefully stopping named/bind...${NC}"
                    systemctl stop named 2>/dev/null
                    systemctl stop bind9 2>/dev/null
                    pkill -9 named 2>/dev/null
                    sleep 2
                else
                    # Try fuser as last resort
                    if command -v fuser &> /dev/null; then
                        echo -e "${YELLOW}Trying to kill process using port 53 with fuser...${NC}"
                        fuser -k 53/udp 2>/dev/null
                        sleep 2
                    else
                        echo -e "${YELLOW}Unknown process using port 53:${NC}"
                        echo "$PORT_53_USAGE"
                        echo ""
                        read -p "Continue anyway? (y/n): " CONTINUE_53
                        if [ "$CONTINUE_53" != "y" ] && [ "$CONTINUE_53" != "Y" ]; then
                            echo "Cancelled. Please choose a different port."
                            exit 1
                        fi
                        return 1
                    fi
                fi
            fi
            
            attempt=$((attempt + 1))
        done
        
        # Final check
        PORT_53_USAGE=$(netstat -tulpn 2>/dev/null | grep -E "udp.*:53 " || ss -tulpn 2>/dev/null | grep -E "udp.*:53 " || echo "")
        if [ -n "$PORT_53_USAGE" ]; then
            echo -e "${RED}Failed to free port 53 after $max_attempts attempts${NC}"
            echo -e "${YELLOW}Port 53 is still in use:${NC}"
            echo "$PORT_53_USAGE"
            echo ""
            read -p "Continue anyway? (y/n): " CONTINUE_53
            if [ "$CONTINUE_53" != "y" ] && [ "$CONTINUE_53" != "Y" ]; then
                echo "Cancelled. Please choose a different port."
                exit 1
            fi
        else
            echo -e "${GREEN}Port 53 is now free${NC}"
        fi
    }
    
    # Free port 53
    free_port_53
    
    # Configure resolv.conf to use external DNS servers
    echo -e "${YELLOW}Configuring /etc/resolv.conf to use external DNS servers...${NC}"
    
    # Backup original resolv.conf
    if [ ! -f /etc/resolv.conf.backup ]; then
        cp /etc/resolv.conf /etc/resolv.conf.backup
        echo -e "${GREEN}Backed up original resolv.conf${NC}"
    fi
    
    # Create new resolv.conf with external DNS
    cat > /etc/resolv.conf << RESOLV_EOF
# Generated by DNSTT setup script
# Using external DNS servers since port 53 is used by dnstt-server
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 8.8.4.4
RESOLV_EOF
    
    # Make resolv.conf immutable to prevent systemd-resolved from overwriting it
    chattr +i /etc/resolv.conf 2>/dev/null || echo -e "${YELLOW}Note: Could not make resolv.conf immutable (chattr not available)${NC}"
    
    echo -e "${GREEN}resolv.conf configured with external DNS servers (8.8.8.8, 1.1.1.1, 8.8.4.4)${NC}"
    echo -e "${YELLOW}Note: If you need to modify resolv.conf later, run: chattr -i /etc/resolv.conf${NC}"
fi

# USER_PORT is fixed at 1080 for documentation purposes only
# It's not used on the server, only shown in instructions to users
USER_PORT="1080"

read -p "MTU (Maximum Transmission Unit) - default: 1232, for better compatibility: 512 (Enter for default): " MTU_VALUE
if [ -z "$MTU_VALUE" ]; then
    MTU_VALUE="1232"
    echo -e "${YELLOW}Using default MTU: $MTU_VALUE${NC}"
fi

echo ""
echo -e "${GREEN}Configuration Summary:${NC}"
echo "  Domain: $DOMAIN"
echo "  Server A IP (destination): $SERVER_A_IP"
echo "  Proxy/Application port on Server A: $PROXY_PORT"
echo "  Local dnstt port on Server B: $LOCAL_PORT"
echo "  MTU: $MTU_VALUE"
echo ""
read -p "Continue? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Cancelled"
    exit 1
fi

# Create work directory
WORK_DIR="/opt/dnstt"
mkdir -p $WORK_DIR

# Check script directory for pre-compiled binaries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Priority 1: Check for binaries in repository binaries/ folder
REPO_BINARIES_SERVER="$SCRIPT_DIR/binaries/dnstt-server"
REPO_BINARIES_CLIENT="$SCRIPT_DIR/binaries/dnstt-client"

# Priority 2: Check for binaries in local dnstt folder
LOCAL_DNSTT_SERVER="$SCRIPT_DIR/dnstt/dnstt-server/dnstt-server"
LOCAL_DNSTT_CLIENT="$SCRIPT_DIR/dnstt/dnstt-client/dnstt-client"

# Check for pre-compiled binaries (repository binaries first, then local)
if [ -f "$REPO_BINARIES_SERVER" ] && [ -f "$REPO_BINARIES_CLIENT" ]; then
    echo -e "${GREEN}Using binaries from repository...${NC}"
    cp "$REPO_BINARIES_SERVER" $WORK_DIR/dnstt-server
    cp "$REPO_BINARIES_CLIENT" $WORK_DIR/dnstt-client
    chmod +x $WORK_DIR/dnstt-server $WORK_DIR/dnstt-client
    echo -e "${GREEN}Files copied${NC}"
elif [ -f "$LOCAL_DNSTT_SERVER" ] && [ -f "$LOCAL_DNSTT_CLIENT" ]; then
    echo -e "${GREEN}Using existing local pre-compiled binaries...${NC}"
    cp "$LOCAL_DNSTT_SERVER" $WORK_DIR/dnstt-server
    cp "$LOCAL_DNSTT_CLIENT" $WORK_DIR/dnstt-client
    chmod +x $WORK_DIR/dnstt-server $WORK_DIR/dnstt-client
    echo -e "${GREEN}Files copied${NC}"
else
    echo -e "${YELLOW}Pre-compiled binaries not found. Downloading and compiling...${NC}"
    # Install Go if not installed (only needed for compilation)
    if ! command -v go &> /dev/null; then
        echo -e "${YELLOW}Go is not installed. Installing...${NC}"
        apt-get update
        apt-get install -y golang-go
    fi
    cd $WORK_DIR
    
    # Download and compile dnstt
    if [ ! -d "dnstt" ]; then
        git clone https://github.com/Mygod/dnstt.git
    fi
    
    cd dnstt/plugin
    
    echo -e "${YELLOW}Compiling dnstt-server...${NC}"
    go build -o $WORK_DIR/dnstt-server ./dnstt-server
    
    echo -e "${YELLOW}Compiling dnstt-client...${NC}"
    go build -o $WORK_DIR/dnstt-client ./dnstt-client
fi

# Generate keys
# According to docs: dnstt-server -gen-key -privkey-file KEY -pubkey-file PUB
echo -e "${YELLOW}Generating keys...${NC}"
$WORK_DIR/dnstt-server -gen-key -privkey-file $WORK_DIR/server.key -pubkey-file $WORK_DIR/server.pub

# Read public key
PUBKEY=$(cat $WORK_DIR/server.pub | grep "pubkey" | awk '{print $2}')

# Create systemd service file for dnstt-server
# According to docs: dnstt-server -udp :PORT -mtu SIZE -privkey-file KEY DOMAIN TARGET:PORT
# -mtu 1232 (default) for better performance, -mtu 512 for better compatibility
echo -e "${YELLOW}Creating systemd service...${NC}"
cat > /etc/systemd/system/dnstt-server.service << EOF
[Unit]
Description=DNSTT Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/dnstt-server -udp :$LOCAL_PORT -mtu $MTU_VALUE -privkey-file $WORK_DIR/server.key $DOMAIN $SERVER_A_IP:$PROXY_PORT
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable dnstt-server

# Final check for port 53 before starting service
if [ "$LOCAL_PORT" = "53" ]; then
    echo -e "${YELLOW}Final check: Ensuring port 53 is free before starting service...${NC}"
    PORT_53_USAGE=$(netstat -tulpn 2>/dev/null | grep -E "udp.*:53 " || ss -tulpn 2>/dev/null | grep -E "udp.*:53 " || echo "")
    if [ -n "$PORT_53_USAGE" ]; then
        echo -e "${YELLOW}Port 53 is still in use. Attempting to free it...${NC}"
        # Stop any remaining processes
        systemctl stop dnstt-server 2>/dev/null
        pkill -9 -f dnstt-server 2>/dev/null
        systemctl stop systemd-resolved 2>/dev/null
        pkill -9 systemd-resolved 2>/dev/null
        pkill -9 dnsmasq 2>/dev/null
        pkill -9 named 2>/dev/null
        sleep 2
        
        # Try fuser if available
        if command -v fuser &> /dev/null; then
            fuser -k 53/udp 2>/dev/null
            sleep 1
        fi
        
        # Final verification
        PORT_53_USAGE=$(netstat -tulpn 2>/dev/null | grep -E "udp.*:53 " || ss -tulpn 2>/dev/null | grep -E "udp.*:53 " || echo "")
        if [ -n "$PORT_53_USAGE" ]; then
            echo -e "${RED}Warning: Port 53 is still in use:${NC}"
            echo "$PORT_53_USAGE"
            echo -e "${YELLOW}Service may fail to start. Continuing anyway...${NC}"
        else
            echo -e "${GREEN}Port 53 is now free${NC}"
        fi
    fi
fi

systemctl restart dnstt-server

# Configure iptables for firewall and redirect
echo -e "${YELLOW}Configuring iptables...${NC}"

# Install iptables-persistent if not installed
if ! command -v iptables-save &> /dev/null; then
    apt-get install -y iptables-persistent
fi

# Allow UDP for dnstt-server port
iptables -I INPUT -p udp --dport $LOCAL_PORT -j ACCEPT

# If you need to redirect another port to dnstt port, uncomment this line:
# iptables -t nat -A PREROUTING -p udp --dport $USER_PORT -j REDIRECT --to-port $LOCAL_PORT

# Save iptables rules
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

# For systems with netfilter-persistent
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save
fi

# Create client script for users
cat > $WORK_DIR/client_setup.sh << 'CLIENT_EOF'
#!/bin/bash

# Get user input
read -p "Domain: " DOMAIN
read -p "Public key file path (server.pub): " PUBKEY_FILE
read -p "Local port for connection (default: 1080): " LOCAL_PORT

if [ -z "$DOMAIN" ] || [ -z "$PUBKEY_FILE" ] || [ -z "$LOCAL_PORT" ]; then
    echo "All fields are required"
    exit 1
fi

# Download and compile dnstt-client
WORK_DIR="$HOME/dnstt-client"
mkdir -p $WORK_DIR
cd $WORK_DIR

if [ ! -d "dnstt" ]; then
    git clone https://github.com/Mygod/dnstt.git
fi

cd dnstt/plugin
go build -o dnstt-client ./dnstt-client

# Run client
# According to docs: dnstt-client -doh URL -pubkey-file KEY DOMAIN LOCAL:PORT
# or: dnstt-client -dot HOST:PORT -pubkey-file KEY DOMAIN LOCAL:PORT
echo "Connecting..."
echo "Please select DNS resolver type:"
echo "1. DoH (DNS over HTTPS) - example: https://doh.cloudflare.com/dns-query"
echo "2. DoT (DNS over TLS) - example: dot.cloudflare.com:853"
echo "3. DoU (DNS over UDP) - example: 8.8.8.8:53"
read -p "Choice (1, 2, or 3, default: 1): " DNS_TYPE
if [ -z "$DNS_TYPE" ]; then
    DNS_TYPE="1"
fi

if [ "$DNS_TYPE" = "2" ]; then
    read -p "DoT resolver address (example: dot.cloudflare.com:853): " DOT_URL
    if [ -z "$DOT_URL" ]; then
        DOT_URL="dot.cloudflare.com:853"
    fi
    ./dnstt-client -dot "$DOT_URL" -pubkey-file "$PUBKEY_FILE" "$DOMAIN" "127.0.0.1:$LOCAL_PORT"
elif [ "$DNS_TYPE" = "3" ]; then
    read -p "DoU resolver address (example: 8.8.8.8:53): " DOU_URL
    if [ -z "$DOU_URL" ]; then
        DOU_URL="8.8.8.8:53"
    fi
    ./dnstt-client -udp "$DOU_URL" -pubkey-file "$PUBKEY_FILE" "$DOMAIN" "127.0.0.1:$LOCAL_PORT"
else
    read -p "DoH resolver address (example: https://doh.cloudflare.com/dns-query): " DOH_URL
    if [ -z "$DOH_URL" ]; then
        DOH_URL="https://doh.cloudflare.com/dns-query"
    fi
    ./dnstt-client -doh "$DOH_URL" -pubkey-file "$PUBKEY_FILE" "$DOMAIN" "127.0.0.1:$LOCAL_PORT"
fi
CLIENT_EOF

chmod +x $WORK_DIR/client_setup.sh

# Create info file
cat > $WORK_DIR/info.txt << EOF
========================================
  DNSTT Connection Information
========================================

Domain: $DOMAIN
Server A IP (destination): $SERVER_A_IP
Proxy/Application port on Server A: $PROXY_PORT

Explanation:
- Server B: Server receiving user traffic (where this script is executed)
- Server A: Server receiving traffic from B (where Telegram proxy or other apps are installed)

Public Key (PUBKEY):
$PUBKEY

Public key file: $WORK_DIR/server.pub

Binary paths (server and client in the same folder):
$WORK_DIR/dnstt-server
$WORK_DIR/dnstt-client

========================================
  Commands for Users:
========================================

1. Download server.pub file from Server B:
   scp root@SERVER_B_IP:$WORK_DIR/server.pub ./

2. On user system, install and run dnstt-client:
   $WORK_DIR/client_setup.sh

   Or manually (with DoH):
   ./dnstt-client -doh https://doh.cloudflare.com/dns-query -pubkey-file ./server.pub $DOMAIN 127.0.0.1:$USER_PORT

   Or with DoT:
   ./dnstt-client -dot dot.cloudflare.com:853 -pubkey-file ./server.pub $DOMAIN 127.0.0.1:$USER_PORT

   Or with UDP (for testing):
   ./dnstt-client -udp 8.8.8.8:53 -pubkey-file ./server.pub $DOMAIN 127.0.0.1:$USER_PORT

   Note: $USER_PORT is the LOCAL port on user's system where dnstt-client listens.
         This port is NOT used on the server. Users connect to 127.0.0.1:$USER_PORT
         from their Telegram or other applications.

3. In Telegram settings, use SOCKS5 proxy:
   Host: 127.0.0.1
   Port: $USER_PORT

========================================
  Management Commands:
========================================

View service status:
systemctl status dnstt-server

View logs:
journalctl -u dnstt-server -f

Restart:
systemctl restart dnstt-server

Stop:
systemctl stop dnstt-server

========================================
EOF

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Complete information saved to:${NC}"
echo "$WORK_DIR/info.txt"
echo ""
echo -e "${YELLOW}Public key:${NC}"
echo "$PUBKEY"
echo ""
echo -e "${YELLOW}Service status:${NC}"
systemctl status dnstt-server --no-pager -l
echo ""
echo -e "${GREEN}To view logs: journalctl -u dnstt-server -f${NC}"
