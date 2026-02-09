#!/bin/bash

# ============================================
#  Silver Mail - Add Users from users.yaml + Thunder Initialization
# ============================================

# -------------------------------
# Configuration
# -------------------------------
# Colors
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

# Directories & files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Services directory contains docker-compose.yaml and silver-config
SERVICES_DIR="$(cd "${SCRIPT_DIR}/../../services" && pwd)"
# Conf directory contains config files
CONF_DIR="$(cd "${SCRIPT_DIR}/../../conf" && pwd)"
VIRTUAL_USERS_FILE="${SERVICES_DIR}/silver-config/gen/postfix/virtual-users"
VIRTUAL_DOMAINS_FILE="${SERVICES_DIR}/silver-config/gen/postfix/virtual-domains"
CONFIG_FILE="${CONF_DIR}/silver.yaml"
USERS_FILE="${CONF_DIR}/users.yaml"
PASSWORDS_DIR="${SCRIPT_DIR}/../../scripts/decrypt"
PASSWORDS_FILE="${PASSWORDS_DIR}/user_passwords.txt"

# Docker container paths
CONTAINER_VIRTUAL_USERS_FILE="/etc/postfix/virtual-users"
CONTAINER_VIRTUAL_DOMAINS_FILE="/etc/postfix/virtual-domains"

# -------------------------------
# Prompt for encryption key
# -------------------------------
echo -e "${YELLOW}Enter encryption key for storing passwords:${NC}"
read -s ENCRYPT_KEY
echo ""
if [ -z "$ENCRYPT_KEY" ]; then
	echo -e "${RED}✗ Encryption key cannot be empty${NC}"
	exit 1
fi

echo -e "${CYAN}---------------------------------------------${NC}"
echo -e " 🚀 ${GREEN}Silver Mail - Bulk Add Users${NC}"
echo -e "${CYAN}---------------------------------------------${NC}\n"

# -------------------------------
# Helper Functions
# -------------------------------

# Generate a random strong password
generate_password() {
	openssl rand -base64 24 | tr -d '\n' | head -c 16
}

