#!/usr/bin/env bash
# 一键生成 Android 发布 keystore，并写入 android/key.properties
# 适用于 macOS/Linux。需要已安装 Java（包含 keytool）。
# 用法：
#   ./tool/generate_android_keystore.sh \
#       -o android/app/release.keystore \
#       -a my-key-alias \
#       -p my-store-pass \
#       -k my-key-pass \
#       -d "CN=Your Name, OU=Dev, O=Company, L=City, S=State, C=CN" \
#       -v 3650
# 参数留空时会交互式提示，并提供默认值。

set -euo pipefail

KEystore_OUT=""
ALIAS=""
STORE_PASS=""
KEY_PASS=""
DNAME="CN=Unknown, OU=Dev, O=Org, L=City, S=State, C=US"
VALIDITY="3650"

while getopts "o:a:p:k:d:v:" opt; do
  case $opt in
    o) KEystore_OUT="$OPTARG" ;;
    a) ALIAS="$OPTARG" ;;
    p) STORE_PASS="$OPTARG" ;;
    k) KEY_PASS="$OPTARG" ;;
    d) DNAME="$OPTARG" ;;
    v) VALIDITY="$OPTARG" ;;
    *) echo "用法见脚本头部注释"; exit 2 ;;
  esac
done

# 交互式补全
if [[ -z "${KEystore_OUT}" ]]; then
  read -r -p "输出 keystore 路径 [android/app/release.keystore]: " KEystore_OUT
  KEystore_OUT=${KEystore_OUT:-android/app/release.keystore}
fi
mkdir -p "$(dirname "${KEystore_OUT}")"

# 若目标 keystore 已存在，提示是否覆盖
if [[ -f "${KEystore_OUT}" ]]; then
  echo "检测到已存在 keystore: ${KEystore_OUT}"
  read -r -p "是否覆盖该文件? (y/N): " OVERWRITE
  OVERWRITE=${OVERWRITE:-N}
  if [[ ! ${OVERWRITE} =~ ^[Yy]$ ]]; then
    echo "已取消。请使用 -o 指定一个新的输出路径，或删除现有文件后重试。"
    exit 1
  fi
  rm -f "${KEystore_OUT}"
fi

if [[ -z "${ALIAS}" ]]; then
  read -r -p "Key Alias [release]: " ALIAS
  ALIAS=${ALIAS:-release}
fi

if [[ -z "${STORE_PASS}" ]]; then
  read -r -s -p "Keystore 密码 [默认随机生成]: " STORE_PASS
  echo
  if [[ -z "${STORE_PASS}" ]]; then
    STORE_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
    echo "已生成随机 Keystore 密码: ${STORE_PASS}"
  fi
fi

if [[ -z "${KEY_PASS}" ]]; then
  read -r -s -p "Key 密码 (回车同 Keystore 密码): " KEY_PASS
  echo
  KEY_PASS=${KEY_PASS:-$STORE_PASS}
fi

if ! command -v keytool >/dev/null 2>&1; then
  echo "未找到 keytool，请确认已安装 Java JDK 并在 PATH 中。" >&2
  exit 1
fi

# 生成 keystore（JDK 17+ 使用 -genkeypair）
set +e
keytool -genkeypair -noprompt \
  -alias "${ALIAS}" \
  -keystore "${KEystore_OUT}" \
  -storepass "${STORE_PASS}" \
  -keypass "${KEY_PASS}" \
  -dname "${DNAME}" \
  -validity "${VALIDITY}" \
  -keyalg RSA -keysize 2048
KT_RC=$?
set -e
if [[ $KT_RC -ne 0 ]]; then
  echo "keytool 生成 keystore 失败，常见原因：" >&2
  echo "  1) 目标文件已存在且密码不匹配（已在本脚本中加入覆盖提示）" >&2
  echo "  2) Java JDK 版本/环境异常" >&2
  echo "  3) DName 格式不正确" >&2
  exit $KT_RC
fi

echo "已生成 keystore: ${KEystore_OUT}"

# 写入 android/key.properties（位置固定在 android/），但 storeFile 需相对于 android/app
KEYPROPS_DIR="$(cd "$(dirname "${KEystore_OUT}")"/.. && pwd)" # android/
KEYPROPS_APP_DIR="${KEYPROPS_DIR}/app"                         # android/app
KEYPROPS_FILE="${KEYPROPS_DIR}/key.properties"

# 计算 storeFile 相对于 android/app 目录的路径（Gradle 中 file() 相对 app 模块解析）
STORE_REL="$(python3 - <<'PY'
import os,sys
kp = os.path.abspath(sys.argv[1])
app_dir = os.path.abspath(sys.argv[2])
print(os.path.relpath(kp, app_dir).replace('\\\\','/'))
PY
"${KEystore_OUT}" "${KEYPROPS_APP_DIR}")"

cat > "${KEYPROPS_FILE}" <<EOF
storeFile=${STORE_REL}
storePassword=${STORE_PASS}
keyAlias=${ALIAS}
keyPassword=${KEY_PASS}
EOF

echo "已写入 ${KEYPROPS_FILE}:"
cat "${KEYPROPS_FILE}"
