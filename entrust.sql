-- =====================================================
-- SQL查询集合 - 基于T_DEAL和T_ENTRUST表的统计分析
-- =====================================================

-- =====================================================
-- 基于T_DEAL表的查询 - 1：买入（BUY）- 2：卖出（SELL）
-- =====================================================

-- 1. 多用户股票成交统计
-- 功能：统计指定用户ID列表的股票成交情况
WITH time_range AS ( 
    SELECT 
        TO_DATE('2025-09-11 00:00:00', 'YYYY-MM-DD HH24:MI:SS') AS start_time, 
        TO_DATE('2025-09-12 23:59:59', 'YYYY-MM-DD HH24:MI:SS') AS end_time 
    FROM DUAL 
) 
SELECT 
    u.ID AS user_id, 
    u.NAME AS user_name, 
    u.TEL AS user_tel, 
    d.STOCK_CODE AS stock_code, 
    d.STOCK_NAME AS stock_name, 
    CASE 
        WHEN d.ENTRUST_DIRECTION = 1 THEN 'BUY' 
        WHEN d.ENTRUST_DIRECTION = 2 THEN 'SELL' 
        ELSE 'UNKNOWN' 
    END AS entrust_direction, 
    SUM(d.AMOUNT * d.PRICE) AS total_deal_amount 
FROM T_DEAL d 
JOIN T_USER u ON u.ID = d.USERID 
CROSS JOIN time_range tr 
WHERE d.USERID IN (115483467, 1880560517) -- 修改此处的用户ID列表
  AND d.DEAL_TIME >= tr.start_time 
  AND d.DEAL_TIME <= tr.end_time 
GROUP BY u.ID, u.NAME, u.TEL, d.STOCK_CODE, d.STOCK_NAME, d.ENTRUST_DIRECTION 
ORDER BY u.ID, total_deal_amount DESC;

-- 2. 当天买入成交金额最大的股票TOP100
-- 功能：统计当天买入成交金额排名前100的股票
WITH time_range AS ( 
    SELECT 
        TO_DATE('2025-09-12 00:00:00', 'YYYY-MM-DD HH24:MI:SS') AS start_time, 
        TO_DATE('2025-09-12 23:59:59', 'YYYY-MM-DD HH24:MI:SS') AS end_time 
    FROM DUAL 
), 
ranked_stocks AS (
    SELECT 
        ROW_NUMBER() OVER (ORDER BY SUM(d.AMOUNT * d.PRICE) DESC) AS stock_rank, 
        d.STOCK_CODE AS stock_code, 
        d.STOCK_NAME AS stock_name, 
        SUM(d.AMOUNT * d.PRICE) AS total_buy_deal_amount, 
        COUNT(*) AS deal_count, 
        SUM(d.AMOUNT) AS total_deal_quantity, 
        ROUND(AVG(d.PRICE), 2) AS avg_buy_price 
    FROM T_DEAL d 
    CROSS JOIN time_range tr 
    WHERE d.DEAL_TIME >= tr.start_time 
      AND d.DEAL_TIME <= tr.end_time 
      AND d.ENTRUST_DIRECTION = 2 
    GROUP BY d.STOCK_CODE, d.STOCK_NAME
)
SELECT 
    stock_rank,
    stock_code,
    stock_name,
    total_buy_deal_amount,
    deal_count,
    total_deal_quantity,
    avg_buy_price
FROM ranked_stocks 
WHERE stock_rank <= 100
ORDER BY stock_rank;

