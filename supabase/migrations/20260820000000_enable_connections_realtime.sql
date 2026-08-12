-- Phase 9.4.6.5: Enable Supabase Realtime for the connections table
--
-- This allows the Flutter client to subscribe to INSERT / UPDATE / DELETE
-- events on public.connections so connection state can synchronize
-- between screens and users without manual refresh.

ALTER PUBLICATION supabase_realtime ADD TABLE public.connections;
