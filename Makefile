.PHONY: terraform ansible

check:
	ansible --version
#	terraform --version

ssh_key:
	ssh-keygen -f ~/.ssh/home-key -t rsa -b 4096

kmaster:
	cd ansible; \
		ansible-playbook -vvv -i inventory masters.yml --diff

kworkers:
	cd ansible; \
		ansible-playbook -vvv -i inventory workers.yml --diff
