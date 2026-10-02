# Hub plików dla lekarza w wielu gabinetach: plan i MVP

Nazwa robocza: **Hub**. Data: 2 października 2026. Podstawa: *analiza-rynku-hub-plikow-dla-lekarzy-v3.md*.
Oznaczenia pewności jak w analizie: **[W]** zweryfikowane, **[D]** deklaracja producenta, **[N]** do sprawdzenia, **[H]** hipoteza lub decyzja projektowa. To nie jest porada prawna ani finansowa.

---

## 0. Streszczenie

**Produkt:** jedno konto lekarza (passkey), wiele gabinetów, jeden inbox plików. Recepcja i laboratoria wrzucają pliki przez link bez konta (link tylko do wysyłania, nigdy do odczytu). Lekarz dostaje powiadomienie i otwiera plik w 2 tapnięciach.

**Strategia w trzech zdaniach:**
1. Budujemy POC na darmowym i otwartym stosie (React/TS PWA + Supabase w UE), z architekturą, która przy wzroście przechodzi na płatne plany bez przepisywania.
2. POC działa **wyłącznie na plikach bez danych pacjentów**. Dane pacjentów włączamy dopiero po przejściu Gate 1 (prawnik/IOD, umowy powierzenia z każdą placówką, plan płatny z kopiami zapasowymi, test penetracyjny). Analiza wskazuje to jako ryzyko nr 1, więc nie traktujemy tego jako formalności.
3. Zanim napiszemy dużo kodu, robimy tydzień 0 (inwentaryzacja systemów gabinetowych i plików, test push na iPhonie). Jeśli wyniki wskażą, że problem rozwiązuje konfiguracja istniejących narzędzi, zatrzymujemy się (kryteria no-go z sekcji 9.4 analizy).

**Czas:** tydzień 0 + ok. 8 tygodni do pilotażu u kolegi na plikach bez danych pacjentów [H]. Dane pacjentów: osobna decyzja po Gate 1.
**Koszt POC:** 0 zł infrastruktury (plus domena). Pilotaż z danymi pacjentów: rząd 150-250 zł/mies. [H, sekcja 10].

---

## 1. Zasady projektowe (guardrails)

| # | Zasada | Konsekwencja |
|---|---|---|
| G1 | **UX przed funkcjami.** Każdy ekran ma jedno główne działanie | Brak funkcji "na zapas"; lista "Won't" w sekcji 3 jest świadoma |
| G2 | **Bezpieczeństwo domyślne, nie opcjonalne** | RLS na każdej tabeli od pierwszej migracji, testy autoryzacji w CI, link do wrzucania jest write-only |
| G3 | **Minimalizacja danych** | Retencja domyślnie 30 dni (inbox, nie archiwum); powiadomienia bez nazw plików i danych pacjentów; brak indeksowania treści |
| G4 | **Placówka jest świadomą stroną** | Gabinet = organizacja z własnym adminem; odebranie dostępu (UC5) działa natychmiast i bez wpływu na inne gabinety |
| G5 | **Neutralność wobec dostawców** | Brak integracji z PMS w MVP; hub działa obok FELG/Proassist/innych (to jedyny wyróżnik wg analizy) |
| G6 | **Bez lock-inu i bez przepisywania** | Wszystko oparte na Postgresie, S3-kompatybilnym storage i standardach (WebAuthn, Web Push, tus); Supabase jest open source i można go później hostować samemu w UE [W] |
| G7 | **Mierzymy zachowanie, nie funkcje** | Metryki z sekcji 2.2 mierzone od pierwszego dnia pilotażu (bez danych osobowych) |

---

## 2. Wymagania i ich pokrycie

### 2.1 Wymagania kolegi → status w MVP

| Wymaganie | Pokrycie | Jak |
|---|---|---|
| Wszystkie gabinety w jednym widoku z wyborem gabinetu | **Pełne** | Inbox zbiorczy + chipy gabinetów z licznikiem nieprzeczytanych |
| Pliki prywatne (widzi tylko on), od razu | **Pełne** | Plik ma `recipient_user_id`; RLS; realtime + push |
| Koniec rozproszenia (mail, Drive, systemy placówek) | **Częściowe** | Rozwiązuje to tylko, jeśli placówki zmienią nawyk (główny konkurent wg analizy to nawyk). Mierzymy odsetek plików przez Hub |
| Mniej haseł i prostsze logowanie | **Częściowe** | Jedno logowanie do Huba: passkey/biometria. **Nie** redukuje haseł do systemów gabinetowych (zaznaczone w analizie 7.1) |
| Brak opóźnień jak na Google Drive | **Do zmierzenia** | Brak klienta synchronizującego; web + push; budżet wydajności w 4.4; test porównawczy w tygodniu 0 |
| Prywatna praktyka kolegi | **Pełne** | Własny gabinet to organizacja typu `personal` z tym samym modelem |

