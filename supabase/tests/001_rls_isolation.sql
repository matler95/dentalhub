begin;
select plan(37);

-- ===== dane testowe (jako superuser) =====
-- użytkownicy
insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-000000000001','alice@x'),  -- lekarz w A i B
  ('a0000000-0000-0000-0000-000000000002','bob@x'),    -- lekarz w A
  ('a0000000-0000-0000-0000-000000000003','carol@x'),  -- admin A
  ('a0000000-0000-0000-0000-000000000004','dave@x'),   -- admin B
  ('a0000000-0000-0000-0000-000000000005','eve@x'),    -- lekarz A, odwołana
  ('a0000000-0000-0000-0000-000000000006','frank@x');  -- staff A

insert into organizations (id, name, kind, retention_days) values
  ('b0000000-0000-0000-0000-00000000000a','Gabinet A','practice',30),
  ('b0000000-0000-0000-0000-00000000000b','Gabinet B','practice',7);

insert into memberships (org_id, user_id, role, status) values
  ('b0000000-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','doctor','active'),
  ('b0000000-0000-0000-0000-00000000000b','a0000000-0000-0000-0000-000000000001','doctor','active'),
  ('b0000000-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000002','doctor','active'),
  ('b0000000-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000003','admin','active'),
  ('b0000000-0000-0000-0000-00000000000b','a0000000-0000-0000-0000-000000000004','admin','active'),
  ('b0000000-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000005','doctor','revoked'),
  ('b0000000-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000006','staff','active');

insert into items (id, org_id, recipient_user_id, file_name, mime, size_bytes, storage_path, scan) values
  ('c0000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','i1.pdf','application/pdf',10,'a/1/x','clean'),
  ('c0000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000002','i2.pdf','application/pdf',10,'a/2/x','clean'),
  ('c0000000-0000-0000-0000-000000000003','b0000000-0000-0000-0000-00000000000b','a0000000-0000-0000-0000-000000000001','i3.pdf','application/pdf',10,'b/3/x','unscanned'),
  ('c0000000-0000-0000-0000-000000000004','b0000000-0000-0000-0000-00000000000a',null,'i4.pdf','application/pdf',10,'a/4/x','clean'),
  ('c0000000-0000-0000-0000-000000000005','b0000000-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','i5.pdf','application/pdf',10,'a/5/x','pending'),
  ('c0000000-0000-0000-0000-000000000006','b0000000-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','i6.pdf','application/pdf',10,'a/6/x','clean'),
  ('c0000000-0000-0000-0000-000000000007','b0000000-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','i7.exe','application/x-msdownload',10,'a/7/x','infected');
update items set expires_at = now() - interval '1 day' where id = 'c0000000-0000-0000-0000-000000000006';

insert into drop_links (id, org_id, recipient_user_id, label, token_hash, created_by) values
  ('d0000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','Recepcja',
   decode(repeat('ab',32),'hex'),'a0000000-0000-0000-0000-000000000003');

insert into audit_log (actor_kind, action, org_id) values
  ('system','test.a','b0000000-0000-0000-0000-00000000000a'),
  ('system','test.b','b0000000-0000-0000-0000-00000000000b');

insert into push_subscriptions (user_id, endpoint, p256dh, auth) values
  ('a0000000-0000-0000-0000-000000000002','https://push/bob','k','a');

-- ===== trigger retencji (superuser) =====
select is((select expires_at - created_at from items where id='c0000000-0000-0000-0000-000000000003'),
          interval '7 days', 'expires_at = created_at + retention_days (org B: 7 dni)');
select is((select (expires_at - created_at) from items where id='c0000000-0000-0000-0000-000000000001'),
          interval '30 days', 'expires_at = created_at + retention_days (org A: 30 dni)');

-- ===== alice: lekarz w A i B =====
set local role authenticated;
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001', true);
select results_eq($$select id::text from items order by id$$,
  $$values ('c0000000-0000-0000-0000-000000000001'),('c0000000-0000-0000-0000-000000000003')$$,
  'alice widzi tylko własne pliki: czyste/nieskanowane, niewygasłe (bez cudzych, pending, infected, expired)');
select is((select count(*)::int from organizations), 2, 'alice widzi swoje 2 gabinety');
select is((select count(*)::int from memberships), 2, 'alice widzi tylko własne członkostwa');
select is((select count(*)::int from drop_links), 1, 'alice (odbiorca) widzi swój link do wrzucania');
select is((select count(*)::int from audit_log), 0, 'lekarz bez roli admin nie widzi audytu');
select throws_ok($$select token_hash from drop_links$$, '42501', null, 'token_hash niedostępny dla klienta');
select throws_ok($$insert into items (org_id,recipient_user_id,file_name,mime,size_bytes,storage_path,expires_at)
  values ('b0000000-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','x','x',1,'a/z/z',now())$$,
  '42501', null, 'klient nie może wstawiać do items');
