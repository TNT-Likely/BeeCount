#!/bin/bash
# 生成 BeeCount 测试账本数据（中英文各一份，1万条，2015-09~2025-09，涵盖所有分类，10%有备注）

set -e

# 中文表头和分类
ZH_HEADER="日期,类型,金额,分类,备注"
ZH_CATEGORIES=(
  "餐饮" "交通" "购物" "娱乐" "居家" "家庭" "通讯" "水电" "住房" "医疗" "教育" "宠物" "运动" "数码" "旅行" "烟酒" "母婴" "美容" "维修" "社交" "学习" "汽车" "打车" "地铁" "外卖" "物业" "停车" "捐赠" "礼金" "纳税" "饮料" "服装" "零食" "红包" "水果" "游戏" "书" "爱人" "装修" "日用品" "彩票" "股票" "社保" "快递" "工作" "工资" "理财" "奖金" "报销" "兼职" "利息" "退款" "二手转卖" "社会保障" "退税退费" "公积金"
)

# 英文表头和分类
EN_HEADER="Date,Type,Amount,Category,Note"
EN_CATEGORIES=(
  "Dining" "Transport" "Shopping" "Entertainment" "Home" "Family" "Communication" "Utilities" "Housing" "Medical" "Education" "Pets" "Sports" "Digital" "Travel" "Alcohol & Tobacco" "Baby Care" "Beauty" "Repair" "Social" "Learning" "Car" "Taxi" "Subway" "Delivery" "Property" "Parking" "Donation" "Gift" "Tax" "Beverage" "Clothing" "Snacks" "Red Packet" "Fruit" "Game" "Book" "Lover" "Decoration" "Daily Goods" "Lottery" "Stock" "Social Security" "Express" "Work" "Salary" "Investment" "Bonus" "Reimbursement" "Part-time" "Interest" "Refund" "Second-hand Sale" "Social Benefit" "Tax Refund" "Provident Fund"
)

TYPES=("收入" "支出")
EN_TYPES=("Income" "Expense")

ZH_FILE="demo_ledger_zh.csv"
EN_FILE="demo_ledger_en.csv"

# 备注样例
NOTES=("" "早餐" "午餐" "晚餐" "交通费" "购物优惠" "家庭聚会" "年度体检" "宠物疫苗" "运动健身" "旅游计划" "生日礼物" "房租" "水电费" "学习资料" "加班补贴" "兼职收入" "股票分红" "彩票中奖" "快递费" "装修进度" "理财收益" "报销成功" "退款到账" "二手转卖" "社保缴纳" "公积金到账" "年度奖金" "节日红包" "饮料零食" "美容护肤" "母婴用品" "数码产品" "汽车保养" "停车费" "物业费" "外卖点餐" "打车出行" "地铁通勤" "烟酒消费" "捐赠公益" "纳税" "服装鞋帽" "水果采购" "游戏充值" "书籍购买" "爱人礼物" "家庭装修" "日用品采购" "彩票投注" "投资理财" "社交聚会" "学习进修" "维修服务" "奖金发放" "工资收入" "工作补贴" "通讯费" "医疗报销" "教育支出" "宠物护理" "娱乐消费" "购物返现" "家庭支出" "居家用品" "交通补贴" "餐饮消费" "年度总结" "年度计划" "年度目标" "年度预算" "年度支出" "年度收入" "年度结余" "年度分析" "年度报告" "年度账单" "年度统计" "年度对账" "年度清算" "年度结算" "年度核算" "年度审计" "年度评估" "年度考核" "年度总结报告" "年度计划书" "年度目标书" "年度预算表" "年度支出表" "年度收入表" "年度结余表" "年度分析表" "年度报告表" "年度账单表" "年度统计表" "年度对账表" "年度清算表" "年度结算表" "年度核算表" "年度审计表" "年度评估表" "年度考核表")
EN_NOTES=("" "Breakfast" "Lunch" "Dinner" "Transport fee" "Shopping discount" "Family gathering" "Annual checkup" "Pet vaccine" "Fitness" "Travel plan" "Birthday gift" "Rent" "Utilities" "Study material" "Overtime bonus" "Part-time income" "Stock dividend" "Lottery win" "Express fee" "Decoration progress" "Investment return" "Reimbursement success" "Refund received" "Second-hand sale" "Social security paid" "Provident fund received" "Annual bonus" "Festival red packet" "Drinks & snacks" "Beauty care" "Baby products" "Digital product" "Car maintenance" "Parking fee" "Property fee" "Food delivery" "Taxi ride" "Subway commute" "Alcohol & tobacco" "Donation" "Tax payment" "Clothing" "Fruit purchase" "Game recharge" "Book purchase" "Gift for lover" "Home decoration" "Daily goods" "Lottery ticket" "Investment" "Social event" "Learning" "Repair service" "Bonus issued" "Salary income" "Work subsidy" "Communication fee" "Medical reimbursement" "Education expense" "Pet care" "Entertainment" "Shopping cashback" "Family expense" "Home goods" "Transport subsidy" "Dining expense" "Annual summary" "Annual plan" "Annual goal" "Annual budget" "Annual expense" "Annual income" "Annual balance" "Annual analysis" "Annual report" "Annual bill" "Annual statistics" "Annual reconciliation" "Annual clearing" "Annual settlement" "Annual accounting" "Annual audit" "Annual evaluation" "Annual assessment" "Annual summary report" "Annual plan book" "Annual goal book" "Annual budget sheet" "Annual expense sheet" "Annual income sheet" "Annual balance sheet" "Annual analysis sheet" "Annual report sheet" "Annual bill sheet" "Annual statistics sheet" "Annual reconciliation sheet" "Annual clearing sheet" "Annual settlement sheet" "Annual accounting sheet" "Annual audit sheet" "Annual evaluation sheet" "Annual assessment sheet")

