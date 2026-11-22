# 共享缓存

容器化构建的主要成本是下载、解包和编译。缓存放在宿主持久目录，容器只挂载，
不写入镜像层，也不随容器删除而丢失。

## 基本原则

1. **宿主目录优先**：`~/.cache/<project>`，可 `du`、可备份、可迁移。
2. **下载与编译分开**：下载缓存通常可跨版本共享；编译/sstate 缓存必须按工具链
   版本隔离。
3. **路径稳定**：同一份缓存被多个项目/容器共享时，容器内路径要固定。
4. **显式清理**：不自动删除下载缓存；编译缓存按时间或容量清理。
5. **并发加锁**：清理脚本与构建互斥。

## 典型布局

```text
~/.cache/<project>/
├── downloads/                  # 源码包、工具链压缩包，全局共享
├── ccache/                     # 编译器缓存
└── sstate/
    └── <version>/              # 按工具链/Yocto 版本隔离
        └── <arch>/             # 可选：按目标架构再分
```

## 环境变量映射

| 工具 | 变量 | 说明 |
| --- | --- | --- |
| Yocto / PetaLinux | `DL_DIR` | 下载缓存 |
| Yocto / PetaLinux | `SSTATE_DIR` | 共享状态缓存，按版本隔离 |
| Yocto | `CCACHE_TOP_DIR` / `CCACHE_DIR` | 编译器缓存 |
| Yocto | `BB_ENV_PASSTHROUGH_ADDITIONS` / `BB_ENV_EXTRAWHITE` | 把变量传入 BitBake |
| Buildroot | `BR2_DL_DIR` | 下载缓存 |
| 通用 | `CACHE_ROOT` | 自定义约定，供 `run.sh` 使用 |

优先级提醒：项目配置里的显式赋值通常高于环境变量。Yocto 的 `DL_DIR ?=` 是弱默认，
环境变量可以覆盖；`DL_DIR = ...` 是强赋值，环境变量无法覆盖。遇到缓存不生效时先
检查项目配置。

## 宿主目录还是命名卷

| | 宿主目录 | 命名卷 |
| --- | --- | --- |
| 可检查/备份 | 直接 | 需经容器 |
| 跨容器共享 | 直接 | 直接 |
| Windows/macOS 权限 | 需配置 | 更省心 |
| 迁移 | `mv`/`cp` | 导出/导入 |
| 大缓存性能 | 好（本地 fs） | 取决于存储驱动 |

构建缓存优先宿主目录；纯容器内部缓存（如包管理器 store）可用命名卷。

## 项目内软链接入

保留项目原来的缓存路径，换成软链：

```bash
ln -s ~/.cache/project/downloads /path/to/project/build/downloads
ln -s ~/.cache/project/sstate/1.0 /path/to/project/build/sstate-cache
```

容器必须把缓存根按**相同绝对路径**挂载，否则软链悬空：

```bash
--volume "$HOME/.cache/project:$HOME/.cache/project:z"
```

软链的好处：项目配置不用改（尤其是自动生成的配置），宿主机和容器内路径一致。
代价：任何手工 `docker run` 都要记得这个挂载。

## 并发

- 下载缓存：多数构建系统按文件加锁，允许多个构建共享。
- sstate/ccache：写入是内容寻址的，通常可并发；同一路径的清理需要互斥。
- 清理脚本用 `flock` 拿排他锁；构建脚本持有共享锁，清理检测到构建时直接退出。

示例：

```bash
exec 9>>"${cache_root}/.cache.lock"
flock -n 9 || { echo "build in progress"; exit 1; }
```

## 清理策略

### 编译缓存

- ccache：按容量上限清理（`ccache --max-size`、`ccache --cleanup`）。
- sstate：按 mtime 成对删除 `.siginfo` 与对应 `*.tar.*`；删除只会导致重建，
  不会破坏一致性。

### 下载缓存

默认不自动删除。源码包体积大但复用价值高；需要腾空间时人工按时间或项目清理。

### 迁移后的注意点

迁移/复制过来的缓存保留**原始 mtime**。刚迁移完不要用较小的“保留天数”跑 GC，
否则会删掉仍然有效的旧条目。先确认缓存能命中，再考虑清理。

### 清理前

1. 确认没有构建在运行。
2. 确认清理范围（哪个版本、哪个架构）。
3. 先用 `info` 看占用。
4. 清理后再跑一次最小构建验证。

## 迁移

同一文件系统内优先 `mv`（瞬时、不占额外空间），需要合并时再复制：

```bash
# 主缓存直接移动
mv /old/cache/downloads ~/.cache/project/downloads

# 第二份合并，保留目标已有文件
cp -a --reflink=auto -n /other/downloads/. ~/.cache/project/downloads/
```

- btrfs/XFS（开启 reflink）上 `cp --reflink=auto` 近乎零成本。
- 合并后核对文件数/大小，再删除源目录。
- 迁移不改变缓存签名；但缓存路径变化后要更新项目配置或软链。

## 容量与监控

```bash
du -sh ~/.cache/project/*
df -h ~/.cache/project
```

构建前检查剩余空间；大缓存建议单独分区或独立磁盘，避免占满根文件系统。

## 不要做

- 不要把缓存目录放进镜像层（体积失控、过期）。
- 不要在容器可写层里做长期缓存（`--rm` 后丢失）。
- 不要跨工具链版本共享 sstate/编译缓存。
- 不要在构建进行中删除缓存。
- 不要把许可证、密钥放进缓存目录。
