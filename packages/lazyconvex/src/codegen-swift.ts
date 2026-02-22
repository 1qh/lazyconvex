#!/usr/bin/env bun
import type { ZodType } from 'zod/v4'

import { readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join, resolve } from 'node:path'

interface FieldEntry {
  isOptional: boolean
  swiftType: string
}

interface SchemaModule {
  base?: Record<string, ZodType>
  children?: Record<string, { schema: ZodType }>
  orgScoped?: Record<string, ZodType>
  owned?: Record<string, ZodType>
  singleton?: Record<string, ZodType>
}

interface ZodDef {
  element?: { _zod: { def: ZodDef } }
  entries?: Record<string, string>
  innerType?: { _zod: { def: ZodDef } }
  options?: { _zod: { def: ZodDef } }[]
  properties?: Record<string, { _zod: { def: ZodDef } }>
  shape?: Record<string, { _zod: { def: ZodDef } }>
  type: string
  values?: string[]
}

const parseArgs = (): { convex: string; output: string; schema: string } => {
    const args = process.argv.slice(2),
      r = { convex: '', output: '', schema: '' }
    for (let i = 0; i < args.length; i += 1) {
      const arg = args[i] ?? ''
      if (arg === '--schema' && args[i + 1]) r.schema = args[(i += 1)] ?? ''
      else if (arg === '--convex' && args[i + 1]) r.convex = args[(i += 1)] ?? ''
      else if (arg === '--output' && args[i + 1]) r.output = args[(i += 1)] ?? ''
    }
    if (!(r.schema && r.convex && r.output)) {
      process.stderr.write('Usage: lazyconvex-codegen-swift --schema <path> --convex <path> --output <path>\n')
      process.exit(1)
    }
    return { convex: resolve(r.convex), output: resolve(r.output), schema: resolve(r.schema) }
  },
  { convex: CONVEX_DIR, output: OUTPUT_PATH, schema: SCHEMA_PATH } = parseArgs(),
  mod = (await import(SCHEMA_PATH)) as SchemaModule,
  owned = mod.owned ?? {},
  orgScoped = mod.orgScoped ?? {},
  base = mod.base ?? {},
  singleton = mod.singleton ?? {},
  children = (mod.children ?? {}) as Record<string, { schema: ZodType }>,
  getDef = (schema: ZodType): ZodDef => (schema as unknown as { _zod: { def: ZodDef } })._zod.def,
  indent = (n: number) => '    '.repeat(n),
  capitalize = (s: string): string => s.charAt(0).toUpperCase() + s.slice(1),
  SPLIT_RE = /[_-]/u,
  pascalCase = (s: string): string => {
    const parts = s.split(SPLIT_RE)
    let result = ''
    for (const p of parts) result += capitalize(p)
    return result
  },
  SWIFT_NAME_MAP: Record<string, string> = {
    Task: 'TaskItem'
  },
  safeSwiftName = (name: string): string => SWIFT_NAME_MAP[name] ?? name,
  enumName = (modelName: string, fieldName: string): string => `${capitalize(modelName)}${capitalize(fieldName)}`,
  enumRegistry = new Map<string, string[]>(),
  pendingLines: string[][] = [],
  nestedEmitted = new Set<string>(),
  unionDiscriminantEnums = new Set<string>(),
  detectFileKind = (def: ZodDef): 'file' | 'files' | null => {
    const { type } = def
    if (type === 'optional' || type === 'nullable') return detectFileKind(def.innerType?._zod.def ?? def)
    if (type === 'custom') return 'file'
    if (type === 'array') {
      const elDef = def.element?._zod.def
      if (elDef && detectFileKind(elDef) === 'file') return 'files'
    }
    return null
  },
  resolveSimpleType = (type: string): null | { isOptional: boolean; swiftType: string } => {
    if (type === 'string') return { isOptional: false, swiftType: 'String' }
    if (type === 'number' || type === 'float' || type === 'int') return { isOptional: false, swiftType: 'Double' }
    if (type === 'boolean') return { isOptional: false, swiftType: 'Bool' }
    if (type === 'custom') return { isOptional: false, swiftType: 'String' }
    return null
  },
  // eslint-disable-next-line complexity, max-statements
  resolveType = (def: ZodDef, modelName: string, fieldName: string): { isOptional: boolean; swiftType: string } => {
    const { type } = def
    if (type === 'optional' || type === 'nullable') {
      const inner = resolveType(def.innerType?._zod.def ?? def, modelName, fieldName)
      return { isOptional: true, swiftType: inner.swiftType }
    }

    const simple = resolveSimpleType(type)
    if (simple) return simple

    if (type === 'enum') {
      const values = def.values ?? (def.entries ? Object.keys(def.entries) : []),
        name = enumName(modelName, fieldName)
      enumRegistry.set(name, values)
      return { isOptional: false, swiftType: name }
    }

    if (type === 'array') {
      const elDef = def.element?._zod.def ?? def
      if (elDef.type === 'custom') return { isOptional: false, swiftType: '[String]' }
      const singularField = fieldName.endsWith('s') ? fieldName.slice(0, -1) : fieldName,
        inner = resolveType(elDef, modelName, singularField)
      return { isOptional: false, swiftType: `[${inner.swiftType}]` }
    }

    if (type === 'union' && def.options) {
      const name = enumName(modelName, fieldName)
      // eslint-disable-next-line @typescript-eslint/no-use-before-define
      collectUnionStruct(name, def.options)
      return { isOptional: false, swiftType: name }
    }

    if (type === 'object' && (def.shape ?? def.properties)) {
      const shape = def.shape ?? def.properties ?? {},
        name = `${capitalize(modelName)}${capitalize(fieldName)}`
      // eslint-disable-next-line @typescript-eslint/no-use-before-define
      collectNestedStruct(name, shape)
      return { isOptional: false, swiftType: name }
    }

    return { isOptional: false, swiftType: 'String' }
  },
  resolveFields = (block: string[], shape: Record<string, { _zod: { def: ZodDef } }>, ctx: string) => {
    for (const [fieldName, fieldSchema] of Object.entries(shape)) {
      const resolved = resolveType(fieldSchema._zod.def, ctx, fieldName),
        swiftType = resolved.isOptional ? `${resolved.swiftType}?` : resolved.swiftType
      block.push(`${indent(1)}public let ${fieldName}: ${swiftType}`)
    }
  },
  collectNestedStruct = (name: string, shape: Record<string, { _zod: { def: ZodDef } }>) => {
    if (nestedEmitted.has(name)) return
    nestedEmitted.add(name)

    const block = [`public struct ${name}: Codable, Sendable {`]
    resolveFields(block, shape, name.toLowerCase())
    block.push('}', '')
    pendingLines.push(block)
  },
  extractEnumValues = (optDef: ZodDef): string[] => {
    const shape = optDef.shape ?? optDef.properties ?? {},
      result: string[] = []
    for (const [k, v] of Object.entries(shape))
      if (k === 'type') {
        const tDef = v._zod.def
        if (tDef.type === 'enum') {
          const vals = tDef.values ?? (tDef.entries ? Object.keys(tDef.entries) : [])
          for (const val of vals) result.push(val)
        }
      }

    return result
  },
  collectUnionTypeValues = (options: { _zod: { def: ZodDef } }[]): string[] => {
    const typeValues: string[] = []
    for (const opt of options) for (const val of extractEnumValues(opt._zod.def)) typeValues.push(val)

    return typeValues
  },
  collectUnionFieldTypes = (
    options: { _zod: { def: ZodDef } }[],
    name: string,
    typEnumName: string
  ): Map<string, { isOptional: boolean; swiftType: string }> => {
    const fieldTypes = new Map<string, { isOptional: boolean; swiftType: string }>([
      ['type', { isOptional: false, swiftType: typEnumName }]
    ])
    for (const opt of options) {
      const optDef = opt._zod.def,
        shape = optDef.shape ?? optDef.properties ?? {}
      for (const [k, v] of Object.entries(shape))
        if (k !== 'type' && !fieldTypes.has(k)) {
          const resolved = resolveType(v._zod.def, name, k)
          fieldTypes.set(k, { isOptional: true, swiftType: resolved.swiftType })
        }
    }
    return fieldTypes
  },
  registerUnionEnum = (typEnumName: string, typeValues: string[]) => {
    if (typeValues.length > 0) {
      enumRegistry.set(typEnumName, typeValues)
      unionDiscriminantEnums.add(typEnumName)
    }
  },
  emitUnionBlock = (fieldTypes: Map<string, { isOptional: boolean; swiftType: string }>, name: string) => {
    const block = [`public struct ${name}: Codable, Sendable {`]
    for (const [fieldName, field] of fieldTypes) {
      const swiftType = field.isOptional ? `${field.swiftType}?` : field.swiftType
      block.push(`${indent(1)}public let ${fieldName}: ${swiftType}`)
    }
    block.push('}', '')
    pendingLines.push(block)
  },
  collectUnionStruct = (name: string, options: { _zod: { def: ZodDef } }[]) => {
    if (nestedEmitted.has(name)) return
    nestedEmitted.add(name)

    const typeValues = collectUnionTypeValues(options),
      typEnumName = `${name}Type`
    registerUnionEnum(typEnumName, typeValues)
    const fieldTypes = collectUnionFieldTypes(options, name, typEnumName)
    emitUnionBlock(fieldTypes, name)
  },
  factoryFields: Record<string, Map<string, FieldEntry>> = {},
  addAutoFileUrlFields = (fields: Map<string, FieldEntry>, shape: Record<string, { _zod: { def: ZodDef } }>) => {
    for (const [fieldName, fieldSchema] of Object.entries(shape)) {
      const kind = detectFileKind(fieldSchema._zod.def)
      if (kind === 'files') fields.set(`${fieldName}Urls`, { isOptional: true, swiftType: '[String]' })
      else if (kind === 'file') fields.set(`${fieldName}Url`, { isOptional: true, swiftType: 'String' })
    }
  },
  resolveSchemaFields = (
    shape: Record<string, { _zod: { def: ZodDef } }>,
    tableName: string,
    extraFields: Map<string, FieldEntry>
  ): Map<string, FieldEntry> => {
    const fields = new Map<string, FieldEntry>(extraFields)
    for (const [fieldName, fieldSchema] of Object.entries(shape)) {
      const resolved = resolveType(fieldSchema._zod.def, tableName, fieldName)
      fields.set(fieldName, resolved)
    }
    addAutoFileUrlFields(fields, shape)
    return fields
  },
  collectSchemas = (schemas: Record<string, ZodType>, extraFields: Map<string, FieldEntry>) => {
    for (const [tableName, schema] of Object.entries(schemas)) {
      const def = getDef(schema),
        shape = def.shape ?? def.properties
      if (shape) factoryFields[tableName] = resolveSchemaFields(shape, tableName, extraFields)
    }
  },
  extractBalancedBlock = (content: string, startIdx: number): null | string => {
    let depth = 0,
      i = startIdx
    while (i < content.length) {
      if (content[i] === '{') depth += 1
      else if (content[i] === '}') {
        depth -= 1
        if (depth === 0) return content.slice(startIdx + 1, i)
      }
      i += 1
    }
    return null
  },
  isContinuationLine = (rest: string): boolean =>
    rest.startsWith(',') || rest.startsWith('{') || rest.startsWith('//') || rest.startsWith('/*'),
  extractStatement = (content: string, startIdx: number): string => {
    let i = startIdx,
      depth = 0
    while (i < content.length) {
      const ch = content[i] ?? ''
      if (ch === '(' || ch === '{' || ch === '[') depth += 1
      else if (ch === ')' || ch === '}' || ch === ']') depth -= 1
      if (depth < 0) break
      if (depth === 0 && ch === '\n') {
        const rest = content.slice(i + 1).trimStart()
        if (!isContinuationLine(rest)) break
      }
      i += 1
    }
    return content.slice(startIdx, i)
  },
  ALPHA_RE = /[a-zA-Z_]/u,
  WORD_RE = /[\w]/u,
  AS_RE = /\s+as\s+/u,
  IDENT_RE = /^[a-zA-Z_]\w*$/u,
  parseName = (s: string, results: string[]) => {
    const colonIdx = s.indexOf(':')
    if (colonIdx === -1) {
      const name = (s.split(AS_RE)[0] ?? '').trim()
      if (IDENT_RE.test(name)) results.push(name)
    } else {
      const renamed = s.slice(colonIdx + 1).trim()
      if (IDENT_RE.test(renamed)) results.push(renamed)
    }
  },
  parseNameList = (text: string, results: string[]) => {
    for (const sub of text.split(',')) {
      const s = sub.trim()
      if (s) parseName(s, results)
    }
  },
  // eslint-disable-next-line max-statements
  extractNames = (block: string): string[] => {
    const results: string[] = []
    let depth = 0,
      current = ''

    for (const ch of block)
      if (ch === '{') {
        if (depth === 0) current = ''
        else if (depth > 0) current += ch
        depth += 1
      } else if (ch === '}') {
        depth -= 1
        if (depth > 0) current += ch
        else if (depth === 0) {
          const trimmed = current.trim()
          if (trimmed) parseNameList(trimmed, results)
          current = ''
        }
      } else if (depth >= 1) current += ch
      else if (ch === ',' || ch === '\n') {
        const trimmed = current.trim()
        if (trimmed) parseName(trimmed, results)
        current = ''
      } else current += ch

    const trimmed = current.trim()
    if (trimmed) parseName(trimmed, results)
    return results
  },
  skipToNextBinding = (stmt: string, i: number): number => {
    let depth = 0,
      pos = i
    while (pos < stmt.length) {
      if (stmt[pos] === '(' || stmt[pos] === '{' || stmt[pos] === '[') depth += 1
      else if (stmt[pos] === ')' || stmt[pos] === '}' || stmt[pos] === ']') depth -= 1
      if (depth === 0 && stmt[pos] === ',') break
      pos += 1
    }
    return pos
  },
  readIdentifier = (stmt: string, start: number): { end: number; name: string } => {
    let i = start,
      name = ''
    while (i < stmt.length && WORD_RE.test(stmt[i] ?? '')) {
      name += stmt[i]
      i += 1
    }
    return { end: i, name }
  },
  // eslint-disable-next-line max-statements
  extractAllBindings = (stmt: string): string[] => {
    const results: string[] = []
    let i = 0
    while (i < stmt.length)
      if (stmt[i] === '{') {
        const block = extractBalancedBlock(stmt, i)
        if (block) {
          const afterClose = i + block.length + 2,
            afterBlock = stmt.slice(afterClose).trimStart()
          // eslint-disable-next-line max-depth
          if (afterBlock.startsWith('=')) for (const name of extractNames(block)) results.push(name)

          i = afterClose
        } else i += 1
      } else if (ALPHA_RE.test(stmt[i] ?? '')) {
        const id = readIdentifier(stmt, i)
        i = id.end
        const afterName = stmt.slice(i).trimStart()
        if (afterName.startsWith('=') && !afterName.startsWith('==')) {
          results.push(id.name)
          i = skipToNextBinding(stmt, i)
        }
      } else i += 1

    return results
  },
  extractSimpleNames = (block: string): string[] => {
    const results: string[] = [],
      parts = block.split(',')
    for (const part of parts) {
      const trimmed = part.trim()
      if (trimmed) {
        const name = (trimmed.split(AS_RE)[0] ?? '').trim()
        if (IDENT_RE.test(name)) results.push(name)
      }
    }
    return results
  },
  parseExportConsts = (content: string, fns: Set<string>) => {
    const exportConsts = content.matchAll(/export\s+(?:const|let)\s/gu)
    for (const m of exportConsts) {
      const idx = m.index,
        stmtStart = idx + m[0].length,
        stmt = extractStatement(content, stmtStart)
      for (const name of extractAllBindings(stmt)) fns.add(name)
    }
  },
  parseTrailingExports = (content: string, fns: Set<string>) => {
    const trailingExport = content.matchAll(/export\s+\{(?<names>[^}]+)\}/gu)
    for (const tm of trailingExport) {
      const block = tm.groups?.names ?? ''
      for (const name of extractSimpleNames(block)) fns.add(name)
    }
  },
  getExportedFunctions = (filePath: string): string[] => {
    try {
      const content = readFileSync(filePath, 'utf8'),
        fns = new Set<string>()
      parseExportConsts(content, fns)
      parseTrailingExports(content, fns)
      return [...fns]
    } catch {
      return []
    }
  },
  SKIP_MODULES = new Set(['_generated', 'auth', 'auth.config', 'http', 'schema', 'testauth']),
  collectModules = (): Record<string, string[]> => {
    const modules: Record<string, string[]> = {},
      files = readdirSync(CONVEX_DIR)

    for (const file of files)
      if (file.endsWith('.ts') && !file.includes('.test.')) {
        const modName = file.replace('.ts', '')
        if (!SKIP_MODULES.has(modName)) {
          const fns = getExportedFunctions(join(CONVEX_DIR, file))
          if (fns.length > 0) modules[modName] = fns
        }
      }

    return modules
  },
  ownedExtra = new Map<string, FieldEntry>([
    ['_creationTime', { isOptional: false, swiftType: 'Double' }],
    ['_id', { isOptional: false, swiftType: 'String' }],
    ['author', { isOptional: true, swiftType: 'Author' }],
    ['updatedAt', { isOptional: false, swiftType: 'Double' }],
    ['userId', { isOptional: false, swiftType: 'String' }]
  ]),
  orgScopedExtra = new Map<string, FieldEntry>([
    ['_creationTime', { isOptional: false, swiftType: 'Double' }],
    ['_id', { isOptional: false, swiftType: 'String' }],
    ['orgId', { isOptional: false, swiftType: 'String' }],
    ['updatedAt', { isOptional: false, swiftType: 'Double' }],
    ['userId', { isOptional: false, swiftType: 'String' }]
  ]),
  baseExtra = new Map<string, FieldEntry>([
    ['_creationTime', { isOptional: true, swiftType: 'Double' }],
    ['_id', { isOptional: true, swiftType: 'String' }],
    ['cacheHit', { isOptional: true, swiftType: 'Bool' }]
  ]),
  singletonExtra = new Map<string, FieldEntry>([['_id', { isOptional: true, swiftType: 'String' }]]),
  childExtra = new Map<string, FieldEntry>([
    ['_creationTime', { isOptional: false, swiftType: 'Double' }],
    ['_id', { isOptional: false, swiftType: 'String' }],
    ['updatedAt', { isOptional: true, swiftType: 'Double' }],
    ['userId', { isOptional: true, swiftType: 'String' }]
  ])

