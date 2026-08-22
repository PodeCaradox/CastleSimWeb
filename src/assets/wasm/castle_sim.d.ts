/* tslint:disable */
/* eslint-disable */

export function init_game(width: number, height: number): void;

/**
 * Game entry that creates a fresh map directly (same as the F2 shortcut)
 * instead of loading one from disk: cargo run --example test_map
 */
export function init_game_new_map(width: number, height: number, map_size_x: number, map_size_y: number): void;

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
    readonly memory: WebAssembly.Memory;
    readonly init_game: (a: number, b: number) => void;
    readonly init_game_new_map: (a: number, b: number, c: number, d: number) => void;
    readonly wasm_bindgen_d07a636776b43d0a___closure__destroy___dyn_core_9b3796e30d99ddb7___ops__function__FnMut__core_9b3796e30d99ddb7___option__Option_web_sys_98dfea4b5f2ab93a___features__gen_Blob__Blob_____Output_______: (a: number, b: number) => void;
    readonly wasm_bindgen_d07a636776b43d0a___closure__destroy___dyn_core_9b3796e30d99ddb7___ops__function__FnMut__wasm_bindgen_d07a636776b43d0a___JsValue____Output________1_: (a: number, b: number) => void;
    readonly wasm_bindgen_d07a636776b43d0a___closure__destroy___dyn_core_9b3796e30d99ddb7___ops__function__FnMut__wasm_bindgen_d07a636776b43d0a___JsValue____Output___core_9b3796e30d99ddb7___result__Result_____wasm_bindgen_d07a636776b43d0a___JsError___: (a: number, b: number) => void;
    readonly wasm_bindgen_d07a636776b43d0a___closure__destroy___dyn_core_9b3796e30d99ddb7___ops__function__FnMut__wasm_bindgen_d07a636776b43d0a___JsValue____Output_______: (a: number, b: number) => void;
    readonly wasm_bindgen_d07a636776b43d0a___convert__closures_____invoke___js_sys_f3682b4cd5e4ff60___Array__web_sys_98dfea4b5f2ab93a___features__gen_ResizeObserver__ResizeObserver______true_: (a: number, b: number, c: any, d: any) => void;
    readonly wasm_bindgen_d07a636776b43d0a___convert__closures_____invoke___wasm_bindgen_d07a636776b43d0a___JsValue__core_9b3796e30d99ddb7___result__Result_____wasm_bindgen_d07a636776b43d0a___JsError___true_: (a: number, b: number, c: any) => [number, number];
    readonly wasm_bindgen_d07a636776b43d0a___convert__closures_____invoke___wasm_bindgen_d07a636776b43d0a___JsValue______true__1_: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_d07a636776b43d0a___convert__closures_____invoke___wasm_bindgen_d07a636776b43d0a___JsValue______true__1__2: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_d07a636776b43d0a___convert__closures_____invoke___wasm_bindgen_d07a636776b43d0a___JsValue______true__1__3: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_d07a636776b43d0a___convert__closures_____invoke___wasm_bindgen_d07a636776b43d0a___JsValue______true__1__4: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_d07a636776b43d0a___convert__closures_____invoke___wasm_bindgen_d07a636776b43d0a___JsValue______true__1__5: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_d07a636776b43d0a___convert__closures_____invoke___wasm_bindgen_d07a636776b43d0a___JsValue______true__1__6: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_d07a636776b43d0a___convert__closures_____invoke___wasm_bindgen_d07a636776b43d0a___JsValue______true__1__7: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_d07a636776b43d0a___convert__closures_____invoke___wasm_bindgen_d07a636776b43d0a___JsValue______true__1__8: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_d07a636776b43d0a___convert__closures_____invoke___wasm_bindgen_d07a636776b43d0a___JsValue______true__2_: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_d07a636776b43d0a___convert__closures_____invoke___wasm_bindgen_d07a636776b43d0a___JsValue______true_: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_d07a636776b43d0a___convert__closures_____invoke_______true_: (a: number, b: number) => void;
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
