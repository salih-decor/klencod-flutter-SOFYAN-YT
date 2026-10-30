import { useState } from "react";
import { Brain, Camera, Copy, History as HistoryIcon, Printer, ShieldCheck, Sparkles } from "lucide-react";
import { historyItem, ocr, solve, verify } from "./api";
import History from "./History";

const TRACKS = ["آداب وفلسفة", "لغات أجنبية", "علوم تجريبية", "رياضيات", "تقني رياضي", "تسيير واقتصاد"];
const SUBJECTS = ["الفلسفة", "اللغة العربية وآدابها", "التاريخ", "الجغرافيا", "العلوم الإسلامية",
  "اللغة الفرنسية", "اللغة الإنجليزية", "الرياضيات", "مادة أخرى"];

const btn = "inline-flex items-center gap-2 rounded-xl px-4 py-2 font-semibold disabled:opacity-50 ";
const primary = btn + "bg-gradient-to-l from-violet-500 to-indigo-500 text-white";
const ghost = btn + "bg-white/10 text-white hover:bg-white/20";

export default function App() {
  const [tab, setTab] = useState<"solve" | "history">("solve");
  const [files, setFiles] = useState<File[]>([]);
  const [text, setText] = useState("");
  const [track, setTrack] = useState(TRACKS[0]);
  const [subject, setSubject] = useState(SUBJECTS[0]);
  const [mode, setMode] = useState<"model" | "teacher">("model");
  const [stage, setStage] = useState("");
  const [notice, setNotice] = useState("");
  const [err, setErr] = useState("");
  const [res, setRes] = useState<{ id: number; answer: string; review: string | null } | null>(null);

  const run = async (label: string, fn: () => Promise<void>) => {
    setErr(""); setStage(label);
    try { await fn(); } catch (e) { setErr((e as Error).message); } finally { setStage(""); }
  };

  const doOcr = () => run("قراءة الصورة واستخراج الأسئلة…", async () => {
    const r = await ocr(files);
    setText(r.text);
    setNotice(r.warning ?? `متوسط وضوح القراءة ≈ ${r.mean_conf}% — راجع النص قبل الحل.`);
  });
  const doSolve = () => run("إنشاء الحل…", async () => {
    const r = await solve({ text, subject, track, mode });
    setRes({ id: r.id, answer: r.answer, review: null });
  });
  const doVerify = () => res && run("مراجعة الإجابة…", async () => {
    const r = await verify(res.id);
    setRes({ ...res, review: r.review });
  });
  const open = async (id: number) => {
    const h = await historyItem(id);
    setText(h.question); setSubject(h.subject); setTrack(h.track);
    setRes({ id: h.id, answer: h.answer, review: h.review }); setTab("solve");
  };

  return (
    <div className="min-h-screen pb-24 text-white" style={{ background: "linear-gradient(160deg,#0b1230,#1a1450)" }}>
      <header className="no-print px-5 pt-8 text-center">
        <h1 className="text-4xl font-extrabold tracking-wide">SOFYAN <span className="text-violet-400">YT</span></h1>
        <p className="mt-1 text-slate-300">المساعد الذكي للبكالوريا الجزائرية</p>
      </header>

      <main className="mx-auto mt-6 max-w-3xl space-y-5 px-4">
        {tab === "history" ? <History onOpen={open} /> : (
          <>
            <section className="no-print space-y-3 rounded-2xl bg-white/5 p-4">
              <h2 className="text-lg font-bold">حل اختبار بالذكاء الاصطناعي</h2>
              <input type="file" accept="image/*" multiple capture="environment"
                onChange={(e) => setFiles(Array.from(e.target.files ?? []))} className="block w-full text-sm" />
              {files.length > 0 && (
                <div className="flex flex-wrap gap-2">
                  {files.map((f, i) => <img key={i} src={URL.createObjectURL(f)} className="h-20 rounded-lg" />)}
                </div>
              )}
              <button className={ghost} disabled={!files.length || !!stage} onClick={doOcr}><Camera size={18} />استخراج النص من الصور</button>
              {notice && <p className="text-amber-300 text-sm">{notice}</p>}
              <textarea value={text} onChange={(e) => setText(e.target.value)} rows={10} dir="auto"
                placeholder="النص المستخرج (قابل للتعديل) أو الصق نص الاختبار هنا…"
                className="w-full rounded-xl bg-black/30 p-3" />
              <div className="grid grid-cols-2 gap-2">
                <select value={track} onChange={(e) => setTrack(e.target.value)} className="rounded-xl bg-black/40 p-2">
                  {TRACKS.map((t) => <option key={t}>{t}</option>)}</select>
                <select value={subject} onChange={(e) => setSubject(e.target.value)} className="rounded-xl bg-black/40 p-2">
                  {SUBJECTS.map((t) => <option key={t}>{t}</option>)}</select>
              </div>
              <div className="flex gap-2">
                <button className={mode === "model" ? primary : ghost} onClick={() => setMode("model")}>الإجابة النموذجية</button>
                <button className={mode === "teacher" ? primary : ghost} onClick={() => setMode("teacher")}><Brain size={18} />الأستاذ الذكي</button>
              </div>
              <button className={primary} disabled={text.trim().length < 5 || !!stage} onClick={doSolve}><Sparkles size={18} />حل الاختبار</button>
              {stage && <p className="animate-pulse text-violet-300">{stage}</p>}
              {err && <p className="rounded-lg bg-red-500/20 p-2 text-red-200">{err}</p>}
            </section>

            {res && (
              <section id="print-area" className="space-y-3 rounded-2xl bg-white/5 p-4">
                <div className="keep">
                  <h2 className="text-xl font-bold">SOFYAN YT — {subject}</h2>
                  <p className="text-sm text-slate-300">السنة الثالثة ثانوي — {track}</p>
                </div>
                <div className="whitespace-pre-wrap leading-8">{res.answer}</div>
                {res.review && (
                  <div className="keep whitespace-pre-wrap rounded-xl bg-emerald-500/10 p-3 leading-8">
                    <b>نتيجة إعادة التحقق:</b>{"\n"}{res.review}</div>
                )}
                <div className="no-print flex flex-wrap gap-2">
                  <button className={ghost} onClick={() => navigator.clipboard.writeText(res.answer)}><Copy size={18} />نسخ</button>
                  <button className={ghost} disabled={!!stage} onClick={doVerify}><ShieldCheck size={18} />إعادة التحقق من الحل</button>
                  <button className={ghost} onClick={() => window.print()}><Printer size={18} />تصدير PDF / طباعة</button>
                </div>
              </section>
            )}
          </>
        )}
      </main>

      <nav className="no-print fixed inset-x-0 bottom-0 flex justify-around border-t border-white/10 bg-[#0b1230]/95 py-3">
        <button onClick={() => setTab("solve")} className={tab === "solve" ? "text-violet-400" : ""}><Sparkles className="mx-auto" />حل</button>
        <button onClick={() => setTab("history")} className={tab === "history" ? "text-violet-400" : ""}><HistoryIcon className="mx-auto" />السجل</button>
      </nav>
    </div>
  );
}
