echo "initial readout at rest"
kubectl get hpa
kubectl get pods
echo "running load-generator pod"
kubectl apply -f yamls/load-generator.yml
sleep 2
echo "confirming load generator active"
kubectl get pods | grep load-generator
echo "sleeping 30 seconds to build load"
sleep 30
echo "getting readout on initial hpa loads"
kubectl get hpa
kubectl get pods | grep -i load-generator
echo "sleeping 45 more seconds to wait on scaling"
sleep 45
echo "getting readout on scaling"
kubectl get pods
kubectl get hpa
echo "cleaning up load-generator"
kubectl delete pod load-generator