# Simple XOR encryption
encrypt_password() {
	local password="$1"
	local key="$ENCRYPT_KEY"
	local encrypted=""
	local i=0
	local key_len=${#key}

	while [ $i -lt ${#password} ]; do
		local char="${password:$i:1}"
		local key_char="${key:$((i % key_len)):1}"
		local char_code=$(printf '%d' "'$char")
		local key_code=$(printf '%d' "'$key_char")
		local xor_result=$((char_code ^ key_code))
		encrypted="${encrypted}$(printf '%02x' $xor_result)"
		i=$((i + 1))
	done

	echo "$encrypted"
}

# Check if Docker Compose services are running
check_services() {
	echo -e "${YELLOW}Checking Docker Compose services...${NC}"

	if ! (cd "${SERVICES_DIR}" && docker compose ps thunder) | grep -q "Up\|running"; then
		echo -e "${RED}✗ Thunder server container is not running${NC}"
		echo -e "${YELLOW}Starting services with: docker compose up -d${NC}"
		(cd "${SERVICES_DIR}" && docker compose up -d)
		sleep 10
	else
		echo -e "${GREEN}✓ Thunder server container is running${NC}"
	fi
}

# -------------------------------
# Step 0: Validate config files exist
# -------------------------------
if [ ! -f "$CONFIG_FILE" ]; then
	echo -e "${RED}✗ Configuration file not found: $CONFIG_FILE${NC}"
	exit 1
fi

if [ ! -f "$USERS_FILE" ]; then
	echo -e "${RED}✗ Users file not found: $USERS_FILE${NC}"
	exit 1
fi

echo -e "${GREEN}✓ Configuration files found${NC}"

# -------------------------------
# Step 1: Check services
# -------------------------------
check_services

# -------------------------------
# Step 2: Extract primary domain for Thunder
# -------------------------------
# Get the first domain from users.yaml as primary domain for Thunder
PRIMARY_DOMAIN=$(grep -m 1 '^\s*-\s*domain:' "$USERS_FILE" | sed 's/.*domain:\s*//' | xargs)

if [ -z "$PRIMARY_DOMAIN" ]; then
	echo -e "${RED}✗ No domains found in $USERS_FILE${NC}"
	exit 1
fi

THUNDER_HOST=${PRIMARY_DOMAIN}
THUNDER_PORT="8090"
echo -e "${GREEN}✓ Thunder host set to: $THUNDER_HOST:$THUNDER_PORT (primary domain)${NC}"

# -------------------------------
# Step 2.1: Authenticate with Thunder and get organization unit
# -------------------------------
# Source Thunder authentication utility
source "${SCRIPT_DIR}/../utils/thunder-auth.sh"

# Authenticate with Thunder
if ! thunder_authenticate "$THUNDER_HOST" "$THUNDER_PORT"; then
	exit 1
fi

# Get organization unit ID for "silver"
if ! thunder_get_org_unit "$THUNDER_HOST" "$THUNDER_PORT" "$BEARER_TOKEN" "silver"; then
	exit 1
fi

# -------------------------------
# Step 3: Validate users.yaml
# -------------------------------
YAML_USER_COUNT=$(grep -c "username:" "$USERS_FILE" 2>/dev/null || echo "0")
if [ "$YAML_USER_COUNT" -eq 0 ]; then
	echo -e "${RED}✗ No users defined in $USERS_FILE${NC}"
	exit 1
fi

# Initialize passwords file
mkdir -p "$PASSWORDS_DIR"
echo "# Silver Mail User Passwords - Generated on $(date)" >"$PASSWORDS_FILE"
echo "# Passwords are encrypted. Use decrypt_password.sh to view them." >>"$PASSWORDS_FILE"
echo "" >>"$PASSWORDS_FILE"

# -------------------------------
# Step 4: Process domains and users
# -------------------------------
ADDED_COUNT=0
CURRENT_DOMAIN=""
USER_USERNAME=""
IN_USERS_SECTION=false

while IFS= read -r line; do
	trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

	# Match domain line: "- domain: example.com" or "  - domain: example.com"
	if [[ $line =~ ^[[:space:]]*-[[:space:]]+domain:[[:space:]]+(.+)$ ]]; then
		CURRENT_DOMAIN="${BASH_REMATCH[1]}"
		CURRENT_DOMAIN=$(echo "$CURRENT_DOMAIN" | xargs)
		IN_USERS_SECTION=false

		if [ -n "$CURRENT_DOMAIN" ]; then
			echo -e "\n${CYAN}========================================${NC}"
			echo -e "${CYAN}Processing domain: ${GREEN}${CURRENT_DOMAIN}${NC}"
			echo -e "${CYAN}========================================${NC}"

			# Validate domain format
			if ! [[ "$CURRENT_DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
				echo -e "${RED}✗ Invalid domain: $CURRENT_DOMAIN${NC}"
				CURRENT_DOMAIN=""
				continue
			fi
		fi
	fi

	# Match "users:" section marker
	if [[ $trimmed_line =~ ^users:[[:space:]]*$ ]] && [ -n "$CURRENT_DOMAIN" ]; then
		IN_USERS_SECTION=true
		continue
	fi

	# Match username line: "- username: alice" or "  - username: alice"
	if [[ $line =~ ^[[:space:]]+-[[:space:]]+username:[[:space:]]+(.+)$ ]] && [ "$IN_USERS_SECTION" = true ] && [ -n "$CURRENT_DOMAIN" ]; then
		USER_USERNAME="${BASH_REMATCH[1]}"
		USER_USERNAME=$(echo "$USER_USERNAME" | xargs)

		if [ -n "$USER_USERNAME" ]; then
			USER_EMAIL="${USER_USERNAME}@${CURRENT_DOMAIN}"

			# Generate password
			USER_PASSWORD=$(generate_password)

			echo -e "\n${YELLOW}Creating user $USER_EMAIL in Thunder...${NC}"

			USER_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
				-H "Content-Type: application/json" \
				-H "Accept: application/json" \
				-H "Authorization: Bearer ${BEARER_TOKEN}" \
				https://${THUNDER_HOST}:${THUNDER_PORT}/users \
				-d "{
                \"organizationUnit\": \"${ORG_UNIT_ID}\",
                \"type\": \"emailuser\",
                \"attributes\": {
                  \"username\": \"$USER_USERNAME\",
                  \"password\": \"$USER_PASSWORD\",
                  \"email\": \"$USER_EMAIL\"
                }
              }")

			USER_BODY=$(echo "$USER_RESPONSE" | head -n -1)
			USER_STATUS=$(echo "$USER_RESPONSE" | tail -n1)

			if [ "$USER_STATUS" -eq 201 ] || [ "$USER_STATUS" -eq 200 ]; then
				echo -e "${GREEN}✓ User $USER_EMAIL created successfully in Thunder (HTTP $USER_STATUS)${NC}"

				# Store encrypted password
				ENCRYPTED_PASSWORD=$(encrypt_password "$USER_PASSWORD")
				echo "EMAIL: $USER_EMAIL" >>"$PASSWORDS_FILE"
				echo "ENCRYPTED: $ENCRYPTED_PASSWORD" >>"$PASSWORDS_FILE"
				echo "" >>"$PASSWORDS_FILE"

				# Display info
				echo -e "${BLUE}📧 Email: ${GREEN}$USER_EMAIL${NC}"
				echo -e "${BLUE}🔐 Encrypted Password: ${YELLOW}$ENCRYPTED_PASSWORD${NC}"
				echo -e "${CYAN}   Use './decrypt_password.sh $USER_EMAIL' to view the plain password${NC}"

				ADDED_COUNT=$((ADDED_COUNT + 1))
			else
				echo -e "${RED}✗ Failed to create user $USER_EMAIL in Thunder (HTTP $USER_STATUS)${NC}"
				if [ -n "$USER_BODY" ]; then
					echo -e "${RED}Response: $USER_BODY${NC}"
				fi
			fi

			USER_USERNAME=""
		fi
	fi
done <"$USERS_FILE"

# -------------------------------
# Final Summary
# -------------------------------
echo -e "\n${CYAN}==============================================${NC}"
echo -e " 🎉 ${GREEN}User Setup Complete!${NC}"
echo " Total users added to Thunder IDP: $ADDED_COUNT"
echo ""
echo -e "${BLUE}🔐 Security Information:${NC}"
echo -e " Encrypted passwords: ${YELLOW}$PASSWORDS_FILE${NC}"
echo -e " Admin decryption tool: ${YELLOW}./decrypt_password.sh${NC}"
echo ""
echo -e "${CYAN}Admin Usage Examples:${NC}"
echo -e " View specific user password: ${YELLOW}./decrypt_password.sh user@domain.com${NC}"
echo -e " View all passwords: ${YELLOW}./decrypt_password.sh all${NC}"
echo -e " Decrypt hex string: ${YELLOW}./decrypt_password.sh '1a2b3c4d...'${NC}"
echo ""
echo -e "${GREEN}✅ All users are now available in Thunder IDP for authentication!${NC}"
echo -e "${CYAN}==============================================${NC}"
