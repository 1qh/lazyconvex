/* eslint-disable no-await-in-loop, no-continue, max-statements, @typescript-eslint/no-unnecessary-condition */
// biome-ignore-all lint/performance/noAwaitInLoops: x
// biome-ignore-all lint/nursery/noContinue: x
import type { ZodObject, ZodRawShape } from 'zod/v4'

import { zid } from 'convex-helpers/server/zod4'
import { array, number } from 'zod/v4'

import type {
  BaseBuilders,
  CanEditOpts,
  CascadeOption,
  DbLike,
  DbReadLike,
  FilterLike,
  MutCtx,
  OrgCrudResult,
  OrgEnrichedDoc,
  OrgRole,
  RateLimitConfig,
  ReadCtx,
  Rec
} from './types'

import { BULK_MAX } from '../constants'
import { flt, idx, typed } from './bridge'
import {
  addUrls,
  checkRateLimit,
  cleanFiles,
  dbDelete,
  dbInsert,
  dbPatch,
  detectFiles,
  err,
  log,
  pgOpts,
  time
} from './helpers'
import { isTestMode } from './test'

const ROLE_LEVEL: Record<OrgRole, number> = { admin: 2, member: 1, owner: 3 },
  getOrgRole = ({
    member,
    org,
    userId
  }: {
    member: null | Record<string, unknown>
    org: Record<string, unknown>
    userId: string
  }): null | OrgRole => {
    if (org.userId === userId) return 'owner'
    if (!member) return null
    return (member as { isAdmin?: boolean }).isAdmin ? 'admin' : 'member'
  },
  getOrgMember = async ({ db, orgId, userId }: { db: unknown; orgId: string; userId: string }) =>
    (db as DbReadLike)
      .query('orgMember')
      .withIndex(
        'by_org_user',
        idx(q => q.eq('orgId', orgId).eq('userId', userId))
      )
      .unique() as Promise<null | Record<string, unknown>>,
  requireOrgMember = async ({ db, orgId, userId }: { db: unknown; orgId: string; userId: string }) => {
    const dbl = db as DbReadLike,
      org = await dbl.get(orgId)
    if (!org) return err('NOT_FOUND')
    const member = await getOrgMember({ db, orgId, userId }),
      role = getOrgRole({ member, org, userId })
    if (!role) return err('NOT_ORG_MEMBER')
    return { member, org, role }
  }

interface RequireOrgRoleArgs {
  db: unknown
  minRole: OrgRole
  orgId: string
  userId: string
}

const requireOrgRole = async ({ db, minRole, orgId, userId }: RequireOrgRoleArgs) => {
    const result = await requireOrgMember({ db, orgId, userId })
    if (ROLE_LEVEL[result.role] < ROLE_LEVEL[minRole]) return err('INSUFFICIENT_ORG_ROLE')
    return result
  },
  canEdit = ({ acl, doc, role, userId }: CanEditOpts): boolean => {
    if (role === 'owner' || role === 'admin') return true
    if (doc.userId === userId) return true
    if (acl && doc.editors?.includes(userId)) return true
    return false
  }

interface OrgCrudOptions<S extends ZodRawShape = ZodRawShape> {
  acl?: boolean
  aclFrom?: { field: keyof S & string; table: string }
  cascade?: CascadeOption
  rateLimit?: RateLimitConfig
  softDelete?: boolean
}

