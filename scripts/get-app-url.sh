#!/bin/bash

# Script to retrieve the LoadBalancer URL for the CloudAge application
# Usage: ./scripts/get-app-url.sh

set -e

NAMESPACE="cloudage"
SERVICE_NAME="cloudage-service"
MAX_WAIT=300  # 5 minutes
WAIT_INTERVAL=10

echo "🔍 Retrieving application URL..."
echo "Namespace: $NAMESPACE"
echo "Service: $SERVICE_NAME"
echo ""

# Check if service exists
if ! kubectl get svc $SERVICE_NAME -n $NAMESPACE &>/dev/null; then
    echo "❌ Service '$SERVICE_NAME' not found in namespace '$NAMESPACE'"
    echo "Please ensure the application is deployed."
    exit 1
fi

echo "⏳ Waiting for LoadBalancer to be provisioned..."
echo "This may take 2-3 minutes..."
echo ""

elapsed=0
while [ $elapsed -lt $MAX_WAIT ]; do
    # Get the LoadBalancer hostname/IP
    LB_HOSTNAME=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    LB_IP=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "$LB_HOSTNAME" ]; then
        echo "✅ LoadBalancer provisioned!"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🌐 Application URL: http://$LB_HOSTNAME"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📝 You can access your application at the URL above."
        echo "🔄 It may take a few more seconds for the application to be fully ready."
        echo ""
        
        # Test if the URL is accessible
        echo "🧪 Testing connectivity..."
        if curl -s -o /dev/null -w "%{http_code}" "http://$LB_HOSTNAME" | grep -q "200\|301\|302"; then
            echo "✅ Application is accessible!"
        else
            echo "⚠️  LoadBalancer is ready but application may still be starting..."
            echo "   Please wait a moment and try accessing the URL."
        fi
        
        exit 0
    elif [ -n "$LB_IP" ]; then
        echo "✅ LoadBalancer provisioned!"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🌐 Application URL: http://$LB_IP"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        exit 0
    fi
    
    echo "⏳ Still waiting... ($elapsed seconds elapsed)"
    sleep $WAIT_INTERVAL
    elapsed=$((elapsed + WAIT_INTERVAL))
done

echo ""
echo "❌ Timeout waiting for LoadBalancer to be provisioned."
echo ""
echo "Troubleshooting steps:"
echo "1. Check service status:"
echo "   kubectl describe svc $SERVICE_NAME -n $NAMESPACE"
echo ""
echo "2. Check events:"
echo "   kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
echo ""
echo "3. Verify pods are running:"
echo "   kubectl get pods -n $NAMESPACE"
echo ""

exit 1
