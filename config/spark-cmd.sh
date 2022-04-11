#!/bin/bash
service ssh start

echo "Starting HDFS and Yarn"
$HADOOP_HOME/sbin/start-dfs.sh
sleep 5
$HADOOP_HOME/sbin/start-yarn.sh
sleep 5

if [[ $1 = "start" ]]; then
    if [[ $2 = "master-node" ]]; then
        /sbin/spark-3.1.2-bin-without-hadoop/sbin/start-master.sh

        # Starts history server to check running and completed applications
        /usr/local/hadoop/bin/hdfs dfs -mkdir -p /spark-logs
        /sbin/spark-3.1.2-bin-without-hadoop/sbin/start-history-server.sh

        sleep infinity
        exit
    fi
    
    # Sleeps to prevent connection issues with master
    sleep 5
    /sbin/spark-3.1.2-bin-without-hadoop/sbin/start-worker.sh master-node:7077
    sleep infinity
    exit
fi

if [[ $1 = "stop" ]]; then
    if [[ $2 = "master-node" ]]; then
        /sbin/spark-3.1.2-bin-without-hadoop/sbin/stop-master.sh
        exit
    fi
    /sbin/spark-3.1.2-bin-without-hadoop/sbin/stop-worker.sh
fi
