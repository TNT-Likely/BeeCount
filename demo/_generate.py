#!/usr/bin/env python3
"""生成 BeeCount 测试数据集(中英文双语)。

包含:
  - store_setup_{zh,en}.yaml  — 账户 + 一级/二级分类 + 标签 配置
  - store_test_{zh,en}.csv    — 指定条数的交易数据

用法:
  python3 _generate.py --count 100   --out 100-records
  python3 _generate.py --count 10000 --out 10000-records

固定 seed = 20260524,重跑结果一致。
"""

import argparse
import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

SEED = 20260524

# ====================== 账户 ======================
ACCOUNTS_ZH = [
    ("招商信用卡", "credit_card"),
    ("微信", "cash"),
    ("支付宝", "cash"),
    ("工商银行卡", "bank_card"),
    ("现金", "cash"),
]
ACCOUNTS_EN = [
    ("Chase Credit", "credit_card"),
    ("Apple Pay", "cash"),
    ("PayPal", "cash"),
    ("BoA Checking", "bank_card"),
    ("Cash", "cash"),
]

# ====================== 一级分类(支出)====================
# (zh_name, en_name, icon)
EXPENSE_L1 = [
    ("餐饮", "Dining", "restaurant"),
    ("交通", "Transport", "directions_car"),
    ("购物", "Shopping", "shopping_cart"),
    ("娱乐", "Entertainment", "movie"),
    ("居家", "Home", "home"),
    ("家庭", "Family", "family_restroom"),
    ("通讯", "Communication", "phone"),
    ("水电", "Utilities", "flash_on"),
    ("住房", "Housing", "home_work"),
    ("医疗", "Medical", "local_hospital"),
    ("教育", "Education", "school"),
    ("宠物", "Pets", "pets"),
    ("运动", "Sports", "fitness_center"),
    ("数码", "Digital", "smartphone"),
    ("旅行", "Travel", "flight"),
    ("烟酒", "Alcohol & Tobacco", "local_bar"),
    ("母婴", "Baby Care", "child_care"),
    ("美容", "Beauty", "face"),
    ("维修", "Repair", "handyman"),
    ("社交", "Social", "group"),
    ("学习", "Learning", "school"),
    ("汽车", "Car", "directions_car"),
    ("打车", "Taxi", "local_taxi"),
    ("地铁", "Subway", "directions_subway"),
    ("外卖", "Delivery", "delivery_dining"),
    ("物业", "Property", "apartment"),
    ("停车", "Parking", "local_parking"),
    ("捐赠", "Donation", "volunteer_activism"),
    ("送礼", "Give Gift", "card_giftcard"),
    ("纳税", "Tax", "receipt_long"),
    ("饮料", "Beverage", "local_cafe"),
    ("服装", "Clothing", "checkroom"),
    ("零食", "Snacks", "fastfood"),
    ("发红包", "Send Red Packet", "wallet"),
    ("水果", "Fruit", "eco"),
    ("游戏", "Game", "sports_esports"),
    ("书", "Book", "menu_book"),
    ("爱人", "Lover", "favorite"),
    ("装修", "Decoration", "home_repair_service"),
    ("日用品", "Daily Goods", "local_laundry_service"),
    ("彩票", "Lottery", "confirmation_number"),
    ("股票", "Stock", "trending_up"),
    ("社保", "Social Security", "security"),
    ("快递", "Express", "local_shipping"),
    ("工作", "Work", "work_outline"),
]

# ====================== 二级分类(支出)====================
# parent_zh -> [(zh, en, icon)]
EXPENSE_L2 = {
    "餐饮": [
        ("早餐", "Breakfast", "free_breakfast"),
        ("午餐", "Lunch", "lunch_dining"),
        ("晚餐", "Dinner", "dinner_dining"),
        ("夜宵", "Late Night", "nightlife"),
    ],
    "交通": [
        ("公交", "Bus", "directions_bus"),
        ("高铁", "Train", "train"),
        ("长途车", "Coach", "airport_shuttle"),
    ],
    "购物": [
        ("鞋子", "Shoes", "ice_skating"),
        ("家具", "Furniture", "chair"),
        ("家电", "Appliances", "kitchen"),
    ],
    "娱乐": [
        ("电影", "Movie", "theaters"),
        ("KTV", "KTV", "mic"),
        ("演唱会", "Concert", "music_note"),
    ],
    "医疗": [
        ("门诊", "Outpatient", "medical_services"),
        ("药品", "Medicine", "medication"),
        ("体检", "Checkup", "monitor_heart"),
    ],
    "教育": [
        ("培训", "Training", "model_training"),
        ("在线课程", "Online Course", "ondemand_video"),
        ("教材", "Textbook", "auto_stories"),
    ],
    "旅行": [
        ("机票", "Flight", "flight_takeoff"),
        ("酒店", "Hotel", "hotel"),
        ("门票", "Ticket", "confirmation_number"),
    ],
    "数码": [
        ("配件", "Accessories", "cable"),
        ("手机", "Phone", "phone_iphone"),
        ("电脑", "Computer", "laptop"),
    ],
}

