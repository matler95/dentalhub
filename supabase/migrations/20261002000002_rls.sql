-- Hub: RLS i uprawnienia. Zasada: klient tylko czyta (przez RLS); zapis przez Edge Functions (service_role)
alter table organizations      enable row level security;
alter table memberships        enable row level security;
alter table drop_links         enable row level security;
alter table items              enable row level security;
alter table audit_log          enable row level security;
alter table push_subscriptions enable row level security;

revoke all on organizations, memberships, drop_links, items, audit_log, push_subscriptions from anon, authenticated;
grant select on organizations, memberships, items, audit_log to authenticated;
grant select (id, org_id, recipient_user_id, label, expires_at, max_file_mb, max_files_per_day,
              revoked_at, created_by, created_at) on drop_links to authenticated;
grant select, insert, delete on push_subscriptions to authenticated;
grant usage, select on sequence audit_log_id_seq to service_role;

create policy orgs_select on organizations for select
  using (is_active_member(id));

create policy memberships_select on memberships for select
  using (
    (user_id = auth.uid() and status <> 'revoked')
    or is_active_member(org_id, array['owner','admin']::org_role[])
  );

create policy drop_links_select on drop_links for select
  using (
    is_active_member(org_id, array['owner','admin']::org_role[])
    or (recipient_user_id = auth.uid() and is_active_member(org_id))
  );

-- Plik widzi wyłącznie odbiorca (lub członek skrzynki gabinetu przy recipient null), póki członkostwo aktywne
create policy items_select on items for select
  using (
    is_active_member(org_id)
    and (
      recipient_user_id = auth.uid()
      or (recipient_user_id is null
          and is_active_member(org_id, array['owner','admin','staff']::org_role[]))
    )
    and scan in ('clean','unscanned')
    and expires_at > now()
  );

create policy audit_select on audit_log for select
  using (org_id is not null and is_active_member(org_id, array['owner','admin']::org_role[]));

create policy push_select on push_subscriptions for select using (user_id = auth.uid());
create policy push_insert on push_subscriptions for insert with check (user_id = auth.uid());
create policy push_delete on push_subscriptions for delete using (user_id = auth.uid());

-- Jedyny zapis klienta na items: archiwizacja własnego pliku
create function archive_item(_item uuid, _archived boolean default true)
returns void language plpgsql security definer set search_path = public as $$
declare _org uuid;
begin
  update items set archived_at = case when _archived then now() else null end
  where id = _item
    and recipient_user_id = auth.uid()
    and is_active_member(org_id)
  returning org_id into _org;
  if _org is null then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  insert into audit_log (actor_user_id, actor_kind, action, org_id, item_id)
  values (auth.uid(), 'user', case when _archived then 'item.archived' else 'item.unarchived' end, _org, _item);
end $$;
revoke all on function archive_item(uuid, boolean) from public, anon;
grant execute on function archive_item(uuid, boolean) to authenticated;
