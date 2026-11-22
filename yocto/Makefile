.PHONY: build run cache-info cache-gc cache-migrate

ARGS ?=

build:
	./build.sh

run:
	./run.sh

cache-info:
	./cache.sh info

cache-gc:
	./cache.sh gc $(ARGS)

cache-migrate:
	./cache.sh migrate $(ARGS)