# ====================== 一级分类(收入)====================
INCOME_L1 = [
    ("工资", "Salary", "work"),
    ("理财", "Investment", "account_balance"),
    ("收红包", "Receive Red Packet", "wallet"),
    ("奖金", "Bonus", "emoji_events"),
    ("报销", "Reimbursement", "receipt"),
    ("兼职", "Part-time", "schedule"),
    ("收礼", "Receive Gift", "card_giftcard"),
    ("利息", "Interest", "monetization_on"),
    ("退款", "Refund", "undo"),
    ("投资收益", "Investment Income", "trending_up"),
    ("二手转卖", "Second-hand", "sell"),
    ("社会保障", "Social Benefit", "health_and_safety"),
    ("退税退费", "Tax Refund", "receipt_long"),
    ("公积金", "Provident Fund", "account_balance_wallet"),
]

# ====================== 二级分类(收入)====================
INCOME_L2 = {
    "工资": [
        ("基本工资", "Base Salary", "payments"),
        ("加班费", "Overtime", "more_time"),
    ],
    "投资收益": [
        ("股息", "Dividend", "savings"),
        ("基金分红", "Fund Distribution", "pie_chart"),
    ],
}

# ====================== 账本 ======================
# CSV 数据都导入到"默认账本",其它账本是空账本用于测试 UI / 多账本切换
LEDGERS_ZH = [
    ("默认账本", "personal"),
    ("差旅报销", "personal"),
    ("家庭账本", "shared"),
]
LEDGERS_EN = [
    ("Default", "personal"),
    ("Business Travel", "personal"),
    ("Family", "shared"),
]

# ====================== 预算 ======================
# (ledger_idx, type, parent_zh_or_None, amount_zh, amount_en, start_day)
# type='total':总预算;type='category':分类预算(parent_zh 是分类名)
# amount_zh 是 CNY,amount_en 是 USD(粗略 1:7 换算)
BUDGETS = [
    # 总预算
    (0, "total", None, 8000.0, 1500.0, 1),
    (1, "total", None, 3000.0, 500.0, 1),
    # 默认账本下的分类预算
    (0, "category", "餐饮", 1500.0, 300.0, 1),
    (0, "category", "购物", 1200.0, 250.0, 1),
    (0, "category", "交通", 600.0, 120.0, 1),
    (0, "category", "娱乐", 500.0, 100.0, 1),
    (0, "category", "水电", 400.0, 80.0, 1),
    (0, "category", "通讯", 200.0, 40.0, 1),
    (0, "category", "外卖", 800.0, 150.0, 1),
    (0, "category", "饮料", 200.0, 40.0, 1),
]
CATEGORY_ZH_TO_EN = {item[0]: item[1] for item in EXPENSE_L1 + INCOME_L1}

# ====================== 标签 ======================
TAGS = [
    # (zh, en, color)
    ("美团", "Meituan", "#FF5722"),
    ("饿了么", "Eleme", "#2196F3"),
    ("淘宝", "Taobao", "#FF9800"),
    ("京东", "JD.com", "#F44336"),
    ("拼多多", "Pinduoduo", "#E91E63"),
    ("星巴克", "Starbucks", "#009688"),
    ("瑞幸咖啡", "Luckin Coffee", "#795548"),
    ("麦当劳", "McDonald's", "#FFC107"),
    ("肯德基", "KFC", "#D32F2F"),
    ("盒马", "Hema", "#00BCD4"),
    ("山姆", "Sam's Club", "#3F51B5"),
    ("Costco", "Costco", "#673AB7"),
    ("出差", "Business Trip", "#607D8B"),
    ("旅行", "Travel", "#00E676"),
    ("聚餐", "Dining Out", "#FF4081"),
    ("网购", "Online Shopping", "#536DFE"),
    ("日常", "Daily", "#8BC34A"),
    ("报销", "Reimbursement", "#9C27B0"),
    ("可退款", "Refundable", "#CDDC39"),
    ("已退款", "Refunded", "#4CAF50"),
    ("语音记账", "Voice", "#FF9800"),
    ("图片记账", "Image", "#4CAF50"),
    ("拍照记账", "Photo", "#2196F3"),
    ("AI记账", "AI", "#9C27B0"),
]

