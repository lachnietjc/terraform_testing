#!/bin/bash

set -x
exec > >(tee /var/log/user-data.log|logger -t user-data ) 2>&1
echo BEGIN
date '+%Y-%m-%d %H:%M:%S'

sudo apt install default-jdk -y 
sudo apt install scala -y 
sudo apt install git -y
sudo apt install jupyter -y 
sudo apt install python3 -y
sudo apt install python3-pip
sudo pip3 install pandas 
sudo pip3 install sqlalchemy

# installs helper for file system mount
sudo apt install nfs-common -y

# install azure cli
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -


#Ubuntu 18.04
sudo curl https://packages.microsoft.com/config/ubuntu/18.04/prod.list > /etc/apt/sources.list.d/mssql-release.list

sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql17
# optional: for bcp and sqlcmd
sudo ACCEPT_EULA=Y apt-get install -y mssql-tools
sudo echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.profile
source root/.profile
# optional: for unixODBC development headers
sudo apt-get install -y unixodbc-dev

sudo pip3 install pyodbc

sudo mount -o sec=sys,vers=3,nolock,proto=tcp hbvmount.blob.core.windows.net:/hbvmount/sparkvm  /mnt/sparkvm

sudo wget https://downloads.apache.org/spark/spark-3.2.0/spark-3.2.0-bin-hadoop2.7.tgz

sudo tar xvf spark-*

sudo mv spark-3.2.0-bin-hadoop2.7 /opt/spark

sudo echo "export SPARK_HOME=/opt/spark" >> ~/.bashrc
sudo echo "export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin" >> ~/.bashrc
sudo echo "export PYSPARK_PYTHON=/usr/bin/python3" >> ~/.bachrc

sudo source ~/.bashrc
echo END
date '+%Y-%m-%d %H:%M:%S'