### 2.2 Use case'y i miary sukcesu

| UC | Priorytet | Uwagi |
|---|---|---|
| UC1 Lekarz widzi pliki ze wszystkich gabinetów | Must | Rdzeń |
| UC2 Recepcja wrzuca plik "dla dr X" | Must | Link bez konta |
| UC3 Lekarz wysyła plik do gabinetu | Should | Do skrzynki gabinetu (konta `staff`) |
| UC4 Wyszukiwanie po wszystkich gabinetach | Must (po nazwie, notatce, nadawcy) | Bez przeszukiwania treści plików |
| UC5 Odebranie dostępu odchodzącej osobie | Must | Panel admina gabinetu |
| UC6 Laboratorium / specjalista | Could | Tylko jako link do wrzucania z etykietą. Nie konkurujemy z 3Shape/Medit (analiza 3.3) |

**Miary (z analizy 1) [H]:** mediana czasu wrzucenie → otwarcie < 1 min; ≥ 80% plików "dla lekarza" przez Hub po 3 tygodniach; 1 logowanie dziennie; ≥ 2 z 3 gabinetów wrzuca regularnie bez przypominania.

---

## 3. Zakres MVP (MoSCoW)

**Must (POC, tygodnie 1-6)**
- Konto lekarza: passkey + zapasowe logowanie e-mailowym kodem; zarządzanie urządzeniami i sesjami
- Organizacje i członkostwa 1 użytkownik : N organizacji, przełącznik gabinetu, zaproszenia
- Linki do wrzucania (write-only) per gabinet i per lekarz, odwoływalne, z limitami; wznawialne wysyłanie
- Potwierdzenie dostarczenia dla nadawcy ("Dr X otrzymał(a) plik o 14:32")
- Inbox zbiorczy: filtr gabinetu, nieprzeczytane, archiwizacja, usuwanie, wyszukiwanie po metadanych
- Podgląd obrazów i PDF w aplikacji (bez wykonywania aktywnej zawartości)
- Powiadomienia: Web Push + e-mail jako kanał zapasowy; treść bez danych wrażliwych
- PWA: instalacja, szybki start, instrukcja dodania do ekranu głównego na iPhonie
- Dziennik audytu (kto, co, kiedy), retencja i automatyczne usuwanie, odebranie dostępu
- Testy RLS w CI, baner "tryb POC: bez danych pacjentów"

**Should (tygodnie 7-8, przed pilotażem szerszym)**
- Skanowanie antywirusowe i kwarantanna (ClamAV na małym VPS w UE)
- Panel admina gabinetu (członkowie, linki, audyt)
- UC3: wysyłanie do skrzynki gabinetu, notatki i etykiety przy pliku

**Could:** Web Share Target na Androidzie (iOS nie wspiera [N]); tryb ciemny; lista "ostatnio otwarte".

**Won't (świadomie, do czasu walidacji):** viewer DICOM/STL, czat, integracje z PMS i P1, E2EE, SSO/SCIM, płatności, aplikacje natywne (chyba że test push w tygodniu 0 tego wymusi), przechowywanie dokumentacji medycznej jako archiwum.

---

## 4. UX

### 4.1 Zasady
- **Inbox, nie dysk.** Ekran startowy to lista "nowe", nie drzewo folderów. Brak folderów w MVP
- **Maksymalnie 2 tapnięcia** od powiadomienia do otwartego pliku
- **Zero haseł:** passkey (Face ID/Touch ID/Windows Hello); odzyskiwanie kodem e-mail
- **Język prosty i polski od początku**, bez żargonu IT; teksty błędów mówią, co zrobić dalej
- **Zaufanie przez informację zwrotną:** nadawca widzi "dostarczono" i "otwarto"; lekarz widzi skąd plik i od kogo
- **iPhone first** (jak w pozostałych projektach), potem desktop

### 4.2 Kluczowe przepływy

**A. Lekarz, rano (UC1)**
Powiadomienie "Nowy plik w gabinecie A" → tap → plik otwarty. Alternatywnie: ikona na ekranie głównym → Face ID → inbox z chipami `Wszystkie | Gabinet A | Gabinet B | Gabinet C | Własny` i licznikami. Swipe w lewo = archiwizuj, w prawo = oznacz jako ważne [H].

