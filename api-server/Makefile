.PHONY: run build clean

run:
	go run .

build:
	go build -o bin/outgoing-email-example .

clean:
	rm -rf bin

gci:
	golangci-lint run
