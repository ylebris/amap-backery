-- Suppression des données existantes
DELETE FROM amap_baker_assignments;
DELETE FROM amap_members;
DELETE FROM amaps;
DELETE FROM user_roles;
DELETE FROM users;

-- Suppression des données d'authentification Supabase
DELETE FROM auth.identities;
DELETE FROM auth.sessions;
DELETE FROM auth.refresh_tokens;
DELETE FROM auth.users;