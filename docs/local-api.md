# 本地配置 HTTP API

桌面 App 提供本机 HTTP 接口，外部工具直接提交配置文本并读取结构化结果。
解析、编译、Geodata 访问和 libXray 校验均复用 App 实现，不要求安装独立命令行客户端。
App 必须已经启动并完成正常服务准备；关闭窗口到托盘不影响接口，退出 App 则接口不可用，
即使系统 VPN 仍在运行。移动端不提供此入口。

## 启用与凭据

在“高级 → Xray → 本地 API”中启用并保存，默认关闭。默认地址为
`http://127.0.0.1:18587`；端口可设置为 1024–65535，仅监听 IPv4 loopback，不能改为局域网地址。
端口占用或偏好写入失败时，保留原有地址和凭据；界面分别展示已保存设置与实际监听状态。

首次启用生成 32 随机字节的 Base64URL Token，保存在设备偏好中，重启不变化。
用户通过 App 的复制按钮将 Token 配置给受信任的本机调用工具；每次请求在
`Authorization: Bearer <token>` 中携带它，不扫描或直接读取 App 沙箱容器。
凭据的接收与保管由调用工具负责，App 不建立独立的客户端凭据目录或登录流程。
不要将 Token 放进 AI 提示词、URL、命令行参数或日志。

- 关闭接口只停止监听，保留 Token；重置立即撤销旧 Token，调用工具需要更新凭据。
- 清空 App 数据删除 API 偏好、关闭监听并清除内存凭据；连接配置备份/恢复不携带 API 设置或 Token。
- 调用工具应避免在输出中暴露 Token，并限制持久凭据的读取权限；本机 Token 鉴权不能
  防御已经控制同一用户账户的恶意程序。
- 所有接口都要求 `Authorization: Bearer <token>`。没有免认证获取 Token 的 HTTP 接口，
  不提供 OAuth、自动配对或公网访问。
- Host 必须与实际 `127.0.0.1:端口` 一致；拒绝带 Origin、查询参数和代理绝对 URI 的请求，
  不启用跨域访问。调用工具应直连回环地址，禁用环境代理和自动重定向，避免泄露凭据。

## 接口合同

协议版本为 `apiVersion: 1`，独立于 App 版本和 libXray Invoke API 版本。

| 方法与路径 | 行为 |
| --- | --- |
| `GET /api/v1/info` | 返回 API、App、内核版本、宿主平台和支持的配置类型；不返回凭据或用户资产 |
| `POST /api/v1/config/validate` | 使用 App 的解析与验证投影，调用现有 `testXray` |
| `POST /api/v1/config/compile` | 使用现有 `ConnectionCompiler` 生成运行配置预览，不调用 `testXray` |

POST 使用 `Content-Type: application/json`，请求体上限 16 MiB。提交的是原始文本字符串，
不能先把配置解析后重新编码，否则原文位置会变化。

```json
{
  "kind": "raw",
  "text": "{\n  \"name\": \"Example\",\n  \"outbounds\": [{\"protocol\": \"freedom\", \"tag\": \"direct\"}]\n}"
}
```

`kind` 必须显式指定：

| kind | text 的含义 |
| --- | --- |
| `outbound` | 一个 outbound 对象，与节点编辑器一致；不是包含 outbounds 的完整文档 |
| `routing` | 常规自定义路由文档，包含空接入槽 |
| `advanced-routing` | 高级自定义路由模板，遵守其独立字段边界 |
| `raw` | 完整 Raw JSON，不施加常规/高级模板白名单 |

可选 `name` 按对应 App 输入类型处理；配置名称与节点 tag 的语义不混用。
模板校验使用 App 现有 freedom 占位出站，不要求真实节点，也不验证实际节点组合。
`validate` 不接受 `outbounds` 或 `options`，避免将未检查的实际运行参数误认为已经通过验证。

### 编译预览

`compile` 除 `kind/text/name` 外，必须提供 `options`：

```json
{
  "platform": "macos",
  "sessionDirectory": "/explicit/preview-directory",
  "metricsPort": 19001,
  "socksPort": 19002,
  "ipv6": true
}
```

