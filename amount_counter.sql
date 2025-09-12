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
        u.ID AS 用户ID,
        u.NAME AS 用户姓名,
        u.TEL AS 用户电话,
        ums.STOCK_CODE,
        ums.STOCK_NAME,
        CASE 
            WHEN ums.ENTRUST_DIRECTION = 1 THEN '卖'
            WHEN ums.ENTRUST_DIRECTION = 2 THEN '买'
            ELSE '未知'
        END AS 成交方向,
        ums.stock_total_amount AS 成交总额,
        uts.user_total_amount AS 用户总成交金额,
        ROW_NUMBER() OVER (ORDER BY uts.user_total_amount DESC) AS user_rank
    FROM user_max_stock ums
    JOIN user_total_summary uts ON ums.USERID = uts.USERID
    JOIN T_USER u ON u.ID = ums.USERID
    WHERE ums.rn = 1
)
SELECT 
    用户ID,
    用户姓名,
    用户电话,
    STOCK_CODE,
    STOCK_NAME,
    成交方向,
    成交总额,
    用户总成交金额
FROM ranked_users
WHERE user_rank <= 100
ORDER BY 用户总成交金额 DESC;