# ====================== 常用备注 ======================
EXPENSE_NOTES_ZH = [
    "", "", "", "", "",  # 50% 空
    "午餐", "晚餐", "早餐", "夜宵", "外卖", "聚餐",
    "公交", "地铁", "打车回家", "高铁票", "机票",
    "充值", "续费", "月卡", "年费",
    "理发", "美甲", "护肤品", "化妆品",
    "燃气费", "电费", "水费", "网费",
    "网购", "代购", "海淘", "礼物",
    "看病", "买药", "体检", "牙医",
    "学费", "培训", "买书", "课程",
    "宠物粮", "猫砂", "宠物医院",
]
EXPENSE_NOTES_EN = [
    "", "", "", "", "",
    "Lunch", "Dinner", "Breakfast", "Late night", "Takeout", "Group meal",
    "Bus", "Subway", "Taxi home", "Train ticket", "Flight",
    "Top-up", "Renewal", "Monthly pass", "Annual fee",
    "Haircut", "Manicure", "Skincare", "Makeup",
    "Gas bill", "Electricity", "Water", "Internet",
    "Online shopping", "Daigou", "Overseas", "Gift",
    "Doctor", "Medicine", "Health check", "Dentist",
    "Tuition", "Training", "Books", "Course",
    "Pet food", "Litter", "Vet",
]
INCOME_NOTES_ZH = [
    "", "", "", "",
    "月薪", "年终奖", "项目奖金", "绩效奖",
    "理财收益", "基金分红", "股息",
    "退款", "返现",
    "兼职", "外快",
    "公积金提取", "社保返还",
]
INCOME_NOTES_EN = [
    "", "", "", "",
    "Monthly salary", "Year-end bonus", "Project bonus", "Performance bonus",
    "Investment yield", "Fund dividend", "Stock dividend",
    "Refund", "Cashback",
    "Side gig", "Extra income",
    "Provident fund", "Social security",
]


