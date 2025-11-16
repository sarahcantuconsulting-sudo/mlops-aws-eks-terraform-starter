AWS_PROFILE ?= builder
CLUSTER_NAME ?= mlops-starter-demo
AWS_REGION ?= us-east-1

PHONY: tf-apply
tf-apply:
    @echo "⏱️  Starting Terraform apply..."
    @START=$$(date +%s); \
    cd terraform && AWS_PROFILE=builder terraform apply -auto-approve; \
    END=$$(date +%s); \
    DURATION=$$((END - START)); \
    echo "✅ Terraform apply completed in $$DURATION seconds ($$(( DURATION / 60 ))m $$(( DURATION % 60 ))s)"

.PHONY: tf-destroy
tf-destroy:
    @echo "⏱️  Starting Terraform destroy..."
    @START=$$(date +%s); \
    cd terraform && AWS_PROFILE=builder terraform destroy -auto-approve; \
    END=$$(date +%s); \
    DURATION=$$((END - START)); \
    echo "✅ Terraform destroy completed in $$DURATION seconds ($$(( DURATION / 60 ))m $$(( DURATION % 60 ))s)"

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

.PHONY: watch-alb
watch-alb:
	@echo "Watching ALB provisioning (Ctrl+C to stop)..."
	@while true; do \
        echo "=== Ingress Status ==="; \
        kubectl get ingress ml-service 2>/dev/null || echo "Ingress not found"; \
        echo ""; \
        echo "=== ML Service Pods ==="; \
        kubectl get pods -l app=ml-service 2>/dev/null || echo "No pods found"; \
        echo ""; \
        ALB_DNS=$$(kubectl get ingress ml-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null); \
        if [ -n "$$ALB_DNS" ]; then \
            echo "✅ ALB DNS: $$ALB_DNS"; \
            echo "Try: curl http://$$ALB_DNS/health"; \
            break; \
        fi; \
        sleep 5; \
    done
