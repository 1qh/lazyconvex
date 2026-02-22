/* eslint-disable max-statements */
// oxlint-disable promise/prefer-await-to-then
// biome-ignore-all lint/performance/noAwaitInLoops: test fixtures
import { describe, expect, test } from 'bun:test'
import { convexTest } from 'convex-test'

import { api } from './_generated/api'
import schema from './schema'

type TestCtx = ReturnType<typeof t>
const modules = {
    '../lazy.ts': async () => import('../lazy'),
    '../models.mock.ts': async () => import('../models.mock'),
    './_generated/api.js': async () => import('./_generated/api'),
    './_generated/server.js': async () => import('./_generated/server'),
    './auth.config.ts': async () => import('./auth.config'),
    './auth.ts': async () => import('./auth'),
    './blog.ts': async () => import('./blog'),
    './blogprofile.ts': async () => import('./blogprofile'),
    './chat.ts': async () => import('./chat'),
    './file.ts': async () => import('./file'),
    './http.ts': async () => import('./http'),
    './message.ts': async () => import('./message'),
    './movie.ts': async () => import('./movie'),
    './org.ts': async () => import('./org'),
    './orgprofile.ts': async () => import('./orgprofile'),
    './project.ts': async () => import('./project'),
    './schema.ts': async () => import('./schema'),
    './task.ts': async () => import('./task'),
    './testauth.ts': async () => import('./testauth'),
    './tools/weather.ts': async () => import('./tools/weather'),
    './user.ts': async () => import('./user'),
    './wiki.ts': async () => import('./wiki')
  },
  t = () => convexTest(schema, modules),
  mockUser = { email: 'owner@example.com', name: 'Owner User' },
  mockUser2 = { email: 'member@example.com', name: 'Member User' },
  mockUser3 = { email: 'third@example.com', name: 'Third User' },
  createUser = async (ctx: TestCtx, user: { email: string; name: string }) =>
    ctx.run(async c => {
      const existing = await c.db
        .query('users')
        .filter(q => q.eq(q.field('email'), user.email))
        .first()
      if (existing) return existing._id
      return c.db.insert('users', { ...user, emailVerificationTime: Date.now() })
    }),
  asIdentity = (ctx: TestCtx, userId: string) => ctx.withIdentity({ subject: userId, tokenIdentifier: `test|${userId}` }),
  // eslint-disable-next-line @typescript-eslint/max-params
  createOrg = async (ctx: TestCtx, userId: string, slug: string, name?: string) =>
    ctx.run(async c =>
      c.db.insert('org', { name: name ?? `${slug} org`, slug, updatedAt: Date.now(), userId: userId as never })
    ),
  // eslint-disable-next-line @typescript-eslint/max-params
  addMember = async (ctx: TestCtx, orgId: string, userId: string, isAdmin = false) =>
    ctx.run(async c =>
      c.db.insert('orgMember', { isAdmin, orgId: orgId as never, updatedAt: Date.now(), userId: userId as never })
    )