# ====================== yaml 生成 ======================
def build_yaml(lang: str, exported_at: str) -> str:
    """生成 store_setup_{lang}.yaml 字符串。"""
    accounts = ACCOUNTS_ZH if lang == "zh" else ACCOUNTS_EN
    currency = "CNY" if lang == "zh" else "USD"
    lang_label = "简体中文 / CNY" if lang == "zh" else "English / USD"
    idx_lang = 0 if lang == "zh" else 1

    lines = []
    lines.append("# BeeCount 配置（测试 / 截图用）")
    lines.append(f"# 语言 / 货币：{lang_label}")
    lines.append(f"# 导出时间：{exported_at}")
    lines.append("")
    lines.append("version: 1")
    lines.append(f'exported_at: "{exported_at}"')
    lines.append("")

    # 账本
    ledgers = LEDGERS_ZH if lang == "zh" else LEDGERS_EN
    lines.append(f"# ----- 账本({len(ledgers)} 个,第一本是默认账本,CSV 数据导入到它)-----")
    lines.append("ledgers:")
    lines.append("  items:")
    for name, ledger_type in ledgers:
        lines.append(f'    - name: "{name}"')
        lines.append(f'      currency: "{currency}"')
        lines.append(f'      type: "{ledger_type}"')
    lines.append("")

    # 账户
    lines.append(f"# ----- 账户({len(accounts)} 个)-----")
    lines.append("accounts:")
    lines.append("  items:")
    for name, acc_type in accounts:
        lines.append(f'    - name: "{name}"')
        lines.append(f'      type: "{acc_type}"')
        lines.append(f'      currency: "{currency}"')
        lines.append("      initial_balance: 0.0")
    lines.append("")

    # 一级 + 二级分类
    expense_l2_count = sum(len(v) for v in EXPENSE_L2.values())
    income_l2_count = sum(len(v) for v in INCOME_L2.values())
    lines.append(
        f"# ----- 分类({len(EXPENSE_L1)} 支出一级 + {expense_l2_count} 支出二级 "
        f"+ {len(INCOME_L1)} 收入一级 + {income_l2_count} 收入二级)-----"
    )
    lines.append("categories:")
    lines.append("  items:")
    # 支出一级
    for i, item in enumerate(EXPENSE_L1):
        name = item[idx_lang]
        icon = item[2]
        lines.append(f'    - name: "{name}"')
        lines.append('      kind: "expense"')
        lines.append(f"      sort_order: {i}")
        lines.append("      level: 1")
        lines.append(f'      icon: "{icon}"')
        lines.append('      icon_type: "material"')
    # 支出二级
    sub_idx = 0
    for parent_zh, subs in EXPENSE_L2.items():
        parent_idx = next(
            i for i, item in enumerate(EXPENSE_L1) if item[0] == parent_zh
        )
        parent_name = EXPENSE_L1[parent_idx][idx_lang]
        for sub in subs:
            sub_name = sub[idx_lang]
            sub_icon = sub[2]
            lines.append(f'    - name: "{sub_name}"')
            lines.append('      kind: "expense"')
            lines.append(f"      sort_order: {sub_idx}")
            lines.append("      level: 2")
            lines.append(f'      parent_name: "{parent_name}"')
            lines.append(f'      icon: "{sub_icon}"')
            lines.append('      icon_type: "material"')
            sub_idx += 1
    # 收入一级
    for i, item in enumerate(INCOME_L1):
        name = item[idx_lang]
        icon = item[2]
        lines.append(f'    - name: "{name}"')
        lines.append('      kind: "income"')
        lines.append(f"      sort_order: {i}")
        lines.append("      level: 1")
        lines.append(f'      icon: "{icon}"')
        lines.append('      icon_type: "material"')
    # 收入二级
    sub_idx = 0
    for parent_zh, subs in INCOME_L2.items():
        parent_idx = next(
            i for i, item in enumerate(INCOME_L1) if item[0] == parent_zh
        )
        parent_name = INCOME_L1[parent_idx][idx_lang]
        for sub in subs:
            sub_name = sub[idx_lang]
            sub_icon = sub[2]
            lines.append(f'    - name: "{sub_name}"')
            lines.append('      kind: "income"')
            lines.append(f"      sort_order: {sub_idx}")
            lines.append("      level: 2")
            lines.append(f'      parent_name: "{parent_name}"')
            lines.append(f'      icon: "{sub_icon}"')
            lines.append('      icon_type: "material"')
            sub_idx += 1
    lines.append("")

    # 标签
    lines.append(f"# ----- 标签({len(TAGS)} 个,含 Material 调色板颜色)-----")
    lines.append("tags:")
    lines.append("  items:")
    for tag in TAGS:
        name = tag[idx_lang]
        color = tag[2]
        lines.append(f'    - name: "{name}"')
        lines.append(f'      color: "{color}"')
    lines.append("")

    # 预算
    total_count = sum(1 for b in BUDGETS if b[1] == "total")
    cat_count = sum(1 for b in BUDGETS if b[1] == "category")
    lines.append(
        f"# ----- 预算({total_count} 个总预算 + {cat_count} 个分类预算)-----"
    )
    lines.append("budgets:")
    lines.append("  items:")
    for ledger_idx, b_type, parent_zh, amount_zh, amount_en, start_day in BUDGETS:
        ledger_name = ledgers[ledger_idx][0]
        amount = amount_zh if lang == "zh" else amount_en
        lines.append(f'    - ledger_name: "{ledger_name}"')
        lines.append(f'      type: "{b_type}"')
        lines.append(f"      amount: {amount}")
        lines.append(f"      start_day: {start_day}")
        if b_type == "category" and parent_zh is not None:
            cat_name = parent_zh if lang == "zh" else CATEGORY_ZH_TO_EN[parent_zh]
            lines.append(f'      category_name: "{cat_name}"')

    return "\n".join(lines) + "\n"


