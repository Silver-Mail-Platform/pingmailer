.PHONY: run build clean run-https docker-build docker-run docker-run-https docker-stop docker-clean

run:
	go run .

run-https:
	go run . -port 8443 -cert ../mail-infra/services/silver-config/certbot/keys/etc/live/yourdomain.com/fullchain.pem -key ../mail-infra/services/silver-config/certbot/keys/etc/live/yourdomain.com/privkey.pem

build:
	go build -o bin/pingmailer-api .

clean:
	rm -rf bin

# Docker commands
docker-build:
	docker build -t pingmailer-api .

docker-run:
	docker run -d -p 8080:8080 --name pingmailer-api pingmailer-api

docker-run-https:
	docker run -d \
		-p 8443:8443 \
		-e PORT=8443 \
		-e CERT_FILE=/certs/live/yourdomain.co/fullchain.pem \
		-e KEY_FILE=/certs/live/yourdomain.co/privkey.pem \
		-v $(PWD)/../mail-infra/services/silver-config/certbot/keys/etc:/certs:ro \
		--network mail-network \
		--name pingmailer-api \
		pingmailer-api

docker-stop:
	docker stop pingmailer-api || true
	docker rm pingmailer-api || true

docker-clean: docker-stop
	docker rmi pingmailer-api || true

docker-compose-up:
	docker-compose up -d

docker-compose-https:
	docker-compose -f docker-compose.https.yml up -d

docker-compose-down:
	docker-compose down

docker-logs:
	docker logs -f pingmailer-api
