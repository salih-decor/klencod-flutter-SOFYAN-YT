export type HistoryRow = { id: number; created: number; subject: string; track: string; mode: string };
export type HistoryItem = HistoryRow & { question: string; answer: string; review: string | null };

async function j<T>(r: Response): Promise<T> {
  if (!r.ok) {
    let m = r.statusText;
    try { m = (await r.json()).detail ?? m; } catch { /* ignore */ }
    throw new Error(typeof m === "string" ? m : "حدث خطأ");
  }
  return r.json();
}
const post = (u: string, b?: unknown) =>
  fetch(u, { method: "POST", headers: { "Content-Type": "application/json" }, body: b ? JSON.stringify(b) : undefined });

export const ocr = (files: File[]) => {
  const f = new FormData();
  files.forEach((x) => f.append("files", x));
  return fetch("/api/ocr", { method: "POST", body: f }).then((r) => j<{ text: string; mean_conf: number; warning: string | null }>(r));
};
export const solve = (b: { text: string; subject: string; track: string; mode: string }) =>
  post("/api/solve", b).then((r) => j<{ id: number; answer: string; usage: { in: number; out: number } }>(r));
export const verify = (id: number) => post(`/api/verify/${id}`).then((r) => j<{ review: string }>(r));
export const history = () => fetch("/api/history").then((r) => j<HistoryRow[]>(r));
export const historyItem = (id: number) => fetch(`/api/history/${id}`).then((r) => j<HistoryItem>(r));
export const historyDelete = (id: number) => fetch(`/api/history/${id}`, { method: "DELETE" }).then((r) => j<{ ok: boolean }>(r));
