#!/bin/bash
# =============================================================================
# Google Workspace MCP Server — Cloud Run Deployment Script
# For: Ava Neal / VisaPlex
# =============================================================================
#
# PREREQUISITES (complete these before running this script):
#   1. Install gcloud CLI: https://cloud.google.com/sdk/docs/install
#   2. Run: gcloud auth login
#   3. Set your project: gcloud config set project YOUR_PROJECT_ID
#   4. Create OAuth credentials in Google Cloud Console (see guide)
#
# USAGE:
#   chmod +x deploy-cloud-run.sh
#   ./deploy-cloud-run.sh
#
# =============================================================================

set -e

# --- CONFIGURATION (edit these) ---
PROJECT_ID="${GCP_PROJECT_ID:-visaplex-mcp}"
REGION="us-central1"  # Free tier region
SERVICE_NAME="gws-mcp"
BUCKET_NAME="${PROJECT_ID}-mcp-creds"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Google Workspace MCP — Cloud Run Deploy   ${NC}"
echo -e "${CYAN}============================================${NC}"

# Check for required env vars
if [ -z "$GOOGLE_OAUTH_CLIENT_ID" ] || [ -z "$GOOGLE_OAUTH_CLIENT_SECRET" ]; then
  echo -e "${RED}ERROR: Set GOOGLE_OAUTH_CLIENT_ID and GOOGLE_OAUTH_CLIENT_SECRET first${NC}"
  echo ""
  echo "  export GOOGLE_OAUTH_CLIENT_ID='your-client-id'"
  echo "  export GOOGLE_OAUTH_CLIENT_SECRET='your-client-secret'"
  exit 1
fi

echo ""
echo -e "${GREEN}Step 1: Enable required APIs...${NC}"
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  gmail.googleapis.com \
  calendar-json.googleapis.com \
  drive.googleapis.com \
  docs.googleapis.com \
  sheets.googleapis.com \
  slides.googleapis.com \
  forms.googleapis.com \
  tasks.googleapis.com \
  people.googleapis.com \
  chat.googleapis.com \
  script.googleapis.com \
  --project=$PROJECT_ID

echo ""
echo -e "${GREEN}Step 2: Create Cloud Storage bucket for credentials...${NC}"
gsutil mb -p $PROJECT_ID -l $REGION gs://$BUCKET_NAME 2>/dev/null || echo "Bucket already exists"

echo ""
echo -e "${GREEN}Step 3: Build and deploy to Cloud Run...${NC}"
gcloud run deploy $SERVICE_NAME \
  --source . \
  --region $REGION \
  --project $PROJECT_ID \
  --platform managed \
  --allow-unauthenticated \
  --port 8000 \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 2 \
  --set-env-vars "GOOGLE_OAUTH_CLIENT_ID=$GOOGLE_OAUTH_CLIENT_ID" \
  --set-env-vars "GOOGLE_OAUTH_CLIENT_SECRET=$GOOGLE_OAUTH_CLIENT_SECRET" \
  --set-env-vars "PORT=8000" \
  --set-env-vars "WORKSPACE_MCP_HOST=0.0.0.0" \
  --set-env-vars "WORKSPACE_MCP_CREDENTIALS_DIR=/mnt/creds" \
  --set-env-vars "MCP_SINGLE_USER_MODE=1" \
  --set-env-vars "TOOL_TIER=extended" \
  --add-volume name=creds-vol,type=cloud-storage,bucket=$BUCKET_NAME \
  --add-volume-mount volume=creds-vol,mount-path=/mnt/creds \
  --command="/bin/sh" \
  --args="-c,uv run main.py --transport streamable-http --single-user --tool-tier extended"

echo ""
echo -e "${GREEN}Step 4: Get service URL...${NC}"
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --project $PROJECT_ID --format 'value(status.url)')
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}DEPLOYMENT COMPLETE!${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "Service URL:  ${GREEN}${SERVICE_URL}${NC}"
echo -e "MCP Endpoint: ${GREEN}${SERVICE_URL}/mcp/${NC}"
echo -e "Health Check: ${GREEN}${SERVICE_URL}/health${NC}"
echo ""
echo -e "Now update the OAuth redirect URI in Google Cloud Console:"
echo -e "  ${CYAN}${SERVICE_URL}/oauth2callback${NC}"
echo ""
echo -e "${CYAN}--- Connect to your AI tools ---${NC}"
echo ""
echo "POKE:"
echo "  Settings → Connections → Create"
echo "  Name: Google Workspace"
echo "  MCP URL: ${SERVICE_URL}/mcp/"
echo ""
echo "MANUS:"
echo "  Settings → Integrations → + Add Custom MCP Server"
echo "  Name: Google Workspace"
echo "  Transport: HTTP"
echo "  URL: ${SERVICE_URL}/mcp/"
echo ""
echo "CLAUDE DESKTOP:"
echo "  Add to claude_desktop_config.json:"
echo "  {\"mcpServers\":{\"google-workspace\":{\"url\":\"${SERVICE_URL}/mcp/\"}}}"
echo ""
echo "CLAUDE CODE:"
echo "  claude mcp add google-workspace --transport http ${SERVICE_URL}/mcp/"
echo ""
