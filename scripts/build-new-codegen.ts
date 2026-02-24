#!/usr/bin/env bun
import { readFileSync, writeFileSync } from 'node:fs'

const original = readFileSync('/tmp/codegen-swift.ts.backup', 'utf8')
const origLines = original.split('\n')

const getLines = (start: number, end: number) => origLines.slice(start - 1, end).join('\n')

const section1 = getLines(1, 29)

const newInterfaces = `
interface CustomArg {
  isOptional: boolean
  name: string
  swiftType: string
  wireExpr?: string
  wireName?: string
}

interface CustomFnDef {
  args: CustomArg[]
  dummyActionType?: string
  fn: string
  kind: 'action' | 'mutation' | 'query'
  nestedData?: boolean
  nestedDataAllOptional?: boolean
  nestedDataOuter?: string[]
  returnType?: string
  structArrayArg?: string
  structArrayFields?: { enumField?: boolean; name: string }[]
  structArrayType?: string
  structArrayVar?: string
}

interface SubConfig {
  args: { name: string; swiftType: string }[]
  fnRef: string
  isArray: boolean
  isPaginated: boolean
  methodName: string
  nullable: boolean
  onNull: boolean
  skipMethod: string
  swiftType: string
  whereType?: string
}

interface MobileActionDef {
  args: CustomArg[]
  fn: string
  returnType: string
  skipElse: string
  skipNotSkip: string
}
`

const section2 = getLines(30, 998)

