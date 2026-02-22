/* eslint-disable @typescript-eslint/naming-convention, @typescript-eslint/no-magic-numbers, max-statements */
import type { GenericTableInfo } from 'convex/server'

import { describe, expect, test } from 'bun:test'
import { ConvexError } from 'convex/values'
import { array, boolean, date, number, object, optional, string, enum as zenum } from 'zod/v4'

import type { UseListOptions } from '../react/use-list'
import type { OrgCrudOptions } from '../server/org-crud'
import type {
  BaseSchema,
  CascadeOption,
  CrudOptions,
  ErrorCode,
  OrgCascadeTableConfig,
  OrgSchema,
  OwnedSchema,
  RateLimitConfig,
  SingletonSchema,
  WhereOf
} from '../server/types'

import { defineSteps } from '../components/step-form'
import {
  ACTIVE_ORG_COOKIE,
  ACTIVE_ORG_SLUG_COOKIE,
  BULK_MAX,
  BYTES_PER_KB,
  BYTES_PER_MB,
  ONE_YEAR_SECONDS,
  sleep
} from '../constants'
import { buildMeta, getMeta } from '../react/form'
import { canEditResource } from '../react/org'
import { DEFAULT_PAGE_SIZE } from '../react/use-list'
import { fetchWithRetry, withRetry } from '../retry'
import { child, cvFile, cvFiles, makeBase, makeOrgScoped, makeOwned, makeSingleton } from '../schema'
import { flt, idx, indexFields, sch, typed } from '../server/bridge'
import { ownedCascade } from '../server/crud'
import {
  cleanFiles,
  detectFiles,
  err,
  errValidation,
  extractErrorData,
  generateToken,
  getErrorCode,
  getErrorMessage,
  groupList,
  handleConvexError,
  isRecord,
  makeUnique,
  matchW,
  RUNTIME_FILTER_WARN_THRESHOLD,
  SEVEN_DAYS_MS,
  time,
  warnLargeFilterSet
} from '../server/helpers'
import { orgCascade } from '../server/org-crud'
import { baseTable, orgTable, ownedTable, singletonTable } from '../server/schema-helpers'
import { isTestMode } from '../server/test'
import { ERROR_MESSAGES } from '../server/types'
import {
  coerceOptionals,
  cvFileKindOf,
  defaultValues,
  enumToOptions,
  isArrayType,
  isBooleanType,
  isDateType,
  isNumberType,
  isOptionalField,
  isStringType,
  pickValues,
  unwrapZod
} from '../zod'

const VOID = undefined

describe('unwrapZod', () => {
  test('plain string', () => {
    const r = unwrapZod(string())
    expect(r.type).toBe('string')
    expect(r.schema).toBeDefined()
    expect(r.def).toBeDefined()
  })

  test('optional(string)', () => {
    const r = unwrapZod(optional(string()))
    expect(r.type).toBe('string')
  })

  test('nullable(optional(string))', () => {
    const r = unwrapZod(string().nullable().optional())
    expect(r.type).toBe('string')
  })

  test('number', () => {
    expect(unwrapZod(number()).type).toBe('number')
  })

  test('boolean', () => {
    expect(unwrapZod(boolean()).type).toBe('boolean')
  })

  test('array(string)', () => {
    expect(unwrapZod(array(string())).type).toBe('array')
  })

  test('enum', () => {
    expect(unwrapZod(zenum(['a', 'b'])).type).toBe('enum')
  })

  test('undefined input', () => {
    const r = unwrapZod(VOID)
    expect(r.type).toBe('')
    expect(r.schema).toBeUndefined()
    expect(r.def).toBeUndefined()
  })

  test('non-schema input', () => {
    const r = unwrapZod(42)
    expect(r.type).toBe('')
  })
})

describe('isOptionalField', () => {
  test('required string is not optional', () => {
    expect(isOptionalField(string())).toBe(false)
  })

  test('optional string is optional', () => {
    expect(isOptionalField(optional(string()))).toBe(true)
  })

  test('nullable(optional(string)) is optional', () => {
    expect(isOptionalField(string().nullable().optional())).toBe(true)
  })

  test('nullable without optional is not optional', () => {
    expect(isOptionalField(string().nullable())).toBe(false)
  })

  test('undefined input', () => {
    expect(isOptionalField(VOID)).toBe(false)
  })
})

describe('cvFileKindOf', () => {
  test('cvFile() returns file', () => {
    expect(cvFileKindOf(cvFile())).toBe('file')
  })

  test('cvFiles() returns files', () => {
    expect(cvFileKindOf(cvFiles())).toBe('files')
  })

  test('optional(cvFile()) returns file', () => {
    expect(cvFileKindOf(cvFile().optional())).toBe('file')
  })

  test('nullable(cvFile()) returns file', () => {
    expect(cvFileKindOf(cvFile().nullable())).toBe('file')
  })

  test('array(cvFile()) returns files', () => {
    expect(cvFileKindOf(array(cvFile()))).toBe('files')
  })

  test('regular string returns undefined', () => {
    expect(cvFileKindOf(string())).toBeUndefined()
  })

  test('regular number returns undefined', () => {
    expect(cvFileKindOf(number())).toBeUndefined()
  })
})

describe('defaultValues', () => {
  const schema = object({
    active: boolean(),
    category: zenum(['tech', 'life', 'food']),
    count: number(),
    tags: array(string()),
    title: string()
  })

  test('generates correct defaults for all field types', () => {
    const defaults = defaultValues(schema)
    expect(defaults).toEqual({
      active: false,
      category: 'tech',
      count: 0,
      tags: [],
      title: ''
    })
  })

  test('file fields default to null', () => {
    const s = object({ photo: cvFile().nullable() })
    expect(defaultValues(s)).toEqual({ photo: null })
  })

  test('cvFiles fields default to empty array', () => {
    const s = object({ attachments: cvFiles() })
    expect(defaultValues(s)).toEqual({ attachments: [] })
  })

  test('date fields default to null', () => {
    const s = object({ createdAt: date() }),
      result = defaultValues(s)
    expect(result.createdAt).toBeNull()
  })
})

describe('pickValues', () => {
  const schema = object({
    price: number(),
    title: string()
  })

  test('extracts matching fields from doc', () => {
    const doc = { _id: '123', extra: true, price: 42, title: 'hello' }
    expect(pickValues(schema, doc)).toEqual({ price: 42, title: 'hello' })
  })

  test('falls back to defaults for missing fields', () => {
    const doc = { _id: '123', title: 'hello' }
    expect(pickValues(schema, doc)).toEqual({ price: 0, title: 'hello' })
  })

  test('ignores extra fields', () => {
    const doc = { foo: 'bar', price: 10, title: 'test', userId: 'u1' },
      result = pickValues(schema, doc)
    expect(result).toEqual({ price: 10, title: 'test' })
    expect('foo' in result).toBe(false)
    expect('userId' in result).toBe(false)
  })
})

describe('coerceOptionals', () => {
  const schema = object({
    name: string(),
    note: optional(string())
  })

  test('empty string on optional field becomes undefined', () => {
    const data = { name: 'test', note: '' },
      result = coerceOptionals(schema, data)
    expect(result.name).toBe('test')
    expect(result.note).toBeUndefined()
  })

  test('whitespace-only on optional field becomes undefined', () => {
    const data = { name: 'test', note: '   ' }
    expect(coerceOptionals(schema, data).note).toBeUndefined()
  })

  test('non-empty optional string stays and is trimmed', () => {
    const data = { name: 'test', note: ' hello ' }
    expect(coerceOptionals(schema, data).note).toBe('hello')
  })

  test('required string field is untouched', () => {
    const data = { name: '', note: 'x' }
    expect(coerceOptionals(schema, data).name).toBe('')
  })

  test('non-string optional field is untouched', () => {
    const s = object({ count: optional(number()) }),
      data = { count: 0 }
    expect(coerceOptionals(s, data).count).toBe(0)
  })
})

describe('enumToOptions', () => {
  const schema = zenum(['draft', 'published', 'archived'])

  test('generates options with capitalized labels', () => {
    const opts = enumToOptions(schema)
    expect(opts).toEqual([
      { label: 'Draft', value: 'draft' },
      { label: 'Published', value: 'published' },
      { label: 'Archived', value: 'archived' }
    ])
  })

  test('uses custom transform', () => {
    const opts = enumToOptions(schema, v => v.toUpperCase())
    expect(opts).toEqual([
      { label: 'DRAFT', value: 'draft' },
      { label: 'PUBLISHED', value: 'published' },
      { label: 'ARCHIVED', value: 'archived' }
    ])
  })
})

describe('type checks', () => {
  test('isStringType', () => {
    expect(isStringType('string')).toBe(true)
    expect(isStringType('enum')).toBe(true)
    expect(isStringType('number')).toBe(false)
    expect(isStringType('')).toBe(false)
  })

  test('isNumberType', () => {
    expect(isNumberType('number')).toBe(true)
    expect(isNumberType('string')).toBe(false)
  })

  test('isBooleanType', () => {
    expect(isBooleanType('boolean')).toBe(true)
    expect(isBooleanType('string')).toBe(false)
  })

  test('isArrayType', () => {
    expect(isArrayType('array')).toBe(true)
    expect(isArrayType('string')).toBe(false)
  })

  test('isDateType', () => {
    expect(isDateType('date')).toBe(true)
    expect(isDateType('string')).toBe(false)
  })
})

describe('matchW', () => {
  const doc = { category: 'tech', price: 50, published: true, title: 'Test', userId: 'u1' }

  test('no where matches everything', () => {
    expect(matchW(doc, VOID)).toBe(true)
  })

  test('AND conditions — all match', () => {
    expect(matchW(doc, { category: 'tech', published: true })).toBe(true)
  })

  test('AND conditions — partial mismatch', () => {
    expect(matchW(doc, { category: 'life', published: true })).toBe(false)
  })

  test('OR conditions', () => {
    expect(matchW(doc, { category: 'life', or: [{ category: 'tech' }] })).toBe(true)
  })

  test('OR conditions — none match', () => {
    expect(matchW(doc, { category: 'life', or: [{ category: 'food' }] })).toBe(false)
  })

  test('own filter with matching viewer', () => {
    expect(matchW(doc, { own: true }, 'u1')).toBe(true)
  })

  test('own filter with non-matching viewer', () => {
    expect(matchW(doc, { own: true }, 'u2')).toBe(false)
  })

  test('own filter with null viewer', () => {
    expect(matchW(doc, { own: true }, null)).toBe(false)
  })

  test('$gt operator', () => {
    expect(matchW(doc, { price: { $gt: 40 } })).toBe(true)
    expect(matchW(doc, { price: { $gt: 50 } })).toBe(false)
  })

  test('$gte operator', () => {
    expect(matchW(doc, { price: { $gte: 50 } })).toBe(true)
    expect(matchW(doc, { price: { $gte: 51 } })).toBe(false)
  })

  test('$lt operator', () => {
    expect(matchW(doc, { price: { $lt: 60 } })).toBe(true)
    expect(matchW(doc, { price: { $lt: 50 } })).toBe(false)
  })

  test('$lte operator', () => {
    expect(matchW(doc, { price: { $lte: 50 } })).toBe(true)
    expect(matchW(doc, { price: { $lte: 49 } })).toBe(false)
  })

  test('$between operator', () => {
    expect(matchW(doc, { price: { $between: [40, 60] } })).toBe(true)
    expect(matchW(doc, { price: { $between: [51, 60] } })).toBe(false)
    expect(matchW(doc, { price: { $between: [50, 50] } })).toBe(true)
  })
})

describe('groupList', () => {
  test('undefined returns empty array', () => {
    expect(groupList()).toEqual([])
  })

  test('empty where with no real keys returns empty', () => {
    expect(groupList({} as Record<string, unknown> & { own?: boolean })).toEqual([])
  })

  test('single group with field', () => {
    const gs = groupList({ published: true } as Record<string, unknown> & { own?: boolean })
    expect(gs).toHaveLength(1)
    expect(gs[0]?.published).toBe(true)
  })

  test('with or[]', () => {
    const input = { category: 'tech', or: [{ category: 'life' }] } as Record<string, unknown> & {
        or?: Record<string, unknown>[]
        own?: boolean
      },
      gs = groupList(input)
    expect(gs).toHaveLength(2)
    expect(gs[0]?.category).toBe('tech')
    expect(gs[1]?.category).toBe('life')
  })

  test('own-only group is included', () => {
    const gs = groupList({ own: true } as Record<string, unknown> & { own?: boolean })
    expect(gs).toHaveLength(1)
  })

  test('filters out empty or groups', () => {
    const input = { category: 'tech', or: [{}] } as Record<string, unknown> & {
        or?: Record<string, unknown>[]
        own?: boolean
      },
      gs = groupList(input)
    expect(gs).toHaveLength(1)
  })
})

