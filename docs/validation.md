# 可复现验证与提交审计

`python scripts/check_project.py` 统计根目录非测试 .mbt 的物理行，并进一步排除空行、注释、纯括号和 derive 方法转发，保守检查不少于 1500 行。示例、CLI 薄适配、测试、生成接口和 Python 不计入。这个筛选是行数审计，不能自动证明每一行的设计价值。

每个非 merge 提交需至少十行非生成文件变化才计入保守提交数；初始基础代码亦计入。人工审阅实现切片包括：词法预算、拥有型模型、严格 parser、canonical writer、conditional scoring、sentence、corpus、stream、predict、rescore、mixture、counts、MLE、discount、audit、vocabulary、shard merge、JSON codec、task protocol、溢出修复、真实工作流/oracle、外部参考验证、完整文档与 CI。没有空提交、重复切分同一功能或为了数量而 revert/reapply。

本地与 CI 工具链固定为 moonc `0.10.22+124d61d05`、Moon CLI `0.1.20261119`、moonrun `0.1.20261119`。`python scripts/check_project.py` 同时核对本页及 README 的编译器版本与 CI 安装固定值，防止验证说明滞后。wasm-gc/wasm/js 的严格 check/test/build 可本地执行；当前 Windows 无 MSVC，因此只完成 native check，本地未宣称 native test/build 成功。Linux 四目标 CI 是该平台的实际证据，应查看公开运行状态，不以本文件替代。

核心 MoonBit 测试包含 30 个命名用例，其中生成变体覆盖八种阶数及 0..10 个输入词。独立 oracle 检查 25 个训练模型、1225 次预测事件；KenLM 参考检查 10 个公开预期值、22 次独立逐词核对，固定上游提交及摘要。Python 标准库足够运行，无数值库或上游引擎依赖。测试属于已列路径的证据，不等同于形式证明或所有 ARPA 方言兼容。

三个真实下游程序分别执行候选重排、固定词表留出评估、分片训练恢复与分叉评分，带有结果断言。README 快速开始使用相同公共 API。JSON fixture 与 CLI 适配器也参与 oracle 调用，外部消费者还应在空缓存环境安装精确版本运行。
