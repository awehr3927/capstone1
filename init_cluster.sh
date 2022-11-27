IFS=$'\n'
SYSPODS=`kubectl get pods -n kube-system 2>&1`
if [ $? -eq 0 ]
then
  if [ $(echo $SYSPODS | wc -l) -gt 1 ]
  then
     exit 0;
  fi
else
  FOO=`kubeadm init --cri-socket /run/cri-dockerd.sock --ignore-preflight-errors=Mem 2>&1`
  if [ $? -ne 0 ]
  then
	echo "failed"
	exit 1;
  else
	mkdir -p $HOME/.kube
	/bin/cp /etc/kubernetes/admin.conf $HOME/.kube/config
	chown $(id -u):$(id -g) $HOME/.kube/config
	echo $( for i in $FOO; do echo "$i"; done | tail -n 2 | tr -d '\n' | tr -d '\\' | tr '\t' ' '  )
  fi
fi