**B. Recepcja, wrzucanie (UC2)** (najważniejszy ekran dla adopcji, bo nadawca nie ma konta)
Link zapisany w zakładce komputera recepcji lub jako skrót. Ekran: nagłówek "Plik dla dr Jan Kowalski" + duża strefa upuszczania, przycisk "Zrób zdjęcie dokumentu" na telefonie, opcjonalne pole "od kogo" (zapamiętane lokalnie), opcjonalna notatka. Po wysłaniu: zielony ekran "Dostarczono" z godziną. Brak logowania, brak rejestracji, brak cookies poza technicznymi.

**C. Onboarding lekarza (3 kroki, ok. 2 minuty)**
1. Zaproszenie e-mailem → utworzenie passkey
2. Na iPhonie: krótki ekran "Dodaj do ekranu głównego" z animowaną instrukcją (wymagane dla push na iOS [W])
3. Zgoda na powiadomienia **dopiero po instalacji i w kontekście** ("Powiadomimy Cię o nowych plikach"). Odmowa na iOS wymaga ponownej instalacji [W], więc nie prosimy zbyt wcześnie

**D. Admin gabinetu (UC5):** lista członków, przycisk "Odbierz dostęp" (natychmiastowy, z potwierdzeniem), lista linków z przyciskiem "Odnów link" (stary przestaje działać), podgląd audytu.

