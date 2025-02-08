-- Reset our application tables
TRUNCATE TABLE amap_baker_assignments CASCADE;
TRUNCATE TABLE amap_members CASCADE;
TRUNCATE TABLE amaps CASCADE;
TRUNCATE TABLE user_roles CASCADE;
TRUNCATE TABLE users CASCADE;

-- Recreate our users table to match Supabase auth
CREATE TABLE IF NOT EXISTS public.users (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  email text NOT NULL,
  first_name text,
  last_name text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create user roles table
CREATE TABLE IF NOT EXISTS public.user_roles (
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('admin', 'user', 'baker')),
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, role)
);

-- Enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own profile"
  ON public.users
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can view their own roles"
  ON public.user_roles
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all users"
  ON public.users
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid()
      AND role = 'admin'
    )
  );

CREATE POLICY "Admins can manage all roles"
  ON public.user_roles
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid()
      AND role = 'admin'
    )
  );

-- Create indexes
CREATE INDEX IF NOT EXISTS users_email_idx ON public.users(email);
CREATE INDEX IF NOT EXISTS user_roles_user_role_idx ON public.user_roles(user_id, role);

-- Create trigger function for updating updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();