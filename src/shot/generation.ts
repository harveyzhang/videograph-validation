// generation.ts — 单镜头任务协调器：冻结输入、取消/隔离旧结果、有限修复、原子采用产物。
// 本阶段仍是会话内工作集；工程落盘与后台恢复由后续工程服务负责。
import type { PlannedCard } from './planner';
import type { FullSongData } from './engine';
import type { ShotRepair } from './codegen';
import { isShotBusy, type ShotArtifact, type ShotCardEntry, type ShotCardRuntime, type ShotSource } from './model';
import { describeShotIssue, MAX_SHOT_REPAIRS, validateShotScene, type ShotValidationReport } from './validation';

export interface ShotCandidate {
  code: string;
  summary: string;
  model?: string;
  motif?: string;
}

export interface ShotExecutor {
  source: ShotSource;
  parallel: boolean;
  generate(card: PlannedCard, signal: AbortSignal, repair?: ShotRepair): Promise<ShotCandidate>;
}

interface Run {
  entry: ShotCardEntry;
  controller: AbortController;
  executor: ShotExecutor;
}

const errorText = (error: unknown) => String(error).slice(0, 600);

export class ShotGenerationController {
  private cards: ShotCardEntry[] = [];
  private runs = new Map<string, Run>();
  private listeners = new Set<() => void>();

  constructor(private song: FullSongData) {}

  getSnapshot = (): ShotCardEntry[] => this.cards;
  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => { this.listeners.delete(listener); };
  };

  private emit() { for (const listener of this.listeners) listener(); }

  patchRuntime(id: string, changes: Partial<ShotCardRuntime>) {
    this.cards = this.cards.map((entry) => entry.card.id === id ? { ...entry, ...changes } : entry);
    this.emit();
  }

  replacePlan(plan: PlannedCard[]) {
    this.cancelAll();
    this.cards = plan.map((card) => ({
      card: structuredClone(card), inputRevision: 0, rev: 0, status: 'planned', source: null, lint: [],
    }));
    this.emit();
  }

  editPrompt(id: string, prompt: string) {
    const entry = this.cards.find((c) => c.card.id === id);
    if (!entry || entry.card.prompt === prompt) return;
    this.cancel(id);
    this.cards = this.cards.map((current) => current.card.id === id ? {
      ...current, card: { ...current.card, prompt }, inputRevision: current.inputRevision + 1,
      status: 'stale', error: undefined, validation: undefined, summary: undefined,
    } : current);
    this.emit();
  }

  cancel(id: string) {
    const run = this.runs.get(id);
    if (!run) return;
    this.runs.delete(id);
    run.controller.abort();
    this.patchRuntime(id, { status: 'stale', error: undefined, summary: '已取消等待；已发送的上游请求可能仍在执行。' });
  }

  cancelAll = () => { for (const id of [...this.runs.keys()]) this.cancel(id); };

  private current(run: Run): boolean {
    return this.runs.get(run.entry.card.id) === run && !run.controller.signal.aborted
      && this.cards.some((entry) => entry.card.id === run.entry.card.id && entry.inputRevision === run.entry.inputRevision);
  }

  /** 先同步预留全部任务，再启动执行，避免批量与单卡重复点击造成并行覆盖。 */
  async generate(ids: string[], executor: ShotExecutor): Promise<void> {
    const requested = new Set(ids);
    const runs = this.cards.filter((entry) => requested.has(entry.card.id) && !isShotBusy(entry.status)).map((entry) => {
      const run: Run = { entry: { ...entry, card: structuredClone(entry.card) }, controller: new AbortController(), executor };
      this.runs.set(entry.card.id, run);
      return run;
    });
    const reserved = new Set(runs.map((run) => run.entry.card.id));
    this.cards = this.cards.map((entry) => reserved.has(entry.card.id) ? {
      ...entry, status: 'generating', source: executor.source, error: undefined, summary: undefined,
      validation: { attempt: 0, samples: 0, failures: [] }, lint: [],
    } : entry);
    this.emit();
    if (executor.parallel) await Promise.all(runs.map((run) => this.execute(run)));
    else for (const run of runs) await this.execute(run);
  }

  private async execute(run: Run): Promise<void> {
    const { card } = run.entry;
    let repair: ShotRepair | undefined;
    let report: ShotValidationReport = { attempt: 0, samples: 0, failures: [] };
    try {
      while (this.current(run)) {
        this.patchRuntime(card.id, {
          status: repair ? 'repairing' : 'generating', validation: report,
          summary: run.executor.source === 'mcp'
            ? `等待外部 agent${repair ? ` 修复 ${repair.attempt}/${MAX_SHOT_REPAIRS}` : ' 生成'}；可取消或修改提示词。`
            : repair ? `自动修复 ${repair.attempt}/${MAX_SHOT_REPAIRS}…` : '生成场景中…',
        });
        const result = await run.executor.generate(card, run.controller.signal, repair);
        if (!this.current(run)) return;
        this.patchRuntime(card.id, { status: 'validating', summary: '正在检查静态约束、编译与 5 个时间点…' });
        // 让界面先显示校验状态。同步场景执行仍不是安全沙箱，不能用这个 yield 防死循环。
        await new Promise<void>((resolve) => setTimeout(resolve, 0));
        if (!this.current(run)) return;
        const validation = validateShotScene(result.code, card.window, this.song);
        if (!this.current(run)) return;
        report = { ...report, samples: validation.samples };
        if (validation.ok) {
          const artifact: ShotArtifact = {
            code: result.code, draw: validation.draw, thumb: validation.thumb,
            rev: run.entry.rev + 1, inputRevision: run.entry.inputRevision,
            source: run.executor.source, summary: result.summary, model: result.model, motif: result.motif, validation: report,
          };
          this.runs.delete(card.id);
          this.cards = this.cards.map((entry) => entry.card.id === card.id ? {
            ...entry, artifact, status: 'ready', rev: artifact.rev, source: artifact.source,
            model: artifact.model, motif: artifact.motif, summary: artifact.summary,
            thumb: artifact.thumb, validation: report, error: undefined, lint: [],
          } : entry);
          this.emit();
          return;
        }
        report = { ...report, failures: [...report.failures, { attempt: report.attempt, issue: validation.issue }] };
        if (run.executor.source === 'builtin' || report.attempt >= MAX_SHOT_REPAIRS) {
          this.runs.delete(card.id);
          this.patchRuntime(card.id, {
            status: 'error', validation: report, summary: undefined,
            error: `${run.executor.source === 'builtin' ? '本地模板校验失败' : `已用完 ${MAX_SHOT_REPAIRS} 次自动修复`}；${describeShotIssue(validation.issue)}`,
          });
          return;
        }
        repair = { attempt: report.attempt + 1, code: result.code, issue: validation.issue };
        report = { ...report, attempt: repair.attempt, samples: 0 };
      }
    } catch (error) {
      // 传输/agent 拒绝不进入代码修复循环；取消或旧输入的异常不修改当前卡片。
      if (this.current(run)) {
        this.runs.delete(card.id);
        this.patchRuntime(card.id, { status: 'error', error: errorText(error), validation: report, summary: undefined });
      }
    }
  }
}
