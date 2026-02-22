'use client'

import { cn } from '@a/ui'
import * as React from 'react'
import * as RechartsPrimitive from 'recharts'

// Format: { THEME_NAME: CSS_SELECTOR }
const THEMES = { dark: '.dark', light: '' } as const

export type ChartConfig = Record<
  string,
  ({ color?: never; theme: Record<keyof typeof THEMES, string> } | { color?: string; theme?: never }) & {
    icon?: React.ComponentType
    label?: React.ReactNode
  }
>

interface ChartContextProps {
  config: ChartConfig
}

const ChartContext = React.createContext<ChartContextProps | null>(null),
  ChartStyle = ({ config, id }: { config: ChartConfig; id: string }) => {
    const colorConfig = Object.entries(config).filter(([, cf]) => cf.theme ?? cf.color)

    if (!colorConfig.length) return null

    return (
      <style
        dangerouslySetInnerHTML={{
          __html: Object.entries(THEMES)
            .map(
              ([theme, prefix]) => `
${prefix} [data-chart=${id}] {
${colorConfig
  .map(([key, itemConfig]) => {
    const color = itemConfig.theme?.[theme as keyof typeof itemConfig.theme] ?? itemConfig.color
    return color ? `  --color-${key}: ${color};` : null
  })
  .join('\n')}
}
`
            )
            .join('\n')
        }}
      />
    )
  },
  ChartContainer = ({
    children,
    className,
    config,
    id,
    ...props
  }: React.ComponentProps<'div'> & {
    children: React.ComponentProps<typeof RechartsPrimitive.ResponsiveContainer>['children']
    config: ChartConfig
  }) => {
    const uniqueId = React.useId(),
      chartId = `chart-${id ?? uniqueId.replaceAll(':', '')}`

    return (
      <ChartContext value={{ config }}>
        <div
          className={cn(
            "flex aspect-video justify-center text-xs [&_.recharts-cartesian-axis-tick_text]:fill-muted-foreground [&_.recharts-cartesian-grid_line[stroke='#ccc']]:stroke-border/50 [&_.recharts-curve.recharts-tooltip-cursor]:stroke-border [&_.recharts-dot[stroke='#fff']]:stroke-transparent [&_.recharts-layer]:outline-hidden [&_.recharts-polar-grid_[stroke='#ccc']]:stroke-border [&_.recharts-radial-bar-background-sector]:fill-muted [&_.recharts-rectangle.recharts-tooltip-cursor]:fill-muted [&_.recharts-reference-line_[stroke='#ccc']]:stroke-border [&_.recharts-sector]:outline-hidden [&_.recharts-sector[stroke='#fff']]:stroke-transparent [&_.recharts-surface]:outline-hidden",
            className
          )}
          data-chart={chartId}
          data-slot='chart'
          {...props}>
          <ChartStyle config={config} id={chartId} />
          <RechartsPrimitive.ResponsiveContainer>{children}</RechartsPrimitive.ResponsiveContainer>
        </div>
      </ChartContext>
    )
  },
  ChartTooltip = RechartsPrimitive.Tooltip,
  ChartLegend = RechartsPrimitive.Legend

export { ChartContainer, ChartLegend, ChartStyle, ChartTooltip }
