.PHONY: install update test

install:
	./install.sh

update:
	./update.sh

test:
	bats tests
	shellcheck install.sh update.sh