# ====================== CSV 生成 ======================
def build_csv_rows(count: int, lang: str):
    """生成 count 行 CSV 数据。返回 (header, rows)。"""
    idx_lang = 0 if lang == "zh" else 1
    account_pairs = ACCOUNTS_ZH if lang == "zh" else ACCOUNTS_EN
    accounts = [a[0] for a in account_pairs]
    # 收入只落资产账户 —— 工资/股息打到信用卡会把负债账户余额顶成正数,污染净资产口径。
    asset_accounts = [a[0] for a in account_pairs if a[1] != "credit_card"]

    # 可选分类池(一级 + 二级 混合,30% 用二级)
    expense_l1_names = [c[idx_lang] for c in EXPENSE_L1]
    expense_l2_names = [
        sub[idx_lang] for subs in EXPENSE_L2.values() for sub in subs
    ]
    income_l1_names = [c[idx_lang] for c in INCOME_L1]
    income_l2_names = [
        sub[idx_lang] for subs in INCOME_L2.values() for sub in subs
    ]

    tags_pool = [t[idx_lang] for t in TAGS]
    expense_notes = EXPENSE_NOTES_ZH if lang == "zh" else EXPENSE_NOTES_EN
    income_notes = INCOME_NOTES_ZH if lang == "zh" else INCOME_NOTES_EN
    expense_label = "支出" if lang == "zh" else "Expense"
    income_label = "收入" if lang == "zh" else "Income"

    # 日期范围(均匀分布)。100 条压缩到 1 个月,1w 条铺到 2.5 年。
    if count <= 200:
        start = datetime(2026, 4, 1, 6, 0, 0)
        end = datetime(2026, 4, 30, 22, 0, 0)
    else:
        start = datetime(2024, 1, 1, 6, 0, 0)
        end = datetime(2026, 5, 23, 22, 0, 0)
    span = int((end - start).total_seconds())
    timestamps = sorted(
        [start + timedelta(seconds=random.randint(0, span)) for _ in range(count)],
        reverse=True,
    )

    income_count = max(1, count // 10)  # 10%
    flags = [True] * income_count + [False] * (count - income_count)
    random.shuffle(flags)

    rows = []
    for ts, is_income in zip(timestamps, flags):
        if is_income:
            type_label = income_label
            amount = round(random.uniform(1000, 15000), 2)
            # 25% 用二级分类(只有部分一级有二级)
            if income_l2_names and random.random() < 0.25:
                category = random.choice(income_l2_names)
            else:
                category = random.choice(income_l1_names)
            note = random.choice(income_notes)
            account = random.choice(asset_accounts)
        else:
            type_label = expense_label
            if random.random() < 0.8:
                amount = round(random.uniform(5, 300), 2)
            else:
                amount = round(random.uniform(300, 3000), 2)
            # 35% 用二级分类
            if random.random() < 0.35:
                category = random.choice(expense_l2_names)
            else:
                category = random.choice(expense_l1_names)
            note = random.choice(expense_notes)
            account = random.choice(accounts)

        # 30% 概率带 1-2 标签
        tags = ""
        if random.random() < 0.3:
            n = random.choice([1, 1, 1, 2])
            tags = ",".join(random.sample(tags_pool, n))

        rows.append([
            ts.strftime("%Y-%m-%d %H:%M:%S"),
            type_label,
            f"{amount:.2f}",
            category,
            note,
            tags,
            account,
        ])

    header_zh = ["日期", "类型", "金额", "分类", "备注", "标签", "账户"]
    header_en = ["Date", "Type", "Amount", "Category", "Note", "Tags", "Account"]
    return (header_zh if lang == "zh" else header_en), rows


# ====================== main ======================
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, required=True, help="生成的 CSV 行数")
    parser.add_argument("--out", type=str, required=True, help="输出目录(相对本脚本)")
    args = parser.parse_args()

    here = Path(__file__).resolve().parent
    out_dir = here / args.out
    out_dir.mkdir(parents=True, exist_ok=True)

    exported_at = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    expense_l2_count = sum(len(v) for v in EXPENSE_L2.values())
    income_l2_count = sum(len(v) for v in INCOME_L2.values())
    total_budget = sum(1 for b in BUDGETS if b[1] == "total")
    cat_budget = sum(1 for b in BUDGETS if b[1] == "category")
    print(f"Output directory: {out_dir}")
    print(
        f"Schema: {len(LEDGERS_ZH)} 账本 / {len(ACCOUNTS_ZH)} 账户 / "
        f"{len(EXPENSE_L1)}+{expense_l2_count} 支出(一级+二级) / "
        f"{len(INCOME_L1)}+{income_l2_count} 收入(一级+二级) / "
        f"{len(TAGS)} 标签 / {total_budget}+{cat_budget} 预算(总+分类)"
    )

    # 每次跑重置 seed,保证 yaml + 两个 CSV 的随机部分独立 + 可复现
    for lang in ("zh", "en"):
        yaml_path = out_dir / f"store_setup_{lang}.yaml"
        yaml_path.write_text(build_yaml(lang, exported_at), encoding="utf-8")
        size_kb = yaml_path.stat().st_size / 1024
        print(f"  ✓ {yaml_path.name}: {size_kb:.0f} KB")

    for lang in ("zh", "en"):
        random.seed(SEED)
        header, rows = build_csv_rows(args.count, lang)
        csv_path = out_dir / f"store_test_{lang}.csv"
        with csv_path.open("w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(header)
            w.writerows(rows)
        size_kb = csv_path.stat().st_size / 1024
        print(f"  ✓ {csv_path.name}: {args.count} 行, {size_kb:.0f} KB")


if __name__ == "__main__":
    main()
