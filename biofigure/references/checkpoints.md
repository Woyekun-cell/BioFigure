# 检查点协议

每次任务建立 checkpoint ledger，顺序读取 `checkpoints/checkpoints.yaml`。检查点不是口头清单：PASS 必须附所需 evidence；前门未 PASS，后门只能 `NOT_RUN`。

- CP0 科学意图：仅当关键科学语义冲突、缺失或涉及不可逆解释选择时，问一个简短问题并 `STOP`。可逆排版、配色与设备选择由 Skill 处理。
- CP1 科学契约：核对样本映射、实验单位、尺度/变换、统计与坐标。不能证实时停止渲染，不补造。
- CP2 设计锁定：Pattern、Design Spec、Renderer、data/annotation/legend/label 槽位全部有效后才写绘图代码。
- CP3 成图检查：生成 PNG 后实际打开；记录精确 SHA-256、查看方式和目标尺寸。重叠、裁切、缺字、字体替代、图例侵入或非白底均 `REVISE`，对象级修复后重画。
- CP4 交付：Critic逐项有实际证据、QA、格式与哈希均通过才 PASS；模拟状态必须声明。失败时只交诊断，禁止声称发表级完成。

运行：`python3 scripts/validate_checkpoints.py checkpoint-ledger.yaml`；依赖 Python 3 与 PyYAML。验证器检查顺序、非空证据、字体回退、成图及交付物哈希；它不替代当前任务实际看图。

critic_reviews逐项记录status与具体evidence；未审查为NOT_ASSESSED。输入文件哈希只验证身份，不证明科学结论或真实视觉查看。
