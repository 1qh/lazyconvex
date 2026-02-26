type AnyApi = Record<string, Record<string, unknown>>

const GUARD_ACTIVE = typeof process !== 'undefined' && process.env.NODE_ENV !== 'production',
  findSuggestion = (modules: string[], name: string): string | undefined => {
    const lower = name.toLowerCase()
    for (const m of modules) if (m.toLowerCase() === lower) return m
  },
  makeGuardedProxy = <T extends AnyApi>(target: T, modules: string[]): T => {
    if (!GUARD_ACTIVE) return target
    const moduleSet = new Set(modules)
    return new Proxy(target, {
      get: (obj, prop) => {
        if (typeof prop !== 'string') return Reflect.get(obj, prop)
        if (moduleSet.has(prop)) return Reflect.get(obj, prop)
        const suggestion = findSuggestion(modules, prop),
          msg = suggestion
            ? `guardApi: api.${prop} does not exist. Did you mean api.${suggestion}?`
            : `guardApi: api.${prop} does not match any module in your convex/ directory. Valid modules: ${modules.join(', ')}`
        throw new Error(msg)
      }
    })
  },
  guardApi = <T extends AnyApi>(api: T, modules: string[]): T => makeGuardedProxy(api, modules)

export { guardApi }
