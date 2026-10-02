// DANE PRZYKŁADOWE (bez danych pacjentów). Zastąpione zapytaniem do Supabase w Sprincie 2.
export type Org = { id: string; name: string };
export type InboxItem = {
  id: string; orgId: string; fileName: string; from: string; sizeBytes: number; at: string; unread: boolean;
};
export const orgs: Org[] = [
  { id: "a", name: "Gabinet A" }, { id: "b", name: "Gabinet B" }, { id: "p", name: "Własny" },
];
const today = new Date();
const at = (h: number, m: number) => new Date(today.getFullYear(), today.getMonth(), today.getDate(), h, m).toISOString();
export const items: InboxItem[] = [
  { id: "1", orgId: "a", fileName: "wzor-zgody.pdf", from: "Recepcja", sizeBytes: 182_000, at: at(9, 14), unread: true },
  { id: "2", orgId: "b", fileName: "instrukcja-sterylizacji.pdf", from: "Anna", sizeBytes: 2_400_000, at: at(8, 2), unread: true },
  { id: "3", orgId: "a", fileName: "logo-gabinetu.png", from: "Recepcja", sizeBytes: 640_000, at: at(7, 41), unread: false },
  { id: "4", orgId: "p", fileName: "cennik-2026.pdf", from: "Ja", sizeBytes: 95_000, at: "2026-09-30T10:00:00.000Z", unread: false },
];
