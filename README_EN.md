# nodewarden-docker

<p align="right"><a href="./README.md">中文</a></p>

Build Docker images automatically from the upstream [`shuaiplus/nodewarden`](https://github.com/shuaiplus/nodewarden) repository.

- If upstream `main` gets new commits, publish `dev` / `dev-<shortsha>`
- If upstream publishes a new Release, publish `latest` / `vX.Y.Z` from the matching tag source
- GitHub Actions runs every 4 hours

## Local run

Defaults:

- `ghcr.io/wochen5770/nodewarden:latest`
- port `8787`
- persist directory `./runtime/shared-state`
- R2 path (upstream default `wrangler.toml`)

Prepare config:

```bash
mkdir -p runtime/shared-state
cp .dev.vars.example runtime/.dev.vars
openssl rand -hex 32
```

Put the generated value into `runtime/.dev.vars`:

```dotenv
JWT_SECRET=your-random-string
```

Start:

```bash
docker compose up -d
```

Open:

- `http://127.0.0.1:8787`
