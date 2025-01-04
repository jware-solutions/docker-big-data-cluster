# Base image
FROM ubuntu:24.10

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Adds some needed environment variables
ENV HDFS_NAMENODE_USER=root
ENV HDFS_DATANODE_USER=root
ENV HDFS_SECONDARYNAMENODE_USER=root
ENV YARN_RESOURCEMANAGER_USER=root
ENV YARN_NODEMANAGER_USER=root
ENV PYSPARK_PYTHON=python3

# Install required packages. NOTE: sudo is needed as it's called in some Spark scripts
ENV OPEN_JDK_VERSION=21
RUN apt update && apt install -y \
    openjdk-${OPEN_JDK_VERSION}-jdk \
    wget \
    curl \
    vim \
    ssh \
    rsync \
    git \
    net-tools \
    python3-pip \
    python3-venv \
    sudo \ 
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME environment variable
ENV JAVA_HOME=/usr/lib/jvm/java-${OPEN_JDK_VERSION}-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# Install Hadoop
ENV HADOOP_VERSION=3.4.0
RUN wget https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz \
    && tar -xzf hadoop-${HADOOP_VERSION}.tar.gz -C /opt/ \
    && rm hadoop-${HADOOP_VERSION}.tar.gz
ENV HADOOP_HOME=/opt/hadoop-${HADOOP_VERSION}
ENV PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH

# Creates the necessary directories for Hadoop
RUN mkdir -p ${HADOOP_VERSION}/logs

# Install Spark
ENV SPARK_VERSION=3.5.4
RUN wget https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz \
    && tar -xzf spark-${SPARK_VERSION}-bin-hadoop3.tgz -C /opt/ \
    && rm spark-${SPARK_VERSION}-bin-hadoop3.tgz
ENV SPARK_HOME=/opt/spark-${SPARK_VERSION}-bin-hadoop3
ENV PATH=$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH

# Set up SSH (for Hadoop to communicate across nodes)
RUN ssh-keygen -t rsa -f ~/.ssh/id_rsa -P '' \
    && cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys \
    && chmod 0600 ~/.ssh/authorized_keys

# Create and activate a virtual environment for Python.
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Copy requirements.txt and install Python dependencies in the virtual environment
COPY ./config/requirements.txt /tmp/
RUN pip install --upgrade pip \
    && pip install -r /tmp/requirements.txt

# Hadoop settings
WORKDIR ${HADOOP_HOME}/etc/hadoop
COPY ./config/core-site.xml .
COPY ./config/hdfs-site.xml .
COPY ./config/mapred-site.xml .
COPY ./config/yarn-site.xml .

# Spark settings
WORKDIR ${SPARK_HOME}/conf
COPY ./config/spark-env.sh .
COPY ./config/spark-defaults.conf .
COPY ./config/log4j.properties .

# Cluster cmd
WORKDIR /home/big_data
COPY ./config/spark-cmd.sh .
RUN chmod +x /home/big_data/spark-cmd.sh

# Add an explicit step to set JAVA_HOME in the bash profile to make it available to all users
RUN echo "export JAVA_HOME=$JAVA_HOME" >> /etc/profile \
    && echo "export JAVA_HOME=$JAVA_HOME" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh \
    && echo "export PATH=$JAVA_HOME/bin:$PATH" >> /etc/profile \
    && echo 'export PATH=$PATH:$HADOOP_HOME/bin' >> ~/.bashrc \
    && echo 'export PATH=$PATH:$HADOOP_HOME/sbin' >> ~/.bashrc

# Expose necessary ports (8080 -> Spark UI, 18080 -> Spark applications logs, 9870 -> Hadoop NameNode UI)
EXPOSE 8080 18080 9870

# Start SSH service. The entrypoint is defined in the docker-compose file
CMD ["service", "ssh", "start", "&&", "sleep", "infinity"]
