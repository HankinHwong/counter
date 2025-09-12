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
        WHEN d.ENTRUST_DIRECTION = 1 THEN 'SELL' 
        WHEN d.ENTRUST_DIRECTION = 2 THEN 'BUY' 
        ELSE 'UNKNOWN' 
    END AS entrust_direction, 
    SUM(d.AMOUNT * d.PRICE) AS total_deal_amount 
FROM T_DEAL d 
JOIN T_USER u ON u.ID = d.USERID 
CROSS JOIN time_range tr 
WHERE d.USERID IN (115483467, 1880560517) 
  AND d.DEAL_TIME >= tr.start_time 
  AND d.DEAL_TIME <= tr.end_time 
GROUP BY u.ID, u.NAME, u.TEL, d.STOCK_CODE, d.STOCK_NAME, d.ENTRUST_DIRECTION 
ORDER BY u.ID, total_deal_amount DESC;
