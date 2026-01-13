#!/bin/bash

# Client connection script for DNSTT Tunnel

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Connect to DNSTT Tunnel${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo -e "${YELLOW}Go is not installed. Installing...${NC}"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y golang-go
        elif command -v yum &> /dev/null; then
            sudo yum install -y golang
        else
            echo -e "${RED}Please install Go manually${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install go
        else
            echo -e "${RED}Please install Go manually${NC}"
            exit 1
        fi
    fi
fi

# Get user input
read -p "Domain (e.g., tunnel.example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain cannot be empty${NC}"
    exit 1
fi

echo "DNS resolver type:"
echo "1. DoH (DNS over HTTPS)"
echo "2. DoT (DNS over TLS)"
read -p "Select (1 or 2, default: 1): " DNS_TYPE
if [ -z "$DNS_TYPE" ]; then
    DNS_TYPE="1"
fi

if [ "$DNS_TYPE" = "2" ]; then
    read -p "DoT resolver address (e.g., dot.cloudflare.com:853): " DOT_URL
    if [ -z "$DOT_URL" ]; then
        DOT_URL="dot.cloudflare.com:853"
    fi
    DNS_METHOD="dot"
    DNS_URL="$DOT_URL"
else
    read -p "DoH resolver address (default: https://doh.cloudflare.com/dns-query): " DOH_URL
    if [ -z "$DOH_URL" ]; then
        DOH_URL="https://doh.cloudflare.com/dns-query"
    fi
    DNS_METHOD="doh"
    DNS_URL="$DOH_URL"
fi

read -p "Public key file path (server.pub): " PUBKEY_FILE
if [ -z "$PUBKEY_FILE" ]; then
    PUBKEY_FILE="./server.pub"
fi

if [ ! -f "$PUBKEY_FILE" ]; then
    echo -e "${RED}Public key file not found: $PUBKEY_FILE${NC}"
    exit 1
fi

read -p "Local port for connection (default: 1080): " LOCAL_PORT
if [ -z "$LOCAL_PORT" ]; then
    LOCAL_PORT="1080"
fi

# Create work directory
WORK_DIR="$HOME/dnstt-client"
mkdir -p $WORK_DIR

# Check script directory for pre-compiled binary
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DNSTT_CLIENT="$SCRIPT_DIR/dnstt/dnstt-client/dnstt-client"

# Check for pre-compiled binary
if [ -f "$LOCAL_DNSTT_CLIENT" ]; then
    echo -e "${GREEN}Using existing pre-compiled binary...${NC}"
    cp "$LOCAL_DNSTT_CLIENT" $WORK_DIR/dnstt-client
    chmod +x $WORK_DIR/dnstt-client
    echo -e "${GREEN}File copied${NC}"
else
    echo -e "${YELLOW}Pre-compiled binary not found. Downloading and compiling...${NC}"
    cd $WORK_DIR
    
    # Download and compile
    if [ ! -d "dnstt" ]; then
        echo -e "${YELLOW}Downloading dnstt...${NC}"
        git clone https://github.com/Mygod/dnstt.git
    fi
    
    cd dnstt/plugin
    
    # Compile directly to work directory
    if [ ! -f "$WORK_DIR/dnstt-client" ]; then
        echo -e "${YELLOW}Compiling dnstt-client...${NC}"
        go build -o $WORK_DIR/dnstt-client ./dnstt-client
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Connecting...${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Domain: $DOMAIN"
if [ "$DNS_METHOD" = "dot" ]; then
    echo "  DNS: DoT - $DNS_URL"
else
    echo "  DNS: DoH - $DNS_URL"
fi
echo "  Local port: $LOCAL_PORT"
echo ""
echo -e "${YELLOW}Use these settings in Telegram:${NC}"
echo "  Type: SOCKS5"
echo "  Host: 127.0.0.1"
echo "  Port: $LOCAL_PORT"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Run client from work directory (same folder as server)
# According to dnstt docs:
# - DoH: ./dnstt-client -doh URL -pubkey-file KEY DOMAIN LOCAL:PORT
# - DoT: ./dnstt-client -dot HOST:PORT -pubkey-file KEY DOMAIN LOCAL:PORT
# - UDP: ./dnstt-client -udp HOST:PORT -pubkey-file KEY DOMAIN LOCAL:PORT
cd $WORK_DIR
if [ "$DNS_METHOD" = "dot" ]; then
    ./dnstt-client -dot "$DNS_URL" -pubkey-file "$PUBKEY_FILE" "$DOMAIN" "127.0.0.1:$LOCAL_PORT"
else
    ./dnstt-client -doh "$DNS_URL" -pubkey-file "$PUBKEY_FILE" "$DOMAIN" "127.0.0.1:$LOCAL_PORT"
fi