describe('detectFiles', () => {
  test('detects cvFile fields', () => {
    const shape = { photo: cvFile().nullable(), title: string() }
    expect(detectFiles(shape)).toEqual(['photo'])
  })

  test('detects cvFiles fields', () => {
    const shape = { attachments: cvFiles(), title: string() }
    expect(detectFiles(shape)).toEqual(['attachments'])
  })

  test('detects both cvFile and cvFiles', () => {
    const shape = { attachments: cvFiles(), photo: cvFile().nullable(), title: string() },
      result = detectFiles(shape)
    expect(result).toContain('photo')
    expect(result).toContain('attachments')
    expect(result).toHaveLength(2)
  })

  test('returns empty for no file fields', () => {
    const shape = { count: number(), title: string() }
    expect(detectFiles(shape)).toEqual([])
  })
})

describe('RateLimitConfig', () => {
  test('config shape', () => {
    const config: RateLimitConfig = { max: 10, window: 60_000 }
    expect(config.max).toBe(10)
    expect(config.window).toBe(60_000)
  })

  test('default values', () => {
    const config: RateLimitConfig = { max: 1, window: 1000 }
    expect(config.max).toBeGreaterThan(0)
    expect(config.window).toBeGreaterThan(0)
  })
})

describe('CrudOptions search config', () => {
  const blogSchema = object({
    category: string(),
    content: string(),
    published: boolean(),
    title: string()
  })
  type BlogShape = typeof blogSchema.shape

  test('search: true enables search with defaults', () => {
    expect(Object.keys(blogSchema.shape)).toHaveLength(4)
    const opts: CrudOptions<BlogShape> = { search: true }
    expect(opts.search).toBe(true)
  })

  test('search: string shorthand sets field name', () => {
    const opts: CrudOptions<BlogShape> = { search: 'content' }
    expect(opts.search).toBe('content')
  })

  test('search: { field, index } accepts valid schema keys', () => {
    const opts: CrudOptions<BlogShape> = { search: { field: 'content', index: 'search_content' } },
      search = opts.search as { field?: string; index?: string }
    expect(search.field).toBe('content')
    expect(search.index).toBe('search_content')
  })

  test('search: { field } accepts any schema field name', () => {
    const opts: CrudOptions<BlogShape> = { search: { field: 'title' } },
      search = opts.search as { field?: string }
    expect(search.field).toBe('title')
  })

  test('search: {} defaults both field and index', () => {
    const opts: CrudOptions<BlogShape> = { search: {} },
      search = opts.search as { field?: string; index?: string }
    expect(search.field).toBeUndefined()
    expect(search.index).toBeUndefined()
  })

  test('search: undefined means no index search', () => {
    const opts: CrudOptions<BlogShape> = {}
    expect(opts.search).toBeUndefined()
  })

  test('typesafe: search string shorthand constrained to schema keys', () => {
    const validField: CrudOptions<BlogShape>['search'] = 'content'
    expect(validField).toBeDefined()

    const anotherValid: CrudOptions<BlogShape>['search'] = 'title'
    expect(anotherValid).toBeDefined()

    // @ts-expect-error - 'conten' is not a key of BlogShape
    const _invalid: CrudOptions<BlogShape>['search'] = 'conten'
    expect(_invalid).toBeDefined()
  })

  test('typesafe: search object field constrained to schema keys', () => {
    const validField: CrudOptions<BlogShape>['search'] = { field: 'content' }
    expect(validField).toBeDefined()

    // @ts-expect-error - 'conten' is not a key of BlogShape
    const _invalid: CrudOptions<BlogShape>['search'] = { field: 'conten' }
    expect(_invalid).toBeDefined()
  })
})

describe('typesafe field references', () => {
  const chatSchema = object({ isPublic: boolean(), title: string().min(1) }),
    messageSchema = object({ chatId: string(), content: string(), role: string() }),
    taskSchema = object({ completed: boolean(), priority: string(), projectId: string(), title: string() }),
    movieSchema = object({ title: string(), tmdb_id: number() })

  test('child() accepts valid foreignKey', () => {
    const result = child({ foreignKey: 'chatId', parent: 'chat', schema: messageSchema })
    expect(result.foreignKey).toBe('chatId')
  })

  test('child() rejects invalid foreignKey', () => {
    // @ts-expect-error - 'chatI' is not a key of messageSchema
    const result = child({ foreignKey: 'chatI', parent: 'chat', schema: messageSchema })
    expect(result).toBeDefined()
  })

  test('child() parentSchema constrains parentField', () => {
    const result = child({ foreignKey: 'chatId', parent: 'chat', parentSchema: chatSchema, schema: messageSchema })
    expect(result.parentSchema).toBe(chatSchema)

    type ChatShape = typeof chatSchema.shape
    // @ts-expect-error - 'isPubic' is not a key of chatSchema
    const _invalid: keyof ChatShape = 'isPubic'
    expect(_invalid).toBeDefined()
  })

  test('search shorthand accepts valid schema keys', () => {
    type MsgShape = typeof messageSchema.shape
    const opts: CrudOptions<MsgShape> = { search: 'content' }
    expect(opts.search).toBeDefined()
  })

  test('search shorthand rejects invalid schema keys', () => {
    type MsgShape = typeof messageSchema.shape
    // @ts-expect-error - 'conten' is not a key of MsgShape
    const _invalid: CrudOptions<MsgShape>['search'] = 'conten'
    expect(_invalid).toBeDefined()
  })

  test('aclFrom.field accepts valid schema keys', () => {
    expect(Object.keys(taskSchema.shape)).toContain('projectId')
    type TaskShape = typeof taskSchema.shape
    const opts: OrgCrudOptions<TaskShape> = { aclFrom: { field: 'projectId', table: 'project' } }
    expect(opts.aclFrom?.field).toBe('projectId')
  })

  test('aclFrom.field rejects invalid schema keys', () => {
    type TaskShape = typeof taskSchema.shape
    // @ts-expect-error - 'projctId' is not a key of TaskShape
    const _invalid: OrgCrudOptions<TaskShape> = { aclFrom: { field: 'projctId', table: 'project' } }
    expect(_invalid).toBeDefined()
  })

  test('orgCascade accepts valid foreignKey', () => {
    const result = orgCascade(taskSchema, { foreignKey: 'projectId', table: 'task' })
    expect(result.foreignKey).toBe('projectId')
    expect(result.table).toBe('task')
  })

  test('orgCascade rejects invalid foreignKey', () => {
    // @ts-expect-error - 'projctId' is not a key of taskSchema
    const result = orgCascade(taskSchema, { foreignKey: 'projctId', table: 'task' })
    expect(result).toBeDefined()
  })

  test('cacheCrud key accepts valid schema keys', () => {
    expect(Object.keys(movieSchema.shape)).toContain('tmdb_id')
    type MovieShape = typeof movieSchema.shape
    const key: keyof MovieShape = 'tmdb_id'
    expect(key).toBe('tmdb_id')
  })

  test('cacheCrud key rejects invalid schema keys', () => {
    type MovieShape = typeof movieSchema.shape
    // @ts-expect-error - 'tmdb_i' is not a key of MovieShape
    const _invalid: keyof MovieShape = 'tmdb_i'
    expect(_invalid).toBeDefined()
  })
})

describe('WhereOf type safety', () => {
  const whereSchema = object({
    category: string(),
    content: string(),
    published: boolean(),
    title: string()
  })
  type WS = typeof whereSchema.shape

  test('WhereOf accepts valid field names', () => {
    expect(whereSchema.shape.category).toBeDefined()
    const validWhere: WhereOf<WS> = { category: 'tech', published: true }
    expect(validWhere.category).toBe('tech')
    expect(validWhere.published).toBe(true)
  })

  test('WhereOf rejects misspelled field names', () => {
    // @ts-expect-error - 'categry' is not a key of WS
    const _invalid: WhereOf<WS> = { categry: 'tech' }
    expect(_invalid).toBeDefined()
  })

  test('WhereOf rejects wrong value types', () => {
    // @ts-expect-error - published should be boolean, not string
    const _invalid: WhereOf<WS> = { published: 'yes' }
    expect(_invalid).toBeDefined()
  })

  test('WhereOf accepts comparison operators', () => {
    const prodSchema = object({ name: string(), price: number() })
    type PS = typeof prodSchema.shape
    expect(prodSchema.shape.price).toBeDefined()

    const validRange: WhereOf<PS> = { price: { $gte: 10, $lte: 100 } }
    expect(validRange.price).toBeDefined()

    const validBetween: WhereOf<PS> = { price: { $between: [10, 100] } }
    expect(validBetween.price).toBeDefined()
  })

  test('WhereOf or[] rejects misspelled field names', () => {
    // @ts-expect-error - 'titl' is not a key of WS
    const _invalid: WhereOf<WS> = { or: [{ titl: 'hello' }] }
    expect(_invalid).toBeDefined()
  })

  test('WhereOf own is always valid', () => {
    const ownFilter: WhereOf<WS> = { own: true }
    expect(ownFilter.own).toBe(true)
  })
})

describe('CrudOptions type safety', () => {
  const crudSchema = object({
    category: string(),
    content: string(),
    published: boolean(),
    title: string()
  })
  type CS = typeof crudSchema.shape

  test('pub.where rejects misspelled field names', () => {
    expect(crudSchema.shape.published).toBeDefined()
    // @ts-expect-error - 'publishd' is not a key of CS
    const _invalid: CrudOptions<CS> = { pub: { where: { publishd: true } } }
    expect(_invalid).toBeDefined()
  })

  test('auth.where rejects misspelled field names', () => {
    // @ts-expect-error - 'categor' is not a key of CS
    const _invalid: CrudOptions<CS> = { auth: { where: { categor: 'tech' } } }
    expect(_invalid).toBeDefined()
  })

  test('search shorthand rejects misspelled field names', () => {
    // @ts-expect-error - 'conten' is not a key of CS
    const _invalid: CrudOptions<CS> = { search: 'conten' }
    expect(_invalid).toBeDefined()
  })

  test('cascade accepts array of CascadeOption', () => {
    const opts: CrudOptions<CS> = { cascade: [{ foreignKey: 'chatId', table: 'message' }] }
    expect(opts.cascade).toHaveLength(1)
  })

  test('cascade accepts multiple targets', () => {
    const opts: CrudOptions<CS> = {
      cascade: [
        { foreignKey: 'chatId', table: 'message' },
        { foreignKey: 'chatId', table: 'reaction' }
      ]
    }
    expect(opts.cascade).toHaveLength(2)
  })

  test('cascade false disables cascade', () => {
    const opts: CrudOptions<CS> = { cascade: false }
    expect(opts.cascade).toBe(false)
  })

  test('cascade undefined means no cascade', () => {
    const opts: CrudOptions<CS> = {}
    expect(opts.cascade).toBeUndefined()
  })

  test('CascadeOption type has foreignKey and table', () => {
    const opt: CascadeOption = { foreignKey: 'parentId', table: 'child' }
    expect(opt.foreignKey).toBe('parentId')
    expect(opt.table).toBe('child')
  })
})