describe('org management', () => {
  describe('org.create', () => {
    test('creates org with valid data', async () => {
      const ctx = t(),
        userId = await createUser(ctx, mockUser),
        asUser = asIdentity(ctx, userId),
        result = await asUser.mutation(api.org.create, { data: { name: 'My Org', slug: 'my-org' } })
      expect(result).toHaveProperty('orgId')

      const orgDoc = await ctx.run(async c => c.db.get(result.orgId))
      expect(orgDoc).not.toBeNull()
      expect((orgDoc as Record<string, unknown>).name).toBe('My Org')
      expect((orgDoc as Record<string, unknown>).slug).toBe('my-org')
      expect((orgDoc as Record<string, unknown>).userId).toBe(userId)
    })

    test('rejects duplicate slug', async () => {
      const ctx = t(),
        userId = await createUser(ctx, mockUser)
      await createOrg(ctx, userId, 'taken-slug')

      const asUser = asIdentity(ctx, userId)
      let threw = false
      try {
        await asUser.mutation(api.org.create, { data: { name: 'Another', slug: 'taken-slug' } })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('ORG_SLUG_TAKEN')
      }
      expect(threw).toBe(true)
    })

    test('requires authentication', async () => {
      const ctx = t()
      let threw = false
      try {
        await ctx.mutation(api.org.create, { data: { name: 'No Auth', slug: 'no-auth' } })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('NOT_AUTHENTICATED')
      }
      expect(threw).toBe(true)
    })
  })

  describe('org.update', () => {
    test('admin can update org name', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        orgId = await createOrg(ctx, ownerId, 'update-test'),
        asOwner = asIdentity(ctx, ownerId)
      await asOwner.mutation(api.org.update, { data: { name: 'Updated Name' }, orgId })

      const orgDoc = await ctx.run(async c => c.db.get(orgId))
      expect((orgDoc as Record<string, unknown>).name).toBe('Updated Name')
    })

    test('admin member can update org', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        adminId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'admin-update')
      await addMember(ctx, orgId, adminId, true)

      const asAdmin = asIdentity(ctx, adminId)
      await asAdmin.mutation(api.org.update, { data: { name: 'Admin Updated' }, orgId })

      const orgDoc = await ctx.run(async c => c.db.get(orgId))
      expect((orgDoc as Record<string, unknown>).name).toBe('Admin Updated')
    })

    test('regular member cannot update org', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        memberId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'member-update')
      await addMember(ctx, orgId, memberId)

      const asMember = asIdentity(ctx, memberId)
      let threw = false
      try {
        await asMember.mutation(api.org.update, { data: { name: 'Member Try' }, orgId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('INSUFFICIENT_ORG_ROLE')
      }
      expect(threw).toBe(true)
    })

    test('rejects slug update to taken slug', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        orgId = await createOrg(ctx, ownerId, 'slug-a')
      await createOrg(ctx, ownerId, 'slug-b')

      const asOwner = asIdentity(ctx, ownerId)
      let threw = false
      try {
        await asOwner.mutation(api.org.update, { data: { slug: 'slug-b' }, orgId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('ORG_SLUG_TAKEN')
      }
      expect(threw).toBe(true)
    })

    test('allows updating slug to own slug', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        orgId = await createOrg(ctx, ownerId, 'same-slug'),
        asOwner = asIdentity(ctx, ownerId)
      await asOwner.mutation(api.org.update, { data: { slug: 'same-slug' }, orgId })

      const orgDoc = await ctx.run(async c => c.db.get(orgId))
      expect((orgDoc as Record<string, unknown>).slug).toBe('same-slug')
    })
  })

  describe('org.get', () => {
    test('member can get org', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        memberId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'get-test')
      await addMember(ctx, orgId, memberId)

      const asMember = asIdentity(ctx, memberId),
        org = await asMember.query(api.org.get, { orgId })
      expect(org).not.toBeNull()
      expect((org as Record<string, unknown>).slug).toBe('get-test')
    })

    test('owner can get org', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        orgId = await createOrg(ctx, ownerId, 'owner-get'),
        asOwner = asIdentity(ctx, ownerId),
        org = await asOwner.query(api.org.get, { orgId })
      expect(org).not.toBeNull()
    })

    test('non-member cannot get org', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        outsiderId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'no-access'),
        asOutsider = asIdentity(ctx, outsiderId)
      let threw = false
      try {
        await asOutsider.query(api.org.get, { orgId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('NOT_ORG_MEMBER')
      }
      expect(threw).toBe(true)
    })
  })

  describe('org.getBySlug', () => {
    test('returns org by slug (public)', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser)
      await createOrg(ctx, ownerId, 'by-slug-test', 'Slug Test')

      const org = await ctx.query(api.org.getBySlug, { slug: 'by-slug-test' })
      expect(org).not.toBeNull()
      expect((org as Record<string, unknown>).name).toBe('Slug Test')
    })

    test('returns null for non-existent slug', async () => {
      const ctx = t(),
        org = await ctx.query(api.org.getBySlug, { slug: 'does-not-exist' })
      expect(org).toBeNull()
    })
  })

  describe('org.getPublic', () => {
    test('returns limited fields', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser)
      await createOrg(ctx, ownerId, 'public-test', 'Public Org')

      const org = await ctx.query(api.org.getPublic, { slug: 'public-test' })
      expect(org).not.toBeNull()
      expect((org as Record<string, unknown>).name).toBe('Public Org')
      expect((org as Record<string, unknown>).slug).toBe('public-test')
      expect((org as Record<string, unknown>)._id).toBeDefined()
      expect((org as Record<string, unknown>).userId).toBeUndefined()
    })

    test('returns null for non-existent slug', async () => {
      const ctx = t(),
        org = await ctx.query(api.org.getPublic, { slug: 'nope-nope' })
      expect(org).toBeNull()
    })
  })

  describe('org.myOrgs', () => {
    test('lists owned orgs', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser)
      await createOrg(ctx, ownerId, 'owned-org')

      const asOwner = asIdentity(ctx, ownerId),
        orgs = await asOwner.query(api.org.myOrgs, {})
      expect(orgs.length).toBeGreaterThanOrEqual(1)
      const found = orgs.find((o: Record<string, unknown>) => (o.org as Record<string, unknown>).slug === 'owned-org')
      expect(found).toBeDefined()
      expect((found as Record<string, unknown>).role).toBe('owner')
    })

    test('lists member orgs with correct role', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        memberId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'member-list')
      await addMember(ctx, orgId, memberId)

      const asMember = asIdentity(ctx, memberId),
        orgs = await asMember.query(api.org.myOrgs, {}),
        found = orgs.find((o: Record<string, unknown>) => (o.org as Record<string, unknown>).slug === 'member-list')
      expect(found).toBeDefined()
      expect((found as Record<string, unknown>).role).toBe('member')
    })

    test('admin member gets admin role', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        adminId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'admin-role')
      await addMember(ctx, orgId, adminId, true)

      const asAdmin = asIdentity(ctx, adminId),
        orgs = await asAdmin.query(api.org.myOrgs, {}),
        found = orgs.find((o: Record<string, unknown>) => (o.org as Record<string, unknown>).slug === 'admin-role')
      expect(found).toBeDefined()
      expect((found as Record<string, unknown>).role).toBe('admin')
    })
  })

  describe('org.remove', () => {
    test('owner can remove org', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        orgId = await createOrg(ctx, ownerId, 'remove-me'),
        asOwner = asIdentity(ctx, ownerId)
      await asOwner.mutation(api.org.remove, { orgId })

      const orgDoc = await ctx.run(async c => c.db.get(orgId))
      expect(orgDoc).toBeNull()
    })

    test('non-owner cannot remove org', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        memberId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'no-remove')
      await addMember(ctx, orgId, memberId, true)

      const asMember = asIdentity(ctx, memberId)
      let threw = false
      try {
        await asMember.mutation(api.org.remove, { orgId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('FORBIDDEN')
      }
      expect(threw).toBe(true)
    })

    test('remove cascades members, invites, and join requests', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        memberId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'cascade-rm')
      await addMember(ctx, orgId, memberId)

      await ctx.run(async c => {
        await c.db.insert('orgInvite', {
          email: 'invite@test.com',
          expiresAt: Date.now() + 86_400_000,
          isAdmin: false,
          orgId,
          token: 'test-token-cascade'
        })
        await c.db.insert('orgJoinRequest', { message: 'hi', orgId, status: 'pending', userId: memberId })
      })

      const asOwner = asIdentity(ctx, ownerId)
      await asOwner.mutation(api.org.remove, { orgId })

      const remaining = await ctx.run(async c => {
        const ms = await c.db.query('orgMember').collect(),
          invs = await c.db.query('orgInvite').collect(),
          jrs = await c.db.query('orgJoinRequest').collect()
        return { invites: invs.length, joinRequests: jrs.length, members: ms.length }
      })
      expect(remaining.members).toBe(0)
      expect(remaining.invites).toBe(0)
      expect(remaining.joinRequests).toBe(0)
    })

    test('remove cascades orgCascadeTables (task, project)', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        orgId = await createOrg(ctx, ownerId, 'cascade-tables')

      await ctx.run(async c => {
        const projectId = await c.db.insert('project', {
          name: 'Test Project',
          orgId,
          updatedAt: Date.now(),
          userId: ownerId
        })
        await c.db.insert('task', {
          orgId,
          projectId,
          title: 'Test Task',
          updatedAt: Date.now(),
          userId: ownerId
        })
      })

      const asOwner = asIdentity(ctx, ownerId)
      await asOwner.mutation(api.org.remove, { orgId })

      const remaining = await ctx.run(async c => {
        const ps = await c.db.query('project').collect(),
          ts = await c.db.query('task').collect()
        return { projects: ps.length, tasks: ts.length }
      })
      expect(remaining.projects).toBe(0)
      expect(remaining.tasks).toBe(0)
    })
  })

  describe('org.isSlugAvailable', () => {
    test('returns available: true for unused slug', async () => {
      const ctx = t(),
        result = await ctx.query(api.org.isSlugAvailable, { slug: 'fresh-slug' })
      expect(result.available).toBe(true)
    })

    test('returns available: false for taken slug', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser)
      await createOrg(ctx, ownerId, 'taken-check')

      const result = await ctx.query(api.org.isSlugAvailable, { slug: 'taken-check' })
      expect(result.available).toBe(false)
    })
  })
})

