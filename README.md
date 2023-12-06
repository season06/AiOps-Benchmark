# AiOps Benchmark, collect metrics and logs

## Infrastructure Environment
The experiment is built on the AWS cloud platform. The main services we use including:
- Launch **AWS EC2** to create a three servers
    - one for backend (PetClinic)
    - one for database (MariaDB)
    - one for monitoring (Prometheus & Grafana)
- Set **Security Group** to control the inbound and outbound traffic
- Allocate **Elastic IP** to get static and public IPv4 address

### Launch AWS EC2
- First, navigate to the EC2 Instance page 
- Next, click `Launch Instance`
- Then, fill in the information below:
    - OS Image: Ubuntu 22.04
    - Instance Type: t2 medium (2 vCPU, 4 GiB Memory)
    - Create a **Key Pair** to connect the instance remotely by SSH
    - Select existing **security group** (refer to next section)

### Set Security Group
The security group acts as a virtual firewall. The traffic that reaches the instance which is allowed by the security group rules. According to the principle of least privilege, we only open the necessary ports to the specific IP address.

- First, navigate to the Security Groups page 
- Next, click `Create security group`
- Then, create three security groups according to the information below:
    - Backend
        - Type: SSH, Port: 22
        - Type: HTTP, Port: 80
        - Type: HTTPS, Port: 443
        - Type: Custom TCP, Port: 9966 (PetClinic)
        - Type: Custom TCP, Port: 12345 (JVM Exporter)
        - Type: Custom TCP, Port: 9100 (Prometheus Node Exporter)
    - Database
        - Type: SSH, Port: 22
        - Type: MYSQL, Port: 3306
        - Type: Custom TCP, Port: 9104 (Mysqld Exporter)
        - Type: Custom TCP, Port: 9100 (Prometheus Node Exporter)
    - Monitoring
        - Type: SSH, Port: 22
        - Type: Custom TCP, Port: 9090 (Prometheus Server)
        - Type: Custom TCP, Port: 9100 (Prometheus Node Exporter)
        - Type: Custom TCP, Port: 3000 (Grafana)

### Allocate Elastic IP
- First, navigate to the Elastic IPs page 
- Next, click `Allocate Elastic IP` in AWS Dashboard, then `Allocate`
- Finally, click `Associate Elastic IP address` in Actions
    - Select the EC2 instance you want to associate
    - Then `Associate`

In EC2 instance dashboard, You can see that the instance has a static IP you created via Elastic IP, rather than a dynamic IP.

## Install Services
After setting up EC2 instances successfully, please connect to the server remotely and install specific services on each server.

> How to connect server by SSH?  
> 1. Download the key pair you created when created the EC2 instance  
> 2. Use the `ssh -i {Key_Name}.pem ubuntu@{Server_IP}` to establish a connection  
> - Note: Traffic is allowed through port `22` due to security group rules

### SetUp Database
- Install MySQL server
```bash
sudo apt update -y
sudo apt install mysql-server -y
sudo systemctl enable mysql.service
sudo systemctl start mysql.service

# Check MySQL status
sudo systemctl status mysql.service
```
- Grant privileges
```Bash
# login as root
sudo mysql -uroot

# Set password
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password';
```

> Then you can login to MySQL server by `mysql -u root -p` with the password.

### Setup Backend Server - PetClinic
- Install dependency
```bash
sudo apt update -y

# install java
sudo apt install openjdk-17-jdk -y
java -version

# install maven
sudo apt install maven -y
mvn --version
```
- Install [PetClinic]((https://github.com/spring-petclinic/spring-petclinic-rest))  
```bash
# clone from GitHub
git clone https://github.com/spring-petclinic/spring-petclinic-rest.git
```
- Edit database infomation
```bash
vim ~/spring-petclinic-rest/src/main/resources/application.properties

# Edit DB type, change with:
spring.profiles.active=mysql,spring-data-jpa

# Edit DB login info, change with:
spring.datasource.url = jdbc:mysql://{DB_Server_IP}:3306/petclinic?useUnicode=true
spring.datasource.username={DB_Username}
spring.datasource.password={DB_Password}
```
- Run the server
```bash
cd spring-petclinic-rest
./mvnw spring-boot:run
```
- Check via web  
`http://{Backend_Server_IP}:9966/petclinic`
> Note: Traffic is allowed through port `9966` due to security group rules

### Setup Monitoring System
- What is [Prometheus](https://prometheus.io/docs/introduction/overview/)?  
  Prometheus is an open-source systems monitoring that can effectively obtain performance matrics. The main features are:
  - Use a pull-model to scrape metrics from the targets that expose an HTTP endpoint, that is the reason why we need to install exporter in the target server and open the port
  - Targets are discovered via service discovery or static configuration
  - PromQL, a flexible query language like SQL, can be used to query the matrics data

- What is [Grafana](https://grafana.com/docs/grafana/latest/fundamentals/)?  
  Grafana is an open-source visualization and analytics software. It allows users to query, visualize, and explore metrics, logs, and traces. But in our case, visualization is optional since we only need to export the metrics data into csv file.

#### Install Prometheus and Exporter
The installation commands have been packaged into automated scripts, please clone this repository and execute on the servers:
```bash
git clone https://github.com/season06/AiOps-Benchmark.git

chmod +x bash_script/*.sh
```

##### In Backend Server:
[JMX Exporter](https://github.com/prometheus/jmx_exporter)
```bash
./bash_script/install_node_exporter.sh
./bash_script/install_jmx_exporter.sh
```

##### In Database Server:
[Mysqld Exporter](https://github.com/prometheus/mysqld_exporter)
```bash
./bash_script/install_node_exporter.sh
./bash_script/install_mysqld_exporter.sh
```
- Login to MySQL server and grant the permission manually
```bash
mysql -u root -p

# Grant Permission in MySQL Server
CREATE USER 'prom_exporter'@'localhost' IDENTIFIED BY 'password' WITH MAX_USER_CONNECTIONS 3;
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'prom_exporter'@'localhost';

# run
cd mysqld_exporter-0.15.0.linux-amd64
./mysqld_exporter
```

##### In Monitoring Server:
```bash
./bash_script/install_prometheus.sh
./bash_script/install_node_exporter.sh

# install grafana (optional)
./bash_script/install_grafana.sh
```
- Configure the target servers in `prometheus.yml`
```bash
./config_promethues.sh {Backend_IP} {Database_IP}
```
> If the setup is successful, check the status of the monitored target servers in Prometheus Dashboard: `http://{Monitoring_Server_IP}:9090/targets`  
> Grafana Dashboard: `http://{Monitoring_Server_IP}:3000`  

### Enable Tomcat Log
```bash
vim ~/spring-petclinic-rest/src/main/resources/application.properties

# Add the following setting
server.tomcat.accesslog.enabled=true
server.tomcat.accesslog.directory=/var/log/tomcat
server.tomcat.accesslog.pattern=%h %t "%r" %s %b %D %F

# Create folder and change the file owner
sudo mkdir /var/log/tomcat
sudo chown -hR ubuntu:ubuntu /var/log/tomcat
```
- Values for the pattern attribute
  - `%t` - Date and time, in Common Log Format
  - `%r` - First line of the request (method and request URI)
  - `%s` - HTTP status code of the response
  - `%b` - Bytes sent, excluding HTTP headers, or '-' if zero
  - `%D` - Time taken to process the request, in millis
  - `%F` - Time taken to commit the response, in millis
  > For more pattern attributes, please refer to [Apache Tomcat 8 Configuration Reference](https://tomcat.apache.org/tomcat-8.0-doc/config/valve.html)
