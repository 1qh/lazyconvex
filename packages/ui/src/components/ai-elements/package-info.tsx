// oxlint-disable import/exports-last, import/group-exports
'use client'

import type { HTMLAttributes } from 'react'

import { cn } from '@a/ui'
import { Badge } from '@a/ui/badge'
import { ArrowRightIcon, MinusIcon, PackageIcon, PlusIcon } from 'lucide-react'
import { createContext, use } from 'react'

type ChangeType = 'added' | 'major' | 'minor' | 'patch' | 'removed'

interface PackageInfoContextType {
  changeType?: ChangeType
  currentVersion?: string
  name: string
  newVersion?: string
}

const PackageInfoContext = createContext<PackageInfoContextType>({
  name: ''
})

export type PackageInfoHeaderProps = HTMLAttributes<HTMLDivElement>

export const PackageInfoHeader = ({ children, className, ...props }: PackageInfoHeaderProps) => (
  <div className={cn('flex items-center justify-between gap-2', className)} {...props}>
    {children}
  </div>
)

export type PackageInfoNameProps = HTMLAttributes<HTMLDivElement>

export const PackageInfoName = ({ children, className, ...props }: PackageInfoNameProps) => {
  const { name } = use(PackageInfoContext)

  return (
    <div className={cn('flex items-center gap-2', className)} {...props}>
      <PackageIcon className='size-4 text-muted-foreground' />
      <span className='font-mono text-sm font-medium'>{children ?? name}</span>
    </div>
  )
}

const changeTypeStyles: Record<ChangeType, string> = {
    added: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400',
    major: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400',
    minor: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400',
    patch: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
    removed: 'bg-gray-100 text-gray-700 dark:bg-gray-900/30 dark:text-gray-400'
  },
  changeTypeIcons: Record<ChangeType, React.ReactNode> = {
    added: <PlusIcon className='size-3' />,
    major: <ArrowRightIcon className='size-3' />,
    minor: <ArrowRightIcon className='size-3' />,
    patch: <ArrowRightIcon className='size-3' />,
    removed: <MinusIcon className='size-3' />
  }

export type PackageInfoChangeTypeProps = HTMLAttributes<HTMLDivElement>

export const PackageInfoChangeType = ({ children, className, ...props }: PackageInfoChangeTypeProps) => {
  const { changeType } = use(PackageInfoContext)

  if (!changeType) return null

  return (
    <Badge
      className={cn('gap-1 text-xs capitalize', changeTypeStyles[changeType], className)}
      variant='secondary'
      {...props}>
      {changeTypeIcons[changeType]}
      {children ?? changeType}
    </Badge>
  )
}

export type PackageInfoVersionProps = HTMLAttributes<HTMLDivElement>

export const PackageInfoVersion = ({ children, className, ...props }: PackageInfoVersionProps) => {
  const { currentVersion, newVersion } = use(PackageInfoContext)

  if (!(currentVersion || newVersion)) return null

  return (
    <div className={cn('mt-2 flex items-center gap-2 font-mono text-sm text-muted-foreground', className)} {...props}>
      {children ?? (
        <>
          {currentVersion ? <span>{currentVersion}</span> : null}
          {currentVersion && newVersion ? <ArrowRightIcon className='size-3' /> : null}
          {newVersion ? <span className='font-medium text-foreground'>{newVersion}</span> : null}
        </>
      )}
    </div>
  )
}

export type PackageInfoDescriptionProps = HTMLAttributes<HTMLParagraphElement>

export const PackageInfoDescription = ({ children, className, ...props }: PackageInfoDescriptionProps) => (
  <p className={cn('mt-2 text-sm text-muted-foreground', className)} {...props}>
    {children}
  </p>
)

export type PackageInfoContentProps = HTMLAttributes<HTMLDivElement>

export const PackageInfoContent = ({ children, className, ...props }: PackageInfoContentProps) => (
  <div className={cn('mt-3 border-t pt-3', className)} {...props}>
    {children}
  </div>
)

export type PackageInfoDependenciesProps = HTMLAttributes<HTMLDivElement>

export const PackageInfoDependencies = ({ children, className, ...props }: PackageInfoDependenciesProps) => (
  <div className={cn('space-y-2', className)} {...props}>
    <span className='text-xs font-medium tracking-wide text-muted-foreground uppercase'>Dependencies</span>
    <div className='space-y-1'>{children}</div>
  </div>
)

export type PackageInfoDependencyProps = HTMLAttributes<HTMLDivElement> & {
  name: string
  version?: string
}

export const PackageInfoDependency = ({ children, className, name, version, ...props }: PackageInfoDependencyProps) => (
  <div className={cn('flex items-center justify-between text-sm', className)} {...props}>
    {children ?? (
      <>
        <span className='font-mono text-muted-foreground'>{name}</span>
        {version ? <span className='font-mono text-xs'>{version}</span> : null}
      </>
    )}
  </div>
)

export type PackageInfoProps = HTMLAttributes<HTMLDivElement> & {
  changeType?: ChangeType
  currentVersion?: string
  name: string
  newVersion?: string
}

export const PackageInfo = ({
  changeType,
  children,
  className,
  currentVersion,
  name,
  newVersion,
  ...props
}: PackageInfoProps) => (
  <PackageInfoContext value={{ changeType, currentVersion, name, newVersion }}>
    <div className={cn('rounded-lg border bg-background p-4', className)} {...props}>
      {children ?? (
        <>
          <PackageInfoHeader>
            <PackageInfoName />
            {changeType ? <PackageInfoChangeType /> : null}
          </PackageInfoHeader>
          {currentVersion || newVersion ? <PackageInfoVersion /> : null}
        </>
      )}
    </div>
  </PackageInfoContext>
)
