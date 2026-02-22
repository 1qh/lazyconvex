/* eslint-disable @typescript-eslint/no-unnecessary-type-parameters, @typescript-eslint/no-unsafe-return */
'use client'

import type { FunctionReference } from 'convex/server'
import type { ReactNode } from 'react'

import { useMutation, useQuery } from 'convex/react'
import { createContext, use, useCallback, useMemo, useState } from 'react'

import type { OrgRole } from '../server/types'

import { ACTIVE_ORG_COOKIE, ACTIVE_ORG_SLUG_COOKIE, ONE_YEAR_SECONDS } from '../constants'

type InferOrg<F> = F extends { _returnType: infer R } ? (NonNullable<R> extends OrgDoc ? NonNullable<R> : OrgDoc) : OrgDoc

interface OrgContextValue<O extends OrgDoc = OrgDoc, M = unknown> {
  canDeleteOrg: boolean
  canManageAdmins: boolean
  canManageMembers: boolean
  isAdmin: boolean
  isMember: boolean
  isOwner: boolean
  membership: M | null
  org: O
  orgId: string
  role: OrgRole
}

interface OrgDoc {
  [key: string]: unknown
  _id: string
  slug: string
}

const OrgContext = createContext<null | OrgContextValue>(null)

interface OrgProviderProps<O extends OrgDoc, M> {
  children: ReactNode
  membership: M | null
  org: O
  role: OrgRole
}

const OrgProvider = <O extends OrgDoc, M>({ children, membership, org, role }: OrgProviderProps<O, M>) => {
    const value = useMemo<OrgContextValue<O, M>>(() => {
      const isOwner = role === 'owner',
        isAdmin = role === 'owner' || role === 'admin'
      return {
        canDeleteOrg: isOwner,
        canManageAdmins: isOwner,
        canManageMembers: isAdmin,
        isAdmin,
        isMember: true,
        isOwner,
        membership,
        org,
        orgId: org._id,
        role
      }
    }, [membership, org, role])

    return <OrgContext value={value as OrgContextValue}>{children}</OrgContext>
  },
  useOrg = <O extends OrgDoc = OrgDoc, M = unknown>() => {
    const ctx = use(OrgContext)
    if (!ctx) throw new Error('useOrg must be used inside OrgProvider')
    return ctx as OrgContextValue<O, M>
  },
  useOrgQuery = <F extends FunctionReference<'query'>>(
    query: F,
    args?: 'skip' | Omit<F['_args'], 'orgId'>
  ): F['_returnType'] | undefined => {
    const { orgId } = useOrg()
    return useQuery(query as FunctionReference<'query'>, args === 'skip' ? 'skip' : { ...args, orgId })
  },
  useOrgMutation = <F extends FunctionReference<'mutation'>>(mutation: F) => {
    const { orgId } = useOrg(),
      mutate = useMutation(mutation as FunctionReference<'mutation'>)
    return useCallback(
      async (args?: Omit<F['_args'], 'orgId'>): Promise<F['_returnType']> => mutate({ ...args, orgId }),
      [mutate, orgId]
    )
  },
  canEditResource = ({
    editorsList,
    isAdmin,
    resource,
    userId
  }: {
    editorsList: { userId: string }[]
    isAdmin: boolean
    resource: { userId: string }
    userId: string
  }): boolean => isAdmin || resource.userId === userId || editorsList.some(e => e.userId === userId),
  useMyOrgs = <O extends OrgDoc>(myOrgsQuery: FunctionReference<'query'>) => {
    const data = useQuery(myOrgsQuery) as undefined | { org: O; role: OrgRole }[]
    return { isLoading: data === undefined, orgs: (data ?? []) as { org: O; role: OrgRole }[] }
  },
  COOKIE_PREFIX = `${ACTIVE_ORG_COOKIE}=`,
  getActiveOrgIdFromCookie = (): null | string => {
    if (typeof document === 'undefined') return null
    for (const c of document.cookie.split('; ')) if (c.startsWith(COOKIE_PREFIX)) return c.slice(COOKIE_PREFIX.length)
    return null
  },
  setActiveOrgCookieClient = ({ orgId, slug }: { orgId: string; slug: string }) => {
    const maxAge = ONE_YEAR_SECONDS
    document.cookie = `${ACTIVE_ORG_COOKIE}=${orgId}; path=/; max-age=${maxAge}`
    document.cookie = `${ACTIVE_ORG_SLUG_COOKIE}=${slug}; path=/; max-age=${maxAge}`
  },
  useActiveOrg = <O extends OrgDoc>(orgGetQuery: FunctionReference<'query'>) => {
    const [activeOrgId, setActiveOrgId] = useState<null | string>(getActiveOrgIdFromCookie),
      activeOrg = useQuery(orgGetQuery, activeOrgId ? { orgId: activeOrgId } : 'skip') as null | O | undefined,
      setActiveOrg = useCallback(
        (org: OrgDoc) => {
          setActiveOrgCookieClient({ orgId: org._id, slug: org.slug })
          setActiveOrgId(org._id)
        },
        [setActiveOrgId]
      ),
      clearActiveOrg = useCallback(() => {
        document.cookie = `${ACTIVE_ORG_COOKIE}=; path=/; max-age=0`
        document.cookie = `${ACTIVE_ORG_SLUG_COOKIE}=; path=/; max-age=0`
        setActiveOrgId(null)
      }, [setActiveOrgId])

    return {
      activeOrg: activeOrg ?? null,
      activeOrgId,
      clearActiveOrg,
      isLoading: activeOrgId ? activeOrg === undefined : false,
      setActiveOrg
    }
  },
  createOrgHooks = <F extends FunctionReference<'query'>, O extends OrgDoc = InferOrg<F>, M = unknown>(orgApi: {
    get: F
    myOrgs: FunctionReference<'query'>
  }) => ({
    useActiveOrg: () => useActiveOrg<O>(orgApi.get),
    useMyOrgs: () => useMyOrgs<O>(orgApi.myOrgs),
    useOrg: () => useOrg<O, M>()
  })

export type { OrgContextValue, OrgDoc, OrgProviderProps }
export {
  canEditResource,
  createOrgHooks,
  OrgProvider,
  setActiveOrgCookieClient,
  useActiveOrg,
  useMyOrgs,
  useOrg,
  useOrgMutation,
  useOrgQuery
}
