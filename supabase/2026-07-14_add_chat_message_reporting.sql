create table if not exists public.chat_message_reports (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  reporter_player_id uuid not null references public.players(id) on delete cascade,
  reported_player_id uuid not null references public.players(id) on delete cascade,
  reason text not null,
  details text not null default '',
  status text not null default 'open',
  created_at timestamptz not null default now(),
  constraint chat_message_reports_reason_check check (
    reason in ('spam', 'hakaret', 'uygunsuz_icerik', 'aldatma', 'diger')
  ),
  constraint chat_message_reports_status_check check (
    status in ('open', 'reviewed', 'resolved', 'dismissed')
  ),
  constraint chat_message_reports_unique_reporter unique (
    message_id,
    reporter_player_id
  )
);

create index if not exists chat_message_reports_message_idx
  on public.chat_message_reports (message_id, created_at desc);

create index if not exists chat_message_reports_status_idx
  on public.chat_message_reports (status, created_at desc);

alter table public.chat_message_reports enable row level security;

revoke all on table public.chat_message_reports from anon, authenticated;

drop function if exists public.report_chat_message(uuid, text, text);
create function public.report_chat_message(
  p_message_id uuid,
  p_reason text,
  p_details text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_reporter_id uuid := auth.uid();
  v_reason text := lower(btrim(coalesce(p_reason, '')));
  v_details text := left(btrim(coalesce(p_details, '')), 240);
  v_message public.chat_messages%rowtype;
  v_existing_id uuid;
begin
  if v_reporter_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if v_reason not in ('spam', 'hakaret', 'uygunsuz_icerik', 'aldatma', 'diger') then
    raise exception 'Gecersiz rapor nedeni.';
  end if;

  select *
  into v_message
  from public.chat_messages
  where id = p_message_id;

  if not found then
    raise exception 'Raporlanacak mesaj bulunamadi.';
  end if;

  if v_message.player_id = v_reporter_id then
    raise exception 'Kendi mesajinizi raporlayamazsiniz.';
  end if;

  select id
  into v_existing_id
  from public.chat_message_reports
  where message_id = p_message_id
    and reporter_player_id = v_reporter_id
  limit 1;

  if v_existing_id is not null then
    return jsonb_build_object(
      'success', true,
      'already_reported', true,
      'message', 'Bu mesaj zaten raporlanmis.'
    );
  end if;

  insert into public.chat_message_reports (
    message_id,
    reporter_player_id,
    reported_player_id,
    reason,
    details
  )
  values (
    p_message_id,
    v_reporter_id,
    v_message.player_id,
    v_reason,
    v_details
  );

  return jsonb_build_object(
    'success', true,
    'already_reported', false,
    'message', 'Raporunuz alindi.'
  );
end;
$function$;

revoke all on function public.report_chat_message(uuid, text, text) from public, anon;
grant execute on function public.report_chat_message(uuid, text, text) to authenticated;
