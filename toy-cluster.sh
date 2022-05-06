#!/bin/bash

imageName="jwaresolutions/big-data-cluster:0.4.1"

# Bring the services up
function startServices {
  docker start master-node worker-1 worker-2 worker-3
  sleep 5
  echo ">> Starting Master and Workers ..."
  docker exec -d master-node /home/big_data/spark-cmd.sh start master-node
  docker exec -d worker-1 /home/big_data/spark-cmd.sh start
  docker exec -d worker-2 /home/big_data/spark-cmd.sh start
  docker exec -d worker-3 /home/big_data/spark-cmd.sh start
  show_info
}

function show_info {
  masterIp=`docker inspect -f "{{ .NetworkSettings.Networks.cluster_net.IPAddress }}" master-node`
  echo "Hadoop info @ master-node: http://$masterIp:8088/cluster"
  echo "Spark info @ master-node:  http://$masterIp:8080/"
  echo "Spark applications logs @ master-node:  http://$masterIp:18080/"
  echo "DFS Health @ master-node:  http://$masterIp:9870/dfshealth.html"
}

if [[ $1 = "start" ]]; then
  startServices
  exit
fi

if [[ $1 = "stop" ]]; then
  docker exec -d master-node /home/big_data/spark-cmd.sh stop master-node
  docker exec -d worker-1 /home/big_data/spark-cmd.sh stop
  docker exec -d worker-2 /home/big_data/spark-cmd.sh stop
  docker exec -d worker-3 /home/big_data/spark-cmd.sh stop
  docker stop master-node worker-1 worker-2 worker-3
  exit
fi

if [[ $1 = "remove" ]]; then
  docker rm master-node worker-1 worker-2 worker-3
  exit
fi

if [[ $1 = "deploy" ]]; then
  docker container rm -f `docker ps -a | grep $imageName | awk '{ print $1 }'` # delete old containers
  docker network rm cluster_net
  docker network create --driver bridge cluster_net # create custom network

  # 3 nodes
  echo ">> Starting nodes master and worker nodes ..."
  docker run -dP --network cluster_net --name master-node -h master-node -it $imageName
  docker run -dP --network cluster_net --name worker-1 -it -h worker-1 $imageName
  docker run -dP --network cluster_net --name worker-2 -it -h worker-2 $imageName
  docker run -dP --network cluster_net --name worker-3 -it -h worker-3 $imageName

  # Format master
  echo ">> Formatting hdfs ..."
  docker exec -it master-node /usr/local/hadoop/bin/hdfs namenode -format

  startServices
  exit
fi

if [[ $1 = "info" ]]; then
  show_info
  exit
fi

echo "Usage: cluster.sh deploy|start|stop"
echo "    deploy - create a new Docker network, containers (a master and 3 workers) and start these last"
echo "    start  - start the existing containers"
echo "    stop   - stop the running containers"
echo "    remove - remove all the created containers"
echo "    info   - useful URLs"
