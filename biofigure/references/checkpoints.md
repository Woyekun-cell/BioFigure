# 检查点协议

每次任务建立 checkpoint ledger，顺序读取 `checkpoints/checkpoints.yaml`。检查点不是口头清单：PASS 必须附所需 evidence；前门未 PASS，后门只能 `NOT_RUN`。

- CP0 科学意图：仅当关键科学语义冲突、缺失或涉及不可逆解释选择时，问一个简短问题并 `STOP`。可逆排版、配色与设备选择由 Skill 处理。
- CP1 科学契约：核对样本映射、实验单位、尺度/变换、统计与坐标。不能证实时停止渲染，不补造。
- CP2 设计锁定：所有绘图先检索匹配模板/参考代码、读图读码并适配，原创不豁免；未过不得写绘图代码。核Pattern、Spec、Renderer及槽位，真实回执的`preparation_id`、任务/领域/后端、`selected_method_case_id`。原创额外核`design_discovery`的`reference-first-v1`、PUBLIC候选、`optional_archive_search`、`locked_template_search`，及`reference_evidence.design_precedent`的policy_id、策略和structure、code、data_mapping、typography、legend_and_layout、adaptation六项review。按[模式合同](reference-modes.md)：reviewed-reference/packaged-replay选候选ID并绑定完整files；前者须真实figure_opened/code_read，后者锁实际renderer、不放行任意新脚本；fallback保留selected_pattern，逐一拒绝三层全部候选并写fallback_reason。原创免DOI/私人档案及旧`reference_method_receipt`；来源/复现保留原retrieval/primary_source/template/learned及对应回执，不加原创新字段、不得降级。新primary-source-lock仍须来源哈希与逐panel映射，不升级资格。公共runner只用packaged-replay，不宣称看图。
- CP3 成图检查：实际打开当前PNG及所需PDF，按最终尺寸核验；记录精确SHA-256、查看方式和目标尺寸。小字、文字错位、标签/图例重叠、面板错位、裁切、缺字、字体替代或非白底均`REVISE`，对象级修复后重画。
- CP4 交付：Critic、QA、格式与哈希均通过才 PASS；`final_size_checks`须在最终尺寸记录字体大小、文字位置、标签/图例重叠、裁切、面板对齐、图文比例与`footer_absent`。最后一项须实际看完画布最底边：正常轴和图例允许，caption/脚注及样本设计、方法、筛选说明段禁止；缺观察即不通过。大画布小字、缺项或任一FAIL均不得视觉PASS；模拟状态在图外声明。

运行：`python3 scripts/validate_checkpoints.py checkpoint-ledger.yaml`；依赖 Python 3 与 PyYAML。验证器检查顺序、非空证据、字体回退、成图及交付物哈希；它不替代当前任务实际看图。

critic_reviews逐项记录status与具体evidence；未审查为NOT_ASSESSED。输入文件哈希只验证身份，不证明科学结论或真实视觉查看。

交付新增绑定见`enforced-execution.md`：CP2必须提供Spec文件供实际重验；CP3绑定渲染凭据；CP4重跑完整Critic。缺凭据、改脚本/Spec/PNG、缺专项观察均不得PASS。每张PNG独立ledger；合法REVISE日志不代表可交付。
