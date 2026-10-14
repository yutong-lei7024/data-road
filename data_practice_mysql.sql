-- ============================================================
-- 数据方向实习 · 本地练习库脚本
-- 用法：用 Navicat 连上本地 MySQL（localhost / 3306 / root / 你的密码）
--       然后「打开文件」选中本文件 → 点「运行(Execute)」→ 全部执行
-- 影响范围：只创建和重写 data_practice 这个练习库，不动你电脑上的其他库
-- 生成内容：30 个用户、12 个商品、200 条近 90 天的订单
-- ============================================================

CREATE DATABASE IF NOT EXISTS data_practice
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE data_practice;

DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS users;

-- ---------- 1. 建表：用户 / 商品 / 订单 ----------
CREATE TABLE users (
  user_id       INT PRIMARY KEY COMMENT '用户ID',
  user_name     VARCHAR(32) NOT NULL COMMENT '用户名',
  city          VARCHAR(32) NOT NULL COMMENT '城市',
  channel       VARCHAR(16) NOT NULL COMMENT '注册渠道',
  register_date DATE        NOT NULL COMMENT '注册日期',
  is_member     TINYINT     NOT NULL DEFAULT 0 COMMENT '1=会员'
) COMMENT='用户维度表';

CREATE TABLE products (
  product_id   INT PRIMARY KEY COMMENT '商品ID',
  product_name VARCHAR(64)   NOT NULL COMMENT '商品名',
  category     VARCHAR(32)   NOT NULL COMMENT '品类',
  price        DECIMAL(10,2) NOT NULL COMMENT '单价'
) COMMENT='商品维度表';

CREATE TABLE orders (
  order_id   BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '订单ID',
  user_id    INT           NOT NULL COMMENT '用户ID',
  product_id INT           NOT NULL COMMENT '商品ID',
  quantity   INT           NOT NULL COMMENT '数量',
  amount     DECIMAL(12,2) NOT NULL COMMENT '金额 = 数量 * 单价',
  order_time DATETIME      NOT NULL COMMENT '下单时间',
  status     VARCHAR(16)   NOT NULL COMMENT 'PAID=已支付 REFUND=已退款',
  KEY idx_user (user_id),
  KEY idx_time (order_time),
  KEY idx_status (status)
) COMMENT='订单事实表';

-- ---------- 2. 造数据 ----------
-- 30 个用户：城市、渠道按编号循环取，注册日期从 2026-10-12 往前推
INSERT INTO users (user_id, user_name, city, channel, register_date, is_member)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 30)
SELECT n,
       CONCAT('用户', LPAD(n, 2, '0')),
       ELT(1 + (n % 10), '北京','上海','广州','深圳','杭州','成都','武汉','西安','南京','重庆'),
       ELT(1 + (n % 5), '搜索','广告','推荐','朋友推荐','自然流量'),
       DATE_SUB('2026-10-12', INTERVAL (n * 7) DAY),
       IF(n % 3 = 0, 1, 0)
FROM seq;

-- 12 个商品
INSERT INTO products (product_id, product_name, category, price) VALUES
  (1,'无线蓝牙耳机','数码配件',399.00),
  (2,'机械键盘','数码配件',549.00),
  (3,'27寸显示器','电脑整机',1299.00),
  (4,'人体工学椅','家居办公',899.00),
  (5,'保温杯','生活日用',89.00),
  (6,'洗发水套装','生活日用',129.00),
  (7,'跑步鞋','运动户外',479.00),
  (8,'瑜伽垫','运动户外',159.00),
  (9,'手机壳','数码配件',39.00),
  (10,'蓝牙音箱','数码配件',299.00),
  (11,'咖啡豆 500g','食品饮料',118.00),
  (12,'坚果礼盒','食品饮料',168.00);

-- 200 条订单：用户、商品、数量、时间随机，金额由数量 * 单价算出
INSERT INTO orders (user_id, product_id, quantity, amount, order_time, status)
SELECT t.uid, t.pid, t.qty, t.qty * p.price,
       NOW() - INTERVAL t.dday DAY - INTERVAL t.dsec SECOND, t.st
FROM (
  WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 200)
  SELECT 1 + FLOOR(RAND() * 30) AS uid,
         1 + FLOOR(RAND() * 12) AS pid,
         1 + FLOOR(RAND() * 3)  AS qty,
         FLOOR(RAND() * 90)     AS dday,
         FLOOR(RAND() * 86400)  AS dsec,
         ELT(1 + FLOOR(RAND() * 5), 'PAID','PAID','PAID','PAID','REFUND') AS st
  FROM seq
) t
JOIN products p ON p.product_id = t.pid;

-- ---------- 3. 验收：这几条能跑通就说明环境没问题 ----------
SELECT COUNT(*) AS 用户数 FROM users;
SELECT COUNT(*) AS 商品数 FROM products;
SELECT COUNT(*) AS 订单数,
       ROUND(SUM(CASE WHEN status = 'PAID' THEN amount END), 2) AS 成交额,
       SUM(status = 'REFUND') AS 退款单数
FROM orders;

-- 关联 + 分组：各品类成交额
SELECT p.category AS 品类,
       COUNT(*) AS 订单数,
       ROUND(SUM(o.amount), 2) AS 成交额
FROM orders o
JOIN products p ON p.product_id = o.product_id
WHERE o.status = 'PAID'
GROUP BY p.category
ORDER BY 成交额 DESC;

-- 窗口函数：各品类内部按成交额排名前 3 的商品
SELECT 品类, 商品名, 成交额, 排名 FROM (
  SELECT p.category AS 品类,
         p.product_name AS 商品名,
         ROUND(SUM(o.amount), 2) AS 成交额,
         ROW_NUMBER() OVER (PARTITION BY p.category ORDER BY SUM(o.amount) DESC) AS 排名
  FROM orders o
  JOIN products p ON p.product_id = o.product_id
  WHERE o.status = 'PAID'
  GROUP BY p.category, p.product_name
) t
WHERE 排名 <= 3
ORDER BY 品类, 排名;

-- ============================================================
-- 4. 你的练习题（先自己写，卡住了再看括号里的提示）
-- ============================================================
-- 1) 每个城市的用户数和成交额
--    （users JOIN orders，GROUP BY city；注意只算 PAID）
-- 2) 每个注册渠道的复购率
--    （先按 user_id 统计订单数，订单数 > 1 的人算复购，再回到渠道聚合）
-- 3) 每月成交额与环比增长
--    （DATE_FORMAT(order_time,'%Y-%m') 分组，再用 LAG() 取上月）
-- 4) 每个用户的首次和末次下单时间
--    （MIN/MAX + GROUP BY user_id）
-- 5) 用户连续下单天数最长的一段
--    （经典技巧：order_date - ROW_NUMBER() 得到分组标记）

-- ============================================================
-- 5. 以后要把数据变大（W3 那天用）
--    把上面 orders 那段里的 n < 200 改成 n < 1000，重新执行一次即可，
--    先执行 DELETE FROM orders; 再跑插入语句。
-- ============================================================
