# Configuration

## My Redis Cluster

### Creating and Installing the Chart

```bash
# Creating the Helm Chart
helm create redis-cluster
cd ./redis-cluster/Charts
helm create redis
# 1- Delete templates on redis-cluster and add your manifests (for stateful set a while loop is added to wait for dependencies)
# 2- Delete templates on redis subfolder and add your manifests
# 3- Add Chart details for both chart.yaml with dependencies for redis subchart
# 4- cd to charts folder
helm lint ./redis-cluster
helm package ./redis-cluster

# Install Helm Chart
helm install redis-cluster --create-namespace --namespace redis ./redis-cluster-0.1.0.tgz

# Get Master Name
kubectl get pods -n redis -o wide | grep `kubectl exec redis-0 -n redis -- redis-cli -h sentinel -p 5000 sentinel get-master-addr-by-name mymaster | head -n 1` | awk '{print $1}'
```

### Build client Image and Deploy the App

```bash
# Build The Image
# Move to application folder
docker build -t ziadhhassan/redis-client .
docker login
docker push ziadhhassan/redis-client

# Deploy Client App
kubectl apply -f redis-client.yaml
kubectl apply -f redis-service.yaml
```

## Bitnami Redis

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install redis bitnami/redis --set sentinel.enabled=true --set cluster.slaveCount=3 --set password=secretpassword
# Get Master Name
kubectl get pods -o wide | grep `kubectl exec redis-node-0 -c redis -- redis-cli -h redis -p 26379 -a secretpassword sentinel get-master-addr-by-name mymaster | head -n 1` | awk '{print $1}' 
```
