'use client'

import { useOrg } from '~/hook/use-org'

import InviteDialog from './invite-dialog'
import JoinRequests from './join-requests'
import MemberList from './member-list'
import PendingInvites from './pending-invites'

const MembersPage = () => {
  const { canManageMembers, org } = useOrg()
  return (
    <div className='space-y-6'>
      <div className='flex items-center justify-between'>
        <h1 className='text-2xl font-bold'>Members</h1>
        {canManageMembers ? <InviteDialog orgId={org._id} /> : null}
      </div>
      <MemberList />
      {canManageMembers ? <PendingInvites /> : null}
      {canManageMembers ? <JoinRequests /> : null}
    </div>
  )
}

export default MembersPage