select throws_ok($$update items set note='hack'$$, '42501', null, 'klient nie może aktualizować items');
select throws_ok($$delete from items$$, '42501', null, 'klient nie może usuwać z items');
select throws_ok($$insert into audit_log (actor_kind, action) values ('user','fake')$$, '42501', null, 'klient nie zapisuje audytu');
select lives_ok($$insert into push_subscriptions (user_id,endpoint,p256dh,auth)
  values ('a0000000-0000-0000-0000-000000000001','https://push/alice','k','a')$$, 'alice rejestruje własną subskrypcję push');
select throws_ok($$insert into push_subscriptions (user_id,endpoint,p256dh,auth)
  values ('a0000000-0000-0000-0000-000000000002','https://push/spoof','k','a')$$,
  '42501', null, 'alice nie rejestruje push za bob');
select is((select count(*)::int from push_subscriptions), 1, 'alice nie widzi push cudzych użytkowników');

-- archive_item
select lives_ok($$select archive_item('c0000000-0000-0000-0000-000000000001')$$, 'alice archiwizuje własny plik');
select isnt((select archived_at from items where id='c0000000-0000-0000-0000-000000000001'), null, 'archived_at ustawione');
select throws_ok($$select archive_item('c0000000-0000-0000-0000-000000000002')$$, 'P0002', null,
  'alice nie zarchiwizuje cudzego pliku');

-- ===== bob =====
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002', true);
select results_eq($$select id::text from items$$, $$values ('c0000000-0000-0000-0000-000000000002')$$,
  'bob widzi tylko swój plik (nie widzi plików alice w tym samym gabinecie)');
select is((select count(*)::int from push_subscriptions), 1, 'bob widzi tylko własną subskrypcję');

-- ===== carol: admin A =====
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000003', true);
select results_eq($$select id::text from items$$, $$values ('c0000000-0000-0000-0000-000000000004')$$,
  'admin A widzi tylko skrzynkę gabinetu, nie pliki adresowane do lekarzy');
select is((select count(*)::int from audit_log where org_id='b0000000-0000-0000-0000-00000000000b'), 0,
  'admin A nie widzi audytu gabinetu B');
select ok((select count(*) from audit_log where org_id='b0000000-0000-0000-0000-00000000000a') >= 1,
  'admin A widzi audyt gabinetu A (w tym wpis o archiwizacji)');
select is((select count(*)::int from memberships), 5, 'admin A widzi członków swojego gabinetu');
select is((select count(*)::int from drop_links), 1, 'admin A widzi linki swojego gabinetu');

-- ===== dave: admin B =====
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000004', true);
select is((select count(*)::int from items), 0, 'admin B nie widzi niczego z gabinetu A (ani plików lekarzy)');
select is((select count(*)::int from memberships where org_id='b0000000-0000-0000-0000-00000000000a'), 0,
  'admin B nie widzi członków gabinetu A');
select is((select count(*)::int from drop_links), 0, 'admin B nie widzi linków gabinetu A');

-- ===== eve: odwołana =====
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000005', true);
select is((select count(*)::int from items) + (select count(*)::int from organizations)
        + (select count(*)::int from memberships) + (select count(*)::int from drop_links), 0,
  'odwołany członek nie widzi niczego');

-- ===== frank: staff =====
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000006', true);
select results_eq($$select id::text from items$$, $$values ('c0000000-0000-0000-0000-000000000004')$$,
  'staff widzi skrzynkę gabinetu, nie pliki lekarzy');

-- ===== anon =====
reset role; set local role anon;
select set_config('request.jwt.claim.sub','', true);
select throws_ok($$select 1 from items$$, '42501', null, 'anon nie czyta items');
select throws_ok($$select 1 from drop_links$$, '42501', null, 'anon nie czyta drop_links');

-- ===== natychmiastowe odebranie dostępu + audyt (superuser aktualizuje jak funkcja serwerowa) =====
reset role;
update memberships set status='revoked'
  where org_id='b0000000-0000-0000-0000-00000000000a' and user_id='a0000000-0000-0000-0000-000000000002';
select ok((select revoked_at is not null from memberships
  where org_id='b0000000-0000-0000-0000-00000000000a' and user_id='a0000000-0000-0000-0000-000000000002'),
  'revoked_at ustawione triggerem');
set local role authenticated;
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002', true);
select is((select count(*)::int from items), 0, 'po odebraniu członkostwa bob natychmiast traci dostęp do plików');

-- ===== audit_log append-only (także dla superusera/service role) =====
reset role;
select throws_ok($$update audit_log set action='x'$$, 'P0001', 'audit_log is append-only', 'audit_log: brak UPDATE');
select throws_ok($$delete from audit_log$$, 'P0001', 'audit_log is append-only', 'audit_log: brak DELETE');
select throws_ok($$truncate audit_log$$, 'P0001', 'audit_log is append-only', 'audit_log: brak TRUNCATE');

select * from finish();
rollback;
