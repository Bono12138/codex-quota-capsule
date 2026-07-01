import React from "react";
import ReactDOM from "react-dom/client";
import { Activity, AlertTriangle, CheckCircle2, CircleHelp, Gauge } from "lucide-react";
import { createMockSnapshot, pickCapsuleCopy, predictCapsuleState } from "@quota-capsule/core";
import "./styles.css";

const now = new Date("2026-07-01T12:00:00+08:00");
const scenarios = ["safe", "watch", "danger", "error"] as const;

function App() {
  return (
    <main>
      <section className="workspace">
        <div className="app-title">
          <Gauge aria-hidden="true" />
          <div>
            <h1>Quota Capsule</h1>
            <p>Codex-first desktop quota gauge, ready for agent adapters.</p>
          </div>
        </div>

        <div className="capsule-row">
          {scenarios.map((scenario, index) => {
            const prediction = predictCapsuleState(createMockSnapshot(scenario, now), { now });
            return (
              <article className={`capsule capsule-${prediction.level}`} key={scenario}>
                <div className="capsule-top">
                  <StatusIcon level={prediction.level} />
                  <span>{prediction.level}</span>
                </div>
                <h2>{prediction.headline}</h2>
                <p>{prediction.detail}</p>
                <small>{pickCapsuleCopy(prediction.level, index)}</small>
                <div className="meter-stack" aria-label="Quota details">
                  <Meter label="时间进度" value={prediction.elapsedPercent ?? 0} />
                  <Meter label="刷新余量" value={prediction.projectedRemainingAtReset ?? 0} />
                </div>
              </article>
            );
          })}
        </div>
      </section>
    </main>
  );
}

function StatusIcon({ level }: { level: string }) {
  if (level === "safe") return <CheckCircle2 aria-hidden="true" />;
  if (level === "watch") return <Activity aria-hidden="true" />;
  if (level === "danger") return <AlertTriangle aria-hidden="true" />;
  return <CircleHelp aria-hidden="true" />;
}

function Meter({ label, value }: { label: string; value: number }) {
  return (
    <div className="meter">
      <div className="meter-label">
        <span>{label}</span>
        <span>{Math.round(value)}%</span>
      </div>
      <div className="meter-track">
        <div className="meter-fill" style={{ width: `${value}%` }} />
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);

