/*
  # SQL Structure Optimization

  1. New Indexes
    - Composite indexes for frequently accessed data
    - Indexes for common query patterns
    - Performance optimization for order management
  
  2. Materialized Views
    - Order statistics by AMAP
    - Product usage statistics
    - Delivery schedule overview
    
  3. Performance Functions
    - Efficient order total calculation
    - Delivery schedule generation
    - Statistics aggregation
*/

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_orders_user_status_date 
ON ephemeral_orders(user_id, status, delivery_date);

CREATE INDEX IF NOT EXISTS idx_orders_amap_status_date 
ON ephemeral_orders(amap_id, status, delivery_date);

CREATE INDEX IF NOT EXISTS idx_contracts_amap_dates 
ON recurring_contracts(amap_id, start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_products_period_price 
ON ephemeral_products(period_id, price);

-- Materialized view for order statistics
CREATE MATERIALIZED VIEW order_statistics AS
SELECT 
  o.amap_id,
  date_trunc('month', o.created_at) as month,
  o.status,
  count(*) as order_count,
  sum(
    (SELECT sum(p.price * i.quantity)
     FROM ephemeral_order_items i
     JOIN ephemeral_products p ON p.id = i.product_id
     WHERE i.order_id = o.id)
  ) as total_amount
FROM ephemeral_orders o
GROUP BY o.amap_id, date_trunc('month', o.created_at), o.status;

CREATE UNIQUE INDEX idx_order_statistics_unique 
ON order_statistics(amap_id, month, status);

-- Materialized view for product usage
CREATE MATERIALIZED VIEW product_usage_statistics AS
SELECT 
  p.id as product_id,
  p.name,
  p.period_id,
  count(DISTINCT oi.order_id) as order_count,
  sum(oi.quantity) as total_quantity,
  sum(p.price * oi.quantity) as total_revenue
FROM ephemeral_products p
LEFT JOIN ephemeral_order_items oi ON oi.product_id = p.id
GROUP BY p.id, p.name, p.period_id;

CREATE UNIQUE INDEX idx_product_usage_statistics_unique 
ON product_usage_statistics(product_id, period_id);

-- Materialized view for delivery schedule
CREATE MATERIALIZED VIEW delivery_schedule AS
SELECT 
  a.id as amap_id,
  a.name as amap_name,
  o.delivery_date,
  count(DISTINCT o.id) as order_count,
  count(DISTINCT o.user_id) as customer_count,
  sum(
    (SELECT sum(p.price * i.quantity)
     FROM ephemeral_order_items i
     JOIN ephemeral_products p ON p.id = i.product_id
     WHERE i.order_id = o.id)
  ) as total_amount
FROM amaps a
JOIN ephemeral_orders o ON o.amap_id = a.id
WHERE o.delivery_date >= CURRENT_DATE
GROUP BY a.id, a.name, o.delivery_date;

CREATE UNIQUE INDEX idx_delivery_schedule_unique 
ON delivery_schedule(amap_id, delivery_date);

-- Function to refresh all materialized views
CREATE OR REPLACE FUNCTION refresh_all_materialized_views()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY order_statistics;
  REFRESH MATERIALIZED VIEW CONCURRENTLY product_usage_statistics;
  REFRESH MATERIALIZED VIEW CONCURRENTLY delivery_schedule;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate order total efficiently
CREATE OR REPLACE FUNCTION calculate_order_total(p_order_id uuid)
RETURNS decimal AS $$
SELECT COALESCE(
  sum(p.price * i.quantity),
  0
)
FROM ephemeral_order_items i
JOIN ephemeral_products p ON p.id = i.product_id
WHERE i.order_id = p_order_id;
$$ LANGUAGE sql SECURITY DEFINER;

-- Add comments
COMMENT ON MATERIALIZED VIEW order_statistics IS 'Monthly order statistics by AMAP';
COMMENT ON MATERIALIZED VIEW product_usage_statistics IS 'Product usage and revenue statistics';
COMMENT ON MATERIALIZED VIEW delivery_schedule IS 'Upcoming delivery schedule with order counts';
COMMENT ON FUNCTION refresh_all_materialized_views IS 'Refreshes all materialized views concurrently';
COMMENT ON FUNCTION calculate_order_total IS 'Efficiently calculates the total amount for an order';