collectSchemas(owned, ownedExtra)
collectSchemas(orgScoped, orgScopedExtra)
collectSchemas(base, baseExtra)
collectSchemas(singleton, singletonExtra)

for (const [childName, childDef] of Object.entries(children)) {
  const def = getDef(childDef.schema),
    shape = def.shape ?? def.properties
  if (shape) factoryFields[childName] = resolveSchemaFields(shape, childName, childExtra)
}

const lines: string[] = [],
  emit = (s: string) => lines.push(s)

emit('// swiftlint:disable file_types_order')
emit('import Foundation')
emit('')

for (const block of pendingLines) for (const line of block) emit(line)

for (const [name, values] of enumRegistry) {
  const sorted = [...values].toSorted()
  emit(`public enum ${name}: String, Codable, Sendable {`)
  for (const v of sorted)
    if (/^[a-z_][a-z0-9_]*$/iu.test(v) && v !== 'default') emit(`${indent(1)}case ${v}`)
    else {
      const safe = v.replaceAll(/[^a-zA-Z0-9_]/gu, '_')
      emit(`${indent(1)}case ${safe} = "${v}"`)
    }

  emit('}')
  emit('')
}

const emittedStructs = new Set<string>(),
  emitIdAccessor = (fields: Map<string, FieldEntry>) => {
    const idField = fields.get('_id')
    emit('')
    if (idField?.isOptional) emit(`${indent(1)}public var id: String { _id ?? "" }`)
    else emit(`${indent(1)}public var id: String { _id }`)
  }