const newConfigAndEmitter = `  CUSTOM_FN_DEFS: Record<string, CustomFnDef[]> = {
    file: [
      { fn: 'upload', kind: 'mutation', returnType: 'String', args: [] }
    ],
    message: [
      { fn: 'list', kind: 'query', returnType: '[Message]', args: [{ name: 'chatId', swiftType: 'String', isOptional: false }] },
      {
        fn: 'create', kind: 'mutation', args: [
          { name: 'chatId', swiftType: 'String', isOptional: false },
          { name: 'parts', swiftType: '[MessagePart]', isOptional: false },
          { name: 'role', swiftType: 'String', isOptional: false }
        ],
        structArrayArg: 'parts',
        structArrayType: 'MessagePart',
        structArrayVar: 'partDicts',
        structArrayFields: [
          { name: 'type', enumField: true },
          { name: 'text' },
          { name: 'image' },
          { name: 'file' },
          { name: 'name' }
        ]
      }
    ],
    mobileAi: [
      { fn: 'chat', kind: 'action', dummyActionType: '[String: String]', args: [{ name: 'chatId', swiftType: 'String', isOptional: false }] }
    ],
    movie: [
      { fn: 'search', kind: 'action', returnType: '[SearchResult]', args: [{ name: 'query', swiftType: 'String', isOptional: false }] },
      { fn: 'load', kind: 'action', returnType: 'Movie', args: [{ name: 'tmdbId', swiftType: 'Int', isOptional: false, wireExpr: 'Double(tmdbId)', wireName: 'tmdb_id' }] }
    ],
    org: [
      {
        fn: 'create', kind: 'mutation', nestedData: true, args: [
          { name: 'name', swiftType: 'String', isOptional: false },
          { name: 'slug', swiftType: 'String', isOptional: false },
          { name: 'avatarId', swiftType: 'String', isOptional: true }
        ]
      },
      {
        fn: 'update', kind: 'mutation', nestedData: true, nestedDataAllOptional: true, nestedDataOuter: ['orgId'],
        args: [
          { name: 'name', swiftType: 'String', isOptional: true },
          { name: 'slug', swiftType: 'String', isOptional: true },
          { name: 'avatarId', swiftType: 'String', isOptional: true }
        ]
      },
      { fn: 'get', kind: 'query', returnType: 'Org', args: [{ name: 'orgId', swiftType: 'String', isOptional: false }] },
      { fn: 'getBySlug', kind: 'query', returnType: 'Org?', args: [{ name: 'slug', swiftType: 'String', isOptional: false }] },
      { fn: 'getPublic', kind: 'query', returnType: 'Org?', args: [{ name: 'slug', swiftType: 'String', isOptional: false }] },
      { fn: 'myOrgs', kind: 'query', returnType: '[OrgWithRole]', args: [] },
      { fn: 'remove', kind: 'mutation', args: [{ name: 'orgId', swiftType: 'String', isOptional: false }] },
      { fn: 'isSlugAvailable', kind: 'query', returnType: 'SlugAvailability', args: [{ name: 'slug', swiftType: 'String', isOptional: false }] },
      { fn: 'getOrCreate', kind: 'mutation', returnType: 'OrgGetOrCreateResult', args: [] },
      { fn: 'membership', kind: 'query', returnType: 'OrgMembership', args: [{ name: 'orgId', swiftType: 'String', isOptional: false }] },
      { fn: 'members', kind: 'query', returnType: '[OrgMemberEntry]', args: [{ name: 'orgId', swiftType: 'String', isOptional: false }] },
      { fn: 'setAdmin', kind: 'mutation', args: [{ name: 'isAdmin', swiftType: 'Bool', isOptional: false }, { name: 'memberId', swiftType: 'String', isOptional: false }] },
      { fn: 'removeMember', kind: 'mutation', args: [{ name: 'memberId', swiftType: 'String', isOptional: false }] },
      { fn: 'leave', kind: 'mutation', args: [{ name: 'orgId', swiftType: 'String', isOptional: false }] },
      { fn: 'transferOwnership', kind: 'mutation', args: [{ name: 'newOwnerId', swiftType: 'String', isOptional: false }, { name: 'orgId', swiftType: 'String', isOptional: false }] },
      { fn: 'invite', kind: 'mutation', args: [{ name: 'email', swiftType: 'String', isOptional: false }, { name: 'isAdmin', swiftType: 'Bool', isOptional: false }, { name: 'orgId', swiftType: 'String', isOptional: false }] },
      { fn: 'acceptInvite', kind: 'mutation', args: [{ name: 'token', swiftType: 'String', isOptional: false }] },
      { fn: 'revokeInvite', kind: 'mutation', args: [{ name: 'inviteId', swiftType: 'String', isOptional: false }] },
      { fn: 'pendingInvites', kind: 'query', returnType: '[OrgInvite]', args: [{ name: 'orgId', swiftType: 'String', isOptional: false }] },
      { fn: 'requestJoin', kind: 'mutation', args: [{ name: 'orgId', swiftType: 'String', isOptional: false }, { name: 'message', swiftType: 'String', isOptional: true }] },
      { fn: 'approveJoinRequest', kind: 'mutation', args: [{ name: 'requestId', swiftType: 'String', isOptional: false }, { name: 'isAdmin', swiftType: 'Bool', isOptional: true }] },
      { fn: 'rejectJoinRequest', kind: 'mutation', args: [{ name: 'requestId', swiftType: 'String', isOptional: false }] },
      { fn: 'cancelJoinRequest', kind: 'mutation', args: [{ name: 'requestId', swiftType: 'String', isOptional: false }] },
      { fn: 'pendingJoinRequests', kind: 'query', returnType: '[OrgJoinRequest]', args: [{ name: 'orgId', swiftType: 'String', isOptional: false }] },
      { fn: 'myJoinRequest', kind: 'query', returnType: 'OrgJoinRequest?', args: [{ name: 'orgId', swiftType: 'String', isOptional: false }] }
    ],
    task: [
      { fn: 'toggle', kind: 'mutation', args: [{ name: 'orgId', swiftType: 'String', isOptional: false }, { name: 'id', swiftType: 'String', isOptional: false }] },
      { fn: 'byProject', kind: 'query', returnType: '[$STRUCT]', args: [{ name: 'orgId', swiftType: 'String', isOptional: false }, { name: 'projectId', swiftType: 'String', isOptional: false }] }
    ]
  },
  CUSTOM_FN_PLACEMENT: Record<string, 'insideCrud' | 'ownBlock'> = {
    file: 'ownBlock',
    message: 'ownBlock',
    mobileAi: 'ownBlock',
    movie: 'ownBlock',
    org: 'ownBlock',
    task: 'insideCrud'
  },
  // eslint-disable-next-line max-statements
  emitNonCrudDesktopWrapper = (modName: string, def: CustomFnDef, structName: string, emitFn: (s: string) => void) => {
    const fnKey = \`\${modName}:\${def.fn}\`,
      hasOptional = def.args.some(a => a.isOptional),
      resolvedReturn = def.returnType?.replace('[$STRUCT]', \`[\${structName}]\`) ?? undefined

    if (def.nestedData) {
      const outerArgs = def.nestedDataOuter ?? [],
        params = ['_ client: ConvexClientProtocol'],
        dataRequired: string[] = [],
        dataOptional: string[] = []
      for (const o of outerArgs) params.push(\`\${o}: String\`)
      for (const a of def.args) {
        const t = a.isOptional ? \`\${a.swiftType}?\` : a.swiftType,
          dv = a.isOptional ? ' = nil' : ''
        params.push(\`\${a.name}: \${t}\${dv}\`)
        if (a.isOptional) dataOptional.push(a.name)
        else dataRequired.push(\`"\${a.name}": \${a.name}\`)
      }
      const retSuffix = resolvedReturn ? \` -> \${resolvedReturn}\` : ''
      emitFn(\`\${indent(1)}public static func \${def.fn}(\${params.join(', ')}) async throws\${retSuffix} {\`)
      const binding = def.nestedDataAllOptional ? 'var' : (dataOptional.length > 0 ? 'var' : 'let')
      emitFn(\`\${indent(2)}\${binding} data: [String: Any] = [\${dataRequired.join(', ')}]\`)
      for (const name of dataOptional) emitFn(\`\${indent(2)}if let \${name} { data["\${name}"] = \${name} }\`)
      const outerParts: string[] = []
      for (const o of outerArgs) outerParts.push(\`"\${o}": \${o}\`)
      outerParts.push('"data": data')
      emitFn(\`\${indent(2)}try await client.\${def.kind}("\${fnKey}", args: [\${outerParts.join(', ')}])\`)
      emitFn(\`\${indent(1)}}\`)
      return
    }

    if (def.structArrayArg && def.structArrayFields && def.structArrayVar) {
      const params = ['_ client: ConvexClientProtocol']
      for (const a of def.args) params.push(\`\${a.name}: \${a.swiftType}\`)
      emitFn(\`\${indent(1)}public static func \${def.fn}(\${params.join(', ')}) async throws {\`)
      emitFn(\`\${indent(2)}var \${def.structArrayVar} = [[String: Any]]()\`)
      emitFn(\`\${indent(2)}for p in \${def.structArrayArg} {\`)
      const requiredField = def.structArrayFields[0]
      if (requiredField) {
        const val = requiredField.enumField ? \`p.\${requiredField.name}.rawValue\` : \`p.\${requiredField.name}\`
        emitFn(\`\${indent(3)}var d: [String: Any] = ["\${requiredField.name}": \${val}]\`)
      }
      for (let fi = 1; fi < def.structArrayFields.length; fi += 1) {
        const f = def.structArrayFields[fi]
        if (f) emitFn(\`\${indent(3)}if let \${f.name} = p.\${f.name} { d["\${f.name}"] = \${f.name} }\`)
      }
      emitFn(\`\${indent(3)}\${def.structArrayVar}.append(d)\`)
      emitFn(\`\${indent(2)}}\`)
      const otherArgs: string[] = []
      for (const a of def.args) {
        if (a.name === def.structArrayArg) otherArgs.push(\`"\${a.name}": \${def.structArrayVar}\`)
        else otherArgs.push(\`"\${a.name}": \${a.name}\`)
      }
      emitFn(\`\${indent(2)}try await client.\${def.kind}("\${fnKey}", args: [\${otherArgs.join(', ')}])\`)
      emitFn(\`\${indent(1)}}\`)
      return
    }

    if (def.dummyActionType) {
      const params = ['_ client: ConvexClientProtocol']
      for (const a of def.args) params.push(\`\${a.name}: \${a.swiftType}\`)
      emitFn(\`\${indent(1)}public static func \${def.fn}(\${params.join(', ')}) async throws {\`)
      const argParts: string[] = []
      for (const a of def.args) argParts.push(\`"\${a.wireName ?? a.name}": \${a.wireExpr ?? a.name}\`)
      emitFn(\`\${indent(2)}let _: \${def.dummyActionType} = try await client.action("\${fnKey}", args: [\${argParts.join(', ')}])\`)
      emitFn(\`\${indent(1)}}\`)
      return
    }

    const params = ['_ client: ConvexClientProtocol'],
      required: string[] = [],
      optional: string[] = []
    for (const a of def.args) {
      const t = a.isOptional ? \`\${a.swiftType}?\` : a.swiftType,
        dv = a.isOptional ? ' = nil' : ''
      params.push(\`\${a.name}: \${t}\${dv}\`)
      if (a.isOptional) optional.push(a.name)
      else required.push(\`"\${a.wireName ?? a.name}": \${a.wireExpr ?? a.name}\`)
    }
    const retSuffix = resolvedReturn ? \` -> \${resolvedReturn}\` : ''

    if (!hasOptional && params.length <= 4) {
      emitFn(\`\${indent(1)}public static func \${def.fn}(\${params.join(', ')}) async throws\${retSuffix} {\`)
      emitFn(\`\${indent(2)}try await client.\${def.kind}("\${fnKey}", args: [\${required.join(', ')}])\`)
      emitFn(\`\${indent(1)}}\`)
    } else if (!hasOptional) {
      emitFn(\`\${indent(1)}public static func \${def.fn}(\`)
      emitFn(\`\${indent(2)}\${params.join(\`,\\n\${indent(2)}\`)}\`)
      emitFn(\`\${indent(1)}) async throws\${retSuffix} {\`)
      emitFn(\`\${indent(2)}try await client.\${def.kind}("\${fnKey}", args: [\${required.join(', ')}])\`)
      emitFn(\`\${indent(1)}}\`)
    } else {
      emitFn(\`\${indent(1)}public static func \${def.fn}(\`)
      emitFn(\`\${indent(2)}\${params.join(\`,\\n\${indent(2)}\`)}\`)
      emitFn(\`\${indent(1)}) async throws\${retSuffix} {\`)
      emitFn(\`\${indent(2)}var args: [String: Any] = [\${required.join(', ')}]\`)
      for (const name of optional) emitFn(\`\${indent(2)}if let \${name} { args["\${name}"] = \${name} }\`)
      emitFn(\`\${indent(2)}try await client.\${def.kind}("\${fnKey}", args: args)\`)
      emitFn(\`\${indent(1)}}\`)
    }
  }

`