### 4.3 Stany i detale, które decydują o odbiorze
Puste stany z instrukcją; stan offline (powłoka aplikacji z cache, lista metadanych, **bez cache'owania treści plików** na urządzeniu); postęp wysyłania z możliwością wznowienia; czytelne błędy (zły typ, za duży plik, link wygasł); dostępność (kontrast, rozmiar celów dotyku ≥ 44 px, nawigacja klawiaturą, WCAG 2.2 AA jako cel).

### 4.4 Budżety wydajności (dla "bez opóźnień")
Pierwsze wyświetlenie inboxu < 1,5 s na 4G (po instalacji PWA); otwarcie podglądu < 1 s dla pliku < 5 MB; powiadomienie push < 5 s od zakończenia wysyłania (poza ograniczeniami iOS); wysyłanie wznawialne. Mierzone w CI (Lighthouse) i w pilotażu.

---

## 5. Architektura i stos (darmowy start → płatna ścieżka)

### 5.1 Stos

| Warstwa | POC (0 zł) | Kiedy i na co przechodzimy | Uwagi |
|---|---|---|---|
| Frontend | React + TypeScript + Vite, `vite-plugin-pwa`, Tailwind + shadcn/ui, TanStack Query | bez zmian | Znany stos; jedno wdrożenie |
| Hosting frontendu | Cloudflare Pages lub Vercel (plan darmowy) | płatny plan przy zespole/ruchu | Statyczne pliki, brak danych |
| Backend, baza, auth, storage | **Supabase** (Postgres + RLS + Auth + Storage + Edge Functions + Realtime), region UE (Frankfurt) | **Pro 25 USD/mies. przed pierwszymi realnymi danymi** [W]; potem własny hosting Supabase w UE (open source) lub dedykowany Postgres + MinIO/S3 | Plan Free: pauza po tygodniu bezczynności, brak kopii zapasowych, limit pliku 50 MB, 1 GB storage [W]. Pro: brak pauzy, codzienne kopie 7 dni, 100 GB [W] |
| Logowanie | Supabase Auth: **passkeys (beta od 28.05.2026)** [W] + kod e-mailowy jako zapasowe + TOTP | stabilizacja passkeys lub SimpleWebAuthn z własną tabelą poświadczeń; SSO (OIDC) dla placówek później | Ryzyko: funkcja w becie; zgłoszenia o problemach z niektórymi menedżerami passkeys (anegdota z dyskusji społeczności) [N]. Plan B zapisany w 5.3 |
| Storage plików | Supabase Storage (prywatny bucket), wysyłanie wznawialne (tus) | Cloudflare R2 / S3-kompatybilny w UE przy wzroście lub dużych plikach CBCT | Ścieżka `org_id/item_id/<uuid>`; nazwa pliku tylko w bazie |
| Czas rzeczywisty | Supabase Realtime (lista inboxu) | bez zmian | Tylko metadane |
| Push | Web Push (VAPID) wysyłany z Edge Function | OneSignal lub natywny wrapper (Capacitor) jeśli test iOS wykaże problem | **Test na fizycznym iPhonie w Polsce w tygodniu 0** (analiza 7.2) |
| E-mail | Dostawca z darmowym planem (np. Resend/Brevo) [N] | płatny plan przy wolumenie | Kanał zapasowy powiadomień i zaproszenia |
| Skan antywirusowy | ClamAV w kontenerze na małym VPS w UE (ok. 5 EUR/mies.) [N] | rozbudowa lub usługa zarządzana | **Nie używać VirusTotal i podobnych**: pliki trafiałyby do trzeciej strony |
| Błędy i monitoring | GlitchTip (self-host) lub Sentry Free z wyłączonym PII | płatny plan | Zero danych pacjentów w logach |
| CI/CD, jakość | GitHub Actions, Dependabot, gitleaks, Semgrep, Playwright, pgTAP | bez zmian | Wszystko darmowe dla małego projektu |
| Domena | **Własna domena od dnia 1** | — | RP ID passkeys jest związane z domeną, a instalacja PWA z originem. Zmiana domeny później unieważni passkeys i instalacje |

### 5.2 Przepływy techniczne

**Wrzucanie przez link (UC2)**
1. Przeglądarka otwiera `/d/<token>` (token 256-bitowy; w bazie tylko jego hash).
2. Edge Function `drop-init` sprawdza token, termin, odwołanie, limity i zwraca sesję wysyłania (podpisany URL / tus) ograniczoną do jednej ścieżki i rozmiaru. **Anon nie ma dostępu do storage ani do tabel.**
3. Po zakończeniu wysyłania `drop-complete` tworzy rekord `items` (`scan_status='pending'` lub `'unscanned'` w POC), sprawdza typ po sygnaturze (magic bytes) i rozmiar.
4. Po skanie (lub od razu w POC dla zaufanych typów) status `clean` → powiadomienie push/e-mail do odbiorcy i potwierdzenie "Dostarczono" u nadawcy.

**Otwieranie pliku (UC1)**
Klient wywołuje `get-file-url` → funkcja sprawdza członkostwo i prawa, zapisuje wpis audytu, zwraca podpisany URL ważny 60 s. Podgląd w sandboxie: obrazy i PDF renderowane w aplikacji; inne typy tylko do pobrania (`Content-Disposition: attachment`); nigdy inline HTML/SVG.

**Odebranie dostępu (UC5):** zmiana `memberships.status='revoked'` + unieważnienie sesji i subskrypcji push tego użytkownika dla tej organizacji. RLS przestaje zwracać dane natychmiast.

### 5.3 Plan B dla ryzyk technicznych
| Ryzyko | Plan B |
|---|---|
| Passkeys w becie zawodzą | SimpleWebAuthn + własna tabela poświadczeń + sesje w Supabase Auth; zapasowo kod e-mail + TOTP |
| Push na iOS w UE niewiarygodny | Capacitor (cienka aplikacja natywna) z APNs; e-mail jako kanał zapasowy (już w MVP) |
| Limity Supabase Free | Przejście na Pro przed danymi pacjentów (i tak wymagane) |
| Lock-in | Eksport schematu i danych; migracja do własnego Postgresa i S3 w UE |

---

## 6. Model danych i RLS

```sql
-- Rozszerzenia i typy
create extension if not exists pgcrypto;
create type org_role as enum ('owner','admin','doctor','staff');
create type member_status as enum ('invited','active','revoked');
create type scan_status as enum ('pending','clean','infected','unscanned','failed');

create table organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind text not null check (kind in ('practice','personal')),
  retention_days int not null default 30 check (retention_days between 1 and 365),
  created_at timestamptz not null default now()
);

create table memberships (
  org_id uuid references organizations on delete cascade,
  user_id uuid references auth.users on delete cascade,
  role org_role not null,
  status member_status not null default 'invited',
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  primary key (org_id, user_id)
);

create table drop_links (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations on delete cascade,
  recipient_user_id uuid not null references auth.users,
  label text not null,                    -- np. "Recepcja", "Laboratorium X"
  token_hash bytea not null unique,       -- sha256 tokenu; token nie jest przechowywany
  expires_at timestamptz,
  max_file_mb int not null default 25,
  max_files_per_day int not null default 100,
  revoked_at timestamptz,
  created_by uuid not null references auth.users,
  created_at timestamptz not null default now()
);

create table items (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations on delete cascade,
  recipient_user_id uuid references auth.users,  -- null = skrzynka gabinetu (UC3)
  drop_link_id uuid references drop_links,
  uploader_user_id uuid references auth.users,   -- null przy wysyłaniu linkiem
  uploader_label text,                           -- wpisane przez nadawcę ("Anna z recepcji")
  file_name text not null,
  mime text not null,
  size_bytes bigint not null,
  storage_path text not null unique,
  scan scan_status not null default 'pending',
  note text,
  created_at timestamptz not null default now(),
  first_opened_at timestamptz,
  archived_at timestamptz,
  expires_at timestamptz not null            -- created_at + retention_days
);

create table audit_log (                      -- append-only
  id bigserial primary key,
  at timestamptz not null default now(),
  actor_user_id uuid,
  actor_kind text not null check (actor_kind in ('user','drop_link','system')),
  action text not null,                       -- item.uploaded, item.opened, member.revoked, link.rotated...
  org_id uuid, item_id uuid,
  ip_hash bytea,                              -- hash z solą rotowaną; nie surowy adres IP
  meta jsonb not null default '{}'
);

create table push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  endpoint text not null unique,
  p256dh text not null, auth text not null,
  user_agent text, created_at timestamptz not null default now()
);

-- Helper (security definer, stały search_path)
create function is_active_member(_org uuid, _roles org_role[] default null)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from memberships m
    where m.org_id = _org and m.user_id = auth.uid() and m.status = 'active'
      and (_roles is null or m.role = any(_roles)));
$$;

-- RLS: włączone wszędzie
alter table organizations enable row level security;
alter table memberships   enable row level security;
alter table drop_links    enable row level security;
alter table items         enable row level security;
alter table audit_log     enable row level security;
alter table push_subscriptions enable row level security;

-- Plik widzi wyłącznie odbiorca (lub członek skrzynki gabinetu przy recipient null), tylko dopóki członkostwo aktywne
create policy items_select on items for select using (
  is_active_member(org_id) and (
    recipient_user_id = auth.uid()
    or (recipient_user_id is null and is_active_member(org_id, array['owner','admin','staff']::org_role[]))
  ) and scan in ('clean','unscanned')
);
-- Brak polityk insert/update/delete dla klienta: zapis tylko przez Edge Functions (service role).
-- Wyjątek: archiwizacja własnych plików przez funkcję RPC.

-- Audyt: odczyt tylko przez adminów gabinetu; brak update/delete dla nikogo
create policy audit_select on audit_log for select using (
  org_id is not null and is_active_member(org_id, array['owner','admin']::org_role[]));
```

**Decyzje modelu [H]:**
- Admin gabinetu widzi **metadane i audyt**, ale **nie treść** plików adresowanych do lekarza (spełnia "widzi je tylko on"). Ewentualna opcja organizacyjna "admin widzi pliki" dopiero po rozmowie z placówkami i prawnikiem.
- Odebranie członkostwa blokuje dostęp lekarza do plików tej organizacji (to placówka jest administratorem danych, analiza 5.2). Kopie lokalne pobrane wcześniej poza kontrolą Huba.
- Polityki dla `memberships`, `drop_links`, `organizations`, `push_subscriptions` piszemy w pierwszej migracji; zasada: użytkownik widzi własne członkostwa, admin widzi członków swojej organizacji, `drop_links` tylko admini i odbiorca.

**Testy (pgTAP, w CI):** lekarz A nie widzi plików lekarza B; odwołany członek nie widzi nic; admin gabinetu A nie widzi nic z gabinetu B; anon nie czyta niczego; nikt nie modyfikuje `audit_log`; link odwołany/wygasły nie przyjmuje plików.

---

## 7. Bezpieczeństwo

### 7.1 Model zagrożeń (skrót)

| Zagrożenie | Kontrola |
|---|---|
| Wyciek lub zgadnięcie linku do wrzucania | Link **write-only**; 256-bitowy token, tylko hash w bazie; wygasanie, limity dzienne i rozmiaru, rotacja jednym przyciskiem; Turnstile/rate limit przy nadużyciach. Najgorszy skutek wycieku: spam plikami, nie odczyt |
| Złośliwy plik (malware, polyglot, XSS przez SVG/HTML) | Allowlista typów (JPG, PNG, WebP, PDF, w Should: DOCX/XLSX), kontrola sygnatury, kwarantanna do czasu skanu, brak renderowania aktywnej zawartości, ścisły CSP, domena plików oddzielona od domeny aplikacji |
| Przejęcie konta lekarza | Passkey (odporne na phishing), krótkie sesje, ponowne uwierzytelnienie przy wrażliwych akcjach, lista urządzeń z odwołaniem, alert e-mail o nowym urządzeniu |
| Współdzielone urządzenie recepcji | Link do wrzucania nie wymaga logowania i nic nie pokazuje; konta `staff` na krótkich sesjach, brak "zapamiętaj mnie" na współdzielonych komputerach |
| Eskalacja uprawnień między gabinetami | RLS + testy pgTAP w CI; zapisy tylko przez funkcje serwerowe; brak `service role` w kliencie |
| Wyciek przez powiadomienia | Treść push: "Nowy plik w gabinecie A" (bez nazwy pliku, nadawcy, danych pacjenta); ekran blokady nic nie ujawnia |
| Wyciek przez logi i narzędzia | Brak danych treściowych w logach; PII scrubbing w Sentry/GlitchTip; IP tylko jako hash |
| Utrata lub zniszczenie danych | Pro: kopie dobowe 7 dni [W]; dodatkowo cotygodniowy zaszyfrowany `pg_dump` poza Supabase; test odtwarzania |
| Nadmierne przechowywanie | Retencja domyślnie 30 dni, usuwanie planowane (cron), usunięcie z storage i bazy |
| Naruszenie i obowiązek zgłoszenia (72 h, art. 33) | Procedura reakcji na incydent, rejestr zdarzeń, kontakt do IOD placówek [N, z prawnikiem] |

### 7.2 Lista kontrolna wdrożenia
- Szyfrowanie w tranzycie (TLS 1.2+, HSTS) i w spoczynku (zweryfikować u dostawcy [N])
- Nagłówki: ścisły CSP, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, `frame-ancestors 'none'`
- Sekrety poza repo (gitleaks w CI), rotacja kluczy, osobne projekty dev/prod
- Cel: **OWASP ASVS poziom 2** dla aplikacji i OWASP Top 10 przeglądane przed pilotażem [H]
- Zależności: Dependabot, `npm audit`, Semgrep w CI; blokada merge przy krytycznych
- 2FA i klucze sprzętowe dla kont deweloperskich (GitHub, Supabase, domena, hosting)
- Rejestr podprocesorów i lokalizacji danych (UE) prowadzony od początku
- Test penetracyjny (własny przegląd + zewnętrzny przed danymi pacjentów)

### 7.3 Poza zakresem POC (później)
E2EE (utrudnia podgląd i wyszukiwanie), HSM/KMS z własnymi kluczami klienta, SOC 2 (plan Team od 599 USD/mies. dodaje SOC 2 i SSO [W]) i certyfikaty. Decyzja po popycie i wymaganiach pierwszych placówek.

---

## 8. Zgodność i bramki decyzyjne

| Bramka | Warunek | Co odblokowuje |
|---|---|---|
| **Gate 0** (tydzień 0) | Ustalono systemy gabinetowe (4 miejsca); tydzień inwentaryzacji plików; test push na iPhonie w PL; zgoda każdej placówki na pilotaż z plikami bez danych pacjentów | Start budowy |
| **Gate P** (przed pilotażem) | Testy RLS zielone; przegląd bezpieczeństwa własny; baner POC; instrukcja dla recepcji | Pilotaż u kolegi na plikach **bez** danych pacjentów |
| **Gate 1** (przed danymi pacjentów) | Konsultacja z prawnikiem/IOD; **umowa powierzenia z każdą placówką** (analiza 5.2); umowa powierzenia lekarz-Hub dla własnego gabinetu; plan płatny z kopiami; region UE; skan antywirusowy; test penetracyjny; procedura incydentów; decyzja o roli Huba (podmiot przetwarzający) | Dane pacjentów (RTG, zlecenia) |
| **Gate 2** (przed sprzedażą innym) | Regulamin i polityka prywatności, DPA wzorcowe, rejestr podprocesorów, ubezpieczenie OC/cyber [N], pierwsze wywiady z lekarzami | Komercjalizacja |

Uwaga: w POC pliki "bez danych pacjentów" to np. grafiki, wzory dokumentów, instrukcje, dokumenty administracyjne **niezawierające danych osobowych**. Dane pracowników (umowy) to już dane osobowe i wymagają umowy powierzenia z placówką (analiza 5.2). Zasady oznaczania plików i szkolenie recepcji ("nie wrzucamy danych pacjentów w trybie POC") są elementem Gate P.

---

## 9. Plan realizacji

Szacunki dla jednego programisty pracującego z asystentem AI [H]; dostosuj do dostępnego czasu.

### Tydzień 0: walidacja i spike'i (3-5 dni)
- Inwentaryzacja systemów gabinetowych i pytanie wsparcia FELG/Proassist o multilogowanie i wymianę plików między kontami (analiza 9.4, krok 0)
- Tydzień dziennika plików u kolegi: od kogo, jaki typ, czy dane pacjenta, jak dotarł, ile trwało znalezienie
- **Spike 1:** minimalna PWA z Web Push na iPhonie kolegi (dodana do ekranu głównego); ocena niezawodności
- **Spike 2:** test opóźnień Google Drive (przeglądarka vs klient desktopowy vs mobilny) jako punkt odniesienia
- Rozmowa z każdą placówką: czy w ogóle zgodzi się na zewnętrzne narzędzie
- Opcjonalnie równolegle: wariant A0 na zarządzanym Nextcloudzie jako baseline do porównania UX

**Wyjście:** decyzja go/no-go wg kryteriów 9.5 analizy. Jeśli no-go: zatrzymujemy się lub zmieniamy kierunek.

### Sprint 1 (tyg. 1-2): fundament
Repo i struktura (sekcja 12), CI (lint, typy, Playwright, pgTAP, gitleaks), projekt Supabase UE (dev), migracje z sekcji 6, auth (passkey + kod e-mail), organizacje, członkostwa, zaproszenia, przełącznik gabinetu. **DoD:** testy RLS zielone, logowanie passkey na iPhonie i laptopie.

### Sprint 2 (tyg. 3-4): rdzeń wartości
Linki do wrzucania (`drop-init`, `drop-complete`), strona wysyłania z aparatem i postępem, wznawialne wysyłanie, potwierdzenie "Dostarczono", inbox zbiorczy z filtrami, realtime, podgląd obrazów/PDF, `get-file-url` z audytem. **DoD:** scenariusz UC2 → UC1 end-to-end w < 1 min na realnych urządzeniach.

### Sprint 3 (tyg. 5): powiadomienia i PWA
Web Push + e-mail zapasowy, onboarding instalacji, odnawianie subskrypcji, ustawienia powiadomień. **DoD:** push w < 5 s na Androidzie i iPhonie (zgodnie ze spike'iem), e-mail gdy push nie dotarł w 2 min.

### Sprint 4 (tyg. 6): kontrola i higiena danych
Odebranie dostępu (UC5), rotacja linków, dziennik audytu (widok), retencja i cron usuwania, zarządzanie urządzeniami i sesjami. **DoD:** odebranie dostępu działa natychmiast (test automatyczny).

### Sprint 5 (tyg. 7-8): utwardzenie i pilotaż
ClamAV i kwarantanna, panel admina gabinetu, UC3 (do skrzynki gabinetu), CSP i nagłówki, przegląd ASVS, testy dostępności, optymalizacja wydajności, instrukcja dla recepcji (1 strona), baner POC. **Gate P**, następnie pilotaż u kolegi (3 gabinety + własny) przez 3 tygodnie z metrykami z 2.2.

### Po pilotażu
- Decyzja wg 9.5 analizy (kryteria go/no-go)
- Jeśli go: **Gate 1**, przejście na Supabase Pro, umowy z placówkami, test penetracyjny, dopiero wtedy dane pacjentów
- Pilotaż u 5-10 lekarzy o podobnym modelu pracy, 10-15 wywiadów (analiza, faza 2), pomiar gotowości do zapłaty
- Panel dla placówek, SSO, viewer DICOM/STL tylko po potwierdzeniu popytu

### Jakość i testy (cały czas)
Testy jednostkowe logiki, pgTAP dla RLS, Playwright dla przepływów A-D, Lighthouse w CI, testy ręczne na fizycznych urządzeniach (iPhone, Android, laptop) przed każdym wydaniem.

---

## 10. Monetyzacja i ścieżka skalowania

### 10.1 Co i kiedy zaczyna kosztować [H]

| Etap | Wyzwalacz | Zmiana | Koszt orientacyjny/mies. |
|---|---|---|---|
| POC | start | Free: Supabase, hosting, GitHub Actions | 0 zł (+ domena ok. rocznie [N]) |
| Pilotaż z realnymi użytkownikami | brak pauzy i kopii wymagane | Supabase Pro [W] | ok. 25 USD |
| Dane pacjentów | Gate 1 | VPS ze skanem ClamAV, zewnętrzny pentest, prawnik (jednorazowo) | + ok. 5 EUR/mies. [N] + koszty jednorazowe |
| Więcej gabinetów lub duże pliki (CBCT) | storage > 100 GB lub pliki > 50 MB [W] | R2/S3 w UE, większy compute | zależnie od użycia |
| Komercjalizacja | płacący klienci | Płatności (Stripe/Przelewy24), e-mail transakcyjny, wsparcie, ubezpieczenie | koszty zmienne |
| Wymagania dużych klientów | SSO, SOC 2 | Supabase Team (599 USD) lub własny hosting [W] | — |

Rząd wielkości dla pilotażu z danymi pacjentów: **150-250 zł/mies.** [H].

### 10.2 Model przychodów (hipotezy do walidacji w wywiadach)
1. **Lekarz (Solo):** abonament za użytkownika, hipoteza start 39-59 zł/mies. [H]. Punkty odniesienia (Dropbox/Tresorit/Workspace) do sprawdzenia [N]
2. **Placówka (później):** pakiet za gabinet z panelem admina, SSO, audytem, retencją i umową powierzenia, hipoteza 99-199 zł/mies. [H]
3. Darmowy poziom dla nadawców (recepcja, laboratoria) jako motor wzrostu od dołu (analiza 9.2). Dla plików z danymi pacjentów warunek: świadoma zgoda placówki
4. Płatny jest **czas i spokój**, nie GB: komunikacja wartości przez zaoszczędzone minuty i bezpieczeństwo

### 10.3 Kryteria przejścia do wersji komercyjnej
Spełnione kryteria go z sekcji 9.5 analizy (m.in. ≥ 8 z 12 lekarzy potwierdza ból, ≥ 3 deklaruje zapłatę, ≥ 1 placówka podpisze umowę powierzenia).

---

## 11. Główne ryzyka (priorytet)

| Ryzyko | Poziom | Działanie w planie |
|---|---|---|
| Rozminięcie z faktycznymi plikami (dane pacjentów) | Najwyższe | Dziennik plików w tygodniu 0; Gate 1 |
| RODO i rola Huba | Najwyższe | POC bez danych pacjentów; umowy z placówkami; prawnik/IOD |
| Konkurencja nawyku (mail, komunikatory) | Wysokie | Link bez konta, potwierdzenie dostarczenia, metryka udziału w plikach |
| Funkcje już w PMS (FELG, Proassist) | Wysokie | Krok 0; pozycjonowanie neutralne |
| Passkeys w becie, push na iOS | Średnie | Spike'i w tygodniu 0, plany B (5.3) |
| Walidacja na jednej osobie | Średnie | Wywiady z lekarzami po pilotażu |
| Dryf zakresu | Średnie | Lista "Won't"; przegląd zakresu co sprint |
| Wsparcie użytkowników nietechnicznych | Średnie | Onboarding 3-krokowy; instrukcja 1-stronicowa dla recepcji |

---

## 12. Struktura repozytorium i funkcje serwerowe

```
hub/
├─ apps/web/                  # React + TS PWA (Vite)
│  ├─ src/features/{auth,inbox,drop,admin,settings}/
│  ├─ src/lib/{supabase,push,format}.ts
│  └─ public/{manifest.webmanifest,sw.ts}
├─ supabase/
│  ├─ migrations/             # schema + RLS (sekcja 6)
│  ├─ tests/                  # pgTAP: izolacja organizacji, audyt, linki
│  └─ functions/
│     ├─ drop-init/           # walidacja tokenu, sesja wysyłania
│     ├─ drop-complete/       # rekord items, kontrola typu, audyt
│     ├─ get-file-url/        # autoryzacja + audyt + podpisany URL (60 s)
│     ├─ notify/              # Web Push + e-mail zapasowy
│     ├─ revoke-member/       # odebranie dostępu + unieważnienie sesji
│     └─ retention-cron/      # usuwanie wygasłych plików
├─ scanner/                   # ClamAV (Docker) + mały worker (Sprint 5)
├─ .github/workflows/         # CI: lint, typy, pgTAP, Playwright, gitleaks, Semgrep
└─ docs/{threat-model.md,runbook-incident.md,dpa-checklist.md}
```

---

## 13. Pierwsze kroki (checklista startowa)

1. Kupić domenę i wybrać subdomenę aplikacji (RP ID passkeys i origin PWA)
2. Założyć projekty Supabase (dev; prod później) w regionie UE, włączyć 2FA na wszystkich kontach
3. Zrobić tydzień 0: inwentaryzacja PMS, dziennik plików, spike push na iPhonie, rozmowy z trzema placówkami
4. Założyć repo z CI i pierwszą migracją (sekcja 6) wraz z testami RLS
5. Ustalić z kolegą 5-10 realnych plików bez danych pacjentów do pilotażu

---

## Źródła zweryfikowane przy przygotowaniu planu (2.10.2026)
- Supabase, passkeys (beta, 28.05.2026): https://supabase.com/changelog/46458-passkeys-for-supabase-auth-beta
- Supabase, plany i limity (Free: pauza po tygodniu, 50 MB/plik, brak kopii; Pro: 100 GB, kopie 7 dni): https://supabase.com/pricing oraz https://supabase.com/docs/pricing
- Ceny Pro/Team i limity (zestawienie zewnętrzne): https://www.nocode.mba/articles/supabase-pricing
- Pozostałe ustalenia (prawo, rynek, iOS push, konkurencja): analiza rynku v3, załącznik B
