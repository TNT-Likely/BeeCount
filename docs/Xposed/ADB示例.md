# 🐝 BeeCount 自动化记账 API 测试指南

## 1. 核心配置
- **广播 Action**: `com.tntlikely.beecount.AUTO_BILLING`
- **目标包名**: `com.tntlikely.beecount.dev.debug`

## 2. 参数说明
- `amount`: 金额 (支持 "1,234.56")
- `account`: 账户名 (需与 App 内一致)
- `type`: 0 为支出, 1 为收入
- `remark`: 备注 (可选)

---

## 3. 支付宝测试 (Alipay)

### 🔴 支出
adb shell am broadcast -a com.tntlikely.beecount.AUTO_BILLING -p com.tntlikely.beecount.dev.debug --es amount "12.80" --es account "支付宝" --ei type 0 --es remark "便利店消费"

### 🔵 收入
adb shell am broadcast -a com.tntlikely.beecount.AUTO_BILLING -p com.tntlikely.beecount.dev.debug --es amount "100.00" --es account "支付宝" --ei type 1 --es remark "余额宝收益"

---

## 4. 微信测试 (WeChat)

### 🔴 支出
adb shell am broadcast -a com.tntlikely.beecount.AUTO_BILLING -p com.tntlikely.beecount.dev.debug --es amount "8.50" --es account "微信" --ei type 0 --es remark "早饭包子"

### 🔵 收入
adb shell am broadcast -a com.tntlikely.beecount.AUTO_BILLING -p com.tntlikely.beecount.dev.debug --es amount "88.88" --es account "微信" --ei type 1 --es remark "收到红包"

---

## 5. 现金测试 (Cash)

### 🔴 支出
adb shell am broadcast -a com.tntlikely.beecount.AUTO_BILLING -p com.tntlikely.beecount.dev.debug --es amount "10.00" --es account "现金" --ei type 0 --es remark "打车零钱"

### 🔵 收入
adb shell am broadcast -a com.tntlikely.beecount.AUTO_BILLING -p com.tntlikely.beecount.dev.debug --es amount "50.00" --es account "现金" --ei type 1 --es remark "捡到钱了"

## 运行效果演示

以下是功能实现的实际运行截图：

### 运行效果演示

| 1. 支付宝收入测试 | 2. 支付宝支出测试 |
| :---: | :---: |
| ![记账结果](./docs/Xposed/示例3.jpg) | ![记账结果](./docs/Xposed/示例3.jpg) |

### 3. 手机端最终入账展示
![记账结果](./docs/Xposed/示例3.jpg)