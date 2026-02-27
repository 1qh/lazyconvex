#!/usr/bin/env bun
/* eslint-disable no-console, max-statements */
/** biome-ignore-all lint/style/noProcessEnv: cli */
/** biome-ignore-all lint/performance/noAwaitInLoops: sequential */
/** biome-ignore-all lint/nursery/noContinue: cli directory scanning */
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

interface TableIndex {
  fields: string[]
  name: string
  type: 'custom' | 'default' | 'search'
}

interface WhereField {
  field: string
  source: string
  table: string
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
  FACTORY_DEFAULT_INDEXES: Record<string, TableIndex[]> = {
    cacheCrud: [],
    childCrud: [],
    crud: [{ fields: ['userId'], name: 'by_user', type: 'default' }],
    orgCrud: [
      { fields: ['orgId'], name: 'by_org', type: 'default' },
      { fields: ['orgId', 'userId'], name: 'by_org_user', type: 'default' }
    ],
    singletonCrud: [{ fields: ['userId'], name: 'by_user', type: 'default' }]
  },
  RESERVED_WHERE_KEYS = new Set(['$between', '$gt', '$gte', '$lt', '$lte', 'or', 'own']),
  TABLE_HELPER_SRC = [
    'ownedTable',
    'orgTable',
    'orgChildTable',
    'childTable',
    'baseTable',
    'singletonTable',
    'defineTable'
  ].join('|'),
  findSchemaDefFile = (convexDir: string): undefined | { content: string; path: string } => {
    for (const name of readdirSync(convexDir))
      if (name.endsWith('.ts') && !name.includes('.test.') && !name.startsWith('_')) {
        const full = join(convexDir, name),
          content = readFileSync(full, 'utf8')
        if (content.includes('defineSchema(')) return { content, path: full }
      }
  },
  extractCustomIndexes = (schemaContent: string): Map<string, TableIndex[]> => {
    const result = new Map<string, TableIndex[]>(),
      helperPat = new RegExp(`(\\w+)\\s*:\\s*(?:${TABLE_HELPER_SRC})\\s*\\(`, 'gu'),
      tables: { name: string; pos: number }[] = []
    let tm = helperPat.exec(schemaContent)
    while (tm) {
      const tName = tm[1] ?? ''
      tables.push({ name: tName, pos: tm.index })
      result.set(tName, [])
      tm = helperPat.exec(schemaContent)
    }
    for (let ti = 0; ti < tables.length; ti += 1) {
      const tEntry = tables[ti]
      if (!tEntry) break
      const nextEntry = tables[ti + 1],
        start = tEntry.pos,
        end = nextEntry ? nextEntry.pos : schemaContent.length,
        segment = schemaContent.slice(start, end),
        tableName = tEntry.name,
        indexes = result.get(tableName) ?? [],
        idxPat = /\.index\(\s*['"](?<iname>[^'"]+)['"]\s*,\s*\[(?<ifields>[^\]]*)\]\s*\)/gu
      let im = idxPat.exec(segment)
      while (im) {
        const idxName = im.groups?.iname ?? '',
          idxFieldsRaw = im.groups?.ifields ?? '',
          fields: string[] = [],
          fieldPat = /['"](?<fname>[^'"]+)['"]/gu
        let fm = fieldPat.exec(idxFieldsRaw)
        while (fm) {
          const fName = fm.groups?.fname ?? ''
          fields.push(fName)
          fm = fieldPat.exec(idxFieldsRaw)
        }
        indexes.push({ fields, name: idxName, type: 'custom' })
        im = idxPat.exec(segment)
      }
      const searchPat =
        /\.searchIndex\(\s*['"](?<sname>[^'"]+)['"]\s*,\s*\{[^}]*searchField:\s*['"](?<sfield>[^'"]+)['"]/gu
      let sm = searchPat.exec(segment)
      while (sm) {
        const sName = sm.groups?.sname ?? '',
          sField = sm.groups?.sfield ?? ''
        indexes.push({ fields: [sField], name: sName, type: 'search' })
        sm = searchPat.exec(segment)
      }
      result.set(tableName, indexes)
    }
    return result
  },
  extractWhereFromOptions = (opts: string): string[] => {
    const fields = new Set<string>(),
      whereIdx = opts.indexOf('where:')
    if (whereIdx === -1) return []
    const braceStart = opts.indexOf('{', whereIdx + 6)
    if (braceStart === -1) return []
    let depth = 1,
      pos = braceStart + 1
    while (pos < opts.length && depth > 0) {
      if (opts[pos] === '{') depth += 1
      else if (opts[pos] === '}') depth -= 1
      pos += 1
    }
    const block = opts.slice(braceStart + 1, pos - 1),
      fieldPat = /(?<wkey>\$?\w+)\s*:/gu
    let fm = fieldPat.exec(block)
    while (fm) {
      const fKey = fm.groups?.wkey ?? ''
      if (!RESERVED_WHERE_KEYS.has(fKey)) fields.add(fKey)
      fm = fieldPat.exec(block)
    }
    return [...fields]
  },
  scanWhereUsage = (root: string, cvxDir: string): WhereField[] => {
    const results: WhereField[] = [],
      schemaPath = join(cvxDir, 'schema.ts'),
      skip = new Set(['.cache', '.git', '.next', '.turbo', '_generated', 'build', 'dist', 'node_modules']),
      processFile = (filePath: string, fileName: string) => {
        const fileContent = readFileSync(filePath, 'utf8'),
          apiPat = /api\.(?<tbl>\w+)\.(?:list|search)\b/gu
        let am = apiPat.exec(fileContent)
        while (am) {
          const table = am.groups?.tbl ?? '',
            after = fileContent.slice(am.index, Math.min(am.index + 500, fileContent.length)),
            wIdx = after.indexOf('where:')
          if (wIdx !== -1 && wIdx < 200) {
            const wFields = extractWhereFromOptions(after.slice(Math.max(0, wIdx - 10)))
            for (const f of wFields) results.push({ field: f, source: fileName, table })
          }
          am = apiPat.exec(fileContent)
        }
      },
      scan = (dir: string) => {
        if (!existsSync(dir)) return
        for (const entry of readdirSync(dir, { withFileTypes: true }))
          if (entry.isDirectory()) {
            if (!(skip.has(entry.name) || entry.name.startsWith('.'))) scan(join(dir, entry.name))
          } else if (
            (entry.name.endsWith('.ts') || entry.name.endsWith('.tsx')) &&
            !entry.name.includes('.test.') &&
            !entry.name.includes('.config.') &&
            join(dir, entry.name) !== schemaPath
          )
            processFile(join(dir, entry.name), entry.name)
      }
    scan(root)
    return results
  },
  // oxlint-disable-next-line complexity
  // eslint-disable-next-line complexity
  printIndexReport = (convexDir: string, calls: FactoryCall[]) => {
    const schemaDef = findSchemaDefFile(convexDir),
      customIndexes = schemaDef ? extractCustomIndexes(schemaDef.content) : new Map<string, TableIndex[]>(),
      root = dirname(convexDir),
      projectWhere = scanWhereUsage(root, convexDir),
      whereByTable = new Map<string, Set<string>>(),
      issues: Issue[] = []
    for (const w of projectWhere) {
      const set = whereByTable.get(w.table) ?? new Set()
      set.add(w.field)
      whereByTable.set(w.table, set)
    }
    for (const call of calls) {
      const wFields = extractWhereFromOptions(call.options)
      if (wFields.length) {
        const set = whereByTable.get(call.table) ?? new Set()
        for (const f of wFields) set.add(f)
        whereByTable.set(call.table, set)
      }
    }
    console.log(bold('Index Analysis\n'))
    if (schemaDef) console.log(`${dim('schema def:')} ${schemaDef.path}\n`)
    let totalIndexes = 0
    for (const call of calls) {
      const defaults = FACTORY_DEFAULT_INDEXES[call.factory] ?? [],
        custom = customIndexes.get(call.table) ?? [],
        allIndexes = [...defaults, ...custom],
        allFields = new Set<string>()
      for (const idx of allIndexes) for (const f of idx.fields) allFields.add(f)
      totalIndexes += allIndexes.length
      console.log(`  ${bold(call.table)} ${dim(`(${call.factory})`)} ${dim(`\u2014 ${call.file}`)}`)
      for (const idx of allIndexes) {
        const symbol = idx.type === 'search' ? dim('\uD83D\uDD0D') : green('\u2713')
        console.log(`    ${symbol} ${idx.name} ${dim(`[${idx.fields.join(', ')}]`)} ${dim(`(${idx.type})`)}`)
      }
      if (!allIndexes.length) console.log(`    ${dim('(no indexes)')}`)
      const tableWhereFields = whereByTable.get(call.table)
      if (tableWhereFields)
        for (const field of tableWhereFields)
          if (!allFields.has(field)) {
            console.log(`    ${yellow('\u26A0')} where filter on '${field}' \u2014 no matching index`)
            issues.push({
              file: call.file,
              level: 'warn',
              message: `"${call.table}": where on '${field}' is runtime-filtered. Add .index('by_${field}', ['${field}']) for better performance`
            })
          }

      console.log('')
    }
    console.log(`${bold(String(totalIndexes))} indexes across ${bold(String(calls.length))} tables\n`)
    if (issues.length) {
      console.log(bold('Performance Suggestions\n'))
      for (const issue of issues)
        console.log(`  ${yellow('\u26A0')} ${issue.file ? `${dim(issue.file)} ` : ''}${issue.message}`)
      console.log(`\n${yellow(`${issues.length} unindexed where clause(s)`)}\n`)
    } else console.log(green('\u2713 All detected where clauses have matching indexes\n'))
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

    if (flags.has('--indexes')) {
      const { calls } = extractFactoryCalls(convexDir)
      printIndexReport(convexDir, calls)
      return
    }

    runCheck(convexDir, schemaFile)
  }

if (import.meta.main) run()

export {
  endpointsForFactory,
  extractCustomIndexes,
  extractWhereFromOptions,
  FACTORY_DEFAULT_INDEXES,
  printIndexReport,
  scanWhereUsage
}
export type { FactoryCall, TableIndex, WhereField }
