VERSION = $(shell git config -f .gitmodules submodule.tempo.tag)

info:
	@echo tempo:$(VERSION)

COMPONENT = tempo
HUB = docker.io/querycaptempo
TARGETARCHS = amd64 arm64

patch:
	cd tempo && sed -i -e 's/jaegertracing\/jaeger-query:1.20.0/querycapjaegertracing\/jaeger-query:1.21.0/g' cmd/tempo-query/Dockerfile

buildx: patch
	cd tempo && sh -c "$(foreach arch,$(TARGETARCHS),GOOS=linux GOARCH=$(arch) make $(COMPONENT) VERSION=$(VERSION);)"
	cat ./tempo/cmd/$(COMPONENT)/Dockerfile
	docker buildx build \
		--push \
		--file ./tempo/cmd/$(COMPONENT)/Dockerfile \
		$(foreach h,$(HUB),--tag=$(h)/$(COMPONENT):$(VERSION)) \
        $(foreach p,$(TARGETARCHS),--platform=linux/$(p)) \
 		./tempo

dep:
	git submodule update --init
	git submodule foreach 'tag="$$(git config -f $$toplevel/.gitmodules submodule.$$name.tag)"; [[ -n $$tag ]] && git reset --hard && git fetch --tags && git checkout $$tag || echo "this module has no branch"'


DEBUG ?= 1

HELM ?= helm upgrade --install --create-namespace
ifeq ($(DEBUG),1)
	HELM = helm template --dependency-update
endif

apply:
	$(HELM) --namespace=tempo-system tempo ./charts/tempo

sync-helm:
	rm -rf charts/tempo/templates/*
	cp tempo/operations/helm/tempo-microservices/templates/* charts/tempo/templates/
	for i in $(shell find charts/tempo/templates -type f); do sed -i '' 's/default.svc.cluster.local/{{ .Release.Namespace }}.svc.cluster.local/g' $${i}; done
	sed -i '' 's/opencensus: null/zipkin: null/g' charts/tempo/templates/configmap-tempo.yaml
	sed -i '' 's/name: ingest/name: tempo-ingest/g' charts/tempo/templates/service-ingest.yaml
	cp tempo/operations/helm/tempo-microservices/values.yaml charts/tempo/values.yaml
	sed -i '' 's/grafana\/tempo:latest/querycaptempo\/tempo:$(VERSION)/g' charts/tempo/values.yaml
	sed -i '' 's/grafana\/tempo-query:latest/querycaptempo\/tempo-query:$(VERSION)/g' charts/tempo/values.yaml

