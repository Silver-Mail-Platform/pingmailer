# PingMailer

PingMailer is a small service that allows you send outgoing emails. It contains:
- A Go API server that accepts SMTP credentials and sends templated emails.
- An outgoing only instance for SMTP using [Silver](https://github.com/LSFLK/silver) components. 

## Repo Layout

- `api-server/` Go API service that accepts SMTP credentials and sends templated emails.
- `mail-infra/` Silver SMTP components
