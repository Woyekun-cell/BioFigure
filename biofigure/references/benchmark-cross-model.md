# 跨模型一致性验证

`protocol.yaml` 当前仅是协议模板，状态为 `PROTOCOL_VALID`、`EXECUTION_BLOCKED`。source-exposed材料只有文字占位，没有真实源图/作者代码，因此四类案例不得用于模型质量评分；transfer/exposed按同任务、输入哈希、画布、DPI与种子成对，唯一预期差异为可见材料。执行前还须冻结模型/版本/推理档、提示词、Skill提交、包锁、权限、工具和CPU/时限。每个模型×案例×重复须有完整结果、两名一致匿名评审的六维1–5分、判断与缺陷坐标。验证器按协议计算中位数、首版率、硬缺陷率、线性加权κ、匹配模型差异与正态近似95%CI；无完整矩阵返回 `INCOMPLETE`，源材料或条件未就绪返回 `BLOCKED`。哈希/账本是流程一致性核对，不是抗主动伪造的安全机制。smoke仅验证本地preflight，不调用模型、不出图。工具不等价时分层报告，不合并估计。

每轮分配盲标签，提交结果时移除模型身份。至少两名评审盲审首版和终版，记录六维1–5分、科学硬错、完成率、首版通过、重叠/裁切/缺字、返工及耗时。机器几何检查与科学/视觉判断分栏，用户认可单独记录。

每个 run 必须有唯一 `run_id`，并由哈希锁定的 run manifest 将其绑定到 `(blind_id, case_id, repeat)`、输入哈希和该行所有证据文件。CP4 inspection与每份review文件都须包含同一 `run_id/blind_id/case_id/repeat/input_sha256/artifact_sha256`；审查记录数量须与独立review文件数相等，reviewer ID唯一，每条记录按ID、run key、路径、哈希及完整内容一对一比对，重复ID或矛盾记录阻断。不同run不得复用renderer source、Design Spec、preparation receipt、PNG、render receipt、checkpoint ledger、inspection或review文件路径；preparation receipt即使内容确定，也须各run独立落盘，允许内容哈希相同。PNG内容哈希可相同，但文件路径及render receipt必须独立。review判断为PASS时，不得同时记录硬缺陷、科学硬错或缺失交付；`revision_count`必须是非布尔、非负整数。`first_pass: true`表示首版即通过，因此不得伴随CP4 revision；终版判断为PASS但`first_pass: false`时，必须有至少1条CP4 revision记录。REVISE/FAIL可在无修订时记录。`reviews`只接受独立评审文件引用 `{path, sha256}`；文件记录 reviewer ID/type、判断、六维分数、科学硬错列表、首版通过判断、缺失交付列表和含严重度的缺陷坐标。validator用CP4坐标检查器核验review坐标，并从文件派生科学硬错、缺失交付、首版率、硬缺陷率、评分、加权κ与配对统计；行内填写的聚合值会被拒绝。任何非PASS运行均不能进入完整质量指标，报告不得输出质量PASS。`tests/test_cross_model_benchmark.py` 的48行满分夹具只测试技术计算，CP3/CP4文件检查由隔离mock跳过，不是真实运行或模型结果。

最小结构示例（路径须换成真实文件）：

```json
{"reviews":[{"path":"reviews/reviewer-01.json","sha256":"<file-sha256>"}],
 "inspection_evidence":{"path":"inspection.json","sha256":"<file-sha256>"}}
```

评审文件本体使用 `schema_version: 1`、`reviewer_id`、`reviewer_type`、`judgment`、`artifact_sha256`、`first_pass`、`scores`、`scientific_hard_errors`、`missing_deliverables`、`defect_coordinates`。每个缺陷坐标须有 `issue`、`severity`（`hard`/`minor`）、有限 `x/y` 和 `unit: normalized`；x/y必须位于0–1。CP4的 `review_records` 项以 `review_file` 路径/哈希和 `review`完整本体配对。命令：`python3 scripts/run_cross_model_benchmark.py --validate-report report.json`。报告基于 JSON 同目录解析相对路径。协议烟测：`python3 scripts/run_cross_model_benchmark.py --validate-protocol`。烟测只检查协议与合成输入，不是模型作图试验。未具备真实文件、CP3/CP4 PASS、评分与双盲评审时，报告状态必须为 INCOMPLETE/BLOCKED，不构成质量结论。

预注册阈值：门禁/回执一致率100%，科学硬错0，缺失交付0，首版通过率≥80%，六维中位数均≥4，硬视觉缺陷≤5%，配对均值差绝对值≤0.35/5且95%CI落在±0.5，评审加权κ≥0.70。不得事后调整。未运行的模型、版本、档位明确标为未测；规则相同不代表图质相同。

本协议含4个合成家族（分布、矩阵、组成、拓扑）及各自两种暴露模式，作为执行框架烟测；它们不构成外部来源复现。真实模型运行和双评审盲审仍待执行。