for (const [tableName, fields] of Object.entries(factoryFields)) {
  const rawName = pascalCase(tableName),
    structName = safeSwiftName(rawName)
  if (!emittedStructs.has(structName)) {
    emittedStructs.add(structName)

    const hasId = fields.has('_id'),
      protocols = hasId ? 'Codable, Identifiable, Sendable' : 'Codable, Sendable'
    emit(`public struct ${structName}: ${protocols} {`)

    for (const [fieldName, field] of fields) {
      const swiftType = field.isOptional ? `${field.swiftType}?` : field.swiftType
      emit(`${indent(1)}public let ${fieldName}: ${swiftType}`)
    }

    if (hasId) emitIdAccessor(fields)

    emit('}')
    emit('')
  }
}

emit('public struct Author: Codable, Sendable {')
emit(`${indent(1)}public let name: String?`)
emit(`${indent(1)}public let email: String?`)
emit(`${indent(1)}public let imageUrl: String?`)
emit('}')
emit('')

emit('#if !SKIP')
emit('public struct PaginatedResult<T: Codable & Sendable>: Codable, Sendable {')
emit(`${indent(1)}public let page: [T]`)
emit(`${indent(1)}public let continueCursor: String`)
emit(`${indent(1)}public let isDone: Bool`)
emit('')
emit(`${indent(1)}public init(page: [T], continueCursor: String, isDone: Bool) {`)
emit(`${indent(2)}self.page = page`)
emit(`${indent(2)}self.continueCursor = continueCursor`)
emit(`${indent(2)}self.isDone = isDone`)
emit(`${indent(1)}}`)
emit('}')
emit('#else')
emit('public struct PaginatedResult<T: Codable & Sendable>: Sendable {')
emit(`${indent(1)}public let page: [T]`)
emit(`${indent(1)}public let continueCursor: String`)
emit(`${indent(1)}public let isDone: Bool`)
emit('')
emit(`${indent(1)}public init(page: [T], continueCursor: String, isDone: Bool) {`)
emit(`${indent(2)}self.page = page`)
emit(`${indent(2)}self.continueCursor = continueCursor`)
emit(`${indent(2)}self.isDone = isDone`)
emit(`${indent(1)}}`)
emit('}')
emit('#endif')
emit('')

