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
