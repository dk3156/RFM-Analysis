# 최근 1년 데이터만 사용
create view sample2 as
select *
from sample
where STR_TO_DATE(order_date, '%m-%d-%Y') > '2017-01-01'

# RFM 분석
CREATE VIEW customer_grouping2 AS
SELECT
  *,
  CASE 
    WHEN (R>=4 AND R<=5) AND (((F+M)/2) >= 4 AND ((F+M)/2) <= 5) THEN 'VIP' 
    WHEN (R>=2 AND R<=5) AND (((F+M)/2) >= 3 AND ((F+M)/2) <=5) THEN 'VVIP'
    WHEN (R>=3 AND R<=5) AND (((F+M)/2) >= 1 AND ((F+M)/2) <=3) THEN '잠재 충성 고객'
    WHEN (R>=4 AND R<=5) AND (((F+M)/2) >= 0 AND ((F+M)/2) <=1) THEN '신규 고객'
    WHEN (R>=3 AND R<=4) AND (((F+M)/2) >= 0 AND ((F+M)/2) <=1) THEN '유망 고객'
    WHEN (R>=2 AND R<=3) AND (((F+M)/2) >= 2 AND ((F+M)/2) <=3) THEN '신경써야 할 고객'
    WHEN (R>=2 AND R<=3) AND (((F+M)/2) >= 0 AND ((F+M)/2) <=2) THEN '휴면 우려 고객'
    WHEN (R>=0 AND R<=2) AND (((F+M)/2) >= 2 AND ((F+M)/2) <=5) THEN '이탈우려고객'
    WHEN (R>=0 AND R<=1) AND (((F+M)/2) >= 4 AND ((F+M)/2) <=5) THEN "떠나간 VIP"
    WHEN (R>=1 AND R<=2) AND (((F+M)/2) >= 1 AND ((F+M)/2) <=2) THEN '휴면 고객'
    WHEN (R>=0 AND R<=2) AND (((F+M)/2) >= 0 AND ((F+M)/2) <=2) THEN '이탈한 고객'
  END AS customer_segment
FROM (
  SELECT
    MAX(STR_TO_DATE(order_date, '%m-%d-%Y')) AS latest_order_date,
    customer_id,
    DATEDIFF(STR_TO_DATE('12-30-2017', '%m-%d-%Y'), max(STR_TO_DATE(order_date, '%m-%d-%Y'))) AS recency,
    COUNT(DISTINCT order_id) AS frequency,
    SUM(sales) AS monetary,
    NTILE(5) OVER (ORDER BY DATEDIFF(STR_TO_DATE('12-30-2017', '%m-%d-%Y'), max(STR_TO_DATE(order_date, '%m-%d-%Y')))DESC) AS R,
    NTILE(5) OVER (ORDER BY COUNT(DISTINCT order_id) ASC) AS F, 
    NTILE(5) OVER (ORDER BY SUM(sales) ASC) AS M 
  FROM sample2
  GROUP BY 2
) rfm_table
GROUP BY customer_id;

# 세그먼트별 고객 수 / 세그 별 고객수 비율 / 세그 별 Sales 비율
SELECT 
    customer_segment,
    COUNT(DISTINCT customer_id) AS num_of_customers,
    ROUND(COUNT(DISTINCT customer_id) / (SELECT COUNT(*) FROM customer_grouping2) * 100, 2) AS pct_of_customers,
    ROUND(sum(monetary) / (SELECT sum(monetary) FROM customer_grouping2 ) * 100, 2) AS pct_of_payment
FROM customer_grouping2
GROUP BY customer_segment
ORDER BY pct_of_customers DESC; 

create view total as(
select ship_mode, round(count(distinct order_id) / (select count(distinct order_id) from superstore) * 100, 2) AS pct_of_orders
from superstore s 
group by ship_mode)

#챔피언 배송옵
WITH champions AS (
	SELECT 
	ship_mode, count(distinct order_id) as order_num, sum(profit) as profit
	from
	SUPERSTORE
	WHERE CUSTOMER_ID IN (
	 SELECT CUSTOMER_ID
	 FROM customer_grouping
	 WHERE CUSTOMER_SEGMENT = 'Champions'
	)
	GROUP BY ship_mode
), 
champions_pct as (
SELECT ship_mode, round(order_num / (SELECT SUM(order_num) FROM champions) * 100, 2) AS pct_of_orders_champ, sum()
FROM champions
)
select total.ship_mode, pct_of_orders_champ, pct_of_orders
from champions_pct join total on champions_pct.ship_mode = total.ship_mode

