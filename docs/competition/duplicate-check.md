# 需求、选题与语义查重

检查日期：2026-11-11。实际执行已安装 osc2026-guide 的 Project Research Guide：moon search --limit 100、MoonCakes docs/精确元数据、近邻源码与测试、GitHub 仓库检索、官方 awesome-moonbit 清单和永久注册表。不是主办方裁决，不保证覆盖未索引/私有/刚发布项目。

## 三个领域候选及落地依据

| 候选 | 用户输入、处理、输出；成熟依据 | 最小完整核心与验收 | 结论 |
| --- | --- | --- | --- |
| LDIF 目录交换 | 目录管理员/身份同步系统/迁移工具导入条目与变更；RFC2849 | 解析值、变更事务、写回；标准与畸形输入 | WeiR-h/moonldif@0.7.5 直接替代，淘汰 |
| SAC 地震信号 | 观测数据管线/分析工具/教学模拟读取波形；SAC、ObsPy | 二进制样本、校准、处理；参考比对 | wch6766/moonbit-seismic@0.1.1 直接替代，淘汰 |
| ARPA 语言模型 | 语音/OCR 系统输入候选句后重排；语料工具输入分词文本后输出似然/困惑度；离线应用输入小语料后训练、导出、查询。KenLM/SRILM 已有此工作流 | 完整 ARPA 解析/写回、回退概率、状态评分、困惑度、重排、计数训练；手算概率、独立解释器和 KenLM 参考向量 | 已检查范围内未确认成熟直接替代，选择 |

评分顺序为广度/三类用户/复用/重合安全/深度/验证/可行性/维护，各1–5：LDIF 4/4/5/1/4/5/4/4；SAC 4/4/4/1/5/5/4/4；ARPA 5/5/5/4/5/5/4/4。硬性重复直接淘汰，分数不抵消。

需求证据来自成熟工具和标准，不声称参赛者已有这些经验、用户访谈或生产部署。ARPA 的核心是条件概率而不是分词、搜索索引、语言识别、通用加权状态机或远程大模型接口；独立可移植概率引擎可被这些系统复用，无须将其耦合进一个搜索或神经模型项目。

## 实际检索

名称/同义词/API：arpa、ARPA parser、ngram、trigram、bigram、kenlm、srilm、Kneser、Witten Bell、backoff、perplexity、statistical language、language modeling、ngram probability、sentence scoring、score_sentence、log10_prob、Markov text、语言模型、语音识别；拒绝候选检索 ldif、ldap、directory interchange、distinguished name、sac、seismic、obspy、sta/lta。所有 moon search 上限100；language model 命中100，结果饱和，不能视为穷尽。精确词零命中不构成唯一性证明。

GitHub search/repositories：arpa language:MoonBit、kenlm language:MoonBit、ldif language:MoonBit、seismic language:MoonBit、ngram language:MoonBit，per_page100；分别0、0、1、1、0，incomplete_results=false。比赛仓库范围随这些检索和官方清单覆盖，不能证明所有比赛项目均可见。MoonCakes 详情路径 https://mooncakes.io/docs/<namespace>/<module>，并用 moon view 模块@版本 --json 核对版本/仓库/许可证。原始输出保存在仓库外本地研究档案。

## 近邻能力矩阵

