/* tslint:disable */
/* eslint-disable */

export function run(width: number, height: number): Promise<void>;

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
  readonly memory: WebAssembly.Memory;
  readonly run: (a: number, b: number) => any;
  readonly wasm_bindgen__convert__closures_____invoke__h2112aca4261725a6: (a: number, b: number, c: any) => void;
  readonly wasm_bindgen__closure__destroy__h06b46c35459df2af: (a: number, b: number) => void;
  readonly wasm_bindgen__convert__closures_____invoke__hdb98e87ab79fe139: (a: number, b: number) => void;
  readonly wasm_bindgen__convert__closures_____invoke__h3056796cd887c430: (a: number, b: number, c: any, d: any) => void;
  readonly wasm_bindgen__convert__closures_____invoke__hb1fc3a3bbc1e5acc: (a: number, b: number, c: any) => void;
  readonly wasm_bindgen__closure__destroy__h037fafc90081686a: (a: number, b: number) => void;
  readonly wasm_bindgen__convert__closures_____invoke__h2d60bd945b1a792c: (a: number, b: number, c: any, d: any) => void;
  readonly __wbindgen_malloc: (a: number, b: number) => number;
  readonly __wbindgen_realloc: (a: number, b: number, c: number, d: number) => number;
  readonly __externref_table_alloc: () => number;
  readonly __wbindgen_externrefs: WebAssembly.Table;
  readonly __wbindgen_exn_store: (a: number) => void;
  readonly __wbindgen_free: (a: number, b: number, c: number) => void;
  readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;

/**
* Instantiates the given `module`, which can either be bytes or
* a precompiled `WebAssembly.Module`.
*
* @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
*
* @returns {InitOutput}
*/
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
* If `module_or_path` is {RequestInfo} or {URL}, makes a request and
* for everything else, calls `WebAssembly.instantiate` directly.
*
* @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
*
* @returns {Promise<InitOutput>}
*/
export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;
