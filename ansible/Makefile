.PHONY: ansible terraform kubernetes

check:
	ansible --version
#	terraform --version

ssh_key:
	ssh-keygen -f ~/.ssh/home-key -t rsa -b 4096

kmaster:
	ansible-playbook -vvv -i inventory masters.yml --diff

kworkers:
	ansible-playbook -vvv -i inventory workers.yml --diff
