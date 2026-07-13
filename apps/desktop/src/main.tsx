import React, { useState } from "react";
import ReactDOM from "react-dom/client";
import {
  AlertTriangle,
  CheckCircle2,
  CircleHelp,
  Gauge,
  Menu,
  RefreshCw,
  Settings,
} from "lucide-react";
import {
  analyzeWeeklyQuality,
  createMockWeeklyScenario,
  predictWeeklyRunway,
  type WeeklyMockKind,
} from "@quota-capsule/core";
import { createCapsuleDisplayModel } from "./capsule-view";
import "./styles.css";

const now = new Date("2026-07-13T08:00:00+08:00");
const scenarios: Array<{ id: WeeklyMockKind; label: string; icon: typeof CheckCircle2 }> = [
  { id: "enough", label: "够用", icon: CheckCircle2 },
  { id: "watch", label: "偏快", icon: Gauge },
  { id: "mayRunOut", label: "可能不够", icon: AlertTriangle },
  { id: "calibrating", label: "校准", icon: RefreshCw },
  { id: "exhausted", label: "已用尽", icon: AlertTriangle },
  { id: "unavailable", label: "不可用", icon: CircleHelp },
];

function App() {
  const [activeScenario, setActiveScenario] = useState<WeeklyMockKind>("enough");
  const scenario = createMockWeeklyScenario(activeScenario, now);
  const quality = analyzeWeeklyQuality(scenario.readings, now);
  const forecast = predictWeeklyRunway(scenario.snapshot, quality, now);
  const model = createCapsuleDisplayModel(forecast);

  return (
    <main className="surface">
      <section className="capsule-stage" aria-label="Quota Capsule Weekly Only preview">
        <header className="top-bar">
          <button className="icon-button" aria-label="菜单"><Menu aria-hidden="true" /></button>
          <span className="brand">Quota Capsule · Weekly Only</span>
          <button className="icon-button" aria-label="设置"><Settings aria-hidden="true" /></button>
        </header>

        <section className={`quiet-capsule quiet-capsule--${model.tone}`} aria-live="polite">
          <span className="status-dot" aria-hidden="true" />
          <strong>{model.statusLabel}</strong>
          <span>{model.compactDetail ? `${model.compactDetail} · ${model.defaultText}` : model.defaultText}</span>
          <button className="capsule-icon-button" aria-label="刷新"><RefreshCw aria-hidden="true" /></button>
        </section>

        <section className="detail-popover" aria-label="周额度详情">
          <div className="verdict">
            <div>
              <p className="eyebrow">Codex · 周额度</p>
              <h1>{model.statusLabel}</h1>
            </div>
            <span className={`verdict-badge verdict-badge--${model.tone}`}>{model.statusLabel}</span>
          </div>
          <p className="verdict-copy">{model.defaultText}</p>

          <section aria-label="本周节奏">
            <p className="eyebrow">本周节奏</p>
            <div className="metric-list">
              {model.detailMetrics.slice(0, 2).map((metric) => <MetricRow key={metric.label} metric={metric} tone={model.tone} />)}
            </div>
          </section>

          <section aria-label="速度与预算">
            <p className="eyebrow">速度与预算</p>
            <div className="secondary-panel">
              {model.detailMetrics.slice(2).map((metric) => (
                <div key={metric.label}>
                  <p className="eyebrow">{metric.label}</p>
                  <strong>{metric.value}</strong>
                </div>
              ))}
            </div>
          </section>

          <div className="freshness-row">
            <span>周额度刷新：{formatTime(scenario.snapshot.weeklyWindow?.resetsAt)}</span>
            <span>{model.confidenceText || "正在积累可信趋势"}</span>
          </div>
        </section>

        <nav className="scenario-switcher" aria-label="周额度场景">
          {scenarios.map((item) => {
            const Icon = item.icon;
            return (
              <button
                className={item.id === activeScenario ? "scenario-button scenario-button--active" : "scenario-button"}
                key={item.id}
                onClick={() => setActiveScenario(item.id)}
                type="button"
              >
                <Icon aria-hidden="true" /><span>{item.label}</span>
              </button>
            );
          })}
        </nav>
      </section>
    </main>
  );
}

function MetricRow({ metric, tone }: { metric: ReturnType<typeof createCapsuleDisplayModel>["detailMetrics"][number]; tone: string }) {
  const width = metric.numericValue === null || metric.numericValue === undefined ? 0 : metric.numericValue;
  return (
    <div className="metric-row">
      <div className="metric-label"><span>{metric.label}</span><strong>{metric.value}</strong></div>
      <div className="metric-track"><span className={`metric-fill metric-fill--${tone}`} style={{ width: `${Math.min(100, Math.max(0, width))}%` }} /></div>
    </div>
  );
}

function formatTime(date: Date | undefined): string {
  if (!date) return "未知";
  return new Intl.DateTimeFormat("zh-CN", { weekday: "short", hour: "2-digit", minute: "2-digit", hour12: false }).format(date);
}

ReactDOM.createRoot(document.getElementById("root")!).render(<React.StrictMode><App /></React.StrictMode>);