# 生成函数
gen_csv() {
  local header="$1"
  local categories=(${!2})
  local types=(${!3})
  local notes=(${!4})
  local file="$5"

  echo "$header" > "$file"
  local total=10000
  local start_year=2015
  local end_year=2025
  local years=$((end_year - start_year + 1))
  local per_year=$((total / years))
  local idx=0
  local progress=0
  local salary_base=5000
  local salary_growth=400 # 每年工资涨幅
  for ((y=start_year; y<=end_year; y++)); do
    local salary=$((salary_base + (y-start_year)*salary_growth))
    for ((i=0; i<per_year; i++)); do
      # 随机日期+时分秒
      month=$((1 + RANDOM % 12))
      day=$((1 + RANDOM % 28))
      hour=$((RANDOM % 24))
      min=$((RANDOM % 60))
      sec=$((RANDOM % 60))
      date=$(printf "%04d-%02d-%02d %02d:%02d:%02d" "$y" "$month" "$day" "$hour" "$min" "$sec")
      # 收入/支出逻辑
      if ((RANDOM % 2 == 0)); then
        # 支出
        type="${types[1]}"
        # 支出金额更小，增加扰动避免批量一致
  rand_seed=$(( (i+1)*(y+1)*RANDOM + idx*3 + 10#$(date +%s%N | cut -b10-13) ))
        amount=$(awk -v min=5 -v max=800 -v seed=$rand_seed 'BEGIN{srand(seed); printf "%.2f", min+rand()*(max-min)}')
        c_idx=$((RANDOM % ${#categories[@]}))
        category="${categories[$c_idx]}"
        while [[ "$category" =~ (工资|奖金|兼职|利息|报销|红包|礼金|投资|理财|股票|二手转卖|社会保障|退税退费|公积金|工作|Salary|Bonus|Part-time|Interest|Reimbursement|Red Packet|Gift|Investment|Stock|Second-hand Sale|Social Benefit|Tax Refund|Provident Fund|Work) ]]; do
          c_idx=$((RANDOM % ${#categories[@]}))
          category="${categories[$c_idx]}"
        done
      else
        # 收入
        type="${types[0]}"
        if ((i % 30 == 0)); then
          # 工资
          rand_seed=$(( (i+1)*(y+1)*RANDOM + idx*7 + 10#$(date +%s%N | cut -b10-13) ))
          salary_noise=$(awk -v min=-100 -v max=100 -v seed=$rand_seed 'BEGIN{srand(seed); printf "%d", min+rand()*(max-min)}')
          amount=$((salary + salary_noise)).00
          for ci in "${!categories[@]}"; do
            if [[ "${categories[$ci]}" =~ (工资|Salary) ]]; then
              category="${categories[$ci]}"
              break
            fi
          done
        else
          # 其他收入
          rand_seed=$(( (i+1)*(y+1)*RANDOM + idx*11 + 10#$(date +%s%N | cut -b10-13) ))
          amount=$(awk -v min=10 -v max=500 -v seed=$rand_seed 'BEGIN{srand(seed); printf "%.2f", min+rand()*(max-min)}')
          income_cats=("工资" "奖金" "兼职" "利息" "报销" "红包" "礼金" "投资" "理财" "股票" "二手转卖" "社会保障" "退税退费" "公积金" "工作" "Salary" "Bonus" "Part-time" "Interest" "Reimbursement" "Red Packet" "Gift" "Investment" "Stock" "Second-hand Sale" "Social Benefit" "Tax Refund" "Provident Fund" "Work")
          while :; do
            c_idx=$((RANDOM % ${#categories[@]}))
            category="${categories[$c_idx]}"
            for incat in "${income_cats[@]}"; do
              if [[ "$category" == "$incat" ]]; then
                break 2
              fi
            done
          done
        fi
      fi
      # 10%有备注
      if ((RANDOM % 10 == 0)); then
        n_idx=$((RANDOM % ${#notes[@]}))
        note="${notes[$n_idx]}"
      else
        note=""
      fi
      echo "$date,$type,$amount,$category,$note" >> "$file"
      idx=$((idx+1))
      # 进度显示
      if ((idx % 500 == 0)); then
        progress=$((100*idx/total))
        echo -ne "\r生成进度: $idx/$total ($progress%)"
      fi
    done
  done
  # 补齐不足的条数
  while ((idx < total)); do
    y=$((start_year + RANDOM % years))
    month=$((1 + RANDOM % 12))
    day=$((1 + RANDOM % 28))
    hour=$((RANDOM % 24))
    min=$((RANDOM % 60))
    sec=$((RANDOM % 60))
    date=$(printf "%04d-%02d-%02d %02d:%02d:%02d" "$y" "$month" "$day" "$hour" "$min" "$sec")
    if ((RANDOM % 2 == 0)); then
      type="${types[1]}"
    rand_seed=$(( (idx+1)*(y+1)*RANDOM + idx*13 + 10#$(date +%s%N | cut -b10-13) ))
      amount=$(awk -v min=5 -v max=800 -v seed=$rand_seed 'BEGIN{srand(seed); printf "%.2f", min+rand()*(max-min)}')
      c_idx=$((RANDOM % ${#categories[@]}))
      category="${categories[$c_idx]}"
      while [[ "$category" =~ (工资|奖金|兼职|利息|报销|红包|礼金|投资|理财|股票|二手转卖|社会保障|退税退费|公积金|工作|Salary|Bonus|Part-time|Interest|Reimbursement|Red Packet|Gift|Investment|Stock|Second-hand Sale|Social Benefit|Tax Refund|Provident Fund|Work) ]]; do
        c_idx=$((RANDOM % ${#categories[@]}))
        category="${categories[$c_idx]}"
      done
    else
      type="${types[0]}"
      if ((idx % 30 == 0)); then
        salary=$((salary_base + (y-start_year)*salary_growth))
  rand_seed=$(( (idx+1)*(y+1)*RANDOM + idx*17 + 10#$(date +%s%N | cut -b10-13) ))
        salary_noise=$(awk -v min=-100 -v max=100 -v seed=$rand_seed 'BEGIN{srand(seed); printf "%d", min+rand()*(max-min)}')
        amount=$((salary + salary_noise)).00
        for ci in "${!categories[@]}"; do
          if [[ "${categories[$ci]}" =~ (工资|Salary) ]]; then
            category="${categories[$ci]}"
            break
          fi
        done
      else
  rand_seed=$(( (idx+1)*(y+1)*RANDOM + idx*19 + 10#$(date +%s%N | cut -b10-13) ))
        amount=$(awk -v min=10 -v max=500 -v seed=$rand_seed 'BEGIN{srand(seed); printf "%.2f", min+rand()*(max-min)}')
        income_cats=("工资" "奖金" "兼职" "利息" "报销" "红包" "礼金" "投资" "理财" "股票" "二手转卖" "社会保障" "退税退费" "公积金" "工作" "Salary" "Bonus" "Part-time" "Interest" "Reimbursement" "Red Packet" "Gift" "Investment" "Stock" "Second-hand Sale" "Social Benefit" "Tax Refund" "Provident Fund" "Work")
        while :; do
          c_idx=$((RANDOM % ${#categories[@]}))
          category="${categories[$c_idx]}"
          for incat in "${income_cats[@]}"; do
            if [[ "$category" == "$incat" ]]; then
              break 2
            fi
          done
        done
      fi
    fi
    if ((RANDOM % 10 == 0)); then
      n_idx=$((RANDOM % ${#notes[@]}))
      note="${notes[$n_idx]}"
    else
      note=""
    fi
    echo "$date,$type,$amount,$category,$note" >> "$file"
    idx=$((idx+1))
    if ((idx % 500 == 0)); then
      progress=$((100*idx/total))
      echo -ne "\r生成进度: $idx/$total ($progress%)"
    fi
  done
  echo -e "\r生成进度: $total/$total (100%)"
}

# 生成中文账本
gen_csv "$ZH_HEADER" ZH_CATEGORIES[@] TYPES[@] NOTES[@] "$ZH_FILE"
# 生成英文账本
gen_csv "$EN_HEADER" EN_CATEGORIES[@] EN_TYPES[@] EN_NOTES[@] "$EN_FILE"

echo "生成完成：$ZH_FILE, $EN_FILE"
