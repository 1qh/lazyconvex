import type { core, output, ZodObject, ZodRawShape, ZodType } from 'zod/v4'

type CvMeta = 'file' | 'files'
type DefType = core.$ZodTypeDef['type']
type ZodSchema = ZodType

const WRAPPERS: ReadonlySet<DefType> = new Set<DefType>([
    'catch',
    'default',
    'nullable',
    'optional',
    'prefault',
    'readonly'
  ]),
  unwrapZod = (
    schema: unknown
  ): {
    def: undefined | ZodSchema['def']
    schema: undefined | ZodSchema
    type: '' | DefType
  } => {
    let cur = schema as undefined | ZodSchema
    while (cur && typeof cur === 'object' && 'type' in cur) {
      if (!WRAPPERS.has(cur.type)) return { def: cur.def, schema: cur, type: cur.type }
      cur = (cur.def as { innerType?: ZodSchema }).innerType
    }
    return { def: undefined, schema: undefined, type: '' }
  },
  isOptionalField = (schema: unknown): boolean => {
    let cur = schema as undefined | ZodSchema
    while (cur && typeof cur === 'object' && 'type' in cur) {
      if (cur.type === 'optional') return true
      if (!WRAPPERS.has(cur.type)) return false
      cur = (cur.def as { innerType?: ZodSchema }).innerType
    }
    return false
  },
  elementOf = (s: undefined | ZodSchema): unknown => (s?.def as undefined | { element?: unknown })?.element,
  cvMetaOf = (schema: undefined | ZodSchema): CvMeta | undefined => {
    if (!schema || typeof schema.meta !== 'function') return
    const m = schema.meta() as undefined | { cv?: unknown }
    if (m && typeof m === 'object') {
      const { cv } = m
      if (cv === 'file' || cv === 'files') return cv
    }
  },
  isArrayType = (t: '' | DefType) => t === 'array',
  isBooleanType = (t: '' | DefType) => t === 'boolean',
  isDateType = (t: '' | DefType) => t === 'date',
  isNumberType = (t: '' | DefType) => t === 'number',
  isStringType = (t: '' | DefType) => t === 'string' || t === 'enum',
  cvFileKindOf = (schema: unknown): CvMeta | undefined => {
    const { schema: s, type } = unwrapZod(schema),
      cv = cvMetaOf(s)
    if (cv) return cv
    if (isArrayType(type) && cvMetaOf(elementOf(s) as undefined | ZodSchema) === 'file') return 'files'
  },
  enumToOptions = <T extends string>(
    schema: { options: readonly T[] },
    transform?: (v: T) => string
  ): {
    label: string
    value: T
  }[] =>
    schema.options.map(v => ({
      label: transform?.(v) ?? v.charAt(0).toUpperCase() + v.slice(1),
      value: v
    })),
  requiredPartial = <S extends ZodObject<ZodRawShape>>(
    schema: S,
    requiredKeys: (keyof S['shape'])[]
  ): ZodObject<ZodRawShape> => {
    const partial = schema.partial(),
      required = Object.fromEntries(requiredKeys.map(k => [k, true])) as Record<string, true>
    return partial.required(required) as ZodObject<ZodRawShape>
  },
  // eslint-disable-next-line max-statements
  defaultValue = (schema: unknown): unknown => {
    const { schema: base, type } = unwrapZod(schema),
      fk = cvFileKindOf(schema)
    if (fk === 'file') return null
    if (fk === 'files') return []
    if (isArrayType(type)) return []
    if (isBooleanType(type)) return false
    if (isNumberType(type)) return 0
    if (isStringType(type)) {
      if (base && 'options' in base) {
        const opts = (base as { options: readonly string[] }).options
        if (opts.length) return opts[0]
      }
      return ''
    }
    if (isDateType(type)) return null
    const inner = (base?.def as undefined | { innerType?: unknown })?.innerType
    if (inner) return defaultValue(inner)
  },
  defaultValues = <S extends ZodObject<ZodRawShape>>(schema: S): output<S> => {
    const result: Record<string, unknown> = {}
    // biome-ignore lint/nursery/noForIn: iterating shape keys with hasOwn guard
    for (const k in schema.shape) if (Object.hasOwn(schema.shape, k)) result[k] = defaultValue(schema.shape[k])
    return result as output<S>
  },
  pickValues = <S extends ZodObject<ZodRawShape>>(schema: S, doc: object): output<S> => {
    const d = doc as Record<string, unknown>,
      result: Record<string, unknown> = {}
    // biome-ignore lint/nursery/noForIn: iterating shape keys with hasOwn guard
    for (const k in schema.shape) if (Object.hasOwn(schema.shape, k)) result[k] = d[k] ?? defaultValue(schema.shape[k])
    return result as output<S>
  },
  coerceOptionals = <S extends ZodObject<ZodRawShape>>(schema: S, data: output<S>): output<S> => {
    const result: Record<string, unknown> = { ...data }
    for (const k of Object.keys(result))
      if (isOptionalField(schema.shape[k]) && isStringType(unwrapZod(schema.shape[k]).type)) {
        const v = result[k]
        if (typeof v === 'string') {
          const trimmed = v.trim()
          result[k] = trimmed.length > 0 ? trimmed : undefined
        }
      }
    return result as output<S>
  }

export type { CvMeta, DefType, ZodSchema }
export {
  coerceOptionals,
  cvFileKindOf,
  cvMetaOf,
  defaultValue,
  defaultValues,
  elementOf,
  enumToOptions,
  isArrayType,
  isBooleanType,
  isDateType,
  isNumberType,
  isOptionalField,
  isStringType,
  pickValues,
  requiredPartial,
  unwrapZod
}
