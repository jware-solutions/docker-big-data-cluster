# Ubuntu 20.04 LTS
FROM ubuntu:20.04

# Defines the environment variables required by Hadoop
ENV HADOOP_HOME "/usr/local/hadoop"
ENV HADOOP_STREAMING_HOME "$HADOOP_HOME/share/hadoop/tools/lib"

# This line is required, otherwise the source command cannot be used.
SHELL ["/bin/bash", "-c"]

# Installation and configuration
RUN apt update \
    # Installs Python 3.x, Java (OpenJDK), and some other tools to make everything work.
    # Configures SSH so that it doesn't throw problems with the connection
    && apt install -y python3 python3-venv openjdk-8-jdk wget ssh openssh-server openssh-client net-tools nano iputils-ping \
    && echo 'ssh:ALL:allow' >> /etc/hosts.allow \
    && echo 'sshd:ALL:allow' >> /etc/hosts.allow \
    && ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa \
    && cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys \
    && echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config \
    && service ssh restart \
    # Downloads and extracts Hadoop
    && wget http://apache.dattatec.com/hadoop/common/hadoop-3.1.3/hadoop-3.1.3.tar.gz \
    # Configures Hadoop and removes downloaded .tar.gz file
    && tar -xzvf hadoop-3.1.3.tar.gz \
    && mv hadoop-3.1.3 $HADOOP_HOME \
    && echo 'export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")' >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh \
    && echo 'export PATH=$PATH:$HADOOP_HOME/bin' >> ~/.bashrc \
    && echo 'export PATH=$PATH:$HADOOP_HOME/sbin' >> ~/.bashrc \
    && rm hadoop-3.1.3.tar.gz
    # Downloads Apache Spark
RUN wget apache.dattatec.com/spark/spark-3.0.0/spark-3.0.0-bin-hadoop2.7.tgz \
    # Decompress, adds to PATH and then removes .tgz Apache Spark file
    && tar -xvzf spark-3.0.0-bin-hadoop2.7.tgz \
    && mv spark-3.0.0-bin-hadoop2.7 sbin/ \
    && echo 'export PATH=$PATH:/sbin/spark-3.0.0-bin-hadoop2.7/sbin/' >> ~/.bashrc \
    && echo 'export PATH=$PATH:/sbin/spark-3.0.0-bin-hadoop2.7/bin/' >> ~/.bashrc \
    && rm spark-3.0.0-bin-hadoop2.7.tgz
RUN mv ${HADOOP_STREAMING_HOME}/hadoop-streaming-3.1.3.jar ${HADOOP_STREAMING_HOME}/hadoop-streaming.jar \
    && source ~/.bashrc

# Installs some extra libraries
RUN apt-get update --fix-missing && apt-get install -y netcat software-properties-common build-essential cmake
RUN add-apt-repository universe

WORKDIR /home/big_data

# Installs common Python3
COPY ./config/requirements.txt ./requirements.txt
RUN apt-get install -y python3-pip
RUN pip3 install -r ./requirements.txt

# Adds some needed environment variables
ENV HDFS_NAMENODE_USER "root"
ENV HDFS_DATANODE_USER "root"
ENV HDFS_SECONDARYNAMENODE_USER "root"
ENV YARN_RESOURCEMANAGER_USER "root"
ENV YARN_NODEMANAGER_USER "root"
ENV PYSPARK_PYTHON "python3"

# Hadoop settings
WORKDIR /usr/local/hadoop/etc/hadoop
COPY ./config/core-site.xml .
COPY ./config/hdfs-site.xml .
COPY ./config/mapred-site.xml .
COPY ./config/yarn-site.xml .

# Spark settings
WORKDIR /sbin/spark-3.0.0-bin-hadoop2.7/conf/
COPY ./config/spark-env.sh .
COPY ./config/log4j.properties .

# Cluster cmd
WORKDIR /home/big_data
COPY ./config/spark-cmd.sh .
RUN chmod +x /home/big_data/spark-cmd.sh

CMD service ssh start && sleep infinity