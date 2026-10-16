# 热图：可辨方格与密集总览

先声明值：counts、TPM、VST、log强度、行Z-score、log2FC和相关系数不可混用。已处理值不默认再缩放；常量行、NA、截断和色阶中心必须记录。样本ID与metadata严格一一对应。

## 可读离散热图

R/ComplexHeatmap优先。少量数据**每个格子**必须正方形，不是整幅画布正方，也不是数据坐标宽高相等。单格边长由最终尺寸决定：`width = ncol * cell_mm + sum(column_gaps_mm)`，`height = nrow * cell_mm + sum(row_gaps_mm)`；给ComplexHeatmap矩阵主体的`width/height`，不要拿整图`heatmap_width/heatmap_height`充当主体。细白/黑边从0.2–0.4pt试画。每个实际body viewport的格宽高相对误差≤1%，该容差仅处理设备数值误差，不能用于设计长方格。标签、树、分类条和图例另留空间，不计入格子尺寸。放不下先扩容或拆分，不静默拉伸、不删行、不缩字掩盖。

CP2声明`heatmap_cell_contract`：`policy_id: heatmap-cells-v1`、`shape: square`、实际展示的`rows/columns`、`measurement_basis: final_body_viewports_mm`、`max_relative_error: 0.01`。CP3记录每panel/slice的`rows/columns`、`matrix_rows/matrix_columns`、`body_width_mm/body_height_mm`和`cell_width_mm/cell_height_mm`；分片必须完整覆盖展示矩阵，分组gap不能混进格高/格宽。CP4同时记录`final_size_checks.checks.cell_geometry`和`visual_evidence.cell_geometry`的当前图观察；少量非方格、缺量测或缺观察均退回。

ggplot2：`coord_fixed()`是常见构建方法，不是验收凭据。`bf_prepare`与`bf_export_png`分别在真实设备检查tile/raster的全部面板，含数值索引、翻转坐标和facet；热图用`geom_rect`时须由授权contract启用热图审查。导出设备或grob变更后重新量测。窄分类条优先用ComplexHeatmap annotation；手写tile条须在contract的`annotation_layers`声明`{layer: 2, role: categorical-strip}`，运行时要求一维且厚度≤3mm，不能把二维数据矩阵声明为注释来跳过检查。

ComplexHeatmap：在最终设备`draw()`后、关闭设备前调用`bf_complexheatmap_cell_metrics(drawn, 'heatmap_name')`；逐row/column slice量测，使用绘制对象实际order长度，不能用原始输入行数、总画布比例或仅`bf_square_body()`算术结果代替。PNG/PDF各自在原后端重验，不拉伸位图修形。最终凭据必须带`heatmap_cell_policy_id`、`checks.cell_geometry=true`和实际`heatmap_cells`；布尔声明不能替代执行。R凭据/inspection用`jsonlite::write_json(..., digits=NA)`保留物理测量精度；统一缩放到最终展示尺寸时同比换算所有mm，不能只改画布元数据。

## 密集表达热图

特别密集的数据可用长方格总览，例如5000基因；`shape: dense-overview`必须显式选择，并写`density_reason`，仍量测、记录真实格比，不能声称正方格。当前自动路由只在**实际展示**行或列>200时开放此选项；200是BioFigure的保守路由默认值，不是期刊标准或用户指定的科学阈值。行列均≤200仍要求square；原始5000行筛成30行、按模块汇总成20行，也按最终小矩阵检查。

使用MAT-EXPR-DENSE-001时保留全部展示数据，body可栅格化，文字/树/注释矢量；按预先定义模块/聚类分片，隐藏大多数行名，只按规则标少量行。逐格描边产生摩尔纹时禁用。需要逐格阅读时另给局部方格图；若用户另要求全量每格正方，只能超长图、分块或分页，并先说明物理尺寸冲突。

检索矩阵 Pattern 必传 `--rows` 与 `--columns`；规模超出卡片范围即从 eligibility 排除，不能只降排序。

共同规则：同一行集合联排只计算一次顺序；记录distance/linkage/seed/order。分类色带默认≤3 mm，名称用矩阵外图例；图例置于矩阵外；颜色参数化，同一颜色不兼任group与module。无总标题、panel letter或画布说明。依据：[ComplexHeatmap](https://jokergoo.github.io/ComplexHeatmap-reference/book/a-single-heatmap.html)。
