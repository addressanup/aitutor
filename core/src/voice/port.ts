/**
 * Cascaded voice interface (docs/execution-plan.md §3.4). Two planes: the action
 * executor emits step events; a narration plane consumes them and speaks at step
 * boundaries. TTS is independently cancellable so learner barge-in kills audio in
 * <300 ms WITHOUT killing the executor. INTERFACE ONLY at scaffold.
 */

export interface CancellableSpeech {
  /** Resolves when playback finishes or is cancelled. */
  done: Promise<void>;
  /** Barge-in: stop audio within the <300 ms budget; never touches the executor. */
  cancel(): void;
}

export interface Transcript {
  text: string;
  final: boolean;
}

export interface VoicePort {
  startListening(onTranscript: (t: Transcript) => void): void;
  stopListening(): void;
  say(text: string): CancellableSpeech;
}