describe('org members', () => {
  describe('org.membership', () => {
    test('returns owner role for org creator', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        orgId = await createOrg(ctx, ownerId, 'membership-owner'),
        asOwner = asIdentity(ctx, ownerId),
        result = await asOwner.query(api.org.membership, { orgId })
      expect(result).not.toBeNull()
      expect((result as Record<string, unknown>).role).toBe('owner')
    })

    test('returns member role', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        memberId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'membership-member')
      await addMember(ctx, orgId, memberId)

      const asMember = asIdentity(ctx, memberId),
        result = await asMember.query(api.org.membership, { orgId })
      expect(result).not.toBeNull()
      expect((result as Record<string, unknown>).role).toBe('member')
    })

    test('returns admin role', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        adminId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'membership-admin')
      await addMember(ctx, orgId, adminId, true)

      const asAdmin = asIdentity(ctx, adminId),
        result = await asAdmin.query(api.org.membership, { orgId })
      expect(result).not.toBeNull()
      expect((result as Record<string, unknown>).role).toBe('admin')
    })

    test('returns null for non-member', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        outsiderId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'membership-none'),
        asOutsider = asIdentity(ctx, outsiderId),
        result = await asOutsider.query(api.org.membership, { orgId })
      expect(result).toBeNull()
    })
  })

  describe('org.members', () => {
    test('lists owner and members', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        memberId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'members-list')
      await addMember(ctx, orgId, memberId)

      const asOwner = asIdentity(ctx, ownerId),
        result = await asOwner.query(api.org.members, { orgId })
      expect(result.length).toBe(2)

      const ownerEntry = result.find(m => m.role === 'owner')
      expect(ownerEntry).toBeDefined()
      expect(ownerEntry?.userId).toBe(ownerId)

      const memberEntry = result.find(m => m.role === 'member')
      expect(memberEntry).toBeDefined()
      expect(memberEntry?.userId).toBe(memberId)
    })

    test('non-member cannot list members', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        outsiderId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'members-denied'),
        asOutsider = asIdentity(ctx, outsiderId)
      let threw = false
      try {
        await asOutsider.query(api.org.members, { orgId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('NOT_ORG_MEMBER')
      }
      expect(threw).toBe(true)
    })
  })

  describe('org.setAdmin', () => {
    test('owner can promote member to admin', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        memberId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'set-admin'),
        memberDocId = await addMember(ctx, orgId, memberId),
        asOwner = asIdentity(ctx, ownerId)
      await asOwner.mutation(api.org.setAdmin, { isAdmin: true, memberId: memberDocId })

      const doc = await ctx.run(async c => c.db.get(memberDocId))
      expect((doc as Record<string, unknown>).isAdmin).toBe(true)
    })

    test('owner can demote admin to member', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        adminId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'demote-admin'),
        memberDocId = await addMember(ctx, orgId, adminId, true),
        asOwner = asIdentity(ctx, ownerId)
      await asOwner.mutation(api.org.setAdmin, { isAdmin: false, memberId: memberDocId })

      const doc = await ctx.run(async c => c.db.get(memberDocId))
      expect((doc as Record<string, unknown>).isAdmin).toBe(false)
    })

    test('non-owner cannot setAdmin', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        adminId = await createUser(ctx, mockUser2),
        thirdId = await createUser(ctx, mockUser3),
        orgId = await createOrg(ctx, ownerId, 'set-admin-denied')
      await addMember(ctx, orgId, adminId, true)
      const thirdMemberId = await addMember(ctx, orgId, thirdId),
        asAdmin = asIdentity(ctx, adminId)
      let threw = false
      try {
        await asAdmin.mutation(api.org.setAdmin, { isAdmin: true, memberId: thirdMemberId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('FORBIDDEN')
      }
      expect(threw).toBe(true)
    })
  })

  describe('org.removeMember', () => {
    test('admin can remove regular member', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        memberId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'rm-member'),
        memberDocId = await addMember(ctx, orgId, memberId),
        asOwner = asIdentity(ctx, ownerId)
      await asOwner.mutation(api.org.removeMember, { memberId: memberDocId })

      const doc = await ctx.run(async c => c.db.get(memberDocId))
      expect(doc).toBeNull()
    })

    test('cannot remove org owner', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        adminId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'rm-owner-fail'),
        ownerMemberId = await addMember(ctx, orgId, ownerId)
      await addMember(ctx, orgId, adminId, true)

      const asAdmin = asIdentity(ctx, adminId)
      let threw = false
      try {
        await asAdmin.mutation(api.org.removeMember, { memberId: ownerMemberId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('CANNOT_MODIFY_OWNER')
      }
      expect(threw).toBe(true)
    })

    test('admin cannot remove another admin', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        admin1Id = await createUser(ctx, mockUser2),
        admin2Id = await createUser(ctx, mockUser3),
        orgId = await createOrg(ctx, ownerId, 'rm-admin-fail')
      await addMember(ctx, orgId, admin1Id, true)
      const admin2DocId = await addMember(ctx, orgId, admin2Id, true),
        asAdmin1 = asIdentity(ctx, admin1Id)
      let threw = false
      try {
        await asAdmin1.mutation(api.org.removeMember, { memberId: admin2DocId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('CANNOT_MODIFY_ADMIN')
      }
      expect(threw).toBe(true)
    })

    test('owner can remove admin', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        adminId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'owner-rm-admin'),
        adminDocId = await addMember(ctx, orgId, adminId, true),
        asOwner = asIdentity(ctx, ownerId)
      await asOwner.mutation(api.org.removeMember, { memberId: adminDocId })

      const doc = await ctx.run(async c => c.db.get(adminDocId))
      expect(doc).toBeNull()
    })
  })

  describe('org.leave', () => {
    test('member can leave org', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        memberId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'leave-org')
      await addMember(ctx, orgId, memberId)

      const asMember = asIdentity(ctx, memberId)
      await asMember.mutation(api.org.leave, { orgId })

      const members = await ctx.run(async c =>
        c.db
          .query('orgMember')
          .filter(q => q.eq(q.field('orgId'), orgId))
          .collect()
      )
      expect(members.length).toBe(0)
    })

    test('owner cannot leave (must transfer first)', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        orgId = await createOrg(ctx, ownerId, 'owner-leave'),
        asOwner = asIdentity(ctx, ownerId)

      let threw = false
      try {
        await asOwner.mutation(api.org.leave, { orgId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('MUST_TRANSFER_OWNERSHIP')
      }
      expect(threw).toBe(true)
    })
  })

  describe('org.transferOwnership', () => {
    test('owner can transfer to admin', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        adminId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'transfer-test')
      await addMember(ctx, orgId, adminId, true)

      const asOwner = asIdentity(ctx, ownerId)
      await asOwner.mutation(api.org.transferOwnership, { newOwnerId: adminId, orgId })

      const orgDoc = await ctx.run(async c => c.db.get(orgId))
      expect((orgDoc as Record<string, unknown>).userId).toBe(adminId)

      const oldOwnerMember = await ctx.run(async c =>
        c.db
          .query('orgMember')
          .filter(q => q.eq(q.field('userId'), ownerId))
          .first()
      )
      expect(oldOwnerMember).not.toBeNull()
    })

    test('non-owner cannot transfer', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        adminId = await createUser(ctx, mockUser2),
        thirdId = await createUser(ctx, mockUser3),
        orgId = await createOrg(ctx, ownerId, 'transfer-deny')
      await addMember(ctx, orgId, adminId, true)
      await addMember(ctx, orgId, thirdId)

      const asAdmin = asIdentity(ctx, adminId)
      let threw = false
      try {
        await asAdmin.mutation(api.org.transferOwnership, { newOwnerId: thirdId, orgId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('FORBIDDEN')
      }
      expect(threw).toBe(true)
    })

    test('cannot transfer to non-admin member', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        memberId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'transfer-non-admin')
      await addMember(ctx, orgId, memberId)

      const asOwner = asIdentity(ctx, ownerId)
      let threw = false
      try {
        await asOwner.mutation(api.org.transferOwnership, { newOwnerId: memberId, orgId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('TARGET_MUST_BE_ADMIN')
      }
      expect(threw).toBe(true)
    })
  })
})

