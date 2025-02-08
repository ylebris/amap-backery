-- Indexes composites pour les requêtes fréquentes
CREATE INDEX idx_orders_date_status ON ephemeral_orders(delivery_date, status);
CREATE INDEX idx_orders_amap_date ON ephemeral_orders(amap_id, delivery_date);
CREATE INDEX idx_catalog_products_composite ON catalog_products(catalog_id, category, price);
CREATE INDEX idx_amap_members_role ON amap_members(amap_id, role);

-- Vue matérialisée pour les statistiques produits
CREATE MATERIALIZED VIEW product_statistics AS
SELECT 
  p.id,
  p.name,
  p.category,
  COUNT(DISTINCT oi.order_id) as total_orders,
  SUM(oi.quantity) as total_quantity,
  SUM(oi.quantity * p.price) as total_revenue,
  AVG(oi.quantity) as avg_quantity_per_order
FROM catalog_products p
LEFT JOIN ephemeral_order_items oi ON oi.product_id = p.id
LEFT JOIN ephemeral_orders o ON o.id = oi.order_id
WHERE o.status != 'cancelled'
GROUP BY p.id, p.name, p.category;

CREATE UNIQUE INDEX idx_product_statistics_id ON product_statistics(id);

-- Vue matérialisée pour le planning des livraisons
CREATE MATERIALIZED VIEW delivery_schedule AS
SELECT 
  dp.amap_id,
  dp.delivery_day,
  o.delivery_date,
  COUNT(DISTINCT o.id) as total_orders,
  COUNT(DISTINCT o.user_id) as total_customers,
  SUM(oi.quantity * p.price) as total_amount
FROM delivery_periods dp
JOIN ephemeral_orders o ON o.amap_id = dp.amap_id
JOIN ephemeral_order_items oi ON oi.order_id = o.id
JOIN catalog_products p ON p.id = oi.product_id
WHERE o.delivery_date BETWEEN dp.start_date AND dp.end_date
GROUP BY dp.amap_id, dp.delivery_day, o.delivery_date;

CREATE UNIQUE INDEX idx_delivery_schedule_composite 
ON delivery_schedule(amap_id, delivery_date);

-- Vue matérialisée pour le résumé des activités AMAP
CREATE MATERIALIZED VIEW amap_activity_summary AS
SELECT 
  a.id as amap_id,
  a.name as amap_name,
  COUNT(DISTINCT m.user_id) as total_members,
  COUNT(DISTINCT o.id) as total_orders,
  SUM(oi.quantity * p.price) as total_revenue,
  MAX(o.delivery_date) as last_delivery_date,
  COUNT(DISTINCT p.id) as total_products
FROM amaps a
LEFT JOIN amap_members m ON m.amap_id = a.id
LEFT JOIN ephemeral_orders o ON o.amap_id = a.id
LEFT JOIN ephemeral_order_items oi ON oi.order_id = o.id
LEFT JOIN catalog_products p ON p.id = oi.product_id
GROUP BY a.id, a.name;

CREATE UNIQUE INDEX idx_amap_activity_summary_id ON amap_activity_summary(amap_id);

-- Fonction pour rafraîchir toutes les vues matérialisées
CREATE OR REPLACE FUNCTION refresh_all_materialized_views()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY order_statistics;
  REFRESH MATERIALIZED VIEW CONCURRENTLY product_statistics;
  REFRESH MATERIALIZED VIEW CONCURRENTLY delivery_schedule;
  REFRESH MATERIALIZED VIEW CONCURRENTLY amap_activity_summary;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Commentaires
COMMENT ON MATERIALIZED VIEW product_statistics IS 'Statistiques détaillées des produits';
COMMENT ON MATERIALIZED VIEW delivery_schedule IS 'Planning des livraisons par AMAP';
COMMENT ON MATERIALIZED VIEW amap_activity_summary IS 'Résumé des activités par AMAP';
COMMENT ON FUNCTION refresh_all_materialized_views IS 'Rafraîchit toutes les vues matérialisées';