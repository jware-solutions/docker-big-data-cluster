#!/bin/bash
service ssh start

# NOTE: SPARK_VERSION and HADOOP_HOME are defined in Dockerfile

echo "Starting HDFS and Yarn"
$HADOOP_HOME/sbin/start-dfs.sh
sleep 5
$HADOOP_HOME/sbin/start-yarn.sh
sleep 5

if [[ $1 = "start" ]]; then
    if [[ $2 = "master-node" ]]; then
        /opt/spark-${SPARK_VERSION}-bin-hadoop3/sbin/start-master.sh

        # Starts history server to check running and completed applications
        ${HADOOP_HOME}/bin/hdfs dfs -mkdir -p /spark-logs
        /opt/spark-${SPARK_VERSION}-bin-hadoop3/sbin/start-history-server.sh

        # Disables safe mode to prevent errors in small clusters
        # ${HADOOP_HOME}/bin/hdfs dfsadmin -safemode leave

        sleep infinity
        exit
    fi
    
    # Sleeps to prevent connection issues with master
    sleep 5
    /opt/spark-${SPARK_VERSION}-bin-hadoop3/sbin/start-worker.sh master-node:7077
    sleep infinity
    exit
fi

if [[ $1 = "stop" ]]; then
    if [[ $2 = "master-node" ]]; then
        /opt/spark-${SPARK_VERSION}-bin-hadoop3/sbin/stop-master.sh
        exit
    fi
    /opt/spark-${SPARK_VERSION}-bin-hadoop3/sbin/stop-worker.sh
fi
