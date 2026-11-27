# MoonARPA

MoonARPA 是纯 MoonBit 的词级 n-gram 语言模型库，提供 ARPA 模型读写、条件回退概率、句子与语料评分、候选重排和小语料训练。模块为 `TerryFFF-jenius/moonarpa@0.1.4`，不依赖网络服务和外部模型运行时。

## 适用任务

- 语音/OCR 工程：输入已经分词的候选句及声学分数，用语言模型重新排序，保留稳定的候选 ID。
- 语料工程：固定训练词表，将留出集映射后计算逐词似然、OOV、交叉熵和语料困惑度。
- 离线应用：合并语料分片计数，训练小型模型，导出 ARPA 后恢复，并查询下一个词或维护流式评分状态。

这些工作流可通过库 API 或 JSON 任务协议接入多个项目。它不提供分词器、神经推理、通用 WFST、搜索索引、KenLM 二进制文件兼容或大规模并行训练。

## 环境与安装

CI 固定并逐项核验以下工具链：Moon CLI `0.1.20261119`、编译器 moonc `0.10.22+124d61d05`、moonrun `0.1.20261119`。支持 `wasm-gc`、`wasm`、`js`、`native`；native 需要平台 C 编译工具，Windows 需要 MSVC C++ 工具与 Windows SDK。无第三方模块依赖，使用官方 core。MoonCakes 页面提供发布包与构建状态，但服务端构建器的工具链由平台管理，模块自身不能固定该服务端版本；平台公开元数据未显示其实际工具链版本。

在已有 MoonBit 工程内执行：

```sh
moon add TerryFFF-jenius/moonarpa@0.1.4
```

在使用者的 `moon.pkg` 中导入：

```moonbit
import { "TerryFFF-jenius/moonarpa" @arpa }
```

## 快速开始

以下代码可放入已有工程的可执行包；包设置 `pkgtype(kind: "executable")`。

```moonbit
fn main raise {
  let model = @arpa.count_corpus([
    ["open", "the", "door"],
    ["open", "the", "door"],
    ["close", "the", "window"],
  ], 3).train_discount()
  let score = model.sentence(["open", "the", "door"])
  println(score.to_json().stringify())
  let text = model.to_arpa()
  let restored = @arpa.parse(text)
  assert_eq(restored.sentence(["open", "the", "door"]), score)
}
```

默认插入一个 BOS 历史和一个计分 EOS。因此上面的三个词产生四个预测事件。手工输入 `<s>`、`</s>` 会报错，边界通过 `ScoreOptions` 控制。可执行示例见 [训练与恢复](examples/train/main.mbt)、[语音重排](examples/speech/main.mbt)、[留出集评估](examples/corpus/main.mbt)。

## API 与数值约定

| 接口 | 用途 |
| --- | --- |
| `parse` / `Model::new` / `to_arpa` | 严格解析、构造验证、确定性导出 |
| `conditional(history, token)` | 返回最长匹配阶数、回退次数、回退权重和 OOV 映射 |
| `sentence` / `score_text` / `corpus` / `score_lines` | 逐词评分与按预测事件加权的语料指标 |
| `scorer` / `feed_batch` / `fork` / `finish` | 独立增量状态、失败批次原子回滚、幂等结束 |
| `predict` / `rank_candidates` / `rescore` | 全词表前 k 项、候选集合排序、句子 n-best 重排 |
| `Mixture::new` | 同词表模型的概率混合，内部稳定 log-sum-exp |
| `count_corpus` / `Counts::merge` | 有界计数与分片合并 |
| `train_mle` / `train_discount` | MLE 与插值绝对折扣 ARPA 训练 |
| `fit_vocabulary` / `transform` | 训练集拟合固定词表与留出集 `<unk>` 映射 |
| `audit_mass` / `audit_contexts` / `summary` | 概率质量及模型结构诊断 |
| `execute` / `handle` | 可移植 JSON 任务引擎与成功/错误信封 |

