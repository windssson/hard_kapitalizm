alter table public.chat_messages
  add column if not exists linked_listing_slot_id uuid,
  add column if not exists linked_product_id text,
  add column if not exists linked_product_name text,
  add column if not exists linked_product_icon text,
  add column if not exists linked_product_quality_level integer,
  add column if not exists linked_product_quantity integer,
  add column if not exists linked_product_price numeric(12, 2);

alter table public.chat_messages
  alter column linked_product_id type text using linked_product_id::text;

drop function if exists public.send_chat_message(text);
drop function if exists public.send_chat_message(
  text,
  uuid,
  text,
  text,
  text,
  integer,
  numeric
);

create function public.send_chat_message(
  p_content text,
  p_linked_listing_slot_id uuid default null,
  p_linked_product_id text default null,
  p_linked_product_name text default null,
  p_linked_product_icon text default null,
  p_linked_product_quality_level integer default null,
  p_linked_product_quantity integer default null,
  p_linked_product_price numeric default null
)
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
  v_has_linked_product boolean := p_linked_product_id is not null
    or p_linked_listing_slot_id is not null;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if v_content = '' and not v_has_linked_product then
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
    content,
    linked_listing_slot_id,
    linked_product_id,
    linked_product_name,
    linked_product_icon,
    linked_product_quality_level,
    linked_product_quantity,
    linked_product_price
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
    v_content,
    p_linked_listing_slot_id,
    p_linked_product_id,
    case
      when v_has_linked_product then coalesce(nullif(p_linked_product_name, ''), 'Urun')
      else null
    end,
    case
      when v_has_linked_product then coalesce(nullif(p_linked_product_icon, ''), 'default.webp')
      else null
    end,
    case
      when v_has_linked_product then greatest(coalesce(p_linked_product_quality_level, 1), 1)
      else null
    end,
    case
      when v_has_linked_product then greatest(coalesce(p_linked_product_quantity, 0), 0)
      else null
    end,
    case
      when v_has_linked_product then greatest(coalesce(p_linked_product_price, 0), 0)
      else null
    end
  );
end;
$function$;

revoke all on function public.send_chat_message(
  text,
  uuid,
  text,
  text,
  text,
  integer,
  integer,
  numeric
) from public, anon;

grant execute on function public.send_chat_message(
  text,
  uuid,
  text,
  text,
  text,
  integer,
  integer,
  numeric
) to authenticated;
