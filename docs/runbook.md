# Deploy
## Expose & Verify
# ClusterIP (local test)
kubectl port-forward svc/ml-service 8080:80
curl http://localhost:8080/health

# Ingress (ALB)
helm upgrade --install ml-svc ./helm/ml-service --set ingress.enabled=true
kubectl get ingress ml-service

## Deploy on Tag
git tag -a v0.0.5 -m "v0.0.5: deploy on tag"
git push --tags

# After workflow:
kubectl get deploy ml-svc
kubectl get svc ml-service

# Rollback

# Logs

# Common Issues

# Ownership