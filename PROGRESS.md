# Hub: dziennik postępu

Źródło prawdy o zakresie: `docs/plan-i-mvp.md`. Ten plik aktualizuję po każdym mniejszym milestonie.
Legenda: ✅ zrobione i zweryfikowane · 🟡 zrobione, niezweryfikowane (brak środowiska) · ⏳ w toku · ⬜ do zrobienia · 🙋 wymaga Twojej akcji

## Stan na teraz
**Faza:** Sprint 1 (fundament). Tydzień 0 jest po stronie człowieka (patrz niżej).
**Tryb POC:** wyłącznie pliki BEZ danych pacjentów (Gate 1 niezaliczony).

## Analiza planu (skrót decyzji, które wpływają na kod)
- Link do wrzucania jest **write-only**; w bazie tylko `sha256(token)`; anon nie ma dostępu do tabel ani storage.
- Zapis do `items`/`audit_log`/`drop_links` **wyłącznie przez Edge Functions** (service role). Klient ma tylko SELECT przez RLS + wąskie RPC (archiwizacja).
- Admin widzi metadane i audyt, **nie treść** plików adresowanych do lekarza.
- Push bez nazw plików i danych pacjentów. Brak cache'owania treści plików w PWA.
- Własna domena od dnia 1 (RP ID passkeys + origin PWA).

## Luki / niejasności wykryte w planie (do decyzji)
1. `items_select` wymaga `is_active_member(org_id)`, a lekarz `doctor` może też być odbiorcą w org, gdzie jest `invited` → nie zobaczy plików. To zamierzone, ale trzeba to potwierdzić.
2. Plan nie definiuje polityk RLS dla `memberships`, `drop_links`, `organizations`, `push_subscriptions` (tylko zasada słowna). Zapisuję je w migracji 0002 zgodnie z zasadą z sekcji 6.
3. Brak tabeli `devices/sessions` dla "zarządzania urządzeniami": zakładam, że bazujemy na sesjach Supabase Auth + `push_subscriptions` (do potwierdzenia w Sprincie 4).
4. `retention_days` jest w `organizations`, a `items.expires_at` ma być `created_at + retention_days`: dodaję trigger, żeby wartość nie zależała od klienta.
5. `ip_hash` wymaga rotowanej soli: potrzebna tabela/sekret na sól (decyzja przy `drop-init`).

## Milestony

### Tydzień 0 (Gate 0) 🙋
- ⬜ Inwentaryzacja systemów gabinetowych (4 miejsca) + pytanie do FELG/Proassist o multilogowanie
- ⬜ Dziennik plików u kolegi (7 dni)
- ⬜ Spike 1: Web Push na iPhonie (PWA na ekranie głównym)
- ⬜ Spike 2: opóźnienia Google Drive jako punkt odniesienia
- ⬜ Zgoda placówek na pilotaż z plikami bez danych pacjentów
- ⬜ Zakup domeny, projekt Supabase (dev, UE), 2FA na kontach

### Sprint 1: fundament
- ✅ M0 Analiza planu, plik progresu
- ✅ M1 Szkielet repo (apps/web, supabase, scanner, docs), `.gitignore`, `.env.example`, CI (gitleaks, web, pgTAP przez `supabase test db`, Semgrep). CI jeszcze niewypróbowane na GitHub (brak remote) → 🟡
- ✅ Środowisko lokalne do testów DB: Postgres 16 + pgTAP + pg_prove działa w sandboxie (lokalnie zamiast Supabase CLI)
- ✅ M2 Migracje `20261002000001_schema.sql` (tabele, enumy, indeksy, triggery: retencja, audyt odebrania dostępu, audit_log append-only) i `..._rls.sql` (RLS na wszystkich 6 tabelach, minimalne GRANT-y, `archive_item` RPC). Zaaplikowane na Postgresie 16 bez błędów.
  - Odstępstwa od planu (świadome): `items_select` dodatkowo wymaga `expires_at > now()`; `drop_links.token_hash` niewidoczny dla klienta (GRANT na kolumny); własne członkostwo `revoked` niewidoczne; `push_subscriptions` – klient może wstawiać/usuwać własne (rejestracja push bez funkcji serwerowej).
  - Uwaga do 5.2: `push_subscriptions` nie ma `org_id`, więc funkcja `notify` MUSI sprawdzać aktywne członkostwo odbiorcy przed wysyłką (zapisane jako wymaganie do Sprintu 3).
- ✅ M3 Testy pgTAP `supabase/tests/001_rls_isolation.sql`: **37/37 zielone** (`scripts/local-db/run-tests.sh`). Pokrycie: izolacja lekarzy w tym samym gabinecie, izolacja gabinetów, admin widzi skrzynkę/metadane ale nie pliki lekarzy, staff, odwołany członek, anon, natychmiastowa utrata dostępu po odebraniu, brak zapisu klienta (items/audit_log), ukryty `token_hash`, retencja, `archive_item`, push, audit_log append-only (UPDATE/DELETE/TRUNCATE).
  - Weryfikacja jakości testów: mutacja polityki `items_select` → 6 testów czerwonych; po przywróceniu zielone.
  - Nie pokryte w DB (będzie w testach Edge Functions): "link odwołany/wygasły nie przyjmuje plików".
- ✅ M4 Szkielet `apps/web`: Vite + React 19 + TS strict + Tailwind 4 + TanStack Query + supabase-js + `vite-plugin-pwa` (cache tylko powłoki, `runtimeCaching: []` → treści plików nie trafiają na urządzenie). `npm run typecheck`, `lint`, `build` przechodzą. Ekran Inbox z chipami gabinetów, licznikami nieprzeczytanych i banerem trybu POC na **danych przykładowych** (`features/inbox/sample.ts`). Klient Supabase zwraca `null` bez `.env`.
  - Nie zweryfikowane: wygląd na realnym iPhonie i Lighthouse (brak urządzenia/przeglądarki w sandboxie) → 🟡

## Następne milestony (Sprint 1, reszta)
- ⬜ M5 Auth: ekran logowania, passkey (Supabase Auth beta) + kod e-mail. **Wymaga 🙋 projektu Supabase (dev, UE) i domeny** – bez tego mogę przygotować kod i testy, ale nie zweryfikuję logowania.
- ⬜ M6 Organizacje: tworzenie gabinetu, zaproszenia, przełącznik gabinetu (zapytania do Supabase zamiast `sample.ts`)
- ⬜ M7 Test e2e Playwright dla przepływu logowania i przełącznika (po M5/M6)
- ⬜ Sprint 2: `drop-init` / `drop-complete` / `get-file-url` (Edge Functions, Deno) + testy odrzucania linków odwołanych/wygasłych

## Decyzje czekające na Ciebie 🙋
1. Potwierdź luki 1–5 z sekcji "Luki / niejasności".
2. Domena (RP ID passkeys) i projekt Supabase UE – blokują M5.
3. Wynik tygodnia 0 (zwłaszcza push na iPhonie) może zmienić plan na Capacitor, zanim zainwestujemy w Sprint 3.

## Jak uruchomić
- Testy DB lokalnie: `scripts/local-db/run-tests.sh` (Postgres + pgTAP) albo `supabase test db` z Supabase CLI.
- Web: `cd apps/web && npm ci && npm run dev`.
