# Benchmark 与跨模型速览

所有绘图写代码前先跑`prepare_figure.py`，强制检索匹配模板与参考代码、读图读码并按当前数据适配；`original`不豁免。原创回执`design_discovery`记录`policy_id: reference-first-v1`、PUBLIC `candidates`、`optional_archive_search`及`locked_template_search`，与Spec的`reference_evidence.design_precedent`及CP2绑定。

原创按[模式合同](reference-modes.md)填六项review；reviewed-reference/packaged-replay选候选ID并绑定文件路径/角色/哈希；pattern-fallback保留selected_pattern，逐一拒绝三层全部候选并写fallback_reason。原创免DOI/私人档案，缺档案不死锁；来源/复现执行原retrieval/source/template/learned证据合同，不要求原创新字段、不得降级。公共runner仅packaged-replay，只放行实际renderer哈希，不为任意新脚本背书，不宣称看过图。

跨模型目标是统一输入合同、候选方法和验收尺度，不是承诺模型原生能力相同。相同回执应得到相同候选/包合同；真实成图差异须在固定留出任务上，以盲审首版通过率、结构评分、文字/重叠硬失败和返工次数衡量。没有跑过的模型/档位一律标“未验证”。

区分来源复现、独立迁移、压力测试；来源读取后的新代码只能记source-exposed。检索、回放、哈希或自动几何检查不代表高保真或审美PASS；全程保留当前PNG及所需PDF的终尺寸human/model审查。方法与批量对账见[判定](benchmark-case-method.md)、[审阅](benchmark-review-operations.md)，配对测试见[一致性方案](benchmark-cross-model.md)。
