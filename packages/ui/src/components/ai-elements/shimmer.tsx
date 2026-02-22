'use client'

import type { CSSProperties, ElementType, JSX } from 'react'

import { cn } from '@a/ui'
import { motion } from 'motion/react'
import { memo, useMemo } from 'react'

export interface TextShimmerProps {
  as?: ElementType
  children: string
  className?: string
  duration?: number
  spread?: number
}

const ShimmerComponent = ({ as: Component = 'p', children, className, duration = 2, spread = 2 }: TextShimmerProps) => {
  const MotionComponent = motion.create(Component as keyof JSX.IntrinsicElements),
    dynamicSpread = useMemo(() => children.length * spread, [children, spread])

  return (
    // eslint-disable-next-line react-hooks/static-components
    <MotionComponent
      animate={{ backgroundPosition: '0% center' }}
      className={cn(
        'relative inline-block bg-size-[250%_100%,auto] bg-clip-text text-transparent',
        '[background-repeat:no-repeat,padding-box] [--bg:linear-gradient(90deg,#0000_calc(50%-var(--spread)),var(--color-background),#0000_calc(50%+var(--spread)))]',
        className
      )}
      initial={{ backgroundPosition: '100% center' }}
      style={
        {
          '--spread': `${dynamicSpread}px`,
          backgroundImage: 'var(--bg), linear-gradient(var(--color-muted-foreground), var(--color-muted-foreground))'
        } as CSSProperties
      }
      transition={{
        duration,
        ease: 'linear',
        repeat: Number.POSITIVE_INFINITY
      }}>
      {children}
    </MotionComponent>
  )
}

export const Shimmer = memo(ShimmerComponent)
