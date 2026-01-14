let initialized = false;

export function initComponentExtensions(): void {
  if (initialized) return;
  initialized = true;
  const modules = import.meta.glob('./*.extension.ts', { eager: true });
  for (const mod of Object.values(modules)) {
    const register = (mod as { register?: () => void }).register;
    if (typeof register === 'function') register();
  }
}
