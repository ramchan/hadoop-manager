#!/bin/bash


function usage()
{
     echo "
    Usage: $0 -h <hmaster> -jt <jt_host>
     "  >&2
exit 1;
}

while getopts "h:j:h" flag
do
#  echo $flag $OPTIND $OPTARG
   case $flag in
   h) hmaster=$OPTARG
   ;;
   j) jt=$OPTARG
   ;;
   h) usage
   ;;
   *) usage
   ;;
   esac
done


host=$(hostname)
cluster=${host:0:2}

html_base="/var/hmanager-client/base"
root_html="/var/hmanager-client/$cluster/dash"

mkdir -p $root_html
chmod 777 $root_html

hdfs_html="$root_html""/hdfs.html"
hbase_html="$root_html""/hbase.html"
mapred_html="$root_html""/mapred.html"
zoo_html="$root_html""/zoo.html"

hmaster=${hmaster:-"nil"} 
jt=${jt:-"nil"} 
hbase_file="/tmp/master-status"
jt_file="/tmp/jt.html"
dead_jt_file="/tmp/dead_jt.html"
/bin/rm $hbase_file $jt_file $dead_jt_file 2> /dev/null

wget http://"$hmaster":60010/master-status -O $hbase_file 2>/dev/null
wget http://"$jt":50030/machines.jsp?type=active -O $jt_file 2> /dev/null
wget http://"$jt":50030/machines.jsp?type=blacklisted -O $dead_jt_file  2> /dev/null

rs=($(sed -n "/>Region Servers/,/Total\:/p" $hbase_file | awk -F "60030" '{print $1}' | awk -F "href" '{print $2}' | awk -F "/" '{print $NF}' |awk -F ":" '{print $1}'  |grep -v ^$))

dead_rs=($(sed -n "/>Dead Region Servers/,/Regions in Transition/p" $hbase_file |grep -v ^$ |egrep -v "Dead Region Servers|Regions in Transition" |  grep , | awk -F "," '{print $1}'  | awk -F "<td>" '{print $2}' ))

zoo=($(sed -n "/Quorum<\/td><td>/,/<td>/p" $hbase_file  |awk -F "Addresses" '{print $1}'    |awk -F "<td>" '{print $3}' | awk -F "</td>" '{print $1}' |sed -e 's/:2181/ /g' |sed -e 's/,//g' |sort))

 sudo kinit  -kt /etc/hadoop/keytabs/hdfs.keytab hdfs/`hostname -f`
 sudo kinit  -R
 dn=($(hadoop dfsadmin -report 2> /dev/null  |grep Hostname |awk '{print $2}' | sort))
dead_dn=$(hadoop dfsadmin -report 2> /dev/null |grep total |awk -F "," '{print $2}'  |awk -F "dead" '{print $1}' )

tt=($(sed -n "/50025/,/\td/p" $jt_file  |grep href |awk -F "50025</a></td" '{print $2}'  |awk -F "</td" '{print $1}'|awk -F "<td>" '{print $2}'  |grep -v ^$  |sort ))
dead_tt=($(sed -n "/50025/,/\td/p" $dead_jt_file  |grep href |awk -F "50025</a></td" '{print $2}'  |awk -F "</td" '{print $1}'|awk -F "<td>" '{print $2}'  |grep -v ^$  |sort ))

krb_master=$(grep admin_server /etc/krb5.conf |awk '{print $3}' )
krb_slave=($(grep -w kdc /etc/krb5.conf  |grep -v FILE |awk '{print $3}' ))


