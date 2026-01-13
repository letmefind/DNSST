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

# Get user input
read -p "Domain (e.g., tunnel.example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain cannot be empty${NC}"
    exit 1
fi

echo "DNS resolver type:"
echo "1. DoH (DNS over HTTPS) - Default"
echo "2. DoT (DNS over TLS)"
echo "3. DoU (DNS over UDP)"
read -p "Select (1, 2, or 3, default: 1): " DNS_TYPE
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
elif [ "$DNS_TYPE" = "3" ]; then
    read -p "DoU resolver address (e.g., 8.8.8.8:53): " DOU_URL
    if [ -z "$DOU_URL" ]; then
        DOU_URL="8.8.8.8:53"
    fi
    DNS_METHOD="dou"
    DNS_URL="$DOU_URL"
else
    read -p "DoH resolver address (default: https://doh.cloudflare.com/dns-query): " DOH_URL
    if [ -z "$DOH_URL" ]; then
        DOH_URL="https://doh.cloudflare.com/dns-query"
    fi
    DNS_METHOD="doh"
    DNS_URL="$DOH_URL"
fi

echo ""
echo -e "${YELLOW}Enter the public key string (exported from server installation):${NC}"
echo -e "${YELLOW}Example format: pubkey:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx${NC}"
read -p "Public key: " PUBKEY_STRING

if [ -z "$PUBKEY_STRING" ]; then
    echo -e "${RED}Public key cannot be empty${NC}"
    exit 1
fi

# Create work directory first
WORK_DIR="/opt/dnstt"
mkdir -p $WORK_DIR

# Save public key to file
PUBKEY_FILE="$WORK_DIR/server.pub"
echo "$PUBKEY_STRING" > "$PUBKEY_FILE"
echo -e "${GREEN}Public key saved to: $PUBKEY_FILE${NC}"

read -p "Local port for connection (default: 1080): " LOCAL_PORT
if [ -z "$LOCAL_PORT" ]; then
    LOCAL_PORT="1080"
fi

# Check script directory for pre-compiled binary
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Priority 1: Check for binary in repository binaries/ folder
REPO_BINARIES_CLIENT="$SCRIPT_DIR/binaries/dnstt-client"

# Priority 2: Check for binary in local dnstt folder
LOCAL_DNSTT_CLIENT="$SCRIPT_DIR/dnstt/dnstt-client/dnstt-client"

# Check for pre-compiled binary (repository binary first, then local)
if [ -f "$REPO_BINARIES_CLIENT" ]; then
    echo -e "${GREEN}Using binary from repository...${NC}"
    cp "$REPO_BINARIES_CLIENT" $WORK_DIR/dnstt-client
    chmod +x $WORK_DIR/dnstt-client
    echo -e "${GREEN}Binary copied to: $WORK_DIR/dnstt-client${NC}"
elif [ -f "$LOCAL_DNSTT_CLIENT" ]; then
    echo -e "${GREEN}Using existing local pre-compiled binary...${NC}"
    cp "$LOCAL_DNSTT_CLIENT" $WORK_DIR/dnstt-client
    chmod +x $WORK_DIR/dnstt-client
    echo -e "${GREEN}Binary copied to: $WORK_DIR/dnstt-client${NC}"
else
    echo -e "${YELLOW}Pre-compiled binary not found. Downloading and compiling...${NC}"
    # Install Go if not installed (only needed for compilation)
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
    
    # Use temporary directory for compilation
    TEMP_DIR="$HOME/dnstt-temp"
    mkdir -p $TEMP_DIR
    cd $TEMP_DIR
    
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
        chmod +x $WORK_DIR/dnstt-client
        echo -e "${GREEN}Binary compiled to: $WORK_DIR/dnstt-client${NC}"
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
elif [ "$DNS_METHOD" = "dou" ]; then
    echo "  DNS: DoU - $DNS_URL"
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
# - DoU: ./dnstt-client -udp HOST:PORT -pubkey-file KEY DOMAIN LOCAL:PORT
if [ "$DNS_METHOD" = "dot" ]; then
    $WORK_DIR/dnstt-client -dot "$DNS_URL" -pubkey-file "$PUBKEY_FILE" "$DOMAIN" "127.0.0.1:$LOCAL_PORT"
elif [ "$DNS_METHOD" = "dou" ]; then
    $WORK_DIR/dnstt-client -udp "$DNS_URL" -pubkey-file "$PUBKEY_FILE" "$DOMAIN" "127.0.0.1:$LOCAL_PORT"
else
    $WORK_DIR/dnstt-client -doh "$DNS_URL" -pubkey-file "$PUBKEY_FILE" "$DOMAIN" "127.0.0.1:$LOCAL_PORT"
fi