-- 3. 买入成交金额最大的100个股票及最大买入用户
-- 功能：统计买入成交金额最大的前100只股票，并列出每只股票买入总额最大的用户信息
WITH time_range AS ( 
    SELECT 
        TO_DATE('2025-09-12 00:00:00', 'YYYY-MM-DD HH24:MI:SS') AS start_time, 
        TO_DATE('2025-09-12 23:59:59', 'YYYY-MM-DD HH24:MI:SS') AS end_time 
    FROM DUAL 
), 
stock_buy_summary AS ( 
    SELECT 
        d.STOCK_CODE, 
        d.STOCK_NAME, 
        SUM(d.AMOUNT * d.PRICE) AS stock_total_deal_amount 
    FROM T_DEAL d 
    CROSS JOIN time_range tr 
    WHERE d.DEAL_TIME >= tr.start_time 
      AND d.DEAL_TIME <= tr.end_time 
      AND d.ENTRUST_DIRECTION = 2 
    GROUP BY d.STOCK_CODE, d.STOCK_NAME 
), 
user_stock_buy AS ( 
    SELECT 
        d.STOCK_CODE, 
        d.STOCK_NAME, 
        d.USERID, 
        SUM(d.AMOUNT * d.PRICE) AS user_deal_amount, 
        ROUND(AVG(d.PRICE), 2) AS user_avg_buy_price, 
        ROW_NUMBER() OVER (PARTITION BY d.STOCK_CODE ORDER BY SUM(d.AMOUNT * d.PRICE) DESC) AS user_rank 
    FROM T_DEAL d 
    CROSS JOIN time_range tr 
    WHERE d.DEAL_TIME >= tr.start_time 
      AND d.DEAL_TIME <= tr.end_time 
      AND d.ENTRUST_DIRECTION = 2 
    GROUP BY d.STOCK_CODE, d.STOCK_NAME, d.USERID 
), 
top_stocks AS ( 
    SELECT 
        STOCK_CODE, 
        STOCK_NAME, 
        stock_total_deal_amount, 
        ROW_NUMBER() OVER (ORDER BY stock_total_deal_amount DESC) AS stock_rank 
    FROM stock_buy_summary 
) 
SELECT 
    ts.stock_rank, 
    ts.STOCK_CODE AS stock_code, 
    ts.STOCK_NAME AS stock_name, 
    ts.stock_total_deal_amount AS total_buy_deal_amount, 
    u.ID AS max_user_id, 
    u.NAME AS max_user_name, 
    u.TEL AS max_user_tel, 
    usb.user_deal_amount AS max_user_deal_amount, 
    usb.user_avg_buy_price AS max_user_avg_buy_price 
FROM top_stocks ts 
JOIN user_stock_buy usb ON ts.STOCK_CODE = usb.STOCK_CODE AND usb.user_rank = 1 
JOIN T_USER u ON u.ID = usb.USERID 
WHERE ts.stock_rank <= 100
ORDER BY ts.stock_rank;

-- 4. 成交总金额最大的用户TOP100
-- 功能：统计成交总金额排名前100的用户及其成交最大的股票
WITH time_range AS ( 
    SELECT 
        TO_DATE('2025-09-12 00:00:00', 'YYYY-MM-DD HH24:MI:SS') AS start_time, 
        TO_DATE('2025-09-12 23:59:59', 'YYYY-MM-DD HH24:MI:SS') AS end_time 
    FROM DUAL 
), 
user_stock_summary AS ( 
    SELECT 
        USERID, 
        STOCK_CODE, 
        STOCK_NAME, 
        ENTRUST_DIRECTION, 
        SUM(AMOUNT * PRICE) AS stock_total_amount 
    FROM T_DEAL, time_range 
    WHERE DEAL_TIME >= time_range.start_time 
      AND DEAL_TIME <= time_range.end_time 
    GROUP BY USERID, STOCK_CODE, STOCK_NAME, ENTRUST_DIRECTION 
), 
user_max_stock AS ( 
    SELECT 
        USERID, 
        STOCK_CODE, 
        STOCK_NAME, 
        ENTRUST_DIRECTION, 
        stock_total_amount, 
        ROW_NUMBER() OVER (PARTITION BY USERID ORDER BY stock_total_amount DESC) AS rn 
    FROM user_stock_summary 
), 
user_total_summary AS ( 
    SELECT 
        USERID, 
        SUM(AMOUNT * PRICE) AS user_total_amount 
    FROM T_DEAL, time_range 
    WHERE DEAL_TIME >= time_range.start_time 
      AND DEAL_TIME <= time_range.end_time 
    GROUP BY USERID 
), 
ranked_users AS ( 
    SELECT 
        u.ID AS user_id, 
        u.NAME AS user_name, 
        u.TEL AS user_tel, 
        ums.STOCK_CODE, 
        ums.STOCK_NAME, 
        CASE 
            WHEN ums.ENTRUST_DIRECTION = 1 THEN 'SELL' 
            WHEN ums.ENTRUST_DIRECTION = 2 THEN 'BUY' 
            ELSE 'UNKNOWN' 
        END AS entrust_direction, 
        ums.stock_total_amount AS stock_total_amount, 
        uts.user_total_amount AS user_total_amount, 
        ROW_NUMBER() OVER (ORDER BY uts.user_total_amount DESC) AS user_rank 
    FROM user_max_stock ums 
    JOIN user_total_summary uts ON ums.USERID = uts.USERID 
    JOIN T_USER u ON u.ID = ums.USERID 
    WHERE ums.rn = 1 
) 
SELECT 
    user_id, 
    user_name, 
    user_tel, 
    STOCK_CODE, 
    STOCK_NAME, 
    entrust_direction, 
    stock_total_amount, 
    user_total_amount 
