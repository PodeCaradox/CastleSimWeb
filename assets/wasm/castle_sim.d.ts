/* tslint:disable */
/* eslint-disable */

export function init_game(width: number, height: number): void;

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
    readonly memory: WebAssembly.Memory;
    readonly init_game: (a: number, b: number) => void;
    readonly wasm_bindgen__closure__destroy__h171e54c78a02aa44: (a: number, b: number) => void;
    readonly wasm_bindgen__closure__destroy__h2267c5a3a33d6ca1: (a: number, b: number) => void;
    readonly wasm_bindgen__closure__destroy__h201731ff488da402: (a: number, b: number) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h72401b5efe02f859: (a: number, b: number, c: any) => [number, number];
    readonly wasm_bindgen__convert__closures_____invoke__hcb093511f31953b8: (a: number, b: number, c: any, d: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h36a805dfca600d37: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h03b69bc391c244c3: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h03b69bc391c244c3_4: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h03b69bc391c244c3_5: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h03b69bc391c244c3_6: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h03b69bc391c244c3_7: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h03b69bc391c244c3_8: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h03b69bc391c244c3_9: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h03b69bc391c244c3_10: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h0a4e10f01bf099b6: (a: number, b: number) => void;
    readonly __wbindgen_malloc: (a: number, b: number) => number;
    readonly __wbindgen_realloc: (a: number, b: number, c: number, d: number) => number;
    readonly __externref_table_alloc: () => number;
    readonly __wbindgen_externrefs: WebAssembly.Table;
    readonly __wbindgen_exn_store: (a: number) => void;
    readonly __wbindgen_free: (a: number, b: number, c: number) => void;
    readonly __externref_table_dealloc: (a: number) => void;
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
