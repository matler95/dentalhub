-- Hub: schemat bazowy (plan sekcja 6)
create extension if not exists pgcrypto;

create type org_role as enum ('owner','admin','doctor','staff');
create type member_status as enum ('invited','active','revoked');
create type scan_status as enum ('pending','clean','infected','unscanned','failed');

create table organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  kind text not null check (kind in ('practice','personal')),
  retention_days int not null default 30 check (retention_days between 1 and 365),
  created_at timestamptz not null default now()
);

create table memberships (
  org_id uuid not null references organizations on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  role org_role not null,
  status member_status not null default 'invited',
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  primary key (org_id, user_id)
);
create index memberships_user_idx on memberships (user_id) where status = 'active';

create table drop_links (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations on delete cascade,
  recipient_user_id uuid not null references auth.users,
  label text not null check (length(trim(label)) > 0),
  token_hash bytea not null unique check (length(token_hash) = 32), -- sha256; token nie jest przechowywany
  expires_at timestamptz,
  max_file_mb int not null default 25 check (max_file_mb between 1 and 50),
  max_files_per_day int not null default 100 check (max_files_per_day between 1 and 1000),
  revoked_at timestamptz,
  created_by uuid not null references auth.users,
  created_at timestamptz not null default now()
);
create index drop_links_org_idx on drop_links (org_id);

create table items (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations on delete cascade,
  recipient_user_id uuid references auth.users,          -- null = skrzynka gabinetu (UC3)
  drop_link_id uuid references drop_links,
  uploader_user_id uuid references auth.users,           -- null przy wysyłaniu linkiem
  uploader_label text,
  file_name text not null,
  mime text not null,
  size_bytes bigint not null check (size_bytes > 0),
  storage_path text not null unique,
  scan scan_status not null default 'pending',
  note text,
  created_at timestamptz not null default now(),
  first_opened_at timestamptz,
  archived_at timestamptz,
  expires_at timestamptz not null                        -- ustawiane triggerem
);
create index items_inbox_idx on items (recipient_user_id, created_at desc) where archived_at is null;
create index items_org_idx on items (org_id, created_at desc);
create index items_expiry_idx on items (expires_at);

create table audit_log (                                  -- append-only
  id bigserial primary key,
  at timestamptz not null default now(),
  actor_user_id uuid,
  actor_kind text not null check (actor_kind in ('user','drop_link','system')),
  action text not null,
  org_id uuid,
  item_id uuid,
  ip_hash bytea,
  meta jsonb not null default '{}'
);
create index audit_org_idx on audit_log (org_id, at desc);

create table push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now()
);
create index push_user_idx on push_subscriptions (user_id);

-- Helper: stały search_path, security definer (omija RLS memberships, brak rekurencji)
create function is_active_member(_org uuid, _roles org_role[] default null)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from memberships m
    where m.org_id = _org and m.user_id = auth.uid() and m.status = 'active'
      and (_roles is null or m.role = any(_roles)));
$$;
revoke all on function is_active_member(uuid, org_role[]) from public;
grant execute on function is_active_member(uuid, org_role[]) to authenticated, service_role;

-- items.expires_at = created_at + retention_days (nie ufamy klientowi)
create function items_set_expiry() returns trigger language plpgsql
security definer set search_path = public as $$
begin
  new.expires_at := coalesce(new.created_at, now())
    + make_interval(days => (select retention_days from organizations where id = new.org_id));
  return new;
end $$;
create trigger items_set_expiry_trg before insert on items
  for each row execute function items_set_expiry();

-- odebranie dostępu: znacznik czasu + wpis audytu
create function memberships_on_revoke() returns trigger language plpgsql
security definer set search_path = public as $$
begin
  if new.status = 'revoked' and old.status <> 'revoked' then
    new.revoked_at := now();
    insert into audit_log (actor_user_id, actor_kind, action, org_id, meta)
    values (auth.uid(), 'user', 'member.revoked', new.org_id, jsonb_build_object('user_id', new.user_id));
  end if;
  return new;
end $$;
create trigger memberships_revoke_trg before update on memberships
  for each row execute function memberships_on_revoke();

-- audit_log: append-only dla wszystkich, także service role
create function audit_log_immutable() returns trigger language plpgsql as $$
begin
  raise exception 'audit_log is append-only';
end $$;
create trigger audit_log_no_update before update or delete on audit_log
  for each row execute function audit_log_immutable();
create trigger audit_log_no_truncate before truncate on audit_log
  for each statement execute function audit_log_immutable();
