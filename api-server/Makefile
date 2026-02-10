.PHONY: run build clean run-https

run:
	go run .

run-https:
	go run . -port 8443 -cert ../mail-infra/services/silver-config/certbot/keys/etc/live/yourdomain.com/fullchain.pem -key ../mail-infra/services/silver-config/certbot/keys/etc/live/yourdomain.com/privkey.pem

build:
	go build -o bin/outgoing-email-example .

clean:
	rm -rf bin