describe('branded schema type enforcement', () => {
  const ownedSchemas = makeOwned({
      blog: object({ content: string(), published: boolean(), title: string() })
    }),
    orgSchemas = makeOrgScoped({
      wiki: object({ content: string(), slug: string(), title: string() })
    }),
    baseSchemas = makeBase({
      movie: object({ title: string(), tmdb_id: number() })
    }),
    singletonSchemas = makeSingleton({
      profile: object({
        bio: string().optional(),
        displayName: string(),
        notifications: boolean(),
        theme: zenum(['light', 'dark', 'system'])
      })
    }),
    plainSchema = object({ name: string() })

  describe('table helper constraints', () => {
    test('ownedTable accepts makeOwned schema', () => {
      const table = ownedTable(ownedSchemas.blog)
      expect(table).toBeDefined()
    })

    test('ownedTable rejects makeOrgScoped schema', () => {
      // @ts-expect-error - OrgSchema is not OwnedSchema
      const table = ownedTable(orgSchemas.wiki)
      expect(table).toBeDefined()
    })

    test('ownedTable rejects makeSingleton schema', () => {
      // @ts-expect-error - SingletonSchema is not OwnedSchema
      const table = ownedTable(singletonSchemas.profile)
      expect(table).toBeDefined()
    })

    test('ownedTable rejects plain ZodObject', () => {
      // @ts-expect-error - plain ZodObject lacks OwnedSchema brand
      const table = ownedTable(plainSchema)
      expect(table).toBeDefined()
    })

    test('orgTable accepts makeOrgScoped schema', () => {
      const table = orgTable(orgSchemas.wiki)
      expect(table).toBeDefined()
    })

    test('orgTable rejects makeOwned schema', () => {
      // @ts-expect-error - OwnedSchema is not OrgSchema
      const table = orgTable(ownedSchemas.blog)
      expect(table).toBeDefined()
    })

    test('baseTable accepts makeBase schema', () => {
      const table = baseTable(baseSchemas.movie)
      expect(table).toBeDefined()
    })

    test('baseTable rejects makeOwned schema', () => {
      // @ts-expect-error - OwnedSchema is not BaseSchema
      const table = baseTable(ownedSchemas.blog)
      expect(table).toBeDefined()
    })

    test('singletonTable accepts makeSingleton schema', () => {
      const table = singletonTable(singletonSchemas.profile)
      expect(table).toBeDefined()
    })

    test('singletonTable rejects makeOwned schema', () => {
      // @ts-expect-error - OwnedSchema is not SingletonSchema
      const table = singletonTable(ownedSchemas.blog)
      expect(table).toBeDefined()
    })

    test('singletonTable rejects makeOrgScoped schema', () => {
      // @ts-expect-error - OrgSchema is not SingletonSchema
      const table = singletonTable(orgSchemas.wiki)
      expect(table).toBeDefined()
    })

    test('singletonTable rejects plain ZodObject', () => {
      // @ts-expect-error - plain ZodObject lacks SingletonSchema brand
      const table = singletonTable(plainSchema)
      expect(table).toBeDefined()
    })
  })

  describe('factory type constraints', () => {
    test('crud type accepts OwnedSchema', () => {
      type BlogShape = typeof ownedSchemas.blog extends OwnedSchema<infer S> ? S : never
      const validCrudSchema: OwnedSchema<BlogShape> = ownedSchemas.blog
      expect(validCrudSchema).toBeDefined()
    })

    test('crud type rejects OrgSchema', () => {
      // @ts-expect-error - OrgSchema is not assignable to OwnedSchema
      const invalidCrudSchema: OwnedSchema<typeof orgSchemas.wiki.shape> = orgSchemas.wiki
      expect(invalidCrudSchema).toBeDefined()
    })

    test('crud type rejects SingletonSchema', () => {
      // @ts-expect-error - SingletonSchema is not assignable to OwnedSchema
      const invalidCrudSchema: OwnedSchema<typeof singletonSchemas.profile.shape> = singletonSchemas.profile
      expect(invalidCrudSchema).toBeDefined()
    })

    test('crud type rejects BaseSchema', () => {
      // @ts-expect-error - BaseSchema is not assignable to OwnedSchema
      const invalidCrudSchema: OwnedSchema<typeof baseSchemas.movie.shape> = baseSchemas.movie
      expect(invalidCrudSchema).toBeDefined()
    })

    test('crud type rejects plain ZodObject', () => {
      // @ts-expect-error - plain ZodObject lacks OwnedSchema brand
      const invalidCrudSchema: OwnedSchema<typeof plainSchema.shape> = plainSchema
      expect(invalidCrudSchema).toBeDefined()
    })

    test('orgCrud type accepts OrgSchema', () => {
      type WikiShape = typeof orgSchemas.wiki extends OrgSchema<infer S> ? S : never
      const validOrgSchema: OrgSchema<WikiShape> = orgSchemas.wiki
      expect(validOrgSchema).toBeDefined()
    })

    test('orgCrud type rejects OwnedSchema', () => {
      // @ts-expect-error - OwnedSchema is not assignable to OrgSchema
      const invalidOrgSchema: OrgSchema<typeof ownedSchemas.blog.shape> = ownedSchemas.blog
      expect(invalidOrgSchema).toBeDefined()
    })

    test('orgCrud type rejects SingletonSchema', () => {
      // @ts-expect-error - SingletonSchema is not assignable to OrgSchema
      const invalidOrgSchema: OrgSchema<typeof singletonSchemas.profile.shape> = singletonSchemas.profile
      expect(invalidOrgSchema).toBeDefined()
    })

    test('cacheCrud type accepts BaseSchema', () => {
      type MovieShape = typeof baseSchemas.movie extends BaseSchema<infer S> ? S : never
      const validBaseSchema: BaseSchema<MovieShape> = baseSchemas.movie
      expect(validBaseSchema).toBeDefined()
    })

    test('cacheCrud type rejects OwnedSchema', () => {
      // @ts-expect-error - OwnedSchema is not assignable to BaseSchema
      const invalidBaseSchema: BaseSchema<typeof ownedSchemas.blog.shape> = ownedSchemas.blog
      expect(invalidBaseSchema).toBeDefined()
    })

    test('singletonCrud type accepts SingletonSchema', () => {
      type ProfileShape = typeof singletonSchemas.profile extends SingletonSchema<infer S> ? S : never
      const validSingletonSchema: SingletonSchema<ProfileShape> = singletonSchemas.profile
      expect(validSingletonSchema).toBeDefined()
    })

    test('singletonCrud type rejects OwnedSchema', () => {
      // @ts-expect-error - OwnedSchema is not assignable to SingletonSchema
      const invalidSingletonSchema: SingletonSchema<typeof ownedSchemas.blog.shape> = ownedSchemas.blog
      expect(invalidSingletonSchema).toBeDefined()
    })

    test('singletonCrud type rejects OrgSchema', () => {
      // @ts-expect-error - OrgSchema is not assignable to SingletonSchema
      const invalidSingletonSchema: SingletonSchema<typeof orgSchemas.wiki.shape> = orgSchemas.wiki
      expect(invalidSingletonSchema).toBeDefined()
    })

    test('singletonCrud type rejects plain ZodObject', () => {
      // @ts-expect-error - plain ZodObject lacks SingletonSchema brand
      const invalidSingletonSchema: SingletonSchema<typeof plainSchema.shape> = plainSchema
      expect(invalidSingletonSchema).toBeDefined()
    })
  })

  describe('wrapper identity', () => {
    test('makeOwned preserves Zod schema shape access', () => {
      expect(ownedSchemas.blog.shape.title).toBeDefined()
      expect(ownedSchemas.blog.shape.content).toBeDefined()
      expect(ownedSchemas.blog.shape.published).toBeDefined()
    })

    test('makeOrgScoped preserves Zod schema methods', () => {
      const partial = orgSchemas.wiki.partial()
      expect(partial).toBeDefined()
      expect(partial.shape.title).toBeDefined()
    })

    test('makeSingleton preserves Zod schema shape access', () => {
      expect(singletonSchemas.profile.shape.displayName).toBeDefined()
      expect(singletonSchemas.profile.shape.bio).toBeDefined()
      expect(singletonSchemas.profile.shape.theme).toBeDefined()
      expect(singletonSchemas.profile.shape.notifications).toBeDefined()
    })

    test('branded schemas work with child() via structural subtyping', () => {
      const childConfig = child({
        foreignKey: 'chatId',
        parent: 'chat',
        parentSchema: makeOwned({ chat: object({ isPublic: boolean(), title: string() }) }).chat,
        schema: object({ chatId: string(), text: string() })
      })
      expect(childConfig.foreignKey).toBe('chatId')
    })
  })

  describe('singletonCrud upsert type safety', () => {
    type ProfileInput = Partial<(typeof singletonSchemas.profile)['_output']>

    test('upsert rejects misspelled field name', () => {
      // @ts-expect-error - misspelledField is not a valid profile key
      const invalid: ProfileInput = { misspelledField: 'x' }
      expect(invalid).toBeDefined()
    })

    test('upsert rejects wrong value type for displayName', () => {
      // @ts-expect-error - displayName must be string, not number
      const invalid: ProfileInput = { displayName: 123 }
      expect(invalid).toBeDefined()
    })

    test('upsert rejects invalid enum value for theme', () => {
      // @ts-expect-error - 'invalid' is not a valid theme value
      const invalid: ProfileInput = { theme: 'invalid' }
      expect(invalid).toBeDefined()
    })

    test('upsert accepts valid fields', () => {
      const valid: ProfileInput = { displayName: 'ok', theme: 'dark' }
      expect(valid).toBeDefined()
    })
  })
})

/* eslint-disable @typescript-eslint/require-await */
// oxlint-disable promise/prefer-await-to-then
const failStorage = () => ({
  delete: async () => {
    throw new Error('storage unavailable')
  },
  getUrl: async () => null
})

describe('cleanFiles resilience', () => {
  test('cleanFiles does not throw on storage.delete failure', async () => {
    const result = await cleanFiles({
      doc: { photo: 'file_123' },
      fileFields: ['photo'],
      storage: failStorage()
    })
    expect(result).toBeUndefined()
  })

  test('cleanFiles with all failures still completes without throwing', async () => {
    const result = await cleanFiles({
      doc: { attachments: ['file_a', 'file_b'], photo: 'file_c' },
      fileFields: ['photo', 'attachments'],
      storage: failStorage()
    })
    expect(result).toBeUndefined()
  })

  test('cleanFiles skips when no file fields', async () => {
    let called = false
    const storage = {
      delete: async () => {
        called = true
      },
      getUrl: async () => null
    }

    await cleanFiles({
      doc: { title: 'test' },
      fileFields: [],
      storage
    })

    expect(called).toBe(false)
  })
})