#포텐 로얄 배송옵션 
WITH potential_loyalist AS (
	SELECT 
	ship_mode, count(distinct order_id) as order_num, sum(profit) as profit
	FROM
	SUPERSTORE
	WHERE CUSTOMER_ID IN (
	 SELECT CUSTOMER_ID
	 FROM customer_grouping
	 WHERE CUSTOMER_SEGMENT = 'Potential Loyalist'
	)
	GROUP BY ship_mode
),
loyal_pct as (
select ship_mode, round(order_num / (select sum(order_num) from potential_loyalist) * 100, 2) as pct_of_orders_loyal
from potential_loyalist
)
select total.ship_mode, pct_of_orders_loyal, pct_of_orders
from loyal_pct join total on loyal_pct.ship_mode = total.ship_mode

#이탈 위험 배송옵션
WITH at_risk AS (
	SELECT 
	ship_mode, count(distinct order_id) as order_num, sum(profit) as profit
	FROM
	SUPERSTORE
	WHERE CUSTOMER_ID IN (
	 SELECT CUSTOMER_ID
	 FROM customer_grouping
	 WHERE CUSTOMER_SEGMENT = 'At Risk'
	)
	GROUP BY ship_mode
),
risk_pct as (
select ship_mode, round(order_num / (select sum(order_num) from at_risk) * 100, 2) as pct_of_orders_risk
from at_risk
)
select total.ship_mode, pct_of_orders_risk, pct_of_orders
from risk_pct join total on risk_pct.ship_mode = total.ship_mode

#전체


#category
WITH champions AS (
	SELECT 
	category, round(sum(sales)) sale, round(sum(profit)) profit, count(distinct customer_id) cust_num
	FROM 
	SUPERSTORE
	WHERE CUSTOMER_ID IN (
	 SELECT CUSTOMER_ID
	 FROM customer_grouping
	 WHERE CUSTOMER_SEGMENT = 'Champions'
	)
	GROUP BY category
)
SELECT category, sale, profit, ROUND(cust_num / (SELECT SUM(CUST_NUM) FROM champions) * 100, 2) AS PERCENTILE
FROM champions
order by sale, profit

# discount 20 %. champions, potloyal, atrisk
# x variable -- time
# y variable -- sales with orders that have 20% discount and champions customer, 아니면 sale / total(sale)
# 20% 할인율에 시간에 따른 매출 증대가 보인다면 --> regression fit 가능
# 20 % 할인을 받은 고객들이 더 많이 살까
# 20 % 할인을 받은 고객들이 언제 구매했는지 보고, 구매 시작일을 기준으로 R, F, M 의 
# 문제 정의: at risk 고객이 상품 전체적으로 20% 할인을 받으면 매출이 시간이 지남에 따라 증가할까?
# 가설 설정: 코호트분석. A/B test를 진행한다. A/B test 결과별로 매출이 증가하는지 확인한다. iteration을 증가한다. A/B 테스트가 불가능 (라이브 플랫폼이 있어햐 한다.) 따라서 액션 플랜을 하자ㅠㅠㅠㅠ

#ship_mode
WITH potential_loyalist AS (
	SELECT 
	ship_mode, round(sum(sales)) sale, round(sum(profit)) profit, count(distinct customer_id) cust_num
	FROM 
	SUPERSTORE
	WHERE CUSTOMER_ID IN (
	 SELECT CUSTOMER_ID
	 FROM customer_grouping
	 WHERE CUSTOMER_SEGMENT = 'Potential Loyalist'
	)
	GROUP BY ship_mode
)
SELECT ship_mode, sale, profit, ROUND(cust_num / (SELECT SUM(CUST_NUM) FROM potential_loyalist) * 100, 2) AS PERCENTILE
FROM potential_loyalist
GROUP BY ship_mode
order by sale, profit

#category
WITH potential_loyalist AS (
	SELECT 
	category, round(sum(sales)) sale, round(sum(profit)) profit, count(distinct customer_id) cust_num
	FROM 
	SUPERSTORE
	WHERE CUSTOMER_ID IN (
	 SELECT CUSTOMER_ID
	 FROM customer_grouping
	 WHERE CUSTOMER_SEGMENT = 'Potential Loyalist'
	)
	GROUP BY category
)
SELECT category, sale, profit, ROUND(cust_num / (SELECT SUM(CUST_NUM) FROM potential_loyalist) * 100, 2) AS PERCENTILE
FROM potential_loyalist
order by sale, profit

#category
WITH at_risk AS (
	SELECT 
	category, round(sum(sales)) sale, round(sum(profit)) profit, count(distinct customer_id) cust_num
	FROM 
	SUPERSTORE
	WHERE CUSTOMER_ID IN (
	 SELECT CUSTOMER_ID
	 FROM customer_grouping
	 WHERE CUSTOMER_SEGMENT = 'At Risk'
	)
	GROUP BY category
)
SELECT category, sale, profit, ROUND(cust_num / (SELECT SUM(CUST_NUM) FROM at_risk) * 100, 2) AS PERCENTILE
FROM at_risk
order by sale, profit

