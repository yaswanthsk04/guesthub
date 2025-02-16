# Set environment variables
export GITHUB_TOKEN="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"
export FAS_KEY="f4152310efff553b26a517879460619bdc2cb1c2b6fc99e7ea67f4309b51fff2"
export FAS_REMOTE_IP="50.85.249.191"
export FAS_PATH="/captiveportal.php"
export TAILSCALE_AUTH_KEY="tskey-auth-ktaLDbZpA121CNTRL-GyN99QQRXsNf3vrh5rxjsNAxxHaqi7ABG"



# Configure IP settings
uci set network.lan.ipaddr='192.168.98.1'
uci set network.lan.netmask='255.255.254.0'
uci commit network
service network restart

# Download the setup script using the environment variable
curl -H "Authorization: token ${GITHUB_TOKEN}" -L -o setup-script.sh "https://raw.githubusercontent.com/yaswanthsk04/guesthub/v0.6.0/scripts/setup/setup-setup.sh"

# Make the script executable
chmod +x setup-script.sh

# Execute the setup script
./setup-script.sh