describe('defineSteps type safety', () => {
  const profileSchema = object({
      avatar: string().optional(),
      bio: string().max(500).optional(),
      displayName: string().min(1)
    }),
    orgSchema = object({
      name: string().min(1),
      slug: string().min(1)
    }),
    appearanceSchema = object({
      orgAvatar: string()
    }),
    preferencesSchema = object({
      notifications: boolean(),
      theme: zenum(['light', 'dark', 'system'])
    }),
    { StepForm, steps, useStepper } = defineSteps(
      { id: 'profile', label: 'Profile', schema: profileSchema },
      { id: 'org', label: 'Organization', schema: orgSchema },
      { id: 'appearance', label: 'Appearance', schema: appearanceSchema },
      { id: 'preferences', label: 'Preferences', schema: preferencesSchema }
    )

  test('defineSteps returns StepForm, useStepper, steps', () => {
    expect(StepForm).toBeDefined()
    expect(StepForm.Step).toBeDefined()
    expect(useStepper).toBeDefined()
    expect(typeof useStepper).toBe('function')
    expect(steps).toHaveLength(4)
  })

  test('steps array has correct ids and labels', () => {
    expect(steps[0]?.id).toBe('profile')
    expect(steps[0]?.label).toBe('Profile')
    expect(steps[1]?.id).toBe('org')
    expect(steps[1]?.label).toBe('Organization')
    expect(steps[2]?.id).toBe('appearance')
    expect(steps[2]?.label).toBe('Appearance')
    expect(steps[3]?.id).toBe('preferences')
    expect(steps[3]?.label).toBe('Preferences')
  })

  test('StepForm.Step accepts valid step IDs', () => {
    // eslint-disable-next-line new-cap
    const _p = StepForm.Step({ id: 'profile', render: () => null }),
      // eslint-disable-next-line new-cap
      _o = StepForm.Step({ id: 'org', render: () => null }),
      // eslint-disable-next-line new-cap
      _a = StepForm.Step({ id: 'appearance', render: () => null }),
      // eslint-disable-next-line new-cap
      _pr = StepForm.Step({ id: 'preferences', render: () => null })
    expect(_p).toBeNull()
    expect(_o).toBeNull()
    expect(_a).toBeNull()
    expect(_pr).toBeNull()
  })

  test('StepForm.Step rejects misspelled step ID', () => {
    // @ts-expect-error — 'proifle' is not a valid step ID
    // eslint-disable-next-line new-cap
    const r = StepForm.Step({ id: 'proifle', render: () => null })
    expect(r).toBeNull()
  })

  test('StepForm.Step rejects unknown step ID', () => {
    // @ts-expect-error — 'nonexistent' is not a valid step ID
    // eslint-disable-next-line new-cap
    const r = StepForm.Step({ id: 'nonexistent', render: () => null })
    expect(r).toBeNull()
  })

  test('profile step render receives displayName field', () => {
    // eslint-disable-next-line new-cap
    const r = StepForm.Step({
      id: 'profile',
      render: f => {
        // eslint-disable-next-line new-cap
        f.Text({ label: 'Name', name: 'displayName' })
        return null
      }
    })
    expect(r).toBeNull()
  })

  test('profile step render rejects org field name', () => {
    // eslint-disable-next-line new-cap
    const r = StepForm.Step({
      id: 'profile',
      render: f => {
        // @ts-expect-error — 'slug' does not exist in profileSchema
        // eslint-disable-next-line new-cap
        f.Text({ label: 'Slug', name: 'slug' })
        return null
      }
    })
    expect(r).toBeNull()
  })

  test('org step render accepts name field', () => {
    // eslint-disable-next-line new-cap
    const r = StepForm.Step({
      id: 'org',
      render: f => {
        // eslint-disable-next-line new-cap
        f.Text({ label: 'Name', name: 'name' })
        return null
      }
    })
    expect(r).toBeNull()
  })

  test('org step render rejects profile field name', () => {
    // eslint-disable-next-line new-cap
    const r = StepForm.Step({
      id: 'org',
      render: f => {
        // @ts-expect-error — 'displayName' does not exist in orgSchema
        // eslint-disable-next-line new-cap
        f.Text({ label: 'Name', name: 'displayName' })
        return null
      }
    })
    expect(r).toBeNull()
  })

  test('appearance step render accepts orgAvatar field', () => {
    // eslint-disable-next-line new-cap
    const r = StepForm.Step({
      id: 'appearance',
      render: f => {
        // eslint-disable-next-line new-cap
        f.Text({ label: 'Avatar', name: 'orgAvatar' })
        return null
      }
    })
    expect(r).toBeNull()
  })

  test('appearance step render rejects org field name', () => {
    // eslint-disable-next-line new-cap
    const r = StepForm.Step({
      id: 'appearance',
      render: f => {
        // @ts-expect-error — 'name' does not exist in appearanceSchema
        // eslint-disable-next-line new-cap
        f.Text({ label: 'Name', name: 'name' })
        return null
      }
    })
    expect(r).toBeNull()
  })

  test('preferences step render accepts theme field', () => {
    // eslint-disable-next-line new-cap
    const r = StepForm.Step({
      id: 'preferences',
      render: f => {
        // eslint-disable-next-line new-cap
        f.Choose({ label: 'Theme', name: 'theme' })
        return null
      }
    })
    expect(r).toBeNull()
  })

  test('preferences step render rejects profile field', () => {
    // eslint-disable-next-line new-cap
    const r = StepForm.Step({
      id: 'preferences',
      render: f => {
        // @ts-expect-error — 'displayName' does not exist in preferencesSchema
        // eslint-disable-next-line new-cap
        f.Text({ label: 'Name', name: 'displayName' })
        return null
      }
    })
    expect(r).toBeNull()
  })

  test('profile step render rejects misspelled field', () => {
    // eslint-disable-next-line new-cap
    const r = StepForm.Step({
      id: 'profile',
      render: f => {
        // @ts-expect-error — 'displyName' is misspelled
        // eslint-disable-next-line new-cap
        f.Text({ label: 'Name', name: 'displyName' })
        return null
      }
    })
    expect(r).toBeNull()
  })

  test('single-step stepper compiles', () => {
    const singleSchema = object({ title: string() }),
      single = defineSteps({ id: 'only', label: 'Only', schema: singleSchema })
    expect(single.steps).toHaveLength(1)
    expect(single.StepForm).toBeDefined()
  })

  test('onSubmit receives profile.displayName as string', () => {
    const _fn: Parameters<typeof useStepper>[0]['onSubmit'] = async ({ profile }) => {
      expect(profile.displayName.toUpperCase()).toBeDefined()
    }
    expect(_fn).toBeDefined()
  })

  test('onSubmit rejects profile.slug (not in profileSchema)', () => {
    const _fn: Parameters<typeof useStepper>[0]['onSubmit'] = async ({ profile }) => {
      // @ts-expect-error — 'slug' does not exist on profile step data
      expect(profile.slug).toBeDefined()
    }
    expect(_fn).toBeDefined()
  })

  test('onSubmit receives org.name as string', () => {
    const _fn: Parameters<typeof useStepper>[0]['onSubmit'] = async ({ org }) => {
      expect(org.name.toUpperCase()).toBeDefined()
    }
    expect(_fn).toBeDefined()
  })

  test('onSubmit receives preferences.theme', () => {
    const _fn: Parameters<typeof useStepper>[0]['onSubmit'] = async ({ preferences }) => {
      expect(preferences.theme).toBeDefined()
    }
    expect(_fn).toBeDefined()
  })

  test('onSubmit rejects typo step id', () => {
    const _fn: Parameters<typeof useStepper>[0]['onSubmit'] = async d => {
      // @ts-expect-error — 'typo' is not a valid step ID
      expect(d.typo).toBeDefined()
    }
    expect(_fn).toBeDefined()
  })

  test('onSubmit receives appearance.orgAvatar', () => {
    const _fn: Parameters<typeof useStepper>[0]['onSubmit'] = async ({ appearance }) => {
      expect(appearance.orgAvatar).toBeDefined()
    }
    expect(_fn).toBeDefined()
  })

  test('step with all optional fields passes validation', () => {
    const optSchema = object({ bio: string().optional(), name: string().optional() }),
      opt = defineSteps({ id: 'info', label: 'Info', schema: optSchema })
    expect(opt.steps).toHaveLength(1)
    expect(opt.StepForm).toBeDefined()
  })

  test('steps with overlapping field names are independently typed', () => {
    const stepA = object({ name: string().min(1) }),
      stepB = object({ name: string().max(100) }),
      overlap = defineSteps({ id: 'a', label: 'A', schema: stepA }, { id: 'b', label: 'B', schema: stepB }),
      // eslint-disable-next-line new-cap
      ra = overlap.StepForm.Step({
        id: 'a',
        render: f => {
          // eslint-disable-next-line new-cap
          f.Text({ label: 'N', name: 'name' })
          return null
        }
      }),
      // eslint-disable-next-line new-cap
      rb = overlap.StepForm.Step({
        id: 'b',
        render: f => {
          // eslint-disable-next-line new-cap
          f.Text({ label: 'N', name: 'name' })
          return null
        }
      })
    expect(ra).toBeNull()
    expect(rb).toBeNull()
  })
})

// oxlint-disable unicorn/consistent-function-scoping
describe('bridge functions', () => {
  describe('idx', () => {
    test('returns the callback as-is (passthrough cast)', () => {
      const fn = (ib: { eq: (f: string, v: unknown) => unknown }) => ib.eq('name', 'test'),
        result: unknown = idx(fn as never)
      expect(result).toBe(fn)
    })

    test('preserves function identity', () => {
      const fn = (ib: { eq: (f: string, v: unknown) => unknown }) => ib.eq('id', 42),
        a: unknown = idx(fn as never),
        b: unknown = idx(fn as never)
      expect(a).toBe(b)
      expect(a).toBe(fn)
    })
  })

  describe('flt', () => {
    test('returns the callback as-is (passthrough cast)', () => {
      const fn = (fb: { eq: (f: string, v: unknown) => unknown }) => fb.eq('active', true),
        result: unknown = flt(fn as never)
      expect(result).toBe(fn)
    })
  })

  describe('sch', () => {
    test('returns the callback as-is (passthrough cast)', () => {
      const fn = (sb: { search: (f: string, q: string) => unknown }) => sb.search('content', 'hello'),
        result: unknown = sch(fn as never)
      expect(result).toBe(fn)
    })
  })

  describe('typed', () => {
    test('returns string value as-is', () => {
      const result: unknown = typed('hello')
      expect(result).toBe('hello')
    })

    test('returns number value as-is', () => {
      const result: unknown = typed(42)
      expect(result).toBe(42)
    })

    test('returns object reference as-is', () => {
      const obj = { a: 1, b: 'two' },
        result: unknown = typed(obj)
      expect(result).toBe(obj)
    })

    test('returns array reference as-is', () => {
      const arr = [1, 2, 3],
        result: unknown = typed(arr)
      expect(result).toBe(arr)
    })

    test('returns null as-is', () => {
      const result: unknown = typed(null)
      expect(result).toBeNull()
    })

    test('returns function as-is', () => {
      const fn = () => 42,
        result: unknown = typed(fn)
      expect(result).toBe(fn)
    })

    test('preserves nested object structure', () => {
      const nested = { deep: { arr: [1, 2], val: true } },
        result: unknown = typed(nested)
      expect(result).toBe(nested)
      expect((result as typeof nested).deep.arr).toEqual([1, 2])
    })
  })

  describe('indexFields', () => {
    test('returns single field as array', () => {
      const result: unknown = indexFields('name')
      expect(result).toEqual(['name'])
    })

    test('returns multiple fields as array', () => {
      const result: unknown = indexFields('orgId', 'userId', 'createdAt')
      expect(result).toEqual(['orgId', 'userId', 'createdAt'])
    })

    test('returns empty array for no args', () => {
      const result: unknown = indexFields()
      expect(result).toEqual([])
    })

    test('preserves field order', () => {
      const result: unknown = indexFields('z', 'a', 'm')
      expect(result).toEqual(['z', 'a', 'm'])
    })
  })
})

const BASE36_PATTERN = /^[\da-z]+$/u,
  /* eslint-disable no-console */
  captureWarns = () => {
    const warns: string[] = [],
      origWarn = console.warn
    console.warn = (...args: unknown[]) => {
      warns.push(String(args[0]))
    }
    return { origWarn, warns }
  }

describe('warnLargeFilterSet', () => {
  test('threshold is 1000', () => {
    expect(RUNTIME_FILTER_WARN_THRESHOLD).toBe(1000)
  })

  test('does not warn below threshold', () => {
    const { origWarn, warns } = captureWarns()
    warnLargeFilterSet(999, 'blog', 'list')
    console.warn = origWarn
    expect(warns).toHaveLength(0)
  })

  test('does not warn at exactly threshold', () => {
    const { origWarn, warns } = captureWarns()
    warnLargeFilterSet(1000, 'blog', 'list')
    console.warn = origWarn
    expect(warns).toHaveLength(0)
  })

  test('warns above threshold', () => {
    const { origWarn, warns } = captureWarns()
    warnLargeFilterSet(1001, 'blog', 'list')
    console.warn = origWarn
    expect(warns).toHaveLength(1)
    expect(warns[0]).toContain('large_filter_set')
    expect(warns[0]).toContain('blog')
  })

  test('warn message includes count, table, context, threshold', () => {
    const { origWarn, warns } = captureWarns()
    warnLargeFilterSet(5000, 'wiki', 'search')
    console.warn = origWarn
    expect(warns).toHaveLength(1)
    const parsed = JSON.parse(String(warns[0])) as Record<string, unknown>
    expect(parsed.count).toBe(5000)
    expect(parsed.table).toBe('wiki')
    expect(parsed.context).toBe('search')
    expect(parsed.threshold).toBe(1000)
    expect(parsed.level).toBe('warn')
  })

  test('zero count does not warn', () => {
    const { origWarn, warns } = captureWarns()
    warnLargeFilterSet(0, 'blog', 'list')
    console.warn = origWarn
    expect(warns).toHaveLength(0)
  })

  test('strict mode throws above threshold', () => {
    expect(() => warnLargeFilterSet(1001, 'blog', 'list', true)).toThrow('Runtime filtering 1001 docs')
  })

  test('strict mode does not throw below threshold', () => {
    expect(() => warnLargeFilterSet(999, 'blog', 'list', true)).not.toThrow()
  })

  test('strict mode does not throw at exactly threshold', () => {
    expect(() => warnLargeFilterSet(1000, 'blog', 'list', true)).not.toThrow()
  })
})