const getEditors = (doc: Rec): string[] => (doc.editors as string[] | undefined) ?? [],
  requireOrgDoc = (doc: null | Rec, orgId: string, debug?: string): Rec => {
    if (doc?.orgId !== orgId) return err('NOT_FOUND', debug)
    return doc
  },
  resolveAclDoc = async (
    db: DbLike,
    doc: Rec,
    opt?: { aclFrom?: { field: string; table: string } }
  ): Promise<{
    editors?: string[]
    userId: string
  }> => {
    if (opt?.aclFrom) {
      const parentId = doc[opt.aclFrom.field] as string,
        parent = parentId ? await db.get(parentId) : null
      return {
        editors: parent ? getEditors(parent) : [],
        userId: doc.userId as string
      }
    }
    return doc as { userId: string }
  },
  makeOrgCrud = <S extends ZodRawShape>({
    builders,
    options: opt,
    schema,
    table
  }: {
    builders: BaseBuilders
    options?: OrgCrudOptions<S>
    schema: ZodObject<S>
    table: string
  }): OrgCrudResult<S> => {
    const { m, q } = builders,
      partial = schema.partial(),
      bulkIdsSchema = array(zid(table)).max(BULK_MAX),
      fileFs = detectFiles(schema.shape),
      idArgs = { id: zid(table) },
      orgIdArg = { orgId: zid('org') },
      useAcl = Boolean(opt?.acl) || Boolean(opt?.aclFrom),
      softDel = Boolean(opt?.softDelete),
      enrich = async (c: ReadCtx, docs: Rec[]) =>
        // oxlint-disable-next-line promise/prefer-await-to-then
        Promise.all(
          (await c.withAuthor(docs as { userId: string }[])).map(async d =>
            addUrls({ doc: d, fileFields: fileFs, storage: c.storage })
          )
        ) as Promise<OrgEnrichedDoc<S>[]>,
      cascadeDelete = async (db: DbLike, id: string) => {
        if (!opt?.cascade) return
        const { foreignKey, table: tbl } = opt.cascade,
          kids = await db
            .query(tbl)
            .filter(flt(f => f.eq(f.field(foreignKey), id)))
            .collect()
        for (const kid of kids) await dbDelete(db, kid._id as string)
      },
      create = m({
        args: { ...orgIdArg, ...schema.shape },
        handler: typed(async (c: MutCtx, a: Rec) => {
          const { orgId, ...data } = a as Rec & { orgId: string }
          await requireOrgMember({ db: c.db, orgId, userId: c.user._id as string })
          if (opt?.rateLimit && !isTestMode())
            await checkRateLimit(c.db, { config: opt.rateLimit, key: c.user._id as string, table })
          return dbInsert(c.db, table, { ...data, orgId, userId: c.user._id, ...time() })
        })
      }),
      list = q({
        args: { ...orgIdArg, paginationOpts: pgOpts },
        handler: typed(async (c: MutCtx & ReadCtx, { orgId, paginationOpts }: { orgId: string; paginationOpts: Rec }) => {
          await requireOrgMember({ db: c.db, orgId, userId: c.user._id as string })
          const qry = c.db
              .query(table)
              .withIndex(
                'by_org',
                idx(o => o.eq('orgId', orgId))
              )
              .order('desc'),
            // oxlint-disable-next-line unicorn/no-useless-undefined
            filtered = softDel ? qry.filter((f: FilterLike) => f.eq(f.field('deletedAt'), undefined)) : qry,
            { page, ...rest } = await filtered.paginate(paginationOpts)
          return { ...rest, page: await enrich(c, page) }
        })
      }),
      read = q({
        args: { ...orgIdArg, ...idArgs },
        handler: typed(async (c: MutCtx & ReadCtx, { id, orgId }: { id: string; orgId: string }) => {
          await requireOrgMember({ db: c.db, orgId, userId: c.user._id as string })
          const doc = requireOrgDoc(await c.db.get(id), orgId)
          return (await enrich(c, [doc]))[0]
        })
      }),
      update = m({
        args: { ...orgIdArg, ...idArgs, ...partial.shape, expectedUpdatedAt: number().optional() },
        handler: typed(async (c: MutCtx, a: Rec) => {
          const { expectedUpdatedAt, id, orgId, ...patch } = a as Rec & {
              expectedUpdatedAt?: number
              id: string
              orgId: string
            },
            { role } = await requireOrgMember({ db: c.db, orgId, userId: c.user._id as string }),
            doc = requireOrgDoc(await c.db.get(id), orgId),
            aclDoc = await resolveAclDoc(c.db, doc, opt)
          if (
            !canEdit({
              acl: useAcl,
              doc: aclDoc as { editors?: string[]; userId: string },
              role,
              userId: c.user._id as string
            })
          )
            return err('FORBIDDEN', `${table}:update`)
          if (expectedUpdatedAt !== undefined && doc.updatedAt !== expectedUpdatedAt)
            return err('CONFLICT', `${table}:update`)
          const now = time()
          await cleanFiles({ doc, fileFields: fileFs, next: patch, storage: c.storage })
          await dbPatch(c.db, id, { ...patch, ...now })
          return { ...doc, ...patch, ...now }
        })
      }),
      rm = m({
        args: { ...orgIdArg, ...idArgs },
        handler: typed(async (c: MutCtx, { id, orgId }: { id: string; orgId: string }) => {
          const { role } = await requireOrgMember({ db: c.db, orgId, userId: c.user._id as string }),
            doc = requireOrgDoc(await c.db.get(id), orgId),
            aclDoc = await resolveAclDoc(c.db, doc, opt)
          if (
            !canEdit({
              acl: useAcl,
              doc: aclDoc as { editors?: string[]; userId: string },
              role,
              userId: c.user._id as string
            })
          )
            return err('FORBIDDEN', `${table}:rm`)
          if (softDel) {
            await dbPatch(c.db, id, { deletedAt: Date.now() })
            log('info', 'crud:delete', { id, soft: true, table })
            return doc
          }
          await cascadeDelete(c.db, id)
          await dbDelete(c.db, id)
          await cleanFiles({ doc, fileFields: fileFs, storage: c.storage })
          return doc
        })
      }),
      bulkUpdate = m({
        args: { ...orgIdArg, data: partial, ids: bulkIdsSchema },
        handler: typed(async (c: MutCtx, a: Rec) => {
          const { data, ids, orgId } = a as { data: Rec; ids: string[]; orgId: string }
          if (ids.length > 100) return err('LIMIT_EXCEEDED', `${table}:bulkUpdate`)
          await requireOrgRole({ db: c.db, minRole: 'admin', orgId, userId: c.user._id as string })
          const results: Rec[] = []
          for (const id of ids) {
            const doc = await c.db.get(id)
            if (doc?.orgId !== orgId) continue
            const now = time()
            await cleanFiles({ doc, fileFields: fileFs, next: data, storage: c.storage })
            await dbPatch(c.db, id, { ...data, ...now })
            results.push({ ...doc, ...data, ...now })
          }
          return results
        })
      }),
      bulkRm = m({
        args: { ...orgIdArg, ids: bulkIdsSchema },
        handler: typed(async (c: MutCtx, a: Rec) => {
          const { ids, orgId } = a as { ids: string[]; orgId: string }
          if (ids.length > 100) return err('LIMIT_EXCEEDED', `${table}:bulkRm`)
          await requireOrgRole({ db: c.db, minRole: 'admin', orgId, userId: c.user._id as string })
          let deleted = 0
          for (const id of ids) {
            const doc = await c.db.get(id)
            if (doc?.orgId !== orgId) continue
            if (softDel) await dbPatch(c.db, id, { deletedAt: Date.now() })
            else {
              await cascadeDelete(c.db, id)
              await dbDelete(c.db, id)
              await cleanFiles({ doc, fileFields: fileFs, storage: c.storage })
            }
            deleted += 1
          }
          return deleted
        })
      }),
      restore = softDel
        ? m({
            args: { ...orgIdArg, ...idArgs },
            handler: typed(async (c: MutCtx, { id, orgId }: { id: string; orgId: string }) => {
              const { role } = await requireOrgMember({ db: c.db, orgId, userId: c.user._id as string }),
                doc = requireOrgDoc(await c.db.get(id), orgId),
                aclDoc = await resolveAclDoc(c.db, doc, opt)
              if (
                !canEdit({
                  acl: useAcl,
                  doc: aclDoc as { editors?: string[]; userId: string },
                  role,
                  userId: c.user._id as string
                })
              )
                return err('FORBIDDEN', `${table}:restore`)
              await dbPatch(c.db, id, { deletedAt: undefined, ...time() })
              return { ...doc, deletedAt: undefined }
            })
          })
        : undefined,
      base = { bulkRm, bulkUpdate, create, list, read, restore, rm, update },
      itemIdKey = `${table}Id` as const,
      itemIdArg = { [itemIdKey]: zid(table) },
      aclArgs = (a: unknown) => {
        const args = a as Rec
        return {
          editorId: args.editorId as string,
          editorIds: args.editorIds as string[] | undefined,
          itemId: args[itemIdKey] as string,
          orgId: args.orgId as string
        }
      },
      addEditor = m({
        args: { editorId: zid('users'), ...orgIdArg, ...itemIdArg },
        handler: typed(async (c: MutCtx, a: Rec) => {
          const { editorId, itemId, orgId } = aclArgs(a)
          await requireOrgRole({ db: c.db, minRole: 'admin', orgId, userId: c.user._id as string })
          const doc = requireOrgDoc(await c.db.get(itemId), orgId),
            editorIsOwner = (await c.db.get(orgId))?.userId === editorId,
            editorMember = await getOrgMember({ db: c.db, orgId, userId: editorId })
          if (!(editorIsOwner || editorMember)) return err('NOT_ORG_MEMBER')
          const eds = getEditors(doc),
            already = eds.some((eid: string) => eid === editorId)
          if (already) return doc
          if (eds.length >= 100) return err('LIMIT_EXCEEDED')
          const now = time(),
            patch = { editors: [...eds, editorId], ...now }
          await dbPatch(c.db, itemId, patch)
          return { ...doc, ...patch }
        })
      }),
      removeEditor = m({
        args: { editorId: zid('users'), ...orgIdArg, ...itemIdArg },
        handler: typed(async (c: MutCtx, a: Rec) => {
          const { editorId, itemId, orgId } = aclArgs(a)
          await requireOrgRole({ db: c.db, minRole: 'admin', orgId, userId: c.user._id as string })
          const doc = requireOrgDoc(await c.db.get(itemId), orgId),
            eds = getEditors(doc),
            filtered = eds.filter((eid: string) => eid !== editorId),
            now = time(),
            patch = { editors: filtered, ...now }
          await dbPatch(c.db, itemId, patch)
          return { ...doc, ...patch }
        })
      }),
      editors = q({
        args: { ...orgIdArg, ...itemIdArg },
        handler: typed(async (c: MutCtx, a: Rec) => {
          const { itemId, orgId } = aclArgs(a)
          await requireOrgMember({ db: c.db, orgId, userId: c.user._id as string })
          const doc = requireOrgDoc(await c.db.get(itemId), orgId),
            editorIds = getEditors(doc),
            users = await Promise.all(editorIds.map(async (eid: string) => c.db.get(eid))),
            result: { email: string; name: string; userId: string }[] = []
          for (let i = 0; i < editorIds.length; i += 1) {
            const u = users[i] as null | Rec,
              eid = editorIds[i]
            if (u && eid) result.push({ email: (u.email as string) ?? '', name: (u.name as string) ?? '', userId: eid })
          }
          return result
        })
      }),
      setEditors = m({
        args: { editorIds: array(zid('users')).max(BULK_MAX), ...orgIdArg, ...itemIdArg },
        handler: typed(async (c: MutCtx, a: Rec) => {
          const { editorIds, itemId, orgId } = aclArgs(a)
          await requireOrgRole({ db: c.db, minRole: 'admin', orgId, userId: c.user._id as string })
          const doc = requireOrgDoc(await c.db.get(itemId), orgId)
          if (editorIds)
            for (const editorId of editorIds) {
              const isOwner = (await c.db.get(orgId))?.userId === editorId,
                member = await getOrgMember({ db: c.db, orgId, userId: editorId })
              if (!(isOwner || member)) return err('NOT_ORG_MEMBER')
            }
          const now = time(),
            patch = { editors: editorIds ?? [], ...now }
          await dbPatch(c.db, itemId, patch)
          return { ...doc, ...patch }
        })
      })
    return { ...base, addEditor, editors, removeEditor, setEditors } as unknown as OrgCrudResult<S>
  },
  orgCascade = <S extends ZodRawShape>(
    _schema: ZodObject<S>,
    config: { foreignKey: keyof S & string; table: string }
  ): CascadeOption => config

export type { OrgCrudOptions }
export { canEdit, getOrgMember, getOrgRole, makeOrgCrud, orgCascade, requireOrgMember, requireOrgRole }
