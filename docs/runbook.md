# Deploy

## Cluster Access Security

**Demo Configuration:** Public endpoint with optional IP restriction  
**Production Recommendation:** Private endpoint + AWS VPN

### Why Not IP Whitelisting in Production?

- **IPs change** - ISP rotation, VPN switches, mobile/travel access
- **Doesn't prevent compromised credentials** - Authentication still required
- **Terraform state drift** - Each apply fetches new IP, causing unnecessary updates
- **Team scaling issues** - Managing multiple developer IPs becomes unwieldy

### Production Alternatives

1. **AWS Client VPN** - Best for remote teams, managed by AWS
2. **Bastion Host + Session Manager** - Cost-effective, SSH tunneling
3. **Site-to-Site VPN / Direct Connect** - Enterprise/on-prem integration
4. **Private endpoint only** - Access via resources within VPC

### Current Setup

By default, the cluster endpoint allows public access from `0.0.0.0/0` but requires valid AWS IAM credentials.  
To restrict to your current IP during development:

```bash
cd terraform
terraform apply -var="enable_ip_restriction=true"
```

**Note:** This fetches your IP at apply time and will cause drift if your IP changes.

## Expose & Verify

### ClusterIP (local test)
```bash
kubectl port-forward svc/ml-service 8080:80
curl http://localhost:8080/health
```

### Ingress (ALB)
```bash
helm upgrade --install ml-svc ./helm/ml-service --set ingress.enabled=true
kubectl get ingress ml-service
```

## Deploy on Tag

```bash
git tag -a v0.0.5 -m "v0.0.5: deploy on tag"
git push --tags
```

After workflow:
```bash
kubectl get deploy ml-svc
kubectl get svc ml-service
```

# Rollback

# Logs

# Common Issues

# Ownership