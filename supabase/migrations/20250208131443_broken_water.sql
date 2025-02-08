-- Table de traçabilité des modifications de catalogues
CREATE TABLE IF NOT EXISTS catalog_change_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  catalog_id uuid REFERENCES product_catalogs(id) ON DELETE CASCADE,
  product_id uuid REFERENCES catalog_products(id) ON DELETE CASCADE,
  change_type text NOT NULL CHECK (change_type IN ('create', 'update', 'delete')),
  changed_by uuid REFERENCES users(id) NOT NULL,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz DEFAULT now()
);

-- Table de validation des catalogues
CREATE TABLE IF NOT EXISTS catalog_validations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  catalog_id uuid REFERENCES product_catalogs(id) ON DELETE CASCADE,
  validated_by uuid REFERENCES users(id) NOT NULL,
  validation_date timestamptz DEFAULT now(),
  comments text
);

-- Enable RLS
ALTER TABLE catalog_change_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_validations ENABLE ROW LEVEL SECURITY;

-- Fonction pour enregistrer les modifications de catalogue
CREATE OR REPLACE FUNCTION log_catalog_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO catalog_change_logs (
      catalog_id,
      product_id,
      change_type,
      changed_by,
      new_data
    ) VALUES (
      CASE 
        WHEN TG_TABLE_NAME = 'product_catalogs' THEN NEW.id
        WHEN TG_TABLE_NAME = 'catalog_products' THEN NEW.catalog_id
      END,
      CASE 
        WHEN TG_TABLE_NAME = 'catalog_products' THEN NEW.id
        ELSE NULL
      END,
      'create',
      auth.uid(),
      to_jsonb(NEW)
    );
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO catalog_change_logs (
      catalog_id,
      product_id,
      change_type,
      changed_by,
      old_data,
      new_data
    ) VALUES (
      CASE 
        WHEN TG_TABLE_NAME = 'product_catalogs' THEN NEW.id
        WHEN TG_TABLE_NAME = 'catalog_products' THEN NEW.catalog_id
      END,
      CASE 
        WHEN TG_TABLE_NAME = 'catalog_products' THEN NEW.id
        ELSE NULL
      END,
      'update',
      auth.uid(),
      to_jsonb(OLD),
      to_jsonb(NEW)
    );
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO catalog_change_logs (
      catalog_id,
      product_id,
      change_type,
      changed_by,
      old_data
    ) VALUES (
      CASE 
        WHEN TG_TABLE_NAME = 'product_catalogs' THEN OLD.id
        WHEN TG_TABLE_NAME = 'catalog_products' THEN OLD.catalog_id
      END,
      CASE 
        WHEN TG_TABLE_NAME = 'catalog_products' THEN OLD.id
        ELSE NULL
      END,
      'delete',
      auth.uid(),
      to_jsonb(OLD)
    );
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Triggers pour la traçabilité
CREATE TRIGGER log_catalog_changes
  AFTER INSERT OR UPDATE OR DELETE ON product_catalogs
  FOR EACH ROW
  EXECUTE FUNCTION log_catalog_change();

CREATE TRIGGER log_product_changes
  AFTER INSERT OR UPDATE OR DELETE ON catalog_products
  FOR EACH ROW
  EXECUTE FUNCTION log_catalog_change();

-- Fonction pour valider un catalogue
CREATE OR REPLACE FUNCTION validate_catalog(
  p_catalog_id uuid,
  p_comments text DEFAULT NULL
)
RETURNS void AS $$
BEGIN
  -- Vérifier les droits de validation
  IF NOT EXISTS (
    SELECT 1 FROM product_catalogs pc
    JOIN amap_members am ON am.amap_id = pc.amap_id
    WHERE pc.id = p_catalog_id
    AND am.user_id = auth.uid()
    AND am.role IN ('amap_admin', 'super_admin')
  ) THEN
    RAISE EXCEPTION 'Seuls les administrateurs AMAP peuvent valider les catalogues';
  END IF;

  -- Vérifier que le catalogue n'est pas déjà validé
  IF EXISTS (
    SELECT 1 FROM catalog_validations
    WHERE catalog_id = p_catalog_id
  ) THEN
    RAISE EXCEPTION 'Ce catalogue a déjà été validé';
  END IF;

  -- Enregistrer la validation
  INSERT INTO catalog_validations (
    catalog_id,
    validated_by,
    comments
  ) VALUES (
    p_catalog_id,
    auth.uid(),
    p_comments
  );

  -- Mettre à jour le statut du catalogue
  UPDATE product_catalogs
  SET status = 'active'
  WHERE id = p_catalog_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Policies pour les logs de modifications
CREATE POLICY "Les administrateurs peuvent voir les logs"
  ON catalog_change_logs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND role IN ('amap_admin', 'super_admin')
    )
  );

-- Policies pour les validations
CREATE POLICY "Les administrateurs peuvent gérer les validations"
  ON catalog_validations
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND role IN ('amap_admin', 'super_admin')
    )
  );

-- Indexes pour les performances
CREATE INDEX IF NOT EXISTS idx_catalog_change_logs_catalog ON catalog_change_logs(catalog_id);
CREATE INDEX IF NOT EXISTS idx_catalog_change_logs_product ON catalog_change_logs(product_id);
CREATE INDEX IF NOT EXISTS idx_catalog_change_logs_changed_by ON catalog_change_logs(changed_by);
CREATE INDEX IF NOT EXISTS idx_catalog_validations_catalog ON catalog_validations(catalog_id);
CREATE INDEX IF NOT EXISTS idx_catalog_validations_validator ON catalog_validations(validated_by);

COMMENT ON TABLE catalog_change_logs IS 'Historique des modifications des catalogues et produits';
COMMENT ON TABLE catalog_validations IS 'Validations des catalogues par les administrateurs';
COMMENT ON FUNCTION validate_catalog IS 'Valide un catalogue et le rend actif';