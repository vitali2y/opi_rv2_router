#!/bin/bash

# Setting up new secure password, SSH keys only, disable password auth

# forcing user to change password with validation
echo "Please set secure password!"
while true; do
    sudo passwd orangepi && break
    echo "Password change failed, try again"
done

# verify your public key is installed
cat ~/.ssh/authorized_keys

# disable password authentication
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*UsePAM.*/UsePAM no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# verify changes
sudo grep -E "^PasswordAuthentication|^PubkeyAuthentication|^UsePAM" /etc/ssh/sshd_config

# restart SSH service
sudo systemctl restart ssh.service

echo "Done"