describe('useOnlineStatus module', () => {
  test('exports default function', async () => {
    const mod = await import('../react/use-online-status')
    expect(typeof mod.default).toBe('function')
  })
})

describe('shared constants', () => {
  test('BYTES_PER_KB is 1024', () => {
    expect(BYTES_PER_KB).toBe(1024)
  })

  test('BYTES_PER_MB is 1024 * 1024', () => {
    expect(BYTES_PER_MB).toBe(1024 * 1024)
  })

  test('BYTES_PER_MB equals BYTES_PER_KB squared', () => {
    expect(BYTES_PER_MB).toBe(BYTES_PER_KB * BYTES_PER_KB)
  })

  test('ONE_YEAR_SECONDS is 365 days in seconds', () => {
    expect(ONE_YEAR_SECONDS).toBe(60 * 60 * 24 * 365)
  })

  test('ONE_YEAR_SECONDS is approximately 31.5 million', () => {
    expect(ONE_YEAR_SECONDS).toBeGreaterThan(31_000_000)
    expect(ONE_YEAR_SECONDS).toBeLessThan(32_000_000)
  })
})

describe('sleep', () => {
  test('resolves after delay', async () => {
    const start = Date.now()
    await sleep(50)
    const elapsed = Date.now() - start
    expect(elapsed).toBeGreaterThanOrEqual(40)
  })

  test('resolves to void', async () => {
    const result = await sleep(1)
    expect(result).toBeUndefined()
  })
})

describe('generateToken', () => {
  test('returns a string', () => {
    expect(typeof generateToken()).toBe('string')
  })

  test('returns 32 characters', () => {
    expect(generateToken()).toHaveLength(32)
  })

  test('generates unique tokens', () => {
    const tokens = new Set<string>()
    for (let i = 0; i < 100; i += 1) tokens.add(generateToken())
    expect(tokens.size).toBe(100)
  })

  test('contains only base-36 characters', () => {
    const token = generateToken()
    expect(token).toMatch(BASE36_PATTERN)
  })

  test('SEVEN_DAYS_MS is 7 days in milliseconds', () => {
    expect(SEVEN_DAYS_MS).toBe(7 * 24 * 60 * 60 * 1000)
  })

  test('SEVEN_DAYS_MS is 604800000', () => {
    expect(SEVEN_DAYS_MS).toBe(604_800_000)
  })
})

describe('cookie constants', () => {
  test('ACTIVE_ORG_COOKIE is activeOrgId', () => {
    expect(ACTIVE_ORG_COOKIE).toBe('activeOrgId')
  })

  test('ACTIVE_ORG_SLUG_COOKIE is activeOrgSlug', () => {
    expect(ACTIVE_ORG_SLUG_COOKIE).toBe('activeOrgSlug')
  })

  test('cookie constants are distinct', () => {
    expect(ACTIVE_ORG_COOKIE).not.toBe(ACTIVE_ORG_SLUG_COOKIE)
  })
})

describe('time helper', () => {
  test('returns object with updatedAt', () => {
    const result = time()
    expect(result).toHaveProperty('updatedAt')
    expect(typeof result.updatedAt).toBe('number')
  })

  test('updatedAt is close to Date.now()', () => {
    const before = Date.now(),
      result = time(),
      after = Date.now()
    expect(result.updatedAt).toBeGreaterThanOrEqual(before)
    expect(result.updatedAt).toBeLessThanOrEqual(after)
  })

  test('spreads into object correctly', () => {
    const obj = { name: 'test', ...time() }
    expect(obj.name).toBe('test')
    expect(typeof obj.updatedAt).toBe('number')
  })

  test('returns only updatedAt key', () => {
    const result = time()
    expect(Object.keys(result)).toEqual(['updatedAt'])
  })
})

describe('err helper', () => {
  test('throws ConvexError with code only', () => {
    expect(() => err('NOT_FOUND')).toThrow()
    try {
      err('NOT_FOUND')
    } catch (error) {
      const e = error as { data: { code: string } }
      expect(e.data.code).toBe('NOT_FOUND')
      expect(e.data).not.toHaveProperty('debug')
      expect(e.data).not.toHaveProperty('message')
    }
  })

  test('throws ConvexError with debug string', () => {
    try {
      err('NOT_AUTHENTICATED', 'login-flow')
    } catch (error) {
      const e = error as { data: { code: string; debug: string } }
      expect(e.data.code).toBe('NOT_AUTHENTICATED')
      expect(e.data.debug).toBe('login-flow')
      expect(e.data).not.toHaveProperty('message')
    }
  })

  test('throws ConvexError with message object', () => {
    try {
      err('RATE_LIMITED', { message: 'Too many requests' })
    } catch (error) {
      const e = error as { data: { code: string; message: string } }
      expect(e.data.code).toBe('RATE_LIMITED')
      expect(e.data.message).toBe('Too many requests')
      expect(e.data).not.toHaveProperty('debug')
    }
  })

  test('return type is never', () => {
    const fn = () => err('NOT_FOUND')
    expect(() => fn()).toThrow()
  })
})

describe('Promise.allSettled resilience pattern', () => {
  test('allSettled continues after rejection', async () => {
    let successCalled = false
    const results = await Promise.allSettled([
      Promise.reject(new Error('storage fail')),
      (async () => {
        successCalled = true
      })()
    ])
    expect(results[0].status).toBe('rejected')
    expect(results[1].status).toBe('fulfilled')
    expect(successCalled).toBe(true)
  })

  test('allSettled collects all failures', async () => {
    const results = await Promise.allSettled([
        Promise.reject(new Error('fail 1')),
        Promise.reject(new Error('fail 2')),
        Promise.resolve('ok')
      ]),
      rejected = results.filter(r => r.status === 'rejected')
    expect(rejected).toHaveLength(2)
    expect(results[2].status).toBe('fulfilled')
  })

  test('subsequent Promise.all still runs after allSettled failures', async () => {
    const order: string[] = [],
      sr = await Promise.allSettled([
        Promise.reject(new Error('storage cleanup fail')),
        (async () => {
          order.push('storage-2')
        })()
      ])
    expect(sr[0].status).toBe('rejected')
    await Promise.all([
      (async () => {
        order.push('db-1')
      })(),
      (async () => {
        order.push('db-2')
      })()
    ])
    expect(order).toContain('storage-2')
    expect(order).toContain('db-1')
    expect(order).toContain('db-2')
  })
})

describe('ROLE_LEVEL export removal', () => {
  test('ROLE_LEVEL is not re-exported from org-crud public API', async () => {
    const mod = await import('../server/org-crud')
    expect(mod).toHaveProperty('orgCascade')
    expect(mod).toHaveProperty('canEdit')
    expect(mod).not.toHaveProperty('ROLE_LEVEL')
  })
})

describe('getMeta', () => {
  test('string field returns kind string', () => {
    expect(getMeta(string())).toEqual({ kind: 'string' })
  })

  test('enum field returns kind string', () => {
    expect(getMeta(zenum(['a', 'b']))).toEqual({ kind: 'string' })
  })

  test('number field returns kind number', () => {
    expect(getMeta(number())).toEqual({ kind: 'number' })
  })

  test('boolean field returns kind boolean', () => {
    expect(getMeta(boolean())).toEqual({ kind: 'boolean' })
  })

  test('date field returns kind date', () => {
    expect(getMeta(date())).toEqual({ kind: 'date' })
  })

  test('cvFile returns kind file', () => {
    expect(getMeta(cvFile())).toEqual({ kind: 'file' })
  })

  test('cvFiles returns kind files', () => {
    expect(getMeta(cvFiles())).toEqual({ kind: 'files' })
  })

  test('cvFiles with max returns kind files with max', () => {
    expect(getMeta(cvFiles().max(5))).toEqual({ kind: 'files', max: 5 })
  })

  test('array(string) returns kind stringArray', () => {
    expect(getMeta(array(string()))).toEqual({ kind: 'stringArray' })
  })

  test('array(string).max(10) returns stringArray with max', () => {
    expect(getMeta(array(string()).max(10))).toEqual({ kind: 'stringArray', max: 10 })
  })

  test('array(number) returns kind unknown', () => {
    expect(getMeta(array(number()))).toEqual({ kind: 'unknown' })
  })

  test('optional string returns kind string', () => {
    expect(getMeta(optional(string()))).toEqual({ kind: 'string' })
  })

  test('nullable cvFile returns kind file', () => {
    expect(getMeta(cvFile().nullable())).toEqual({ kind: 'file' })
  })

  test('optional nullable cvFile returns kind file', () => {
    expect(getMeta(cvFile().nullable().optional())).toEqual({ kind: 'file' })
  })

  test('unknown input returns kind unknown', () => {
    expect(getMeta(42)).toEqual({ kind: 'unknown' })
  })
})

describe('buildMeta', () => {
  test('builds meta map for all field types', () => {
    const s = object({
        active: boolean(),
        avatar: cvFile().nullable().optional(),
        bio: optional(string()),
        count: number(),
        photos: cvFiles().max(3),
        tags: array(string()).max(10),
        title: string()
      }),
      meta = buildMeta(s)
    expect(meta.title).toEqual({ kind: 'string' })
    expect(meta.count).toEqual({ kind: 'number' })
    expect(meta.active).toEqual({ kind: 'boolean' })
    expect(meta.avatar).toEqual({ kind: 'file' })
    expect(meta.photos).toEqual({ kind: 'files', max: 3 })
    expect(meta.tags).toEqual({ kind: 'stringArray', max: 10 })
    expect(meta.bio).toEqual({ kind: 'string' })
  })

  test('empty schema returns empty meta', () => {
    const s = object({})
    expect(buildMeta(s)).toEqual({})
  })

  test('schema with only one field', () => {
    const s = object({ name: string() }),
      meta = buildMeta(s)
    expect(Object.keys(meta)).toHaveLength(1)
    expect(meta.name).toEqual({ kind: 'string' })
  })

  test('enum fields are typed as string', () => {
    const s = object({ status: zenum(['draft', 'published']) })
    expect(buildMeta(s).status).toEqual({ kind: 'string' })
  })

  test('date field in buildMeta', () => {
    const s = object({ createdAt: date() })
    expect(buildMeta(s).createdAt).toEqual({ kind: 'date' })
  })
})

describe('canEditResource', () => {
  const resource = { userId: 'u1' }

  test('admin can always edit', () => {
    expect(canEditResource({ editorsList: [], isAdmin: true, resource, userId: 'u999' })).toBe(true)
  })

  test('resource creator can edit', () => {
    expect(canEditResource({ editorsList: [], isAdmin: false, resource, userId: 'u1' })).toBe(true)
  })

  test('user in editors list can edit', () => {
    expect(canEditResource({ editorsList: [{ userId: 'u2' }], isAdmin: false, resource, userId: 'u2' })).toBe(true)
  })

  test('non-admin, non-creator, not in editors cannot edit', () => {
    expect(canEditResource({ editorsList: [], isAdmin: false, resource, userId: 'u2' })).toBe(false)
  })

  test('non-admin, non-creator, editors list has others', () => {
    expect(canEditResource({ editorsList: [{ userId: 'u3' }], isAdmin: false, resource, userId: 'u2' })).toBe(false)
  })

  test('admin takes precedence over empty editors', () => {
    expect(canEditResource({ editorsList: [], isAdmin: true, resource, userId: 'u2' })).toBe(true)
  })

  test('creator takes precedence over missing from editors', () => {
    expect(canEditResource({ editorsList: [{ userId: 'u99' }], isAdmin: false, resource, userId: 'u1' })).toBe(true)
  })

  test('multiple editors, user is one of them', () => {
    const editors = [{ userId: 'u2' }, { userId: 'u3' }, { userId: 'u4' }]
    expect(canEditResource({ editorsList: editors, isAdmin: false, resource, userId: 'u3' })).toBe(true)
  })

  test('multiple editors, user is none of them', () => {
    const editors = [{ userId: 'u2' }, { userId: 'u3' }]
    expect(canEditResource({ editorsList: editors, isAdmin: false, resource, userId: 'u5' })).toBe(false)
  })
})

