/* eslint-disable @typescript-eslint/no-unnecessary-type-parameters, @typescript-eslint/max-params */
import type { GenericDataModel, GenericMutationCtx, GenericQueryCtx } from 'convex/server'
import type { ZodObject, ZodRawShape } from 'zod/v4'

import { customCtx } from 'convex-helpers/server/customFunctions'
import { zCustomMutation, zCustomQuery } from 'convex-helpers/server/zod4'

import type { OrgCrudOptions } from './org-crud'
import type {
  BaseSchema,
  CrudOptions,
  DbLike,
  Mb,
  OrgSchema,
  OwnedSchema,
  Qb,
  Rec,
  SetupConfig,
  SingletonOptions,
  SingletonSchema
} from './types'

import { typed } from './bridge'
import { makeCacheCrud } from './cache-crud'
import { makeChildCrud } from './child'
import { makeCrud } from './crud'
import { dbInsert, dbPatch, err, getUser, makeUnique, ownGet, readCtx, time } from './helpers'
import { makeOrg } from './org'
import { makeOrgCrud } from './org-crud'
import { makeSingletonCrud } from './singleton'

const setup = <DM extends GenericDataModel>(config: SetupConfig<DM>) => {
  type QCtx = GenericQueryCtx<DM>
  type MCtx = GenericMutationCtx<DM>
  const { getAuthUserId } = config,
    authId = async (c: unknown) => getAuthUserId(typed(c)),
    asDb = (c: { db: unknown }) => typed(c.db) as DbLike,
    pq = zCustomQuery(
      config.query,
      customCtx(async (c: QCtx) => {
        const vid = await authId(c),
          { withAuthor } = readCtx({ db: asDb(c), storage: typed(c.storage), viewerId: vid })
        return { viewerId: vid, withAuthor }
      })
    ),
    q = zCustomQuery(
      config.query,
      customCtx(async (c: QCtx) => {
        const db = asDb(c),
          user = await getUser({ ctx: typed(c), db, getAuthUserId }),
          { viewerId, withAuthor } = readCtx({ db, storage: typed(c.storage), viewerId: user._id })
        return {
          get: ownGet(db, user._id),
          user,
          viewerId,
          withAuthor
        }
      })
    ),
    m = zCustomMutation(
      config.mutation,
      customCtx(async (c: MCtx) => {
        const db = asDb(c),
          now = time(),
          user = await getUser({ ctx: typed(c), db, getAuthUserId }),
          get = ownGet(db, user._id)
        return {
          create: async (t: string, d: Rec) => dbInsert(db, t, { ...d, ...now, userId: user._id }),
          delete: async (id: string) => {
            const d = await get(id)
            await db.delete(id)
            return d
          },
          get,
          patch: async (
            id: string,
            data: ((doc: Rec) => Partial<Rec> | Promise<Partial<Rec>>) | Partial<Rec>,
            expectedUpdatedAt?: number
          ) => {
            const doc = await get(id)
            if (expectedUpdatedAt !== undefined && doc.updatedAt !== expectedUpdatedAt) return err('CONFLICT')
            const up = typeof data === 'function' ? await data(doc) : data
            await dbPatch(db, id, { ...up, ...now })
            return { ...doc, ...up, ...now }
          },
          user
        }
      })
    ),
    cq = zCustomQuery(
      config.query,
      customCtx(() => ({}))
    ),
    cm = zCustomMutation(
      config.mutation,
      customCtx(() => ({}))
    ),
    crud = <S extends ZodRawShape>(table: keyof DM & string, schema: OwnedSchema<S>, opt?: CrudOptions<S>) =>
      makeCrud({
        builders: { cm, cq, m: typed(m) as Mb, pq: typed(pq) as Qb, q: typed(q) as Qb },
        options: opt,
        schema,
        strictFilter: config.strictFilter,
        table
      }),
    childCrud = <S extends ZodRawShape, PS extends ZodRawShape = ZodRawShape>(
      table: keyof DM & string,
      meta: { foreignKey: string; index: string; parent: string; parentSchema?: ZodObject<PS>; schema: ZodObject<S> },
      opt?: { pub?: { parentField: keyof PS & string } }
    ) =>
      makeChildCrud({
        builders: { m: typed(m) as Mb, pq: typed(pq) as Qb, q: typed(q) as Qb },
        meta,
        options: opt,
        table
      }),
    orgCrud = <S extends ZodRawShape>(table: keyof DM & string, schema: OrgSchema<S>, opt?: OrgCrudOptions<S>) =>
      makeOrgCrud({
        builders: { m: typed(m) as Mb, q: typed(q) as Qb },
        options: opt,
        schema,
        table
      }),
    cacheCrud = <S extends ZodRawShape, K extends keyof S & string>(opts: {
      fetcher?: (c: unknown, key: unknown) => Promise<unknown>
      key: K
      rateLimit?: { max: number; window: number }
      schema: BaseSchema<S>
      table: keyof DM & string
      ttl?: number
    }) =>
      makeCacheCrud({
        ...opts,
        builders: {
          action: config.action,
          cm,
          cq,
          internalMutation: config.internalMutation,
          internalQuery: config.internalQuery,
          mutation: config.mutation,
          query: config.query
        }
      }),
    singletonCrud = <S extends ZodRawShape>(
      table: keyof DM & string,
      schema: SingletonSchema<S>,
      opt?: SingletonOptions
    ) =>
      makeSingletonCrud({
        builders: { m: typed(m) as Mb, q: typed(q) as Qb },
        options: opt,
        schema,
        table
      }),
    uniqueCheck = <S extends ZodRawShape>(
      _schema: ZodObject<S>,
      table: keyof DM & string,
      field: keyof S & string,
      index?: string
    ) => makeUnique({ field, index, pq: typed(pq) as Qb, table }),
    normCascade = config.orgCascadeTables?.map(t => (typeof t === 'string' ? { table: t } : t)),
    org = config.orgSchema
      ? makeOrg({
          cascadeTables: normCascade,
          getAuthUserId: config.getAuthUserId,
          mutation: config.mutation,
          query: config.query,
          schema: config.orgSchema
        })
      : undefined,
    user = { me: q({ handler: (c: Rec) => c.user }) }
  return { cacheCrud, childCrud, cm, cq, crud, m, org, orgCrud, pq, q, singletonCrud, uniqueCheck, user }
}

export { setup }