- 全部概率及回退权重使用 **log10**。负无穷表示不可能事件；正回退权重合法。模型的显式概率必须非正。合法 ARPA 不一定归一化，可通过 `audit_mass` 检查。
- 缺失高阶 n-gram 时加入对应历史的回退权重，再移除最早的历史词；缺失权重按零处理。`conditional` 只使用最近 `order-1` 个历史词，但输入总量仍受预算约束。
- OOV 默认映射到 `<unk>`；模型缺失该 unigram 或指定 `Reject` 时返回错误。已经映射成字面 `<unk>` 的输入不再计为新 OOV，`MappedCorpus.replaced` 记录预处理替换数。
- 困惑度是 `10^(-sum_log10 / predicted)`；EOS 默认计入分母，BOS 不计入。没有预测事件返回 `None`；不可能事件得到无限困惑度。JSON 使用字符串 `"Infinity"`、`"-Infinity"`，无事件指标使用 `null`。
- `rescore` 计算 `lm_weight*LM + acoustic_weight*acoustic + length_weight*词数`，并列按输入顺序；声学分数须由调用者换算到相容单位。零 LM 权重会跳过不可能似然项，避免 `0 * -inf`。
- `words` 只按 Unicode 空白分割，不执行语言学分词、大小写或 Unicode 规范化。token 不能为空或包含空白、ASCII 控制字符、DEL。
- 模型和词表拥有内部数据，公开数组返回副本。评分报告是调用方拥有的结果。混合模型的 `matched_order=0` 表示跨组件结果，不宣称单一匹配阶数。

## 运行工作流与 JSON 命令

在本仓库根目录执行：

```sh
moon run examples/speech
moon run examples/corpus
moon run examples/train
python scripts/run_request.py fixtures/train-request.json --target wasm-gc
```

命令行包接收一个 JSON 参数并输出 `{"ok":true,"result":...}` 或 `{"ok":false,"error":...}`。Python 文件适配器检查信封后输出结果或以异常退出。大请求应直接调用库里的 `execute`，因为操作系统的 argv 上限可能小于模型预算。完整请求字段和例子见 [JSON 协议](docs/protocol.md)。

## 资源限制与错误

`Limits` 默认限制：最高八阶、20 万记录、1,600 万字符串单位、100 万输入 token、200 万工作事件。可以传入更低预算。受整数安全上限约束，最大值依次为 8 / 100 万 / 2.56 亿 / 1,000 万 / 1 亿。`max_text` 使用 MoonBit 的 `String.length()` 单位，不承诺 UTF-8 字节数或精确进程内存上限。

声明记录数、输入长度、统计工作、候选扫描和语料累积都受到检查；排序仍有 `O(R log R)` 成本。计数训练在内存进行，没有磁盘外排序。`ArpaError` 分为 `Invalid`、`Budget`、`Missing`。ARPA 严格要求连续阶数声明、升序 section、精确计数、结束标记；支持空行、行首 `#` 注释、CRLF 与 `-inf`，不支持行尾注释及无词表符号的高阶记录。

## 检查与复现

```sh
moon info
moon fmt --check
moon check --deny-warn --target wasm-gc
moon test --deny-warn --target wasm-gc
moon build --deny-warn --target wasm-gc
python scripts/check_project.py
python scripts/verify_oracle.py --target wasm-gc
python scripts/verify_reference.py --target wasm-gc
```

将 target 换成 `wasm`、`js`、`native` 可复现其他后端。CI 对四目标执行严格检查/测试/构建、三个工作流和独立 Python oracle。参考测试按固定 SHA 从 KenLM 官方仓库读取测试数据并校验 SHA256，需要网络；也可用 `--fixture PATH` 指向同摘要的已下载数据。没有执行 KenLM 二进制，不能视为全量 KenLM 兼容认证。

独立 oracle 以线性概率和独立 `Counter` 计数核对 25 组训练场景、1,225 个预测事件；KenLM 检查 10 个公开数值与 22 个预测事件。MoonBit 测试覆盖八种模型阶数、空语料、OOV、多层回退、正回退、概率质量、输入预算、溢出和规范化往返。详细设计见 [设计](docs/design.md)、[限制与安全](SECURITY.md)、[查重证据](docs/competition/duplicate-check.md)、[版本记录](CHANGELOG.md)。这些是软件验证证据，不代表赛事官方验收或实际生产性能。

## 许可与 AI 使用

原创 MoonBit 与辅助脚本采用 [MIT](LICENSE)，作者 `TerryFFF-jenius`。本项目参考 ARPA/KenLM 的格式和评分行为，未复制其引擎代码；KenLM 测试数据仅在验证时从上游读取，未包含在发布包。上游许可及边界见 [THIRD_PARTY.md](THIRD_PARTY.md)。

实现、测试、文档和交付由 OpenAI Codex 协助完成。AI 输出经过编译、测试、独立数值核验与接口审查；未声称用户已有生产部署或性能基准。包不包含任何私有参赛文书或联系方式。