const section4 = getLines(1218, 1246)

const newLine1247 = `      const insideCrudDefs = CUSTOM_FN_DEFS[modName]
      if (insideCrudDefs && CUSTOM_FN_PLACEMENT[modName] === 'insideCrud')
        for (const def of insideCrudDefs) if (fnSet.has(def.fn)) emitNonCrudDesktopWrapper(modName, def, structName, emit)`

const section6 = getLines(1248, 1261)

const newOwnBlocks = `  const ownBlockDefs = CUSTOM_FN_DEFS[modName]
  if (ownBlockDefs && CUSTOM_FN_PLACEMENT[modName] === 'ownBlock') {
    const prevCustomLen = lines.length
    for (const def of ownBlockDefs) if (fnSet.has(def.fn)) emitNonCrudDesktopWrapper(modName, def, structName, emit)
    if (lines.length > prevCustomLen) {
      const customLines = lines.splice(prevCustomLen)
      emit('')
      emit(\`\${indent(1)}#if DESKTOP\`)
      for (const line of customLines) emit(line)
      emit(\`\${indent(1)}#endif\`)
    }
  }`

const section8 = getLines(1296, 1321)

const newMobileSection = `if (MOBILE_OUTPUT_PATH) {
  const mLines: string[] = [],
    me = (s: string) => mLines.push(s),
    MOBILE_VOID_OVERRIDES = new Set(['org:getOrCreate']),
    // eslint-disable-next-line max-statements
    emitMobileNonCrudWrapper = (modName: string, def: CustomFnDef, emitFn: (s: string) => void) => {
      const fnKey = \`\${modName}:\${def.fn}\`,
        isMobileVoid = MOBILE_VOID_OVERRIDES.has(fnKey),
        resolvedReturn = isMobileVoid ? undefined : def.returnType,
        hasOptional = def.args.some(a => a.isOptional)

      if (def.nestedData) {
        const outerArgs = def.nestedDataOuter ?? [],
          params: string[] = [],
          dataRequired: string[] = [],
          dataOptional: string[] = []
        for (const o of outerArgs) params.push(\`\${o}: String\`)
        for (const a of def.args) {
          const t = a.isOptional ? \`\${a.swiftType}?\` : a.swiftType,
            dv = a.isOptional ? ' = nil' : ''
          params.push(\`\${a.name}: \${t}\${dv}\`)
          if (a.isOptional) dataOptional.push(a.name)
          else dataRequired.push(\`"\${a.name}": \${a.name}\`)
        }
        const retSuffix = resolvedReturn ? \` -> \${resolvedReturn}\` : ''
        emitFn(\`\${indent(1)}public static func \${def.fn}(\${params.join(', ')}) async throws\${retSuffix} {\`)
        const binding = def.nestedDataAllOptional ? 'var' : (dataOptional.length > 0 ? 'var' : 'let')
        emitFn(\`\${indent(2)}\${binding} data: [String: Any] = [\${dataRequired.join(', ')}]\`)
        for (const name of dataOptional) emitFn(\`\${indent(2)}if let \${name} { data["\${name}"] = \${name} }\`)
        const outerParts: string[] = []
        for (const o of outerArgs) outerParts.push(\`"\${o}": \${o}\`)
        outerParts.push('"data": data')
        emitFn(\`\${indent(2)}try await ConvexService.shared.mutate("\${fnKey}", args: [\${outerParts.join(', ')}])\`)
        emitFn(\`\${indent(1)}}\`)
        return
      }

      if (def.structArrayArg && def.structArrayFields && def.structArrayVar) {
        const params: string[] = []
        for (const a of def.args) params.push(\`\${a.name}: \${a.swiftType}\`)
        emitFn(\`\${indent(1)}public static func \${def.fn}(\${params.join(', ')}) async throws {\`)
        emitFn(\`\${indent(2)}var \${def.structArrayVar} = [[String: Any]]()\`)
        emitFn(\`\${indent(2)}for p in \${def.structArrayArg} {\`)
        const requiredField = def.structArrayFields[0]
        if (requiredField) {
          const val = requiredField.enumField ? \`p.\${requiredField.name}.rawValue\` : \`p.\${requiredField.name}\`
          emitFn(\`\${indent(3)}var d: [String: Any] = ["\${requiredField.name}": \${val}]\`)
        }
        for (let fi = 1; fi < def.structArrayFields.length; fi += 1) {
          const f = def.structArrayFields[fi]
          if (f) emitFn(\`\${indent(3)}if let \${f.name} = p.\${f.name} { d["\${f.name}"] = \${f.name} }\`)
        }
        emitFn(\`\${indent(3)}\${def.structArrayVar}.append(d)\`)
        emitFn(\`\${indent(2)}}\`)
        const otherArgs: string[] = []
        for (const a of def.args) {
          if (a.name === def.structArrayArg) otherArgs.push(\`"\${a.name}": \${def.structArrayVar}\`)
          else otherArgs.push(\`"\${a.name}": \${a.name}\`)
        }
        emitFn(\`\${indent(2)}try await ConvexService.shared.mutate("\${fnKey}", args: [\${otherArgs.join(', ')}])\`)
        emitFn(\`\${indent(1)}}\`)
        return
      }

      const params: string[] = [],
        required: string[] = [],
        optional: string[] = []
      for (const a of def.args) {
        const t = a.isOptional ? \`\${a.swiftType}?\` : a.swiftType,
          dv = a.isOptional ? ' = nil' : ''
        params.push(\`\${a.name}: \${t}\${dv}\`)
        if (a.isOptional) optional.push(a.name)
        else required.push(\`"\${a.wireName ?? a.name}": \${a.wireExpr ?? a.name}\`)
      }
      const retSuffix = resolvedReturn ? \` -> \${resolvedReturn}\` : ''

      if (!hasOptional && params.length <= 3) {
        emitFn(\`\${indent(1)}public static func \${def.fn}(\${params.join(', ')}) async throws\${retSuffix} {\`)
        emitFn(\`\${indent(2)}try await ConvexService.shared.mutate("\${fnKey}", args: [\${required.join(', ')}])\`)
        emitFn(\`\${indent(1)}}\`)
      } else if (!hasOptional) {
        emitFn(\`\${indent(1)}public static func \${def.fn}(\`)
        emitFn(\`\${indent(2)}\${params.join(\`,\\n\${indent(2)}\`)}\`)
        emitFn(\`\${indent(1)}) async throws\${retSuffix} {\`)
        emitFn(\`\${indent(2)}try await ConvexService.shared.mutate("\${fnKey}", args: [\${required.join(', ')}])\`)
        emitFn(\`\${indent(1)}}\`)
      } else {
        emitFn(\`\${indent(1)}public static func \${def.fn}(\${params.join(', ')}) async throws\${retSuffix} {\`)
        emitFn(\`\${indent(2)}var args: [String: Any] = [\${required.join(', ')}]\`)
        for (const name of optional) emitFn(\`\${indent(2)}if let \${name} { args["\${name}"] = \${name} }\`)
        emitFn(\`\${indent(2)}try await ConvexService.shared.mutate("\${fnKey}", args: args)\`)
        emitFn(\`\${indent(1)}}\`)
      }
    },
    // eslint-disable-next-line max-statements
    emitMobileCreateWrapper = (modName: string, fields: Map<string, FieldEntry>, factoryType: string) => {
      const params: string[] = [],
        required: string[] = [],
        optional: string[] = []
      if (factoryType === 'orgScoped') params.push('orgId: String')
      for (const [fname, field] of fields) {
        const t = field.isOptional ? \`\${field.swiftType}?\` : field.swiftType,
          defaultVal = field.isOptional ? ' = nil' : ''
        params.push(\`\${fname}: \${t}\${defaultVal}\`)
        const value = isEnumField(field.swiftType) ? \`\${fname}.rawValue\` : fname
        if (field.isOptional) optional.push(fname)
        else required.push(\`"\${fname}": \${value}\`)
      }
      if (factoryType === 'orgScoped') required.unshift('"orgId": orgId')
      me(\`\${indent(1)}public static func create(\`)
      me(\`\${indent(2)}\${params.join(\`,\\n\${indent(2)}\`)}\`)
      me(\`\${indent(1)}) async throws {\`)
      const binding = optional.length > 0 ? 'var' : 'let'
      me(\`\${indent(2)}\${binding} args: [String: Any] = [\${required.join(', ')}]\`)
      for (const fname of optional) {
        const field = fields.get(fname)
        if (field) {
          const value = isEnumField(field.swiftType) ? \`\${fname}.rawValue\` : fname
          me(\`\${indent(2)}if let \${fname} { args["\${fname}"] = \${value} }\`)
        }
      }
      me(\`\${indent(2)}try await ConvexService.shared.mutate("\${modName}:create", args: args)\`)
      me(\`\${indent(1)}}\`)
    },
    // eslint-disable-next-line max-statements
    emitMobileUpdateWrapper = (modName: string, fields: Map<string, FieldEntry>, factoryType: string) => {
      const params: string[] = [],
        required: string[] = ['"id": id'],
        optional: string[] = []
      if (factoryType === 'orgScoped') {
        params.push('orgId: String')
        required.push('"orgId": orgId')
      }
      params.push('id: String')
      for (const [fname, field] of fields) {
        params.push(\`\${fname}: \${field.swiftType}? = nil\`)
        optional.push(fname)
      }
      params.push('expectedUpdatedAt: Double? = nil')
      optional.push('expectedUpdatedAt')
      me(\`\${indent(1)}public static func update(\`)
      me(\`\${indent(2)}\${params.join(\`,\\n\${indent(2)}\`)}\`)
      me(\`\${indent(1)}) async throws {\`)
      me(\`\${indent(2)}var args: [String: Any] = [\${required.join(', ')}]\`)
      for (const fname of optional) {
        const field =
          fname === 'expectedUpdatedAt' ? ({ isOptional: true, swiftType: 'Double' } as FieldEntry) : fields.get(fname)
        if (field) {
          const value = isEnumField(field.swiftType) ? \`\${fname}.rawValue\` : fname
          me(\`\${indent(2)}if let \${fname} { args["\${fname}"] = \${value} }\`)
        }
      }
      me(\`\${indent(2)}try await ConvexService.shared.mutate("\${modName}:update", args: args)\`)
      me(\`\${indent(1)}}\`)
    },
    emitMobileRmWrapper = (modName: string, factoryType: string) => {
      const params: string[] = [],
        argParts = ['"id": id']
      if (factoryType === 'orgScoped') {
        params.push('orgId: String')
        argParts.push('"orgId": orgId')
      }
      params.push('id: String')
      me(\`\${indent(1)}public static func rm(\${params.join(', ')}) async throws {\`)
      me(\`\${indent(2)}try await ConvexService.shared.mutate("\${modName}:rm", args: [\${argParts.join(', ')}])\`)
      me(\`\${indent(1)}}\`)
    },
    // eslint-disable-next-line max-statements
    emitMobileUpsertWrapper = (modName: string, fields: Map<string, FieldEntry>) => {
      const params: string[] = [],
        optional: string[] = []
      for (const [fname, field] of fields) {
        params.push(\`\${fname}: \${field.swiftType}? = nil\`)
        optional.push(fname)
      }
      me(\`\${indent(1)}public static func upsert(\`)
      me(\`\${indent(2)}\${params.join(\`,\\n\${indent(2)}\`)}\`)
      me(\`\${indent(1)}) async throws {\`)
      me(\`\${indent(2)}var args: [String: Any] = [:]\`)
      for (const fname of optional) {
        const field = fields.get(fname)
        if (field) {
          const value = isEnumField(field.swiftType) ? \`\${fname}.rawValue\` : fname
          me(\`\${indent(2)}if let \${fname} { args["\${fname}"] = \${value} }\`)
        }
      }
      me(\`\${indent(2)}try await ConvexService.shared.mutate("\${modName}:upsert", args: args)\`)
      me(\`\${indent(1)}}\`)
    },
    emitMobileRestoreWrapper = (modName: string, factoryType: string) => {
      const params: string[] = [],
        argParts = ['"id": id']
      if (factoryType === 'orgScoped') {
        params.push('orgId: String')
        argParts.push('"orgId": orgId')
      }
      params.push('id: String')
      me(\`\${indent(1)}public static func restore(\${params.join(', ')}) async throws {\`)
      me(\`\${indent(2)}try await ConvexService.shared.mutate("\${modName}:restore", args: [\${argParts.join(', ')}])\`)
      me(\`\${indent(1)}}\`)
    },
    emitMobileBulkRmWrapper = (modName: string, factoryType: string) => {
      const params: string[] = [],
        argParts = ['"ids": ids']
      if (factoryType === 'orgScoped') {
        params.push('orgId: String')
        argParts.push('"orgId": orgId')
      }
      params.push('ids: [String]')
      me(\`\${indent(1)}public static func bulkRm(\${params.join(', ')}) async throws {\`)
      me(\`\${indent(2)}try await ConvexService.shared.mutate("\${modName}:bulkRm", args: [\${argParts.join(', ')}])\`)
      me(\`\${indent(1)}}\`)
    },
    MOBILE_CUSTOM_CRUD: Record<string, string[]> = {
      task: ['toggle']
    },
    MOBILE_NONCRUD_MODULES = new Set(['org']),
    // eslint-disable-next-line max-statements
    emitMobileSubscription = (sub: SubConfig) => {
      me(\`\${indent(1)}@preconcurrency\`)
      me(\`\${indent(1)}public static func \${sub.methodName}(\`)
      const params: string[] = []
      if (sub.whereType) params.push(\`where filterWhere: \${sub.whereType}? = nil\`)
      for (const a of sub.args) params.push(\`\${a.name}: \${a.swiftType}\`)
      params.push(\`onUpdate: @escaping @Sendable @MainActor (\${sub.swiftType}) -> Void\`)
      params.push(\`onError: @escaping @Sendable @MainActor (Error) -> Void = { _ in _ = () }\`)
      if (sub.onNull) params.push(\`onNull: @escaping @Sendable @MainActor () -> Void = { () }\`)
      me(\`\${indent(2)}\${params.join(\`,\\n\${indent(2)}\`)}\`)
      me(\`\${indent(1)}) -> String {\`)

      const argParts: string[] = []
      for (const a of sub.args) argParts.push(\`"\${a.name}": \${a.name}\`)
      const argsStr = argParts.length > 0 ? \`[\${argParts.join(', ')}]\` : '[:]'

      if (sub.isPaginated && sub.whereType) {
        const hasOrgId = sub.args.some(a => a.name === 'orgId')
        if (hasOrgId) me(\`\${indent(2)}let args = listArgs(orgId: orgId)\`)
        else me(\`\${indent(2)}let args = listArgs(where: filterWhere)\`)
        me(\`\${indent(2)}#if !SKIP\`)
        me(\`\${indent(2)}return ConvexService.shared.subscribe(to: \${sub.fnRef}, args: args, type: \${sub.swiftType}.self, onUpdate: onUpdate, onError: onError)\`)
        me(\`\${indent(2)}#else\`)
        me(\`\${indent(2)}return ConvexService.shared.\${sub.skipMethod}(to: \${sub.fnRef}, args: args, onUpdate: { r in onUpdate(r) }, onError: { e in onError(e) })\`)
        me(\`\${indent(2)}#endif\`)
      } else if (sub.isPaginated) {
        const hasOrgId = sub.args.some(a => a.name === 'orgId')
        if (hasOrgId) me(\`\${indent(2)}let args = listArgs(orgId: orgId)\`)
        else me(\`\${indent(2)}let args = listArgs()\`)
        me(\`\${indent(2)}#if !SKIP\`)
        me(\`\${indent(2)}return ConvexService.shared.subscribe(to: \${sub.fnRef}, args: args, type: \${sub.swiftType}.self, onUpdate: onUpdate, onError: onError)\`)
        me(\`\${indent(2)}#else\`)
        me(\`\${indent(2)}return ConvexService.shared.\${sub.skipMethod}(to: \${sub.fnRef}, args: args, onUpdate: { r in onUpdate(r) }, onError: { e in onError(e) })\`)
        me(\`\${indent(2)}#endif\`)
      } else if (sub.nullable) {
        me(\`\${indent(2)}#if !SKIP\`)
        me(\`\${indent(2)}return ConvexService.shared.subscribe(to: \${sub.fnRef}, args: \${argsStr}, type: \${sub.swiftType}.self, onUpdate: onUpdate, onError: onError)\`)
        me(\`\${indent(2)}#else\`)
        const nullPart = sub.onNull ? ', onNull: { onNull() }' : ''
        me(\`\${indent(2)}return ConvexService.shared.\${sub.skipMethod}(to: \${sub.fnRef}, args: \${argsStr}, onUpdate: { r in onUpdate(r) }, onError: { e in onError(e) }\${nullPart})\`)
        me(\`\${indent(2)}#endif\`)
      } else if (sub.isArray) {
        if (sub.args.length === 0) {
          me(\`\${indent(2)}#if !SKIP\`)
          me(\`\${indent(2)}return ConvexService.shared.subscribe(to: \${sub.fnRef}, type: \${sub.swiftType}.self, onUpdate: onUpdate, onError: onError)\`)
          me(\`\${indent(2)}#else\`)
          me(\`\${indent(2)}return ConvexService.shared.\${sub.skipMethod}(to: \${sub.fnRef}, onUpdate: { r in onUpdate(Array(r)) }, onError: { e in onError(e) })\`)
          me(\`\${indent(2)}#endif\`)
        } else {
          me(\`\${indent(2)}#if !SKIP\`)
          me(\`\${indent(2)}return ConvexService.shared.subscribe(to: \${sub.fnRef}, args: \${argsStr}, type: \${sub.swiftType}.self, onUpdate: onUpdate, onError: onError)\`)
          me(\`\${indent(2)}#else\`)
          me(\`\${indent(2)}return ConvexService.shared.\${sub.skipMethod}(to: \${sub.fnRef}, args: \${argsStr}, onUpdate: { r in onUpdate(Array(r)) }, onError: { e in onError(e) })\`)
          me(\`\${indent(2)}#endif\`)
        }
      } else {
        me(\`\${indent(2)}#if !SKIP\`)
        me(\`\${indent(2)}return ConvexService.shared.subscribe(to: \${sub.fnRef}, args: \${argsStr}, type: \${sub.swiftType}.self, onUpdate: onUpdate, onError: onError)\`)
        me(\`\${indent(2)}#else\`)
        me(\`\${indent(2)}return ConvexService.shared.\${sub.skipMethod}(to: \${sub.fnRef}, args: \${argsStr}, onUpdate: { r in onUpdate(r) }, onError: { e in onError(e) })\`)
        me(\`\${indent(2)}#endif\`)
      }

      me(\`\${indent(1)}}\`)
    },
    // eslint-disable-next-line max-statements
    emitMobileAction = (act: MobileActionDef) => {
      const params: string[] = []
      for (const a of act.args) params.push(\`\${a.name}: \${a.swiftType}\`)
      const retSuffix = act.returnType ? \` -> \${act.returnType}\` : ''
      me(\`\${indent(1)}public static func \${act.fn.split(':')[1] ?? act.fn}(\${params.join(', ')}) async throws\${retSuffix} {\`)
      me(\`\${indent(2)}#if !SKIP\`)
      me(\`\${indent(2)}\${act.skipNotSkip}\`)
      me(\`\${indent(2)}#else\`)
      me(\`\${indent(2)}\${act.skipElse}\`)
      me(\`\${indent(2)}#endif\`)
      me(\`\${indent(1)}}\`)
    },
    SUB_CONFIGS: { apiName: string; subs: SubConfig[] }[] = [
      {
        apiName: 'BlogAPI',
        subs: [
          { methodName: 'subscribeList', fnRef: 'list', swiftType: 'PaginatedResult<Blog>', isPaginated: true, isArray: false, nullable: false, onNull: false, skipMethod: 'subscribePaginatedBlogs', whereType: 'BlogWhere', args: [] },
          { methodName: 'subscribeRead', fnRef: 'read', swiftType: 'Blog', isPaginated: false, isArray: false, nullable: false, onNull: false, skipMethod: 'subscribeBlog', args: [{ name: 'id', swiftType: 'String' }] }
        ]
      },
      {
        apiName: 'ChatAPI',
        subs: [
          { methodName: 'subscribeList', fnRef: 'list', swiftType: 'PaginatedResult<Chat>', isPaginated: true, isArray: false, nullable: false, onNull: false, skipMethod: 'subscribePaginatedChats', whereType: 'ChatWhere', args: [] }
        ]
      },
      {
        apiName: 'BlogProfileAPI',
        subs: [
          { methodName: 'subscribeGet', fnRef: 'get', swiftType: 'ProfileData', isPaginated: false, isArray: false, nullable: true, onNull: true, skipMethod: 'subscribeProfileData', args: [] }
        ]
      },
      {
        apiName: 'MessageAPI',
        subs: [
          { methodName: 'subscribeList', fnRef: 'list', swiftType: '[Message]', isPaginated: false, isArray: true, nullable: false, onNull: false, skipMethod: 'subscribeMessages', args: [{ name: 'chatId', swiftType: 'String' }] }
        ]
      },
      {
        apiName: 'ProjectAPI',
        subs: [
          { methodName: 'subscribeList', fnRef: 'list', swiftType: 'PaginatedResult<Project>', isPaginated: true, isArray: false, nullable: false, onNull: false, skipMethod: 'subscribePaginatedProjects', args: [{ name: 'orgId', swiftType: 'String' }] }
        ]
      },
      {
        apiName: 'WikiAPI',
        subs: [
          { methodName: 'subscribeList', fnRef: 'list', swiftType: 'PaginatedResult<Wiki>', isPaginated: true, isArray: false, nullable: false, onNull: false, skipMethod: 'subscribePaginatedWikis', args: [{ name: 'orgId', swiftType: 'String' }] }
        ]
      },
      {
        apiName: 'OrgAPI',
        subs: [
          { methodName: 'subscribeMyOrgs', fnRef: 'myOrgs', swiftType: '[OrgWithRole]', isPaginated: false, isArray: true, nullable: false, onNull: false, skipMethod: 'subscribeOrgsWithRole', args: [] },
          { methodName: 'subscribeMembers', fnRef: 'members', swiftType: '[OrgMemberEntry]', isPaginated: false, isArray: true, nullable: false, onNull: false, skipMethod: 'subscribeOrgMembers', args: [{ name: 'orgId', swiftType: 'String' }] },
          { methodName: 'subscribePendingInvites', fnRef: 'pendingInvites', swiftType: '[OrgInvite]', isPaginated: false, isArray: true, nullable: false, onNull: false, skipMethod: 'subscribeInvites', args: [{ name: 'orgId', swiftType: 'String' }] }
        ]
      },
      {
        apiName: 'TaskAPI',
        subs: [
          { methodName: 'subscribeByProject', fnRef: 'byProject', swiftType: '[TaskItem]', isPaginated: false, isArray: true, nullable: false, onNull: false, skipMethod: 'subscribeTasks', args: [{ name: 'orgId', swiftType: 'String' }, { name: 'projectId', swiftType: 'String' }] }
        ]
      }
    ],
    MOBILE_ACTIONS: { apiName: string; actions: MobileActionDef[] }[] = [
      {
        apiName: 'MovieAPI',
        actions: [
          {
            fn: 'movie:search', returnType: '[SearchResult]',
            args: [{ name: 'query', swiftType: 'String', isOptional: false }],
            skipNotSkip: 'return try await ConvexService.shared.action("movie:search", args: ["query": query], returning: [SearchResult].self)',
            skipElse: 'return Array(try await ConvexService.shared.actionSearchResults(name: "movie:search", args: ["query": query]))'
          },
          {
            fn: 'movie:load', returnType: 'Movie',
            args: [{ name: 'tmdbId', swiftType: 'Int', isOptional: false, wireExpr: 'Double(tmdbId)', wireName: 'tmdb_id' }],
            skipNotSkip: 'return try await ConvexService.shared.action("movie:load", args: ["tmdb_id": Double(tmdbId)], returning: Movie.self)',
            skipElse: 'return try await ConvexService.shared.actionMovie(name: "movie:load", args: ["tmdb_id": Double(tmdbId)])'
          }
        ]
      },
      {
        apiName: 'MobileAiAPI',
        actions: [
          {
            fn: 'mobileAi:chat', returnType: '',
            args: [{ name: 'chatId', swiftType: 'String', isOptional: false }],
            skipNotSkip: 'let _: [String: String] = try await ConvexService.shared.action("mobileAi:chat", args: ["chatId": chatId], returning: [String: String].self)',
            skipElse: 'try await ConvexService.shared.action(name: "mobileAi:chat", args: ["chatId": chatId])'
          }
        ]
      }
    ],
    MESSAGE_MOBILE_CREATE_DEF: CustomFnDef = {
      fn: 'create', kind: 'mutation', args: [
        { name: 'chatId', swiftType: 'String', isOptional: false },
        { name: 'parts', swiftType: '[MessagePart]', isOptional: false },
        { name: 'role', swiftType: 'String', isOptional: false }
      ],
      structArrayArg: 'parts',
      structArrayType: 'MessagePart',
      structArrayVar: 'partDicts',
      structArrayFields: [
        { name: 'type', enumField: true },
        { name: 'text' },
        { name: 'image' },
        { name: 'file' },
        { name: 'name' }
      ]
    }

  me('// swiftlint:disable file_length')
  me('import Foundation')
  me('')

  for (const [modName, fns] of Object.entries(modules)) {
    const tableName = modName.replace(/^(?<ch>[a-z])/u, (_, c: string) => c.toLowerCase()),
      factoryType = tableFactoryType[tableName],
      fields = userSchemaFields[tableName],
      apiName = \`\${pascalCase(modName)}API\`,
      fnSet = new Set(fns)

    if (factoryType && fields) {
      const prevLen = mLines.length

      if (factoryType === 'owned' || factoryType === 'orgScoped') {
        if (fnSet.has('create')) emitMobileCreateWrapper(modName, fields, factoryType)
        if (fnSet.has('update')) emitMobileUpdateWrapper(modName, fields, factoryType)
        if (fnSet.has('rm')) emitMobileRmWrapper(modName, factoryType)
        if (fnSet.has('restore')) emitMobileRestoreWrapper(modName, factoryType)
        if (fnSet.has('bulkRm')) emitMobileBulkRmWrapper(modName, factoryType)
        const customCrud = MOBILE_CUSTOM_CRUD[modName]
        if (customCrud) {
          const defs = CUSTOM_FN_DEFS[modName]
          if (defs)
            for (const def of defs)
              if (customCrud.includes(def.fn) && fnSet.has(def.fn))
                emitMobileNonCrudWrapper(modName, def, me)
        }
      } else if (factoryType === 'singleton' && fnSet.has('upsert')) emitMobileUpsertWrapper(modName, fields)

      if (mLines.length > prevLen) {
        const wrappedLines = mLines.splice(prevLen)
        me('')
        me(\`extension \${apiName} {\`)
        for (const line of wrappedLines) me(line)
        me('}')
      }
    }

    if (MOBILE_NONCRUD_MODULES.has(modName)) {
      const defs = CUSTOM_FN_DEFS[modName]
      if (defs) {
        me('')
        me(\`extension \${apiName} {\`)
        for (const def of defs) if (fnSet.has(def.fn)) emitMobileNonCrudWrapper(modName, def, me)
        me('}')
      }
    }
  }

  for (const group of SUB_CONFIGS) {
    const hasMessageCreate = group.apiName === 'MessageAPI'
    me('')
    me(\`extension \${group.apiName} {\`)
    if (hasMessageCreate) {
      emitMobileNonCrudWrapper('message', MESSAGE_MOBILE_CREATE_DEF, me)
      me('')
    }
    for (let si = 0; si < group.subs.length; si += 1) {
      if (si > 0 || hasMessageCreate) me('')
      emitMobileSubscription(group.subs[si]!)
    }
    me('}')
  }

  for (const group of MOBILE_ACTIONS) {
    me('')
    me(\`extension \${group.apiName} {\`)
    for (let ai = 0; ai < group.actions.length; ai += 1) {
      if (ai > 0) me('')
      emitMobileAction(group.actions[ai]!)
    }
    me('}')
  }

  const mobileOutput = \`\${mLines.join('\\n')}\\n\`
  writeFileSync(MOBILE_OUTPUT_PATH, mobileOutput)
  process.stdout.write(\`Generated \${MOBILE_OUTPUT_PATH}\\n\`)
}
`

const result = [
  section1,
  newInterfaces,
  section2,
  newConfigAndEmitter,
  section4,
  newLine1247,
  section6,
  newOwnBlocks,
  section8,
  '',
  newMobileSection
].join('\n')

writeFileSync('packages/lazyconvex/src/codegen-swift.ts', result)
console.log('File written successfully')
console.log(`Total lines: ${result.split('\n').length}`)
