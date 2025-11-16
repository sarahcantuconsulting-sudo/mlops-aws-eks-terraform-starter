AWS_PROFILE ?= builder
CLUSTER_NAME ?= mlops-starter-demo
AWS_REGION ?= us-east-1

.PHONY: install-alb-controller
install-alb-controller:
	CLUSTER_NAME=$(CLUSTER_NAME) AWS_REGION=$(AWS_REGION) AWS_PROFILE=$(AWS_PROFILE) \
		bash helm/alb-controller/install.sh

.PHONY: deploy-ml-service
deploy-ml-service:
	CLUSTER_NAME=$(CLUSTER_NAME) AWS_REGION=$(AWS_REGION) AWS_PROFILE=$(AWS_PROFILE) \
		aws eks update-kubeconfig --name $(CLUSTER_NAME) --region $(AWS_REGION) --alias $(CLUSTER_NAME)
	kubectl config use-context $(CLUSTER_NAME)
	helm upgrade --install ml-svc ./helm/ml-service

.PHONY: verify-alb
verify-alb:
	kubectl get ingress ml-service
	@echo "Once ADDRESS is non-empty, run:"
	@echo "  curl http://<ALB-DNS>/health"
