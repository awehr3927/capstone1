stablepods=0
slept=0
while [ $stablepods -ne $1 ]
do
   if [ $slept -gt 180 ]
   then
     echo "kube-system took longer than 3m to stabilize, something is wrong! exiting!"
     exit 1;
   fi
   sleep 5
   slept=$(($slept + 5))
   stablepods=`kubectl get pods -n kube-system | grep $2 | grep Running | wc -l`
done

