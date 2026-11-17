# Shadowsocks-rust 离线一键部署包

这个压缩包已经包含官方编译好的 `ssserver`，安装时：

- 不访问 Debian/Ubuntu 软件库
- 不访问 GitHub
- 不需要安装 Python、curl、OpenSSL 或解压工具
- 自动选择 Intel/AMD 64 位或 ARM64 程序
- 自动生成密码、systemd 服务和 v2rayN 的 `ss://` 导入链接

内置版本：Shadowsocks-rust `v1.25.0`。来源：<https://github.com/shadowsocks/shadowsocks-rust/releases/tag/v1.25.0>

## 支持范围

- 64 位 Linux
- x86_64（Intel/AMD）或 ARM64
- 使用 systemd 的常见 Debian、Ubuntu、Rocky Linux、AlmaLinux 等服务器

不支持 Windows、32 位 Linux和没有 systemd 的特殊系统。

## 使用方法

### 1. 上传文件夹

在本地解压 ZIP，把整个 `shadowsocks-rust-offline` 文件夹上传到新服务器。

### 2. 确认公网 IP

假设新服务器公网 IP 是 `1.2.3.4`，运行：

```bash
cd shadowsocks-rust-offline
sudo SERVER_IP=1.2.3.4 bash install.sh
```

如果省略 `SERVER_IP`，脚本会在终端里询问。

### 3. 查看导入链接

```bash
sudo cat /root/shadowsocks-rust-client.txt
```

复制完整的 `ss://` 行，在 v2rayN 中选择“服务器”→“从剪贴板导入批量 URL”。

### 4. 云防火墙

在云服务器控制面板放行：

```text
TCP 443
UDP 443
```

云安全组像小区大门；即使程序已经运行，大门没开也无法连接。

## 检查

```bash
sudo bash check.sh
```

## 重装或更改公网 IP

再次运行安装命令即可，原密码会保留：

```bash
sudo SERVER_IP=新的公网IP bash install.sh
```

## 自定义端口或密码

```bash
sudo SERVER_IP=1.2.3.4 SS_PORT=8443 SS_PASSWORD='至少8位安全密码' bash install.sh
```

换端口后，云防火墙也要放行对应的 TCP 和 UDP 端口。

## 卸载

保留密码和配置：

```bash
sudo bash uninstall.sh
```

彻底删除：

```bash
sudo PURGE=1 bash uninstall.sh
```

## 安全说明

- 密码和 `ss://` 链接只保存在服务器的 root 私有文件中。
- 离线包本身不含你的服务器密码、SSH 密钥或节点信息。
- 离线安装可以绕过失效的软件仓库，但无法让已经停止维护的旧操作系统重新获得安全更新；长期运行仍建议使用 Debian 12 或受支持的 Ubuntu。
- 新服务器验证可用后，再关闭旧服务器。
