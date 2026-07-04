# nodewarden-docker

<p align="right"><a href="./README_EN.md">English</a></p>

基于上游 [`shuaiplus/nodewarden`](https://github.com/shuaiplus/nodewarden) 自动构建 Docker 镜像。

- 上游 `main` 有新提交：发布 `dev` / `dev-<shortsha>`
- 上游有新 Release：按对应 tag 源码发布 `latest` / `vX.Y.Z`
- GitHub Actions 每 4 小时运行一次

## 架构支持

本镜像支持以下架构：
- `linux/amd64` (x86_64)
- `linux/arm64` (ARM64/Apple Silicon)

Docker 会自动拉取适合你系统架构的镜像。

## 快速开始

### 1. 准备配置文件

```bash
# 创建必要的目录
mkdir -p runtime/shared-state

# 复制配置文件模板
cp .dev.vars.example runtime/.dev.vars

# 生成随机密钥
openssl rand -base64 48
```

编辑 `runtime/.dev.vars`，设置 JWT_SECRET：

```dotenv
JWT_SECRET=你生成的随机字符串（至少32字符）
```

### 2. 启动容器

```bash
docker compose up -d
```

### 3. 访问服务

默认访问地址：`http://localhost:8787`

## Nginx 反向代理配置

如果需要通过域名和 HTTPS 访问 NodeWarden，需要配置 Nginx 反向代理。

### ⚠️ 关键配置说明

NodeWarden 使用**同源策略**验证敏感操作（注册、密码重置等）的请求来源。Nginx 必须正确改写 `Host`、`Origin` 和 `Referer` 请求头，使其与后端地址匹配，否则会返回 `403 Forbidden origin` 错误。

### 配置示例

假设部署环境：
- 后端服务地址：`http://192.168.1.100:8787`（示例IP，请替换为你的实际地址）
- 公开访问域名：`https://vault.example.com`

```nginx
server {
    listen 443 ssl http2;
    server_name vault.example.com;
    
    # SSL 证书配置
    ssl_certificate /path/to/your/fullchain.pem;
    ssl_certificate_key /path/to/your/privkey.pem;
    
    location ^~ / {
        # 后端服务地址（改为你的实际地址）
        proxy_pass http://192.168.1.100:8787;
        
        # ⚠️ 关键配置：改写请求头使其与后端地址匹配
        # 这三行是解决 "Forbidden origin" 错误的关键
        proxy_set_header Host "192.168.1.100:8787";
        proxy_set_header Origin "http://192.168.1.100:8787";
        proxy_set_header Referer "http://192.168.1.100:8787/";
        
        # 标准反向代理配置
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header REMOTE-HOST $remote_addr;
        
        # WebSocket 支持（用于实时通知）
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_connection;
        proxy_http_version 1.1;
        
        # 缓存控制
        add_header X-Cache $upstream_cache_status;
        add_header Cache-Control no-cache;
        
        # 安全头
        add_header Strict-Transport-Security "max-age=31536000" always;
    }
}

# HTTP 自动跳转 HTTPS
server {
    listen 80;
    server_name vault.example.com;
    return 301 https://$server_name$request_uri;
}
```

### 为什么需要改写这些请求头？

NodeWarden 的注册和密码重置等敏感操作会验证请求来源，确保请求的 `Origin` 与实际请求 URL 的 origin 匹配：

```typescript
// NodeWarden 源码中的验证逻辑
const targetOrigin = new URL(request.url).origin;  // 从请求 URL 提取 origin
const origin = request.headers.get('Origin');       // 从请求头获取 Origin
if (origin !== targetOrigin) {
    return 403;  // 返回 "Forbidden origin" 错误
}
```

- 用户访问 `https://vault.example.com`，浏览器发送 `Origin: https://vault.example.com`
- Nginx 转发到后端 `http://192.168.1.100:8787`
- 如果不改写请求头，后端看到的 origin 不匹配，返回 403 错误
- 通过改写 `Host`、`Origin` 和 `Referer`，让后端认为请求来自自己，从而通过验证

### 可选：增加请求头缓冲区大小

如果 Nginx 报 `proxy_headers_hash` 警告，在 `http` 块中添加：

```nginx
http {
    proxy_headers_hash_max_size 1024;
    proxy_headers_hash_bucket_size 128;
    
    # ... 其他配置
}
```

## TLS 证书配置

如果配置了自动备份到 **HTTPS WebDAV** 服务器，需要确保容器内能验证 SSL 证书。

### 完整的 docker-compose.yml 配置

```yaml
services:
  nodewarden:
    image: ghcr.io/wochen5770/nodewarden:latest
    ports:
      - "8787:8787"
    environment:
      WRANGLER_PORT: 8787
      WRANGLER_PERSIST_DIR: /data/wrangler-state
      # TLS 证书配置（备份到 HTTPS 服务时需要）
      SSL_CERT_FILE: "/etc/ssl/certs/ca-certificates.crt"
      SSL_CERT_DIR: "/etc/ssl/certs"
    working_dir: /app
    volumes:
      - ./runtime/shared-state:/data
      - ./runtime/.dev.vars:/app/.dev.vars:ro
      # 挂载系统证书（备份到 HTTPS 服务时需要）
      - /etc/ssl/certs:/etc/ssl/certs:ro
    restart: unless-stopped
```

## 常见问题

### 访问时提示 "Forbidden origin"

**原因：** Nginx 反向代理配置不正确，后端无法通过同源验证。

**解决：** 参考上面的 Nginx 配置示例，确保正确设置了：
```nginx
proxy_set_header Host "你的后端地址:端口";
proxy_set_header Origin "http://你的后端地址:端口";
proxy_set_header Referer "http://你的后端地址:端口/";
```

### 备份到 HTTPS WebDAV 失败，提示 TLS 证书错误

**错误信息：** `TLS peer's certificate is not trusted; reason = unable to get local issuer certificate`

**原因：** 容器内缺少必要的 CA 证书来验证 SSL 连接。

**解决：** 在 `docker-compose.yml` 中添加证书挂载和环境变量：
```yaml
environment:
  SSL_CERT_FILE: "/etc/ssl/certs/ca-certificates.crt"
  SSL_CERT_DIR: "/etc/ssl/certs"
volumes:
  - /etc/ssl/certs:/etc/ssl/certs:ro
```

### 页面提示 "未检测到 JWT_SECRET"

**原因：** 环境变量配置不正确。

**解决：** 确保已在 `runtime/.dev.vars` 文件中配置 `JWT_SECRET`。**注意：** 环境变量必须写在 `.dev.vars` 文件中，而不是 `docker-compose.yml` 的 `environment` 部分，因为 Wrangler 只读取 `.dev.vars` 文件。

### 浏览器报错 "Cannot read properties of undefined (reading 'importKey')"

**原因：** 通过 HTTP 访问了服务。Web Crypto API 仅在 HTTPS 或 localhost 环境下可用。

**解决：** 
- 生产环境：通过 HTTPS 域名访问（配置 Nginx + SSL 证书）
- 本地测试：使用 `http://localhost:8787` 或 `http://127.0.0.1:8787`
- ⚠️ **不要使用** `http://192.168.x.x:8787` 等局域网 IP 地址访问

## 许可证

本项目仅提供打包配置，上游 NodeWarden 项目请参考：https://github.com/shuaiplus/nodewarden

## 相关链接

- [NodeWarden 上游项目](https://github.com/shuaiplus/nodewarden)
- [镜像仓库](https://github.com/WoChen5770/nodewarden-docker/pkgs/container/nodewarden)
