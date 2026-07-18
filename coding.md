# Coding guidelines

The Chatium platform lets you write TypeScript code and run it on the Chatium backend. The platform is highly opinionated and feels similar to Node.js in many ways. However, there is no real Node.js runtime, so standard built-in Node.js modules are not available.

## Coding standards

Use 2 spaces for indentation.

Follow this example when you write Vue single-file components:

<example filename="pages/Page.vue">
<template>
  // ... Your template code here ...
</template>

<script setup>
  // ... Your initializing script here
</script>

<style scoped>
  // ... Your styles here ...
</style>
</example>

**IMPORTANT:** Keep files small and maintainable. For example, when building a landing page, split it into sections and components, and put each section and component in a **separate file**.

**IMPORTANT:** Any interface, website page, landing page, dashboard, or visual block must be implemented with Vue single-file components (`.vue`).

**IMPORTANT:** Do not implement the UI as one huge JSX/TSX page. Use TSX only as route wrappers and server-side HTML shells.

**IMPORTANT:** Always split the UI across multiple files: each major section and reusable element must be its own component.

## Chatium backend framework runtime

You run in a special JavaScript environment compatible with the V8 engine used in browsers. This is **not** Node.js. You **must not** use npm, `node_modules`, the shell, or direct file-system access.

You cannot use built-in Node modules such as `crypto`, `http`, `https`, or `fs`.

There is a global variable `ctx`: the request context. If an example passes it into methods, functions, or components, you must do the same in your code.

The current working directory is `/`. Always use relative paths.

In server-side code (`app.get`, `app.post`), do not use `setTimeout`, `setInterval`, `setImmediate`, `process.nextTick`, or similar APIs.

**To run server-side code after a delay (a deferred / scheduled task), use a JOB — never `setTimeout`.** Define a job, then schedule it with a delay from a route handler:
```ts
// jobs/<name>.ts (or inline) — define the job handler
export const myJob = app.job('/my-job', async (ctx, params) => { /* e.g. await Table.create(ctx, {...}) */ })
// from a route handler — schedule it to run later (params passed to the handler):
const taskId = await myJob.scheduleJobAfter(ctx, 5, 'minutes', { someId: x })  // runs the handler ~5 min later
```
Signature: `<job>.scheduleJobAfter(ctx, amount, unit, params)` (e.g. unit `'minutes'`). Returns a task id.

## Vue.js

You use Vue.js **3.5.13**.

You never call `Vue.createApp()` yourself; the Chatium backend framework does that for you.

Inside any Vue component, `ctx` is available as a global. Do not pass it through props or read it from the `setup` context API; it is always available globally everywhere in your code.

If the task involves a UI, page, or site, use Vue as the primary and mandatory approach for the interface.

Do not use React, Solid, Svelte, or a raw HTML template instead of Vue components for the UI.

## Expected output structure

There are always at least two files:

<file_structure>
/index.tsx
/pages/RequestedPage.vue
</file_structure>

For UI work, expect a **multi-file** layout, not one large file. Minimum split for a typical page: a dedicated page file plus separate section components under `/components`.

You may also add:

- components under `/components`
- API endpoints under `/api`
- extra route files **only** if the task explicitly requires them
- shared frontend/backend logic under `/shared`

For example:

<file_structure>
/index.tsx
/aboutPage.tsx
/pages/RequestedPage.vue
/components/HeaderBlock.vue
/components/Button.vue
/api/products.ts
/api/basket.ts
/shared/utils.ts
</file_structure>

Do not create `.js` files for shared logic; always use `.ts`.

### `/index.tsx`

Application entry point: a wrapper that boots and renders the rest of the app.

Declare **only one** route per route file using `app.get('/')` or `app.post('/')`. Do not put multiple routes in one file. If another route is needed, add a separate file **only** when the task explicitly asks for it.

Example:

<example filename="/index.tsx">
import { jsx } from "@app/html-jsx"
import ProductsListPage from './pages/ProductsListPage.vue'

// Use export to access index route in components and other modules
export const indexPageRoute = app.get('/', async (ctx, req) => {
  return (
    <html>
      <head>
        <title>Product list</title>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <script src="/s/metric/clarity.js"></script>
      </head>
      <body>
        <ProductsListPage />
      </body>
    </html>
  )
})
</example>

Do not forget to close all HTML tags.

Do not use HTML comments inside JSX.

## Inline JavaScript in server-rendered HTML

If you need to inline JavaScript in server-rendered HTML, follow this pattern:

<example filename="index.tsx">
// @shared
import { jsx } from "@app/html-jsx"
import ProductsListPage from './pages/ProductsListPage.vue'

// Use export to access index route in components and other modules
export const indexPageRoute = app.get('/', async (ctx, req) => {
  return (
    <html>
      <head>
        <title>Product list</title>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <script src="/s/metric/clarity.js"></script>
        <script type="text/javascript">{`
          Your inlined javascript goes here. Do not forget to escape any backtick if present in inlined script
        `}</>
      </head>
      <body>
        <ProductsListPage />
      </body>
    </html>
  )
})
</example>


## Code rules
- Routing - routing.md
- Database - heap.md
- Database filter - heap_filter.md
- File storage - storage.md
- Authentication - auth.md