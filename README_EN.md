# nodewarden-docker

<p align="right"><a href="./README.md">中文</a></p>

Build Docker images automatically from the upstream [`shuaiplus/nodewarden`](https://github.com/shuaiplus/nodewarden) repository.

- If upstream `main` gets new commits, publish `dev` / `dev-<shortsha>`
- If upstream publishes a new Release, publish `latest` / `vX.Y.Z` from the matching tag source
- GitHub Actions runs every 4 hours

## Architecture Support

This image supports the following architectures:
- `linux/amd64` (x86_64)
- `linux/arm64` (ARM64/Apple Silicon)

Docker will automatically pull the image matching your system architecture.

## Quick Start

### 1. Prepare Configuration

```bash
# Create necessary directories
mkdir -p runtime/shared-state

# Copy configuration template
cp .dev.vars.example runtime/.dev.vars

# Generate random secret
openssl rand -base64 48
```

Edit `runtime/.dev.vars` and set JWT_SECRET:

```dotenv
JWT_SECRET=your-generated-random-string-at-least-32-chars
```

### 2. Start Container

```bash
docker compose up -d
```

### 3. Access Service

Default access URL: `http://localhost:8787`

## Nginx Reverse Proxy Configuration

If you need to access NodeWarden via domain name and HTTPS, configure Nginx reverse proxy.

### ⚠️ Critical Configuration

NodeWarden uses **same-origin policy** to verify sensitive operations (registration, password reset, etc.). Nginx must correctly rewrite `Host`, `Origin`, and `Referer` headers to match the backend address, otherwise it will return `403 Forbidden origin` error.

### Configuration Example

Deployment scenario:
- Backend service address: `http://192.168.1.100:8787` (example IP, replace with your actual address)
- Public domain: `https://vault.example.com`

```nginx
server {
    listen 443 ssl http2;
    server_name vault.example.com;
    
    # SSL certificate configuration
    ssl_certificate /path/to/your/fullchain.pem;
    ssl_certificate_key /path/to/your/privkey.pem;
    
    location ^~ / {
        # Backend service address (replace with your actual address)
        proxy_pass http://192.168.1.100:8787;
        
        # ⚠️ Critical: Rewrite headers to match backend address
        # These three lines are key to solving "Forbidden origin" errors
        proxy_set_header Host "192.168.1.100:8787";
        proxy_set_header Origin "http://192.168.1.100:8787";
        proxy_set_header Referer "http://192.168.1.100:8787/";
        
        # Standard reverse proxy configuration
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header REMOTE-HOST $remote_addr;
        
        # WebSocket support (for real-time notifications)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_connection;
        proxy_http_version 1.1;
        
        # Cache control
        add_header X-Cache $upstream_cache_status;
        add_header Cache-Control no-cache;
        
        # Security headers
        add_header Strict-Transport-Security "max-age=31536000" always;
    }
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name vault.example.com;
    return 301 https://$server_name$request_uri;
}
```

### Why Rewrite These Headers?

NodeWarden validates request origins for sensitive operations, ensuring the `Origin` header matches the actual request URL's origin:

```typescript
// Validation logic in NodeWarden source code
const targetOrigin = new URL(request.url).origin;  // Extract origin from request URL
const origin = request.headers.get('Origin');       // Get Origin from request header
if (origin !== targetOrigin) {
    return 403;  // Return "Forbidden origin" error
}
```

- User visits `https://vault.example.com`, browser sends `Origin: https://vault.example.com`
- Nginx forwards to backend `http://192.168.1.100:8787`
- Without header rewriting, backend sees mismatched origins and returns 403
- By rewriting `Host`, `Origin`, and `Referer`, backend thinks the request comes from itself and passes validation

### Optional: Increase Header Buffer Size

If Nginx reports `proxy_headers_hash` warnings, add to `http` block:

```nginx
http {
    proxy_headers_hash_max_size 1024;
    proxy_headers_hash_bucket_size 128;
    
    # ... other configurations
}
```

## TLS Certificate Configuration

If you've configured automatic backups to **HTTPS WebDAV** servers, ensure the container can validate SSL certificates.

### Complete docker-compose.yml Configuration

```yaml
services:
  nodewarden:
    image: ghcr.io/wochen5770/nodewarden:latest
    ports:
      - "8787:8787"
    environment:
      WRANGLER_PORT: 8787
      WRANGLER_PERSIST_DIR: /data/wrangler-state
      # TLS certificate configuration (required for HTTPS backups)
      SSL_CERT_FILE: "/etc/ssl/certs/ca-certificates.crt"
      SSL_CERT_DIR: "/etc/ssl/certs"
    working_dir: /app
    volumes:
      - ./runtime/shared-state:/data
      - ./runtime/.dev.vars:/app/.dev.vars:ro
      # Mount system certificates (required for HTTPS backups)
      - /etc/ssl/certs:/etc/ssl/certs:ro
    restart: unless-stopped
```

## Troubleshooting

### "Forbidden origin" Error

**Cause:** Nginx reverse proxy configuration is incorrect, backend cannot pass same-origin validation.

**Solution:** Refer to the Nginx configuration example above, ensure these are correctly set:
```nginx
proxy_set_header Host "your-backend-address:port";
proxy_set_header Origin "http://your-backend-address:port";
proxy_set_header Referer "http://your-backend-address:port/";
```

### HTTPS WebDAV Backup Fails with TLS Certificate Error

**Error message:** `TLS peer's certificate is not trusted; reason = unable to get local issuer certificate`

**Cause:** Container lacks necessary CA certificates to validate SSL connections.

**Solution:** Add certificate mounts and environment variables in `docker-compose.yml`:
```yaml
environment:
  SSL_CERT_FILE: "/etc/ssl/certs/ca-certificates.crt"
  SSL_CERT_DIR: "/etc/ssl/certs"
volumes:
  - /etc/ssl/certs:/etc/ssl/certs:ro
```

### "JWT_SECRET Not Detected" Error

**Cause:** Environment variable configuration is incorrect.

**Solution:** Ensure `JWT_SECRET` is configured in `runtime/.dev.vars` file. **Note:** Environment variables must be in the `.dev.vars` file, not in `docker-compose.yml`'s `environment` section, because Wrangler only reads the `.dev.vars` file.

### Browser Error "Cannot read properties of undefined (reading 'importKey')"

**Cause:** Accessing the service via HTTP. Web Crypto API is only available in HTTPS or localhost environments.

**Solution:**
- Production: Access via HTTPS domain (configure Nginx + SSL certificate)
- Local testing: Use `http://localhost:8787` or `http://127.0.0.1:8787`
- ⚠️ **Do NOT use** LAN IP addresses like `http://192.168.x.x:8787`

## License

This project only provides packaging configuration. For the upstream NodeWarden project, see: https://github.com/shuaiplus/nodewarden

## Links

- [NodeWarden Upstream Project](https://github.com/shuaiplus/nodewarden)
- [Image Registry](https://github.com/WoChen5770/nodewarden-docker/pkgs/container/nodewarden)
