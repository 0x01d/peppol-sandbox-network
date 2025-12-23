#!/bin/bash
# =============================================================================
# Send a test message using curl to the AS4 endpoint
# This is a simplified test - real AS4 messages require proper SOAP/ebMS3 formatting
# =============================================================================

set -e

echo "=== Testing Peppol Sandbox Connectivity ==="
echo ""

# Check SMP is responding
echo "1. Checking SMP..."
if curl -sf http://localhost:8080/ > /dev/null; then
    echo "   ✓ SMP is running at http://localhost:8080"
else
    echo "   ✗ SMP is not responding"
    exit 1
fi

# Check AP1 is responding
echo ""
echo "2. Checking AP1..."
if curl -sf http://localhost:8081/status > /dev/null 2>&1 || curl -sf http://localhost:8081/ > /dev/null 2>&1; then
    echo "   ✓ AP1 is running at http://localhost:8081"
else
    echo "   ? AP1 may still be starting up"
fi

# Check AP2 is responding  
echo ""
echo "3. Checking AP2..."
if curl -sf http://localhost:8082/status > /dev/null 2>&1 || curl -sf http://localhost:8082/ > /dev/null 2>&1; then
    echo "   ✓ AP2 is running at http://localhost:8082"
else
    echo "   ? AP2 may still be starting up"
fi

# Query SMP for a registered participant
echo ""
echo "4. Querying SMP for test-receiver-001..."
RESULT=$(curl -sf "http://localhost:8080/iso6523-actorid-upis%3A%3A9915%3Atest-receiver-001" 2>/dev/null || echo "NOT_FOUND")
if [[ "$RESULT" != "NOT_FOUND" ]]; then
    echo "   ✓ Participant found in SMP"
else
    echo "   ✗ Participant not found - run ./scripts/register-participants.sh first"
fi

echo ""
echo "=== Sandbox Status Complete ==="
echo ""
echo "To send actual AS4 messages, you can use:"
echo "  - Oxalis Standalone CLI (if installed locally)"
echo "  - A SOAP client with proper ebMS3 message formatting"
echo "  - The phase4 sender library"
echo ""
echo "For testing the full flow, consider:"
echo "  1. Register participants: ./scripts/register-participants.sh"
echo "  2. Use an external AS4 client to send to http://localhost:8081/as4"
echo "  3. Check received files: docker exec peppol-ap2 ls -la /var/peppol/inbound/"
