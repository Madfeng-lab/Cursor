#!/bin/bash

set -e

echo "🚀 开始部署 Fitness App（规范版）..."

# =====================
# 统一目录结构
# =====================

APP_DIR="/app"
TOOLS_DIR="/opt/tools"
DATA_DIR="/data"
LOG_DIR="/var/log/fitness"

mkdir -p $APP_DIR
mkdir -p $TOOLS_DIR
mkdir -p $DATA_DIR/mysql
mkdir -p $DATA_DIR/redis
mkdir -p $LOG_DIR

echo "📁 目录结构创建完成"

# =====================
# 安装基础依赖
# =====================

apt update -y
apt install -y wget tar nginx

echo "📦 基础依赖安装完成"

# =====================
# 安装 Java（统一路径）
# =====================

cd $TOOLS_DIR

# =====================
# 安装 Java（推荐方式）
# =====================

apt install -y openjdk-17-jdk

JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export JAVA_HOME
export PATH=$JAVA_HOME/bin:$PATH

echo "☕ Java 安装完成"

# =====================
# 安装 MySQL（使用系统包）
# =====================

apt install -y mysql-server

systemctl start mysql
systemctl enable mysql

echo "🗄️ MySQL 安装完成"

# =====================
# 初始化数据库
# =====================

mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS fitness_app;
EOF

echo "📊 数据库初始化完成"

# =====================
# 安装 Redis
# =====================

apt install -y redis-server

systemctl start redis-server
systemctl enable redis-server

echo "⚡ Redis 安装完成"

# =====================
# 配置 Nginx
# =====================

cat > /etc/nginx/sites-available/fitness <<EOF
server {
    listen 80;

    server_name _;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/fitness /etc/nginx/sites-enabled/

systemctl restart nginx

echo "🌐 Nginx 配置完成"

# =====================
# 创建应用启动脚本
# =====================

cat > $APP_DIR/start.sh <<EOF
#!/bin/bash

export JAVA_HOME=$TOOLS_DIR/java
export PATH=\$JAVA_HOME/bin:\$PATH

cd $APP_DIR

echo "🚀 启动后端服务..."

nohup java -jar app.jar > $LOG_DIR/app.log 2>&1 &
EOF

chmod +x $APP_DIR/start.sh

# =====================
# 创建停止脚本
# =====================

cat > $APP_DIR/stop.sh <<EOF
#!/bin/bash

PID=\$(ps -ef | grep app.jar | grep -v grep | awk '{print \$2}')

if [ -n "\$PID" ]; then
    kill -9 \$PID
    echo "🛑 应用已停止"
else
    echo "⚠️ 未找到运行中的应用"
fi
EOF

chmod +x $APP_DIR/stop.sh

# =====================
# 创建重启脚本
# =====================

cat > $APP_DIR/restart.sh <<EOF
#!/bin/bash

$APP_DIR/stop.sh
sleep 2
$APP_DIR/start.sh
EOF

chmod +x $APP_DIR/restart.sh

# =====================
# 输出提示
# =====================

echo ""
echo "🎉 部署完成！"
echo ""
echo "👉 上传你的后端："
echo "scp target/app.jar root@服务器:$APP_DIR/"
echo ""
echo "👉 启动服务："
echo "cd $APP_DIR && ./start.sh"
echo ""
echo "👉 查看日志："
echo "tail -f $LOG_DIR/app.log"
echo ""
echo "👉 访问："
echo "http://服务器IP"
echo ""
