import { useEffect, useState } from "react";
import { Trash2 } from "lucide-react";
import { HistoryRow, history, historyDelete } from "./api";

export default function History({ onOpen }: { onOpen: (id: number) => void }) {
  const [rows, setRows] = useState<HistoryRow[]>([]);
  const [err, setErr] = useState("");
  const load = () => history().then(setRows).catch((e) => setErr(e.message));
  useEffect(() => { load(); }, []);
  if (err) return <p className="text-red-300">{err}</p>;
  if (!rows.length) return <p className="text-slate-400">لا توجد حلول محفوظة بعد.</p>;
  return (
    <ul className="space-y-2">
      {rows.map((r) => (
        <li key={r.id} className="flex items-center justify-between rounded-xl bg-white/5 p-3">
          <button className="text-right" onClick={() => onOpen(r.id)}>
            <div className="font-semibold">{r.subject} — {r.track}</div>
            <div className="text-xs text-slate-400">{new Date(r.created * 1000).toLocaleString("ar-DZ")}</div>
          </button>
          <button aria-label="حذف" onClick={() => historyDelete(r.id).then(load)}><Trash2 size={18} /></button>
        </li>
      ))}
    </ul>
  );
}
