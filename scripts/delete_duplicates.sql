DELETE FROM k15_tickers
WHERE id IN (SELECT id
             FROM (SELECT id, ROW_NUMBER() OVER (partition BY time ORDER BY vo DESC) AS rnum FROM k15_tickers) t
             WHERE t.rnum > 1);
