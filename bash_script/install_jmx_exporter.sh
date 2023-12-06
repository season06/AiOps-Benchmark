#!/bin/bash

wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.19.0/jmx_prometheus_javaagent-0.19.0.jar

# Setup the config
cat << EOF | tee ~/jvm_exporter_config.yaml
rules:
- pattern: ".*"
EOF

# Set the environment variables of the JMX exporter agent. When the PetClinic server is executed, maven will automatically load it.
cat << EOF | tee -a ~/.profile
MAVEN_OPTS="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.util.logging.config.file=logging.properties -javaagent:$HOME/jmx_prometheus_javaagent-0.19.0.jar=12345:$HOME/jvm_exporter_config.yaml"
EOF
source ~/.profile

echo "Install Success"