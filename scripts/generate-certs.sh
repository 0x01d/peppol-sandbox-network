#!/bin/bash
set -e

CERT_DIR="$(dirname "$0")/../certs"
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo "=== Generating Local Peppol Test PKI ==="

# Password for all keystores (change in production!)
KEYSTORE_PASS="changeit"

# Validity in days
VALIDITY=3650

echo ""
echo "1. Creating Root CA (for SMP only)..."
openssl genrsa -out ca-key.pem 4096
openssl req -new -x509 -days $VALIDITY -key ca-key.pem -out ca-cert.pem \
    -subj "/C=XX/ST=Test/L=Test/O=Local Peppol Test/OU=Test CA/CN=Local Peppol Test CA"

echo ""
echo "2. Creating SMP certificate (CA-signed)..."
openssl genrsa -out smp-key.pem 2048
openssl req -new -key smp-key.pem -out smp.csr \
    -subj "/C=XX/ST=Test/L=Test/O=Local Peppol Test/OU=SMP/CN=smp.local"
openssl x509 -req -days $VALIDITY -in smp.csr -CA ca-cert.pem -CAkey ca-key.pem \
    -CAcreateserial -out smp-cert.pem

# Create SMP keystore (PKCS12)
openssl pkcs12 -export -in smp-cert.pem -inkey smp-key.pem \
    -certfile ca-cert.pem -out smp-keystore.p12 \
    -name smp -passout pass:$KEYSTORE_PASS

# Convert to JKS for phoss-SMP
keytool -importkeystore \
    -srckeystore smp-keystore.p12 -srcstoretype PKCS12 -srcstorepass $KEYSTORE_PASS \
    -destkeystore smp-keystore.jks -deststoretype JKS -deststorepass $KEYSTORE_PASS \
    -noprompt 2>/dev/null || true

echo ""
echo "3. Creating Access Point 1 certificate (SELF-SIGNED for LOCAL mode)..."
openssl genrsa -out ap1-key.pem 2048
# Create SELF-SIGNED certificate (required for Oxalis LOCAL mode)
openssl req -new -x509 -days $VALIDITY -key ap1-key.pem -out ap1-cert.pem \
    -subj "/C=XX/ST=Test/L=Test/O=Local Peppol Test/OU=AP1/CN=ap1.local"

openssl pkcs12 -export -in ap1-cert.pem -inkey ap1-key.pem \
    -out ap1-keystore.p12 \
    -name ap1 -passout pass:$KEYSTORE_PASS

keytool -importkeystore \
    -srckeystore ap1-keystore.p12 -srcstoretype PKCS12 -srcstorepass $KEYSTORE_PASS \
    -destkeystore ap1-keystore.jks -deststoretype JKS -deststorepass $KEYSTORE_PASS \
    -noprompt 2>/dev/null || true

echo ""
echo "4. Creating Access Point 2 certificate (SELF-SIGNED for LOCAL mode)..."
openssl genrsa -out ap2-key.pem 2048
# Create SELF-SIGNED certificate (required for Oxalis LOCAL mode)
openssl req -new -x509 -days $VALIDITY -key ap2-key.pem -out ap2-cert.pem \
    -subj "/C=XX/ST=Test/L=Test/O=Local Peppol Test/OU=AP2/CN=ap2.local"

openssl pkcs12 -export -in ap2-cert.pem -inkey ap2-key.pem \
    -out ap2-keystore.p12 \
    -name ap2 -passout pass:$KEYSTORE_PASS

keytool -importkeystore \
    -srckeystore ap2-keystore.p12 -srcstoretype PKCS12 -srcstorepass $KEYSTORE_PASS \
    -destkeystore ap2-keystore.jks -deststoretype JKS -deststorepass $KEYSTORE_PASS \
    -noprompt 2>/dev/null || true

echo ""
echo "5. Creating truststore with CA certificate AND AP self-signed certs..."
# Import CA cert
keytool -import -trustcacerts -alias localca -file ca-cert.pem \
    -keystore truststore.jks -storepass $KEYSTORE_PASS -noprompt 2>/dev/null || true

# Import AP1 self-signed cert so AP2 can trust it
keytool -import -trustcacerts -alias ap -file ap1-cert.pem \
    -keystore truststore.jks -storepass $KEYSTORE_PASS -noprompt 2>/dev/null || true

# Import AP2 self-signed cert so AP1 can trust it
keytool -import -trustcacerts -alias ap2 -file ap2-cert.pem \
    -keystore truststore.jks -storepass $KEYSTORE_PASS -noprompt 2>/dev/null || true

# Also create PKCS12 truststore
keytool -importkeystore \
    -srckeystore truststore.jks -srcstoretype JKS -srcstorepass $KEYSTORE_PASS \
    -destkeystore truststore.p12 -deststoretype PKCS12 -deststorepass $KEYSTORE_PASS \
    -noprompt 2>/dev/null || true

echo ""
echo "6. Cleaning up CSR files..."
rm -f *.csr *.srl

echo ""
echo "=== Certificate Generation Complete ==="
echo ""
echo "Files created in $CERT_DIR:"
ls -la
echo ""
echo "Keystore password for all files: $KEYSTORE_PASS"
echo ""
echo "Summary:"
echo "  - ca-cert.pem / ca-key.pem     : Root CA (for SMP)"
echo "  - smp-keystore.jks             : SMP signing keystore (CA-signed)"
echo "  - ap1-keystore.jks             : Access Point 1 keystore (SELF-SIGNED)"
echo "  - ap2-keystore.jks             : Access Point 2 keystore (SELF-SIGNED)"
echo "  - truststore.jks               : Trust store with CA + AP certs"
echo ""
echo "NOTE: AP certificates are SELF-SIGNED for Oxalis LOCAL mode compatibility."
