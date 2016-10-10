#!/bin/bash
# network.sh - Network usage stats
#
# Copyright 2010 Frode Petterson. All rights reserved.
# See README.rdoc for license.

rrdtool=/usr/bin/rrdtool
log=/var/log/rrdtool.log
si=$1
ru=$2
lat=$3
per=$4
in=$5
out=$6
contract=$7

dir="/opt/odoo/sistema-social/rossa/isp/isp/scripts/rrd"
img=$dir'/'img
db=$dir'/'$contract'_trafego'.rrd

if [ ! -e $db ]
then
	$rrdtool create $db \
	DS:in:DERIVE:600:U:U \
	DS:out:DERIVE:600:U:U \
	RRA:AVERAGE:0.5:1:576 \
	RRA:AVERAGE:0.5:6:672 \
	RRA:AVERAGE:0.5:24:732 \
	RRA:AVERAGE:0.5:144:1460
fi

echo "$rrdtool update $db -t in:out N:$in:$out" >> $log
$rrdtool updatev $db -t in:out N:$in:$out

for period in day week month year
do
    $rrdtool graph $img/$contract$period.png -s -1$period \
    -t "Network traffic the last $period" -z \
    -c "BACK#FFFFFF" -c "SHADEA#FFFFFF" -c "SHADEB#FFFFFF" \
    -c "MGRID#AAAAAA" -c "GRID#CCCCCC" -c "ARROW#333333" \
    -c "FONT#333333" -c "AXIS#333333" -c "FRAME#333333" \
        -h 134 -w 543 -l 0 -a PNG -v "B/s" \
    DEF:in=$db:in:AVERAGE \
    DEF:out=$db:out:AVERAGE \
    VDEF:minin=in,MINIMUM \
    VDEF:minout=out,MINIMUM \
    VDEF:maxin=in,MAXIMUM \
    VDEF:maxout=out,MAXIMUM \
    VDEF:avgin=in,AVERAGE \
    VDEF:avgout=out,AVERAGE \
    VDEF:lstin=in,LAST \
    VDEF:lstout=out,LAST \
    VDEF:totin=in,TOTAL \
    VDEF:totout=out,TOTAL \
    "COMMENT: \l" \
    "COMMENT:               " \
    "COMMENT:Minimum      " \
    "COMMENT:Maximum      " \
    "COMMENT:Average      " \
    "COMMENT:Current      " \
    "COMMENT:Total        \l" \
    "COMMENT:   " \
    "AREA:out#2EFEF7:Down  " \
    "LINE1:out#819FF7" \
    "GPRINT:minout:%5.1lf %sb/s   " \
    "GPRINT:maxout:%5.1lf %sb/s   " \
    "GPRINT:avgout:%5.1lf %sb/s   " \
    "GPRINT:lstout:%5.1lf %sb/s   " \
    "GPRINT:totout:%5.1lf %sb   \l" \
    "COMMENT:   " \
    "AREA:in#81F7BE:Up   " \
    "LINE1:in#04B404" \
    "GPRINT:minin:%5.1lf %sb/s   " \
    "GPRINT:maxin:%5.1lf %sb/s   " \
    "GPRINT:avgin:%5.1lf %sb/s   " \
    "GPRINT:lstin:%5.1lf %sb/s   " \
    "GPRINT:totin:%5.1lf %sb   \l" > /dev/null
done

db=$dir'/'$contract'_sinal'.rrd

if [ ! -e $db ]
then
    $rrdtool create $db \
    DS:sinal:GAUGE:600:-130:U \
    DS:ruido:GAUGE:600:-130:U \
    DS:latencia:GAUGE:600:U:U \
    DS:perdida:GAUGE:600:U:U \
    RRA:AVERAGE:0.5:1:576 
fi

$rrdtool updatev $db -t sinal:ruido:latencia:perdida N:$si:$ru:$lat:$per
#echo $si $ru $lat

rrdtool graph $img'/'$contract.png --interlaced -a PNG -w 600 -h 125 \
-v "sinal em dbm" \
'DEF:sinal='$db':sinal:AVERAGE' \
'DEF:ruido='$db':ruido:AVERAGE' \
'LINE1:sinal#0000FF:SINAL' \
'GPRINT:sinal:MIN: Min\:%2.lf dbm' \
'GPRINT:sinal:MAX: Max\:%2.lf dbm' \
'GPRINT:sinal:AVERAGE: Med\:%4.1lf dbm' \
'GPRINT:sinal:LAST: Ult\:%2.lf dbm \l'  \
'LINE2:ruido#ff0000:RUIDO' \
'GPRINT:ruido:MIN: Min\:%2.lf dbm' \
'GPRINT:ruido:MAX: Max\:%2.lf dbm' \
'GPRINT:ruido:AVERAGE: Med\:%4.1lf dbm' \
'GPRINT:ruido:LAST: Ult\:%2.lf dbm' \

rrdtool graph $img'/'$contract'_ping.png' --interlaced -a PNG -w 600 -h 125 \
-v "PING" \
'DEF:latencia='$db':latencia:AVERAGE' \
'DEF:perdida='$db':perdida:AVERAGE' \
'AREA:latencia#2EFEF7:Latencia' \
'LINE1:latencia#819FF7' \
'GPRINT:latencia:MIN: Min\:%2.lf ms' \
'GPRINT:latencia:MAX: Max\:%2.lf ms' \
'GPRINT:latencia:AVERAGE: Med\:%4.1lf ms' \
'GPRINT:latencia:LAST: Ult\:%2.lf ms \l'  \
'LINE2:perdida#04B404:Perdida' \
'GPRINT:perdida:MIN: Min\:%2.lf ' \
'GPRINT:perdida:MAX: Max\:%2.lf ' \
'GPRINT:perdida:AVERAGE: Med\:%4.1lf ' \
'GPRINT:perdida:LAST: Ult\:%2.lf ' \
