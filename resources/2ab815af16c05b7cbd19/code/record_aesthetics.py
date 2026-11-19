"""Source-specific observations recorded after opening all source/PNG/PDF images."""
from pathlib import Path
import hashlib
import json
import yaml

W = Path(__file__).resolve().parent
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
data = {
 'ASF-V01': {
  'hierarchy': '韩国轮廓及社群网络为主体，权重节点第二层；地图左、两种图例右。',
  'whitespace': '细灰底图退后；右侧独立留白容纳图例，济州岛完整保留。',
  'legend': '七类Community先列，Node weight三个圆后列；类别与大小分别解释。',
  'palette': '七种命名离散社群色，跨社群边淡灰；类别不套连续色条。',
  'typography': 'Arial 7 pt图例；原图地名未转嫁给合成网络；无流程文字。',
  'marks': '边先画、节点后画，深细节点描边；log10权重映射大小。',
  'parameters': {'edge_alpha': .42, 'edge_width_mm': [.1,.65], 'node_alpha': .85, 'node_size_mm': [.45,2.9], 'node_stroke_mm': .25, 'code': 'prepare_simulated.R:12-14'},
  'adaptation': '合成近邻网络较原图稀疏，社群位置和编号不同；未复现作者社群、节点值或原图密度。',
  'reuse_rule': '新网络先核节点/边密度，再定透明度与点径；坐标、社群编号及尺寸范围不能直接迁移。'},
 'ASF-V02': {
  'hierarchy': '原图4+3城市地图顺序和暖色高值重点保留；同城市配对使用同一几何。',
  'whitespace': '地图去坐标轴，第八空位容纳共同色条；七地图不被图例挤压。',
  'legend': '0、2、4、>=8完整，明确上限截断；共用尺度与原图每图独立断点有差异。',
  'palette': '浅黄、黄橙、红顺序渐变；白色Voronoi区块边界和灰外界形成内外层级。',
  'typography': '城市、分组与面板字母合在顶部一行；Arial 7 pt，色条不碰标题。',
  'marks': 'Voronoi区块白边0.07 mm、市界0.2 mm；同城几何固定以便数值比较。',
  'parameters': {'palette':['#FFF6C5','#FFDB7B','#F9A13B','#E74338'], 'limits_percent':[0,8], 'legend_mm':[30,3], 'cell_border_mm':.07, 'outer_border_mm':.2, 'code':'prepare_simulated.R:18-19'},
  'adaptation': '原图道路、水域、热点、比例尺和独立断点未完整保留；不生成未公开置信度。',
  'reuse_rule': '只有单位、范围、比较目标相同才共用色条；独立断点必须恢复各自图例。'},
 'ASF-V04': {
  'hierarchy': '原图立柱突出，工作日/周末等视角并排；当前保持等比例地图。',
  'whitespace': '两图同宽、窄中缝，底部预留共享图例；最高柱不碰顶部文字。',
  'legend': '两图共享0-100连续色条；颜色与高度在两图同义。',
  'palette': '低值蓝绿到高值暖黄红；浅中性地形退后。原深底对比按现有政策适配为白底。',
  'typography': 'Weekday/Weekend短标题位于图上方；Arial 7 pt，无图内说明段。',
  'marks': '0.7 mm圆端竖柱；EPSG:3414后作x=x+0.45y、y=0.58y显示变换；颜色与高度双编码。',
  'parameters': {'palette':['#087EA4','#1BB89B','#F6D76B','#F29C38','#C82856'], 'bar_width_mm':.7, 'panel_spacing_mm':1, 'code':'prepare_simulated.R:23-24'},
  'adaptation': '白底向量立柱替代深色道路底图/立体格网，1300行合成值非原GPS观测。',
  'reuse_rule': '双图锁同一投影、斜视变换、位置和高度范围；高密度先调柱宽，不单独改尺度。'},
 'ASF-V11': {
  'hierarchy': '仅放大源Figure1B韩国历史计数地图；原时间线和五曲线不含在交付内。',
  'whitespace': '小城市标签外置，两侧引线；省名白底内置；右上北箭头、左下比例尺和底部色条分开。',
  'legend': '65×3 mm色条明确原始累计计数；0/2000/4000/6000完整，不暗示人口标准化。',
  'palette': '浅粉至深红随计数递增；省界白细线、灰引线与填色分离，深红小区仍可辨。',
  'typography': '17地名/计数Arial 7 pt，长省名分行；外引线终点邻近标签，页内无裁切。',
  'marks': '白底标签padding 0.15 mm；引线0.22 mm、端点0.8 mm；17个官方值按行政键匹配。',
  'parameters': {'palette':['#FFDDDD','#D52332'], 'count_limits':[0,7200], 'boundary_mm':.22, 'leader_mm':.22, 'legend_mm':[65,3], 'code':'prepare_plot.R:13-21'},
  'adaptation': '17项官方2020-09-30值与源标签一致；GADM4.1/100 m简化为显示适配，非作者shp或整Figure1复现。',
  'reuse_rule': '按正式键匹配；小区外置标签不可删区域，新日期值必须重新审布局。'},
 'ASF-V23': {
  'hierarchy': '全球全景与三处海峡圆形局部形成全球至局部层级；当前主图大、三圆图小。',
  'whitespace': '主图和三局部分两行，色条置中间；移出新闻正文后局部仍有独立空间。',
  'legend': 'log10量级1e2/1e4/1e6/1e8完整；各局部与主图同色限，无局部单独归一。',
  'palette': '冷蓝至浅黄橙红表示合成量递增，淡米陆地退后；原暖底编辑风格适配为白页。',
  'typography': '三个海峡短标题置于圆窗上方，Arial 7 pt；色条单位完整。',
  'marks': '局部投影至中心LAEA并真正圆裁；圆边0.25 mm、点0.65 mm；点先画、陆地后盖。',
  'parameters': {'main_projection':'Robinson','inset_projection':'local LAEA','inset_border_mm':.25,'main_point_mm':.55,'inset_point_mm':.65,'layout_heights':[2.1,1],'code':'prepare_global_rio.R:7-10'},
  'adaptation': '合成航路显著少于原AIS密度，圆图位置重排；不继承原排放数量或新闻结论。',
  'reuse_rule': '圆图做几何裁切，不仅加圆框；放大密度必须共用主图尺度。'},
 'ASF-V26': {
  'hierarchy': '九等尺度时间地图按行读；数量等级用颜色和线宽双编码，时间顺序固定。',
  'whitespace': '3×3间距一致，底图灰弱于路径；底部共同图例独占一行。',
  'legend': '五级Paths同显色宽，1-10至81-200全可见；离散区间不用连续色条。',
  'palette': '源图启发的蓝/橙/黄/绿/红用于命名等级，线宽同步递增；不升为全库套色。',
  'typography': '九时间窗格式一致置顶；Arial 7 pt图例，底边无裁切或过程备注。',
  'marks': '灰网络0.15 mm；主线0.18/0.30/0.45/0.70/0.95 mm，alpha 0.9；直线合成段非观测道路。',
  'parameters': {'line_widths_mm':[.18,.3,.45,.7,.95],'alpha':.9,'ncol':3,'code':'prepare_simulated.R:26-27'},
  'adaptation': '真实武汉轮廓加合成近邻直线替代原道路/负荷；只借鉴时间小多图与共享编码。',
  'reuse_rule': '跨时间先固定网络、范围、断点、色宽和图例，不逐时段单独归一化。'},
 'ASF-V27': {
  'hierarchy': '源两大地图加右列两局部ABC/ABD结构保留；全局比较后读匹配放大。',
  'whitespace': '两主图同宽，右列相对宽0.8；底部图例独占横带，浅县界退后。',
  'legend': '五个Home-work trips区间用于所有面板；浅深紫及细粗同时解释。',
  'palette': '单色紫顺序梯度表达量级、底图浅灰；各面板不另配色。',
  'typography': 'a/b/c/d固定左上角色位置，Arial 8 pt，正文7 pt；无地名覆盖交点。',
  'marks': '0.10至0.80 mm线、alpha 0.78；全图局部使用同一网络和五级色宽映射。',
  'parameters': {'palette':['#DBCFEB','#BA96D5','#9564B4','#743C96','#4D226C'],'line_widths_mm':[.1,.2,.35,.55,.8],'alpha':.78,'layout_widths':[1,1,.8],'code':'prepare_simulated.R:29-30'},
  'adaptation': '450点合成近邻网络比源道路稀疏，几何为直线；不是道路级保真。',
  'reuse_rule': '局部从相同全图数据裁切；新数值需重核区间边界和溢出，不能只复用五种紫色。'},
 'ASF-V29': {
  'hierarchy': '上排曲线/柱图，下排宽地图；地图相对高1.45，先读策略再看空间。',
  'whitespace': '双图轴基线对齐；地图右预留两种数量图例，灰底/蓝点/绿线层级分离。',
  'legend': '距离三色跨曲线和柱图一致；origin点径和ridership线宽分两种独立图例。',
  'palette': '距离为柔和绿/橙/紫离散色；蓝透明圆和绿线路表达不同量，不混成同一色条。',
  'typography': '轴/图例Arial 7 pt、面板a/b/c 8 pt；柱横标签45度。',
  'marks': '曲线0.45 mm、点1.5 mm；柱深边0.35 mm；地图圆alpha 0.3、径1-9 mm，路线0.25-1.7 mm、alpha 0.85。',
  'parameters': {'distance_colors':{'1 km':'#409B85','2 km':'#D57434','3 km':'#7772AB'},'bubble_alpha':.3,'route_alpha':.85,'bar_border_mm':.35,'layout_heights':[1,1.45],'code':'prepare_global_rio.R:13-19'},
  'adaptation': '源origin/destination连续表面改为origin气泡和路线；合成曲线/位置不能支持策略效果结论。',
  'reuse_rule': '跨图类别命名绑定；点面积和线宽各自定标，新单位/范围须重审。'},
}
for mid, item in data.items():
    w = W if mid == 'ASF-V11' else W / mid
    spec = yaml.safe_load((w / 'design-spec.yaml').read_text())
    qc = json.loads((w / 'input-qc.json').read_text())
    run = json.loads((w / 'run.json').read_text())
    item['parameters']['canvas_mm'] = [qc['width_mm'], qc['height_mm']]
    ref = spec['design_target']['reference']
    item.update(method_id=mid, source_figure={'path':ref,'sha256':sha(ref)}, artifact=run['png'], pdf=run['pdf'], reviewed_source=True, reviewed_current_png=True, reviewed_actual_pdf_raster=True, validation_scope='Fixed-input design review; new-input transfer and stress cases NOT_TESTED', user_acceptance='NOT_ASSESSED')
    (w / 'aesthetic-learning.json').write_text(json.dumps(item, ensure_ascii=False, indent=2)+'\n')
(W / 'aesthetic-learning-all.json').write_text(json.dumps({'schema_version':1,'cases':data,'reviewer_type':'model'}, ensure_ascii=False, indent=2)+'\n')
print('Recorded aesthetic observations for', len(data), 'cases.')
