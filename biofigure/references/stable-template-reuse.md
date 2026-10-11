# 已审模板稳定复用

入口自动检索`atlas/reusable-template-index.json`。索引只收有来源、可调用渲染器、输入、种子、字体/包锁、视觉基线及独立复跑的案例；历史一次PASS仍保留，但不能继承稳定级别。

命中后打开源图、终图、视觉记录和渲染函数。确认单位、列名、排序、尺度及数据范围适配；复用已验函数和关系合同，按新数据调整布局并重审。

```bash
python3 <Skill根>/scripts/run_template_replay.py --case-id <案例ID> --preparation-receipt <当次回执> --output <项目>/work/<任务>/template-replay.json
```

独立R进程跑两次，在work镜像中授权；原案、原数据和已审基线不改。每次均比较PNG像素、120dpi PDF预览及几何；环境、字体或脚本变化阻断，禁止自动更新基线。

Spec的`reference_evidence.template_reuse`填写`decision: reuse`、`case_id`、`replay_receipt`和`replay_sha256`；CP2验证当次preparation ID、回执及证据哈希。精确案例命中不能跳过；方法候选不适配须填`decision: not_applicable`、`reason`和`data_contract_difference`。无命中不继承质量。

内部固定样例重放仅允许原科学/视觉Spec及完整输入/脚本内容不变；只重签执行标识。此通道不允许新数据或改画布。

新图终尺寸仍逐项审查结构、共享排序/坐标、色义、字号、图例、裁切、描边和对齐。固定样例一致只证明锁定环境下重复性，不证明任意数据、盲迁移或跨模型质量。用户验收单列。

每次修图将失败触发条件、最终参数、输入合同和检查加入对应主题包；运行回归后才更新索引。保留旧基线与变更理由；未完成复跑记待验证。新增案例不得仅凭渲染成功登记稳定。
