WITH time_range AS (
    SELECT 
        TO_DATE('2025-09-11 00:00:00', 'YYYY-MM-DD HH24:MI:SS') AS start_time,
        TO_DATE('2025-09-12 23:59:59', 'YYYY-MM-DD HH24:MI:SS') AS end_time
    FROM DUAL
)
SELECT 
    u.ID AS 用户ID,
    u.NAME AS 用户姓名,
    u.TEL AS 用户电话,
    d.STOCK_CODE AS 股票代码,
    d.STOCK_NAME AS 股票名称,
    CASE 
        WHEN d.ENTRUST_DIRECTION = 1 THEN '卖'
        WHEN d.ENTRUST_DIRECTION = 2 THEN '买'
        ELSE '未知'
    END AS 委托方向,
    SUM(d.AMOUNT * d.PRICE) AS 成交总金额
FROM T_DEAL d
JOIN T_USER u ON u.ID = d.USERID
CROSS JOIN time_range tr
WHERE d.USERID IN (115483467, 1880560517) 
  AND d.DEAL_TIME >= tr.start_time
  AND d.DEAL_TIME <= tr.end_time
GROUP BY u.ID, u.NAME, u.TEL, d.STOCK_CODE, d.STOCK_NAME, d.ENTRUST_DIRECTION
ORDER BY u.ID, 成交总金额 DESC;
