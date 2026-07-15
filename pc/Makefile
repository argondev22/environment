INVENTORY=inventory.ini
VAULT_FILE=.vault_pass

.PHONY: check apply syntax clean yamllint

syntax:
	@ansible-playbook --syntax-check -i $(INVENTORY) playbook.yml

check:
	@ansible-playbook -i $(INVENTORY) playbook.yml --check --diff --vault-password-file $(VAULT_FILE) --ask-become-pass

apply:
	@ansible-playbook -i $(INVENTORY) playbook.yml --vault-password-file $(VAULT_FILE) --ask-become-pass

debug:
	@ansible-playbook -i $(INVENTORY) playbook.yml --check --diff -vvv --vault-password-file $(VAULT_FILE) --ask-become-pass

clean:
	@rm -f $(VAULT_FILE)