describe('org invites', () => {
  describe('org.invite', () => {
    test('admin can create invite', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        orgId = await createOrg(ctx, ownerId, 'invite-org'),
        asOwner = asIdentity(ctx, ownerId),
        result = await asOwner.mutation(api.org.invite, { email: 'invited@test.com', isAdmin: false, orgId })
      expect(result).toHaveProperty('token')
      expect(result).toHaveProperty('inviteId')
      expect(typeof result.token).toBe('string')
      expect(result.token.length).toBeGreaterThan(0)
    })

    test('regular member cannot invite', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        memberId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'invite-denied')
      await addMember(ctx, orgId, memberId)

      const asMember = asIdentity(ctx, memberId)
      let threw = false
      try {
        await asMember.mutation(api.org.invite, { email: 'nope@test.com', isAdmin: false, orgId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('INSUFFICIENT_ORG_ROLE')
      }
      expect(threw).toBe(true)
    })
  })

  describe('org.acceptInvite', () => {
    test('valid token adds user as member', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        inviteeId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'accept-invite'),
        token = 'valid-accept-token'
      await ctx.run(async c => {
        await c.db.insert('orgInvite', {
          email: mockUser2.email,
          expiresAt: Date.now() + 86_400_000,
          isAdmin: false,
          orgId,
          token
        })
      })

      const asInvitee = asIdentity(ctx, inviteeId),
        result = await asInvitee.mutation(api.org.acceptInvite, { token })
      expect(result).toHaveProperty('orgId')

      const memberDoc = await ctx.run(async c =>
        c.db
          .query('orgMember')
          .filter(q => q.eq(q.field('userId'), inviteeId))
          .first()
      )
      expect(memberDoc).not.toBeNull()
    })

    test('expired token is rejected', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        inviteeId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'expired-invite'),
        token = 'expired-token'
      await ctx.run(async c => {
        await c.db.insert('orgInvite', {
          email: mockUser2.email,
          expiresAt: Date.now() - 1000,
          isAdmin: false,
          orgId,
          token
        })
      })

      const asInvitee = asIdentity(ctx, inviteeId)
      let threw = false
      try {
        await asInvitee.mutation(api.org.acceptInvite, { token })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('INVITE_EXPIRED')
      }
      expect(threw).toBe(true)
    })

    test('already member gets ALREADY_ORG_MEMBER', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        memberId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'already-member')
      await addMember(ctx, orgId, memberId)

      const token = 'already-member-token'
      await ctx.run(async c => {
        await c.db.insert('orgInvite', {
          email: mockUser2.email,
          expiresAt: Date.now() + 86_400_000,
          isAdmin: false,
          orgId,
          token
        })
      })

      const asMember = asIdentity(ctx, memberId)
      let threw = false
      try {
        await asMember.mutation(api.org.acceptInvite, { token })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('ALREADY_ORG_MEMBER')
      }
      expect(threw).toBe(true)
    })

    test('invalid token is rejected', async () => {
      const ctx = t(),
        userId = await createUser(ctx, mockUser),
        asUser = asIdentity(ctx, userId)
      let threw = false
      try {
        await asUser.mutation(api.org.acceptInvite, { token: 'nonexistent-token' })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('INVALID_INVITE')
      }
      expect(threw).toBe(true)
    })

    test('invite with isAdmin: true creates admin member', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        inviteeId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'admin-invite'),
        token = 'admin-invite-token'
      await ctx.run(async c => {
        await c.db.insert('orgInvite', {
          email: mockUser2.email,
          expiresAt: Date.now() + 86_400_000,
          isAdmin: true,
          orgId,
          token
        })
      })

      const asInvitee = asIdentity(ctx, inviteeId)
      await asInvitee.mutation(api.org.acceptInvite, { token })

      const memberDoc = await ctx.run(async c =>
        c.db
          .query('orgMember')
          .filter(q => q.eq(q.field('userId'), inviteeId))
          .first()
      )
      expect(memberDoc).not.toBeNull()
      expect((memberDoc as Record<string, unknown>).isAdmin).toBe(true)
    })
  })

  describe('org.revokeInvite', () => {
    test('admin can revoke invite', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        orgId = await createOrg(ctx, ownerId, 'revoke-invite'),
        inviteId = await ctx.run(async c =>
          c.db.insert('orgInvite', {
            email: 'revoke@test.com',
            expiresAt: Date.now() + 86_400_000,
            isAdmin: false,
            orgId,
            token: 'revoke-token'
          })
        ),
        asOwner = asIdentity(ctx, ownerId)
      await asOwner.mutation(api.org.revokeInvite, { inviteId })

      const doc = await ctx.run(async c => c.db.get(inviteId))
      expect(doc).toBeNull()
    })
  })

  describe('org.pendingInvites', () => {
    test('admin can list pending invites', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        orgId = await createOrg(ctx, ownerId, 'pending-invites')

      await ctx.run(async c => {
        await c.db.insert('orgInvite', {
          email: 'a@test.com',
          expiresAt: Date.now() + 86_400_000,
          isAdmin: false,
          orgId,
          token: 'token-a'
        })
        await c.db.insert('orgInvite', {
          email: 'b@test.com',
          expiresAt: Date.now() + 86_400_000,
          isAdmin: true,
          orgId,
          token: 'token-b'
        })
      })

      const asOwner = asIdentity(ctx, ownerId),
        invites = await asOwner.query(api.org.pendingInvites, { orgId })
      expect(invites.length).toBe(2)
    })
  })
})

