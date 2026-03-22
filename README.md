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
cp .env.local.template .env.local
# Generate secrets: openssl rand -base64 32
# Set DB_PASSWORD, AUTH_SECRET, AUTH_CLIENT_ID, AUTH_CLIENT_SECRET in .env.local
docker compose --env-file .env.local up -d
```

This starts 5 containers:

| Container | Description | Port |
|-----------|-------------|------|
| `db` | PostgreSQL (Runa) | 5432 |
| `auth-db` | PostgreSQL (auth) | — |
| `auth` | Authentication (login/signup) | 3001 |
| `api` | Runa API | 4000 |
| `app` | Runa web app | 3000 |

Open `http://localhost:3000` and create your first account.

Verification URLs appear in the auth container logs:

```bash
docker compose logs auth
```

## License

The code in this repository is licensed under Apache 2.0, &copy; [Omni LLC](https://omni.dev). See [LICENSE.md](LICENSE.md) for more information.
