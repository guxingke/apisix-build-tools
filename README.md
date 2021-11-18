## 私有构建方案

主要需求

1. 不需要打包为 rpm 等分发包。
2. 依赖固定的版本。
3. 仅支持在 `Centos 7`，x86_64 环境下构建。


## 编译步骤

1. 安装依赖
2. 编译 openresty
3. 编译 apisix

```
./build_openresty.sh
./build_apisix.sh
```

## 变更

1. 不改动原有代码
2. 添加私有实现


## 源 README

[README_OLD](README_old.md)
