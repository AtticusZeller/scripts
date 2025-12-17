
#!/bin/bash

CF_Domain="domain"
certPath="/etc/ssl"
export CF_Token="zone_dns_token"
export CF_Account_ID="account_id"


# Issue the certificate using Cloudflare DNS
~/.acme.sh/acme.sh --issue --dns dns_cf -d "${CF_Domain}" -d "*.${CF_Domain}" --log --force
if [ $? -ne 0 ]; then
    echo "Certificate issuance failed, script exiting..."
    exit 1
else
    echo "Certificate issued successfully, Installing..."
fi


# Install the certificate
mkdir -p ${certPath}/certs
mkdir -p ${certPath}/private
if [ $? -ne 0 ]; then
    echo "Failed to create directory: ${certPath}, script exiting..."
    exit 1
fi

~/.acme.sh/acme.sh --installcert -d "${CF_Domain}" -d "*.${CF_Domain}" \
    --fullchain-file ${certPath}/certs/${CF_Domain}.fullchain.pem \
    --key-file ${certPath}/private/${CF_Domain}.key \
    --reloadcmd "cd ~/librechat && docker compose restart traefik" \
    --force