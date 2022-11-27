kubectl apply -f yamls/poduser.yml
kubectl config set-credentials poduser --token=$(kubectl describe secrets "$(kubectl describe serviceaccount poduser -n default| grep -i Tokens | awk '{print $2}')" -n default | grep token: | awk '{ print $2}')
kubectl config set-context poduser --cluster=kubernetes --namespace=default --user=poduser
echo "swapping to poduser"
kubectl config use-context poduser
kubectl config get-contexts
echo "kubectl get pods (should succeed)"
kubectl get pods
echo "kubectl get hpa (shold fail)"
kubectl get hpa
echo "kubectl get deployments (should fail)"
kubectl get deployments
echo "kubectl get svc (should fail)"
kubectl get svc
echo "kubectl run poduser-created --image=nginx (should succeed)"
kubectl run poduser-created --image=nginx 
sleep 5
kubectl get pods
echo "kubectl delete pod poduser-created (should succeed)"
kubectl delete pod poduser-created
sleep 5
kubectl get pods
echo "swapping back to admin"
kubectl config use-context kubernetes-admin@kubernetes
kubectl config get-contexts
