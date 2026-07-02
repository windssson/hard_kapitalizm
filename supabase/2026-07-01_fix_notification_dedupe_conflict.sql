drop index if exists public.idx_player_notifications_unique_dedupe;

create unique index if not exists idx_player_notifications_unique_dedupe
  on public.player_notifications(player_id, dedupe_key);
