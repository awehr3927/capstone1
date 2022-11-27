TARGET_IP=$1
slept=0
wget -q -O- http://$TARGET_IP > /dev/null
while [ $? -ne 0 ]
do
   if [ $slept -gt 180 ]
   then
     echo "kube-system took longer than 3m to stabilize, something is wrong! exiting!"
     exit 1;
   fi
   sleep 5
   slept=$(($slept + 5))
   wget -q -O- http://$TARGET_IP > /dev/null
done

