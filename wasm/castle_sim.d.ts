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
    readonly wasm_bindgen__closure__destroy__h0ae2e7a0dc04e545: (a: number, b: number) => void;
    readonly wasm_bindgen__closure__destroy__h39928b18bef4cd3e: (a: number, b: number) => void;
    readonly wasm_bindgen__closure__destroy__h45c260b7f02a2570: (a: number, b: number) => void;
    readonly wasm_bindgen__closure__destroy__ha1d5b66363b308c9: (a: number, b: number) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h83c79836daa8d999: (a: number, b: number, c: any, d: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__hf832fc45549c4652: (a: number, b: number, c: any) => [number, number];
    readonly wasm_bindgen__convert__closures_____invoke__h2d7816a0cf610446: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h2d7816a0cf610446_2: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h2d7816a0cf610446_3: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h2d7816a0cf610446_4: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h2d7816a0cf610446_5: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h2d7816a0cf610446_6: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h2d7816a0cf610446_7: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h2d7816a0cf610446_8: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h6c1b68b4cab936c2: (a: number, b: number, c: number) => void;
    readonly wasm_bindgen__convert__closures_____invoke__he24a3e51186ceada: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h6d9134210719b338: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h80d42dc5365b87a0: (a: number, b: number) => void;
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
