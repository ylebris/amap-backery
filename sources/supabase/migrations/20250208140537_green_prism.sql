-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Les utilisateurs peuvent voir leur propre profil" ON auth.users;
DROP POLICY IF EXISTS "Les super admins peuvent gérer tous les utilisateurs" ON auth.users;
DROP POLICY IF EXISTS "Les utilisateurs peuvent voir leurs propres identités" ON auth.identities;

-- Activation de RLS sur les tables d'authentification
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;

-- Policies pour auth.users
CREATE POLICY "Les utilisateurs peuvent voir leur propre profil"
  ON auth.users
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Les super admins peuvent gérer tous les utilisateurs"
  ON auth.users
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND role = 'super_admin'
    )
  );

-- Policies pour les identités
CREATE POLICY "Les utilisateurs peuvent voir leurs propres identités"
  ON auth.identities
  FOR SELECT
  USING (user_id = auth.uid());

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS auth.generate_jwt(uuid);

-- Fonction pour générer un JWT
CREATE OR REPLACE FUNCTION auth.generate_jwt(user_id uuid)
RETURNS text AS $$
DECLARE
  jwt_secret text := current_setting('app.settings.jwt_secret', true);
  jwt_exp integer := 3600; -- 1 hour
  jwt_claims jsonb;
BEGIN
  SELECT jsonb_build_object(
    'sub', user_id::text,
    'email', email,
    'role', 'authenticated',
    'exp', extract(epoch from (now() + (jwt_exp || ' seconds')::interval))::integer
  )
  INTO jwt_claims
  FROM auth.users
  WHERE id = user_id;

  RETURN auth.sign(jwt_claims::json, jwt_secret);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;