FROM ranked_users 
WHERE user_rank <= 100 
ORDER BY user_total_amount DESC;

-- =====================================================
-- 基于T_ENTRUST表的查询
-- =====================================================

-- 5. 多用户委托统计
-- 功能：统计指定用户ID列表的股票委托情况
WITH time_range AS ( 
    SELECT 
        TO_DATE('2025-09-12 00:00:00', 'YYYY-MM-DD HH24:MI:SS') AS start_time, 
        TO_DATE('2025-09-12 23:59:59', 'YYYY-MM-DD HH24:MI:SS') AS end_time 
    FROM DUAL 
) 
SELECT 
    u.ID AS user_id, 
    u.NAME AS user_name, 
    u.TEL AS user_tel, 
    e.STOCK_CODE AS stock_code, 
    e.STOCK_NAME AS stock_name, 
    CASE 
        WHEN e.ENTRUST_DIRECTION = 1 THEN 'SELL' 
        WHEN e.ENTRUST_DIRECTION = 2 THEN 'BUY' 
        ELSE 'UNKNOWN' 
    END AS entrust_direction, 
    SUM(e.ENTRUST_AMOUNT * e.ENTRUST_PRICE) AS total_entrust_amount 
FROM T_ENTRUST e 
JOIN T_USER u ON u.ID = e.USERID 
CROSS JOIN time_range tr 
WHERE e.USERID IN (115483467, 1880560517) -- 修改此处的用户ID列表
  AND e.ENTRUST_TIME >= tr.start_time 
  AND e.ENTRUST_TIME <= tr.end_time 
GROUP BY u.ID, u.NAME, u.TEL, e.STOCK_CODE, e.STOCK_NAME, e.ENTRUST_DIRECTION 
ORDER BY u.ID, total_entrust_amount DESC;

-- 6. 当天买入委托金额最大的股票TOP100
-- 功能：统计当天买入委托金额排名前100的股票
WITH time_range AS ( 
    SELECT 
        TO_DATE('2025-09-12 00:00:00', 'YYYY-MM-DD HH24:MI:SS') AS start_time, 
        TO_DATE('2025-09-12 23:59:59', 'YYYY-MM-DD HH24:MI:SS') AS end_time 
    FROM DUAL 
), 
ranked_stocks AS (
    SELECT 
        ROW_NUMBER() OVER (ORDER BY SUM(e.ENTRUST_AMOUNT * e.ENTRUST_PRICE) DESC) AS stock_rank, 
        e.STOCK_CODE AS stock_code, 
        e.STOCK_NAME AS stock_name, 
        SUM(e.ENTRUST_AMOUNT * e.ENTRUST_PRICE) AS total_buy_entrust_amount, 
        COUNT(*) AS entrust_count, 
        SUM(e.ENTRUST_AMOUNT) AS total_entrust_quantity, 
        ROUND(AVG(e.ENTRUST_PRICE), 2) AS avg_entrust_price 
    FROM T_ENTRUST e 
    CROSS JOIN time_range tr 
    WHERE e.ENTRUST_TIME >= tr.start_time 
      AND e.ENTRUST_TIME <= tr.end_time 
      AND e.ENTRUST_DIRECTION = 2 
    GROUP BY e.STOCK_CODE, e.STOCK_NAME
)
SELECT 
    stock_rank,
    stock_code,
    stock_name,
    total_buy_entrust_amount,
    entrust_count,
    total_entrust_quantity,
    avg_entrust_price
