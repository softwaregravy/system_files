export type Gist = { topic: string; request: string; response: string }

declare module 'claude-code' {
  interface PluginState {
    'session-gist': { gist: Gist | null }
  }
}
