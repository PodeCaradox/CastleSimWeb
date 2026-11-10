// A browser keeps an AudioContext made before any input suspended, and bevy_audio makes its own at
// start and hands it to nobody. So every context is noted when it is made and resumed on input (E449).
// The wrap stands on the module's top level: the wasm glue keeps the class when it loads, after its imports.
const contexts = [];
if (globalThis.AudioContext) {
  globalThis.AudioContext = new Proxy(globalThis.AudioContext, {
    construct(target, args) {
      const context = new target(...args);
      contexts.push(context);
      keep_buffers_in_line(context);
      return context;
    },
  });
}

// cpal's WebAudio host starts each buffer at its cursor, which a blocked main thread leaves behind
// the clock: late buffers would start at once, together, and play the music fast. So a buffer (any
// source: taken for cpal's, played whole once at rate 1) starts at the clock or the end of the last.
function keep_buffers_in_line(context) {
  let end = 0;
  const create = context.createBufferSource.bind(context);
  context.createBufferSource = () => {
    const source = create();
    const start = source.start.bind(source);
    source.start = (when = 0, ...rest) => {
      const at = Math.max(when, end, context.currentTime);
      end = at + (source.buffer ? source.buffer.duration : 0);
      start(at, ...rest);
    };
    return source;
  };
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
