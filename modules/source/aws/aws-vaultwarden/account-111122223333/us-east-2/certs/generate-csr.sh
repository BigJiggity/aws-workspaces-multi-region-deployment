#!/bin/bash
# ==============================================================================
# Generate CSR and Private Key for vw.example.com
# ==============================================================================

set -e

DOMAIN="vw.example.com"
KEY_FILE="vw.example.com.key"
CSR_FILE="vw.example.com.csr"
CONFIG_FILE="vw.example.com.cnf"

cd "$(dirname "$0")"

echo "Generating private key and CSR for ${DOMAIN}..."

# Create OpenSSL config for CSR
cat > "${CONFIG_FILE}" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = US
ST = Texas
L = Houston
O = Example Corp
OU = IT
CN = ${DOMAIN}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
EOF

# Generate private key (RSA 2048-bit)
openssl genrsa -out "${KEY_FILE}" 2048

# Generate CSR
openssl req -new -key "${KEY_FILE}" -out "${CSR_FILE}" -config "${CONFIG_FILE}"

# Set secure permissions on private key
chmod 600 "${KEY_FILE}"

echo ""
echo "=============================================================================="
echo "Files generated:"
echo "  Private Key: ${KEY_FILE}"
echo "  CSR:         ${CSR_FILE}"
echo "  Config:      ${CONFIG_FILE}"
echo "=============================================================================="
echo ""
echo "CSR Contents:"
echo "=============================================================================="
cat "${CSR_FILE}"
echo ""
echo "=============================================================================="
echo ""
echo "CSR Details:"
echo "=============================================================================="
openssl req -in "${CSR_FILE}" -noout -text | head -20
echo ""
echo "=============================================================================="
echo ""
echo "Next steps:"
echo "  1. Submit the CSR to your CA to get it signed"
echo "  2. Once you have the certificate, import to ACM:"
echo ""
echo "     aws acm import-certificate \\"
echo "       --certificate fileb://vw.example.com.crt \\"
echo "       --private-key fileb://vw.example.com.key \\"
echo "       --certificate-chain fileb://ca-chain.crt \\"
echo "       --region us-east-2"
echo ""
echo "  3. Update the ALB listener to use the imported certificate ARN"
echo "=============================================================================="
