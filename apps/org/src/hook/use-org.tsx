'use client'

import { api } from '@a/be'
import { createOrgHooks } from 'lazyconvex/react'

export const { useActiveOrg, useMyOrgs, useOrg } = createOrgHooks(api.org)
