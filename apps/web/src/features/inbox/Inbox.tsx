import { useMemo, useState } from "react";
import { formatSize, formatWhen } from "../../lib/format";
import { items, orgs } from "./sample";

export function Inbox() {
  const [orgId, setOrgId] = useState<string | "all">("all");
  const visible = useMemo(() => items.filter((i) => orgId === "all" || i.orgId === orgId), [orgId]);
  const unreadBy = (id: string | "all") =>
    items.filter((i) => i.unread && (id === "all" || i.orgId === id)).length;

  const chips: { id: string | "all"; name: string }[] = [{ id: "all", name: "Wszystkie" }, ...orgs];

  return (
    <main className="mx-auto max-w-2xl px-4 pb-16">
      <h1 className="pt-6 pb-3 text-2xl font-semibold tracking-tight">Nowe pliki</h1>
      <nav aria-label="Gabinety" className="-mx-4 flex gap-2 overflow-x-auto px-4 pb-3">
        {chips.map((c) => {
          const active = c.id === orgId;
          const n = unreadBy(c.id);
          return (
            <button key={c.id} onClick={() => setOrgId(c.id)} aria-pressed={active}
              className={`min-h-11 shrink-0 rounded-full border px-4 text-sm font-medium ${
                active ? "border-brand bg-brand text-brand-ink" : "border-line bg-white text-ink"}`}>
              {c.name}{n > 0 && <span className={`ml-2 ${active ? "" : "text-unread"}`}>{n}</span>}
            </button>
          );
        })}
      </nav>
      {visible.length === 0 ? (
        <p className="mt-10 text-muted">Brak plików. Gdy recepcja wyśle plik, pojawi się tutaj i dostaniesz powiadomienie.</p>
      ) : (
        <ul className="divide-y divide-line rounded-xl border border-line bg-white">
          {visible.map((i) => (
            <li key={i.id}>
              <button className="flex min-h-14 w-full items-center gap-3 px-4 py-3 text-left">
                <span aria-hidden className={`size-2.5 shrink-0 rounded-full ${i.unread ? "bg-unread" : "bg-transparent"}`} />
                <span className="min-w-0 flex-1">
                  <span className={`block truncate ${i.unread ? "font-semibold" : ""}`}>{i.fileName}</span>
                  <span className="block truncate text-sm text-muted">
                    {orgs.find((o) => o.id === i.orgId)?.name} · od: {i.from} · {formatSize(i.sizeBytes)}
                  </span>
                </span>
                <time className="shrink-0 text-sm text-muted" dateTime={i.at}>{formatWhen(i.at)}</time>
              </button>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
