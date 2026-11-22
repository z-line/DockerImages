# 模板使用说明

三个文件是一套最小可用的开发环境：

```text
Dockerfile.dev      -> 镜像定义（非 root、UID/GID 可传参）
devcontainer.json   -> IDE/Dev Container 配置
run.sh              -> 命令行运行包装
```

复制到项目后按需修改路径和依赖。

## Docker 还是 Podman

`devcontainer.json` 默认带 Podman 参数：

```json
"runArgs": ["--userns=keep-id"]
```

- **标准 Docker**：删除整个 `runArgs`，保留 `"updateRemoteUserUID": true`。
  Docker 不支持 `--userns=keep-id`，直接使用会报错。
- **Podman**：保留 `runArgs`；把 `"updateRemoteUserUID"` 设为 `false` 或删除。
  UID 已由 `keep-id` 映射，重复修改可能冲突。

SELinux 主机上，Podman 的 bind mount 可能需要 `:z`；开发容器可以用
`"--security-opt", "label=disable"` 放进 `runArgs`，但只建议在本地开发使用。

## 复制

```bash
mkdir -p .devcontainer
cp <skill>/templates/Dockerfile.dev .devcontainer/Dockerfile
cp <skill>/templates/devcontainer.json .devcontainer/devcontainer.json
cp <skill>/templates/run.sh scripts/run-dev.sh
chmod +x scripts/run-dev.sh
```

如果 Dockerfile 放在 `.devcontainer/`，把 `build.dockerfile` 改成 `"Dockerfile"`，
`build.context` 保持 `".."`，以便引用项目根目录的依赖文件。

## 缓存挂载

模板挂载：

```json
"source=${localEnv:HOME}/.cache/project-dev,target=/home/dev/.cache,type=bind
```

首次使用前创建目录：

```bash
mkdir -p ~/.cache/project-dev
```

Windows/macOS 上 `${localEnv:HOME}` 可能为空，改用命名卷更稳：

```json
"source=project-dev-cache,target=/home/dev/.cache,type=volume"
```

## 验证

```bash
# JSON 语法
jq empty .devcontainer/devcontainer.json

# 构建并进入
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash -lc 'id; touch /workspace/.t && rm /workspace/.t'

# 没有 devcontainer CLI 时，用同一镜像的 run.sh 验证
./scripts/run-dev.sh . bash -lc 'id; command -v git'
```
