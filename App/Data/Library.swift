import SwiftUI

// MARK: - 训练方案模型

struct PlanItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var sets: String
    var reps: String
    var rest: String
    /// 自定义休息秒数，0 表示沿用 rest 文案解析出来的值
    var restSec: Int = 0
}

struct PlanDay: Identifiable, Hashable, Codable {
    var id = UUID()
    var title: String
    var focus: String
    var items: [PlanItem]
}

struct PlanTemplate: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var tag: String
    var level: String
    var daysPerWeek: Int
    var cycle: String
    var summary: String
    var progression: String
    var days: [PlanDay]
}

// MARK: - 动作库（88 个）

let allMoves: [MoveItem] = [
    // ========== 胸 13 ==========
    MoveItem(name: "杠铃平板卧推", group: "胸", equipment: "杠铃", cue: "肩胛后缩下沉，杠触下胸乳线，肘与躯干 45–60°", pr: "65kg × 8",
             error: "肘外展到 90°、耸肩；杠在胸口弹起； hips 离凳", alt: "哑铃卧推 / 器械推胸", level: "中级",
             video: "https://www.iesdouyin.com/share/video/7642310606598821489"),
    MoveItem(name: "上斜杠铃卧推", group: "胸", equipment: "杠铃", cue: "凳角 30°，杠触锁骨下缘", pr: "50kg × 8",
             error: "凳角超过 45° 变成练肩；下放过高压肩", alt: "上斜哑铃卧推", level: "中级"),
    MoveItem(name: "哑铃上斜卧推", group: "胸", equipment: "哑铃", cue: "凳角 30°，顶峰不相撞，肘微内收", pr: "22kg × 10",
             error: "下放过深拉伤肩前束；双铃相撞卸力", alt: "上斜杠铃卧推", level: "初级"),
    MoveItem(name: "下斜卧推", group: "胸", equipment: "杠铃", cue: "脚卡稳，练下胸，肘 45°", pr: "55kg × 8",
             error: "头部充血、没固定脚滑落", alt: "双杠臂屈伸", level: "中级"),
    MoveItem(name: "哑铃平板飞鸟", group: "胸", equipment: "哑铃", cue: "肘微屈画弧，下放到胸同高即止", pr: "14kg × 12",
             error: "肘伸太直拉伤肩；下放过低", alt: "绳索夹胸", level: "中级"),
    MoveItem(name: "绳索夹胸", group: "胸", equipment: "器械", cue: "顶峰收缩停 1 秒，全程张力", pr: "15kg × 15",
             error: "重量过大靠身体前倾压", alt: "哑铃飞鸟", level: "初级"),
    MoveItem(name: "器械推胸", group: "胸", equipment: "器械", cue: "背贴垫，推至不锁死肘", pr: "60kg × 12",
             error: "肩前伸耸起；肘锁死", alt: "杠铃卧推", level: "初级"),
    MoveItem(name: "俯卧撑", group: "胸", equipment: "自重", cue: "身体一条线，核心收紧，肘 45°", pr: "20 次",
             error: "塌腰撅臀；只做半程", alt: "跪姿俯卧撑", level: "初级"),
    MoveItem(name: "双杠臂屈伸", group: "胸", equipment: "自重", cue: "身体前倾 30° 练下胸，下沉到肩肘同高", pr: "12 次",
             error: "下沉过深伤肩；耸肩", alt: "下斜卧推", level: "中级"),
    MoveItem(name: "窄距卧推", group: "胸", equipment: "杠铃", cue: "握距与肩同宽，肘贴身体", pr: "45kg × 10",
             error: "握太窄手腕疼；肘外张", alt: "窄距俯卧撑", level: "中级"),
    MoveItem(name: "哑铃仰卧上拉", group: "胸", equipment: "哑铃", cue: "感受背阔与胸廓拉伸，只到舒适幅度", pr: "18kg × 12",
             error: "下沉过深压肩关节", alt: "直臂下压", level: "中级"),
    MoveItem(name: "地板卧推", group: "胸", equipment: "杠铃", cue: "肘触地即停，保护肩关节", pr: "50kg × 8",
             error: "用惯性弹起；肘砸地", alt: "平板卧推", level: "初级"),
    MoveItem(name: "弹力带夹胸", group: "胸", equipment: "弹力带", cue: "站姿前倾，双手在胸前合拢停 1 秒", pr: "20 次",
             error: "只用手臂不夹胸", alt: "绳索夹胸", level: "初级"),

    // ========== 背 14 ==========
    MoveItem(name: "硬拉", group: "背", equipment: "杠铃", cue: "杠贴小腿垂直上行，髋主导，背全程中立", pr: "100kg × 5",
             error: "弓腰起杠；杠离腿前飘；顶端后仰顶腰", alt: "罗马尼亚硬拉", level: "高级",
             video: "https://www.iesdouyin.com/share/video/7658225274181487915"),
    MoveItem(name: "罗马尼亚硬拉", group: "背", equipment: "杠铃", cue: "髋后推、膝微屈，腿后侧拉到紧即回", pr: "80kg × 8",
             error: "弯腰而不是屈髋；杠离腿", alt: "哑铃 RDL", level: "中级"),
    MoveItem(name: "引体向上", group: "背", equipment: "自重", cue: "沉肩挺胸，肘尖向下压找裤兜", pr: "8 次",
             error: "耸肩、靠摆动借力；半程不伸肘", alt: "高位下拉 / 助力引体", level: "中级",
             video: "https://www.iesdouyin.com/share/video/7646278157255538154"),
    MoveItem(name: "宽握引体", group: "背", equipment: "自重", cue: "宽握更偏背阔外沿，全幅度", pr: "6 次",
             error: "只做上半程；肩耸到耳朵", alt: "高位下拉", level: "高级"),
    MoveItem(name: "高位下拉", group: "背", equipment: "器械", cue: "先沉肩再拉肘到锁骨，别拉背后颈", pr: "55kg × 12",
             error: "身体后仰 45°；拉到颈后", alt: "引体向上", level: "初级"),
    MoveItem(name: "杠铃划船", group: "背", equipment: "杠铃", cue: "躯干 45°，拉向小腹，肩胛后缩", pr: "60kg × 10",
             error: "弓背；甩腰借力；耸肩", alt: "T 杠划船", level: "中级"),
    MoveItem(name: "单臂哑铃划船", group: "背", equipment: "哑铃", cue: "肘贴身体走，拉向髋侧", pr: "26kg × 10",
             error: "身体旋转借力；只用手臂", alt: "坐姿绳索划船", level: "初级"),
    MoveItem(name: "T 杠划船", group: "背", equipment: "器械", cue: "胸贴垫，肩胛后缩再拉", pr: "50kg × 10",
             error: "起身借力；弓背", alt: "杠铃划船", level: "中级"),
    MoveItem(name: "坐姿绳索划船", group: "背", equipment: "器械", cue: "肩胛后缩再拉，肘贴身", pr: "50kg × 12",
             error: "耸肩；用腰后仰借力", alt: "器械划船", level: "初级"),
    MoveItem(name: "直臂下压", group: "背", equipment: "器械", cue: "手臂伸直，划弧到髋，感受背阔", pr: "20kg × 15",
             error: "屈肘变成三头下压", alt: "仰卧上拉", level: "初级"),
    MoveItem(name: "面拉", group: "背", equipment: "器械", cue: "拉向额头，肘高于手，末端分开", pr: "20kg × 15",
             error: "重量过大耸肩弓背", alt: "反向飞鸟", level: "初级"),
    MoveItem(name: "山羊挺身", group: "背", equipment: "器械", cue: "起身到身体成直线即停", pr: "15 次",
             error: "顶端过伸伤腰", alt: "鸟狗", level: "初级"),
    MoveItem(name: "杠铃耸肩", group: "背", equipment: "杠铃", cue: "只做上下，不转肩", pr: "70kg × 12",
             error: "绕肩、甩头", alt: "哑铃耸肩", level: "初级"),
    MoveItem(name: "反向飞鸟", group: "背", equipment: "哑铃", cue: "俯身 45°，肘微屈向两侧打开", pr: "6kg × 15",
             error: "弓背耸肩；用惯性甩", alt: "面拉", level: "初级"),

    // ========== 腿 15 ==========
    MoveItem(name: "杠铃深蹲", group: "腿", equipment: "杠铃", cue: "膝对脚尖，蹲到大腿平行或略低", pr: "90kg × 6",
             error: "膝内扣；脚跟离地；弓背", alt: "高脚杯深蹲", level: "中级",
             video: "https://www.iesdouyin.com/share/video/7639102910932542857"),
    MoveItem(name: "高脚杯深蹲", group: "腿", equipment: "哑铃", cue: "哑铃抱胸前，躯干直立下蹲", pr: "20kg × 12",
             error: "上身前倾变成早安式", alt: "杠铃深蹲", level: "初级"),
    MoveItem(name: "保加利亚分腿蹲", group: "腿", equipment: "哑铃", cue: "前脚掌发力，后脚只做支撑", pr: "16kg × 10",
             error: "步距太近压膝盖；后脚蹬地", alt: "箭步蹲", level: "中级"),
    MoveItem(name: "腿举", group: "腿", equipment: "器械", cue: "背贴垫，下放到 90°，蹬起不锁死", pr: "140kg × 12",
             error: "下放过深腰离垫；锁死膝盖", alt: "深蹲", level: "初级"),
    MoveItem(name: "腿屈伸", group: "腿", equipment: "器械", cue: "顶端停 1 秒，控制下放", pr: "40kg × 12",
             error: "甩腿借力", alt: "保加利亚分腿蹲", level: "初级"),
    MoveItem(name: "腿弯举", group: "腿", equipment: "器械", cue: "收缩到底停 1 秒", pr: "40kg × 12",
             error: "臀部抬离垫", alt: "罗马尼亚硬拉", level: "初级"),
    MoveItem(name: "站姿提踵", group: "腿", equipment: "自重", cue: "登顶停 1 秒再慢放", pr: "25 次",
             error: "弹震式借力", alt: "坐姿提踵", level: "初级"),
    MoveItem(name: "坐姿提踵", group: "腿", equipment: "器械", cue: "全幅度，底部充分拉伸", pr: "30kg × 15",
             error: "幅度太短", alt: "站姿提踵", level: "初级"),
    MoveItem(name: "臀桥", group: "腿", equipment: "自重", cue: "顶端夹臀 2 秒，肋骨收住", pr: "20 次",
             error: "用腰顶而不是臀", alt: "杠铃臀推", level: "初级"),
    MoveItem(name: "杠铃臀推", group: "腿", equipment: "杠铃", cue: "下巴收、肋骨下沉，顶峰夹臀", pr: "80kg × 12",
             error: "腰椎过伸；幅度不足", alt: "臀桥", level: "中级"),
    MoveItem(name: "箭步蹲", group: "腿", equipment: "哑铃", cue: "前后膝均约 90°，垂直下蹲", pr: "16kg × 12",
             error: "步幅过小压前膝；上身前倾", alt: "保加利亚分腿蹲", level: "初级"),
    MoveItem(name: "登台阶", group: "腿", equipment: "哑铃", cue: "全脚掌上台，膝对脚尖", pr: "16kg × 10",
             error: "后脚蹬地借力", alt: "箭步蹲", level: "初级"),
    MoveItem(name: "相扑硬拉", group: "腿", equipment: "杠铃", cue: "宽站距，膝外展，杠贴腿", pr: "90kg × 6",
             error: "弓背；杠离腿；膝内扣", alt: "常规硬拉", level: "中级"),
    MoveItem(name: "髋外展", group: "腿", equipment: "器械", cue: "坐姿，膝外展停 1 秒", pr: "50kg × 15",
             error: "用腰代偿晃动", alt: "弹力带侧步", level: "初级"),
    MoveItem(name: "靠墙静蹲", group: "腿", equipment: "自重", cue: "大腿平行地面，膝不过脚尖", pr: "60 秒",
             error: "膝盖内扣；蹲太深", alt: "高脚杯深蹲", level: "初级"),

    // ========== 肩 12 ==========
    MoveItem(name: "哑铃肩上推举", group: "肩", equipment: "哑铃", cue: "核心收紧，别塌腰，推到手臂伸直", pr: "16kg × 10",
             error: "过度挺腰；推时耸肩", alt: "杠铃推举", level: "初级"),
    MoveItem(name: "杠铃推举", group: "肩", equipment: "杠铃", cue: "杠过锁骨，头微后移让杆过线", pr: "40kg × 8",
             error: "后仰借力；腰椎超伸", alt: "哑铃推举", level: "中级"),
    MoveItem(name: "侧平举", group: "肩", equipment: "哑铃", cue: "肘带手，小指略高，提到肩高即止", pr: "8kg × 15",
             error: "耸肩；甩动借力；举过肩", alt: "绳索侧平举", level: "初级"),
    MoveItem(name: "绳索侧平举", group: "肩", equipment: "器械", cue: "低位滑轮，全程保持张力", pr: "10kg × 15",
             error: "身体摆动借力", alt: "哑铃侧平举", level: "中级"),
    MoveItem(name: "前平举", group: "肩", equipment: "哑铃", cue: "举至肩高即停，不借力", pr: "8kg × 15",
             error: "举过高耸肩；身体后仰", alt: "杠铃片前平举", level: "初级"),
    MoveItem(name: "俯身反向飞鸟", group: "肩", equipment: "哑铃", cue: "俯身 45°，肘微屈外展到肩高", pr: "6kg × 15",
             error: "弓背；用惯性甩", alt: "面拉", level: "初级"),
    MoveItem(name: "阿诺德推举", group: "肩", equipment: "哑铃", cue: "掌心朝自己起，旋转中推起", pr: "14kg × 10",
             error: "旋转过快伤肩", alt: "哑铃推举", level: "中级"),
    MoveItem(name: "器械肩推", group: "肩", equipment: "器械", cue: "背贴垫，推至不锁死", pr: "40kg × 12",
             error: "耸肩；幅度不足", alt: "哑铃推举", level: "初级"),
    MoveItem(name: "直立划船", group: "肩", equipment: "杠铃", cue: "拉到胸线，肘高于手，不拉到下巴", pr: "30kg × 12",
             error: "拉太高挤压肩；耸肩", alt: "侧平举", level: "高级"),
    MoveItem(name: "Y 字举", group: "肩", equipment: "哑铃", cue: "俯身 Y 型抬起，练后束与斜方下束", pr: "4kg × 15",
             error: "重量过大变成耸肩", alt: "反向飞鸟", level: "中级"),
    MoveItem(name: "倒立撑", group: "肩", equipment: "自重", cue: "靠墙倒立，头颈中立，慢下慢上", pr: "5 次",
             error: "塌腰；颈部受压", alt: "哑铃推举", level: "高级"),
    MoveItem(name: "哑铃耸肩", group: "肩", equipment: "哑铃", cue: "只做上下，顶端停 1 秒", pr: "30kg × 12",
             error: "绕肩；用腿弹", alt: "杠铃耸肩", level: "初级"),

    // ========== 手臂 12 ==========
    MoveItem(name: "哑铃二头弯举", group: "手臂", equipment: "哑铃", cue: "肘贴身，弯起时腕外旋", pr: "14kg × 12",
             error: "甩腰借力；肘前移", alt: "杠铃弯举", level: "初级"),
    MoveItem(name: "杠铃弯举", group: "手臂", equipment: "杠铃", cue: "下放 2 秒，别借力", pr: "30kg × 10",
             error: "身体后仰甩起", alt: "哑铃弯举", level: "初级"),
    MoveItem(name: "锤式弯举", group: "手臂", equipment: "哑铃", cue: "拇指朝上，练肱桡肌", pr: "12kg × 12",
             error: "肘前移；摆动", alt: "反握弯举", level: "初级"),
    MoveItem(name: "牧师椅弯举", group: "手臂", equipment: "器械", cue: "上臂固定，底部不完全放松", pr: "20kg × 12",
             error: "底部完全放松伤肘", alt: "斜托弯举", level: "中级"),
    MoveItem(name: "集中弯举", group: "手臂", equipment: "哑铃", cue: "肘抵大腿内侧，只动前臂", pr: "12kg × 12",
             error: "用肩提", alt: "哑铃弯举", level: "初级"),
    MoveItem(name: "斜托弯举", group: "手臂", equipment: "哑铃", cue: "斜凳 45°，底部充分拉伸", pr: "10kg × 12",
             error: "肩前移卸力", alt: "牧师椅弯举", level: "中级"),
    MoveItem(name: "绳索下压", group: "手臂", equipment: "器械", cue: "肘固定在体侧，到底分开绳", pr: "30kg × 15",
             error: "耸肩；肘后移", alt: "窄距俯卧撑", level: "初级"),
    MoveItem(name: "仰卧臂屈伸", group: "手臂", equipment: "杠铃", cue: "肘尖朝天，杠落到额头上方", pr: "25kg × 10",
             error: "肘外展；下放砸到脸", alt: "过顶臂屈伸", level: "中级"),
    MoveItem(name: "过顶臂屈伸", group: "手臂", equipment: "哑铃", cue: "肘尖朝前，只动前臂", pr: "16kg × 12",
             error: "肘外张；腰部代偿", alt: "绳索下压", level: "初级"),
    MoveItem(name: "窄距俯卧撑", group: "手臂", equipment: "自重", cue: "双手与肩同宽，肘贴身", pr: "15 次",
             error: "肘外展变成练胸", alt: "绳索下压", level: "初级"),
    MoveItem(name: "腕弯举", group: "手臂", equipment: "哑铃", cue: "前臂贴凳，只动手腕", pr: "10kg × 20",
             error: "幅度太短；用前臂发力", alt: "反握腕弯举", level: "初级"),
    MoveItem(name: "反握弯举", group: "手臂", equipment: "杠铃", cue: "掌心向下，练前臂伸肌", pr: "20kg × 12",
             error: "甩动借力", alt: "锤式弯举", level: "中级"),

    // ========== 核心 22 ==========
    MoveItem(name: "平板支撑", group: "核心", equipment: "自重", cue: "夹臀收肋，身体一条线", pr: "90 秒",
             error: "塌腰撅臀；憋气", alt: "侧平板", level: "初级"),
    MoveItem(name: "侧平板", group: "核心", equipment: "自重", cue: "髋不下沉，身体成直线", pr: "45 秒/侧",
             error: "身体旋转前倾", alt: "平板支撑", level: "初级"),
    MoveItem(name: "卷腹", group: "核心", equipment: "自重", cue: "下背贴地，只抬肩胛离地", pr: "20 次",
             error: "拉扯脖子；整段起身", alt: "悬垂举腿", level: "初级"),
    MoveItem(name: "悬垂举腿", group: "核心", equipment: "自重", cue: "骨盆后倾再抬腿，不是摆腿", pr: "10 次",
             error: "只摆腿不卷骨盆；身体晃", alt: "仰卧举腿", level: "高级"),
    MoveItem(name: "仰卧举腿", group: "核心", equipment: "自重", cue: "腰贴地，腿慢放不落地", pr: "15 次",
             error: "腰离地形成反弓", alt: "卷腹", level: "初级"),
    MoveItem(name: "死虫", group: "核心", equipment: "自重", cue: "腰全程贴地，对侧手脚缓慢伸展", pr: "12 次/侧",
             error: "腰拱起；动作太快", alt: "鸟狗", level: "初级"),
    MoveItem(name: "鸟狗", group: "核心", equipment: "自重", cue: "四点跪姿，对侧手脚伸展，慢", pr: "12 次/侧",
             error: "塌腰；身体旋转", alt: "死虫", level: "初级"),
    MoveItem(name: "健腹轮", group: "核心", equipment: "器械", cue: "能控住才往外滚，滚到极限即回", pr: "8 次",
             error: "塌腰滚出去；用腰代偿", alt: "平板支撑", level: "高级"),
    MoveItem(name: "俄罗斯转体", group: "核心", equipment: "自重", cue: "胸带动旋转，不是甩手", pr: "20 次",
             error: "只甩手臂；腰代偿", alt: "Pallof 推", level: "中级"),
    MoveItem(name: "登山跑", group: "核心", equipment: "自重", cue: "髋屈主导，背保持平", pr: "30 秒",
             error: "臀部抬高；塌腰", alt: "卷腹", level: "中级"),
    MoveItem(name: "Pallof 推", group: "核心", equipment: "器械", cue: "抗旋转，双手推出时身体不转", pr: "12 次/侧",
             error: "身体跟着转", alt: "俄罗斯转体", level: "中级"),
    MoveItem(name: "负重体前屈", group: "核心", equipment: "杠铃", cue: "轻重量，脊柱全程中立", pr: "20kg × 12",
             error: "弓背；重量过大", alt: "山羊挺身", level: "高级"),

    // ========== 腹部补全 10 ==========
    MoveItem(name: "空中蹬自行车", group: "核心", equipment: "自重", cue: "仰卧双手抱头，对侧肘碰膝，腿伸直不落地，慢速画圈", pr: "20 次/侧",
             error: "靠脖子发力拉扯颈椎；速度太快变甩腿；腰离地", alt: "俄罗斯转体", level: "中级"),
    MoveItem(name: "反向卷腹", group: "核心", equipment: "自重", cue: "仰卧屈膝 90°，用下腹把骨盆卷离地，膝盖靠向胸口", pr: "15 次",
             error: "用腿的惯性甩上去；腰代偿抬起整条背", alt: "仰卧举腿", level: "初级"),
    MoveItem(name: "V 字两头起", group: "核心", equipment: "自重", cue: "仰卧伸展，手脚同时抬起在身体上方相触，形成 V 字", pr: "12 次",
             error: "靠惯性甩起；落地时腰砸地；屈膝作弊", alt: "抱膝起坐", level: "高级"),
    MoveItem(name: "仰卧起坐", group: "核心", equipment: "自重", cue: "屈膝固定双脚，卷起脊柱逐节离地，下巴微收", pr: "25 次",
             error: "双手抱头猛拉颈椎；直腿靠惯性弹起", alt: "卷腹", level: "初级"),
    MoveItem(name: "触踝卷腹", group: "核心", equipment: "自重", cue: "仰卧屈膝脚掌贴地，肩胛离地后左右手交替触踝", pr: "20 次/侧",
             error: "整个背抬起；只伸手不转体", alt: "俄罗斯转体", level: "初级"),
    MoveItem(name: "剪刀腿", group: "核心", equipment: "自重", cue: "仰卧腰贴地，双腿伸直离地 15cm 上下交替交叉", pr: "30 秒",
             error: "腰离地形成反弓；腿抬过高省力", alt: "仰卧举腿", level: "中级"),
    MoveItem(name: "悬垂抬膝", group: "核心", equipment: "自重", cue: "悬挂身体稳定，屈膝抬到胸口高度，慢放不晃", pr: "12 次",
             error: "摆腿借力；身体前后荡", alt: "悬垂举腿", level: "中级"),
    MoveItem(name: "绳索跪姿卷腹", group: "核心", equipment: "器械", cue: "跪在滑轮前，绳在头两侧，用腹肌把肘拉向膝盖", pr: "15kg × 15",
             error: "手臂发力拉绳；髋部前后移动代偿", alt: "卷腹", level: "中级"),
    MoveItem(name: "负重侧屈", group: "核心", equipment: "哑铃", cue: "单手执铃，只做侧向屈体，不前后倾", pr: "20kg × 15",
             error: "身体前倾或旋转；幅度过大", alt: "俄罗斯转体", level: "初级"),
    MoveItem(name: "龙旗", group: "核心", equipment: "自重", cue: "肩背固定长凳，身体绷直如板，靠核心控制缓慢下落", pr: "6 次",
             error: "塌腰折断式下落；没控制直接砸下", alt: "V 字两头起", level: "高级")
]

