-- 0048_notifications.sql — Admin Notification Broadcast
CREATE TABLE IF NOT EXISTS public.admin_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text NOT NULL,
  filter jsonb,                     -- { "role": "MODERATOR", "is_pro": true } or null (all users)
  created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz
);

ALTER TABLE public.admin_notifications ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read their own notifications (filter-based check in app)
CREATE POLICY admin_notifications_select ON public.admin_notifications
  FOR SELECT TO authenticated USING (true);

-- Only service_role may insert (admin API uses service_role)
-- No INSERT/UPDATE/DELETE policy for anon/authenticated