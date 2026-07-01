import React, { useMemo, useState } from "react";
import ReactDOM from "react-dom/client";
import {
  AlertTriangle,
  CheckCircle2,
  CircleHelp,
  History,
  Menu,
  PauseCircle,
  RefreshCw,
  Settings,
} from "lucide-react";
import {
  createMockSnapshot,
  createSnapshotRecord,
  InMemorySnapshotStore,
  pickCapsuleCopy,
  predictCapsuleState,
} from "@quota-capsule/core";
import { createCapsuleDisplayModel } from "./capsule-view";
import "./styles.css";

const now = new Date("2026-07-01T12:00:00+08:00");
const scenarios = [
  { id: "safe", label: "安全", icon: CheckCircle2 },
  { id: "watch", label: "注意", icon: PauseCircle },
  { id: "danger", label: "危险", icon: AlertTriangle },
  { id: "error", label: "未知", icon: CircleHelp },
] as const;

function App() {
  const [activeScenario, setActiveScenario] = useState<(typeof scenarios)[number]["id"]>("safe");
  const activeIndex = scenarios.findIndex((scenario) => scenario.id === activeScenario);
  const snapshot = createMockSnapshot(activeScenario, now);
  const prediction = predictCapsuleState(snapshot, { now });
  const model = createCapsuleDisplayModel(snapshot, prediction);
  const history = useMemo(() => createMockHistory(), []);

  return (
    <main className="surface">
      <section className="capsule-stage" aria-label="Quota Capsule">
        <header className="top-bar">
          <button className="icon-button" aria-label="菜单">
            <Menu aria-hidden="true" />
          </button>
          <span className="brand">Quota Capsule</span>
          <button className="icon-button" aria-label="设置">
            <Settings aria-hidden="true" />
          </button>
        </header>

        <section className={`quiet-capsule quiet-capsule--${model.tone}`} aria-live="polite">
          <span className="status-dot" aria-hidden="true" />
          <strong>{model.statusLabel}</strong>
          <span>{model.defaultText}</span>
          <button className="capsule-icon-button" aria-label="刷新">
            <RefreshCw aria-hidden="true" />
          </button>
        </section>

        <section className="detail-popover" aria-label="额度详情">
          <div className="verdict">
            <div>
              <p className="eyebrow">Codex · 5 小时窗口</p>
              <h1>{prediction.headline}</h1>
            </div>
            <span className={`verdict-badge verdict-badge--${model.tone}`}>{model.statusLabel}</span>
          </div>

          <p className="verdict-copy">{prediction.detail}</p>
          <p className="nudge">{pickCapsuleCopy(prediction.level, activeIndex)}</p>

          <div className="metric-list">
            {model.detailMetrics.map((metric) => (
              <MetricRow key={metric.label} metric={metric} tone={model.tone} />
            ))}
          </div>

          <div className="secondary-panel">
            <div>
              <p className="eyebrow">周额度压力</p>
              <strong>{snapshot.weeklyWindow?.remainingPercent ?? "未知"}%</strong>
            </div>
            <div>
              <p className="eyebrow">最后更新</p>
              <strong>{formatTime(snapshot.fetchedAt)}</strong>
            </div>
          </div>

          <section className="history-strip" aria-label="快照历史">
            <div className="history-title">
              <History aria-hidden="true" />
              <span>{model.historyCta}</span>
            </div>
            <div className="history-bars">
              {history.list({ provider: "mock" }).map((record) => (
                <span
                  className={`history-bar history-bar--${record.state}`}
                  key={record.id}
                  style={{ height: `${Math.max(12, record.usedPercent ?? 0)}%` }}
                  title={`${formatTime(record.capturedAt)} · ${record.usedPercent ?? 0}%`}
                />
              ))}
            </div>
          </section>
        </section>

        <nav className="scenario-switcher" aria-label="场景">
          {scenarios.map((scenario) => {
            const Icon = scenario.icon;
            return (
              <button
                className={scenario.id === activeScenario ? "scenario-button scenario-button--active" : "scenario-button"}
                key={scenario.id}
                onClick={() => setActiveScenario(scenario.id)}
                type="button"
              >
                <Icon aria-hidden="true" />
                <span>{scenario.label}</span>
              </button>
            );
          })}
        </nav>
      </section>
    </main>
  );
}

function MetricRow({
  metric,
  tone,
}: {
  metric: ReturnType<typeof createCapsuleDisplayModel>["detailMetrics"][number];
  tone: string;
}) {
  const width = metric.numericValue === null || metric.numericValue === undefined ? 0 : metric.numericValue;

  return (
    <div className="metric-row">
      <div className="metric-label">
        <span>{metric.label}</span>
        <strong>{metric.value}</strong>
      </div>
      <div className="metric-track">
        <span className={`metric-fill metric-fill--${tone}`} style={{ width: `${Math.min(100, Math.max(0, width))}%` }} />
      </div>
    </div>
  );
}

function createMockHistory(): InMemorySnapshotStore {
  const store = new InMemorySnapshotStore();
  const kinds = ["safe", "safe", "watch", "watch", "danger", "safe"] as const;

  kinds.forEach((kind, index) => {
    const capturedAt = new Date(now.getTime() - (kinds.length - index) * 20 * 60_000);
    const mock = createMockSnapshot(kind, capturedAt);
    const prediction = predictCapsuleState(mock, { now: capturedAt });
    store.add(createSnapshotRecord(mock, prediction, { capturedAt, appVersion: "0.0.0-demo" }));
  });

  return store;
}

function formatTime(date: Date): string {
  return new Intl.DateTimeFormat("zh-CN", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