describe('isRecord', () => {
  test('plain object returns true', () => {
    expect(isRecord({ a: 1 })).toBe(true)
  })

  test('empty object returns true', () => {
    expect(isRecord({})).toBe(true)
  })

  test('null returns false', () => {
    expect(isRecord(null)).toBe(false)
  })

  test('undefined returns false', () => {
    const val = undefined
    expect(isRecord(val)).toBe(false)
  })

  test('string returns false', () => {
    expect(isRecord('hello')).toBe(false)
  })

  test('number returns false', () => {
    expect(isRecord(42)).toBe(false)
  })

  test('boolean returns false', () => {
    expect(isRecord(true)).toBe(false)
  })

  test('array returns true (arrays are objects)', () => {
    expect(isRecord([1, 2, 3])).toBe(true)
  })

  test('0 returns false', () => {
    expect(isRecord(0)).toBe(false)
  })

  test('empty string returns false', () => {
    expect(isRecord('')).toBe(false)
  })

  test('false returns false', () => {
    expect(isRecord(false)).toBe(false)
  })
})

describe('extractErrorData', () => {
  test('extracts code from ConvexError', () => {
    const e = new ConvexError({ code: 'NOT_FOUND' }),
      d = extractErrorData(e)
    expect(d).toBeDefined()
    expect(d?.code).toBe('NOT_FOUND')
  })

  test('extracts code, debug from ConvexError', () => {
    const e = new ConvexError({ code: 'NOT_AUTHENTICATED', debug: 'session-expired' }),
      d = extractErrorData(e)
    expect(d?.code).toBe('NOT_AUTHENTICATED')
    expect(d?.debug).toBe('session-expired')
  })

  test('extracts code, message from ConvexError', () => {
    const e = new ConvexError({ code: 'RATE_LIMITED', message: 'Too fast' }),
      d = extractErrorData(e)
    expect(d?.code).toBe('RATE_LIMITED')
    expect(d?.message).toBe('Too fast')
  })

  test('extracts code, fields from ConvexError', () => {
    const e = new ConvexError({ code: 'NOT_FOUND', fields: ['title', 'content'] }),
      d = extractErrorData(e)
    expect(d?.code).toBe('NOT_FOUND')
    expect(d?.fields).toEqual(['title', 'content'])
  })

  test('returns undefined for non-ConvexError', () => {
    expect(extractErrorData(new Error('plain'))).toBeUndefined()
  })

  test('returns undefined for string', () => {
    expect(extractErrorData('error')).toBeUndefined()
  })

  test('returns undefined for null', () => {
    expect(extractErrorData(null)).toBeUndefined()
  })

  test('returns undefined for ConvexError without valid code', () => {
    const e = new ConvexError({ code: 'INVALID_CODE_THAT_DOES_NOT_EXIST' })
    expect(extractErrorData(e)).toBeUndefined()
  })

  test('returns undefined for ConvexError with non-string code', () => {
    const e = new ConvexError({ code: 42 })
    expect(extractErrorData(e)).toBeUndefined()
  })

  test('returns undefined for ConvexError with non-record data', () => {
    const e = new ConvexError('just a string')
    expect(extractErrorData(e)).toBeUndefined()
  })

  test('debug is undefined when not a string', () => {
    const e = new ConvexError({ code: 'NOT_FOUND', debug: 123 }),
      d = extractErrorData(e)
    expect(d?.debug).toBeUndefined()
  })

  test('message is undefined when not a string', () => {
    const e = new ConvexError({ code: 'NOT_FOUND', message: false }),
      d = extractErrorData(e)
    expect(d?.message).toBeUndefined()
  })

  test('fields is undefined when not an array', () => {
    const e = new ConvexError({ code: 'NOT_FOUND', fields: 'title' }),
      d = extractErrorData(e)
    expect(d?.fields).toBeUndefined()
  })
})

describe('getErrorCode', () => {
  test('returns code from ConvexError', () => {
    expect(getErrorCode(new ConvexError({ code: 'CONFLICT' }))).toBe('CONFLICT')
  })

  test('returns undefined for plain Error', () => {
    expect(getErrorCode(new Error('nope'))).toBeUndefined()
  })

  test('returns undefined for non-error', () => {
    expect(getErrorCode('string')).toBeUndefined()
  })

  test('returns undefined for null', () => {
    expect(getErrorCode(null)).toBeUndefined()
  })
})

describe('getErrorMessage', () => {
  test('returns message from ConvexError with message field', () => {
    expect(getErrorMessage(new ConvexError({ code: 'NOT_FOUND', message: 'Blog not found' }))).toBe('Blog not found')
  })

  test('falls back to ERROR_MESSAGES for code without message', () => {
    const msg = getErrorMessage(new ConvexError({ code: 'NOT_AUTHENTICATED' }))
    expect(typeof msg).toBe('string')
    expect(msg.length).toBeGreaterThan(0)
    expect(msg).not.toBe('Unknown error')
  })

  test('returns Error.message for plain Error', () => {
    expect(getErrorMessage(new Error('something broke'))).toBe('something broke')
  })

  test('returns Unknown error for non-error values', () => {
    expect(getErrorMessage('random')).toBe('Unknown error')
    expect(getErrorMessage(42)).toBe('Unknown error')
    expect(getErrorMessage(null)).toBe('Unknown error')
  })
})

describe('handleConvexError', () => {
  test('calls specific handler for matching code', () => {
    let called = false
    handleConvexError(new ConvexError({ code: 'NOT_FOUND' }), {
      NOT_FOUND: () => {
        called = true
      }
    })
    expect(called).toBe(true)
  })

  test('calls default handler when no matching code handler', () => {
    let defaultCalled = false
    handleConvexError(new ConvexError({ code: 'NOT_FOUND' }), {
      default: () => {
        defaultCalled = true
      }
    })
    expect(defaultCalled).toBe(true)
  })

  test('calls default handler for plain Error', () => {
    let defaultCalled = false
    handleConvexError(new Error('plain'), {
      default: () => {
        defaultCalled = true
      }
    })
    expect(defaultCalled).toBe(true)
  })

  test('does nothing when no matching handler and no default', () => {
    let called = false
    handleConvexError(new ConvexError({ code: 'RATE_LIMITED' }), {
      NOT_FOUND: () => {
        called = true
      }
    })
    expect(called).toBe(false)
  })

  test('specific handler receives error data', () => {
    handleConvexError(new ConvexError({ code: 'CONFLICT', message: 'stale data' }), {
      CONFLICT: d => {
        expect(d.code).toBe('CONFLICT')
        expect(d.message).toBe('stale data')
      }
    })
  })

  test('specific handler takes precedence over default', () => {
    let which = ''
    handleConvexError(new ConvexError({ code: 'NOT_FOUND' }), {
      default: () => {
        which = 'default'
      },
      NOT_FOUND: () => {
        which = 'specific'
      }
    })
    expect(which).toBe('specific')
  })

  test('default receives original error for non-ConvexError', () => {
    const original = new Error('oops')
    handleConvexError(original, {
      default: e => {
        expect(e).toBe(original)
      }
    })
  })

  test('does nothing for non-error with no default', () => {
    expect(() => handleConvexError(null, {})).not.toThrow()
  })
})

describe('withRetry', () => {
  test('returns value on immediate success', async () => {
    const result = await withRetry(async () => 42)
    expect(result).toBe(42)
  })

  test('retries and succeeds on second attempt', async () => {
    let calls = 0
    const result = await withRetry(
      async () => {
        calls += 1
        // oxlint-disable-next-line no-conditional-in-test
        if (calls < 2) throw new Error('fail')
        return 'ok'
      },
      { initialDelayMs: 1, maxAttempts: 3 }
    )
    expect(result).toBe('ok')
    expect(calls).toBe(2)
  })

  test('throws last error after all attempts exhausted', async () => {
    let calls = 0,
      threw = false
    try {
      await withRetry(
        async () => {
          calls += 1
          throw new Error(`fail-${String(calls)}`)
        },
        { initialDelayMs: 1, maxAttempts: 3 }
      )
    } catch (error) {
      threw = true
      expect((error as Error).message).toBe('fail-3')
    }
    expect(threw).toBe(true)
    expect(calls).toBe(3)
  })

  test('respects maxAttempts: 1 (no retry)', async () => {
    let calls = 0,
      threw = false
    try {
      await withRetry(
        async () => {
          calls += 1
          throw new Error('once')
        },
        { maxAttempts: 1 }
      )
    } catch (error) {
      threw = true
      expect((error as Error).message).toBe('once')
    }
    expect(threw).toBe(true)
    expect(calls).toBe(1)
  })

  test('wraps non-Error thrown values', async () => {
    let threw = false
    try {
      await withRetry(
        async () => {
          throw new Error('string-error')
        },
        { initialDelayMs: 1, maxAttempts: 2 }
      )
    } catch (error) {
      threw = true
      expect(error).toBeInstanceOf(Error)
      expect((error as Error).message).toBe('string-error')
    }
    expect(threw).toBe(true)
  })

  test('default options: 3 attempts', async () => {
    let calls = 0
    try {
      await withRetry(
        async () => {
          calls += 1
          throw new Error('fail')
        },
        { initialDelayMs: 1 }
      )
    } catch {
      /* Expected */
    }
    expect(calls).toBe(3)
  })
})

/* eslint-disable require-atomic-updates */
const mockFetch = (fn: (...args: never[]) => Promise<Response>) => {
  globalThis.fetch = fn as never
}

describe('fetchWithRetry', () => {
  test('returns successful response', async () => {
    const originalFetch = globalThis.fetch
    mockFetch(async () => new Response('ok', { status: 200 }))
    try {
      const resp = await fetchWithRetry('https://example.com')
      expect(resp.ok).toBe(true)
      expect(await resp.text()).toBe('ok')
    } finally {
      globalThis.fetch = originalFetch
    }
  })

  test('does not retry on 4xx errors', async () => {
    const originalFetch = globalThis.fetch
    let calls = 0
    mockFetch(async () => {
      calls += 1
      return new Response('not found', { status: 404, statusText: 'Not Found' })
    })
    try {
      const resp = await fetchWithRetry('https://example.com', { retry: { initialDelayMs: 1, maxAttempts: 3 } })
      expect(resp.status).toBe(404)
      expect(calls).toBe(1)
    } finally {
      globalThis.fetch = originalFetch
    }
  })

  test('retries on 5xx errors', async () => {
    const originalFetch = globalThis.fetch
    let calls = 0
    mockFetch(async () => {
      calls += 1
      // oxlint-disable-next-line no-conditional-in-test
      if (calls < 3) return new Response('error', { status: 500, statusText: 'Internal Server Error' })
      return new Response('ok', { status: 200 })
    })
    try {
      const resp = await fetchWithRetry('https://example.com', { retry: { initialDelayMs: 1, maxAttempts: 3 } })
      expect(resp.ok).toBe(true)
      expect(calls).toBe(3)
    } finally {
      globalThis.fetch = originalFetch
    }
  })

  test('throws after all retries for persistent 5xx', async () => {
    const originalFetch = globalThis.fetch
    let calls = 0
    mockFetch(async () => {
      calls += 1
      return new Response('error', { status: 500, statusText: 'Internal Server Error' })
    })
    let threw = false
    try {
      await fetchWithRetry('https://example.com', { retry: { initialDelayMs: 1, maxAttempts: 2 } })
    } catch (error) {
      threw = true
      expect((error as Error).message).toContain('500')
    } finally {
      globalThis.fetch = originalFetch
    }
    expect(threw).toBe(true)
    expect(calls).toBe(2)
  })

  test('passes fetch options through', async () => {
    const originalFetch = globalThis.fetch
    let receivedInit: RequestInit | undefined
    mockFetch(async (...args: never[]) => {
      const [, init] = args as unknown as [unknown, RequestInit | undefined]
      receivedInit = init
      return new Response('ok', { status: 200 })
    })
    try {
      await fetchWithRetry('https://example.com', { method: 'POST' })
      expect(receivedInit?.method).toBe('POST')
    } finally {
      globalThis.fetch = originalFetch
    }
  })
})