| 项目/版本/实际证据 | 核心输入、行为和输出 | 分类/处置 |
| --- | --- | --- |
| [WeiR-h/moonldif@0.7.5](https://mooncakes.io/docs/WeiR-h/moonldif)、[源码](https://github.com/WeiR-h/moonldif)，SHA 595dea397558137310ce8538f58a5deb08e281bb；src/parser.mbt、parser_wbtest.mbt | 条目值、add/modify/moddn/delete；字节保留 LDIF、结构诊断 | 直接替代被拒候选 |
| [wch6766/moonbit-seismic@0.1.1](https://github.com/wch6766/moonbit-seismic)，SHA 17f93abbe5565118accc593b9f720a48b3a27c36；sac.mbt、seismic_test.mbt | SAC 二进制波形、滤波、时序信号 | 直接替代被拒候选 |
| [Juwan-Hwang/moon-certified@0.1.1](https://github.com/Juwan-Hwang/moon-certified)，SHA 94dd850ce24db5610e720035d5bdb1ecb2923e43；nlp/text_processing/text_processing.mbt 含内嵌测试 | token/char ngrams、TFIDF、cosine；不是条件 backoff 概率模型 | 同方向不同功能 |
| [Lucius646/MoonSearch@0.9.0](https://github.com/Lucius646/MoonSearch)，SHA 536ad0428edf3fbcddf6d846373e0e6f770f89cd；analysis/tokenizers.mbt、m12_wbtest.mbt | 分词、图过滤、索引、搜索 | 可为下游，核心任务不同 |
| [soehi/moonlm@0.3.0](https://github.com/soehi/moonlm)，SHA c14b6db1b8ab535e29a577e9f85f404bffeefe18；README、src/model/forward_test.mbt | GGUF 神经权重、张量前向计算、代理 | 同领域不同模型 |
| [cn-nnzy/mbglot@0.2.0](https://github.com/cn-nnzy/mbglot) README、公开接口 | franc-min 字符 trigram 排名轮廓，输出语言标签 | 高度相邻统计词汇，任务不同；无词级 ARPA 回退或句子条件似然 |
| [xlyyyyyy112/moonbit-mirostat@0.1.2](https://github.com/xlyyyyyy112/moonbit-mirostat)，SHA 165944e3ab5ce625fa4f46a62ebacf76d034b637；README、distribution_wbtest.mbt | 从调用方提供的分布采样、控制惊异度 | 下游采样与模型求概率不同；不重复 Mirostat |
| 永久登记 MoonWFST / MoonSeqMine / MoonRQA | 半环图组合/最短路；有序项集频繁模式；相空间复现矩阵 | 核心模型与闭环不同；不实现这些通用算法 |

已读完整相关登记指纹并搜索所有 reserved/completed/rejected/external-checked 能力。MoonBench、MoonContract、MoonRecur、MoonShard 及其扩展边界保留。通过公共目录结构、实现及测试反向核对 backoff、ARPA、score_sentence、perplexity 的核心任务。原始 raw.githubusercontent.com 获取不稳定，改用 GitHub API 读取相同源码；不把获取失败算成无重复。

## 决策与边界

2026-11-11 在登记表同目录 project-registry.md.lock 持有排他锁，重新读取后以临时文件原子替换登记 MoonARPA 并保留全部已有记录。新项目是原创实现；KenLM 用作参考行为及运行时读取的测试数据，不拷贝引擎。实现前完成门禁，发布前重查核心术语和近邻版本。结论仅限已记录公开范围，不声称全生态唯一。

## 发布前复查（2026-11-11）

再次执行 moon search limit100：arpa=0、kenlm=0、backoff=28、perplexity=3、ngram=8、score_sentence=4；GitHub arpa language:MoonBit per_page100 为0且 incomplete=false。逐条检查返回的接口简介，ngram 新近邻为布局图 NetworkSimplex、地理索引、record linkage 与 MinHash 分词；perplexity 还含 Perplexity 云厂商 SDK 与 t-SNE 参数，并非词级 ARPA 模型。score_sentence 还含文本指标、词嵌入检索和 npm 绑定。未把同名词命中直接视为重复。

补读 cn-nnzy/mbglot HEAD 的 detect.mbt 与 detect_test.mbt：文本经过脚本/语言检测得到语言标签与置信度，测试含英语、西语、俄语、中文等识别，与词级条件似然不同。此补查是当前 HEAD，不冒充精确 0.2.0 内容。中文检索早期输出编码有局限；结论主要依赖可核对的英文任务/API、多近邻实际代码与测试。

最终交付用三个带断言工作流兑现初始场景；训练/评分经过独立线性概率 oracle，ARPA 经固定 KenLM 测试输入与公开参考值对照。没有复制 KenLM 引擎或再发布其测试 fixture。有限公开范围内仍未确认成熟直接替代；广义 language model 查询曾饱和，不能证明全生态唯一。
