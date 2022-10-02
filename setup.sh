##############################################################         
# Description: This will spin up 4 node vagrant cluster with kubernetes 
# 
#
##############################################################

# Defined variables
MASTER_IP=192.168.59.21
PUBLIC_IP_START=192.168.59.25
PUBLIC_IP_END=192.168.59.50

# Construct Variables
SHORT_IP=$(echo $MASTER_IP | awk -F'.' '{print $1"."$2"."$3"."}')
UP_INT=$(echo $MASTER_IP | awk -F'.' '{print $4+1}')
NODE01_IP=$SHORT_IP$(echo $MASTER_IP | awk -F'.' '{if ($4 < 10) { print "0"$4+1 } else { print $4+1 }}')
NODE02_IP=$SHORT_IP$(echo $NODE01_IP | awk -F'.' '{if ($4 < 10) { print "0"$4+1 } else { print $4+1 }}')
NODE03_IP=$SHORT_IP$(echo $NODE02_IP | awk -F'.' '{if ($4 < 10) { print "0"$4+1 } else { print $4+1 }}')


sed -i '.bak' -e  "s|UP_INT|$UP_INT|g;s|MASTER_IP|$MASTER_IP|g;s|NODE01_IP|$NODE01_IP|g;s|NODE02_IP|$NODE02_IP|g;s|NODE03_IP|$NODE03_IP|g;s|SHORT_IP|$SHORT_IP|g;s|PUBLIC_IP_END|$PUBLIC_IP_END|g;s|PUBLIC_IP_START|$PUBLIC_IP_START|g" Vagrantfile

vagrant up
sh start.sh
rm -rf ubuntu-* start.sh *bak

