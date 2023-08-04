#!/bin/bash
sudo apt-get update
sudo apt-get install unzip

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
sudo apt-get install apt-transport-https -y
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
sudo apt-get update && sudo apt-get install kibana -y

tee /etc/kibana/kibana.yml <<EOF
server.port: 5601
server.host: "0.0.0.0"
elasticsearch.hosts: ["http://${lb_dns_name}:9200"]

logging:
  appenders:
    file:
      type: file
      fileName: /var/log/kibana/kibana.log
      layout:
        type: json
  root:
    appenders:
      - default
      - file

EOF

sudo /bin/systemctl daemon-reload
sudo systemctl enable kibana.service
sudo systemctl start kibana.service


