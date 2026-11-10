# MCU AI Firmware Skill

把 **AI 辅助开发单片机固件**（STM32 / ARM Cortex-M，`arm-none-eabi-gcc` + Make）
的整套工作流做成一个可复用的 Agent Skill：

- 分层架构与依赖边界（app / service / driver / bsp / common / config / mcu）
- 主机（PC）单元测试 + 目标板交叉编译的双构建体系
- SWD / OpenOCD 真机调试与硬件在环（HIL）验收方法
- 协议先行、变更留痕、发布门禁
- AI 协作规则（范围控制、真实输入验证、如实汇报、密钥管理）

适用于**新项目初始化**，也适用于**日常开发和排障**。

---

## 快速开始

### Claude Code

```bash
# 个人级（所有项目可用）
cp -r skill/mcu-ai-firmware ~/.claude/skills/

# 或项目级（只对某个仓库生效）
mkdir -p <repo>/.claude/skills
cp -r skill/mcu-ai-firmware <repo>/.claude/skills/
```

之后直接描述任务即可，例如“给这个 STM32 工程加一个 Modbus 从站服务并写主机单测”。

### 其他 AI 工具（Cursor / Codex / 自建 Agent）

把 `skill/mcu-ai-firmware/SKILL.md` 作为系统提示或项目规则导入，按需让它继续读
`references/` 下的文件（渐进式加载，避免一上来塞满上下文）。

### 模板

- `templates/CLAUDE.md` — 可直接改名的项目规则文件（AI 每次会话都会读）
- `templates/check_architecture.sh` — 用脚本强制执行分层依赖规则

---

## 目录

```text
skill/mcu-ai-firmware/
├── SKILL.md                     # 入口：工作流循环 + 硬规则 + 索引
├── references/
│   ├── layered-architecture.md  # 分层、依赖矩阵、bsp 抽象、初始化顺序
│   ├── build-and-ci.md          # 双构建、编译选项、布局/大小预算、CI 门禁
│   ├── host-testing.md          # 主机单测结构、桩注入、确定性、回归规则
│   ├── hil-debugging.md         # OpenOCD/SWD、静态量取证、时序测量、坑
│   ├── protocol-design.md       # 二进制帧、字节序、CRC、配置记录版本化
│   ├── power-and-reliability.md # 看门狗、Standby、RTC 闹钟、低压保护
│   ├── change-log-and-docs.md   # CLAUDE.md/协议文档/变更日志写法
│   ├── windows-toolchain.md     # MSYS2 UCRT64、Python venv、PowerShell 编码等
│   └── git-and-release.md       # 托管选择、凭证、打包、发布前脱敏
└── templates/
    ├── CLAUDE.md
    └── check_architecture.sh
```

---

## 这套流程解决什么问题

1. **AI 写的固件能验收**：纯逻辑全部在主机上可测，硬件相关代码被压缩到最薄的一层。
2. **排障有证据**：用 SWD 读静态变量、抓真实报文、量真实时序，而不是猜。
3. **改动可追溯**：每个行为变更都写进带日期的变更日志（文件、原因、测试数、HIL 证据）。
4. **不会悄悄跑偏**：分层检查、大小预算、看门狗和复位原因都是自动校验项。
5. **人机协作可控**：范围、真实输入验证、如实报告、密钥不落库。

---

## English

A portable agent skill for AI-driven bare-metal MCU firmware development:
layered architecture, host-side unit tests, hardware-in-the-loop debugging over
SWD/OpenOCD, protocol-first documentation, and release gates. Copy
`skill/mcu-ai-firmware/` into your agent's skills directory and point it at the
repository; start from `SKILL.md`, then load the references you need.

## License

MIT — see `LICENSE`.
