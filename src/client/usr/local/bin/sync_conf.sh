#!/bin/bash

host=$(hostname)
cluster=${host:0:2}

/bin/rm -rf /tmp/$cluster 2>/dev/null
/bin/mkdir -p /tmp/$cluster/{hadoop,hbase,zoo,krb}

/usr/bin/rsync -hav /tmp/$cluster hmanager_server_host::hm-conf/

/usr/bin/rsync -hav /etc/hadoop/conf/*.xml hmanager_server_host::hm-conf/$cluster/hadoop/
/usr/bin/rsync -hav /etc/hadoop/conf/*.cfg hmanager_server_host::hm-conf/$cluster/hadoop/
/usr/bin/rsync -hav /etc/hadoop/conf/*.conf hmanager_server_host::hm-conf/$cluster/hadoop/

/usr/bin/rsync -hav /etc/hbase/conf/*.xml hmanager_server_host::hm-conf/$cluster/hbase/
/usr/bin/rsync -hav /etc/hbase/conf/*.cfg hmanager_server_host::hm-conf/$cluster/hbase/
/usr/bin/rsync -hav /etc/hbase/conf/*.conf hmanager_server_host::hm-conf/$cluster/hbase/

/usr/bin/rsync -hav /etc/zookeeper/conf/zoo.cfg hmanager_server_host::hm-conf/$cluster/zoo/
/usr/bin/rsync -hav /etc/krb5.conf hmanager_server_host::hm-conf/$cluster/krb/
