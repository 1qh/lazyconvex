'use client'
import type { OrgRole } from 'lazyconvex'

import { OrgAvatar, RoleBadge } from 'lazyconvex/components'
import { setActiveOrgCookieClient } from 'lazyconvex/react'
import { useRouter } from 'next/navigation'

interface OrgItem {
  avatarId?: null | string
  id: string
  name: string
  role: OrgRole
  slug: string
}

const OrgList = ({ orgs }: { orgs: OrgItem[] }) => {
  const router = useRouter()
  return (
    <div className='grid gap-4 md:grid-cols-2 lg:grid-cols-3'>
      {orgs.map(o => (
        <button
          className='flex items-center gap-3 rounded-lg border p-4 text-left transition-colors hover:bg-muted'
          key={o.id}
          onClick={() => {
            setActiveOrgCookieClient({ orgId: o.id, slug: o.slug })
            router.push('/dashboard')
          }}
          type='button'>
          <OrgAvatar name={o.name} size='lg' src={o.avatarId ? `/api/image?id=${o.avatarId}` : undefined} />
          <div className='flex-1'>
            <div className='font-medium'>{o.name}</div>
            <div className='text-sm text-muted-foreground'>/{o.slug}</div>
          </div>
          <RoleBadge role={o.role} />
        </button>
      ))}
    </div>
  )
}

export default OrgList
