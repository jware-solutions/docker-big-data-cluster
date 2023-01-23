
# Docker Big Data Cluster

A ready to go Big Data cluster (Hadoop + Hadoop Streaming + Spark + PySpark) with Docker and Docker Swarm!


## Index

1. [Why?](#why)
1. [Features](#features)
1. [Running toy cluster](#running-toy-cluster)
1. [Running a real cluster in Docker Swarm](#running-a-real-cluster-in-docker-swarm)
1. [Usage](#usage)
	1. [HDFS](#hdfs)
	1. [Spark and PySpark](#spark-and-pyspark)
1. [Going further](#going-further)
1. [Frequent problems](#frequent-problems)
1. [Contributing](#contributing)


## Why?

Although today you can find several repositories ready to deploy a Spark or Hadoop cluster, they all run into the same problem: they do not work when deployed on Docker Swarm due to several issues ranging from the definition of the worker nodes to connection problems with Docker network interfaces.

This repository seeks to solve the problem by offering a functional alternative, both a toy cluster to deploy on a single machine, as well as a real cluster that works on multiple nodes that conform a Docker Swarm cluster.


## Features

This repository is inspired by and uses several scripts taken from [Rubenafo's repo][rubenafo-repo] and [Sdesilva26's repo][sdesilva26-repo], however there are several changes introduced; the API is simpler, there is more documentation about usage and some extra features:

- ✅ Ready to deploy in a Docker Swarm cluster: all the networking and port configuration issues have been fixed so you can scale your cluster to as many worker nodes as you need.
- ⚡️ Hadoop, HDFS, Spark, Scala and PySpark ready to use: all the tools are available inside the container globally so you don't have to fight with environment variables and executable paths.
- 🌟 New technology: our image offers Hadoop 3.3.2, Spark 3.1.3 and Python 3.8.5!
- ⚙️ Less configuration: we have removed some settings to keep the minimum possible configuration, this way you prevent errors, unexpected behaviors and get the freedom to set parameters via environment variables and have an agile development that does not require rebuilding the Docker image. 
- 🐍 Python dependencies: we include the most used Python dependencies like Pandas, Numpy and Scipy to be able to work on datasets and perform mathematical operations (you can remove them if you don't need them!)


## Running toy cluster

You have two ways to run a cluster on a single machine:

- Use `toy-cluster.sh` script...
- Or use `docker-compose.yml` file


### Using toy-cluster.sh script

The script has the following commands:

- deploy: create a new Docker network, containers (a master and 3 workers) and start these last
- start: start the existing containers
- stop: stop the running containers
- remove: remove all the created containers
- info:: useful URLs

So, if you want to try your new cluster run `./toy-cluster.sh deploy` to create a network, containers and format namenode HDFS (note that this script will start the containers too). To stop, start again or remove just run the `stop`, `start` or `remove` respectively.

Use `./toy-cluster.sh info` to see the URLs to check Hadoop and Spark clusters status.


### Using docker-compose.yml file

The `docker-compose.yml` file has the same structure than `toy-cluster.sh` script except for the use of volumes to preserve HDFS data.

Only for the first time, you need to format the namenode information directory. **Do not execute this command when you are in production with valid data stored as you will lose all your data stored in the HDFS**:

`docker container run --rm -v hdfs_master_data_swarm:/home/hadoop/data/nameNode jwaresolutions/big-data-cluster:<tag> /usr/local/hadoop/bin/hadoop namenode -format`

Then you can manage your toy cluster with the following commands:

- To start the cluster run: `docker-compose up -d`
- To stop the cluster run: `docker-compose down`

**Important:** the use of `./toy-cluster.sh info` works with this! So you can get the useful cluster URLs.


## Running a real cluster in Docker Swarm

Here is the important stuff, there are some minors steps to do to make it work: first of all you need a Docker Swarm cluster:

1. Start the cluster in your master node: `docker swarm init`.
1. Generate a token for the workers to be added ([official doc][swarm-docs]): `docker swarm join-token worker`. It will print on screen a token in a command that must be executed in all the workers to be added.
1. Run the command generated in the previous step in all workers node: `docker swarm join: --token <token generated> <HOST>:<PORT>`

You have your Docker Swarm cluster! Now you have to label all the nodes to indicate which one will be the *master* and *workers*. On master node run:

1. List all cluster nodes to get their ID: `docker node ls`
1. Label master node as master: `docker node update --label-add role=master <MASTER NODE ID>`
1. **For every** worker ID node run: `docker node update --label-add role=worker <WORKER NODE ID>`

Create needed network and volumes:

```
docker network create -d overlay cluster_net_swarm
docker volume create --name=hdfs_master_data_swarm
docker volume create --name=hdfs_master_checkpoint_data_swarm
docker volume create --name=hdfs_worker_data_swarm
```

Now it is time to select a tag of the Docker image. The default is latest but it is not recommended to use it in production. After choose one, set it version on `docker-compose_cluster.yml` and the command below.

Only for the first time, you need to format the namenode information directory **in Master and Workers nodes. Do not execute this command when you are in production with valid data stored as you will lose all your data stored in the HDFS**:

`docker container run --rm -v hdfs_master_data_swarm:/home/hadoop/data/nameNode jwaresolutions/big-data-cluster:<tag> /usr/local/hadoop/bin/hadoop namenode -format`

Now you are ready to deploy your production cluster!

`docker stack deploy -c docker-compose_cluster.yml big-data-cluster`

<!-- TODO: add ports -->

## Usage

Finally you can use your cluster! Like the toy cluster, you have available some useful URLs:

- \<MASTER IP>:8088 -> Hadoop panel
- \<MASTER IP>:8080 -> Spark panel
- \<MASTER IP>:18080 -> Spark applications logs
- \<MASTER IP>:9870 -> HDFS panel

 Enter the master node:

`docker container exec -it <MASTER CONTAINER ID> bash`


### HDFS

You can store files in the Hadoop Distributed File System:

```
echo "test" > test.txt
hdfs dfs -copyFromLocal ./test.txt /test.txt
```

If you check in a worker node that the file is visible in the entire cluster:

`hdfs dfs -ls /`

<!-- ### TODO: add Hadoop -->

### Spark and PySpark

1. You can initiate a PySpark console: `pyspark --master spark://master-node:7077`
	1. Now, for example, read a file and count lines:

	```python
	lines = sc.textFile('hdfs://master-node:9000/test.txt')
	lines_count = lines.count()
	print(f'Line count -> {lines_count}')
	```
1. Or you can submit an script:
	1. Make the script:
	
	```python
	from pyspark import SparkContext
	import random

	NUM_SAMPLES = 1000

	sc = SparkContext("spark://master-node:7077", "Pi Estimation")


	def inside(p):
		x, y = random.random(), random.random()
		return x*x + y*y < 1

	count = sc.parallelize(range(0, NUM_SAMPLES)) \
				.filter(inside).count()
	print("Pi is roughly %f" % (4.0 * count / NUM_SAMPLES))
	```
	
	
	2. Submit it: `spark-submit your-script.py` 


## Going further


### Expand number of workers

Adding workers to cluster is easy:

1. Add a worker to your Swarm cluster as explained in [Running a real cluster in Docker Swarm](##running-a-real-cluster-in-Docker-Swarm) and label it with `role=worker`.
1. Increment the number of replicas in `docker-compose_cluster.yml` for `worker` service.
1. Deploy the stack again with `docker stack deploy -c docker-compose_cluster.yml big-data-cluster` (restart is no required).


### Add files/folder inside cluster

In both `docker-compose.yml` (toy cluster) and `docker-compose_cluster.yml` (real cluster) there is a commented line in `volumes` section. Just uncomment it and set the the file/folder in host file and the destination inside master node in cluster! For more information read [official documentation][volumes-docs] about `volumes` setting in Docker Compose.


### Add Python dependencies

1. Add the dependency to the `requirements.txt` file.
1. Build the image again.


### Check Spark logs

To check Spark `stderr` and `stdout` files you can run `bash` inside the Worker container and then run the following commands:

- stderr: `cat /sbin/spark-3.1.3-bin-without-hadoop/work/<app id>/<partition id>/stderr`
- stdout: `cat /sbin/spark-3.1.3-bin-without-hadoop/work/<app id>/<partition id>/stdout`


## Frequent problems


### Connection refused error

Sometimes it throws a *Connection refused* error when run a HDFS command or try to access to DFS from Hadoop/Spark. There is [official documentation][connection-refused-docs] about this problem. The solution that worked for this repository was running the commands listed in [this Stack Overflow answer][connection-refused-answer]. That is why you need to format the namenode directory the first time you are deploying the real cluster (see [Running a real cluster in Docker Swarm](##running-a-real-cluster-in-docker-swarm)).


### Port 9870 is not working

This problem means that Namenode is now running in master node, is associated with [Connection refused for HDFS](###connection-refused-for-hdfs) problem and has the same solution. Once Namenode is running the port should be working correctly.


### HDFS panel does not show some living nodes

If there are nodes that are not listed as active in the HDFS panel you may also need to run the nanemode directory formatting command on the Workers nodes, not just the Driver. See [Running a real cluster in Docker Swarm](##running-a-real-cluster-in-docker-swarm) to get the command.


## Contributing

Any kind of help is welcome and appreciated! If you find a bug please submit an issue or make a PR:

1. Fork this repo.
1. Create a branch where you will develop some changes.
1. Make a PR.

There are some TODOs to complete:

- [ ] Find a way to prevent *Connection refused* error to avoid format the namenode information directory
- [ ] Add examples for Hadoop
- [ ] Add examples for Hadoop Streaming
- [ ] Add examples for Spark Streaming


[rubenafo-repo]: https://github.com/rubenafo/docker-spark-cluster
[sdesilva26-repo]: https://github.com/sdesilva26/docker-spark
[swarm-docs]: https://docs.docker.com/engine/swarm/join-nodes/
[volumes-docs]: https://docs.docker.com/compose/compose-file/compose-file-v3/#volumes
[connection-refused-docs]: https://cwiki.apache.org/confluence/display/HADOOP2/ConnectionRefused
[connection-refused-answer]: https://stackoverflow.com/a/42281292/7058363
