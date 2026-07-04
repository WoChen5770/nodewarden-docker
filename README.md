# nodewarden-docker

<p align="right"><a href="./README_EN.md">English</a></p>

基于上游 [`shuaiplus/nodewarden`](https://github.com/shuaiplus/nodewarden) 自动构建 Docker 镜像。

- 上游 `main` 有新提交：发布 `dev` / `dev-<shortsha>`
- 上游有新 Release：按对应 tag 源码发布 `latest` / `vX.Y.Z`
- GitHub Actions 每 4 小时运行一次

## 本地运行

默认使用：

- `ghcr.io/wochen5770/nodewarden:latest`
- 端口 `8787`
- 持久化目录 `./runtime/shared-state`
- R2 路线（上游默认 `wrangler.toml`）

准备配置：

```bash
mkdir -p runtime/shared-state
cp .dev.vars.example runtime/.dev.vars
openssl rand -hex 32
```

把生成的值写入 `runtime/.dev.vars`：

```dotenv
JWT_SECRET=你的随机字符串
```

启动：

```bash
docker compose up -d
```

访问：

- `http://127.0.0.1:8787`
