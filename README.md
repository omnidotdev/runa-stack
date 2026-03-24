# 🌙 Runa Metarepo

This is the metarepo for the Runa service stack.

- Runa app: https://github.com/omnidotdev/runa-app
- Runa API: https://github.com/omnidotdev/runa-api

## Prerequisites

- Install [Tilt](https://tilt.dev)

## Getting Started

`cp services.yaml.template services.yaml`, then configure the services as you see fit. To disable a service, simply comment it out. Any included services will be locally cloned. A local path override for each service can be specified using the `path` key. If no path is explicitly specified, the service will be cloned to `services/service-name` by default.

> 💡 _Note that if nested repos are cloned within this metarepo (such as with the default path of `services/service-name`) for a service and you open this metarepo in your IDE, the IDE may mark the directories as ignored due to the `.gitignore` patterns. To combat this, open the services you want to work on in their own directory (e.g. a separate unit in a VS Code workspace) rather than working with them from within this metarepo._

To get started after setting up the service configuration, run `tilt up`. The `Tiltfile` will automatically pull in resources from any nested `Tiltfile`s it discovers.

> [!WARNING]
> Services might have their own setup requirements, such as environment variable configuration. Consult the service README to make sure you have satisfied all of the initial requirements.

## Self-Hosting

```bash
git clone https://github.com/omnidotdev/runa-stack.git
cd runa-stack
./start.sh
```

That's it. The start script auto-generates secrets, starts all containers, and waits for healthy.

### HTTPS

If [mkcert](https://github.com/FiloSottile/mkcert) is installed, the start script automatically generates trusted localhost certificates — HTTPS with zero browser warnings. Without mkcert, it falls back to HTTP.

```bash
# Install mkcert (optional, for trusted HTTPS)
# macOS: brew install mkcert
# Arch: pacman -S mkcert
# Ubuntu: apt install mkcert

# Then start (or restart with --fresh if already running)
./start.sh --fresh
```

### Custom Domain

Set your domain in `.env.local` and Caddy auto-provisions Let's Encrypt certificates:

```bash
BASE_URL=https://runa.example.com
AUTH_BASE_URL=https://auth.example.com
API_BASE_URL=https://api.example.com
```

### Services

| Container | Description | Default Port |
|-----------|-------------|--------------|
| `db` | PostgreSQL (Runa) | — |
| `auth-db` | PostgreSQL (auth) | — |
| `auth` | Authentication (login/signup) | 3001 |
| `api` | Runa API | 4000 |
| `app` | Runa web app | 443 (HTTPS) / 80 (HTTP) |
| `caddy` | Reverse proxy (TLS termination) | — |

### Managing

```bash
./start.sh          # Start (generates secrets on first run)
./start.sh --fresh  # Clean slate — wipe data and restart
./stop.sh           # Stop, preserve data
./stop.sh --clean   # Stop and remove all data, secrets, and certs
```

### Email Verification

Without SMTP configured, verification URLs appear in the auth container logs:

```bash
docker compose --env-file .env.local logs auth
```

To enable email delivery, set `SENDER_EMAIL_ADDRESS` in `.env.local`.

## License

The code in this repository is licensed under Apache 2.0, &copy; [Omni LLC](https://omni.dev). See [LICENSE.md](LICENSE.md) for more information.
