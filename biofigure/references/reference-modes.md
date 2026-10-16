# 绘图证据模式

`reference_mode`贯穿请求、preparation回执、Design Spec、一次性授权和CP4。普通新画默认`original`；三个模式的科学、统计、字体、尺寸、配色、文字、方格和最终实际审图标准相同。

- `original`：按当前数据和科学问题原创设计。选择包内Pattern，完成完整设计拆解；不要求原图、论文DOI、作者数据、作者代码或私有图库。可检索参考，但实际采用来源须改为`reference-guided`，不得在原创合同中伪填来源身份。
- `reference-guided`：采用已查看来源的视觉或方法设计。绑定来源图及采用、拒绝、适配依据；来源可为论文、官方包文档、教程或用户附件。教程记录官方URL和版本，不能编造DOI。采用的原代码、输入或已验renderer按其合同逐项绑定；新primary-source-lock须显式写reference_mode、primary_source.kind和adopted_roles，至少哈希figure_asset并记录原尺寸查看，采用代码/数据时绑定对应角色及数据映射；package-docs/tutorial记录URL和version，user-reference记录attachment_name。未标模式的旧锁保持原三角色要求。候选推荐本身不使缺失的私有档案成为本次必需输入。
- `reproduction`：显式`operation: reproduce`自动进入本模式；要求来源、原图、代码、输入及逐panel映射所支持的复现范围。缺失材料必须记录，并阻止相关复现/资格声明。不得改标`original`绕过来源真实性。

显式指定`primary_source`、`learned_method_id`、`reusable_case_id`至少需要来源模式；与显式`original`冲突直接拒绝。已验适配器的renderer哈希、原数据复跑、新输入验证和资格边界继续适用。来源学习、运行、视觉复现、迁移与用户验收保持独立状态。

## 原创请求与Spec

```yaml
reference_mode: original
operation: draw
figure_task: group-distribution
figure_family: distribution
pattern_id: DIST-BOX-001
data_shape: sample_id, group, value; 24 independent samples, 12 per group
primary_domain: imaging-assay
primary_role: comparison
backend: R
deliverable: quick-png
statistics_required: false
```

`pattern_id`必须是包内存在且适合当前数据/任务的Pattern；无唯一图型时先返回`READY_FOR_CHART_SELECTION`，不猜图。`PREFLIGHT_COMPLETE`只表示规划材料就绪，不能表示科学、成图或视觉PASS。

Spec显式写`reference_mode: original`。`reference_evidence`保留真实回执的`preparation_id`、完整`preparation_request`、`selected_method_case_id`（`PATTERN-<Pattern ID>`）与`retrieval_query: {domain, task, pattern}`。不要填`selected_atlas_ids`、`primary_source_lock`或虚构的`source-and-visual-reviewed`。

`reference_analysis`在原创模式表示当前设计分析，仍完整包含`figure_family`、`semantic_purpose`、`panels`、`elements`、`relationships`、`spatial_topology`、`required_structures`和`forbidden_substitutions`。`design_target`的六维仍逐项填写`observation`、`implementation`和`difference_reason`；观察来自当前数据和设计需求，不填写`reference`或`reference_opened`。

CP2原创不要求`reference_method_receipt`，仍须验证完整Spec及真实preparation回执。原创code gate为`BLOCKED_UNTIL_DESIGN_ANALYSIS_AND_CP2`，来源模式保留`BLOCKED_UNTIL_REFERENCE_ANALYSIS_AND_CP2`。授权CLI参数不变，消费时重新核验模式与绑定文件。`deliverable: paper-pdf`同时要求最终PDF和PNG预览（`[pdf, png]`），全部最终尺寸和实际审图门保留；需要SVG时使用原有paper-composite。

## 最终审美与兼容

CP4始终执行完整publication审查及领域专项。原创使用`critic_reviews.design-quality`；来源模式使用`critic_reviews.reference-quality`。两者均要求`hierarchy`、`geometry`、`palette`、`typography`、`marks`、`annotation`六维，每维有PASS/REVISE/FAIL和具体终尺寸视觉证据；缺一不可。任何自动检查不得代替打开当前PNG/PDF及human/model判断。

未记录模式的历史Spec/回执保留原来源模式规则；不重写历史结果、不自动升级资格。新回执必须规范化并绑定模式，Spec或授权模式不一致拒绝。档案缺失保持`NOT_VERIFIED`或当前缺失状态；原创新图的成功不改变档案记录。

## 测试范围

`python3 scripts/run_public_tests.py --profile public --report <work>/public-tests.json`执行公开发行适用测试，包括科学、统计、字体、文字、热图、授权、模式、真实审图凭据及公开案例。`tests/archival-tests.json`逐项列出需要私有原图/作者档案或历史固定产物的测试、原因和输入路径；默认明确记`NOT_RUN`，不计PASS。`--profile archive`执行这些来源重放，`--profile all`执行未经筛除的全套测试。公开测试通过不等于原图复现、全部档案资格或用户验收。
