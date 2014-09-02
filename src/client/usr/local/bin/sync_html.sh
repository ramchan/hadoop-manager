#!/bin/bash


host=$(hostname)
cluster=${host:0:2}
dash_html="/var/hmanager-client/""$cluster""/dash/dash.html"

/bin/mkdir -p /var/hmanager-client/"$cluster"/dash
cp /var/hmanager-client/base/dash_base.html $dash_html

if [[ "$cluster" == *h4* ]];
then
/usr/local/bin/gen_html.sh -h NAMENODE -j JOBTRACKER  >> $dash_html
elif [[ "$cluster" == *h3* ]]
then
/usr/local/bin/gen_html.sh -h NAMENODE -j JOBTRACKER  >> $dash_html
elif [[ "$cluster" == *sp* ]]
then
/usr/local/bin/gen_html.sh -h NAMENODE -j JOBTRACKER  >> $dash_html
else
echo
fi

rsync -hav /var/hmanager-client/$cluster  hmanager_server_host::hm-dash/
