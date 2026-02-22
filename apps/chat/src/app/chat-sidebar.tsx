'use client'

import { Button } from '@a/ui/button'
import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem
} from '@a/ui/sidebar'
import { GlobeIcon, MessageSquareIcon, MessageSquarePlusIcon, Trash2Icon } from 'lucide-react'
import Link from 'next/link'
import { useParams, useRouter } from 'next/navigation'

interface ChatSidebarProps<T extends Thread> {
  basePath: string
  getTitle?: (thread: T) => string
  onDelete: (threadId: string) => Promise<void>
  threads: T[]
}

interface Thread {
  _id: string
  title?: string
}

const ChatSidebar = <T extends Thread>({ basePath, getTitle, onDelete, threads }: ChatSidebarProps<T>) => {
  const router = useRouter(),
    params = useParams(),
    rootPath = basePath || '/',
    handleDelete = async (e: React.KeyboardEvent | React.MouseEvent, threadId: string) => {
      e.stopPropagation()
      await onDelete(threadId)
      if (params.id === threadId) router.push(rootPath)
    }
  return (
    <Sidebar side='left'>
      <SidebarHeader className='gap-2'>
        <Link href={rootPath}>
          <Button className='w-full' data-testid='new-chat-button'>
            <MessageSquarePlusIcon className='mr-2 size-4' />
            New Chat
          </Button>
        </Link>
        <Link href='/public'>
          <Button className='w-full' data-testid='public-chats-button' variant='outline'>
            <GlobeIcon className='mr-2 size-4' />
            Public Chats
          </Button>
        </Link>
      </SidebarHeader>
      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel>Conversations</SidebarGroupLabel>
          <SidebarMenu data-testid='thread-list'>
            {threads.map(t => (
              <SidebarMenuItem data-testid='thread-item' key={t._id}>
                <SidebarMenuButton
                  className='group/item'
                  isActive={params.id === t._id}
                  onClick={() => router.push(`${basePath}/${t._id}`)}>
                  <MessageSquareIcon className='size-4' />
                  <span className='flex-1 truncate'>{getTitle ? getTitle(t) : (t.title ?? 'Untitled')}</span>
                  <span
                    className='flex size-6 cursor-pointer items-center justify-center rounded-sm opacity-0 transition-opacity group-hover/item:opacity-100 hover:bg-accent'
                    data-testid='delete-thread-button'
                    // eslint-disable-next-line @typescript-eslint/strict-void-return
                    onClick={async e => handleDelete(e, t._id)}
                    // eslint-disable-next-line @typescript-eslint/strict-void-return
                    onKeyDown={async e => e.key === 'Enter' && handleDelete(e, t._id)}
                    role='button'
                    tabIndex={0}>
                    <Trash2Icon className='size-3' />
                  </span>
                </SidebarMenuButton>
              </SidebarMenuItem>
            ))}
          </SidebarMenu>
        </SidebarGroup>
      </SidebarContent>
    </Sidebar>
  )
}

export default ChatSidebar