- `platform` 为 `ios/macos/android/windows/linux`；表示生成配置的目标，不是远程运行请求。
- Windows 必须显式提供 `windowsMode: exe|msix`；Windows/Linux 必须提供 `interfaceName`。
- 可选 `tunDnsIpv4Address/tunDnsIpv6Address/logEnabled/logFilesSupported/logLevel/dnsLog/maskAddress`
  使用 `RuntimeOptions` 的同名默认值，不读取用户当前连接策略。
- `routing/advanced-routing` 必须另提供 `outbounds` 数组，真实节点数与模板接入槽一致。
- `outbound` 用自身节点生成全部经过 VPN 的预览；`raw` 使用自身节点。这两类不接受额外 outbounds。
- 资源路径使用当前 App 的已安装目录；生成跨平台 JSON 不等于该路径在目标设备可用。
  不检查端口空闲或网卡存在，不创建 `sessionDirectory`，不写正式运行文件。

## 结果语义

```json
{
  "apiVersion": 1,
  "status": "failed",
  "stage": "input",
  "diagnostics": [{
    "code": "invalidConfiguration",
    "message": "Original diagnostic",
    "offset": 12,
    "line": 2,
    "column": 5
  }]
}
```

- `status` 为 `passed/failed/notRun`，`stage` 为 `input/compile/kernel`。
  `passed + compile` 只证明预览生成，不代表内核通过；HTTP 200 也不等于配置正确。
- `diagnostics` 包含稳定分类码及原因，可带 `path/offset/line/column`；offset 和 column 采用
  Dart 原文 UTF-16 code unit，offset 从 0 开始，行列从 1 开始。没有可靠原文位置时省略，
  不从 libXray 错误文字猜字段，不使用生成副本的位置。
  `path` 为属性名与整数索引组成的数组，例如 `["routing", "rules", 0, "domain"]`。
- 校验可返回 `validationConfig`，编译可返回 `compiledConfig`，均为 JSON 文本；其中可能含节点凭据。
  `limitations` 描述本次检查未覆盖的范围。服务只返回结果，不写输出文件；调用工具若要保存，
  应使用用户明确选择的目标并保护其中的敏感内容。
- 认证失败为 401，浏览器 Origin 为 403，忙碌为 409，超限为 413，服务暂停为 503；
  传输/服务不可用与配置被拒绝分别处理，未执行不算通过。

校验共用 [Xray 配置合同](xray-configuration.md) 的投影和 `LoadConfig → core.New → Close`。
不下载缺失 Geodata，不导入文件，不检查数据库名称重复或资产数量限制，不承诺配置已可保存、
VPN 必然启动或联网成功。缺少必要本地资源时报告原始错误。

## 并发、生命周期与副作用

本地接口最多接收一个正在处理的配置请求，其他请求立即报告忙碌，不无限排队。
内核调用与 App 自己的操作沿用现有原生串行机制；没有新增全局业务锁。
Geodata 读取继续进入既有文件访问队列。清空数据或恢复时暂停新请求，并等待已接收请求结束。

客户端超时、断开或用户关闭接口不能取消已经进入 Native 的校验，也不能触发自动重试。
桌面 VPN 内核运行在独立进程，但校验仍在 App 进程；`core.New` 可能修改 Go 全局状态、
读取文件或创建协议资源。这不是安全沙箱，不能用于不受信任的远程配置服务，
也不能承诺进程级崩溃都能转换成 HTTP 错误。

API 不暴露通用 `invoke`，不允许保存/删除资产、修改正式配置或启停 VPN。

## 验证

在仓库根目录执行 HTTP 服务、配置处理、生命周期与设置页测试：

```shell
flutter test test/service/advanced/local_api test/pages/advanced/local_api
```

`http_integration_test.dart` 使用通用 HTTP 客户端访问正式服务及配置处理器，覆盖认证、
info、校验、原文错误位置及编译预览。它默认随测试执行，不需要外部工具、持久凭据或输出文件。
内核结果通过测试注入；测试只证明认证、传输、配置投影及诊断协议，不代表已在签名 App 内
执行 Native 校验。四种输入类型与 UI 投影的一致性由配置处理测试覆盖。

本机单元测试和 HTTP 回环测试不能替代签名 App 中的实际监听、Windows MSIX 安装环境及
各平台 Native 校验链路的验收。macOS 验证不启动 VPN，Windows/Linux 实机行为留待对应平台验收。
