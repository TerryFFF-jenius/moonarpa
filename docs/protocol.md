# JSON 任务协议 v1

`execute(text, limits=...)` 返回 Json 或抛出 ArpaError；`handle` 返回稳定 JSON 信封。`cmd/moonarpa` 只接收一个 JSON argv 参数，`scripts/run_request.py` 从 UTF-8 文件读取、调用它并检查信封。命令宿主不打开模型路径、不访问网络或执行请求中的代码。JSON 最多嵌套 16 层，未知字段报错。

| op | 必需字段 | 可选字段 |
| --- | --- | --- |
| train | sentences, order | method (`discount`/`mle`), discount, unigram_prior |
| inspect | arpa | 无 |
| canonicalize | arpa | 无 |
| score | arpa, tokens | options |
| corpus | arpa, sentences | options |
| predict | arpa, history, k | 无 |
| rescore | arpa, hypotheses | lm_weight, acoustic_weight, length_weight, options |
| audit | arpa, history | tolerance |

`arpa` 是完整文本字符串；`sentences` 是 token 数组的数组；`tokens`/`history` 是字符串数组。`options` 对象仅接受 `bos`、`eos` 布尔值和 `oov` 字符串 `map` 或 `reject`。整数应非负且为 Int32 范围，order 还必须在 1..8。所有实数选项须有限。

## 从训练到评估

```json
{"op":"train","order":3,"sentences":[["hello","moon"],["hello","world"]]}
```

成功结果包含 `arpa` 和 `summary`；把返回的 arpa 原样用于下一个请求：

```json
{"op":"score","arpa":"完整的 ARPA 文本","tokens":["hello","world"],"options":{"bos":true,"eos":true,"oov":"map"}}
```

上例的“完整的 ARPA 文本”是字段说明，实际应用必须替换为 train 返回值。`scripts/verify_oracle.py` 展示可执行的多次调用。`fixtures/train-request.json` 可直接运行。

## n-best 重排

```json
{"op":"rescore","arpa":"完整的 ARPA 文本","lm_weight":1.0,"hypotheses":[{"id":"one","tokens":["hello","moon"],"acoustic_score":-0.4},{"id":"two","tokens":["hello","world"],"acoustic_score":-0.5}]}
```

ID 非空且唯一；并列按输入顺序。`input_index` 帮助调用者映射回原结果。声学得分单位由调用者负责，协议不假设自然对数或自动换算。

有限值用 JSON number，不可能 log 概率为字符串 `"-Infinity"`，无限困惑度为 `"Infinity"`；零事件指标为 `null`。消费者必须处理这三种表示，不应将字符串当作零。错误信封只有 `ok=false` 与错误说明，没有部分成功结果。CLI 正常返回错误信封时仍可能退出 0，Python 适配器检查 `ok`。