emit('public struct Org: Codable, Identifiable, Sendable {')
emit(`${indent(1)}public let _id: String`)
emit(`${indent(1)}public let _creationTime: Double`)
emit(`${indent(1)}public let name: String`)
emit(`${indent(1)}public let slug: String`)
emit(`${indent(1)}public let userId: String`)
emit(`${indent(1)}public let updatedAt: Double`)
emit('')
emit(`${indent(1)}public var id: String { _id }`)
emit('}')
emit('')

emit('public struct OrgMember: Codable, Identifiable, Sendable {')
emit(`${indent(1)}public let _id: String`)
emit(`${indent(1)}public let orgId: String`)
emit(`${indent(1)}public let userId: String`)
emit(`${indent(1)}public let isAdmin: Bool`)
emit(`${indent(1)}public let updatedAt: Double`)
emit('')
emit(`${indent(1)}public var id: String { _id }`)
emit('}')
emit('')

emit('public struct OrgMemberEntry: Codable, Identifiable, Sendable {')
emit(`${indent(1)}public let userId: String`)
emit(`${indent(1)}public let role: String`)
emit(`${indent(1)}public let name: String?`)
emit(`${indent(1)}public let email: String?`)
emit(`${indent(1)}public let imageUrl: String?`)
emit('')
emit(`${indent(1)}public var id: String { userId }`)
emit('}')
emit('')

