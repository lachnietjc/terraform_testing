#!/bin/bash

set -x
exec > >(tee /var/log/user-data.log|logger -t user-data ) 2>&1
echo BEGIN
date '+%Y-%m-%d %H:%M:%S'

##Update packages
sudo add-apt-repository universe
sudo apt-get update
sudo snap install jq
sudo apt-get --ignore-missing install -y ca-certificates \
                        curl \
                        gnupg \
                        lsb-release 

sudo apt install -y python3-pip

export PATH="$HOME/.local/bin:$PATH"

sudo curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -

sudo curl https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list > /etc/apt/sources.list.d/mssql-release.list

sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql17
# optional: for bcp and sqlcmd
sudo ACCEPT_EULA=Y apt-get install -y mssql-tools
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc
# optional: for unixODBC development headers
sudo apt-get install -y unixodbc-dev

sudo pip install pandas
sudo pip install pendulum
sudo pip install "dask[complete]"
sudo pip install pyarrow
sudo pip install adlfs

pip3 install -r requirements.txt

## Installs helper for file system mount
sudo apt install nfs-common -y

mkdir -p /mnt/sparkvm /mnt/app

sudo chmod -R 777 /mnt

curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# ## Download docker and update
# echo \
#   "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
#   $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# sudo apt-get update
# sudo apt install docker-ce docker-ce-cli containerd.io -y 
# sudo docker pull jupyter/pyspark-notebook

cd /mnt/app

## Get azure devops pwd from keyvault
token="your token "
devops_pwd=$(curl '{url_to_secrets_in_keyvault}?api-version=2016-10-01' -H "Authorization: Bearer $token" | jq -r ".value")
devops_pwd_b64=$(printf "%s"":$devops_pwd" | base64)


export client_id=$(curl '{url_to_secrets_in_keyvault}?api-version=2016-10-01' -H "Authorization: Bearer $token" | jq -r ".value")
export client_secret=$(curl '{url_to_secrets_in_keyvault}?api-version=2016-10-01' -H "Authorization: Bearer $token" | jq -r ".value")
export tenant_id=$(curl '{url_to_secrets_in_keyvault}?api-version=2016-10-01' -H "Authorization: Bearer $token" | jq -r ".value")
export devops_artifact_secret=$(curl '{url_to_secrets_in_keyvault}?api-version=2016-10-01' -H "Authorization: Bearer $token" | jq -r ".value")

sudo touch /etc/pip.conf 
sudo chmod 777 etc/pip.conf

sudo echo \
"[global]
extra-index-url={url_to_artifact}" > /etc/pip.conf

sudo chmod 777 /etc/ssl/openssl.cnf
sudo sed -i '1i openssl_conf = default_conf' /etc/ssl/openssl.cnf

sudo echo -e '[default_conf]\nssl_conf = ssl_sect\n\n[ssl_sect]\nsystem_default = system_default_sect\n\n[system_default_sect]\nMinProtocol = TLSv1\nCipherString = DEFAULT@SECLEVEL=1' >> /etc/ssl/openssl.cnf

sudo chmod -R 777 /mnt

sudo mount -o sec=sys,vers=3,nolock,proto=tcp {storage_account}.blob.core.windows.net:/hbvmount/sparkvm  /mnt/sparkvm








