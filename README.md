Hadoop Cluster Manager
==============

Hadoop Cluster Manager is a single place dashboard that gives a  bird's eye view of multiple hadoop clusters. It serves as Monitoring and Configuration tool. It has below components:


1) Monitoring

	a) HDFS
	b) MapReduce
	c) Hbase
	d) Zookeeper

2) Configuration

        a) HDFS
        b) Hbase
        c) Zookeeper
        d) Kerberos


How it works
------

The tool consists of below two packages

1) Server - Centralized host that all clients sends data. This regenrates the dashboard periodically.

2) Client - All hosts send their stats and configurations to the server.

How to setup
------

Please refer "setup/INSTALL" for detailed steps.