emit('public struct OrgWithRole: Codable, Identifiable, Sendable {')
emit(`${indent(1)}public let org: Org`)
emit(`${indent(1)}public let role: String`)
emit('')
emit(`${indent(1)}public var id: String { org._id }`)
emit('}')
emit('')

emit('public struct OrgMembership: Codable, Sendable {')
emit(`${indent(1)}public let _id: String?`)
emit(`${indent(1)}public let orgId: String?`)
emit(`${indent(1)}public let userId: String?`)
emit(`${indent(1)}public let isAdmin: Bool?`)
emit(`${indent(1)}public let role: String?`)
emit('}')
emit('')

emit('public struct OrgInvite: Codable, Identifiable, Sendable {')
emit(`${indent(1)}public let _id: String`)
emit(`${indent(1)}public let orgId: String`)
emit(`${indent(1)}public let email: String`)
emit(`${indent(1)}public let expiresAt: Double`)
emit('')
emit(`${indent(1)}public var id: String { _id }`)
emit('}')
emit('')

emit('public struct OrgJoinRequest: Codable, Identifiable, Sendable {')
emit(`${indent(1)}public let _id: String`)
emit(`${indent(1)}public let orgId: String`)
emit(`${indent(1)}public let userId: String`)
emit(`${indent(1)}public let status: String`)
emit('')
emit(`${indent(1)}public var id: String { _id }`)
emit('}')
emit('')

const modules = collectModules()

for (const [modName, fns] of Object.entries(modules)) {
  const apiName = `${pascalCase(modName)}API`
  emit(`public enum ${apiName} {`)
  for (const fn of fns) emit(`${indent(1)}public static let ${fn} = "${modName}:${fn}"`)

  emit('}')
  emit('')
}

emit('// swiftlint:enable file_types_order')

const output = `${lines.join('\n')}\n`
writeFileSync(OUTPUT_PATH, output)

const structCount = emittedStructs.size + nestedEmitted.size,
  enumCount = enumRegistry.size,
  moduleCount = Object.keys(modules).length
let fnCount = 0
for (const fns of Object.values(modules)) fnCount += fns.length

process.stdout.write(
  `Generated ${OUTPUT_PATH}\n  ${String(structCount)} structs, ${String(enumCount)} enums, ${String(moduleCount)} modules, ${String(fnCount)} API constants\n`
)
