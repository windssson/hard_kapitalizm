alter table public.chat_messages enable row level security;

revoke insert, update, delete on table public.chat_messages from anon, authenticated;
grant select on table public.chat_messages to authenticated;

drop policy if exists "Authenticated users can read chat messages" on public.chat_messages;
create policy "Authenticated users can read chat messages"
on public.chat_messages
for select
to authenticated
using (true);

drop function if exists public.send_chat_message(text);
create function public.send_chat_message(p_content text)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_player_id uuid := auth.uid();
  v_content text := btrim(coalesce(p_content, ''));
  v_player public.players%rowtype;
  v_last_message_at timestamptz;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if v_content = '' then
    raise exception 'Mesaj bos olamaz.';
  end if;

  if char_length(v_content) > 200 then
    raise exception 'Mesaj 200 karakterden uzun olamaz.';
  end if;

  select *
  into v_player
  from public.players
  where id = v_player_id;

  if not found then
    raise exception 'Oyuncu kaydi bulunamadi.';
  end if;

  select max(cm.created_at)
  into v_last_message_at
  from public.chat_messages cm
  where cm.player_id = v_player_id;

  if v_last_message_at is not null and now() - v_last_message_at < interval '3 seconds' then
    raise exception '3 saniyede bir mesaj gonderilebilir.';
  end if;

  insert into public.chat_messages (
    player_id,
    player_name,
    avatar_id,
    player_level,
    content
  )
  values (
    v_player_id,
    coalesce(nullif(v_player.player_name, ''), 'Oyuncu'),
    coalesce(
      nullif(v_player.google_avatar_url, ''),
      nullif(v_player.avatar_id, ''),
      'ae1.webp'
    ),
    greatest(coalesce(v_player.level, 1), 1),
    v_content
  );
end;
$function$;

revoke all on function public.send_chat_message(text) from public, anon;
grant execute on function public.send_chat_message(text) to authenticated;
