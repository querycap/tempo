VERSION = $(shell git config -f .gitmodules submodule.tempo.tag)

info:
	@echo tempo:$(VERSION)

COMPONENT = tempo
HUB = docker.io/querycaptempo
TARGETARCHS = amd64 arm64

patch:
	cd tempo && sed -i '' 's/jaegertracing/ghcr.io\/querycap\/istio/g' cmd/tempo-query/Dockerfile

buildx: patch
	cd tempo && sh -c "$(foreach arch,$(TARGETARCHS),GOOS=linux GOARCH=$(arch) make $(COMPONENT);)"
	docker buildx build \
		--file ./tempo/cmd/$(COMPONENT)/Dockerfile \
		$(foreach h,$(HUB),--tag=$(h)/$(COMPONENT):$(VERSION)) \
        $(foreach p,$(TARGETARCHS),--platform=linux/$(p)) \
 		./tempo

dep:
	git submodule update --init --recursive
	git submodule foreach 'tag="$$(git config -f $$toplevel/.gitmodules submodule.$$name.tag)"; [[ -n $$tag ]] && git reset --hard && git checkout $$tag || echo "this module has no branch"'

