#!/bin/bash

# ============================================
#  Silver Mail - Thunder User Registration Only
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
CONFIG_FILE="${CONF_DIR}/silver.yaml"
USERS_FILE="${CONF_DIR}/users.yaml"
INVITE_URLS_DIR="${SCRIPT_DIR}/../../scripts/user"
INVITE_URLS_FILE="${INVITE_URLS_DIR}/user_invite_urls.txt"

echo -e "${CYAN}---------------------------------------------${NC}"
echo -e " 🚀 ${GREEN}Thunder User Registration${NC}"
echo -e "${CYAN}---------------------------------------------${NC}\n"

# -------------------------------
# Helper Functions
# -------------------------------

# Make a Thunder API call and parse response
# Usage: thunder_api_call <url> <json_data> <description>
# Sets global variables: API_RESPONSE_BODY and API_RESPONSE_STATUS
thunder_api_call() {
	local url="$1"
	local json_data="$2"
	local description="$3"
	
	local full_response=$(curl -s -w "\n%{http_code}" -X POST \
		-H "Content-Type: application/json" \
		-H "Accept: application/json" \
		-H "Authorization: Bearer ${BEARER_TOKEN}" \
		"$url" \
		-d "$json_data")
	
	API_RESPONSE_BODY=$(echo "$full_response" | head -n -1)
	API_RESPONSE_STATUS=$(echo "$full_response" | tail -n1)
	
	if [ "$API_RESPONSE_STATUS" -ne 200 ]; then
		echo -e "${RED}✗ Failed to $description (HTTP $API_RESPONSE_STATUS)${NC}"
		echo -e "${RED}Response: $API_RESPONSE_BODY${NC}"
		return 1
	fi
	
	return 0
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
# Step 1: Extract primary domain for Thunder
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
# Step 2: Authenticate with Thunder and get organization unit
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

# Initialize invite URLs file
mkdir -p "$INVITE_URLS_DIR"
echo "# Silver Mail User Invite URLs - Generated on $(date)" >"$INVITE_URLS_FILE"
echo "# Users must complete registration using these URLs to set their passwords" >>"$INVITE_URLS_FILE"
echo "" >>"$INVITE_URLS_FILE"

# -------------------------------
# Step 4: Register users in Thunder
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

			echo -e "\n${YELLOW}Creating user $USER_EMAIL in Thunder...${NC}"

			# Step 1: Start USER_ONBOARDING flow
			echo -e "${CYAN}  → Step 1: Starting USER_ONBOARDING flow...${NC}"
			if ! thunder_api_call "https://${THUNDER_HOST}:${THUNDER_PORT}/flow/execute" \
				'{"flowType":"USER_ONBOARDING","verbose":true}' \
				"start USER_ONBOARDING flow"; then
				USER_USERNAME=""
				continue
			fi

			FLOW_ID=$(echo "$API_RESPONSE_BODY" | grep -o '"flowId":"[^"]*' | sed 's/"flowId":"//')
			if [ -z "$FLOW_ID" ]; then
				echo -e "${RED}✗ Failed to extract flowId${NC}"
				USER_USERNAME=""
				continue
			fi

			echo -e "${GREEN}  ✓ Flow started: $FLOW_ID${NC}"

			# Step 2: Submit user type (emailuser)
			echo -e "${CYAN}  → Step 2: Submitting user type...${NC}"
			if ! thunder_api_call "https://${THUNDER_HOST}:${THUNDER_PORT}/flow/execute" \
				"{\"flowId\":\"${FLOW_ID}\",\"inputs\":{\"userType\":\"emailuser\"},\"verbose\":true,\"action\":\"usertype_submit\"}" \
				"submit user type"; then
				USER_USERNAME=""
				continue
			fi

			echo -e "${GREEN}  ✓ User type submitted${NC}"

			# Step 3: Submit email address
			echo -e "${CYAN}  → Step 3: Submitting email address...${NC}"
			if ! thunder_api_call "https://${THUNDER_HOST}:${THUNDER_PORT}/flow/execute" \
				"{\"flowId\":\"${FLOW_ID}\",\"inputs\":{\"email\":\"${USER_EMAIL}\"},\"verbose\":true,\"action\":\"action_submit_email\"}" \
				"submit email"; then
				USER_USERNAME=""
				continue
			fi

			echo -e "${GREEN}  ✓ Email submitted${NC}"

			# Extract invite link from response
			INVITE_URL=$(echo "$API_RESPONSE_BODY" | grep -o '"inviteLink":"[^"]*' | sed 's/"inviteLink":"//;s/\\u0026/\&/g;s/\\//g')

			if [ -z "$INVITE_URL" ]; then
				echo -e "${RED}✗ Failed to extract invite link from response${NC}"
				echo -e "${YELLOW}Response: $API_RESPONSE_BODY${NC}"
				USER_USERNAME=""
				continue
			fi

			echo -e "${GREEN}✓ User $USER_EMAIL created successfully in Thunder${NC}"
			echo -e "${GREEN}  Invite link generated${NC}"

			# Store invite URL
			echo "EMAIL: $USER_EMAIL" >>"$INVITE_URLS_FILE"
			echo "INVITE URL: $INVITE_URL" >>"$INVITE_URLS_FILE"
			echo "" >>"$INVITE_URLS_FILE"

			# Display info
			echo -e "${BLUE}📧 Email: ${GREEN}$USER_EMAIL${NC}"
			echo -e "${BLUE}🔗 Invite URL: ${YELLOW}$INVITE_URL${NC}"
			echo -e "${CYAN}   User must visit this URL to set their password${NC}"

			ADDED_COUNT=$((ADDED_COUNT + 1))

			USER_USERNAME=""
		fi
	fi
done <"$USERS_FILE"

# -------------------------------
# Final Summary
# -------------------------------
echo -e "\n${CYAN}==============================================${NC}"
echo -e " 🎉 ${GREEN}Thunder User Registration Complete!${NC}"
echo " Total users registered in Thunder: $ADDED_COUNT"
echo ""
echo -e "${BLUE}🔐 User Registration:${NC}"
echo -e " Invite URLs saved to: ${YELLOW}$INVITE_URLS_FILE${NC}"
echo -e " Users must visit their invite URLs to complete registration and set passwords"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo -e " 1. Share the invite URLs with the respective users"
echo -e " 2. Users will complete registration by setting their passwords"
echo -e " 3. Users can then authenticate via Thunder IDP"
echo ""
echo -e "${GREEN}✅ All users registered in Thunder IDP successfully!${NC}"
echo -e "${CYAN}==============================================${NC}"