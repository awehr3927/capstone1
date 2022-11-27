set -e
NODECOUNT=`kubectl get nodes | grep -v NAME | wc -l`
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
./wait_for_stable_service_pods.sh $NODECOUNT weave-net