// MARK: - 训练方案（4 套）

let planTemplates: [PlanTemplate] = [
    PlanTemplate(
        name: "5×5 新手力量",
        tag: "力量打底",
        level: "新手",
        daysPerWeek: 3,
        cycle: "12–16 周",
        summary: "五个杠铃复合动作，每次训练加一点重量。新手前 3 个月涨力量最快的一套，重点是把动作模式练标准。",
        progression: "完成全部 5×5 且动作标准 → 下次加 2.5kg（深蹲、硬拉 5kg）。同一重量连续失败两次 → 减 10% 重建。",
        days: [
            PlanDay(title: "训练 A", focus: "蹲 · 推 · 拉", items: [
                PlanItem(name: "杠铃深蹲", sets: "5", reps: "5", rest: "3–5 分钟"),
                PlanItem(name: "杠铃平板卧推", sets: "5", reps: "5", rest: "3–5 分钟"),
                PlanItem(name: "杠铃划船", sets: "5", reps: "5", rest: "3–5 分钟")
            ]),
            PlanDay(title: "训练 B", focus: "蹲 · 推举 · 硬拉", items: [
                PlanItem(name: "杠铃深蹲", sets: "5", reps: "5", rest: "3–5 分钟"),
                PlanItem(name: "杠铃推举", sets: "5", reps: "5", rest: "3–5 分钟"),
                PlanItem(name: "硬拉", sets: "1", reps: "5", rest: "3–5 分钟")
            ])
        ]
    ),

    PlanTemplate(
        name: "PPL 六日分化",
        tag: "增肌进阶",
        level: "进阶",
        daysPerWeek: 6,
        cycle: "8 周一轮",
        summary: "推、拉、腿各练两次，A 日偏重重量、B 日偏多次数。每个肌群一周练到两次，是增肌效率最高的排法之一。",
        progression: "双重渐进：先把每组做到次数上限，再加最小重量（上肢 2.5kg、下肢 5kg）重新从下限爬。第 6–8 周减载一周。",
        days: [
            PlanDay(title: "推 A", focus: "胸 · 肩 · 三头（重）", items: [
                PlanItem(name: "杠铃平板卧推", sets: "4", reps: "5–6", rest: "3 分钟"),
                PlanItem(name: "杠铃推举", sets: "3", reps: "8–10", rest: "2 分钟"),
                PlanItem(name: "哑铃上斜卧推", sets: "3", reps: "10–12", rest: "90 秒"),
                PlanItem(name: "绳索夹胸", sets: "3", reps: "12–15", rest: "60 秒"),
                PlanItem(name: "侧平举", sets: "3", reps: "15", rest: "60 秒"),
                PlanItem(name: "绳索下压", sets: "3", reps: "12–15", rest: "60 秒")
            ]),
            PlanDay(title: "拉 A", focus: "背 · 后束 · 二头（重）", items: [
                PlanItem(name: "硬拉", sets: "3", reps: "5", rest: "3 分钟"),
                PlanItem(name: "引体向上", sets: "3", reps: "8–10", rest: "2 分钟"),
                PlanItem(name: "杠铃划船", sets: "3", reps: "8–10", rest: "2 分钟"),
                PlanItem(name: "面拉", sets: "3", reps: "15", rest: "60 秒"),
                PlanItem(name: "杠铃弯举", sets: "3", reps: "10–12", rest: "60 秒"),
                PlanItem(name: "锤式弯举", sets: "3", reps: "12–15", rest: "60 秒")
            ]),
            PlanDay(title: "腿 A", focus: "股四头为主", items: [
                PlanItem(name: "杠铃深蹲", sets: "4", reps: "6", rest: "3 分钟"),
                PlanItem(name: "罗马尼亚硬拉", sets: "3", reps: "8–10", rest: "2 分钟"),
                PlanItem(name: "腿举", sets: "3", reps: "10–12", rest: "2 分钟"),
                PlanItem(name: "腿弯举", sets: "3", reps: "12–15", rest: "60 秒"),
                PlanItem(name: "站姿提踵", sets: "4", reps: "12–15", rest: "60 秒"),
                PlanItem(name: "悬垂举腿", sets: "3", reps: "12–15", rest: "60 秒")
            ]),
            PlanDay(title: "推 B", focus: "胸 · 肩 · 三头（多次数）", items: [
                PlanItem(name: "上斜杠铃卧推", sets: "4", reps: "6–8", rest: "2.5 分钟"),
                PlanItem(name: "哑铃平板卧推", sets: "3", reps: "10–12", rest: "90 秒"),
                PlanItem(name: "器械肩推", sets: "3", reps: "10–12", rest: "90 秒"),
                PlanItem(name: "侧平举", sets: "3", reps: "15", rest: "60 秒"),
                PlanItem(name: "双杠臂屈伸", sets: "3", reps: "10–12", rest: "90 秒"),
                PlanItem(name: "过顶臂屈伸", sets: "3", reps: "12–15", rest: "60 秒")
            ]),
            PlanDay(title: "拉 B", focus: "背 · 后束 · 二头（多次数）", items: [
                PlanItem(name: "杠铃划船", sets: "4", reps: "6–8", rest: "2.5 分钟"),
                PlanItem(name: "宽握引体", sets: "3", reps: "10–12", rest: "90 秒"),
                PlanItem(name: "坐姿绳索划船", sets: "3", reps: "10–12", rest: "90 秒"),
                PlanItem(name: "反向飞鸟", sets: "3", reps: "15", rest: "60 秒"),
                PlanItem(name: "斜托弯举", sets: "3", reps: "10–12", rest: "60 秒"),
                PlanItem(name: "锤式弯举", sets: "3", reps: "12–15", rest: "60 秒")
            ]),
            PlanDay(title: "腿 B", focus: "臀腿后链为主", items: [
                PlanItem(name: "硬拉", sets: "3", reps: "5", rest: "3 分钟"),
                PlanItem(name: "高脚杯深蹲", sets: "3", reps: "12", rest: "90 秒"),
                PlanItem(name: "保加利亚分腿蹲", sets: "3", reps: "10/腿", rest: "90 秒"),
                PlanItem(name: "腿屈伸", sets: "3", reps: "12", rest: "60 秒"),
                PlanItem(name: "坐姿提踵", sets: "4", reps: "12–15", rest: "60 秒"),
                PlanItem(name: "健腹轮", sets: "3", reps: "8", rest: "60 秒")
            ])
        ]
    ),

    PlanTemplate(
        name: "上下肢四日",
        tag: "力量 + 增肌平衡",
        level: "中级",
        daysPerWeek: 4,
        cycle: "8 周一轮",
        summary: "上肢两天、下肢两天，练四天休三天。时间不够练六天的人，这套性价比最高，力量和围度都能兼顾。",
        progression: "复合动作完成次数上限就加 2.5–5kg；孤立动作先加次数再加重量。四周加一次负荷，第六周减载。",
        days: [
            PlanDay(title: "上肢 A", focus: "水平推 · 水平拉", items: [
                PlanItem(name: "杠铃平板卧推", sets: "4", reps: "6", rest: "2.5 分钟"),
                PlanItem(name: "杠铃划船", sets: "4", reps: "8", rest: "2.5 分钟"),
                PlanItem(name: "杠铃推举", sets: "3", reps: "8", rest: "2 分钟"),
                PlanItem(name: "高位下拉", sets: "3", reps: "10", rest: "90 秒"),
                PlanItem(name: "杠铃弯举", sets: "3", reps: "12", rest: "60 秒"),
                PlanItem(name: "绳索下压", sets: "3", reps: "12", rest: "60 秒")
            ]),
            PlanDay(title: "下肢 A", focus: "蹲为主", items: [
                PlanItem(name: "杠铃深蹲", sets: "4", reps: "6", rest: "3 分钟"),
                PlanItem(name: "罗马尼亚硬拉", sets: "3", reps: "8", rest: "2 分钟"),
                PlanItem(name: "腿举", sets: "3", reps: "10", rest: "2 分钟"),
                PlanItem(name: "腿弯举", sets: "3", reps: "12", rest: "60 秒"),
                PlanItem(name: "站姿提踵", sets: "4", reps: "15", rest: "60 秒"),
                PlanItem(name: "平板支撑", sets: "3", reps: "60 秒", rest: "45 秒")
            ]),
            PlanDay(title: "上肢 B", focus: "上斜推 · 垂直拉", items: [
                PlanItem(name: "上斜杠铃卧推", sets: "4", reps: "8", rest: "2 分钟"),
                PlanItem(name: "引体向上", sets: "4", reps: "8", rest: "2 分钟"),
                PlanItem(name: "侧平举", sets: "4", reps: "15", rest: "60 秒"),
                PlanItem(name: "坐姿绳索划船", sets: "3", reps: "10", rest: "90 秒"),
                PlanItem(name: "锤式弯举", sets: "3", reps: "12", rest: "60 秒"),
                PlanItem(name: "面拉", sets: "3", reps: "15", rest: "60 秒")
            ]),
            PlanDay(title: "下肢 B", focus: "髋主导", items: [
                PlanItem(name: "硬拉", sets: "3", reps: "5", rest: "3 分钟"),
                PlanItem(name: "箭步蹲", sets: "3", reps: "10/腿", rest: "90 秒"),
                PlanItem(name: "腿屈伸", sets: "3", reps: "12", rest: "60 秒"),
                PlanItem(name: "杠铃臀推", sets: "3", reps: "12", rest: "90 秒"),
                PlanItem(name: "坐姿提踵", sets: "4", reps: "15", rest: "60 秒"),
                PlanItem(name: "侧平板", sets: "3", reps: "45 秒/侧", rest: "45 秒")
            ])
        ]
    ),

    PlanTemplate(
        name: "新手全身三日",
        tag: "零基础起步",
        level: "新手",
        daysPerWeek: 3,
        cycle: "8 周",
        summary: "每次训练覆盖全身，隔天练。动作简单、单次时间短，先把动作学会、把习惯建立起来。",
        progression: "同一动作每次加 2.5kg 或加 2 次；连续两次完不成就减 10%。第八周减载一半组数。",
        days: [
            PlanDay(title: "第 1 天", focus: "全身 · 推为主", items: [
                PlanItem(name: "杠铃深蹲", sets: "3", reps: "8", rest: "2 分钟"),
                PlanItem(name: "杠铃平板卧推", sets: "3", reps: "8", rest: "2 分钟"),
                PlanItem(name: "杠铃划船", sets: "3", reps: "10", rest: "90 秒"),
                PlanItem(name: "侧平举", sets: "3", reps: "15", rest: "60 秒"),
                PlanItem(name: "平板支撑", sets: "3", reps: "45 秒", rest: "45 秒")
            ]),
            PlanDay(title: "第 2 天", focus: "全身 · 拉为主", items: [
                PlanItem(name: "硬拉", sets: "3", reps: "5", rest: "2.5 分钟"),
                PlanItem(name: "杠铃推举", sets: "3", reps: "8", rest: "2 分钟"),
                PlanItem(name: "高位下拉", sets: "3", reps: "10", rest: "90 秒"),
                PlanItem(name: "哑铃二头弯举", sets: "3", reps: "12", rest: "60 秒"),
                PlanItem(name: "卷腹", sets: "3", reps: "15", rest: "45 秒")
            ]),
            PlanDay(title: "第 3 天", focus: "全身 · 腿为主", items: [
                PlanItem(name: "高脚杯深蹲", sets: "3", reps: "12", rest: "90 秒"),
                PlanItem(name: "哑铃上斜卧推", sets: "3", reps: "10", rest: "90 秒"),
                PlanItem(name: "坐姿绳索划船", sets: "3", reps: "12", rest: "90 秒"),
                PlanItem(name: "腿弯举", sets: "3", reps: "12", rest: "60 秒"),
                PlanItem(name: "死虫", sets: "3", reps: "12/侧", rest: "45 秒")
            ])
        ]
    ),

    PlanTemplate(
        name: "核心特训",
        tag: "15 分钟",
        level: "初中级",
        daysPerWeek: 3,
        cycle: "8 周一轮",
        summary: "专攻腹部的三练分化：A 日上腹、B 日下腹、C 日侧腹。每次 4 个动作、15 分钟能收工，隔天练一次。腹肌需要的是张力不是次数，所以宁慢不多。",
        progression: "第 1–2 周每个动作 2 组；第 3–4 周加到 3 组；第 5 周起改成慢速离心（下落 3 秒）或加负重。组间不躺着，站着自己调呼吸。",
        days: [
            PlanDay(title: "A 日 · 上腹", focus: "腹直肌上段 / 屈曲", items: [
                PlanItem(name: "卷腹", sets: "3", reps: "15–20", rest: "45 秒"),
                PlanItem(name: "空中蹬自行车", sets: "3", reps: "每侧 15", rest: "45 秒"),
                PlanItem(name: "触踝卷腹", sets: "2", reps: "每侧 20", rest: "30 秒"),
                PlanItem(name: "平板支撑", sets: "3", reps: "45–60 秒", rest: "45 秒")
            ]),
            PlanDay(title: "B 日 · 下腹", focus: "腹直肌下段 / 骨盆后倾", items: [
                PlanItem(name: "反向卷腹", sets: "3", reps: "15", rest: "45 秒"),
                PlanItem(name: "仰卧举腿", sets: "3", reps: "12–15", rest: "45 秒"),
                PlanItem(name: "剪刀腿", sets: "3", reps: "30 秒", rest: "40 秒"),
                PlanItem(name: "死虫", sets: "2", reps: "每侧 12", rest: "40 秒")
            ]),
            PlanDay(title: "C 日 · 侧腹", focus: "腹斜肌 / 抗旋转", items: [
                PlanItem(name: "俄罗斯转体", sets: "3", reps: "20", rest: "45 秒"),
                PlanItem(name: "负重侧屈", sets: "3", reps: "每侧 15", rest: "40 秒"),
                PlanItem(name: "侧平板", sets: "3", reps: "每侧 40 秒", rest: "40 秒"),
                PlanItem(name: "登山跑", sets: "3", reps: "30 秒", rest: "45 秒")
            ])
        ]
    )
]

/// 在抖音搜索该动作教学
func moveSearchURL(_ name: String) -> String {
    let q = (name + " 教学").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
    return "https://www.douyin.com/search/\(q)"
}
