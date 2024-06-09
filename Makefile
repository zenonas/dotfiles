.PHONY: install
install:
	./install.sh

.PHONY: git-update
git-update:
	git pull

.PHONY: update
update: git-update install
