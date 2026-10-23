/* tslint:disable */
/* eslint-disable */

/**
 * Starts the game on the shipped map.
 */
export function init_game(width: number, height: number): void;

/**
 * Starts the game on a fresh `map_size_x` x `map_size_y` map (the F2 shortcut).
 */
export function init_game_new_map(width: number, height: number, map_size_x: number, map_size_y: number): void;

/**
 * How far the game's load is, 0..=1000; the web page polls it for its bar.
 */
export function loading_permille(): number;

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
    readonly memory: WebAssembly.Memory;
    readonly init_game: (a: number, b: number) => void;
    readonly init_game_new_map: (a: number, b: number, c: number, d: number) => void;
    readonly loading_permille: () => number;
    readonly wasm_bindgen_54c5affd1a0fe3d9___closure__destroy___dyn_core_9b3796e30d99ddb7___ops__function__FnMut__core_9b3796e30d99ddb7___option__Option_web_sys_f0db91317b509b4___features__gen_Blob__Blob_____Output_______: (a: number, b: number) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___closure__destroy___dyn_core_9b3796e30d99ddb7___ops__function__FnMut__wasm_bindgen_54c5affd1a0fe3d9___JsValue____Output________1_: (a: number, b: number) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___closure__destroy___dyn_core_9b3796e30d99ddb7___ops__function__FnMut__wasm_bindgen_54c5affd1a0fe3d9___JsValue____Output_______: (a: number, b: number) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___closure__destroy___dyn_core_9b3796e30d99ddb7___ops__function__FnMut__wasm_bindgen_54c5affd1a0fe3d9___JsValue____Output___core_9b3796e30d99ddb7___result__Result_____wasm_bindgen_54c5affd1a0fe3d9___JsError___: (a: number, b: number) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___convert__closures_____invoke___js_sys_54f365f9f1d0fa8a___Array__web_sys_f0db91317b509b4___features__gen_ResizeObserver__ResizeObserver______true_: (a: number, b: number, c: any, d: any) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___convert__closures_____invoke___wasm_bindgen_54c5affd1a0fe3d9___JsValue__core_9b3796e30d99ddb7___result__Result_____wasm_bindgen_54c5affd1a0fe3d9___JsError___true_: (a: number, b: number, c: any) => [number, number];
    readonly wasm_bindgen_54c5affd1a0fe3d9___convert__closures_____invoke___wasm_bindgen_54c5affd1a0fe3d9___JsValue______true__1_: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___convert__closures_____invoke___wasm_bindgen_54c5affd1a0fe3d9___JsValue______true__1__2: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___convert__closures_____invoke___wasm_bindgen_54c5affd1a0fe3d9___JsValue______true__1__3: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___convert__closures_____invoke___wasm_bindgen_54c5affd1a0fe3d9___JsValue______true__1__4: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___convert__closures_____invoke___wasm_bindgen_54c5affd1a0fe3d9___JsValue______true__1__5: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___convert__closures_____invoke___wasm_bindgen_54c5affd1a0fe3d9___JsValue______true__1__6: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___convert__closures_____invoke___wasm_bindgen_54c5affd1a0fe3d9___JsValue______true__1__7: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___convert__closures_____invoke___wasm_bindgen_54c5affd1a0fe3d9___JsValue______true__1__8: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___convert__closures_____invoke___core_9b3796e30d99ddb7___option__Option_web_sys_f0db91317b509b4___features__gen_Blob__Blob_______true_: (a: number, b: number, c: number) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___convert__closures_____invoke___wasm_bindgen_54c5affd1a0fe3d9___JsValue______true__2_: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___convert__closures_____invoke___wasm_bindgen_54c5affd1a0fe3d9___JsValue______true_: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen_54c5affd1a0fe3d9___convert__closures_____invoke_______true_: (a: number, b: number) => void;
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
