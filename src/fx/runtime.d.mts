// runtime.mjs 的类型声明（运行时是纯 JS，供审阅室 TSX 使用）。
export interface FxParamSpec { type?: 'float' | 'int' | 'bool' | 'vec2' | 'vec3' | 'vec4' | 'ivec2' | 'color'; default: unknown; min?: number; max?: number; label?: string }
export interface FxBinding { to: 'beat' | 'kick' | 'bar' | 'energy'; amount: number }
export interface FxEffect {
  id: string; name: string; kind: 'post' | 'transition'; category?: string; tags?: string[]; summary?: string; when?: string; avoid?: string;
  params: Record<string, FxParamSpec>; bindings?: Record<string, FxBinding>; glsl: string; declaresUniforms?: boolean; version?: number;
  origin?: string; license?: string; author?: string; provenance?: string; inspiredBy?: Array<{ source: string; ref: string; note?: string }>; unsupported?: string;
}
export const FX_COMMON: string;
export const DEMO_SOURCES: Record<string, string>;
export function beatClock(t: number, bpm?: number): { beat: number; bar: number; kick: number; energy: number };
export function hexToVec3(hex: string): [number, number, number];
export function resolveParams(effect: Pick<FxEffect, 'params' | 'bindings'>, values?: Record<string, unknown>, clock?: Partial<ReturnType<typeof beatClock>>): Record<string, unknown>;
export function drawDemo(ctx: CanvasRenderingContext2D, name: string, t: number, clock?: ReturnType<typeof beatClock>): void;
export class EffectPreviewer {
  constructor(canvas: HTMLCanvasElement);
  canvas: HTMLCanvasElement;
  compile(effect: FxEffect): unknown;
  render(effect: FxEffect, options?: { values?: Record<string, unknown>; t?: number; source?: string; toSource?: string; progress?: number; bpm?: number }): void;
}
