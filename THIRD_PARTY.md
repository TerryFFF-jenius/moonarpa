# 来源与许可边界

MoonARPA 的 MoonBit 实现、Python oracle、示例和文档为本项目独立编写，采用 MIT。没有从 KenLM、SRILM 或 MoonBit 近邻复制引擎实现。

- ARPA 回退模型格式与评分行为参考 [KenLM](https://github.com/kpu/kenlm) 和其测试。KenLM 主体采用 LGPL-2.1-or-later，详见 [上游 LICENSE](https://github.com/kpu/kenlm/blob/4cb443e60b7bf2c0ddf3c745378f76cb59e254e5/LICENSE)。这不是将 KenLM 重许可为 MIT。
- `scripts/verify_reference.py` 在运行时读取 KenLM `lm/test.arpa`，固定提交 `4cb443e60b7bf2c0ddf3c745378f76cb59e254e5`、SHA256 `fa7d176e45ce43669a4e057c73c112ffe5be047c33a63bb1be0406252976f75c`。该数据及上游代码不保存在仓库或 MoonCakes 包中。数值预期来自同一提交的 `lm/model_test.cc`，用于可复现外部对照。
- 插值绝对折扣是本项目按概率公式实现的估计器；不是 KenLM lmplz 的 modified Kneser-Ney 复刻，也没有对应的训练兼容承诺。
- 依赖官方 `moonbitlang/core` 标准库（其自身许可见 MoonBit core），没有增加第三方 MoonCakes 依赖。
- 查重文档引用的 MoonCakes/GitHub 近邻只作为范围证据，不构成依赖或代码来源。

OpenAI Codex 协助编写代码、测试、文档和工程交付。作者账号为 TerryFFF-jenius；不将 AI 协助表述为第三方软件移植。