describe('org join requests', () => {
  describe('org.requestJoin', () => {
    test('non-member can request to join', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        requesterId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'join-req'),
        asRequester = asIdentity(ctx, requesterId),
        result = await asRequester.mutation(api.org.requestJoin, { message: 'Please let me in', orgId })
      expect(result).toHaveProperty('requestId')
    })

    test('existing member cannot request join', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        memberId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'join-already-member')
      await addMember(ctx, orgId, memberId)

      const asMember = asIdentity(ctx, memberId)
      let threw = false
      try {
        await asMember.mutation(api.org.requestJoin, { orgId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('ALREADY_ORG_MEMBER')
      }
      expect(threw).toBe(true)
    })

    test('duplicate pending request is rejected', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        requesterId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'join-dup'),
        asRequester = asIdentity(ctx, requesterId)
      await asRequester.mutation(api.org.requestJoin, { orgId })

      let threw = false
      try {
        await asRequester.mutation(api.org.requestJoin, { orgId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('JOIN_REQUEST_EXISTS')
      }
      expect(threw).toBe(true)
    })
  })

  describe('org.approveJoinRequest', () => {
    test('admin can approve request (creates member)', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        requesterId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'approve-join'),
        requestId = await ctx.run(async c =>
          c.db.insert('orgJoinRequest', { orgId, status: 'pending', userId: requesterId })
        ),
        asOwner = asIdentity(ctx, ownerId)
      await asOwner.mutation(api.org.approveJoinRequest, { requestId })

      const memberDoc = await ctx.run(async c =>
        c.db
          .query('orgMember')
          .filter(q => q.eq(q.field('userId'), requesterId))
          .first()
      )
      expect(memberDoc).not.toBeNull()

      const requestDoc = await ctx.run(async c => c.db.get(requestId))
      expect((requestDoc as Record<string, unknown>).status).toBe('approved')
    })

    test('approve with isAdmin creates admin member', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        requesterId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'approve-admin'),
        requestId = await ctx.run(async c =>
          c.db.insert('orgJoinRequest', { orgId, status: 'pending', userId: requesterId })
        ),
        asOwner = asIdentity(ctx, ownerId)
      await asOwner.mutation(api.org.approveJoinRequest, { isAdmin: true, requestId })

      const memberDoc = await ctx.run(async c =>
        c.db
          .query('orgMember')
          .filter(q => q.eq(q.field('userId'), requesterId))
          .first()
      )
      expect((memberDoc as Record<string, unknown>).isAdmin).toBe(true)
    })
  })

  describe('org.rejectJoinRequest', () => {
    test('admin can reject request', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        requesterId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'reject-join'),
        requestId = await ctx.run(async c =>
          c.db.insert('orgJoinRequest', { orgId, status: 'pending', userId: requesterId })
        ),
        asOwner = asIdentity(ctx, ownerId)
      await asOwner.mutation(api.org.rejectJoinRequest, { requestId })

      const requestDoc = await ctx.run(async c => c.db.get(requestId))
      expect((requestDoc as Record<string, unknown>).status).toBe('rejected')
    })
  })

  describe('org.cancelJoinRequest', () => {
    test('requester can cancel own pending request', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        requesterId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'cancel-join'),
        requestId = await ctx.run(async c =>
          c.db.insert('orgJoinRequest', { orgId, status: 'pending', userId: requesterId })
        ),
        asRequester = asIdentity(ctx, requesterId)
      await asRequester.mutation(api.org.cancelJoinRequest, { requestId })

      const doc = await ctx.run(async c => c.db.get(requestId))
      expect(doc).toBeNull()
    })

    test('cannot cancel someone elses request', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        requesterId = await createUser(ctx, mockUser2),
        thirdId = await createUser(ctx, mockUser3),
        orgId = await createOrg(ctx, ownerId, 'cancel-other'),
        requestId = await ctx.run(async c =>
          c.db.insert('orgJoinRequest', { orgId, status: 'pending', userId: requesterId })
        ),
        asThird = asIdentity(ctx, thirdId)
      let threw = false
      try {
        await asThird.mutation(api.org.cancelJoinRequest, { requestId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('FORBIDDEN')
      }
      expect(threw).toBe(true)
    })

    test('cannot cancel non-pending request', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        requesterId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'cancel-approved'),
        requestId = await ctx.run(async c =>
          c.db.insert('orgJoinRequest', { orgId, status: 'approved', userId: requesterId })
        ),
        asRequester = asIdentity(ctx, requesterId)
      let threw = false
      try {
        await asRequester.mutation(api.org.cancelJoinRequest, { requestId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('NOT_FOUND')
      }
      expect(threw).toBe(true)
    })
  })

  describe('org.pendingJoinRequests', () => {
    test('admin can list pending requests', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        req1Id = await createUser(ctx, mockUser2),
        req2Id = await createUser(ctx, mockUser3),
        orgId = await createOrg(ctx, ownerId, 'pending-reqs')

      await ctx.run(async c => {
        await c.db.insert('orgJoinRequest', { message: 'hi', orgId, status: 'pending', userId: req1Id })
        await c.db.insert('orgJoinRequest', { orgId, status: 'pending', userId: req2Id })
      })

      const asOwner = asIdentity(ctx, ownerId),
        requests = await asOwner.query(api.org.pendingJoinRequests, { orgId })
      expect(requests.length).toBe(2)
      for (const r of requests) {
        expect(r).toHaveProperty('request')
        expect(r).toHaveProperty('user')
      }
    })

    test('regular member cannot list pending requests', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        memberId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'pending-denied')
      await addMember(ctx, orgId, memberId)

      const asMember = asIdentity(ctx, memberId)
      let threw = false
      try {
        await asMember.query(api.org.pendingJoinRequests, { orgId })
      } catch (error) {
        threw = true
        expect(String(error)).toContain('INSUFFICIENT_ORG_ROLE')
      }
      expect(threw).toBe(true)
    })
  })

  describe('org.myJoinRequest', () => {
    test('returns pending request for current user', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        requesterId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'my-join-req')

      await ctx.run(async c => {
        await c.db.insert('orgJoinRequest', { message: 'please', orgId, status: 'pending', userId: requesterId })
      })

      const asRequester = asIdentity(ctx, requesterId),
        result = await asRequester.query(api.org.myJoinRequest, { orgId })
      expect(result).not.toBeNull()
      expect((result as Record<string, unknown>).status).toBe('pending')
    })

    test('returns null when no pending request', async () => {
      const ctx = t(),
        ownerId = await createUser(ctx, mockUser),
        userId = await createUser(ctx, mockUser2),
        orgId = await createOrg(ctx, ownerId, 'no-join-req'),
        asUser = asIdentity(ctx, userId),
        result = await asUser.query(api.org.myJoinRequest, { orgId })
      expect(result).toBeNull()
    })
  })
})