FROM ranked_stocks 
WHERE stock_rank <= 100
ORDER BY stock_rank;

-- 7. 买入委托金额最大的100个股票及最大委托用户
-- 功能：统计买入委托金额最大的前100只股票，并列出每只股票买入总额最大的用户信息
WITH time_range AS ( 
    SELECT 
        TO_DATE('2025-09-12 00:00:00', 'YYYY-MM-DD HH24:MI:SS') AS start_time, 
        TO_DATE('2025-09-12 23:59:59', 'YYYY-MM-DD HH24:MI:SS') AS end_time 
    FROM DUAL 
), 
stock_buy_summary AS ( 
    SELECT 
        e.STOCK_CODE, 
        e.STOCK_NAME, 
        SUM(e.ENTRUST_AMOUNT * e.ENTRUST_PRICE) AS stock_total_entrust_amount 
    FROM T_ENTRUST e 
    CROSS JOIN time_range tr 
    WHERE e.ENTRUST_TIME >= tr.start_time 
      AND e.ENTRUST_TIME <= tr.end_time 
      AND e.ENTRUST_DIRECTION = 2 
    GROUP BY e.STOCK_CODE, e.STOCK_NAME 
), 
user_stock_buy AS ( 
    SELECT 
        e.STOCK_CODE, 
        e.STOCK_NAME, 
        e.USERID, 
        SUM(e.ENTRUST_AMOUNT * e.ENTRUST_PRICE) AS user_entrust_amount, 
        ROUND(AVG(e.ENTRUST_PRICE), 2) AS user_avg_entrust_price, 
        ROW_NUMBER() OVER (PARTITION BY e.STOCK_CODE ORDER BY SUM(e.ENTRUST_AMOUNT * e.ENTRUST_PRICE) DESC) AS user_rank 
    FROM T_ENTRUST e 
    CROSS JOIN time_range tr 
    WHERE e.ENTRUST_TIME >= tr.start_time 
      AND e.ENTRUST_TIME <= tr.end_time 
      AND e.ENTRUST_DIRECTION = 2 
    GROUP BY e.STOCK_CODE, e.STOCK_NAME, e.USERID 
), 
top_stocks AS ( 
    SELECT 
        STOCK_CODE, 
        STOCK_NAME, 
        stock_total_entrust_amount, 
        ROW_NUMBER() OVER (ORDER BY stock_total_entrust_amount DESC) AS stock_rank 
    FROM stock_buy_summary 
) 
SELECT 
    ts.stock_rank, 
    ts.STOCK_CODE AS stock_code, 
    ts.STOCK_NAME AS stock_name, 
    ts.stock_total_entrust_amount AS total_buy_entrust_amount, 
    u.ID AS max_user_id, 
    u.NAME AS max_user_name, 
    u.TEL AS max_user_tel, 
    usb.user_entrust_amount AS max_user_entrust_amount, 
    usb.user_avg_entrust_price AS max_user_avg_entrust_price 
FROM top_stocks ts 
JOIN user_stock_buy usb ON ts.STOCK_CODE = usb.STOCK_CODE AND usb.user_rank = 1 
JOIN T_USER u ON u.ID = usb.USERID 
WHERE ts.stock_rank <= 100
ORDER BY ts.stock_rank;

