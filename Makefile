TF = terraform -chdir=infra/terraform

up:
	$(TF) init
	$(TF) apply -auto-approve $(TFARGS)

down:
	$(TF) destroy -auto-approve $(TFARGS)

.PHONY: up down
