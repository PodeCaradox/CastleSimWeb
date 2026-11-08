// A browser keeps an AudioContext made before any input suspended, and bevy_audio makes its own at
// start and hands it to nobody. So every context is noted when it is made and resumed on input (E449).
// The wrap stands on the module's top level: the wasm glue keeps the class when it loads, after its imports.
const contexts = [];
if (globalThis.AudioContext) {
  globalThis.AudioContext = new Proxy(globalThis.AudioContext, {
    construct(target, args) {
      const context = new target(...args);
      contexts.push(context);
      return context;
    },
  });
}

export function resume_audio_on_input() {
  const resume = () => {
    for (const context of contexts) {
      if (context.state === 'suspended' || context.state === 'interrupted') context.resume();
    }
  };
  // Stays on: not every press counts as input (Esc), and a phone call can suspend the context again.
  for (const input of ['pointerdown', 'pointerup', 'touchend', 'keydown', 'click']) {
    globalThis.addEventListener(input, resume, { capture: true, passive: true });
  }
}
