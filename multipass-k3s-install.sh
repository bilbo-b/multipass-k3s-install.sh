# This script sets up VMs running Ubuntu by using multipass (from https://multipass.run) and installs 
# k3s on them. Please note that it has only been tested on macOS (Ventura) and with 3 VMs
# It created an environment as described in the first part of the c't course for kubernetes:
# https://www.heise.de/select/ct/2022/22/2220016192019307305
export MP="/usr/local/bin/multipass"
export NAMES="kube1 kube2 kube3"
export FIRST=true
if [ ! -x $MP ]
then
	echo "$MP is not an executable file. Please make sure multipass is installed and the variable MP is set correctly in the script"
	if [ `uname` = Darwin ]
	then
		cat <<EOF

you may consider if you have not already done so to install homebrew from https://brew.sh
by running the one line command given on their main page for installation on your Mac

after that you can install e.g.

	brew install --cask multipass # from https://multipass.run

and 

	brew install kubernetes-cli

EOF
	fi
	exit 1
fi
for NAME in $NAMES
do
	$MP list | grep $NAME  >/dev/null
	if [ $? -eq 0 ]
	then
		echo "a VM by the name of $NAME already exists, this script does not know how to handle this:"
		$MP list
		exit 1
	fi
done
echo
echo "VMs will be created running Ubuntu 20.04 LTS, each with 1 CPU, 5GB disk and 512MB mem ..."
echo
echo "Names: $NAMES"
echo 
for NAME in $NAMES
do
	$MP launch focal -n $NAME
	$MP exec $NAME -- sudo mkdir -p /etc/rancher/k3s/
	echo 'disable: traefik' >config.yaml
	$MP transfer config.yaml ${NAME}:
	$MP exec $NAME sudo cp config.yaml /etc/rancher/k3s/
	if [ $FIRST = true ]
	then
		echo "/usr/bin/curl -sfL https://get.k3s.io | /usr/bin/sh -s - server --cluster-init" >inst_k3s
		$MP transfer inst_k3s ${NAME}:
		$MP exec $NAME -- chmod +x /home/ubuntu/inst_k3s
		$MP exec $NAME -- sudo sh -c /home/ubuntu/inst_k3s
		sleep 10
		echo "kubectl get nodes: "
		$MP exec $NAME -- sudo kubectl get nodes
		TOKEN=`multipass exec kube1 -- sudo cat /var/lib/rancher/k3s/server/token`
		IPLAST=`multipass list | grep $NAME | cut -f4 -d"." | cut -d" " -f1`
		IPADDR="192.168.64.$IPLAST"
		$MP exec $NAME -- sudo cat /etc/rancher/k3s/k3s.yaml >.kube_config_pre
		FIRST="false"
	else 
		echo "$NAME :"
                echo "/usr/bin/curl -sfL https://get.k3s.io | K3S_TOKEN=${TOKEN} sh -s - server --server https://${IPADDR}:6443" >inst_k3s
                $MP transfer inst_k3s ${NAME}:
                $MP exec $NAME -- chmod +x /home/ubuntu/inst_k3s
                $MP exec $NAME -- sudo sh -c /home/ubuntu/inst_k3s
		sleep 10
		echo "kubectl get nodes: "
		$MP exec $NAME -- sudo kubectl get nodes
	fi

done
echo multipass list
$MP list | grep -v Stopped
echo
perl -pe "s/127.0.0.1/${IPADDR}/" .kube_config_pre >.kube_config
echo the file .kube_config should be copied/moved to \~/.kube/config for the local configuration of kubectl 
echo will download first-pod.yml for your convenience as well
curl -O https://raw.githubusercontent.com/jamct/kubernetes-einstieg/main/part-1/first-pod.yml 2>/dev/null
echo "done!"
echo
echo "to stop the VMs:"
echo multipass stop $NAMES
echo "to delete the VMs:"
echo multipass delete $NAMES ; multipass purge
