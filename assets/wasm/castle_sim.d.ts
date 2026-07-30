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
    readonly wasm_bindgen__closure__destroy__h4d7e7582a79afb0c: (a: number, b: number) => void;
    readonly wasm_bindgen__closure__destroy__h4e1f99db5ce347ba: (a: number, b: number) => void;
    readonly wasm_bindgen__closure__destroy__h13f9d7347e3c9f55: (a: number, b: number) => void;
    readonly wasm_bindgen__convert__closures_____invoke__habca73242a8829e7: (a: number, b: number, c: any) => [number, number];
    readonly wasm_bindgen__convert__closures_____invoke__h0da3f946998c2a22: (a: number, b: number, c: any, d: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h09f6c6d99d7ca4d4: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h18d91ba7dd3614ec: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h18d91ba7dd3614ec_4: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h18d91ba7dd3614ec_5: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h18d91ba7dd3614ec_6: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h18d91ba7dd3614ec_7: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h18d91ba7dd3614ec_8: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h18d91ba7dd3614ec_9: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h18d91ba7dd3614ec_10: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h3a470fd3977ff306: (a: number, b: number) => void;
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
