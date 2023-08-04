#!/bin/bash
sudo apt-get update
sudo apt-get install unzip

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# installing elastic
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
sudo apt-get install apt-transport-https -y
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
sudo apt-get update && sudo apt-get install elasticsearch -y

# if data node - create /data folder, format the data volume and mount /data to the data volume
export node_role=`curl http://169.254.169.254/latest/meta-data/tags/instance/Role`
if [ "$node_role" = "es-data" ]; then
  sudo mkdir /data
  export unmounted=`lsblk  --noheadings --raw | awk '{print substr($0,0,4)}' | uniq -c | grep 1 | awk '{print "/dev/"$2}'`
  sudo mkfs.xfs $unmounted
  export device_uuid=`sudo blkid | grep $unmounted | awk '{print $2}'`
  echo "$device_uuid /data xfs defaults 0 1" | sudo tee -a /etc/fstab
  sudo mount -a
fi

# configure jvm options
# see https://www.elastic.co/guide/en/elasticsearch/reference/current/advanced-configuration.html#set-jvm-heap-size
sudo sed -i 's/## -Xms4g/-Xms4g/g' /etc/elasticsearch/jvm.options 
sudo sed -i 's/## -Xmx4g/-Xmx4g/g' /etc/elasticsearch/jvm.options 
sudo sed -i 's/Type=notify/Type=notify\nLimitMEMLOCK=infinity/g' /usr/lib/systemd/system/elasticsearch.service

# get the node name to specify in elastic.yml
export node_name=`curl http://169.254.169.254/latest/meta-data/tags/instance/Name`

# create elastic.yml
# even though it's using EC2 plugin, we must specify cluster.initial_master_nodes
# each master node name is the name given to it in the config itself
tee /etc/elasticsearch/elasticsearch.yml <<EOF
cluster.name: es-cluster
cluster.initial_master_nodes:
  - es-master-1
  - es-master-2
  - es-master-3

node.name: ${node_name}
node.roles: [${role}]

path.data: ${data_path}
path.logs: /var/log/elasticsearch

bootstrap.memory_lock: true

network.host: 0.0.0.0
http.port: 9200

discovery.ec2.tag.cluster_name: es-cluster
discovery.ec2.endpoint: ec2.us-east-1.amazonaws.com
discovery.seed_providers: ec2
discovery.ec2.protocol: http
discovery.ec2.host_type: private_ip

xpack.security.enabled: false
xpack.security.transport.ssl.enabled: false
xpack.security.http.ssl.enabled: false

EOF

sudo /bin/systemctl daemon-reload
sudo /usr/share/elasticsearch/bin/elasticsearch-plugin install --batch discovery-ec2

# changing /data folder ownership to elasticsearch user and group
if [ "$node_role" = "es-data" ]; then
  sudo chown elasticsearch:elasticsearch /data
fi

sudo systemctl enable elasticsearch.service
sudo systemctl start elasticsearch.service


