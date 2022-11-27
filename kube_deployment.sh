set -e
kubectl apply -f yamls/dbsecret.yml
kubectl apply -f yamls/pv.yml
kubectl apply -f yamls/pvc.yml
kubectl apply -f yamls/mysql_deployment.yml
kubectl apply -f yamls/mysql_service.yml
kubectl apply -f yamls/mysql_networkpolicy.yml
kubectl apply -f yamls/api_awehr_deployment.yml
kubectl apply -f yamls/api_nodeport.yml
kubectl apply -f yamls/api_awehr_autoscaler.yml
kubectl apply -f yamls/frontend_deployment.yml
kubectl apply -f yamls/frontend_nodeport.yml
kubectl apply -f yamls/frontend_autoscaler.yml
echo "waiting 30s for deployments and services to start"
sleep 30
kubectl get pods