-- 8. 委托总金额最大的用户TOP100
-- 功能：统计委托总金额排名前100的用户及其委托最大的股票
WITH time_range AS ( 
    SELECT 
        TO_DATE('2025-09-12 00:00:00', 'YYYY-MM-DD HH24:MI:SS') AS start_time, 
        TO_DATE('2025-09-12 23:59:59', 'YYYY-MM-DD HH24:MI:SS') AS end_time 
    FROM DUAL 
), 
user_stock_summary AS ( 
    SELECT 
        USERID, 
        STOCK_CODE, 
        STOCK_NAME, 
        ENTRUST_DIRECTION, 
        SUM(ENTRUST_AMOUNT * ENTRUST_PRICE) AS stock_total_entrust_amount 
    FROM T_ENTRUST, time_range 
    WHERE ENTRUST_TIME >= time_range.start_time 
      AND ENTRUST_TIME <= time_range.end_time 
    GROUP BY USERID, STOCK_CODE, STOCK_NAME, ENTRUST_DIRECTION 
), 
user_max_stock AS ( 
    SELECT 
        USERID, 
        STOCK_CODE, 
        STOCK_NAME, 
        ENTRUST_DIRECTION, 
        stock_total_entrust_amount, 
        ROW_NUMBER() OVER (PARTITION BY USERID ORDER BY stock_total_entrust_amount DESC) AS rn 
    FROM user_stock_summary 
), 
user_total_summary AS ( 
    SELECT 
        USERID, 
        SUM(ENTRUST_AMOUNT * ENTRUST_PRICE) AS user_total_entrust_amount 
    FROM T_ENTRUST, time_range 
    WHERE ENTRUST_TIME >= time_range.start_time 
      AND ENTRUST_TIME <= time_range.end_time 
    GROUP BY USERID 
), 
ranked_users AS ( 
    SELECT 
        u.ID AS user_id, 
        u.NAME AS user_name, 
        u.TEL AS user_tel, 
        ums.STOCK_CODE, 
        ums.STOCK_NAME, 
        CASE 
            WHEN ums.ENTRUST_DIRECTION = 1 THEN 'SELL' 
            WHEN ums.ENTRUST_DIRECTION = 2 THEN 'BUY' 
            ELSE 'UNKNOWN' 
        END AS entrust_direction, 
        ums.stock_total_entrust_amount AS stock_total_entrust_amount, 
        uts.user_total_entrust_amount AS user_total_entrust_amount, 
        ROW_NUMBER() OVER (ORDER BY uts.user_total_entrust_amount DESC) AS user_rank 
    FROM user_max_stock ums 
    JOIN user_total_summary uts ON ums.USERID = uts.USERID 
    JOIN T_USER u ON u.ID = ums.USERID 
    WHERE ums.rn = 1 
) 
SELECT 
    user_id, 
    user_name, 
    user_tel, 
    STOCK_CODE, 
    STOCK_NAME, 
    entrust_direction, 
    stock_total_entrust_amount, 
    user_total_entrust_amount 
FROM ranked_users 
WHERE user_rank <= 100 
ORDER BY user_total_entrust_amount DESC;

-- =====================================================
-- 使用说明
-- =====================================================
/*
时间配置说明：
1. 查询昨天到今天：
   start_time: TO_DATE(TO_CHAR(SYSDATE-1, 'YYYY-MM-DD') || ' 00:00:00', 'YYYY-MM-DD HH24:MI:SS')
   end_time: TO_DATE(TO_CHAR(SYSDATE, 'YYYY-MM-DD') || ' 23:59:59', 'YYYY-MM-DD HH24:MI:SS')

2. 查询指定日期范围：
   start_time: TO_DATE('2025-09-10 00:00:00', 'YYYY-MM-DD HH24:MI:SS')
   end_time: TO_DATE('2025-09-12 23:59:59', 'YYYY-MM-DD HH24:MI:SS')

3. 查询最近7天：
   start_time: TO_DATE(TO_CHAR(SYSDATE-7, 'YYYY-MM-DD') || ' 00:00:00', 'YYYY-MM-DD HH24:MI:SS')
   end_time: TO_DATE(TO_CHAR(SYSDATE, 'YYYY-MM-DD') || ' 23:59:59', 'YYYY-MM-DD HH24:MI:SS')

4. 查询本月：
   start_time: TO_DATE(TO_CHAR(TRUNC(SYSDATE, 'MM'), 'YYYY-MM-DD') || ' 00:00:00', 'YYYY-MM-DD HH24:MI:SS')
   end_time: TO_DATE(TO_CHAR(LAST_DAY(SYSDATE), 'YYYY-MM-DD') || ' 23:59:59', 'YYYY-MM-DD HH24:MI:SS')

委托方向说明：
- 1 = 卖出 (SELL)
- 2 = 买入 (BUY)

表结构说明：
- T_DEAL: 成交数据表，记录实际交易结果
- T_ENTRUST: 委托数据表，记录下单委托信息
- T_USER: 用户信息表

注意事项：
1. 所有查询都已针对Oracle数据库进行优化
2. 使用ROW_NUMBER()窗口函数进行排序和分页
3. 时间字段统一使用WITH子句配置，便于修改
4. 所有字段别名使用英文，便于国际化
*/
