// oxlint-disable import/exports-last, import/group-exports
'use client'

import type { HTMLAttributes, ReactNode } from 'react'

import { cn } from '@a/ui'
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@a/ui/collapsible'
import { ChevronRightIcon, FileIcon, FolderIcon, FolderOpenIcon } from 'lucide-react'
import { createContext, use, useState } from 'react'

interface FileTreeContextType {
  expandedPaths: Set<string>
  onSelect?: (path: string) => void
  selectedPath?: string
  togglePath: (path: string) => void
}

const FileTreeContext = createContext<FileTreeContextType>({
  expandedPaths: new Set(),
  togglePath: () => {
    //
  }
})

export type FileTreeProps = HTMLAttributes<HTMLDivElement> & {
  defaultExpanded?: Set<string>
  expanded?: Set<string>
  onExpandedChange?: (expanded: Set<string>) => void
  onSelect?: (path: string) => void
  selectedPath?: string
}

export const FileTree = ({
  children,
  className,
  // eslint-disable-next-line react/no-object-type-as-default-prop
  defaultExpanded = new Set(),
  expanded: controlledExpanded,
  onExpandedChange,
  onSelect,
  selectedPath,
  ...props
}: FileTreeProps) => {
  const [internalExpanded, setInternalExpanded] = useState(defaultExpanded),
    expandedPaths = controlledExpanded ?? internalExpanded,
    togglePath = (path: string) => {
      const newExpanded = new Set(expandedPaths)
      if (newExpanded.has(path)) newExpanded.delete(path)
      else newExpanded.add(path)

      setInternalExpanded(newExpanded)
      onExpandedChange?.(newExpanded)
    }

  return (
    <FileTreeContext value={{ expandedPaths, onSelect, selectedPath, togglePath }}>
      <div className={cn('rounded-lg border bg-background font-mono text-sm', className)} role='tree' {...props}>
        <div className='p-2'>{children}</div>
      </div>
    </FileTreeContext>
  )
}

interface FileTreeFolderContextType {
  isExpanded: boolean
  name: string
  path: string
}

const FileTreeFolderContext = createContext<FileTreeFolderContextType>({
  isExpanded: false,
  name: '',
  path: ''
})

export type FileTreeIconProps = HTMLAttributes<HTMLSpanElement>

export const FileTreeIcon = ({ children, className, ...props }: FileTreeIconProps) => (
  <span className={cn('shrink-0', className)} {...props}>
    {children}
  </span>
)

export type FileTreeNameProps = HTMLAttributes<HTMLSpanElement>

export const FileTreeName = ({ children, className, ...props }: FileTreeNameProps) => (
  <span className={cn('truncate', className)} {...props}>
    {children}
  </span>
)

export type FileTreeFolderProps = HTMLAttributes<HTMLDivElement> & {
  name: string
  path: string
}

export const FileTreeFolder = ({ children, className, name, path, ...props }: FileTreeFolderProps) => {
  const { expandedPaths, onSelect, selectedPath, togglePath } = use(FileTreeContext),
    isExpanded = expandedPaths.has(path),
    isSelected = selectedPath === path

  return (
    <FileTreeFolderContext value={{ isExpanded, name, path }}>
      <Collapsible onOpenChange={() => togglePath(path)} open={isExpanded}>
        <div className={cn('', className)} role='treeitem' tabIndex={0} {...props}>
          <CollapsibleTrigger asChild>
            <button
              className={cn(
                'flex w-full items-center gap-1 rounded-sm px-2 py-1 text-left transition-colors hover:bg-muted/50',
                isSelected && 'bg-muted'
              )}
              onClick={() => onSelect?.(path)}
              type='button'>
              <ChevronRightIcon
                className={cn('size-4 shrink-0 text-muted-foreground transition-transform', isExpanded && 'rotate-90')}
              />
              <FileTreeIcon>
                {isExpanded ? (
                  <FolderOpenIcon className='size-4 text-blue-500' />
                ) : (
                  <FolderIcon className='size-4 text-blue-500' />
                )}
              </FileTreeIcon>
              <FileTreeName>{name}</FileTreeName>
            </button>
          </CollapsibleTrigger>
          <CollapsibleContent>
            <div className='ml-4 border-l pl-2'>{children}</div>
          </CollapsibleContent>
        </div>
      </Collapsible>
    </FileTreeFolderContext>
  )
}

interface FileTreeFileContextType {
  name: string
  path: string
}

const FileTreeFileContext = createContext<FileTreeFileContextType>({
  name: '',
  path: ''
})

export type FileTreeActionsProps = HTMLAttributes<HTMLDivElement>

export const FileTreeActions = ({ children, className, ...props }: FileTreeActionsProps) => (
  // biome-ignore lint/a11y/noNoninteractiveElementInteractions: stopPropagation required for nested interactions
  // biome-ignore lint/a11y/useSemanticElements: fieldset doesn't fit this UI pattern
  // oxlint-disable-next-line jsx_a11y/no-static-element-interactions
  <div
    className={cn('ml-auto flex items-center gap-1', className)}
    onClick={e => e.stopPropagation()}
    onKeyDown={e => e.stopPropagation()}
    role='group'
    {...props}>
    {children}
  </div>
)

export type FileTreeFileProps = HTMLAttributes<HTMLDivElement> & {
  icon?: ReactNode
  name: string
  path: string
}

export const FileTreeFile = ({ children, className, icon, name, path, ...props }: FileTreeFileProps) => {
  const { onSelect, selectedPath } = use(FileTreeContext),
    isSelected = selectedPath === path

  return (
    <FileTreeFileContext value={{ name, path }}>
      <div
        className={cn(
          'flex cursor-pointer items-center gap-1 rounded-sm px-2 py-1 transition-colors hover:bg-muted/50',
          isSelected && 'bg-muted',
          className
        )}
        onClick={() => onSelect?.(path)}
        onKeyDown={e => {
          if (e.key === 'Enter' || e.key === ' ') onSelect?.(path)
        }}
        role='treeitem'
        tabIndex={0}
        {...props}>
        {children ?? (
          <>
            <span className='size-4' />
            <FileTreeIcon>{icon ?? <FileIcon className='size-4 text-muted-foreground' />}</FileTreeIcon>
            <FileTreeName>{name}</FileTreeName>
          </>
        )}
      </div>
    </FileTreeFileContext>
  )
}
