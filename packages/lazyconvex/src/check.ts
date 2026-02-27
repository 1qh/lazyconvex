#!/usr/bin/env bun
/* eslint-disable no-console, max-statements */
/** biome-ignore-all lint/style/noProcessEnv: cli */
/** biome-ignore-all lint/performance/noAwaitInLoops: sequential */
import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { basename, dirname, join } from 'node:path'

const red = (s: string) => `\u001B[31m${s}\u001B[0m`,
  green = (s: string) => `\u001B[32m${s}\u001B[0m`,
  yellow = (s: string) => `\u001B[33m${s}\u001B[0m`,
  dim = (s: string) => `\u001B[2m${s}\u001B[0m`,
  bold = (s: string) => `\u001B[1m${s}\u001B[0m`

interface FactoryCall {
  factory: string
  file: string
  options: string
  table: string
}

interface Issue {
  file?: string
  level: 'error' | 'warn'
  message: string
}

const schemaMarkers = ['makeOwned(', 'makeOrgScoped(', 'makeSingleton(', 'makeBase(', 'child('],
  factoryPat = /(?<factory>crud|orgCrud|childCrud|cacheCrud|singletonCrud)\(\s*['"](?<table>\w+)['"]/gu,
  wrapperFactories = ['makeOwned', 'makeOrgScoped', 'makeSingleton', 'makeBase'],
  CRUD_BASE = ['create', 'update', 'rm', 'bulkCreate', 'bulkRm', 'bulkUpdate'],
  CRUD_PUB = ['pub.list', 'pub.read'],
  ORG_CRUD_BASE = ['list', 'read', 'create', 'update', 'rm', 'bulkCreate', 'bulkRm', 'bulkUpdate'],
  ORG_ACL = ['addEditor', 'removeEditor', 'setEditors', 'editors'],
  CHILD_BASE = ['list', 'create', 'update', 'rm', 'bulkCreate', 'bulkRm', 'bulkUpdate'],
  CACHE_BASE = ['get', 'all', 'list', 'create', 'update', 'rm', 'invalidate', 'purge', 'load', 'refresh'],
  SINGLETON_BASE = ['get', 'upsert'],
  isSchemaFile = (content: string): boolean => {
    for (const marker of schemaMarkers) if (content.includes(marker)) return true
    return false
  },
  hasGenerated = (dir: string): boolean => existsSync(join(dir, '_generated')),
  findConvexDir = (root: string): string | undefined => {
    const direct = join(root, 'convex')
    if (hasGenerated(direct)) return direct
    if (!existsSync(root)) return
    for (const sub of readdirSync(root, { withFileTypes: true }))
      if (sub.isDirectory()) {
        const nested = join(root, sub.name, 'convex')
        if (hasGenerated(nested)) return nested
      }
  },
  findSchemaFile = (convexDir: string): undefined | { content: string; path: string } => {
    const searchDir = dirname(convexDir)
    if (!existsSync(searchDir)) return
    for (const entry of readdirSync(searchDir))
      if (entry.endsWith('.ts') && !entry.endsWith('.test.ts') && !entry.endsWith('.config.ts')) {
        const full = join(searchDir, entry),
          content = readFileSync(full, 'utf8')
        if (isSchemaFile(content)) return { content, path: full }
      }
  },
  extractSchemaTableNames = (content: string): Set<string> => {
    const tables = new Set<string>()
    for (const factory of wrapperFactories) {
      const pat = new RegExp(`${factory}\\(\\{`, 'gu')
      let fm = pat.exec(content)
      while (fm) {
        let depth = 1,
          pos = fm.index + fm[0].length
        while (pos < content.length && depth > 0) {
          if (content[pos] === '{') depth += 1
          else if (content[pos] === '}') depth -= 1
          pos += 1
        }
        const block = content.slice(fm.index + fm[0].length, pos - 1),
          propPat = /(?<pname>\w+)\s*:\s*object\(/gu
        let pm = propPat.exec(block)
        while (pm) {
          if (pm.groups?.pname) tables.add(pm.groups.pname)
          pm = propPat.exec(block)
        }
        fm = pat.exec(content)
      }
    }
    const childPat = /(?<cname>\w+)\s*:\s*child\(/gu
    let cm = childPat.exec(content)
    while (cm) {
      if (cm.groups?.cname) tables.add(cm.groups.cname)
      cm = childPat.exec(content)
    }
    return tables
  },
  extractRemainingOptions = (content: string, startPos: number): string => {
    let depth = 1,
      pos = startPos
    while (pos < content.length && depth > 0) {
      if (content[pos] === '(') depth += 1
      else if (content[pos] === ')') depth -= 1
      pos += 1
    }
    return content.slice(startPos, pos - 1)
  },
  extractFactoryCalls = (convexDir: string): { calls: FactoryCall[]; files: string[] } => {
    const calls: FactoryCall[] = [],
      files: string[] = []
    for (const entry of readdirSync(convexDir))
      if (entry.endsWith('.ts') && !entry.startsWith('_') && !entry.includes('.test.') && !entry.includes('.config.')) {
        const full = join(convexDir, entry),
          content = readFileSync(full, 'utf8')
        files.push(entry)
        let m = factoryPat.exec(content)
        while (m) {
          if (m.groups?.factory && m.groups.table) {
            const afterTable = content.indexOf(m.groups.table, m.index) + m.groups.table.length,
              rest = extractRemainingOptions(content, afterTable)
            calls.push({ factory: m.groups.factory, file: entry, options: rest, table: m.groups.table })
          }
          m = factoryPat.exec(content)
        }
        factoryPat.lastIndex = 0
      }
    return { calls, files }
  },
  hasOption = (opts: string, key: string): boolean => opts.includes(key),
  endpointsForFactory = (call: FactoryCall): string[] => {
    const { factory, options: opts } = call
    if (factory === 'singletonCrud') return [...SINGLETON_BASE]
    if (factory === 'cacheCrud') return [...CACHE_BASE]
    if (factory === 'childCrud') {
      const eps = [...CHILD_BASE]
      if (hasOption(opts, 'pub')) {
        eps.push('pub.list')
        eps.push('pub.get')
      }
      return eps
    }
    if (factory === 'orgCrud') {
      const eps = [...ORG_CRUD_BASE]
      if (hasOption(opts, 'acl')) eps.push(...ORG_ACL)
      if (hasOption(opts, 'softDelete')) eps.push('restore')
      if (hasOption(opts, 'search')) eps.push('search')
      return eps
    }
    const eps = [...CRUD_BASE, ...CRUD_PUB]
    if (hasOption(opts, 'search')) eps.push('pub.search')
    if (hasOption(opts, 'softDelete')) eps.push('restore')
    return eps
  },
  printEndpoints = (calls: FactoryCall[]) => {
    let total = 0
    console.log(bold('Generated Endpoints\n'))
    for (const call of calls) {
      const eps = endpointsForFactory(call)
      total += eps.length
      console.log(`  ${bold(call.table)} ${dim(`(${call.factory})`)} ${dim(`\u2014 ${call.file}`)}`)
      const groups: Record<string, string[]> = {}
      for (const ep of eps) {
        const dot = ep.indexOf('.')
        if (dot > 0) {
          const prefix = ep.slice(0, dot),
            name = ep.slice(dot + 1)
          groups[prefix] ??= []
          groups[prefix].push(name)
        } else {
          groups[''] ??= []
          groups[''].push(ep)
        }
      }
      if (groups['']) console.log(`    ${groups[''].join(', ')}`)
      for (const [prefix, names] of Object.entries(groups))
        if (prefix) console.log(`    ${dim(`${prefix}.`)}${names.join(`, ${dim(`${prefix}.`)}`)}`)
      console.log('')
    }
    console.log(`${bold(String(total))} endpoints from ${bold(String(calls.length))} factory calls\n`)
  },
  runCheck = (convexDir: string, schemaFile: { content: string; path: string }) => {
    const issues: Issue[] = [],
      schemaTables = extractSchemaTableNames(schemaFile.content),
      { calls, files } = extractFactoryCalls(convexDir)

    console.log(`${dim('tables in schema:')} ${[...schemaTables].join(', ') || 'none'}`)
    console.log(`${dim('factory calls:')}    ${calls.length}\n`)

    const seen = new Map<string, string>()
    for (const call of calls) {
      if (seen.has(call.table))
        issues.push({
          file: call.file,
          level: 'error',
          message: `Duplicate factory for table "${call.table}" (also in ${seen.get(call.table)})`
        })
      else seen.set(call.table, call.file)

      if (!schemaTables.has(call.table))
        issues.push({
          file: call.file,
          level: 'error',
          message: `${call.factory}('${call.table}') but no "${call.table}" table found in schema`
        })
    }

    const factoryTables = new Set(calls.map(c => c.table))
    for (const table of schemaTables)
      if (!factoryTables.has(table))
        issues.push({
          file: basename(schemaFile.path),
          level: 'warn',
          message: `Table "${table}" defined in schema but no factory call found`
        })

    const convexFiles = new Set(files.map(f => f.replace('.ts', '')))
    for (const call of calls)
      if (call.table !== basename(call.file, '.ts') && !convexFiles.has(call.table))
        issues.push({
          file: call.file,
          level: 'warn',
          message: `${call.factory}('${call.table}') in ${call.file} — table name doesn't match filename`
        })

    if (!issues.length) {
      console.log(green('\u2713 All checks passed\n'))
      return
    }

    const errors = issues.filter(i => i.level === 'error'),
      warnings = issues.filter(i => i.level === 'warn')

    for (const issue of errors) console.log(`${red('\u2717')} ${issue.file ? `${dim(issue.file)} ` : ''}${issue.message}`)
    for (const issue of warnings)
      console.log(`${yellow('\u26A0')} ${issue.file ? `${dim(issue.file)} ` : ''}${issue.message}`)

    console.log(
      `\n${errors.length ? red(`${errors.length} error(s)`) : ''}${errors.length && warnings.length ? ', ' : ''}${warnings.length ? yellow(`${warnings.length} warning(s)`) : ''}\n`
    )

    if (errors.length) process.exit(1)
  },
  run = () => {
    const root = process.cwd(),
      flags = new Set(process.argv.slice(2))

    console.log(bold('\nlazyconvex check\n'))

    const convexDir = findConvexDir(root)
    if (!convexDir) {
      console.log(red('\u2717 Could not find convex/ directory with _generated/'))
      console.log(dim('  Run from project root or a directory containing convex/'))
      process.exit(1)
    }
    console.log(`${dim('convex dir:')} ${convexDir}`)

    const schemaFile = findSchemaFile(convexDir)
    if (!schemaFile) {
      console.log(red('\u2717 Could not find schema file with lazyconvex markers'))
      console.log(dim('  Expected a .ts file importing makeOwned/makeOrgScoped/etc.'))
      process.exit(1)
    }
    console.log(`${dim('schema:')}    ${schemaFile.path}\n`)

    if (flags.has('--endpoints')) {
      const { calls } = extractFactoryCalls(convexDir)
      printEndpoints(calls)
      return
    }

    runCheck(convexDir, schemaFile)
  }

if (import.meta.main) run()

export { endpointsForFactory }
export type { FactoryCall }