len=${#zoo[@]}
flag=0
msg=""
str=""
count=1

if [ $len -gt 0 ];
then
for i in ${zoo[@]}
do
i=$(echo $i  |sed -e 's/DOMAIN//g')
str="$str""$i""<br />"

if [ $count == 1 ];
then
cp $html_base/zoo_base.html $zoo_html
echo "<li class=\"active\"><a href=\"#pane$count\" data-toggle=\"tab\">$i</a></li> " >> $zoo_html
else
echo  "<li><a href=\"#pane$count\" data-toggle=\"tab\">$i</a></li>" >> $zoo_html
fi

((count++))

echo "<pre>" > "$root_html""/zoo_""$i"".html"
date >> "$root_html""/zoo_""$i"".html"
echo >> "$root_html""/zoo_""$i"".html"
echo stat |nc $i 2181 >> "$root_html""/zoo_""$i"".html"
echo "</pre>" >> "$root_html""/zoo_""$i"".html"

echo "\nquit" | nc -w 3 $i 2181
if [ $? -ne 0 ];
then 
flag=1
msg="$msg""$i"" - F""<br>"
fi
done

count=1
echo "
  </ul>
  <div class=\"tab-content\">
" >> $zoo_html

for i in ${zoo[@]}
do
i=$(echo $i  |sed -e 's/DOMAIN//g')
if [ $count == 1 ];
then
echo "<div id=\"pane$count\" class=\"tab-pane active\">" >> $zoo_html
else
echo "<div id=\"pane$count\" class=\"tab-pane\">" >> $zoo_html
fi
echo "
<iframe src=\"/$cluster/dash/zoo_$i.html\" style=\"width: 100%; height: 100%; border: 0\" ></iframe>
</div>
" >> $zoo_html

((count++))
done
echo "
  </div>
</div>
</body>
</html> " >> $zoo_html


str=${str:0:${#str} - 6}
echo "<tr>"
echo "<td class=\"text-center\"><IMG SRC=\"/img/menuzookeeper.png\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Zookeeper</td>"
if [ $flag == 1 ];
then
echo "<td class=\"text-center\"><font color=\"red\">$msg</td>"
else
echo "<td class=\"text-center\"><font color=\"green\">Running</td>"
fi

echo "<td class=\"text-center\"><a href=\"#\" id=\"zoo\" rel=\"popover\" data-content=\"$str\">$len Zookeeper</a>"
echo "</tr>"
fi

len=${#dn[@]}
flag=0
msg=""
str=""

if [ $len -gt 0 ];
then


nnstr=$(/usr/local/bin/check_namenode_ha |grep pri)
if [[ "$nnstr" == *pri* ]]
then
if echo "$nnstr" |grep -q FAIL;
then
flag=1
hdfsmsg="0 Pri NN"
msg="Pri NN fail""<br>"
fi
prinn=$(echo $nnstr |awk '{print $2}')
prinn=$(echo $prinn  |sed -e 's/DOMAIN//g')
hdfsmsg="<a href=\"#\" id=\"zoo1\" rel=\"popover\" data-content=\"$prinn\">1 Pri NN</a>, "
fi

priflag=0
prinn_fqdn="$prinn""DOMAIN"
echo "\nquit" | nc -w 3 $prinn_fqdn 50070 > /dev/null 2>&1
if [ $? -ne 0 ];
then
prinn_fqdn="$prinn""DOMAIN"
echo "\nquit" | nc -w 3 $prinn_fqdn 50070 > /dev/null 2>&1
if [ $? -ne 0 ];
then
priflag=1
fi
fi

if [ $priflag == 1 ];
then
echo " 
<html>
<body>
<h1>
<p>
<center>Namenode $prinn is down
</body>
</html>
" > $hdfs_html
else
cp $html_base/hdfs_base.html $hdfs_html
echo "
<iframe src=\"http://$prinn_fqdn:50070/dfshealth.jsp\" style=\"width: 100%; height: 100%; border: 0\" ></iframe>
</div>
<div id=\"pane2\" class=\"tab-pane\">
<iframe src=\"http://$prinn_fqdn:50070/dfsnodelist.jsp?whatNodes=LIVE\" style=\"width: 100%; height: 100%; border: 0\" ></iframe>
</div>
<div id=\"pane3\" class=\"tab-pane\">
<iframe src=\"http://$prinn_fqdn:50070/nn_browsedfscontent.jsp\" style=\"width: 100%; height: 100%; border: 0\" ></iframe>
</div>
</div>
</div>
</body>
</html>
" >> $hdfs_html
fi


nnstr=""
nnstr=$(/usr/local/bin/check_namenode_ha |grep sec)
if [[ "$nnstr" == *sec* ]]
then
if echo "$nnstr" |grep -q FAIL;
then
flag=1
hdfsmsg="$hdfsmsg""0 Sec NN"
msg="$msg""Sec NM fail<br>"
else
secnn=$(echo $nnstr |awk '{print $2}')
secnn=$(echo $secnn  |sed -e 's/DOMAIN//g')
hdfsmsg="$hdfsmsg""<a href=\"#\" id=\"zoo1\" rel=\"popover\" data-content=\"$secnn\">1 Sec NN</a>, "
fi
fi


if [ $dead_dn -gt 0 ];
then
flag=1
msg="$msg""$i"" - F""<br>"
fi


echo "<tr>"
echo "<td class=\"text-center\"><IMG SRC=\"/img/menuhdfs.png\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;HDFS</td>"
if [ $flag == 1 ];
then
echo "<td class=\"text-center\"><font color=\"red\">$msg</td>"
else
echo "<td class=\"text-center\"><font color=\"green\">Running</td>"
fi

for i in ${dn[@]}
do
i=$(echo $i  |sed -e 's/DOMAIN//g')
str="$str""$i""<br />"
done

str=${str:0:${#str} - 6}
echo "<td class=\"text-center\">""$hdfsmsg"" <a href=\"#\" id=\"zoo\" rel=\"popover\" data-content=\"$str\">$len DN</td></tr>"

fi



if [[ "$jt" == "nil" || "$jt" == *h4* ]]
then
echo "
<tr>
<td class=\"text-center\"><IMG SRC=\"/img/menumapred.png\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;MapReduce</td>
<td class="text-center">NA</td>
<td class="text-center">NA</td> </tr>
"
echo " 
<html>
<body>
<h1>
<p>
<center>Jobtracker NA 
</body>
</html>
" > $mapred_html

else

flag=0
msg=""
str=""

echo "\nquit" | nc -w 3 $jt 50030 > /dev/null
if [ $? -eq 0 ];
then

cp $html_base/mapred_base.html $mapred_html
echo "
<iframe src=\"http://$jt:50030/jobtracker.jsp\" style=\"width: 100%; height: 100%; border: 0; overflow-x: scroll; overflow-y: scroll;\" ></iframe>
</div>
<div id=\"pane2\" class=\"tab-pane\">
<iframe src=\"http://$jt:50030/machines.jsp?type=active\" style=\"width: 100%; height: 100%; border: 0\" ></iframe>
</div>
</div>
</div>
</body>
</html>
" >> $mapred_html


dead_len=${#dead_tt[@]}
if [ $dead_len -gt 0 ];then
flag=1
for i in ${dead_tt[@]}
do
str="$str""$i""<br />"
done
str=${str:0:${#str} - 6}
fi



echo "<tr>"
echo "<td class=\"text-center\"><IMG SRC=\"/img/menumapred.png\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;MapReduce</td>"
if [ $flag == 1 ];
then
echo "<td class=\"text-center\">$msg<a href=\"#\" id=\"zoo\" rel=\"popover\" data-content=\"$str\"><font color=\"red\">$dead_len blacklisted TT</td>"
else
echo "<td class=\"text-center\"><font color=\"green\">Running</td>"
fi

len=${#tt[@]}

for i in ${tt[@]}
do
i=$(echo $i  |sed -e 's/DOMAIN//g')
str="$str""$i""<br />"
done

str=${str:0:${#str} - 6}
echo "<td class=\"text-center\"><a href=\"#\" id=\"zoo1\" rel=\"popover\" data-content=\"$jt\">1 JT</a>, <a href=\"#\" id=\"zoo\" rel=\"popover\" data-content=\"$str\">$len TT</td></tr>"

else
echo "
<tr>
<td class=\"text-center\"><IMG SRC=\"/img/menumapred.png\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;MapReduce</td>
<td class=\"text-center\"><a href=\"#\" id=\"zoo\" rel=\"popover\" data-content=\"$jt\"><font color=\"red\">JT down</a></td>
<td class=\"text-center\"><a href=\"#\" id=\"zoo1\" rel=\"popover\" data-content=\"$jt\">1 JT</a>
"
echo " 
<html>
<body>
<h1>
<p>
<center>Jobtracker $jt is down
</body>
</html>
" > $mapred_html
fi

fi



if [[ "$hmaster" == "nil" ]]
then
echo "
<tr>
<td class="text-center">&nbsp;&nbsp;<IMG SRC="/img/menuhbase.png">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Hbase</td>
<td class="text-center">NA</td>
<td class="text-center">NA</td> </tr>
"
else

flag=0
msg=""
str=""

echo "\nquit" | nc -w 3 $hmaster 60010 > /dev/null
if [ $? -eq 0 ];
then


cp $html_base/hbase_base.html $hbase_html
echo "
<iframe src=\"http://$hmaster:60010/master-status\" style=\"width: 100%; height: 100%; border: 0\" ></iframe>
</div>
<div id=\"pane2\" class=\"tab-pane\">
<iframe src=\"http://$hmaster:60010/tablesDetailed.jsp\" style=\"width: 100%; height: 100%; border: 0\" ></iframe>
</div>
</div>
</div>
</body>
</html>
" >> $hbase_html


dead_len=${#dead_rs[@]}
if [ $dead_len -gt 0 ];
then
flag=1
for i in ${dead_rs[@]}
do
i=$(echo $i  |sed -e 's/DOMAIN//g')
str="$str""$i""<br />"
done
str=${str:0:${#str} - 6}

fi



echo "<tr>"
echo "<td class=\"text-center\"><IMG SRC=\"/img/menuhbase.png\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Hbase</td>"
if [ $flag == 1 ];
then
echo "<td class=\"text-center\">$msg<a href=\"#\" id=\"zoo\" rel=\"popover\" data-content=\"$str\"><font color=\"red\">$dead_len dead RS</td>"
else
echo "<td class=\"text-center\"><font color=\"green\">Running</td>"
fi

len=${#rs[@]}

for i in ${rs[@]}
do
i=$(echo $i  |sed -e 's/DOMAIN//g')
str="$str""$i""<br />"
done

str=${str:0:${#str} - 6}
echo "<td class=\"text-center\"><a href=\"#\" id=\"zoo1\" rel=\"popover\" data-content=\"$hmaster\">1 Hmaster</a>, <a href=\"#\" id=\"zoo\" rel=\"popover\" data-content=\"$str\">$len RS</td></tr>"

else
echo "
<tr>
<td class=\"text-center\"><IMG SRC=\"/img/menuhbase.png\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Hbase</td>
<td class=\"text-center\"><a href=\"#\" id=\"zoo\" rel=\"popover\" data-content=\"$hmaster\"><font color=\"red\">Hmaster dead</a></td>
<td class=\"text-center\"><a href=\"#\" id=\"zoo1\" rel=\"popover\" data-content=\"$hmaster\">1 Hmaster</a>
"
echo " 
<html>
<body>
<h1>
<p>
<center>Hbase master dead
</body>
</html>
" > $hbase_html

fi

fi

len=${#krb_slave[@]}
flag=0
msg=""
str=""

echo "\nquit" | nc -w 3 $krb_master 749 > /dev/null
if [ $? -ne 0 ];
then
flag=1
msg="$msg""Kmaster $krb_master"" - F""<br>"
fi


if [ $len -gt 0 ];
then
for i in ${krb_slave[@]}
do
i=$(echo $i  |sed -e 's/DOMAIN//g')
str="$str""$i""<br />"
done
str=${str:0:${#str} - 6}
echo "<tr>"
echo "<td class=\"text-center\"><IMG SRC=\"/img/kerb.png\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Kerberos</td>"
if [ $flag == 1 ];
then
echo "<td class=\"text-center\"><font color=\"red\">$msg</td>"
else
echo "<td class=\"text-center\"><font color=\"green\">Running</td>"
fi

echo "<td class=\"text-center\"><a href=\"#\" id=\"zoo1\" rel=\"popover\" data-content=\"$krb_master\">1 Kmaster</a>, <a href=\"#\" id=\"zoo\" rel=\"popover\" data-content=\"$str\">$len Kslaves</td></tr>"

fi



if [[ "$host" == *h3gw* ]]
then
hive=$(/etc/init.d/hive-metastore status)
sq=$( /etc/init.d/sqoop-metastore status)
oz=$( /etc/init.d/oozie status)

echo "
<tr>
<td class=\"text-center\">&nbsp;&nbsp;<IMG SRC=\"/img/menuhive.png\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Hive</td>
"
if [[ "$hive" == "Checking for service : metastore is running." ]]
then
echo "<td class=\"text-center\"><font color=\"green\">Running</td>"
else
echo "<td class=\"text-center\"><font color=\"red\">Hive down</td>"
fi
echo "<td class=\"text-center\"><a href=\"#\" id=\"zoo\" rel=\"popover\" data-content=\"$host\">1 Hive</a></tr>"


echo "
<tr>
<td class=\"text-center\">&nbsp;&nbsp;<IMG SRC=\"/img/menuoozie.png\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Oozie</td>
"
if [[ "$oz" == "running" ]]
then
echo "<td class=\"text-center\"><font color=\"green\">Running</td>"
else
echo "<td class=\"text-center\"><font color=\"red\">Oozie down</td>"
fi
echo "<td class=\"text-center\"><a href=\"#\" id=\"zoo\" rel=\"popover\" data-content=\"$host\">1 Oozie</a></tr>"

echo "
<tr>
<td class=\"text-center\">&nbsp;&nbsp;<IMG SRC=\"/img/menusq.jpg\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Sqoop</td>
"
if [[ "$sq" == "sqoop-metastore is running" ]]
then
echo "<td class=\"text-center\"><font color=\"green\">Running</td>"
else
echo "<td class=\"text-center\"><font color=\"red\">Sqoop down</td>"
fi
echo "<td class=\"text-center\"><a href=\"#\" id=\"zoo\" rel=\"popover\" data-content=\"$host\">1 Sqoop</a></tr>"



else

echo "
<tr>
<td class=\"text-center\">&nbsp;&nbsp;<IMG SRC=\"/img/menuhive.png\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Hive</td>
<td class=\"text-center\">NA</td>
<td class=\"text-center\">NA</td> </tr>

<tr>
<td class=\"text-center\">&nbsp;&nbsp;<IMG SRC=\"/img/menuoozie.png\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Oozie</td>
<td class=\"text-center\">NA</td>
<td class=\"text-center\">NA</td> </tr>

<tr>
<td class=\"text-center\">&nbsp;&nbsp;<IMG SRC=\"/img/menusq.jpg\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Sqoop</td>
<td class=\"text-center\">NA</td>
<td class=\"text-center\">NA</td> </tr>
"
fi

today=$(/bin/date)

echo "
</table>
<div class=\"footer\">
Gen at: $today
</div>
</body>
</html>
";
