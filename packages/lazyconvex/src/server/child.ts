import type { ZodObject, ZodRawShape } from 'zod/v4'

import { zid } from 'convex-helpers/server/zod4'
import { number } from 'zod/v4'

import type { BaseBuilders, ChildCrudResult, DbReadLike, MutCtx, Rec, UserCtx } from './types'

import { idx, typed } from './bridge'
import { cleanFiles, dbDelete, dbInsert, dbPatch, detectFiles, err, pickFields, time } from './helpers'

interface ChildCrudOptions<PS extends ZodRawShape = ZodRawShape> {
  pub?: { parentField: keyof PS & string }
}

interface ChildMeta<S extends ZodRawShape = ZodRawShape, PS extends ZodRawShape = ZodRawShape> {
  foreignKey: string
  index: string
  parent: string
  parentSchema?: ZodObject<PS>
  schema: ZodObject<S>
}

const checkParentField = async (db: DbReadLike, parentId: string, field: string) => {
    const p = await db.get(parentId)
    return p?.[field] ? p : null
  },
  makeChildCrud = <S extends ZodRawShape, PS extends ZodRawShape = ZodRawShape>({
    builders,
    meta,
    options,
    table
  }: {
    builders: BaseBuilders
    meta: ChildMeta<S, PS>
    options?: ChildCrudOptions<PS>
    table: string
  }): ChildCrudResult<S> => {
    const { m, pq, q } = builders,
      { foreignKey, index, parent, schema } = meta,
      getFK = (doc: Rec): string => doc[foreignKey] as string,
      schemaKeys = Object.keys(schema.shape),
      partial = schema.partial(),
      fileFs = detectFiles(schema.shape),
      idArgs = { id: zid(table) },
      // oxlint-disable-next-line unicorn/consistent-function-scoping
      verifyParentOwnership = async (ctx: UserCtx, parentId: string) => {
        const p = await ctx.db.get(parentId)
        return p && p.userId === ctx.user._id ? p : null
      },
      create = m({
        args: { ...schema.shape, [foreignKey]: zid(parent) },
        handler: typed(async (ctx: UserCtx, a: Rec) => {
          const args = a,
            parentId = args[foreignKey] as string,
            data = schema.parse(pickFields(args, schemaKeys))
          if (!(await verifyParentOwnership(ctx, parentId))) return err('NOT_FOUND', `${table}:create`)
          return dbInsert(ctx.db, table, { ...data, [foreignKey]: parentId, ...time() })
        })
      }),
      update = m({
        args: { ...idArgs, ...partial.shape },
        handler: typed(async (ctx: MutCtx, a: Rec) => {
          const args = a as Rec & { id: string },
            { id, ...rest } = args,
            data = partial.parse(pickFields(rest, schemaKeys)),
            doc = await ctx.db.get(id)
          if (!doc) return err('NOT_FOUND', `${table}:update`)
          const parentId = getFK(doc)
          if (!(await verifyParentOwnership(ctx, parentId))) return err('NOT_FOUND', `${table}:update`)
          const now = time()
          await cleanFiles({ doc, fileFields: fileFs, next: data as Rec, storage: ctx.storage })
          await dbPatch(ctx.db, id, { ...data, ...now })
          return { ...doc, ...data, ...now }
        })
      }),
      rm = m({
        args: idArgs,
        handler: typed(async (ctx: MutCtx, { id }: { id: string }) => {
          const doc = await ctx.db.get(id)
          if (!doc) return err('NOT_FOUND', `${table}:rm`)
          const parentId = getFK(doc)
          if (!(await verifyParentOwnership(ctx, parentId))) return err('NOT_FOUND', `${table}:rm`)
          await dbDelete(ctx.db, id)
          await cleanFiles({ doc, fileFields: fileFs, storage: ctx.storage })
          return doc
        })
      }),
      list = q({
        args: { [foreignKey]: zid(parent), limit: number().optional() },
        handler: typed(async (ctx: UserCtx, a: Rec) => {
          const args = a,
            parentId = args[foreignKey] as string
          if (!(await verifyParentOwnership(ctx, parentId))) return err('NOT_AUTHORIZED', `${table}:list`)
          const qry = ctx.db
            .query(table)
            .withIndex(
              index,
              idx(i => i.eq(foreignKey, parentId))
            )
            .order('asc')
          return args.limit ? qry.take(args.limit as number) : qry.collect()
        })
      }),
      get = q({
        args: idArgs,
        handler: typed(async (ctx: UserCtx, { id }: { id: string }) => {
          const doc = await ctx.db.get(id)
          if (!doc) return null
          const parentId = getFK(doc)
          if (!(await verifyParentOwnership(ctx, parentId))) return err('NOT_AUTHORIZED', `${table}:get`)
          return doc
        })
      }),
      pubField = options?.pub?.parentField,
      pub =
        pubField && pq
          ? {
              get: pq({
                args: idArgs,
                handler: typed(async (ctx: { db: DbReadLike }, { id }: { id: string }) => {
                  const doc = await ctx.db.get(id)
                  if (!doc) return null
                  if (!(await checkParentField(ctx.db, getFK(doc), pubField))) return err('NOT_FOUND', `${table}:pub.get`)
                  return doc
                })
              }),
              list: pq({
                args: { [foreignKey]: zid(parent), limit: number().optional() },
                handler: typed(async (ctx: { db: DbReadLike }, a: Rec) => {
                  const parentId = a[foreignKey] as string
                  if (!(await checkParentField(ctx.db, parentId, pubField))) return err('NOT_FOUND', `${table}:pub.list`)
                  const qry = ctx.db
                    .query(table)
                    .withIndex(
                      index,
                      idx(i => i.eq(foreignKey, parentId))
                    )
                    .order('asc')
                  return a.limit ? qry.take(a.limit as number) : qry.collect()
                })
              })
            }
          : undefined
    return { create, get, list, ...(pub ? { pub } : {}), rm, update } as unknown as ChildCrudResult<S>
  }

export { makeChildCrud }
