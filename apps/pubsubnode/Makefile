PROJECT_ID        := pubsub-benchmark
REGISTRY_LOCATION := europe-west9
REPOSITORY_NAME   := pubsub-node
IMAGE_NAME   := pubsub-node
TAG               := stable

CREDENTIALS_FILE := key.json

TOPIC        := projects/pubsub-benchmark/topics/node-topic
SUBSCRIPTION := node-subscription

build-image:
	docker build --no-cache=true -t ${REGISTRY_LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${IMAGE_NAME}:${TAG} .

push-image:
	docker push ${REGISTRY_LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${IMAGE_NAME}:${TAG}

run-publisher:
	docker run \
		--rm \
		-it \
		-p 8080:8080 \
		-e GOOGLE_APPLICATION_CREDENTIALS=/app/${CREDENTIALS_FILE} \
		-e TOPIC=${TOPIC} \
		--mount type=bind,source=$(shell pwd)/${CREDENTIALS_FILE},target=/app/${CREDENTIALS_FILE} \
		${REGISTRY_LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${IMAGE_NAME}:${TAG} \
		node index.js publish

run-subscriber:
	docker run \
		--rm \
		-it \
		-p 8080:8080 \
		-e GOOGLE_APPLICATION_CREDENTIALS=/app/${CREDENTIALS_FILE} \
		-e SUBSCRIPTION=${SUBSCRIPTION} \
		--mount type=bind,source=$(shell pwd)/${CREDENTIALS_FILE},target=/app/${CREDENTIALS_FILE} \
		${REGISTRY_LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${IMAGE_NAME}:${TAG} \
		node index.js subscribe

.PHONY: build