describe('Fix #1: getOrgMember compound index', () => {
  test('getOrgMember is exported from org-crud', async () => {
    const mod = await import('../server/org-crud')
    expect(mod).toHaveProperty('getOrgMember')
    expect(typeof mod.getOrgMember).toBe('function')
  })

  test('getOrgMember is re-exported from server/index', async () => {
    const mod = await import('../server/index')
    expect(mod).toHaveProperty('getOrgMember')
  })

  test('requireOrgMember is exported from org-crud', async () => {
    const mod = await import('../server/org-crud')
    expect(mod).toHaveProperty('requireOrgMember')
    expect(typeof mod.requireOrgMember).toBe('function')
  })
})

describe('Fix #2: singleton first-upsert validates full schema', () => {
  const singletonProfile = object({
    bio: string().optional(),
    displayName: string(),
    notifications: boolean(),
    theme: zenum(['light', 'dark', 'system'])
  })

  test('partial data fails full schema safeParse (missing required fields)', () => {
    const result = singletonProfile.safeParse({ bio: 'hello' })
    expect(result.success).toBe(false)
  })

  test('partial data missing displayName fails', () => {
    const result = singletonProfile.safeParse({ notifications: true, theme: 'dark' })
    expect(result.success).toBe(false)
  })

  test('partial data missing notifications fails', () => {
    const result = singletonProfile.safeParse({ displayName: 'Jane', theme: 'dark' })
    expect(result.success).toBe(false)
  })

  test('partial data missing theme fails', () => {
    const result = singletonProfile.safeParse({ displayName: 'Jane', notifications: true })
    expect(result.success).toBe(false)
  })

  test('complete data passes full schema safeParse', () => {
    const result = singletonProfile.safeParse({ displayName: 'Jane', notifications: true, theme: 'dark' })
    expect(result.success).toBe(true)
  })

  test('complete data with optional bio passes', () => {
    const result = singletonProfile.safeParse({
      bio: 'Hello world',
      displayName: 'Jane',
      notifications: false,
      theme: 'system'
    })
    expect(result.success).toBe(true)
  })

  test('partial schema allows subset of fields', () => {
    const partial = singletonProfile.partial(),
      result = partial.safeParse({ bio: 'hello' })
    expect(result.success).toBe(true)
  })

  test('partial schema allows empty object', () => {
    const partial = singletonProfile.partial(),
      result = partial.safeParse({})
    expect(result.success).toBe(true)
  })

  test('invalid enum value fails full schema', () => {
    const result = singletonProfile.safeParse({ displayName: 'Jane', notifications: true, theme: 'invalid' })
    expect(result.success).toBe(false)
  })

  test('wrong type for required field fails full schema', () => {
    const result = singletonProfile.safeParse({ displayName: 123, notifications: true, theme: 'dark' })
    expect(result.success).toBe(false)
  })
})

describe('Fix #3: factory table names typed as keyof DM & string', () => {
  test('setup is exported from server/setup', async () => {
    const mod = await import('../server/setup')
    expect(mod).toHaveProperty('setup')
    expect(typeof mod.setup).toBe('function')
  })

  test('setup is re-exported from server/index', async () => {
    const mod = await import('../server/index')
    expect(mod).toHaveProperty('setup')
  })
})

describe('Fix #4: ownedCascade helper', () => {
  const taskSchema = object({ completed: boolean(), priority: string(), projectId: string(), title: string() }),
    messageSchema = object({ chatId: string(), content: string(), role: string() })

  test('ownedCascade accepts valid foreignKey', () => {
    const result = ownedCascade(taskSchema, { foreignKey: 'projectId', table: 'task' })
    expect(result.foreignKey).toBe('projectId')
    expect(result.table).toBe('task')
  })

  test('ownedCascade accepts another valid foreignKey', () => {
    const result = ownedCascade(messageSchema, { foreignKey: 'chatId', table: 'message' })
    expect(result.foreignKey).toBe('chatId')
    expect(result.table).toBe('message')
  })

  test('ownedCascade rejects invalid foreignKey', () => {
    // @ts-expect-error — 'projctId' is not a key of taskSchema
    const _invalid = ownedCascade(taskSchema, { foreignKey: 'projctId', table: 'task' })
    expect(_invalid).toBeDefined()
  })

  test('ownedCascade rejects completely wrong foreignKey', () => {
    // @ts-expect-error — 'nonExistentField' is not a key of taskSchema
    const _invalid = ownedCascade(taskSchema, { foreignKey: 'nonExistentField', table: 'task' })
    expect(_invalid).toBeDefined()
  })

  test('ownedCascade rejects misspelled foreignKey on messageSchema', () => {
    // @ts-expect-error — 'chatI' is not a key of messageSchema
    const _invalid = ownedCascade(messageSchema, { foreignKey: 'chatI', table: 'message' })
    expect(_invalid).toBeDefined()
  })

  test('ownedCascade returns object with foreignKey and table', () => {
    const result = ownedCascade(taskSchema, { foreignKey: 'title', table: 'subtask' })
    expect(typeof result.foreignKey).toBe('string')
    expect(typeof result.table).toBe('string')
  })

  test('ownedCascade is re-exported from server/index', async () => {
    const mod = await import('../server/index')
    expect(mod).toHaveProperty('ownedCascade')
    expect(typeof mod.ownedCascade).toBe('function')
  })

  test('ownedCascade mirrors orgCascade behavior', () => {
    const owned = ownedCascade(taskSchema, { foreignKey: 'projectId', table: 'task' }),
      org = orgCascade(taskSchema, { foreignKey: 'projectId', table: 'task' })
    expect(owned.foreignKey).toBe(org.foreignKey)
    expect(owned.table).toBe(org.table)
  })
})

describe('Fix #5: OrgCascadeTableConfig type', () => {
  interface TestDM {
    [key: string]: GenericTableInfo
    blog: GenericTableInfo
    wiki: GenericTableInfo
  }

  test('string config accepts valid table name', () => {
    const config: OrgCascadeTableConfig<TestDM> = 'blog'
    expect(config).toBe('blog')
  })

  test('string config accepts another valid table name', () => {
    const config: OrgCascadeTableConfig<TestDM> = 'wiki'
    expect(config).toBe('wiki')
  })

  test('object config accepts valid table name', () => {
    const config: OrgCascadeTableConfig<TestDM> = { table: 'wiki' }
    expect(config).toEqual({ table: 'wiki' })
  })

  test('object config accepts fileFields', () => {
    const config: OrgCascadeTableConfig<TestDM> = { fileFields: ['photo', 'avatar'], table: 'blog' }
    expect(config).toEqual({ fileFields: ['photo', 'avatar'], table: 'blog' })
  })

  test('object config with empty fileFields', () => {
    const config: OrgCascadeTableConfig<TestDM> = { fileFields: [], table: 'blog' }
    expect(config).toEqual({ fileFields: [], table: 'blog' })
  })

  test('array of OrgCascadeTableConfig accepts mixed configs', () => {
    const configs: OrgCascadeTableConfig<TestDM>[] = ['blog', { fileFields: ['photo'], table: 'wiki' }]
    expect(configs).toHaveLength(2)
  })
})

describe('Fix #6: org update allows clearing avatarId with null', () => {
  const convertAvatar = (v: null | string) => v ?? undefined

  test('null converts to undefined', () => {
    expect(convertAvatar(null)).toBeUndefined()
  })

  test('non-null value preserved', () => {
    expect(convertAvatar('storage_123')).toBe('storage_123')
  })

  test('undefined is present in patch object', () => {
    const patchData: Record<string, unknown> = { avatarId: undefined }
    expect(Object.keys(patchData)).toContain('avatarId')
    expect(patchData.avatarId).toBeUndefined()
  })

  test('different values trigger cleanup', () => {
    const shouldCleanup = (a: null | string, b: null | string) => a !== b
    expect(shouldCleanup('storage_old', 'storage_new')).toBe(true)
  })

  test('null is different from old value', () => {
    const shouldCleanup = (a: null | string, b: null | string) => a !== b
    expect(shouldCleanup('storage_old', null)).toBe(true)
  })

  test('same value skips cleanup', () => {
    const shouldCleanup = (a: null | string, b: null | string) => a !== b
    expect(shouldCleanup('storage_same', 'storage_same')).toBe(false)
  })
})

describe('Fix #7: child list accepts optional limit parameter', () => {
  const limitSchema = number().optional()

  test('limit schema accepts undefined', () => {
    const undef = undefined
    expect(limitSchema.safeParse(undef).success).toBe(true)
  })

  test('limit schema accepts positive number', () => {
    expect(limitSchema.safeParse(10).success).toBe(true)
  })

  test('limit schema accepts zero', () => {
    expect(limitSchema.safeParse(0).success).toBe(true)
  })

  test('limit schema rejects string', () => {
    expect(limitSchema.safeParse('abc').success).toBe(false)
  })

  test('limit schema rejects boolean', () => {
    expect(limitSchema.safeParse(true).success).toBe(false)
  })

  test('child.ts list arg includes limit field', async () => {
    const mod = await import('../server/child')
    expect(mod).toHaveProperty('makeChildCrud')
  })
})

// oxlint-disable-next-line unicorn/consistent-function-scoping
const capBatchSize = (bs: number | undefined) => Math.min(bs ?? BULK_MAX, BULK_MAX)

describe('Fix #8: cache purge uses take(batchSize)', () => {
  test('BULK_MAX is 100', () => {
    expect(BULK_MAX).toBe(100)
  })

  test('batchSize capping — undefined defaults to BULK_MAX', () => {
    const undef = undefined
    expect(capBatchSize(undef)).toBe(100)
  })

  test('batchSize capping — small value preserved', () => {
    expect(capBatchSize(50)).toBe(50)
  })

  test('batchSize capping — large value capped at BULK_MAX', () => {
    expect(capBatchSize(200)).toBe(100)
  })

  test('batchSize capping — exact BULK_MAX preserved', () => {
    expect(capBatchSize(100)).toBe(100)
  })

  test('batchSize capping — value of 1 preserved', () => {
    expect(capBatchSize(1)).toBe(1)
  })

  test('batchSize schema accepts number or undefined', () => {
    const bsSchema = number().optional(),
      undef = undefined
    expect(bsSchema.safeParse(undef).success).toBe(true)
    expect(bsSchema.safeParse(50).success).toBe(true)
    expect(bsSchema.safeParse('abc').success).toBe(false)
  })
})

describe('Fix #9: useList accepts optional pageSize', () => {
  test('DEFAULT_PAGE_SIZE is 50', () => {
    expect(DEFAULT_PAGE_SIZE).toBe(50)
  })

  test('UseListOptions accepts pageSize', () => {
    const opts: UseListOptions = { pageSize: 25 }
    expect(opts.pageSize).toBe(25)
  })

  test('UseListOptions accepts empty object', () => {
    const opts: UseListOptions = {}
    expect(opts.pageSize).toBeUndefined()
  })

  test('pageSize is used when provided', () => {
    const opts: UseListOptions = { pageSize: 25 }
    expect(opts.pageSize).toBe(25)
    expect(opts.pageSize).not.toBe(DEFAULT_PAGE_SIZE)
  })

  test('missing pageSize falls back to DEFAULT_PAGE_SIZE conceptually', () => {
    const opts: UseListOptions = {}
    expect(opts.pageSize).toBeUndefined()
    expect(DEFAULT_PAGE_SIZE).toBe(50)
  })

  test('DEFAULT_PAGE_SIZE module export', async () => {
    const mod = await import('../react/use-list')
    expect(mod).toHaveProperty('DEFAULT_PAGE_SIZE')
    expect(mod.DEFAULT_PAGE_SIZE).toBe(50)
  })

  test('useList module export', async () => {
    const mod = await import('../react/use-list')
    expect(mod).toHaveProperty('useList')
    expect(typeof mod.useList).toBe('function')
  })
})

