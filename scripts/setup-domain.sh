#!/bin/bash
SCRIPT_DIR=$(dirname "$0")
source "${SCRIPT_DIR}/local-env.sh"

DRY_RUN=""
TEST_CERT=""

# Function to display usage
usage() {
    echo "Usage: $0 [-t] <domain>" >&2
    echo "  -t, --test-cert    Perform a test run with Certbot" >&2
}

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -t|--test-run) TEST_CERT="--test-cert"; shift ;;
        *) DOMAIN="${1}"; shift ;;
    esac
done

# Check if domain is provided
if [ -z "$DOMAIN" ]; then
    usage >&2
    exit 1
fi

# Function to check certificates
check_certificate() {
    local domain=$1
    if certbot --config-dir "$CERTS_DIR" --work-dir "$CERTS_DIR" --logs-dir="$CERTS_DIR" certificates --register-unsafely-without-email -d "$domain" 2>/dev/null | grep -q "VALID"; then
        echo "Certificate for $domain is valid." >&2
        return 0
    else
        echo "Certificate for $domain is not valid or does not exist." >&2
        return 1
    fi
}

# Function to obtain/renew certificate
obtain_certificate() {
    local domain=$1
    echo "Obtaining certificate for $domain..." >&2
    certbot --config-dir "$CERTS_DIR" --work-dir "$CERTS_DIR" --logs-dir="$CERTS_DIR" certonly --manual --register-unsafely-without-email --preferred-challenges=dns -d "$domain" $TEST_CERT
}

# Check and renew certificates for DOMAIN
if ! check_certificate "$DOMAIN"; then
    obtain_certificate "$DOMAIN"
fi

# Return the paths of the SSL certificates
fullchain_path="$CERTS_DIR/live/$DOMAIN/fullchain.pem"
privkey_path="$CERTS_DIR/live/$DOMAIN/privkey.pem"
echo "$fullchain_path"
echo "$privkey_path"

echo "Certificate setup completed for $DOMAIN." >&2
