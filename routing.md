# Chatium Backend Routing

## Route Definition
Use global `app` variable (backend only, .ts/.tsx files) with methods:
- `app.get('/')` - GET route builder
- `app.post('/')` - POST route builder

Attach schemas and handler with chain methods:
- `.query(s => ({ ... }))` - validate and type query parameters
- `.body(s => ({ ... }))` - validate and type request body for POST routes
- `.handle(async (ctx, req) => { ... })` - route handler

Simple form `app.get('/', handler)` / `app.post('/', handler)` is also allowed, but when a route has query params or body, prefer the schema-based chain style.

These are the route builder methods for API routes and pages. (For deferred/background tasks there is also `app.job` — see the jobs topic.)

## Core Constraints
- Only one route is allowed per file.
- The only allowed route path inside a file is `/`.
- Path parameters are not supported (for example: `/:id` is invalid).
- Do not put variable values into the path.
- Use `.query()` for query parameters and `.body()` for POST request payloads.

## Schema Definition
Inside `.query()` and `.body()`, use the provided schema builder `s`.
The validated values become typed in `req.query` and `req.body`.

```ts
app.get('/')
  .query(s => ({
    key: s.string()
  }))
  .handle(async (ctx, req) => {
    // req.query.key is validated and typed
    return { ok: true }
  })

app.post('/')
  .query(s => ({
    key: s.string()
  }))
  .body(s => ({
    bodyKey: s.string()
  }))
  .handle(async (ctx, req) => {
    // req.query contains validated and typed query
    // req.body contains validated and typed body
    return { ok: true }
  })
```

Comprehensive schema example:

```ts
s.object({
  string: s.string(),
  optionalString: s.string().optional(),
  enum: s.enum(['a', 'b']),
  number: s.number(),
  arrayOf: s.array(s.string()),
  any: s.any(),
  unknown: s.unknown(),
  nestedObj: s.object({
    key: s.string().optional()
  })
})
```

Use Chatium schema builder `s`; do not invent other validation libraries such as Zod or Yup unless the surrounding code already requires them.

## File-based Routing
- Route `/` in `api/task/list.ts` -> `api/task/list`
- Route `/` in `api/task/get.ts` -> `api/task/get`
- Route `/` in `api/task/create.ts` -> `api/task/create`
- Route `/` in `api/task/delete.ts` -> `api/task/delete`
- Route `/` in `api/task/update.ts` -> `api/task/update`

If you need multiple routes for one entity (for example CRUD), create a folder for that entity (for example `task`) and implement separate files per action: `list`, `get`, `create`, `delete`, `update`.

## RouteRef Usage
Route references must be used:
- to provide URL to user (use `.url()`)
- to call routes inside application code (use `.run(ctx)`)
- for POST routes, pass request body as the second argument of `.run(ctx, body)`

Never hardcode URLs.

```ts
// api/task/get.ts
export const taskGetRoute = app.get('/')
  .query(s => ({ id: s.string() }))
  .handle(async (ctx, req) => {
    // req.query.id is validated and typed
    return { ok: true }
  })

// api/task/create.ts
export const taskCreateRoute = app.post('/')
  .query(s => ({ source: s.string().optional() }))
  .body(s => ({
    title: s.string(),
    description: s.string().optional()
  }))
  .handle(async (ctx, req) => {
    // req.query.source is validated and typed
    // req.body.title / req.body.description are validated and typed
    return { ok: true }
  })
```

```ts
import { taskGetRoute } from './api/task/get'
import { taskCreateRoute } from './api/task/create'

// URL for user
taskGetRoute.query({ id: '123' }).url()

// Route invocation in app
await taskGetRoute.query({ id: '123' }).run(ctx, {})
await taskCreateRoute
  .query({ source: 'ui' })
  .run(ctx, { title: 'Task title', description: 'Task description' })
```

# Rules
NEVER hardcode URLs - always use RouteRef
Only one `/` route per file
No path parameters
Use `.query()` for query parameters and `.body()` for POST body when needed
Schema callbacks use Chatium schema builder `s`
RouteRef instances work in both backend and frontend code
Do NOT use ctx.routes.routeName - ctx has no routes property
