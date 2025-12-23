#!/bin/bash
# =============================================================================
# Register test participants in the SMP
# Run this after docker-compose up
# =============================================================================

SMP_URL="http://localhost:8080"
SMP_USER="admin@helger.com"
SMP_PASS="password"

# Test participant IDs (using test identifier scheme)
PARTICIPANT_1="9915:test-sender-001"
PARTICIPANT_2="9915:test-receiver-001"

# Document type and process (BIS Billing 3.0 Invoice)
DOC_TYPE="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2::Invoice##urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0::2.1"
PROCESS_ID="urn:fdc:peppol.eu:2017:poacc:billing:01:1.0"

echo "=== Registering Test Participants in SMP ==="
echo ""

# Function to register a service group (participant)
register_participant() {
    local participant_id=$1
    local endpoint_url=$2
    local cert_file=$3
    
    echo "Registering participant: $participant_id"
    echo "  Endpoint: $endpoint_url"
    
    # URL encode the participant ID for the URL path
    local encoded_id=$(echo -n "$participant_id" | sed 's/:/%3A/g')
    
    # Create service group with CORRECT namespaces
    # Note: ParticipantIdentifier must use the id: namespace prefix
    echo "  Creating service group..."
    curl -s -X PUT \
        -u "$SMP_USER:$SMP_PASS" \
        -H "Content-Type: application/xml" \
        -d '<?xml version="1.0" encoding="UTF-8"?>
<smp:ServiceGroup xmlns:smp="http://busdox.org/serviceMetadata/publishing/1.0/" xmlns:id="http://busdox.org/transport/identifiers/1.0/">
  <id:ParticipantIdentifier scheme="iso6523-actorid-upis">'"$participant_id"'</id:ParticipantIdentifier>
  <smp:ServiceMetadataReferenceCollection/>
</smp:ServiceGroup>' \
        "$SMP_URL/iso6523-actorid-upis%3A%3A$encoded_id"
    
    echo ""
    echo "  Service group created."
    
    # Read certificate (base64 encoded, no headers)
    local cert_b64=""
    if [ -f "$cert_file" ]; then
        cert_b64=$(grep -v '^-----' "$cert_file" | tr -d '\n')
    else
        echo "  Warning: Certificate file not found: $cert_file"
        cert_b64="ZHVtbXk="  # base64 of "dummy"
    fi
    
    # URL encode the document type
    local encoded_doctype=$(echo -n "$DOC_TYPE" | sed 's/:/%3A/g; s/#/%23/g')
    
    # Register service metadata (endpoint info) with CORRECT namespaces
    echo "  Registering service metadata..."
    curl -s -X PUT \
        -u "$SMP_USER:$SMP_PASS" \
        -H "Content-Type: application/xml" \
        -d '<?xml version="1.0" encoding="UTF-8"?>
<smp:ServiceMetadata xmlns:smp="http://busdox.org/serviceMetadata/publishing/1.0/" xmlns:id="http://busdox.org/transport/identifiers/1.0/" xmlns:wsa="http://www.w3.org/2005/08/addressing">
  <smp:ServiceInformation>
    <id:ParticipantIdentifier scheme="iso6523-actorid-upis">'"$participant_id"'</id:ParticipantIdentifier>
    <id:DocumentIdentifier scheme="busdox-docid-qns">'"$DOC_TYPE"'</id:DocumentIdentifier>
    <smp:ProcessList>
      <smp:Process>
        <id:ProcessIdentifier scheme="cenbii-procid-ubl">'"$PROCESS_ID"'</id:ProcessIdentifier>
        <smp:ServiceEndpointList>
          <smp:Endpoint transportProfile="peppol-transport-as4-v2_0">
            <wsa:EndpointReference>
              <wsa:Address>'"$endpoint_url"'</wsa:Address>
            </wsa:EndpointReference>
            <smp:RequireBusinessLevelSignature>false</smp:RequireBusinessLevelSignature>
            <smp:Certificate>'"$cert_b64"'</smp:Certificate>
            <smp:ServiceDescription>Test AS4 Endpoint</smp:ServiceDescription>
            <smp:TechnicalContactUrl>mailto:test@local</smp:TechnicalContactUrl>
          </smp:Endpoint>
        </smp:ServiceEndpointList>
      </smp:Process>
    </smp:ProcessList>
  </smp:ServiceInformation>
</smp:ServiceMetadata>' \
        "$SMP_URL/iso6523-actorid-upis%3A%3A$encoded_id/services/busdox-docid-qns%3A%3A$encoded_doctype"
    
    echo ""
    echo "  Service metadata registered."
    echo ""
}

# Wait for SMP to be ready
echo "Waiting for SMP..."
until curl -sf "$SMP_URL/" > /dev/null 2>&1; do
    sleep 2
done
echo "SMP is ready!"
echo ""

# Register participants
# Note: AP1 is at port 8081, AP2 at port 8082 (inside Docker network: ap1:8080, ap2:8080)
register_participant "$PARTICIPANT_1" "http://ap1:8080/as4" "./certs/ap1-cert.pem"
register_participant "$PARTICIPANT_2" "http://ap2:8080/as4" "./certs/ap2-cert.pem"

echo "=== Registration Complete ==="
echo ""
echo "Registered participants:"
echo "  - $PARTICIPANT_1 -> AP1 (http://localhost:8081)"
echo "  - $PARTICIPANT_2 -> AP2 (http://localhost:8082)"
echo ""
echo "You can verify in the SMP UI at: $SMP_URL"
echo "Login: $SMP_USER / $SMP_PASS"