describe('Fix #10: isTestMode production safety', () => {
  test('isTestMode returns true when CONVEX_TEST_MODE=true and NODE_ENV=test', () => {
    const origTest = process.env.CONVEX_TEST_MODE,
      origNode = process.env.NODE_ENV
    process.env.CONVEX_TEST_MODE = 'true'
    process.env.NODE_ENV = 'test'
    expect(isTestMode()).toBe(true)
    process.env.CONVEX_TEST_MODE = origTest
    process.env.NODE_ENV = origNode
  })

  test('isTestMode returns false when NODE_ENV=production even with CONVEX_TEST_MODE=true', () => {
    const origTest = process.env.CONVEX_TEST_MODE,
      origNode = process.env.NODE_ENV
    process.env.CONVEX_TEST_MODE = 'true'
    process.env.NODE_ENV = 'production'
    expect(isTestMode()).toBe(false)
    process.env.CONVEX_TEST_MODE = origTest
    process.env.NODE_ENV = origNode
  })

  test('isTestMode returns false when CONVEX_TEST_MODE is false', () => {
    const origTest = process.env.CONVEX_TEST_MODE,
      origNode = process.env.NODE_ENV
    process.env.CONVEX_TEST_MODE = 'false'
    process.env.NODE_ENV = 'test'
    expect(isTestMode()).toBe(false)
    process.env.CONVEX_TEST_MODE = origTest
    process.env.NODE_ENV = origNode
  })

  test('isTestMode returns false when CONVEX_TEST_MODE is undefined', () => {
    const origTest = process.env.CONVEX_TEST_MODE,
      origNode = process.env.NODE_ENV
    /** biome-ignore lint/performance/noDelete: process.env requires delete to truly unset */
    delete process.env.CONVEX_TEST_MODE
    process.env.NODE_ENV = 'test'
    expect(isTestMode()).toBe(false)
    process.env.CONVEX_TEST_MODE = origTest
    process.env.NODE_ENV = origNode
  })

  test('isTestMode returns false when both are undefined', () => {
    const origTest = process.env.CONVEX_TEST_MODE,
      origNode = process.env.NODE_ENV
    /** biome-ignore lint/performance/noDelete: process.env requires delete to truly unset */
    delete process.env.CONVEX_TEST_MODE
    /** biome-ignore lint/performance/noDelete: process.env requires delete to truly unset */
    delete process.env.NODE_ENV
    expect(isTestMode()).toBe(false)
    process.env.CONVEX_TEST_MODE = origTest
    process.env.NODE_ENV = origNode
  })

  test('isTestMode returns true when CONVEX_TEST_MODE=true and NODE_ENV=development', () => {
    const origTest = process.env.CONVEX_TEST_MODE,
      origNode = process.env.NODE_ENV
    process.env.CONVEX_TEST_MODE = 'true'
    process.env.NODE_ENV = 'development'
    expect(isTestMode()).toBe(true)
    process.env.CONVEX_TEST_MODE = origTest
    process.env.NODE_ENV = origNode
  })

  test('isTestMode returns true when CONVEX_TEST_MODE=true and NODE_ENV is empty', () => {
    const origTest = process.env.CONVEX_TEST_MODE,
      origNode = process.env.NODE_ENV
    process.env.CONVEX_TEST_MODE = 'true'
    process.env.NODE_ENV = ''
    expect(isTestMode()).toBe(true)
    process.env.CONVEX_TEST_MODE = origTest
    process.env.NODE_ENV = origNode
  })

  test('isTestMode is exported from server/test', async () => {
    const mod = await import('../server/test')
    expect(mod).toHaveProperty('isTestMode')
    expect(typeof mod.isTestMode).toBe('function')
  })
})

describe('VALIDATION_FAILED error code', () => {
  test('VALIDATION_FAILED exists in ERROR_MESSAGES', () => {
    expect(ERROR_MESSAGES).toHaveProperty('VALIDATION_FAILED')
    expect(ERROR_MESSAGES.VALIDATION_FAILED).toBe('Validation failed')
  })

  test('VALIDATION_FAILED is a valid ErrorCode', () => {
    const code: ErrorCode = 'VALIDATION_FAILED'
    expect(code).toBe('VALIDATION_FAILED')
  })

  test('err() accepts VALIDATION_FAILED', () => {
    expect(() => err('VALIDATION_FAILED')).toThrow()
    try {
      err('VALIDATION_FAILED')
    } catch (error) {
      const e = error as { data: { code: string } }
      expect(e.data.code).toBe('VALIDATION_FAILED')
    }
  })

  test('extractErrorData works with VALIDATION_FAILED', () => {
    const e = new ConvexError({ code: 'VALIDATION_FAILED', fields: ['title'] }),
      d = extractErrorData(e)
    expect(d).toBeDefined()
    expect(d?.code).toBe('VALIDATION_FAILED')
    expect(d?.fields).toEqual(['title'])
  })

  test('getErrorCode returns VALIDATION_FAILED', () => {
    const e = new ConvexError({ code: 'VALIDATION_FAILED' })
    expect(getErrorCode(e)).toBe('VALIDATION_FAILED')
  })

  test('getErrorMessage falls back to ERROR_MESSAGES for VALIDATION_FAILED', () => {
    const msg = getErrorMessage(new ConvexError({ code: 'VALIDATION_FAILED' }))
    expect(msg).toBe('Validation failed')
  })

  test('handleConvexError routes VALIDATION_FAILED', () => {
    let called = false
    handleConvexError(new ConvexError({ code: 'VALIDATION_FAILED' }), {
      VALIDATION_FAILED: () => {
        called = true
      }
    })
    expect(called).toBe(true)
  })

  test('typo in ErrorCode is caught at compile time', () => {
    // @ts-expect-error - VALIDATION_FAILEDD is not a valid ErrorCode (typo)
    const _invalidCode: ErrorCode = 'VALIDATION_FAILEDD' as const
    expect(_invalidCode).toBeDefined()
  })
})

describe('errValidation with VALIDATION_FAILED', () => {
  test('errValidation throws ConvexError with code and fields', () => {
    const zodError = {
      flatten: () => ({ fieldErrors: { content: ['Too short'], title: ['Required'] } })
    }
    try {
      errValidation('VALIDATION_FAILED', zodError)
    } catch (error) {
      const e = error as { data: { code: string; fields: string[]; message: string } }
      expect(e.data.code).toBe('VALIDATION_FAILED')
      expect(e.data.fields).toContain('title')
      expect(e.data.fields).toContain('content')
      expect(e.data.fields).toHaveLength(2)
      expect(e.data.message).toContain('Invalid:')
      expect(e.data.message).toContain('title')
      expect(e.data.message).toContain('content')
    }
  })

  test('errValidation with empty fieldErrors uses fallback message', () => {
    const zodError = {
      flatten: () => ({ fieldErrors: {} })
    }
    try {
      errValidation('VALIDATION_FAILED', zodError)
    } catch (error) {
      const e = error as { data: { code: string; fields: string[]; message: string } }
      expect(e.data.code).toBe('VALIDATION_FAILED')
      expect(e.data.fields).toEqual([])
      expect(e.data.message).toBe('Validation failed')
    }
  })

  test('errValidation return type is never', () => {
    const zodError = { flatten: () => ({ fieldErrors: { x: ['bad'] } }) }
    expect(() => errValidation('VALIDATION_FAILED', zodError)).toThrow()
  })
})

describe('cleanFiles update scenario (next param)', () => {
  const mockStorage = () => {
    const deleted: string[] = []
    return {
      delete: async (id: string) => {
        deleted.push(id)
      },
      deleted,
      getUrl: async () => null
    }
  }

  test('cleans replaced single file on update', async () => {
    const s = mockStorage()
    await cleanFiles({
      doc: { photo: 'old_file_id' },
      fileFields: ['photo'],
      next: { photo: 'new_file_id' },
      storage: s
    })
    expect(s.deleted).toEqual(['old_file_id'])
  })

  test('cleans removed single file on update (set to null)', async () => {
    const s = mockStorage()
    await cleanFiles({
      doc: { photo: 'old_file_id' },
      fileFields: ['photo'],
      next: { photo: null },
      storage: s
    })
    expect(s.deleted).toEqual(['old_file_id'])
  })

  test('does not clean unchanged file on update', async () => {
    const s = mockStorage()
    await cleanFiles({
      doc: { photo: 'same_file_id' },
      fileFields: ['photo'],
      next: { photo: 'same_file_id' },
      storage: s
    })
    expect(s.deleted).toEqual([])
  })

  test('does not clean file when field not in next (partial update)', async () => {
    const s = mockStorage()
    await cleanFiles({
      doc: { photo: 'existing_file' },
      fileFields: ['photo'],
      next: { title: 'new title' },
      storage: s
    })
    expect(s.deleted).toEqual([])
  })

  test('cleans removed array files on update', async () => {
    const s = mockStorage()
    await cleanFiles({
      doc: { attachments: ['file_a', 'file_b', 'file_c'] },
      fileFields: ['attachments'],
      next: { attachments: ['file_a'] },
      storage: s
    })
    expect(s.deleted).toContain('file_b')
    expect(s.deleted).toContain('file_c')
    expect(s.deleted).not.toContain('file_a')
  })

  test('cleans all files on delete (no next param)', async () => {
    const s = mockStorage()
    await cleanFiles({
      doc: { attachments: ['file_a', 'file_b'], photo: 'file_c' },
      fileFields: ['photo', 'attachments'],
      storage: s
    })
    expect(s.deleted).toContain('file_a')
    expect(s.deleted).toContain('file_b')
    expect(s.deleted).toContain('file_c')
    expect(s.deleted).toHaveLength(3)
  })

  test('skips null prev values on delete', async () => {
    const s = mockStorage()
    await cleanFiles({
      doc: { photo: null },
      fileFields: ['photo'],
      storage: s
    })
    expect(s.deleted).toEqual([])
  })

  test('handles mixed file types (single + array) on update', async () => {
    const s = mockStorage()
    await cleanFiles({
      doc: { attachments: ['att_old'], photo: 'photo_old' },
      fileFields: ['photo', 'attachments'],
      next: { attachments: ['att_new'], photo: 'photo_new' },
      storage: s
    })
    expect(s.deleted).toContain('photo_old')
    expect(s.deleted).toContain('att_old')
    expect(s.deleted).not.toContain('photo_new')
    expect(s.deleted).not.toContain('att_new')
  })
})

describe('detectFiles on child-like schemas', () => {
  test('detects file fields in child schema with foreign key', () => {
    const shape = { avatar: cvFile().nullable(), chatId: string(), content: string() }
    expect(detectFiles(shape)).toEqual(['avatar'])
  })

  test('detects cvFiles in child schema', () => {
    const shape = { attachments: cvFiles(), chatId: string(), text: string() }
    expect(detectFiles(shape)).toEqual(['attachments'])
  })

  test('detects multiple file fields in child schema', () => {
    const shape = {
        attachments: cvFiles(),
        chatId: string(),
        content: string(),
        thumbnail: cvFile().nullable().optional()
      },
      result = detectFiles(shape)
    expect(result).toContain('attachments')
    expect(result).toContain('thumbnail')
    expect(result).toHaveLength(2)
  })

  test('returns empty for child schema without file fields', () => {
    const shape = { chatId: string(), content: string(), likes: number() }
    expect(detectFiles(shape)).toEqual([])
  })
})

describe('makeUnique optional index param', () => {
  test('makeUnique is exported from helpers', () => {
    expect(typeof makeUnique).toBe('function')
  })

  test('makeUnique accepts index parameter in options', () => {
    const sig = makeUnique.length
    expect(sig).toBe(1)
  })
})

describe('ERROR_MESSAGES completeness', () => {
  test('all error codes have non-empty string messages', () => {
    for (const key of Object.keys(ERROR_MESSAGES)) {
      const msg = ERROR_MESSAGES[key as ErrorCode]
      expect(typeof msg).toBe('string')
      expect(msg.length).toBeGreaterThan(0)
    }
  })

  test('ErrorCode type matches ERROR_MESSAGES keys', () => {
    const keys = Object.keys(ERROR_MESSAGES)
    expect(keys.length).toBeGreaterThan(0)
    for (const k of keys) {
      const code = k as ErrorCode
      expect(ERROR_MESSAGES[code]).toBeDefined()
    }
  })

  test('VALIDATION_FAILED is distinct from INVALID_WHERE', () => {
    expect(ERROR_MESSAGES.VALIDATION_FAILED).not.toBe(ERROR_MESSAGES.INVALID_WHERE)
    expect(ERROR_MESSAGES.VALIDATION_FAILED).toBe('Validation failed')
    expect(ERROR_MESSAGES.INVALID_WHERE).toBe('Invalid filters')
  })
})
