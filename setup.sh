#!/bin/bash

# Ensure environment variables are available
set -a
source .env
set +a

# Create the wireguard directory if it doesn't exist
mkdir -p wireguard

# Step 1: Generate the server private and public keys if they don't exist
cd wireguard
if [ ! -f server_privatekey ]; then
    wg genkey | tee server_privatekey | wg pubkey >server_publickey
    echo "Server private and public keys generated."
else
    echo "Server private and public keys already exist."
fi

# Step 2: Generate keys for MacBook if they don't exist
if [ ! -f macbook_client_privatekey ]; then
    wg genkey | tee macbook_client_privatekey | wg pubkey >macbook_client_publickey
    echo "MacBook private and public keys generated."
else
    echo "MacBook private and public keys already exist."
fi

# Step 3: Generate keys for Phone if they don't exist
if [ ! -f phone_client_privatekey ]; then
    wg genkey | tee phone_client_privatekey | wg pubkey >phone_client_publickey
    echo "Phone private and public keys generated."
else
    echo "Phone private and public keys already exist."
fi

# Step 4: Read the keys into variables
SERVER_PRIVATE_KEY=$(cat server_privatekey)
SERVER_PUBLIC_KEY=$(cat server_publickey)
MACBOOK_PUBLIC_KEY=$(cat macbook_client_publickey)
PHONE_PUBLIC_KEY=$(cat phone_client_publickey)

# Step 5: Update or add these values in the .env file
echo "Updating the .env file with the generated keys..."
sed -i '' "s|^SERVER_PRIVATE_KEY=.*|SERVER_PRIVATE_KEY=${SERVER_PRIVATE_KEY}|" ../.env || echo "SERVER_PRIVATE_KEY=${SERVER_PRIVATE_KEY}" >>../.env
sed -i '' "s|^SERVER_PUBLIC_KEY=.*|SERVER_PUBLIC_KEY=${SERVER_PUBLIC_KEY}|" ../.env || echo "SERVER_PUBLIC_KEY=${SERVER_PUBLIC_KEY}" >>../.env
sed -i '' "s|^MACBOOK_PUBLIC_KEY=.*|MACBOOK_PUBLIC_KEY=${MACBOOK_PUBLIC_KEY}|" ../.env || echo "MACBOOK_PUBLIC_KEY=${MACBOOK_PUBLIC_KEY}" >>../.env
sed -i '' "s|^PHONE_PUBLIC_KEY=.*|PHONE_PUBLIC_KEY=${PHONE_PUBLIC_KEY}|" ../.env || echo "PHONE_PUBLIC_KEY=${PHONE_PUBLIC_KEY}" >>../.env

echo "Environment variables updated in .env file."

# Step 6: Export the variables to ensure they are available for substitution
export SERVER_PRIVATE_KEY=${SERVER_PRIVATE_KEY}
export SERVER_PUBLIC_KEY=${SERVER_PUBLIC_KEY}
export MACBOOK_PUBLIC_KEY=${MACBOOK_PUBLIC_KEY}
export PHONE_PUBLIC_KEY=${PHONE_PUBLIC_KEY}
export SERVERPORT=${SERVERPORT}

# Step 7: Generate the WireGuard configuration file (`wg0.conf`) from the template
echo "Generating WireGuard configuration file (wg0.conf)..."
envsubst <../wireguard.conf.template >wg0.conf
echo "WireGuard configuration generated at wireguard/wg0.conf."

cd ..

# Step 8: Start the WireGuard container to generate initial configs
echo "Starting WireGuard container..."
docker compose up -d wireguard

# Step 9: Wait for the WireGuard container to initialize
echo "Waiting for WireGuard container to initialize..."
sleep 10

# Step 10: Retrieve the client configurations for your devices
echo "Copying peer configurations from the container to the host..."
docker compose cp wireguard_vpn:/config/peer1/peer1.conf ./wireguard/macbook-client.conf
docker compose cp wireguard_vpn:/config/peer2/peer2.conf ./wireguard/phone-client.conf

# Verify that the files were successfully copied
if [ -f wireguard/macbook-client.conf ] && [ -f wireguard/phone-client.conf ]; then
    echo "Successfully copied 'macbook-client.conf' and 'phone-client.conf' to the host."
else
    echo "Failed to copy client configuration files. Please check the container logs for more details."
    exit 1
fi

echo "WireGuard setup complete!"
echo "Download 'macbook-client.conf' for your MacBook and 'phone-client.conf' for your phone."
echo "Start the services using 'docker compose up -d' to begin routing traffic through mitmproxy."
