# 绘图证据模式

`reference_mode`贯穿请求、回执、Spec、授权和CP4。所有绘图写代码前必须检索匹配模板/参考代码、读图读码、按当前数据适配；原创不豁免。三个模式的科学、统计、字体、尺寸、配色、文字、方格及最终实际审图标准相同。

- `original`：普通新画默认。检索审阅后按当前数据和包内Pattern设计；免DOI、作者数据和私人档案，不免检索或参考代码检查。候选审阅本身不强制转模式；采用具体来源设计/方法时转`reference-guided`，不得伪填来源。
- `reference-guided`：采用已查看来源的视觉或方法设计。绑定来源图及采用、拒绝、适配依据；来源可为论文、官方包文档、教程或用户附件。教程记录官方URL和版本，不能编造DOI。采用的原代码、输入或已验renderer按其合同逐项绑定；新primary-source-lock须显式写reference_mode、primary_source.kind和adopted_roles，至少哈希figure_asset并记录原尺寸查看，采用代码/数据时绑定对应角色及数据映射；package-docs/tutorial记录URL和version，user-reference记录attachment_name。未标模式的旧锁保持原三角色要求。候选推荐本身不使缺失的私有档案成为本次必需输入。
- `reproduction`：显式`operation: reproduce`自动进入本模式；要求来源、原图、代码、输入及逐panel映射所支持的复现范围。缺失材料必须记录，并阻止相关复现/资格声明。不得改标`original`绕过来源真实性。

显式`primary_source`、`learned_method_id`、`reusable_case_id`至少需要来源模式；与`original`冲突拒绝。来源/复现沿用原primary_source、learned/reuse绑定及资格边界，不得降级。

## 写代码前的发现与审阅

所有模式先运行`prepare_figure.py`并检索审阅。原创回执`design_discovery`须包含`policy_id: reference-first-v1`、匹配`candidates`、`optional_archive_search`与`locked_template_search`。来源/复现保留原retrieval/source/template/learned证据合同，不要求这两个原创新字段。候选推荐和私人档案缺失不使档案成为原创必需输入。

原创Spec的`reference_evidence.design_precedent`必须写`policy_id: reference-first-v1`、`strategy`及六项`review`：`structure`、`code`、`data_mapping`、`typography`、`legend_and_layout`、`adaptation`。逐项写真实观察及当前数据取舍，不能只填PASS。以下前两种策略选回执中的`candidate_id`，完整绑定其图、代码、metadata、provenance的`files`（路径、角色、SHA-256）。

- `reviewed-reference`：打开原尺寸参考图、读对应代码；`inspection.figure_opened`与`inspection.code_read`须记录真实查看与读码观察。按当前数据独立适配；审阅不等于原图复现。
- `packaged-replay`：公共runner仅可用此策略；绑定并运行包内实际renderer哈希，不自称看过图。不允许据此给任意新脚本放行，代码改变须重新审阅及授权。
- `pattern-fallback`：检索后无可用候选时，保留`selected_pattern`，不选`candidate_id`。`rejected_candidates`须覆盖PUBLIC `candidates`、`optional_archive_search`和`locked_template_search`的全部候选，逐项写`candidate_id`及拒绝`reason`；零命中如实记录。`fallback_reason`解释新设计与参考/代码缺口，阅读适用包内Pattern与代码；不得因不想审阅而fallback，不得绕过明确来源/复现。

原创保留真实`preparation_id`、完整`preparation_request`、`selected_method_case_id`和`retrieval_query`，不伪填atlas/primary_source。`reference_analysis`完整拆解面板、元素、映射、拓扑及专用包职责；`design_target`六维写观察、实现和差异理由。

CP2所有模式验证完整Spec和真实回执；原创验证`design_discovery`、`design_precedent`，不要求旧`reference_method_receipt`；来源/复现继续原证据字段与绑定。预检就绪不授权写代码；CP2通过才可编码，授权时重验候选与实际文件哈希。

## 最终审美与兼容

CP4执行完整publication及领域审查。原创用`design-quality`，来源用`reference-quality`；均保留hierarchy、geometry、palette、typography、marks、annotation六维当前终尺寸观察。实际打开PNG及所需PDF，自动检查、回放和哈希不代替human/model审图。`quick-png`仅PNG；`paper-pdf`须PDF及PNG预览。

历史来源规则和缺失档案状态不变；不自动升级资格，模式或绑定不一致拒绝。来源学习、运行、视觉复现、迁移、用户验收分别记录。

## 测试范围

`run_public_tests.py --profile public`执行公开测试；私人档案项按`tests/archival-tests.json`记`NOT_RUN`，不计PASS。`archive`或`all`另跑来源重放；公开测试通过不等于原图复现或用户验收。
